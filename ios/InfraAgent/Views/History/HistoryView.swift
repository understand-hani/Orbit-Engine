import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    LoadingView(title: "正在加载记录")
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }

                Section("归档记录") {
                    ForEach(viewModel.groupedDates, id: \.self) { date in
                        let dayCheckins = viewModel.checkins(on: date)
                        NavigationLink {
                            DailyHistoryView(
                                date: date,
                                checkins: dayCheckins,
                                sessionTitlesByID: viewModel.archivedSessionsByID.mapValues { $0.title }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(date)
                                    .font(.headline)
                                Text("\(dayCheckins.count) 条归档 · \(dayCheckins.reduce(0) { $0 + $1.durationMin }) 分钟")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("暂存") {
                    if viewModel.archivedCheckins.isEmpty {
                        EmptyStateView(
                            title: "暂无暂存工作区",
                            systemImage: "archivebox",
                            message: "以后不想立刻做、但还可能继续的 Deep Dive 或 Signal Radar 信号会先放在这里。"
                        )
                    } else {
                        ForEach(viewModel.archivedCheckins) { checkin in
                            NavigationLink {
                                CheckinDetailView(
                                    checkin: checkin,
                                    sessionTitle: viewModel.archivedSessionTitle(for: checkin)
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(archivedTitle(for: checkin))
                                        .font(.headline)
                                    Text("\(checkin.date) · \(checkin.taskType.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteArchivedCheckin(checkin) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    Task { await viewModel.restoreArchivedCheckin(checkin) }
                                } label: {
                                    Label("恢复", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("归档")
            .task {
                await viewModel.load()
            }
        }
    }

    private func archivedTitle(for checkin: Checkin) -> String {
        if let sessionTitle = nonEmpty(viewModel.archivedSessionTitle(for: checkin)) {
            return sessionTitle
        }

        let displayDate = checkin.date.replacingOccurrences(of: "-", with: "/")
        let prefix = checkin.taskType == .techRadar
            ? "Signal Radar-\(displayDate)-No."
            : "Deep Dive-\(displayDate)-No."
        let legacySessionPrefix = "Deep Dive-\(checkin.date)-"
        if checkin.summary.contains(prefix),
           let range = checkin.summary.range(of: prefix) {
            return String(checkin.summary[range.lowerBound...])
        }
        if checkin.summary.contains(legacySessionPrefix),
           let range = checkin.summary.range(of: legacySessionPrefix) {
            return String(checkin.summary[range.lowerBound...])
                .replacingOccurrences(of: legacySessionPrefix, with: prefix)
        }
        return nonEmpty(checkin.sourceTitle) ?? "\(prefix)1"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

#Preview {
    HistoryView()
}
