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

                Section("暂存") {
                    if viewModel.archivedCheckins.isEmpty {
                        EmptyStateView(
                            title: "暂无暂存工作区",
                            systemImage: "archivebox",
                            message: "以后不想立刻做、但还可能继续的 Deep Dive 会先放在这里。"
                        )
                    } else {
                        ForEach(viewModel.archivedCheckins) { checkin in
                            NavigationLink {
                                CheckinDetailView(checkin: checkin)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(checkin.summary)
                                        .font(.headline)
                                    Text("\(checkin.date) · \(checkin.taskType.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("归档记录") {
                    ForEach(viewModel.groupedDates, id: \.self) { date in
                        let dayCheckins = viewModel.checkins(on: date)
                        NavigationLink {
                            DailyHistoryView(date: date, checkins: dayCheckins)
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
            }
            .navigationTitle("归档")
            .task {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    HistoryView()
}
