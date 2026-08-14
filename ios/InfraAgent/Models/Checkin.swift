import Foundation

struct Checkin: Codable, Identifiable {
    let id: String
    let sessionID: String
    let date: String
    let taskType: TaskType
    let durationMin: Int
    let status: String
    let summary: String
    let keyInsight: String
    let nextAction: String
    let sourceTitle: String?
    let sourceURL: String?
    let sourceSummary: String?
    let userNotes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case date
        case taskType = "task_type"
        case durationMin = "duration_min"
        case status
        case summary
        case keyInsight = "key_insight"
        case nextAction = "next_action"
        case sourceTitle = "source_title"
        case sourceURL = "source_url"
        case sourceSummary = "source_summary"
        case userNotes = "user_notes"
        case createdAt = "created_at"
    }
}

struct CheckinCreate: Codable {
    let sessionID: String
    let date: String
    let taskType: TaskType
    let durationMin: Int
    let status: String
    let summary: String
    let keyInsight: String
    let nextAction: String
    let sourceTitle: String?
    let sourceURL: String?
    let sourceSummary: String?
    let userNotes: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case date
        case taskType = "task_type"
        case durationMin = "duration_min"
        case status
        case summary
        case keyInsight = "key_insight"
        case nextAction = "next_action"
        case sourceTitle = "source_title"
        case sourceURL = "source_url"
        case sourceSummary = "source_summary"
        case userNotes = "user_notes"
    }
}

struct CompletionConfirmRequest: Codable {
    let durationMin: Int
    let status: String
    let summary: String
    let keyInsight: String
    let nextAction: String
    let sourceTitle: String?
    let sourceURL: String?
    let sourceSummary: String?
    let userNotes: String?

    enum CodingKeys: String, CodingKey {
        case durationMin = "duration_min"
        case status
        case summary
        case keyInsight = "key_insight"
        case nextAction = "next_action"
        case sourceTitle = "source_title"
        case sourceURL = "source_url"
        case sourceSummary = "source_summary"
        case userNotes = "user_notes"
    }
}

struct CompletionDraftRequest: Codable {
    let durationMin: Int
    let sourceTitle: String?
    let sourceURL: String?
    let sourceSummary: String?
    let userNotes: String?

    enum CodingKeys: String, CodingKey {
        case durationMin = "duration_min"
        case sourceTitle = "source_title"
        case sourceURL = "source_url"
        case sourceSummary = "source_summary"
        case userNotes = "user_notes"
    }
}

struct CompletionDraftResponse: Codable {
    let summary: String
    let keyInsight: String
    let nextAction: String
    let provider: String

    enum CodingKeys: String, CodingKey {
        case summary
        case keyInsight = "key_insight"
        case nextAction = "next_action"
        case provider
    }
}

struct WeeklyStudioDraftResponse: Codable {
    let completionSummary: String
    let suggestedPriorities: [String]
    let provider: String

    enum CodingKeys: String, CodingKey {
        case completionSummary = "completion_summary"
        case suggestedPriorities = "suggested_priorities"
        case provider
    }
}

struct CompletionConfirmResponse: Codable {
    let session: BaseSession
    let checkin: Checkin
}
