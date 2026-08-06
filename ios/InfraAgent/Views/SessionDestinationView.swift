import SwiftUI

struct SessionQueueView: View {
    let seedSession: BaseSession

    @State private var sessions: [BaseSession] = []
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let sessionAPI = SessionAPI()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sessionDisplayTitle(seedSession))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("管理当前未完成的 \(sessionDisplayTitle(seedSession))，或新建一个同类型工作区。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            Section("进行中 / 未完成") {
                if activeSessions.isEmpty {
                    EmptyStateView(
                        title: "暂无未完成工作区",
                        systemImage: "tray",
                        message: "已完成的记录会进入历史栏目。"
                    )
                } else {
                    ForEach(activeSessions) { session in
                        NavigationLink {
                            SessionDestinationView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(session.title)
                                    .font(.headline)
                                Text(session.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                TagRow(tags: [session.date, sessionDisplayType(session), session.status.rawValue])
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section("新建") {
                Button {
                    Task { await createSession() }
                } label: {
                    if isCreating {
                        Label("正在新建", systemImage: "hourglass")
                    } else {
                        Label("新建 \(sessionDisplayTitle(seedSession))", systemImage: "plus.circle")
                    }
                }
                .disabled(isCreating)

                Text("当前版本先复用后端 mock session 生成同类工作区；真实多实例列表将在后端增加按类型和状态查询后接入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(sessionDisplayTitle(seedSession))
        .onAppear {
            if sessions.isEmpty {
                sessions = [seedSession]
            }
        }
    }

    private func createSession() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let date = nextManualDate(existingCount: sessions.count)
            let session = try await sessionAPI.generateAndSaveMock(date: date)
            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.insert(session, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nextManualDate(existingCount: Int) -> String {
        let dates = manualDates(for: seedSession)
        return dates[min(existingCount, dates.count - 1)]
    }

    private var activeSessions: [BaseSession] {
        sessions.filter { $0.status != .completed && $0.status != .archived }
    }
}

struct SessionDestinationView: View {
    let session: BaseSession

    var body: some View {
        switch session.payload {
        case .techRadar(let payload):
            TechRadarView(session: session, payload: payload)
        case .jdAnalysis:
            JDIntelligenceView()
        case .researchFeeder(let payload):
            ResearchReaderView(session: session, payload: payload)
        }
    }
}

private func sessionDisplayTitle(_ session: BaseSession) -> String {
    switch session.taskType {
    case .techRadar:
        return "Radar"
    case .researchFeeder:
        if session.date == "2026-08-09" || session.date == "2026-08-16" {
            return "Weekly Studio"
        }
        return "Deep Dive"
    case .jdAnalysis:
        return "Opportunity Alignment"
    }
}

private func sessionDisplayType(_ session: BaseSession) -> String {
    switch session.taskType {
    case .techRadar:
        return "radar"
    case .researchFeeder:
        if session.date == "2026-08-09" || session.date == "2026-08-16" {
            return "weekly_studio"
        }
        return "deep_dive"
    case .jdAnalysis:
        return "opportunity_alignment"
    }
}

private func manualDates(for session: BaseSession) -> [String] {
    switch session.taskType {
    case .techRadar:
        return ["2026-08-04", "2026-08-10", "2026-08-11"]
    case .jdAnalysis:
        return ["2026-08-05", "2026-08-12"]
    case .researchFeeder:
        if session.date == "2026-08-09" || session.date == "2026-08-16" {
            return ["2026-08-09", "2026-08-16"]
        }
        return ["2026-08-06", "2026-08-07", "2026-08-13", "2026-08-14"]
    }
}
