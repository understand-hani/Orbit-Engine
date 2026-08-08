import SwiftUI

struct AgentChatView: View {
    let session: BaseSession
    let contextRefs: [String]
    let title: String

    @State private var thread: AIChatThread?
    @State private var draft = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSavingDiscussion = false

    private let chatAPI = ChatAPI()

    var body: some View {
        VStack(spacing: 0) {
            List {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if let thread, !thread.messages.isEmpty {
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
        } catch {
            errorMessage = error.localizedDescription
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
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await chatAPI.send(threadID: threadID, content: content)
            thread = response.thread
        } catch {
            errorMessage = error.localizedDescription
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
