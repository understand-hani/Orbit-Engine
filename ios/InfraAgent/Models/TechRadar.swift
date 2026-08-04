import Foundation

enum RadarType: String, Codable {
    case productStrategyRadar = "product_strategy_radar"
    case technicalMethodRadar = "technical_method_radar"
}

struct TechRadarPayload: Codable {
    let radarType: RadarType
    let scope: RadarScope
    let generationMode: String
    let sourceRefreshTime: Date?
    let isStale: Bool
    let digest: RadarDigest

    enum CodingKeys: String, CodingKey {
        case radarType = "radar_type"
        case scope
        case generationMode = "generation_mode"
        case sourceRefreshTime = "source_refresh_time"
        case isStale = "is_stale"
        case digest
    }
}

struct RadarScope: Codable {
    let topics: [String]
    let companies: [String]
    let researchGroups: [String]
    let signalTypes: [String]
    let exclude: [String]

    enum CodingKeys: String, CodingKey {
        case topics
        case companies
        case researchGroups = "research_groups"
        case signalTypes = "signal_types"
        case exclude
    }
}

struct RadarDigest: Codable {
    let weekStart: String
    let weekEnd: String
    let summary: String
    let items: [RadarItem]
    let topSignals: [String]
    let noiseFiltered: [String]
    let followUpQuestions: [String]

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case summary
        case items
        case topSignals = "top_signals"
        case noiseFiltered = "noise_filtered"
        case followUpQuestions = "follow_up_questions"
    }
}

struct RadarItem: Codable, Identifiable {
    let id: String
    let radarType: RadarType
    let title: String
    let source: String
    let url: URL?
    let signalType: String
    let summary: String
    let technicalSubstance: String
    let marketingNoise: String
    let whyItMatters: String
    let visuals: [VisualAsset]
    let recommendedDepth: String
    let userMark: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case radarType = "radar_type"
        case title
        case source
        case url
        case signalType = "signal_type"
        case summary
        case technicalSubstance = "technical_substance"
        case marketingNoise = "marketing_noise"
        case whyItMatters = "why_it_matters"
        case visuals
        case recommendedDepth = "recommended_depth"
        case userMark = "user_mark"
        case tags
    }
}
