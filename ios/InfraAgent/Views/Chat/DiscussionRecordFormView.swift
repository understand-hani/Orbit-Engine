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
    @State private var message: String?

    private let chatAPI = ChatAPI()
    private let checkinAPI = CheckinAPI()

    var body: some View {
        NavigationStack {
            Form {
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
                    .disabled(isSaving || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

        let localSummary = localDiscussionSummary
        let localInsight = localKeyInsight
        let localAction = localNextAction
        summary = localSummary
        keyInsight = localInsight
        nextAction = localAction

        guard !thread.id.hasPrefix("local_") else { return }
        do {
            let draft = try await chatAPI.summarize(threadID: thread.id)
            guard summary == localSummary,
                  keyInsight == localInsight,
                  nextAction == localAction else { return }
            summary = draft.summary
            keyInsight = draft.keyInsights.joined(separator: "\n")
            nextAction = draft.actionItems.joined(separator: "\n")
        } catch {
            // The local conversation-based draft remains available without interruption.
        }
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

    private var localNextAction: String {
        switch session.taskType {
        case .researchFeeder:
            return "回到论文原文或关键图表，核对一条能支持当前判断的直接证据。"
        case .techRadar:
            return "核对该信号的一手来源，再决定是否转入 Deep Dive。"
        case .jdAnalysis:
            return "把讨论结论转成一个可验证的能力补齐或求职行动。"
        }
    }

    private var localKeyInsight: String {
        switch session.taskType {
        case .researchFeeder:
            return "核心判断是用原文段落和图表证据校验结论，避免把材料概述视为已验证事实。"
        case .techRadar:
            return "核心判断是先区分一手证据与转载信息，再评估信号的技术实质和跟进价值。"
        case .jdAnalysis:
            return "核心判断是把岗位要求映射到已有经历与能力缺口，再确定可验证的优先行动。"
        }
    }

    private var localDiscussionSummary: String {
        switch session.taskType {
        case .researchFeeder:
            return "本次讨论聚焦于论文结论、证据支撑及其与当前研究任务的关联。"
        case .techRadar:
            return "本次讨论聚焦于当前信号的信息可信度、技术实质与跟进价值。"
        case .jdAnalysis:
            return "本次讨论聚焦于岗位要求、现有能力证据与优先补齐方向。"
        }
    }
}
