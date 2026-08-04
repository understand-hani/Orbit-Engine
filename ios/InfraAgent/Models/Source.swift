import Foundation

struct SourceItem: Codable, Identifiable {
    let id: String
    let source: String
    let itemType: String
    let title: String
    let url: URL?
    let summary: String
    let authors: [String]
    let publishedAt: Date?
    let updatedAt: Date?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case itemType = "item_type"
        case title
        case url
        case summary
        case authors
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
        case tags
    }
}

struct SourceSearchResponse: Codable {
    let query: String
    let source: String
    let items: [SourceItem]
    let fetchedAt: Date

    enum CodingKeys: String, CodingKey {
        case query
        case source
        case items
        case fetchedAt = "fetched_at"
    }
}

struct CombinedSearchResponse: Codable {
    let query: String
    let items: [SourceItem]
    let fetchedAt: Date

    enum CodingKeys: String, CodingKey {
        case query
        case items
        case fetchedAt = "fetched_at"
    }
}
