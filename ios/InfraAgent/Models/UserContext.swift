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
    var targetCycle: String
    var fullCyclePlan: [String]
    var weeklyFocus: String
    var activeTasks: [String]
    var nextAction: String
    var trackingKeywords: [String]
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case longTermGoal = "long_term_goal"
        case targetCycle = "target_cycle"
        case fullCyclePlan = "full_cycle_plan"
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

struct DirectionProfileSuggestionRequest: Codable {
    let longTermGoal: String
    let currentDirection: String
    let currentStage: String
    let backgroundSummary: String
    let targetCycle: String
    let timeBudgetMin: Int
    let fullCyclePlan: [String]
    let weeklyFocus: String
    let activeTasks: [String]
    let nextAction: String

    enum CodingKeys: String, CodingKey {
        case longTermGoal = "long_term_goal"
        case currentDirection = "current_direction"
        case currentStage = "current_stage"
        case backgroundSummary = "background_summary"
        case targetCycle = "target_cycle"
        case timeBudgetMin = "time_budget_min"
        case fullCyclePlan = "full_cycle_plan"
        case weeklyFocus = "weekly_focus"
        case activeTasks = "active_tasks"
        case nextAction = "next_action"
    }
}

struct DirectionProfileSuggestion: Codable {
    let fullCyclePlan: [String]
    let weeklyFocus: String
    let nextAction: String
    let activeTasks: [String]
    let trackingKeywords: [String]
    let fields: [String]
    let sourcePreferences: [String]
    let constraints: [String]
    let generationMode: String?

    enum CodingKeys: String, CodingKey {
        case fullCyclePlan = "full_cycle_plan"
        case weeklyFocus = "weekly_focus"
        case nextAction = "next_action"
        case activeTasks = "active_tasks"
        case trackingKeywords = "tracking_keywords"
        case fields
        case sourcePreferences = "source_preferences"
        case constraints
        case generationMode = "generation_mode"
    }
}
