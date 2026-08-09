import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            HistoryView()
                .tabItem {
                    Label("归档", systemImage: "archivebox")
                }

            PlanView()
                .tabItem {
                    Label("计划", systemImage: "list.bullet.clipboard")
                }

            MoreView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
    }
}

struct PlanView: View {
    @State private var context: UserContext?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var isShowingQuickEdit = false

    private let api = UserContextAPI()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("计划")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("维护长期目标、本周重点和当前任务，供 Agent 生成今日 session 时引用。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let context {
                    Section("当前目标") {
                        LabeledContent("长期目标", value: context.plan.longTermGoal)
                        LabeledContent("目标周期", value: context.plan.targetCycle.isEmpty ? "未设置" : context.plan.targetCycle)
                    }

                    Section("全周期计划") {
                        if context.plan.fullCyclePlan.isEmpty {
                            Text("还没有全周期计划。去“我的 > 方向配置”生成后会显示在这里。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(context.plan.fullCyclePlan.enumerated()), id: \.offset) { index, item in
                                PlanPhaseBlockView(index: index + 1, text: item)
                            }
                        }
                    }

                    Section("第一周计划") {
                        LabeledContent("本周重点", value: context.plan.weeklyFocus)
                        LabeledContent("下一步", value: context.plan.nextAction)
                    }

                    Section("当前任务") {
                        if context.plan.activeTasks.isEmpty {
                            Text("暂无任务")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(context.plan.activeTasks, id: \.self) { task in
                                Text(task)
                            }
                        }
                    }

                    Section("Tracking Keywords") {
                        TagRow(tags: context.plan.trackingKeywords)
                    }
                } else if isLoading {
                    Section {
                        ProgressView("加载计划中")
                    }
                } else {
                    Section {
                        Text("暂无计划数据")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("计划")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("快编") {
                        isShowingQuickEdit = true
                    }
                    .disabled(context == nil)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("编辑") {
                        DirectionProfileView()
                    }
                }
            }
            .task {
                await load()
            }
            .refreshable {
                await load(force: true)
            }
            .sheet(isPresented: $isShowingQuickEdit) {
                NavigationStack {
                    if let context {
                        PlanQuickEditView(
                            initialContext: context,
                            isSaving: isSaving,
                            onSave: { updated in
                                await saveQuickEdit(updated)
                            }
                        )
                    } else {
                        ProgressView("加载计划中")
                    }
                }
            }
        }
    }

    private func load(force: Bool = false) async {
        if isLoading { return }
        if context != nil && !force { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await api.get()
            let normalized = PlanNormalizer.normalizedContext(loaded)
            context = normalized.context
            if normalized.changed {
                _ = try await api.save(normalized.context)
                message = "已自动整理旧计划：全周期计划现在控制在 3-4 个具体阶段。"
            } else {
                message = "这里展示的是当前已保存到用户上下文的计划，Agent 会直接引用这些内容。"
            }
        } catch {
            message = "加载计划失败：\(error.localizedDescription)"
        }
    }

    private func saveQuickEdit(_ updated: UserContext) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let normalized = PlanNormalizer.normalizedContext(updated)
            let saved = try await api.save(normalized.context)
            context = PlanNormalizer.normalizedContext(saved).context
            message = "计划已保存。Today 和 Agent 将优先使用这份更新后的计划。"
            isShowingQuickEdit = false
        } catch {
            message = "保存计划失败：\(error.localizedDescription)"
        }
    }
}

private struct PlanQuickEditView: View {
    let initialContext: UserContext
    let isSaving: Bool
    let onSave: (UserContext) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var longTermGoal: String
    @State private var targetCycle: String
    @State private var fullCyclePlanText: String
    @State private var weeklyFocus: String
    @State private var nextAction: String
    @State private var activeTasksText: String
    @State private var trackingKeywordsText: String

