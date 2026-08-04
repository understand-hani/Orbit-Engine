import SwiftUI

struct InboxView: View {
    @StateObject private var viewModel = InboxViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("模式") {
                    Picker("模式", selection: $viewModel.mode) {
                        ForEach(InboxViewModel.InboxMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.mode == .catchUp {
                    Section("补看") {
                        DatePicker("日期", selection: $viewModel.selectedDate, displayedComponents: .date)
                        Button {
                            Task { await viewModel.loadCatchUpSessions() }
                        } label: {
                            Label("加载日期", systemImage: "calendar")
                        }
                        Button {
                            Task { await viewModel.generateForSelectedDate() }
                        } label: {
                            Label("为该日期生成", systemImage: "wand.and.stars")
                        }
                    }
                } else {
                    Section("今日") {
                        Button {
                            Task { await viewModel.generateToday() }
                        } label: {
                            Label("生成今日材料", systemImage: "tray.and.arrow.down")
                        }
                    }
                }

                if viewModel.isLoading {
                    LoadingView(title: "正在加载材料")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                    }
                }

                Section("任务") {
                    ForEach(viewModel.sessions) { session in
                        NavigationLink {
                            SessionDestinationView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.title)
                                    .font(.headline)
                                Text(session.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TagRow(tags: [session.date, session.weekday, session.taskType.rawValue])
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("收件箱")
        }
    }
}

#Preview {
    InboxView()
}
