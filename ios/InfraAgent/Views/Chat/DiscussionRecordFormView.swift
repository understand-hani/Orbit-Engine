import SwiftUI

struct DiscussionRecordFormView: View {
    let session: BaseSession
    let thread: AIChatThread

    @Environment(\.dismiss) private var dismiss

    @State private var summary = ""
    @State private var keyInsight = ""
    @State private var nextAction = ""
    @State private var durationMin = 15
    @State private var isSaving = false
    @State private var isRefining = false
    @State private var message: String?

    private let chatAPI = ChatAPI()
    private let checkinAPI = CheckinAPI()

    var body: some View {
        NavigationStack {
            Form {
                if isRefining {
                    Section {
                        LoadingView(title: "Agent 正在提炼讨论精髓")
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("讨论总结") {
                    TextField("总结", text: $summary, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("关键洞察") {
                    TextField("关键洞察", text: $keyInsight, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("行动项") {
                    TextField("下一步行动", text: $nextAction, axis: .vertical)
                        .lineLimit(2...6)
                    Stepper("时长：\(durationMin) 分钟", value: $durationMin, in: 5...120, step: 5)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        Label(isSaving ? "正在保存" : "保存到归档", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(
                        isSaving || isRefining ||
                        summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .navigationTitle("保存讨论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSummary()
            }
        }
    }

    private func loadSummary() async {
        guard summary.isEmpty && keyInsight.isEmpty && nextAction.isEmpty else { return }
        isRefining = true
        defer { isRefining = false }

        if !thread.id.hasPrefix("local_") {
            do {
                let draft = try await chatAPI.summarize(threadID: thread.id)
                if !draft.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = draft.summary
                    keyInsight = draft.keyInsights.joined(separator: "\n")
                    nextAction = draft.actionItems.joined(separator: "\n")
                    return
                }
            } catch {
                // A conversation-specific local draft keeps archiving usable offline.
            }
        }

        let draft = localConversationDraft
        summary = draft.summary
        keyInsight = draft.insight
        nextAction = draft.action
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await checkinAPI.create(
                CheckinCreate(
                    sessionID: session.id,
                    date: session.date,
                    taskType: session.taskType,
                    durationMin: durationMin,
                    status: "partial",
                    summary: "讨论记录：\(summary)",
                    keyInsight: keyInsight,
                    nextAction: nextAction,
                    sourceTitle: nil,
                    sourceURL: nil,
                    sourceSummary: nil,
                    userNotes: nil
                )
            )
            message = "已保存到归档"
            dismiss()
        } catch {
            message = "归档服务暂不可用，当前草稿已保留，可稍后重试。"
        }
    }

    private var localConversationDraft: (summary: String, insight: String, action: String) {
        let validMessages = thread.messages.filter { message in
            !message.content.contains("The request timed out") &&
            !message.content.contains("讨论请求失败") &&
            !message.content.contains("远端 Agent 暂未响应") &&
            !message.content.contains("Mock fallback")
        }
        let question = cleanFragment(
            validMessages.last(where: { $0.role == "user" })?.content ?? "本次问题",
            limit: 90
        )
        let answer = validMessages.last(where: { $0.role == "assistant" })?.content ?? ""
        let points = discussionPoints(answer)
        let actionWords = ["建议", "下一步", "应当", "需要", "核验", "确认", "追踪", "阅读"]
        let actionPoint = points.first { point in actionWords.contains { point.contains($0) } }
        let insight = points.first(where: { $0 != actionPoint }) ?? points.first

        guard let insight else {
            return (
                "本次讨论围绕“\(question)”展开。",
                "当前有效对话尚未形成足够具体、可归档的判断。",
                "继续围绕“\(question)”补充证据，并确认一个可执行的下一步。"
            )
        }
        return (
            cleanFragment("围绕“\(question)”，讨论聚焦于\(insight)", limit: 180),
            cleanFragment(insight, limit: 140),
            cleanFragment(
                actionPoint ?? "继续围绕“\(question)”补充证据，并确认一个可执行的下一步。",
                limit: 140
            )
        )
    }

    private func discussionPoints(_ content: String) -> [String] {
        var result: [String] = []
        for rawLine in content.components(separatedBy: .newlines) {
            let line = cleanFragment(rawLine, limit: 160)
            guard line.count >= 8,
                  !["好的", "当然", "下面", "以下", "总的来说"].contains(where: { line.hasPrefix($0) }),
                  !result.contains(line) else { continue }
            result.append(line)
        }
        return Array(result.prefix(5))
    }

    private func cleanFragment(_ content: String, limit: Int) -> String {
        let stripped = content.replacingOccurrences(
            of: #"^(?:#{1,6}\s*|[-*•>]\s*|\d+[.)、]\s*)+"#,
            with: "",
            options: .regularExpression
        )
        let compact = stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "。；; "))
        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
