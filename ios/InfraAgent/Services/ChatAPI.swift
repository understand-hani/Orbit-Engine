import Foundation

struct ChatAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func createThread(_ request: AIChatThreadCreate) async throws -> AIChatThread {
        try await resolvedClient.post(
            "/api/chat/threads",
            timeoutInterval: 4,
            body: request
        )
    }

    func thread(id: String) async throws -> AIChatThread {
        try await resolvedClient.get("/api/chat/threads/\(id)")
    }

    func threads(sessionID: String) async throws -> [AIChatThread] {
        try await resolvedClient.get("/api/sessions/\(sessionID)/chat/threads")
    }

    func send(threadID: String, content: String) async throws -> AIChatSendResponse {
        try await resolvedClient.post(
            "/api/chat/threads/\(threadID)/messages",
            timeoutInterval: 10,
            body: AIChatSendRequest(content: content)
        )
    }

    func summarize(threadID: String) async throws -> AIChatSummary {
        try await resolvedClient.post("/api/chat/threads/\(threadID)/summarize")
    }
}
