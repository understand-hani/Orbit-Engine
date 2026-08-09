import Foundation

struct UserContext: Codable {
    var profile: PersonalProfileContext
    var plan: WorkLearningPlanContext
    var preferences: UserPreferenceContext
    var materials: [UserMaterialContext]
}

struct PersonalProfileContext: Codable {
    var id: String
    var displayName: String
    var goal: String
    var backgroundSummary: String
    var currentStage: String
    var constraints: [String]
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case goal
        case backgroundSummary = "background_summary"
        case currentStage = "current_stage"
        case constraints
        case updatedAt = "updated_at"
    }
}

struct WorkLearningPlanContext: Codable {
    var id: String
    var longTermGoal: String
    var weeklyFocus: String
    var activeTasks: [String]
    var nextAction: String
    var trackingKeywords: [String]
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case longTermGoal = "long_term_goal"
        case weeklyFocus = "weekly_focus"
        case activeTasks = "active_tasks"
        case nextAction = "next_action"
        case trackingKeywords = "tracking_keywords"
        case updatedAt = "updated_at"
    }
}

struct UserPreferenceContext: Codable {
    var id: String
    var fields: [String]
    var sourcePreferences: [String]
    var sessionTimeBudgetMin: Int
    var language: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fields
        case sourcePreferences = "source_preferences"
        case sessionTimeBudgetMin = "session_time_budget_min"
        case language
        case updatedAt = "updated_at"
    }
}

struct UserMaterialContext: Codable, Identifiable {
    var id: String
    var title: String
    var sourceType: String
    var summary: String
    var url: URL?
    var filePath: String
    var authorsOrOwner: [String]
    var publishedDate: String
    var tags: [String]
    var relatedPlan: String
    var whySelected: String
    var fetchedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceType = "source_type"
        case summary
        case url
        case filePath = "file_path"
        case authorsOrOwner = "authors_or_owner"
        case publishedDate = "published_date"
        case tags
        case relatedPlan = "related_plan"
        case whySelected = "why_selected"
        case fetchedAt = "fetched_at"
    }
}
