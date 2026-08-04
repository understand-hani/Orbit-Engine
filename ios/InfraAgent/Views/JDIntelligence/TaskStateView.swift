import SwiftUI
import UniformTypeIdentifiers

struct TaskStateView: View {
    @State private var snapshot: TaskStateSnapshot?
    @State private var convertedTasks: [TaskProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var planRefreshID = UUID()
    @State private var isShowingImporter = false
    @State private var importMessage: String?

    private let api = JDIntelligenceAPI()

    init(snapshot: TaskStateSnapshot? = nil) {
        _snapshot = State(initialValue: snapshot)
    }

    var body: some View {
        List {
            if isLoading {
                LoadingView(title: "正在加载任务状态")
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            if let importMessage {
                Section {
                    Text(importMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if periodRefs.isEmpty {
                EmptyStateView(
                    title: "暂无 Period",
                    systemImage: "rectangle.stack",
                    message: "加载任务状态后会在这里显示 Period。"
                )
            } else {
                Section("Period") {
                    ForEach(periodRefs) { item in
                        NavigationLink {
                            PeriodDetailView(taskID: item.taskID, period: item.period) {
                                refreshLocalPlans()
                            }
                        } label: {
                            PeriodCardView(period: item.period)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deletePeriod(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("任务状态")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }

                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.json]) { result in
            importPeriods(from: result)
        }
        .task {
            convertedTasks = LocalConvertedTaskStore.taskProfiles()
            if snapshot == nil {
                await load()
            } else {
                refreshLocalPlans()
            }
        }
        .onAppear {
            convertedTasks = LocalConvertedTaskStore.taskProfiles()
            refreshLocalPlans()
        }
    }

    private var allTasks: [TaskProfile] {
        var tasks = (snapshot?.tasks ?? []) + convertedTasks
        if TaskHierarchyStore.hasSavedPlan(for: TaskHierarchyStore.importedTaskID) {
            tasks.append(TaskHierarchyStore.importedTask)
        }
        return tasks.map {
            LocalTaskStateStore.apply(to: $0)
        }
    }

    private var periodRefs: [TaskPeriodRef] {
        _ = planRefreshID
        return allTasks.flatMap { task in
            TaskHierarchyStore.plan(for: task).periods.map { period in
                TaskPeriodRef(taskID: task.id, period: period)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await api.latestTaskSnapshot()
            convertedTasks = LocalConvertedTaskStore.taskProfiles()
            refreshLocalPlans()
            errorMessage = nil
        } catch {
            snapshot = MockJDIntelligence.taskSnapshot
            convertedTasks = LocalConvertedTaskStore.taskProfiles()
            refreshLocalPlans()
            errorMessage = "正在使用本地 Mock 数据：\(error.localizedDescription)"
        }
    }

    private func refreshLocalPlans() {
        for task in allTasks where !TaskHierarchyStore.hasSavedPlan(for: task.id) {
            TaskHierarchyStore.save(TaskHierarchyStore.plan(for: task), for: task.id)
        }
        planRefreshID = UUID()
    }

    private func importPeriods(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let periods = try JSONDecoder().decode(TaskPeriodImportFile.self, from: data).periods
            TaskHierarchyStore.appendImportedPeriods(periods)
            importMessage = "已导入 \(periods.count) 个 Period"
            refreshLocalPlans()
        } catch {
            importMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func deletePeriod(_ item: TaskPeriodRef) {
        TaskHierarchyStore.deletePeriod(taskID: item.taskID, periodID: item.period.id)
        importMessage = "已删除 \(item.period.title)"
        refreshLocalPlans()
    }
}

private struct TaskPeriodRef: Identifiable {
    let taskID: String
    let period: PeriodPlan

    var id: String {
        "\(taskID)_\(period.id)"
    }
}

private struct TaskPeriodImportFile: Codable {
    let periods: [PeriodPlan]
}
