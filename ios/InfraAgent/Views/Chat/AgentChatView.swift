import SwiftUI

struct AgentChatView: View {
    let session: BaseSession
    let contextRefs: [String]
    let title: String

    @State private var thread: AIChatThread?
    @State private var draft = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isUsingLocalFallback = false
    @State private var isSavingDiscussion = false

    private let chatAPI = ChatAPI()

    var body: some View {
        VStack(spacing: 0) {
            List {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if isUsingLocalFallback {
                    Label("快速讨论模式", systemImage: "bolt.horizontal.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                if let thread, !thread.messages.isEmpty, !isUsingLocalFallback {
                    Section("归档") {
                        Button {
                            isSavingDiscussion = true
                        } label: {
                            Label("保存讨论到归档", systemImage: "tray.and.arrow.down")
                        }
                    }
                }

                ForEach(thread?.messages ?? []) { message in
                    ChatBubbleView(
                        role: message.role == "assistant" ? "Agent" : "你",
                        content: message.content,
                        isUser: message.role != "assistant"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if isLoading {
                    LoadingView(title: "思考中")
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
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadThread()
        }
        .sheet(isPresented: $isSavingDiscussion) {
            if let thread {
                DiscussionRecordFormView(session: session, threadID: thread.id)
            }
        }
    }

    private func loadThread() async {
        guard thread == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            thread = try await chatAPI.createThread(
                AIChatThreadCreate(sessionID: session.id, contextRefs: contextRefs)
            )
            errorMessage = nil
        } catch {
            thread = localThread()
            isUsingLocalFallback = true
            errorMessage = nil
        }
    }

    private func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        if thread == nil {
            await loadThread()
        }
        guard let threadID = thread?.id else { return }

        draft = ""
        if isUsingLocalFallback {
            appendLocalExchange(question: content)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await chatAPI.send(threadID: threadID, content: content)
            thread = response.thread
            errorMessage = nil
        } catch {
            appendLocalExchange(question: content)
            isUsingLocalFallback = true
            errorMessage = nil
        }
    }

    private func localThread() -> AIChatThread {
        let now = Date()
        return AIChatThread(
            id: "local_\(UUID().uuidString)",
            sessionID: session.id,
            taskType: session.taskType,
            contextRefs: contextRefs,
            messages: [],
            createdAt: now,
            updatedAt: now
        )
    }

    private func appendLocalExchange(question: String) {
        let now = Date()
        let current = thread ?? localThread()
        let userMessage = AIChatMessage(
            id: "local_user_\(UUID().uuidString)",
            role: "user",
            content: question,
            createdAt: now
        )
        let assistantMessage = AIChatMessage(
            id: "local_agent_\(UUID().uuidString)",
            role: "assistant",
            content: localReply(to: question),
            createdAt: now
        )
        thread = AIChatThread(
            id: current.id,
            sessionID: current.sessionID,
            taskType: current.taskType,
            contextRefs: current.contextRefs,
            messages: current.messages + [userMessage, assistantMessage],
            createdAt: current.createdAt,
            updatedAt: now
        )
    }

    private func localReply(to question: String) -> String {
        switch session.payload {
        case .researchFeeder(let payload):
            let readers = (payload.paperReaders ?? []) + (payload.paperReader.map { [$0] } ?? [])
            if let figure = readers.flatMap(\.keyFigures).first(where: { contextRefs.contains($0.id) }) {
                return "针对“\(question)”：这张图当前最重要的判断是：\(figure.whyImportant) 下一步应结合图注与正文核对其变量、对照组和结论边界。"
            }
            if let passage = readers.flatMap(\.selectedPassages).first(where: { contextRefs.contains($0.id) }) {
                return "针对“\(question)”：这段原文值得关注，因为：\(passage.whySelected) 建议继续追问它支持了哪条结论，以及还缺什么证据。"
            }
            if let paper = payload.papers.first(where: { contextRefs.contains($0.id) }) {
                return "针对“\(question)”：可先基于《\(paper.title)》的 Abstract 与当前选材理由判断。\(paper.whySelected) 下一步核对关键段落或图表是否真正支持该判断。"
            }
            return "针对“\(question)”：先回到当前论文的 Abstract、关键段落和图表证据，区分作者结论与可验证证据，再记录一条明确判断。"
        case .techRadar(let payload):
            if let item = payload.digest.items.first(where: { contextRefs.contains($0.id) || contextRefs.contains("signal:\($0.id)") }) {
                return "针对“\(question)”：当前信号的技术实质是：\(item.technicalSubstance) 证据状态为“\(item.evidenceStatus)”，建议先核对一手来源，再决定是否转入 Deep Dive。"
            }
            return "针对“\(question)”：先核对当前信号的一手来源、技术实质和证据状态，再判断是否值得转入 Deep Dive。"
        case .jdAnalysis:
            return "针对“\(question)”：先把岗位要求映射到现有经历与能力缺口，再选择一个可验证的下一步行动。"
        }
    }
}

struct ChatBubbleView: View {
    let role: String
    let content: String
    let isUser: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser {
                Spacer(minLength: 42)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 42)
            }
        }
        .padding(.vertical, 3)
    }
}
