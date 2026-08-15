import Foundation

struct SessionAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func today(date: String? = nil) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/today", queryItems: dateQuery(date))
    }

    func preview(date: String? = nil, taskType: TaskType? = nil) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/preview", queryItems: sessionQuery(date: date, taskType: taskType))
    }

    func mock(date: String? = nil, taskType: TaskType? = nil, weeklyStudio: Bool = false) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/mock", queryItems: sessionQuery(date: date, taskType: taskType, weeklyStudio: weeklyStudio))
    }

    func generateAndSaveMock(date: String? = nil, taskType: TaskType? = nil, weeklyStudio: Bool = false) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/mock", queryItems: sessionQuery(date: date, taskType: taskType, weeklyStudio: weeklyStudio))
    }

    func sessionsByDate(_ date: String) async throws -> [BaseSession] {
        try await resolvedClient.get("/api/sessions/by-date", queryItems: [URLQueryItem(name: "date", value: date)])
    }

    func session(id: String) async throws -> BaseSession {
        try await resolvedClient.get("/api/sessions/\(id)")
    }

    func delete(id: String) async throws {
        try await resolvedClient.postNoContent("/api/sessions/\(id)/delete")
    }

    func archive(id: String) async throws {
        try await resolvedClient.postNoContent("/api/sessions/\(id)/archive")
    }

    func restore(id: String) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/\(id)/restore")
    }

    func rename(id: String, suffix: String) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/\(id)/rename", body: SessionRenameRequest(suffix: suffix))
    }

    func refreshRadar(sessionID: String) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/\(sessionID)/radar/refresh")
    }

    func saveSelectedResearchMaterials(
        sessionID: String,
        materials: [ConfirmedResearchMaterial]
    ) async throws -> BaseSession {
        try await resolvedClient.post(
            "/api/sessions/\(sessionID)/research/selected-materials",
            body: materials
        )
    }

    func refreshResearchMaterials(
        sessionID: String,
        query: String,
        note: String
    ) async throws -> BaseSession {
        try await resolvedClient.post(
            "/api/sessions/\(sessionID)/research/materials/refresh",
            timeoutInterval: 75,
            body: ResearchMaterialSearchRequest(query: query, note: note)
        )
    }

    func draftWeeklyStudio(sessionID: String) async throws -> WeeklyStudioDraftResponse {
        try await resolvedClient.post("/api/sessions/\(sessionID)/weekly-studio/draft")
    }

    func analyzeJD(sessionID: String, request: JDInputCreate) async throws -> BaseSession {
        try await resolvedClient.post("/api/sessions/\(sessionID)/jd-analysis", body: request)
    }

    private func dateQuery(_ date: String?) -> [URLQueryItem] {
        guard let date else { return [] }
        return [URLQueryItem(name: "date", value: date)]
    }

    private func sessionQuery(date: String?, taskType: TaskType?, weeklyStudio: Bool = false) -> [URLQueryItem] {
        var items = dateQuery(date)
        if let taskType {
            items.append(URLQueryItem(name: "task_type", value: taskType.rawValue))
        }
        if weeklyStudio {
            items.append(URLQueryItem(name: "weekly_studio", value: "true"))
        }
        return items
    }
}

private struct SessionRenameRequest: Encodable {
    let suffix: String
}
