import Foundation

struct UserContextAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func get() async throws -> UserContext {
        try await resolvedClient.get("/api/user-context")
    }

    func save(_ context: UserContext) async throws -> UserContext {
        try await resolvedClient.put("/api/user-context", body: context)
    }

    func suggestDirection(_ request: DirectionProfileSuggestionRequest) async throws -> DirectionProfileSuggestion {
        try await resolvedClient.post("/api/user-context/direction/suggest", body: request)
    }
}
