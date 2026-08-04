import Foundation

struct JDAnalysisPayload: Codable {
    let jdInput: JDInput
    let resumeProfileSnapshotID: String?
    let learningPlanSnapshotID: String?
    let analysis: JDAnalysis
    let resumeRevisionSuggestions: [ResumeRevisionSuggestion]
    let capabilityActions: [CapabilityAction]

    enum CodingKeys: String, CodingKey {
        case jdInput = "jd_input"
        case resumeProfileSnapshotID = "resume_profile_snapshot_id"
        case learningPlanSnapshotID = "learning_plan_snapshot_id"
        case analysis
        case resumeRevisionSuggestions = "resume_revision_suggestions"
        case capabilityActions = "capability_actions"
    }
}

struct JDInput: Codable, Identifiable {
    let id: String
    let sourceType: String
    let company: String
    let roleTitle: String
    let location: String
    let url: URL?
    let jdText: String
    let recruiterContext: String
    let userQuestion: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sourceType = "source_type"
        case company
        case roleTitle = "role_title"
        case location
        case url
        case jdText = "jd_text"
        case recruiterContext = "recruiter_context"
        case userQuestion = "user_question"
        case createdAt = "created_at"
    }
}

struct JDInputCreate: Codable {
    let sourceType: String
    let company: String
    let roleTitle: String
    let location: String
    let url: URL?
    let jdText: String
    let recruiterContext: String
    let userQuestion: String

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case company
        case roleTitle = "role_title"
        case location
        case url
        case jdText = "jd_text"
        case recruiterContext = "recruiter_context"
        case userQuestion = "user_question"
    }
}

struct JDAnalysis: Codable {
    let roleType: String
    let matchLevel: String
    let technicalOverlap: [String]
    let redFlags: [String]
    let fatalGaps: [String]
    let trainableGaps: [String]
    let timingRecommendation: String
    let overallRecommendation: String

    enum CodingKeys: String, CodingKey {
        case roleType = "role_type"
        case matchLevel = "match_level"
        case technicalOverlap = "technical_overlap"
        case redFlags = "red_flags"
        case fatalGaps = "fatal_gaps"
        case trainableGaps = "trainable_gaps"
        case timingRecommendation = "timing_recommendation"
        case overallRecommendation = "overall_recommendation"
    }
}

struct ResumeRevisionSuggestion: Codable, Identifiable {
    let id: String
    let targetSection: String
    let currentText: String
    let suggestedText: String
    let reason: String
    let risk: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case targetSection = "target_section"
        case currentText = "current_text"
        case suggestedText = "suggested_text"
        case reason
        case risk
        case status
    }
}

struct CapabilityAction: Codable, Identifiable {
    let id: String
    let title: String
    let reason: String
    let relatedGap: String
    let suggestedTimeframe: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case reason
        case relatedGap = "related_gap"
        case suggestedTimeframe = "suggested_timeframe"
        case status
    }
}
