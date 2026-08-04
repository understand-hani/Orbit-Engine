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

                ForEach(viewModel.groupedDates, id: \.self) { date in
                    let dayCheckins = viewModel.checkins(on: date)
                    NavigationLink {
                        DailyHistoryView(date: date, checkins: dayCheckins)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(date)
                                .font(.headline)
                            Text("\(dayCheckins.count) 条记录 · \(dayCheckins.reduce(0) { $0 + $1.durationMin }) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("历史")
            .task {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    HistoryView()
}
