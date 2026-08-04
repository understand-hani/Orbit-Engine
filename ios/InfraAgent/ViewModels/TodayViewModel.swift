import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    enum LoadState {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var session: BaseSession?
    @Published private(set) var state: LoadState = .idle

    private let sessionAPI: SessionAPI

    init(sessionAPI: SessionAPI = SessionAPI()) {
        self.sessionAPI = sessionAPI
    }

    func loadToday() async {
        state = .loading
        do {
            session = try await sessionAPI.today()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func generateMock() async {
        state = .loading
        do {
            session = try await sessionAPI.generateAndSaveMock()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
