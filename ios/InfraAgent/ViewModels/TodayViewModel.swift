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
    @Published private(set) var userContext: UserContext?
    @Published private(set) var healthStatus: String = "API 未验证"
    @Published private(set) var state: LoadState = .idle
    @Published var mode: TodayMode = .scheduled

    private let sessionAPI: SessionAPI
    private let contextAPI: UserContextAPI
    private let healthAPI: HealthAPI

    init(
        sessionAPI: SessionAPI = SessionAPI(),
        contextAPI: UserContextAPI = UserContextAPI(),
        healthAPI: HealthAPI = HealthAPI()
    ) {
        self.sessionAPI = sessionAPI
        self.contextAPI = contextAPI
        self.healthAPI = healthAPI
    }

    func loadToday() async {
        state = .loading
        await refreshContext()
        do {
            session = try await sessionAPI.today()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func selectMode(_ mode: TodayMode) async {
        self.mode = mode
        if mode == .scheduled {
            await loadToday()
        }
    }

    func loadManual(_ entry: ManualSessionEntry) async {
        mode = .manual
        state = .loading
        await refreshContext()
        do {
            session = try await sessionAPI.mock(date: entry.date, taskType: entry.taskTypeOverride)
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

    private func refreshContext() async {
        do {
            let health = try await healthAPI.health()
            healthStatus = health.status.uppercased()
        } catch {
            healthStatus = "API 失败"
        }

        do {
            userContext = try await contextAPI.get()
        } catch {
            userContext = nil
        }
    }
}

enum TodayMode: String, CaseIterable, Identifiable {
    case scheduled = "Scheduled"
    case manual = "Manual"

    var id: String { rawValue }
}

struct ManualSessionEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let date: String
    let taskTypeOverride: TaskType?

    static var all: [ManualSessionEntry] {
        [
        ManualSessionEntry(
            id: "radar",
            title: "Radar",
            subtitle: "发现趋势、信号、机会和外部变化。",
            systemImage: "dot.radiowaves.left.and.right",
            date: "2026-08-04",
            taskTypeOverride: nil
        ),
        ManualSessionEntry(
            id: "deep_dive",
            title: "Deep Dive",
            subtitle: "围绕一个材料完成深入阅读和小产出。",
            systemImage: "doc.text.magnifyingglass",
            date: todayString(),
            taskTypeOverride: .researchFeeder
        ),
        ManualSessionEntry(
            id: "weekly_studio",
            title: "Weekly Studio",
            subtitle: "复盘、归档、更新计划并准备下一轮。",
            systemImage: "calendar.badge.clock",
            date: "2026-08-09",
            taskTypeOverride: nil
        ),
        ManualSessionEntry(
            id: "opportunity_alignment",
            title: "Opportunity Alignment",
            subtitle: "把学习行动和真实机会、要求、反馈对齐。",
            systemImage: "scope",
            date: "2026-08-05",
            taskTypeOverride: nil
        ),
        ]
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct HealthAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func health() async throws -> HealthResponse {
        try await resolvedClient.get("/api/health")
    }
}

struct HealthResponse: Codable {
    let status: String
    let app: String
    let env: String
}
