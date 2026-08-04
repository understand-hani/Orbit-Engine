import Foundation

struct SessionAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func today(date: String? = nil) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/today", queryItems: dateQuery(date))
    }

    func preview(date: String? = nil) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/preview", queryItems: dateQuery(date))
    }

    func mock(date: String? = nil) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/mock", queryItems: dateQuery(date))
    }

    func generateAndSaveMock(date: String? = nil) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/mock", queryItems: dateQuery(date))
    }

    func sessionsByDate(_ date: String) async throws -> [BaseSession] {
        try await resolvedClient.get("/api/sessions/by-date", queryItems: [URLQueryItem(name: "date", value: date)])
    }

    func session(id: String) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/\(id)")
    }

    func analyzeJD(sessionID: String, request: JDInputCreate) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/\(sessionID)/jd-analysis", body: request)
    }

    private func dateQuery(_ date: String?) -> [URLQueryItem] {
        guard let date else { return [] }
        return [URLQueryItem(name: "date", value: date)]
    }
}
