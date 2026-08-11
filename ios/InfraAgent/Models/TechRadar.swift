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
    let sourcePassages: [RadarSourcePassage]
    let visuals: [VisualAsset]
    let recommendedDepth: String
    let userMark: String
    let archivedAt: Date?
    let archiveNote: String
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
        case sourcePassages = "source_passages"
        case visuals
        case recommendedDepth = "recommended_depth"
        case userMark = "user_mark"
        case archivedAt = "archived_at"
        case archiveNote = "archive_note"
        case tags
    }

    init(
        id: String,
        radarType: RadarType,
        title: String,
        source: String,
        url: URL?,
        signalType: String,
        summary: String,
        technicalSubstance: String,
        marketingNoise: String,
        whyItMatters: String,
        sourcePassages: [RadarSourcePassage] = [],
        visuals: [VisualAsset],
        recommendedDepth: String,
        userMark: String,
        archivedAt: Date? = nil,
        archiveNote: String = "",
        tags: [String]
    ) {
        self.id = id
        self.radarType = radarType
        self.title = title
        self.source = source
        self.url = url
        self.signalType = signalType
        self.summary = summary
        self.technicalSubstance = technicalSubstance
        self.marketingNoise = marketingNoise
        self.whyItMatters = whyItMatters
        self.sourcePassages = sourcePassages
        self.visuals = visuals
        self.recommendedDepth = recommendedDepth
        self.userMark = userMark
        self.archivedAt = archivedAt
        self.archiveNote = archiveNote
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        radarType = try container.decode(RadarType.self, forKey: .radarType)
        title = try container.decode(String.self, forKey: .title)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        signalType = try container.decode(String.self, forKey: .signalType)
        summary = try container.decode(String.self, forKey: .summary)
        technicalSubstance = try container.decodeIfPresent(String.self, forKey: .technicalSubstance) ?? ""
        marketingNoise = try container.decodeIfPresent(String.self, forKey: .marketingNoise) ?? ""
        whyItMatters = try container.decodeIfPresent(String.self, forKey: .whyItMatters) ?? ""
        sourcePassages = try container.decodeIfPresent([RadarSourcePassage].self, forKey: .sourcePassages) ?? []
        visuals = try container.decodeIfPresent([VisualAsset].self, forKey: .visuals) ?? []
        recommendedDepth = try container.decodeIfPresent(String.self, forKey: .recommendedDepth) ?? "skim"
        userMark = try container.decodeIfPresent(String.self, forKey: .userMark) ?? "unread"
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        archiveNote = try container.decodeIfPresent(String.self, forKey: .archiveNote) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

struct RadarSourcePassage: Codable, Identifiable {
    let id: String
    let title: String
    let excerpt: String
    let analysis: String
    let sourceURL: URL?
    let location: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case excerpt
        case analysis
        case sourceURL = "source_url"
        case location
    }
}

struct RadarItemMarkRequest: Codable {
    let userMark: String
    let archiveNote: String

    enum CodingKeys: String, CodingKey {
        case userMark = "user_mark"
        case archiveNote = "archive_note"
    }
}
