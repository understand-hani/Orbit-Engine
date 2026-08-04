import Foundation

struct AIChatThread: Codable, Identifiable {
    let id: String
    let sessionID: String
    let taskType: TaskType
    let contextRefs: [String]
    let messages: [AIChatMessage]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case taskType = "task_type"
        case contextRefs = "context_refs"
        case messages
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AIChatMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt = "created_at"
    }
}

struct AIChatThreadCreate: Codable {
    let sessionID: String
    let contextRefs: [String]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case contextRefs = "context_refs"
    }
}

struct AIChatSendRequest: Codable {
    let content: String
}

struct AIChatSendResponse: Codable {
    let thread: AIChatThread
    let userMessage: AIChatMessage
    let assistantMessage: AIChatMessage

    enum CodingKeys: String, CodingKey {
        case thread
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
    }
}

struct AIChatSummary: Codable {
    let threadID: String
    let sessionID: String
    let suggestedTitle: String
    let summary: String
    let keyInsights: [String]
    let actionItems: [String]
    let contextRefs: [String]

    enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case sessionID = "session_id"
        case suggestedTitle = "suggested_title"
        case summary
        case keyInsights = "key_insights"
        case actionItems = "action_items"
        case contextRefs = "context_refs"
    }
}
