import Foundation

struct BaseSession: Codable, Identifiable {
    let id: String
    let date: String
    let weekday: String
    let taskType: TaskType
    let sessionMode: SessionMode
    let title: String
    let subtitle: String
    let status: SessionStatus
    let suggestedAction: SuggestedAction
    let payloadType: TaskType
    let payload: SessionPayload
    let aiChatThreadID: String
    let completion: CompletionState
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case weekday
        case taskType = "task_type"
        case sessionMode = "session_mode"
        case title
        case subtitle
        case status
        case suggestedAction = "suggested_action"
        case payloadType = "payload_type"
        case payload
        case aiChatThreadID = "ai_chat_thread_id"
        case completion
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        weekday = try container.decode(String.self, forKey: .weekday)
        taskType = try container.decode(TaskType.self, forKey: .taskType)
        sessionMode = try container.decode(SessionMode.self, forKey: .sessionMode)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        status = try container.decode(SessionStatus.self, forKey: .status)
        suggestedAction = try container.decode(SuggestedAction.self, forKey: .suggestedAction)
        payloadType = try container.decode(TaskType.self, forKey: .payloadType)
        aiChatThreadID = try container.decode(String.self, forKey: .aiChatThreadID)
        completion = try container.decode(CompletionState.self, forKey: .completion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        switch payloadType {
        case .techRadar:
            payload = .techRadar(try container.decode(TechRadarPayload.self, forKey: .payload))
        case .jdAnalysis:
            payload = .jdAnalysis(try container.decode(JDAnalysisPayload.self, forKey: .payload))
        case .researchFeeder:
            payload = .researchFeeder(try container.decode(ResearchFeederPayload.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(weekday, forKey: .weekday)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(sessionMode, forKey: .sessionMode)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(status, forKey: .status)
        try container.encode(suggestedAction, forKey: .suggestedAction)
        try container.encode(payloadType, forKey: .payloadType)
        try container.encode(aiChatThreadID, forKey: .aiChatThreadID)
        try container.encode(completion, forKey: .completion)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        switch payload {
        case .techRadar(let value):
            try container.encode(value, forKey: .payload)
        case .jdAnalysis(let value):
            try container.encode(value, forKey: .payload)
        case .researchFeeder(let value):
            try container.encode(value, forKey: .payload)
        }
    }
}

enum SessionPayload {
    case techRadar(TechRadarPayload)
    case jdAnalysis(JDAnalysisPayload)
    case researchFeeder(ResearchFeederPayload)
}

struct CompletionState: Codable {
    let criteria: [CompletionCriterion]
    let evidence: [CompletionEvidence]
    let systemSuggestion: String
    let systemReason: String
    let userConfirmedStatus: String?
    let confirmedAt: Date?

    enum CodingKeys: String, CodingKey {
        case criteria
        case evidence
        case systemSuggestion = "system_suggestion"
        case systemReason = "system_reason"
        case userConfirmedStatus = "user_confirmed_status"
        case confirmedAt = "confirmed_at"
    }
}

struct CompletionCriterion: Codable, Identifiable {
    let id: String
    let description: String
    let required: Bool
    let status: String
}

struct CompletionEvidence: Codable, Identifiable {
    let id: String
    let type: String
    let description: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case description
        case createdAt = "created_at"
    }
}
