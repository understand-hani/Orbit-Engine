import Combine
import Foundation

@MainActor
final class JDIntelligenceViewModel: ObservableObject {
    @Published private(set) var entries: [JDEntry] = []
    @Published private(set) var actions: [CandidateAction] = []
    @Published private(set) var skillSnapshot: SkillStackSnapshot?
    @Published private(set) var taskSnapshot: TaskStateSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: JDIntelligenceAPI

    init(api: JDIntelligenceAPI = JDIntelligenceAPI()) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            entries = LocalJDPreferenceStore.apply(to: try await api.entries())
            actions = LocalCandidateActionDecisionStore.apply(to: try await api.actions())
            skillSnapshot = try await api.latestSkillSnapshot()
            taskSnapshot = try await api.latestTaskSnapshot()
            errorMessage = nil
        } catch {
            entries = LocalJDPreferenceStore.apply(to: MockJDIntelligence.entries)
            actions = LocalCandidateActionDecisionStore.apply(to: MockJDIntelligence.actions)
            skillSnapshot = MockJDIntelligence.skillSnapshot
            taskSnapshot = MockJDIntelligence.taskSnapshot
            errorMessage = "Using local mock data: \(error.localizedDescription)"
        }
    }

    func createEntry(_ request: JDEntryCreate) async -> JDEntry? {
        do {
            let entry = try await api.createEntry(request)
            await load()
            return entry
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    var favoriteEntries: [JDEntry] {
        entries.filter { LocalJDPreferenceStore.isFavorite($0) }
    }

    var suggestedActions: [CandidateAction] {
        actions.filter { $0.status == "suggested" }
    }

    var highPriorityEntries: [JDEntry] {
        entries.filter { $0.applicationPriority == "high" }
    }
}
