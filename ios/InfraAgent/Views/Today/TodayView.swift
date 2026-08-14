import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("今日")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(viewModel.healthStatus)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }

                        Text("选择今天的固定 session，或手动启动一个工作区。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Picker("模式", selection: $viewModel.mode) {
                        ForEach(TodayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.mode) { newValue in
                        Task { await viewModel.selectMode(newValue) }
                    }
                }

                if let context = viewModel.userContext {
                    Section("计划上下文") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(context.plan.weeklyFocus)
                                .font(.subheadline)
                            Text(context.plan.nextAction)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TagRow(tags: Array(context.plan.trackingKeywords.prefix(3)))
                        }
                        .padding(.vertical, 4)
                    }
                }

                if viewModel.mode == .manual {
                    Section("Manual") {
                        ForEach(ManualSessionEntry.all) { entry in
                            if entry.opensDirectly {
                                NavigationLink {
                                    JDIntelligenceView()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: entry.systemImage)
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.title)
                                                .font(.headline)
                                            Text(entry.subtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            } else {
                                Button {
                                    Task { await viewModel.loadManual(entry) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: entry.systemImage)
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(entry.subtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                if viewModel.mode == .scheduled {
                    Section("Scheduled") {
                        Text("默认根据日期读取后端推荐的今日 session。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
                    if let session = viewModel.session, isActive(session) {
                        Section("今日工作区") {
                            NavigationLink {
                                if session.taskType == .jdAnalysis {
                                    JDIntelligenceView()
                                } else {
                                    SessionQueueView(seedSession: session)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(displayTitle(for: session))
                                        .font(.headline)
                                    Text(session.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                    TagRow(tags: [session.weekday, displayTaskType(for: session), session.status.rawValue])
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        Section("今日工作区") {
                            EmptyStateView(
                                title: "暂无今日工作区",
                                systemImage: "tray",
                                message: "已丢弃、已暂存或已完成的任务不会在 Today 中重复出现。"
                            )
                        }
                    }
                }
            }
            .navigationTitle("圆周引擎")
            .task {
                if case .idle = viewModel.state {
                    await viewModel.loadToday()
                }
            }
            .onAppear {
                if viewModel.mode == .scheduled {
                    Task { await viewModel.loadToday() }
                }
            }
        }
    }

    private func displayTitle(for session: BaseSession) -> String {
        switch session.taskType {
        case .techRadar:
            return "Signal Radar"
        case .researchFeeder:
            if viewModel.mode == .manual,
               session.date == "2026-08-09" || session.date == "2026-08-16" {
                return "Weekly Studio"
            }
            return deepDiveDisplayTitle(for: session)
        case .jdAnalysis:
            return "Opportunity Alignment"
        }
    }

    private func displayTaskType(for session: BaseSession) -> String {
        switch session.taskType {
        case .techRadar:
            return "radar"
        case .researchFeeder:
            if viewModel.mode == .manual,
               session.date == "2026-08-09" || session.date == "2026-08-16" {
                return "weekly_studio"
            }
            return "deep_dive"
        case .jdAnalysis:
            return "opportunity_alignment"
        }
    }

    private func isActive(_ session: BaseSession) -> Bool {
        session.status != .completed &&
            session.status != .archived &&
            session.status != .skipped
    }

    private func deepDiveDisplayTitle(for session: BaseSession) -> String {
        let prefix = "Deep Dive-\(session.date.replacingOccurrences(of: "-", with: "/"))-"
        if session.title.hasPrefix(prefix) {
            return session.title
        }
        return "\(prefix)1"
    }
}

#Preview {
    TodayView()
}
