import Foundation

struct MaterialAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func radarItems(sessionID: String) async throws -> [RadarItem] {
        try await resolvedClient.get("/api/sessions/\(sessionID)/radar-items")
    }

    func papers(sessionID: String) async throws -> [Paper] {
        try await resolvedClient.get("/api/sessions/\(sessionID)/papers")
    }

    func paper(sessionID: String, paperID: String) async throws -> Paper {
        try await resolvedClient.get("/api/sessions/\(sessionID)/papers/\(paperID)")
    }

    func paperReader(sessionID: String) async throws -> PaperReader {
        try await resolvedClient.get("/api/sessions/\(sessionID)/paper-reader")
    }
}
