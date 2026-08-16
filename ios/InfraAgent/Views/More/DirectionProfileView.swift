import SwiftUI

struct DirectionProfileView: View {
    @State private var context: UserContext?
    @State private var goal = ""
    @State private var backgroundSummary = ""
    @State private var currentStage = ""
    @State private var targetCycle = ""
    @State private var longTermGoal = ""
    @State private var fullCyclePlanText = ""
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
    @State private var isEnhancingInitialPlan = false
    @State private var isShowingPlanSheet = false
    @State private var planStep: DirectionPlanStep = .fullCycle
    @State private var sheetErrorMessage: String?

    private let api = UserContextAPI()
    private let sourceOptions = [
        ("arxiv", "arXiv"),
        ("github", "GitHub"),
        ("official_doc", "官方文档"),
        ("url", "网页")
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

                DirectionQuestionField(
                    title: "5. 你希望用多长周期完成这个目标？",
                    help: "例如：2 周、3 个月、半年、一年。Agent 会据此生成全周期计划和本周计划。",
                    placeholder: "",
                    text: $targetCycle,
                    lineLimit: 1...2
                )

                Stepper("时间预算 \(timeBudget) 分钟", value: $timeBudget, in: 15...120, step: 15)
            }

            Section {
                Button {
                    Task { await beginPlanGeneration() }
                } label: {
                    HStack {
                        Spacer()
                        Text(isGenerating ? "Agent 正在生成" : directionEntryButtonTitle)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || context == nil || goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .sheet(isPresented: $isShowingPlanSheet) {
            NavigationStack {
                planSheetContent
                    .navigationTitle(planStep.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                isShowingPlanSheet = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var planSheetContent: some View {
        if isGenerating {
            VStack(spacing: 12) {
                ProgressView()
                Text("Agent 正在根据你的方向生成计划")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                if isEnhancingInitialPlan {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("基础计划已可编辑，Agent 正在后台尝试优化")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let currentSheetError = sheetErrorMessage {
                    Section {
                        Text(currentSheetError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Button("重试当前步骤") {
                            Task { await retryCurrentPlanStep() }
                        }
                        if isFullCycleStep && hasReusableFullCyclePlan {
                            Button("继续使用当前计划") {
                                sheetErrorMessage = nil
                            }
                        }
                    }
                }

                switch planStep {
                case .fullCycle:
                    Section("全周期计划") {
                        Text("建议控制在 3-4 个阶段。每个阶段按条目填写目标、具体执行计划和产出；阶段之间用空行分隔。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("阶段之间用空行分隔", text: $fullCyclePlanText, axis: .vertical)
                            .lineLimit(4...10)
                        Button("重新生成全周期计划") {
                            Task { await generateSuggestion() }
                        }
                    }
                    if let issue = fullCyclePlanValidationMessage {
                        Section {
                            Text(issue)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                case .week:
                    Section("已确认的全周期计划") {
                        planPreviewSectionItems(splitPlanBlocks(fullCyclePlanText), emptyText: "还没有全周期计划。")
                    }

                    Section("第一周计划") {
                        Text("确认全周期计划后，再确认第一周要推进什么。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("本周 focus", text: $weeklyFocus, axis: .vertical)
                            .lineLimit(2...5)
                        TextField("下一步动作", text: $nextAction, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("当前任务，每行一个", text: $activeTasksText, axis: .vertical)
                            .lineLimit(3...8)
                    }
                case .strategy:
                    Section("全周期计划") {
                        planPreviewSectionItems(splitPlanBlocks(fullCyclePlanText), emptyText: "还没有全周期计划。")
                    }

                    Section("第一周计划") {
                        LabeledContent("本周 focus", value: weeklyFocus.isEmpty ? "未填写" : weeklyFocus)
                        LabeledContent("下一步动作", value: nextAction.isEmpty ? "未填写" : nextAction)
                        planPreviewSectionItems(splitLines(activeTasksText), emptyText: "还没有当前任务。")
                    }

                    Section("Agent 检索策略") {
                        Text("最后确认 Agent 用什么关键词和材料源来筛选 Deep Dive 材料。")
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

                Section {
                    Button {
                        Task { await confirmCurrentPlanStep() }
                    } label: {
                        HStack {
                            Spacer()
                            Text(planStep.confirmTitle(isSaving: isSaving))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || !canConfirmCurrentPlanStep)
                }
            }
        }
    }

    private func load() async {
        guard context == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await api.get()
            let normalized = PlanNormalizer.normalizedContext(loaded)
            context = normalized.context
            apply(normalized.context)
            message = "这些配置会用于下一步 Agent 自动检索今天 Deep Dive 材料。"
        } catch {
            message = "加载失败：\(error.localizedDescription)"
        }
    }

    private func generateSuggestion() async {
        isGenerating = true
        message = nil
        sheetErrorMessage = nil
        defer { isGenerating = false }

        do {
            let suggestion = try await api.suggestDirection(
                DirectionProfileSuggestionRequest(
                    longTermGoal: longTermGoal,
                    currentDirection: goal,
                    currentStage: currentStage,
                    backgroundSummary: backgroundSummary,
                    targetCycle: targetCycle,
                    timeBudgetMin: timeBudget,
                    fullCyclePlan: [],
                    weeklyFocus: "",
                    activeTasks: [],
                    nextAction: ""
                )
            )
            apply(suggestion)
            message = suggestion.generationMode == "llm"
                ? "Agent 已生成计划，请按步骤确认后保存。"
                : "已生成可编辑的基础计划；Agent 本次未及时响应，你仍可继续确认并保存。"
        } catch {
            sheetErrorMessage = "Agent 生成失败：\(error.localizedDescription)"
            message = sheetErrorMessage
        }
    }

    private func beginPlanGeneration() async {
        planStep = .fullCycle
        sheetErrorMessage = nil
        isShowingPlanSheet = true
        if !hasReusableFullCyclePlan {
            let draftSnapshot = applyImmediateDraft()
            await enhanceInitialDraft(replacing: draftSnapshot)
        }
    }

    @discardableResult
    private func applyImmediateDraft() -> String {
        let direction = goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? longTermGoal : goal
        fullCyclePlanText = PlanNormalizer.normalizedFullCyclePlan(
            [],
            direction: direction,
            targetCycle: targetCycle
        ).joined(separator: "\n\n")
        sheetErrorMessage = nil
        message = "已生成可编辑的基础计划；无需等待 Agent 即可继续确认。"
        return fullCyclePlanText
    }

    private func enhanceInitialDraft(replacing draftSnapshot: String) async {
        isEnhancingInitialPlan = true
        defer { isEnhancingInitialPlan = false }

        do {
            let suggestion = try await api.suggestDirection(
                DirectionProfileSuggestionRequest(
                    longTermGoal: longTermGoal,
                    currentDirection: goal,
                    currentStage: currentStage,
                    backgroundSummary: backgroundSummary,
                    targetCycle: targetCycle,
                    timeBudgetMin: timeBudget,
                    fullCyclePlan: [],
                    weeklyFocus: "",
                    activeTasks: [],
                    nextAction: ""
                )
            )
            guard isShowingPlanSheet,
                  isFullCycleStep,
                  fullCyclePlanText == draftSnapshot else {
                return
            }
            apply(suggestion)
            message = suggestion.generationMode == "llm"
                ? "Agent 已在后台优化计划，请确认后保存。"
                : "基础计划已可用；Agent 本次未及时响应，可稍后重新生成。"
        } catch {
            guard isShowingPlanSheet, isFullCycleStep else { return }
            message = "基础计划已可用；Agent 增强暂不可用，但不影响确认和保存。"
        }
    }

    private func confirmCurrentPlanStep() async {
        switch planStep {
        case .fullCycle:
            if await regenerateWeekPlanFromEditedFullCycle() {
                planStep = .week
            }
        case .week:
            if await regenerateStrategyFromEditedWeekPlan() {
                planStep = .strategy
            }
        case .strategy:
            await save()
            if message?.hasPrefix("已保存") == true {
                isShowingPlanSheet = false
            }
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
        context.plan.targetCycle = nonEmpty(targetCycle, fallback: context.plan.targetCycle)
        context.plan.fullCyclePlan = PlanNormalizer.normalizedFullCyclePlan(
            nonEmptyList(splitPlanBlocks(fullCyclePlanText), fallback: context.plan.fullCyclePlan),
            direction: context.profile.goal.isEmpty ? context.plan.longTermGoal : context.profile.goal,
            targetCycle: context.plan.targetCycle
        )
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
            let normalized = PlanNormalizer.normalizedContext(saved).context
            self.context = normalized
            apply(normalized)
            message = "已保存。Agent 自动选材会优先使用这些方向和偏好。"
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }

    private func apply(_ context: UserContext) {
        goal = context.profile.goal
        backgroundSummary = context.profile.backgroundSummary
        currentStage = context.profile.currentStage
        targetCycle = context.plan.targetCycle
        longTermGoal = context.plan.longTermGoal
        fullCyclePlanText = context.plan.fullCyclePlan.joined(separator: "\n\n")
        weeklyFocus = context.plan.weeklyFocus
        nextAction = context.plan.nextAction
        fieldsText = context.preferences.fields.joined(separator: "\n")
        keywordsText = context.plan.trackingKeywords.joined(separator: "\n")
        activeTasksText = context.plan.activeTasks.joined(separator: "\n")
        constraintsText = context.profile.constraints.joined(separator: "\n")
        sourcePreferences = searchableSources(context.preferences.sourcePreferences)
        timeBudget = context.preferences.sessionTimeBudgetMin
    }

    private func apply(_ suggestion: DirectionProfileSuggestion) {
        fullCyclePlanText = PlanNormalizer.normalizedFullCyclePlan(
            suggestion.fullCyclePlan,
            direction: goal.isEmpty ? longTermGoal : goal,
            targetCycle: targetCycle
        ).joined(separator: "\n\n")
        weeklyFocus = suggestion.weeklyFocus
        nextAction = suggestion.nextAction
        activeTasksText = suggestion.activeTasks.joined(separator: "\n")
        applyFirstWeekPlanIfAvailable()
        keywordsText = suggestion.trackingKeywords.joined(separator: "\n")
        fieldsText = suggestion.fields.joined(separator: "\n")
        constraintsText = suggestion.constraints.joined(separator: "\n")
        sourcePreferences = searchableSources(suggestion.sourcePreferences)
    }

    private func regenerateWeekPlanFromEditedFullCycle() async -> Bool {
        isGenerating = true
        sheetErrorMessage = nil
        defer { isGenerating = false }

        do {
            let suggestion = try await api.suggestDirection(
                buildSuggestionRequest(
                    fullCyclePlan: splitPlanBlocks(fullCyclePlanText),
                    weeklyFocus: "",
                    activeTasks: [],
                    nextAction: ""
                )
            )
            weeklyFocus = suggestion.weeklyFocus
            nextAction = suggestion.nextAction
            activeTasksText = suggestion.activeTasks.joined(separator: "\n")
            applyFirstWeekPlanIfAvailable()
            keywordsText = suggestion.trackingKeywords.joined(separator: "\n")
            fieldsText = suggestion.fields.joined(separator: "\n")
            constraintsText = suggestion.constraints.joined(separator: "\n")
            sourcePreferences = searchableSources(suggestion.sourcePreferences)
            message = "已根据你修改后的全周期计划重新生成第一周计划。"
            return true
        } catch {
            sheetErrorMessage = "基于全周期计划生成第一周计划失败：\(error.localizedDescription)"
            message = sheetErrorMessage
            return false
        }
    }

    private func regenerateStrategyFromEditedWeekPlan() async -> Bool {
        isGenerating = true
        sheetErrorMessage = nil
        // Old persisted Demo values must never be presented as a newly
        // generated strategy while this request is in flight or after failure.
        keywordsText = ""
        fieldsText = ""
        sourcePreferences = []
        constraintsText = ""
        defer { isGenerating = false }

        do {
            let suggestion = try await api.suggestDirection(
                buildSuggestionRequest(
                    fullCyclePlan: splitPlanBlocks(fullCyclePlanText),
                    weeklyFocus: weeklyFocus,
                    activeTasks: splitLines(activeTasksText),
                    nextAction: nextAction
                )
            )
            keywordsText = suggestion.trackingKeywords.joined(separator: "\n")
            fieldsText = suggestion.fields.joined(separator: "\n")
            constraintsText = suggestion.constraints.joined(separator: "\n")
            sourcePreferences = searchableSources(suggestion.sourcePreferences)
            message = "已根据你确认后的第一周计划重新生成检索策略。"
            return true
        } catch {
            sheetErrorMessage = "基于第一周计划生成检索策略失败：\(error.localizedDescription)"
            message = sheetErrorMessage
            return false
        }
    }

    private func retryCurrentPlanStep() async {
        switch planStep {
        case .fullCycle:
            await generateSuggestion()
        case .week, .strategy:
            await confirmCurrentPlanStep()
        }
    }

    private func buildSuggestionRequest(
        fullCyclePlan: [String],
        weeklyFocus: String,
        activeTasks: [String],
        nextAction: String
    ) -> DirectionProfileSuggestionRequest {
        DirectionProfileSuggestionRequest(
            longTermGoal: longTermGoal,
            currentDirection: goal,
            currentStage: currentStage,
            backgroundSummary: backgroundSummary,
            targetCycle: targetCycle,
            timeBudgetMin: timeBudget,
            fullCyclePlan: fullCyclePlan,
            weeklyFocus: weeklyFocus,
            activeTasks: activeTasks,
            nextAction: nextAction
        )
    }

    private func toggleSource(_ source: String) {
        if sourcePreferences.contains(source) {
            sourcePreferences.remove(source)
        } else {
            sourcePreferences.insert(source)
        }
    }

    private func searchableSources(_ values: [String]) -> Set<String> {
        let allowed = Set(sourceOptions.map { $0.0 })
        return Set(values.filter { allowed.contains($0) })
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

    private func applyFirstWeekPlanIfAvailable() {
        guard let weekPlan = firstWeekPlan(from: splitPlanBlocks(fullCyclePlanText)) else { return }
        weeklyFocus = "本周推进：\(weekPlan)"
        let action = weekPlanBody(weekPlan)
        nextAction = action.isEmpty ? "让 Agent 根据本周重点生成候选材料，并先确认一份今天最值得读的主材料。" : action
        activeTasksText = weekPlanTasks(from: action.isEmpty ? weekPlan : action).joined(separator: "\n")
    }

    private func firstWeekPlan(from planBlocks: [String]) -> String? {
        guard let firstPhase = planBlocks.first else { return nil }
        let executionLines = sectionLines(in: firstPhase, after: "具体执行计划：", before: "产出：")
        if let weekOne = executionLines.first(where: { line in
            line.contains("Week 1") || line.contains("第 1 周") || line.contains("第1周")
        }) {
            return cleanListMarker(weekOne)
        }
        return executionLines.first.map(cleanListMarker)
    }

    private func sectionLines(in text: String, after startMarker: String, before endMarker: String) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let start = lines.firstIndex(of: startMarker) else { return [] }
        let end = lines.firstIndex(of: endMarker) ?? lines.endIndex
        guard start + 1 < end else { return [] }
        return Array(lines[(start + 1)..<end])
    }

    private func cleanListMarker(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = text.first,
              first.isNumber || ".、-• ".contains(first) {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func weekPlanBody(_ weekPlan: String) -> String {
        guard let range = weekPlan.range(of: "：") else { return weekPlan }
        return String(weekPlan[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func weekPlanTasks(from text: String) -> [String] {
        let tasks = text
            .components(separatedBy: CharacterSet(charactersIn: "。；;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array((tasks.isEmpty ? [text] : tasks).prefix(3))
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func nonEmptyList(_ value: [String], fallback: [String]) -> [String] {
        value.isEmpty ? fallback : value
    }

    private var canConfirmCurrentPlanStep: Bool {
        switch planStep {
        case .fullCycle:
            return fullCyclePlanValidationMessage == nil && sheetErrorMessage == nil
        case .week:
            return true
        case .strategy:
            return sheetErrorMessage == nil &&
                !splitLines(keywordsText).isEmpty &&
                !splitLines(fieldsText).isEmpty
        }
    }

    private var hasReusableFullCyclePlan: Bool {
        !splitPlanBlocks(fullCyclePlanText).isEmpty && fullCyclePlanValidationMessage == nil
    }

    private var isFullCycleStep: Bool {
        if case .fullCycle = planStep {
            return true
        }
        return false
    }

    private var directionEntryButtonTitle: String {
        hasReusableFullCyclePlan ? "查看并确认当前计划" : "提交方向，让 Agent 生成计划"
    }

    private var fullCyclePlanValidationMessage: String? {
        PlanNormalizer.validationMessage(for: splitPlanBlocks(fullCyclePlanText))
    }

    @ViewBuilder
    private func planPreviewSectionItems(_ items: [String], emptyText: String) -> some View {
        if items.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("阶段 \(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(planBlockLines(item), id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func planBlockLines(_ item: String) -> [String] {
        item
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private enum DirectionPlanStep {
    case fullCycle
    case week
    case strategy

    var title: String {
        switch self {
        case .fullCycle:
            return "确认全周期计划"
        case .week:
            return "确认第一周计划"
        case .strategy:
            return "确认检索策略"
        }
    }

    func confirmTitle(isSaving: Bool) -> String {
        if isSaving {
            return "保存中"
        }
        switch self {
        case .fullCycle:
            return "确认全周期计划，生成第一周计划"
        case .week:
            return "确认第一周计划，生成检索策略"
        case .strategy:
            return "确认并保存到个人情况"
        }
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
