import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("打开今天的固定任务，生成材料，并记录完成情况。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                switch viewModel.state {
                case .idle:
                    Section("任务") {
                        Button {
                            Task { await viewModel.loadToday() }
                        } label: {
                            Label("加载今日任务", systemImage: "arrow.clockwise")
                        }
                    }
                case .loading:
                    Section {
                        LoadingView(title: "正在加载任务")
                    }
                case .failed(let message):
                    Section {
                        ErrorBanner(message: message)
                        Button("重试") {
                            Task { await viewModel.loadToday() }
                        }
                    }
                case .loaded:
                    if let session = viewModel.session {
                        Section("任务") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.title)
                                    .font(.headline)
                                Text(session.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TagRow(tags: [session.weekday, session.taskType.rawValue, session.status.rawValue])
                            }
                            .padding(.vertical, 4)

                            NavigationLink {
                                SessionDestinationView(session: session)
                            } label: {
                                Label("打开工作区", systemImage: "rectangle.grid.2x2")
                            }
                        }
                    }
                }

                Section("操作") {
                    Button {
                        Task { await viewModel.generateMock() }
                    } label: {
                        Label("生成 Mock 任务", systemImage: "wand.and.stars")
                    }
                }
            }
            .navigationTitle("Infra Agent")
            .task {
                if case .idle = viewModel.state {
                    await viewModel.loadToday()
                }
            }
        }
    }
}

#Preview {
    TodayView()
}
