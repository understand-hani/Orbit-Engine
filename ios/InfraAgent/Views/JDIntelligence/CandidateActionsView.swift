import SwiftUI

struct CandidateActionsView: View {
    @State private var actions: [CandidateAction] = []
    @State private var priorityFilter = "all"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = JDIntelligenceAPI()

    var body: some View {
        List {
            Section("筛选") {
                Picker("优先级", selection: $priorityFilter) {
                    Text("全部").tag("all")
                    Text("高").tag("high")
                    Text("中").tag("medium")
                    Text("低").tag("low")
                }
                .pickerStyle(.segmented)
            }

            Section("文件夹") {
                CandidateActionFolderRow(title: "建议", status: "suggested", actions: actions, onChanged: load)
                CandidateActionFolderRow(title: "已接受", status: "accepted", actions: actions, onChanged: load)
                CandidateActionFolderRow(title: "已延后", status: "deferred", actions: actions, onChanged: load)
                CandidateActionFolderRow(title: "已拒绝", status: "rejected", actions: actions, onChanged: load)
                CandidateActionFolderRow(title: "已转任务", status: "converted_to_task", actions: actions, onChanged: load)
            }

            if isLoading {
                LoadingView(title: "正在加载行动")
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            Section("建议行动") {
                ForEach(filteredAndSortedActions) { action in
                    NavigationLink {
                        CandidateActionDetailView(action: action) {
                            await load()
                        }
                    } label: {
                        CandidateActionRow(action: action)
                    }
                }
            }
        }
        .navigationTitle("候选行动")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await load()
        }
        .onAppear {
            Task { await load() }
        }
    }

    private var filteredAndSortedActions: [CandidateAction] {
        actions
            .filter { $0.status == "suggested" }
            .filter { priorityFilter == "all" || $0.priority == priorityFilter }
            .sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
    }

    private func priorityRank(_ priority: String) -> Int {
        switch priority {
        case "high":
            return 0
        case "medium":
            return 1
        case "low":
            return 2
        default:
            return 3
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            actions = LocalCandidateActionDecisionStore.apply(to: try await api.actions())
            if actions.isEmpty {
                actions = LocalCandidateActionDecisionStore.apply(to: MockJDIntelligence.actions)
            }
            errorMessage = nil
        } catch {
            actions = LocalCandidateActionDecisionStore.apply(to: MockJDIntelligence.actions)
            errorMessage = "正在使用本地 Mock 数据：\(error.localizedDescription)"
        }
    }

}

struct CandidateActionFolderRow: View {
    let title: String
    let status: String
    let actions: [CandidateAction]
    let onChanged: () async -> Void

    private var count: Int {
        actions.filter { $0.status == status }.count
    }

    var body: some View {
        NavigationLink {
            CandidateActionFolderView(title: title, status: status, actions: actions, onChanged: onChanged)
        } label: {
            HStack {
                Label(title, systemImage: iconName)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iconName: String {
        switch status {
        case "accepted":
            return "checkmark.circle"
        case "deferred":
            return "clock"
        case "rejected":
            return "xmark.circle"
        case "converted_to_task":
            return "arrow.triangle.branch"
        default:
            return "tray"
        }
    }
}

struct CandidateActionFolderView: View {
    let title: String
    let status: String
    let actions: [CandidateAction]
    let onChanged: () async -> Void

    @State private var localActions: [CandidateAction]

    init(
        title: String,
        status: String,
        actions: [CandidateAction],
        onChanged: @escaping () async -> Void
    ) {
        self.title = title
        self.status = status
        self.actions = actions
        self.onChanged = onChanged
        _localActions = State(initialValue: actions)
    }

    private var folderActions: [CandidateAction] {
        localActions.filter { $0.status == status }
    }

    var body: some View {
        List {
            if folderActions.isEmpty {
                EmptyStateView(
                    title: "暂无\(title)行动",
                    systemImage: "tray",
                    message: "你做出决定后，行动会移动到这里。"
                )
            } else {
                Section(title) {
                    ForEach(folderActions) { action in
                        NavigationLink {
                            CandidateActionDetailView(action: action) {
                                await onChanged()
                                applyLocalDecisionUpdate()
                            }
                        } label: {
                            CandidateActionRow(action: action)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            localActions = actions
        }
    }

    private func applyLocalDecisionUpdate() {
        localActions = LocalCandidateActionDecisionStore.apply(to: localActions)
    }
}
