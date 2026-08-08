import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var checkins: [Checkin] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let checkinAPI: CheckinAPI
    private let sessionAPI: SessionAPI

    init(checkinAPI: CheckinAPI = CheckinAPI(), sessionAPI: SessionAPI = SessionAPI()) {
        self.checkinAPI = checkinAPI
        self.sessionAPI = sessionAPI
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

    func deleteArchivedCheckin(_ checkin: Checkin) async {
        do {
            try await sessionAPI.delete(id: checkin.sessionID)
            try await checkinAPI.delete(id: checkin.id)
            checkins.removeAll { $0.id == checkin.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreArchivedCheckin(_ checkin: Checkin) async {
        do {
            _ = try await sessionAPI.restore(id: checkin.sessionID)
            try await checkinAPI.delete(id: checkin.id)
            checkins.removeAll { $0.id == checkin.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var timelineCheckins: [Checkin] {
        checkins.filter { $0.status == "completed" }
    }
}
