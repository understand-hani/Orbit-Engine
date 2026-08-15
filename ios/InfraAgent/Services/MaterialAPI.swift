import Foundation

struct MaterialAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func radarItems(sessionID: String) async throws -> [RadarItem] {
        try await resolvedClient.get("/api/sessions/\(sessionID)/radar-items")
    }

    func markRadarItem(sessionID: String, itemID: String, mark: String, archiveNote: String = "") async throws -> RadarItem {
        try await resolvedClient.post(
            "/api/sessions/\(sessionID)/radar-items/\(itemID)/mark",
            body: RadarItemMarkRequest(userMark: mark, archiveNote: archiveNote)
        )
    }

    func generateRadarItemJudgement(sessionID: String, itemID: String) async throws -> RadarItem {
        try await resolvedClient.post("/api/sessions/\(sessionID)/radar-items/\(itemID)/judgement")
    }

    func archiveRadarItem(sessionID: String, itemID: String, archiveNote: String = "") async throws -> RadarItem {
        try await resolvedClient.post(
            "/api/sessions/\(sessionID)/radar-items/\(itemID)/archive",
            body: RadarItemMarkRequest(userMark: "archived", archiveNote: archiveNote)
        )
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