    init(
        initialContext: UserContext,
        isSaving: Bool,
        onSave: @escaping (UserContext) async -> Void
    ) {
        self.initialContext = initialContext
        self.isSaving = isSaving
        self.onSave = onSave
        let normalized = PlanNormalizer.normalizedContext(initialContext).context
        _longTermGoal = State(initialValue: initialContext.plan.longTermGoal)
        _targetCycle = State(initialValue: initialContext.plan.targetCycle)
        _fullCyclePlanText = State(initialValue: normalized.plan.fullCyclePlan.joined(separator: "\n\n"))
        _weeklyFocus = State(initialValue: initialContext.plan.weeklyFocus)
        _nextAction = State(initialValue: initialContext.plan.nextAction)
        _activeTasksText = State(initialValue: initialContext.plan.activeTasks.joined(separator: "\n"))
        _trackingKeywordsText = State(initialValue: initialContext.plan.trackingKeywords.joined(separator: "\n"))
    }

    var body: some View {
        Form {
            Section("方向级目标") {
                TextField("长期目标", text: $longTermGoal, axis: .vertical)
                    .lineLimit(2...4)
                TextField("目标周期", text: $targetCycle)
            }

            Section("全周期计划") {
                Text("建议保留 3-4 个阶段。每个阶段可用多行写目标、动作和产出；阶段之间用空行分隔。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("阶段之间用空行分隔", text: $fullCyclePlanText, axis: .vertical)
                    .lineLimit(4...10)
            }

            if let issue = fullCyclePlanValidationMessage {
                Section {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("本周计划") {
                TextField("本周重点", text: $weeklyFocus, axis: .vertical)
                    .lineLimit(2...5)
                TextField("下一步", text: $nextAction, axis: .vertical)
                    .lineLimit(2...4)
                TextField("当前任务，每行一个", text: $activeTasksText, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Tracking Keywords") {
                TextField("每行一个关键词", text: $trackingKeywordsText, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle("快速编辑计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中" : "保存") {
                    Task {
                        await onSave(buildUpdatedContext())
                    }
                }
                .disabled(isSaving || fullCyclePlanValidationMessage != nil)
            }
        }
    }

    private func buildUpdatedContext() -> UserContext {
        var updated = initialContext
        let now = Date()
        updated.plan.longTermGoal = nonEmpty(longTermGoal, fallback: initialContext.plan.longTermGoal)
        updated.plan.targetCycle = nonEmpty(targetCycle, fallback: initialContext.plan.targetCycle)
        updated.plan.fullCyclePlan = PlanNormalizer.normalizedFullCyclePlan(
            nonEmptyList(splitPlanBlocks(fullCyclePlanText), fallback: initialContext.plan.fullCyclePlan),
            direction: updated.profile.goal.isEmpty ? updated.plan.longTermGoal : updated.profile.goal,
            targetCycle: updated.plan.targetCycle
        )
        updated.plan.weeklyFocus = nonEmpty(weeklyFocus, fallback: initialContext.plan.weeklyFocus)
        updated.plan.nextAction = nonEmpty(nextAction, fallback: initialContext.plan.nextAction)
        updated.plan.activeTasks = nonEmptyList(splitLines(activeTasksText), fallback: initialContext.plan.activeTasks)
        updated.plan.trackingKeywords = nonEmptyList(splitLines(trackingKeywordsText), fallback: initialContext.plan.trackingKeywords)
        updated.plan.updatedAt = now
        return updated
    }

    private func splitLines(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",，\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitPlanBlocks(_ text: String) -> [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func nonEmptyList(_ value: [String], fallback: [String]) -> [String] {
        value.isEmpty ? fallback : value
    }

    private var fullCyclePlanValidationMessage: String? {
        PlanNormalizer.validationMessage(for: splitPlanBlocks(fullCyclePlanText))
    }
}

private struct PlanPhaseBlockView: View {
    let index: Int
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(bodyLines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var lines: [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var title: String {
        lines.first ?? "阶段 \(index)"
    }

    private var bodyLines: [String] {
        Array(lines.dropFirst())
    }
}

#Preview {
    RootTabView()
}
