import Foundation

struct ResumeProfile: Codable, Identifiable {
    let id: String
    let version: String
    let basicProfile: [String: String]
    let education: [[String: String]]
    let workExperience: [[String: String]]
    let projects: [[String: String]]
    let skills: [[String: String]]
    let papers: [[String: String]]
    let openSource: [[String: String]]
    let targetVersions: [[String: String]]
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case version
        case basicProfile = "basic_profile"
        case education
        case workExperience = "work_experience"
        case projects
        case skills
        case papers
        case openSource = "open_source"
        case targetVersions = "target_versions"
        case updatedAt = "updated_at"
    }
}

struct ResearchArchive: Codable, Identifiable {
    let id: String
    let paperID: String
    let noteID: String
    let tags: [String]
    let usableFor: [String]
    let summaryMD: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case paperID = "paper_id"
        case noteID = "note_id"
        case tags
        case usableFor = "usable_for"
        case summaryMD = "summary_md"
        case createdAt = "created_at"
    }
}
