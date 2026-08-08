import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var checkins: [Checkin] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let checkinAPI: CheckinAPI

    init(checkinAPI: CheckinAPI = CheckinAPI()) {
        self.checkinAPI = checkinAPI
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            checkins = try await checkinAPI.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var archivedCheckins: [Checkin] {
        checkins
            .filter { $0.status == "archived" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var groupedDates: [String] {
        Dictionary(grouping: timelineCheckins, by: \.date)
            .keys
            .sorted(by: >)
    }

    func checkins(on date: String) -> [Checkin] {
        timelineCheckins
            .filter { $0.date == date }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var timelineCheckins: [Checkin] {
        checkins.filter { $0.status != "archived" }
    }
}
