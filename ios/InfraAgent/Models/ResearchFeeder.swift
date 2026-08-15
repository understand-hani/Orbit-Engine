import Foundation

struct ResearchFeederPayload: Codable {
    let researchDayRole: String
    let researchContext: ResearchContext
    let readingPack: ReadingPack
    let papers: [Paper]
    let paperReader: PaperReader?
    let paperReaders: [PaperReader]?
    let notes: PaperNotes
    let archivePlan: ArchivePlan?
    let selectedMaterials: [ConfirmedResearchMaterial]?

    enum CodingKeys: String, CodingKey {
        case researchDayRole = "research_day_role"
        case researchContext = "research_context"
        case readingPack = "reading_pack"
        case papers
        case paperReader = "paper_reader"
        case paperReaders = "paper_readers"
        case notes
        case archivePlan = "archive_plan"
        case selectedMaterials = "selected_materials"
    }
}

struct ResearchContext: Codable {
    let currentDirection: String
    let currentTask: String
    let weekGoal: String
    let relatedProject: String

    enum CodingKeys: String, CodingKey {
        case currentDirection = "current_direction"
        case currentTask = "current_task"
        case weekGoal = "week_goal"
        case relatedProject = "related_project"
    }
}

struct ReadingPack: Codable {
    let primaryPaperID: String
    let candidatePaperID: String?
    let selectionReason: String
    let readingGoal: String
    let expectedFinishWindow: String

    enum CodingKeys: String, CodingKey {
        case primaryPaperID = "primary_paper_id"
        case candidatePaperID = "candidate_paper_id"
        case selectionReason = "selection_reason"
        case readingGoal = "reading_goal"
        case expectedFinishWindow = "expected_finish_window"
    }
}

struct Paper: Codable, Identifiable {
    let id: String
    let title: String
    let authors: [String]
    let venue: String
    let year: Int?
    let url: URL?
    let pdfURL: URL?
    let repoURL: URL?
    let summary: String
    let whySelected: String
    let visuals: [VisualAsset]
    let tags: [String]
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case authors
        case venue
        case year
        case url
        case pdfURL = "pdf_url"
        case repoURL = "repo_url"
        case summary
        case whySelected = "why_selected"
        case visuals
        case tags
        case status
    }
}

struct PaperReader: Codable {
    let paperID: String
    let pdfLocalPath: String
    let pdfURL: URL?
    let sections: [ReadingSection]
    let selectedPassages: [SelectedPassage]
    let keyFigures: [KeyFigure]
    let annotations: [PaperAnnotation]

    enum CodingKeys: String, CodingKey {
        case paperID = "paper_id"
        case pdfLocalPath = "pdf_local_path"
        case pdfURL = "pdf_url"
        case sections
        case selectedPassages = "selected_passages"
        case keyFigures = "key_figures"
        case annotations
    }
}

struct ReadingSection: Codable, Identifiable {
    let id: String
    let sectionName: String
    let pageStart: Int?
    let pageEnd: Int?
    let readMode: String
    let extractedText: String
    let whyRead: String
    let agentInstruction: String
    let knowledgePoints: [String]
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case sectionName = "section_name"
        case pageStart = "page_start"
        case pageEnd = "page_end"
        case readMode = "read_mode"
        case extractedText = "extracted_text"
        case whyRead = "why_read"
        case agentInstruction = "agent_instruction"
        case knowledgePoints = "knowledge_points"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sectionName = try container.decode(String.self, forKey: .sectionName)
        pageStart = try container.decodeIfPresent(Int.self, forKey: .pageStart)
        pageEnd = try container.decodeIfPresent(Int.self, forKey: .pageEnd)
        readMode = try container.decode(String.self, forKey: .readMode)
        extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText) ?? ""
        whyRead = try container.decode(String.self, forKey: .whyRead)
        agentInstruction = try container.decode(String.self, forKey: .agentInstruction)
        knowledgePoints = try container.decodeIfPresent([String].self, forKey: .knowledgePoints) ?? []
        status = try container.decode(String.self, forKey: .status)
    }
}

struct SelectedPassage: Codable, Identifiable {
    let id: String
    let paperID: String
    let page: Int?
    let sectionName: String
    let textExcerpt: String
    let whySelected: String
    let readingQuestion: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case paperID = "paper_id"
        case page
        case sectionName = "section_name"
        case textExcerpt = "text_excerpt"
        case whySelected = "why_selected"
        case readingQuestion = "reading_question"
        case status
    }
}

struct KeyFigure: Codable, Identifiable {
    let id: String
    let paperID: String
    let page: Int?
    let figureLabel: String
    let visual: VisualAsset
    let whyImportant: String
    let readingQuestion: String

    enum CodingKeys: String, CodingKey {
        case id
        case paperID = "paper_id"
        case page
        case figureLabel = "figure_label"
        case visual
        case whyImportant = "why_important"
        case readingQuestion = "reading_question"
    }
}

struct PaperAnnotation: Codable, Identifiable {
    let id: String
    let paperID: String
    let annotationType: String
    let page: Int?
    let sectionName: String
    let textExcerpt: String
    let comment: String
    let color: String
    let pdfQuadpoints: [Double]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case paperID = "paper_id"
        case annotationType = "annotation_type"
        case page
        case sectionName = "section_name"
        case textExcerpt = "text_excerpt"
        case comment
        case color
        case pdfQuadpoints = "pdf_quadpoints"
        case createdAt = "created_at"
    }
}

struct PaperNotes: Codable {
    let inputOutput: String
    let problemDefinition: String
    let coreIdea: String
    let trainingOrInferenceLogic: String
    let evidence: String
    let limitations: String
    let relationToMyPlan: String
    let usableFor: [String]
    let continueOrDrop: String
    let nextAction: String

    enum CodingKeys: String, CodingKey {
        case inputOutput = "input_output"
        case problemDefinition = "problem_definition"
        case coreIdea = "core_idea"
        case trainingOrInferenceLogic = "training_or_inference_logic"
        case evidence
        case limitations
        case relationToMyPlan = "relation_to_my_plan"
        case usableFor = "usable_for"
        case continueOrDrop = "continue_or_drop"
        case nextAction = "next_action"
    }
}

struct ArchivePlan: Codable {
    let targetArchive: [String]
    let tags: [String]
    let summaryMD: String

    enum CodingKeys: String, CodingKey {
        case targetArchive = "target_archive"
        case tags
        case summaryMD = "summary_md"
    }
}

struct ResearchMaterialSearchRequest: Codable {
    let query: String
    let note: String
}
