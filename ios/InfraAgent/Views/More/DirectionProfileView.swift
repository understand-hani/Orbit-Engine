import SwiftUI

struct DirectionProfileView: View {
    @State private var context: UserContext?
    @State private var goal = ""
    @State private var backgroundSummary = ""
    @State private var currentStage = ""
    @State private var longTermGoal = ""
    @State private var weeklyFocus = ""
    @State private var nextAction = ""
    @State private var fieldsText = ""
    @State private var keywordsText = ""
    @State private var activeTasksText = ""
    @State private var constraintsText = ""
    @State private var sourcePreferences = Set<String>()
    @State private var timeBudget = 30
    @State private var message: String?
    @State private var isLoading = false
    @State private var isSaving = false

    private let api = UserContextAPI()
    private let sourceOptions = [
        ("arxiv", "arXiv"),
        ("github", "GitHub"),
        ("official_doc", "官方文档"),
        ("url", "网页"),
        ("pdf", "PDF"),
        ("manual", "手动材料")
    ]

    var body: some View {
        Form {
            if let message {
                Section {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("方向") {
                TextField("长期目标", text: $longTermGoal, axis: .vertical)
                    .lineLimit(2...4)
                TextField("当前方向", text: $goal, axis: .vertical)
                    .lineLimit(2...4)
                TextField("当前阶段", text: $currentStage, axis: .vertical)
                    .lineLimit(2...4)
                TextField("背景 / 已有基础", text: $backgroundSummary, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("本周计划") {
                TextField("本周 focus", text: $weeklyFocus, axis: .vertical)
                    .lineLimit(2...5)
                TextField("下一步动作", text: $nextAction, axis: .vertical)
                    .lineLimit(2...4)
                TextField("当前任务，每行一个", text: $activeTasksText, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Agent 检索策略") {
                TextField("领域关键词，用逗号或换行分隔", text: $keywordsText, axis: .vertical)
                    .lineLimit(2...6)
                TextField("关注领域，用逗号或换行分隔", text: $fieldsText, axis: .vertical)
                    .lineLimit(2...5)
                Stepper("时间预算 \(timeBudget) 分钟", value: $timeBudget, in: 15...120, step: 15)

                ForEach(sourceOptions, id: \.0) { option in
                    Button {
                        toggleSource(option.0)
                    } label: {
                        HStack {
                            Text(option.1)
                            Spacer()
                            if sourcePreferences.contains(option.0) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("约束") {
                TextField("约束，每行一个", text: $constraintsText, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle("方向配置")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "保存中" : "保存") {
                    Task { await save() }
                }
                .disabled(isSaving || context == nil)
            }
        }
        .task {
            await load()
        }
        .overlay {
            if isLoading {
                ProgressView("加载中")
            }
        }
    }

    private func load() async {
        guard context == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await api.get()
            context = loaded
            apply(loaded)
            message = "这些配置会用于下一步 Agent 自动检索今天 Deep Dive 材料。"
        } catch {
            message = "加载失败：\(error.localizedDescription)"
        }
    }

    private func save() async {
        guard var context else { return }
        isSaving = true
        defer { isSaving = false }

        let now = Date()
        context.profile.goal = goal
        context.profile.backgroundSummary = backgroundSummary
        context.profile.currentStage = currentStage
        context.profile.constraints = splitLines(constraintsText)
        context.profile.updatedAt = now
        context.plan.longTermGoal = longTermGoal
        context.plan.weeklyFocus = weeklyFocus
        context.plan.nextAction = nextAction
        context.plan.activeTasks = splitLines(activeTasksText)
        context.plan.trackingKeywords = splitLines(keywordsText)
        context.plan.updatedAt = now
        context.preferences.fields = splitLines(fieldsText)
        context.preferences.sourcePreferences = Array(sourcePreferences).sorted()
        context.preferences.sessionTimeBudgetMin = timeBudget
        context.preferences.updatedAt = now

        do {
            let saved = try await api.save(context)
            self.context = saved
            apply(saved)
            message = "已保存。Agent 自动选材会优先使用这些方向和偏好。"
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }

    private func apply(_ context: UserContext) {
        goal = context.profile.goal
        backgroundSummary = context.profile.backgroundSummary
        currentStage = context.profile.currentStage
        longTermGoal = context.plan.longTermGoal
        weeklyFocus = context.plan.weeklyFocus
        nextAction = context.plan.nextAction
        fieldsText = context.preferences.fields.joined(separator: "\n")
        keywordsText = context.plan.trackingKeywords.joined(separator: "\n")
        activeTasksText = context.plan.activeTasks.joined(separator: "\n")
        constraintsText = context.profile.constraints.joined(separator: "\n")
        sourcePreferences = Set(context.preferences.sourcePreferences)
        timeBudget = context.preferences.sessionTimeBudgetMin
    }

    private func toggleSource(_ source: String) {
        if sourcePreferences.contains(source) {
            sourcePreferences.remove(source)
        } else {
            sourcePreferences.insert(source)
        }
    }

    private func splitLines(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",，\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    NavigationStack {
        DirectionProfileView()
    }
}
