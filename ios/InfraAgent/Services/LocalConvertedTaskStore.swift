import Foundation

enum LocalConvertedTaskStore {
    private static let key = "jd_converted_candidate_actions"

    static func add(_ action: CandidateAction, note: String) {
        var actions = loadActions()
        actions.removeAll { $0.id == action.id }
        actions.append(action.withConvertedStatus(note: note))
        save(actions)
    }

    static func taskProfiles() -> [TaskProfile] {
        loadActions().map { action in
            TaskProfile(
                id: "converted_\(action.id)",
                title: action.title,
                category: "jd_follow_up",
                status: "planned",
                currentPhase: action.suggestedSlot.isEmpty ? "Candidate action converted from JD analysis" : action.suggestedSlot,
                relatedSkillIDs: action.relatedSkillIDs,
                deadline: nil,
                weeklySlot: action.suggestedSlot,
                progressSummary: action.reason,
                blockers: [],
                nextMilestone: action.expectedOutput,
                evidenceOutputs: action.expectedOutput.isEmpty ? [] : [action.expectedOutput],
                adjustability: "medium"
            )
        }
    }

    private static func loadActions() -> [CandidateAction] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CandidateAction].self, from: data)) ?? []
    }

    private static func save(_ actions: [CandidateAction]) {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
