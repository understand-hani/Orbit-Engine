import Combine
import Foundation

@MainActor
final class InboxViewModel: ObservableObject {
    enum InboxMode: String, CaseIterable, Identifiable {
        case catchUp = "补看"
        case today = "今日"

        var id: String { rawValue }
    }

    @Published var mode: InboxMode = .catchUp
    @Published var selectedDate = Date()
    @Published private(set) var sessions: [BaseSession] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let sessionAPI: SessionAPI
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(sessionAPI: SessionAPI = SessionAPI()) {
        self.sessionAPI = sessionAPI
    }

    func loadCatchUpSessions() async {
        let date = dateFormatter.string(from: selectedDate)
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await sessionAPI.sessionsByDate(date)
            errorMessage = sessions.isEmpty ? "这个日期没有任务。需要补看时可以先生成一个。" : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateForSelectedDate() async {
        let date = mode == .today ? nil : dateFormatter.string(from: selectedDate)
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await sessionAPI.generateAndSaveMock(date: date)
            sessions = [session]
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateToday() async {
        mode = .today
        await generateForSelectedDate()
    }
}
