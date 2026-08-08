import Foundation

struct CheckinAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func create(_ request: CheckinCreate) async throws -> Checkin {
        try await resolvedClient.post("/api/checkins", body: request)
    }

    func list(date: String? = nil) async throws -> [Checkin] {
        var queryItems: [URLQueryItem] = []
        if let date {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        return try await resolvedClient.get("/api/checkins", queryItems: queryItems)
    }

    func get(id: String) async throws -> Checkin {
        try await resolvedClient.get("/api/checkins/\(id)")
    }

    func delete(id: String) async throws {
        try await resolvedClient.delete("/api/checkins/\(id)")
    }

    func confirmCompletion(sessionID: String, request: CompletionConfirmRequest) async throws -> CompletionConfirmResponse {
        try await resolvedClient.post("/api/sessions/\(sessionID)/completion/confirm", body: request)
    }

    func draftCompletion(sessionID: String, request: CompletionDraftRequest) async throws -> CompletionDraftResponse {
        try await resolvedClient.post("/api/sessions/\(sessionID)/completion/draft", body: request)
    }
}
