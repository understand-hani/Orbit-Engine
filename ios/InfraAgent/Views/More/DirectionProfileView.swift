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
    @State private var isGenerating = false
    @State private var showGeneratedSections = false

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
                Text("先告诉 Agent 你接下来想推进什么。下面的提示文字只是示例，不需要按固定领域填写。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DirectionQuestionField(
                    title: "1. 你长期想达成什么目标？",
                    help: "例如：建立某个领域的能力、准备转岗、形成研究判断、做出一个项目。",
                    placeholder: "",
                    text: $longTermGoal,
                    lineLimit: 2...4
                )

                DirectionQuestionField(
                    title: "2. 你现在最想推进的方向是什么？",
                    help: "这是 Agent 自动检索材料的核心输入。可以是技术、行业、岗位、学科或任何自定义方向。",
                    placeholder: "",
                    text: $goal,
                    lineLimit: 2...4
                )

                DirectionQuestionField(
                    title: "3. 你现在处在哪个阶段？",
                    help: "例如：入门、补基础、追前沿、做项目、准备输出、准备面试。",
                    placeholder: "",
                    text: $currentStage,
                    lineLimit: 2...4
                )

                DirectionQuestionField(
                    title: "4. Agent 还需要知道你的哪些背景或基础？",
                    help: "写下已有经验、限制条件、熟悉/不熟悉的内容，帮助 Agent 避免推荐不合适的材料。",
                    placeholder: "",
                    text: $backgroundSummary,
                    lineLimit: 3...6
                )

                Stepper("时间预算 \(timeBudget) 分钟", value: $timeBudget, in: 15...120, step: 15)
            }

            Section {
                Button {
                    Task { await generateSuggestion() }
                } label: {
                    HStack {
                        Spacer()
                        Text(isGenerating ? "Agent 正在生成" : "提交方向，让 Agent 生成计划")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || context == nil || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if showGeneratedSections {
                Section("本周计划") {
                    Text("Agent 会根据你的方向先生成一版计划；你可以直接修改。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("本周 focus", text: $weeklyFocus, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("下一步动作", text: $nextAction, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("当前任务，每行一个", text: $activeTasksText, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Agent 检索策略") {
                    Text("这些字段会用于下一步自动生成搜索 query 和筛选今天的 Deep Dive 材料。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("领域关键词，用逗号或换行分隔", text: $keywordsText, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("关注领域，用逗号或换行分隔", text: $fieldsText, axis: .vertical)
                        .lineLimit(2...5)

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
                    Text("约束会帮助 Agent 避免推荐太泛、太难或不适合当前时间窗口的材料。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("约束，每行一个", text: $constraintsText, axis: .vertical)
                        .lineLimit(2...6)
                }
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
            message = "这些配置会用于下一步 Agent 自动检索今天 Deep Dive 材料。"
        } catch {
            message = "加载失败：\(error.localizedDescription)"
        }
    }

    private func generateSuggestion() async {
        isGenerating = true
        message = nil
        defer { isGenerating = false }

        do {
            let suggestion = try await api.suggestDirection(
                DirectionProfileSuggestionRequest(
                    longTermGoal: longTermGoal,
                    currentDirection: goal,
                    currentStage: currentStage,
                    backgroundSummary: backgroundSummary,
                    timeBudgetMin: timeBudget
                )
            )
            apply(suggestion)
            showGeneratedSections = true
            message = "Agent 已生成后续配置，请检查并按你的真实情况修改后保存。"
        } catch {
            showGeneratedSections = true
            message = "Agent 生成失败，你仍可以手动编辑后续配置：\(error.localizedDescription)"
        }
    }

    private func save() async {
        guard var context else { return }
        isSaving = true
        defer { isSaving = false }

        let now = Date()
        context.profile.goal = nonEmpty(goal, fallback: context.profile.goal)
        context.profile.backgroundSummary = nonEmpty(backgroundSummary, fallback: context.profile.backgroundSummary)
        context.profile.currentStage = nonEmpty(currentStage, fallback: context.profile.currentStage)
        context.profile.constraints = nonEmptyList(splitLines(constraintsText), fallback: context.profile.constraints)
        context.profile.updatedAt = now
        context.plan.longTermGoal = nonEmpty(longTermGoal, fallback: context.plan.longTermGoal)
        context.plan.weeklyFocus = nonEmpty(weeklyFocus, fallback: context.plan.weeklyFocus)
        context.plan.nextAction = nonEmpty(nextAction, fallback: context.plan.nextAction)
        context.plan.activeTasks = nonEmptyList(splitLines(activeTasksText), fallback: context.plan.activeTasks)
        context.plan.trackingKeywords = nonEmptyList(splitLines(keywordsText), fallback: context.plan.trackingKeywords)
        context.plan.updatedAt = now
        context.preferences.fields = nonEmptyList(splitLines(fieldsText), fallback: context.preferences.fields)
        context.preferences.sourcePreferences = nonEmptyList(
            Array(sourcePreferences).sorted(),
            fallback: context.preferences.sourcePreferences
        )
        context.preferences.sessionTimeBudgetMin = timeBudget
        context.preferences.updatedAt = now

        do {
            let saved = try await api.save(context)
            self.context = saved
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

    private func apply(_ suggestion: DirectionProfileSuggestion) {
        weeklyFocus = suggestion.weeklyFocus
        nextAction = suggestion.nextAction
        activeTasksText = suggestion.activeTasks.joined(separator: "\n")
        keywordsText = suggestion.trackingKeywords.joined(separator: "\n")
        fieldsText = suggestion.fields.joined(separator: "\n")
        constraintsText = suggestion.constraints.joined(separator: "\n")
        sourcePreferences = Set(suggestion.sourcePreferences)
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

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func nonEmptyList(_ value: [String], fallback: [String]) -> [String] {
        value.isEmpty ? fallback : value
    }
}

private struct DirectionQuestionField: View {
    let title: String
    let help: String
    let placeholder: String
    @Binding var text: String
    let lineLimit: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(lineLimit)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        DirectionProfileView()
    }
}
