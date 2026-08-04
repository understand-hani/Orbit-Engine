import Foundation

struct JDIntelligenceAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func entries() async throws -> [JDEntry] {
        try await resolvedClient.get("/api/jd/entries")
    }

    func createEntry(_ request: JDEntryCreate) async throws -> JDEntry {
        try await resolvedClient.post("/api/jd/entries", body: request)
    }

    func importImage(_ request: JDImageImportRequest) async throws -> JDImageImportResult {
        try await resolvedClient.post("/api/jd/import/image", body: request)
    }

    func entry(id: String) async throws -> JDEntry {
        try await resolvedClient.get("/api/jd/entries/\(id)")
    }

    func savePreference(entryID: String, request: JDPreferenceMarkCreate) async throws -> JDPreferenceMark {
        try await resolvedClient.post("/api/jd/entries/\(entryID)/preference", body: request)
    }

    func analyze(entryID: String) async throws -> JDFitAnalysisResult {
        try await resolvedClient.post("/api/jd/entries/\(entryID)/analyze")
    }

    func analyses(entryID: String) async throws -> [JDFitAnalysis] {
        try await resolvedClient.get("/api/jd/entries/\(entryID)/analyses")
    }

    func latestSkillSnapshot() async throws -> SkillStackSnapshot {
        try await resolvedClient.get("/api/capability/skill-snapshot/latest")
    }

    func latestTaskSnapshot() async throws -> TaskStateSnapshot {
        try await resolvedClient.get("/api/capability/task-snapshot/latest")
    }

    func actions(status: String? = nil) async throws -> [CandidateAction] {
        var queryItems: [URLQueryItem] = []
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return try await resolvedClient.get("/api/jd/actions", queryItems: queryItems)
    }

    func acceptAction(id: String, reason: String = "") async throws -> CandidateAction {
        try await resolvedClient.post(
            "/api/jd/actions/\(id)/accept",
            body: CandidateActionDecision(reason: reason, convertedTaskID: nil)
        )
    }

    func deferAction(id: String, reason: String = "") async throws -> CandidateAction {
        try await resolvedClient.post(
            "/api/jd/actions/\(id)/defer",
            body: CandidateActionDecision(reason: reason, convertedTaskID: nil)
        )
    }

    func rejectAction(id: String, reason: String = "") async throws -> CandidateAction {
        try await resolvedClient.post(
            "/api/jd/actions/\(id)/reject",
            body: CandidateActionDecision(reason: reason, convertedTaskID: nil)
        )
    }

    func convertActionToTask(id: String, reason: String = "") async throws -> CandidateAction {
        try await resolvedClient.post(
            "/api/jd/actions/\(id)/convert-to-task",
            body: CandidateActionDecision(reason: reason, convertedTaskID: nil)
        )
    }

    func discuss(messages: [JDDiscussionMessagePayload], content: String) async throws -> JDDiscussionResponse {
        try await resolvedClient.post(
            "/api/jd/discussion/messages",
            body: JDDiscussionRequest(messages: messages, content: content)
        )
    }
}
