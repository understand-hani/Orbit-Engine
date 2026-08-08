import SwiftUI

struct JDLocalAgentDiscussionView: View {
    @State private var messages: [JDLocalChatMessage] = [
        JDLocalChatMessage(
            role: "Agent",
            content: "我可以讨论 JD 匹配、TPM 风险、能力差距、候选行动和当前任务状态。"
        )
    ]
    @State private var draft = ""
    @State private var isSending = false
    @State private var isSaving = false
    @State private var saveMessage: String?

    private let api = JDIntelligenceAPI()
    private let checkinAPI = CheckinAPI()

    var body: some View {
        VStack(spacing: 0) {
            List {
                if messages.count > 1 {
                    Section("归档") {
                        Button {
                            Task { await saveDiscussion() }
                        } label: {
                            Label(isSaving ? "正在保存" : "保存讨论到归档", systemImage: "tray.and.arrow.down")
                        }
                        .disabled(isSaving)

                        if let saveMessage {
                            Text(saveMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(messages) { message in
                    ChatBubbleView(
                        role: message.role,
                        content: message.content,
                        isUser: message.role == "你"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            HStack(spacing: 8) {
                TextField("输入你的问题...", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await send() }
                    }

                Button("发送") {
                    Task { await send() }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle("Agent 讨论")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let history = messages.map {
            JDDiscussionMessagePayload(role: $0.role, content: $0.content)
        }
        draft = ""
        messages.append(JDLocalChatMessage(role: "你", content: content))

        isSending = true
        defer { isSending = false }

        do {
            let response = try await api.discuss(
                messages: history,
                content: content
            )
            messages.append(JDLocalChatMessage(role: "Agent", content: response.content))
        } catch {
            messages.append(
                JDLocalChatMessage(
                    role: "Agent",
                    content: "讨论请求失败：\(error.localizedDescription)"
                )
            )
        }
    }

    private func saveDiscussion() async {
        isSaving = true
        defer { isSaving = false }

        let transcript = messages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        let lastAgentMessage = messages.last(where: { $0.role == "Agent" })?.content ?? "JD Agent 讨论已保存。"

        do {
            _ = try await checkinAPI.create(
                CheckinCreate(
                    sessionID: "jd_intelligence",
                    date: Self.todayString(),
                    taskType: .jdAnalysis,
                    durationMin: 15,
                    status: "partial",
                    summary: "JD Agent 讨论记录",
                    keyInsight: lastAgentMessage,
                    nextAction: transcript,
                    sourceTitle: nil,
                    sourceURL: nil,
                    sourceSummary: nil,
                    userNotes: nil
                )
            )
            saveMessage = "已保存到归档"
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct JDLocalChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}
