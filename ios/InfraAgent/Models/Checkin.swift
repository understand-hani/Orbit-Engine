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

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case date
        case taskType = "task_type"
        case durationMin = "duration_min"
        case status
        case summary
        case keyInsight = "key_insight"
        case nextAction = "next_action"
    }
}

struct CompletionConfirmRequest: Codable {
    let durationMin: Int
    let status: String
    let summary: String
    let keyInsight: String
    let nextAction: String

    enum CodingKeys: String, CodingKey {
        case durationMin = "duration_min"
        case status
        case summary
        case keyInsight = "key_insight"
        case nextAction = "next_action"
    }
}

struct CompletionConfirmResponse: Codable {
    let session: BaseSession
    let checkin: Checkin
}
