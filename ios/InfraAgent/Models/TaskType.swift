import Foundation

enum TaskType: String, Codable, CaseIterable {
    case techRadar = "tech_radar"
    case jdAnalysis = "jd_analysis"
    case researchFeeder = "research_feeder"
}

enum SessionMode: String, Codable {
    case scheduled
    case manual
    case catchUp = "catch_up"
    case review
}

enum SessionStatus: String, Codable {
    case draft
    case active
    case completed
    case partial
    case skipped
    case archived
}

enum SuggestedAction: String, Codable {
    case generateWeeklyRadar = "generate_weekly_radar"
    case openWeeklyRadar = "open_weekly_radar"
    case discussSignal = "discuss_signal"
    case markRadarDone = "mark_radar_done"
    case addJDInput = "add_jd_input"
    case analyzeJD = "analyze_jd"
    case openAnalysisReport = "open_analysis_report"
    case reviseResume = "revise_resume"
    case openGapPlan = "open_gap_plan"
    case markJDDone = "mark_jd_done"
    case generateReadingPack = "generate_reading_pack"
    case openPaperReader = "open_paper_reader"
    case continueReading = "continue_reading"
    case editNotes = "edit_notes"
    case archivePaper = "archive_paper"
    case markResearchDone = "mark_research_done"
}

enum VisualType: String, Codable {
    case image
    case video
    case pdfFigure = "pdf_figure"
    case chart
    case screenshot
    case table
}

enum VisualUsage: String, Codable {
    case cover
    case evidence
    case methodFigure = "method_figure"
    case productScreenshot = "product_screenshot"
    case architecture
    case benchmark
    case teaser
    case chart
}

struct VisualAsset: Codable, Identifiable, Hashable {
    let id: String
    let type: VisualType
    let url: URL?
    let localPath: String
    let caption: String
    let source: String
    let usage: VisualUsage

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case localPath = "local_path"
        case caption
        case source
        case usage
    }
}
