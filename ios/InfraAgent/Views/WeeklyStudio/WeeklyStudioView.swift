import SwiftUI

struct WeeklyStudioView: View {
    let session: BaseSession
    var onArchiveRequested: ((CompletionStartMode, CheckinSourceContext?) -> Void)?

    @State private var context: UserContext?
    @State private var checkins: [Checkin] = []
    @State private var isLoading = true
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var hasDraft = false
    @State private var completionSummary = ""
    @State private var blockers = ""
    @State private var nextWeekFocus = ""
    @State private var firstPriority = ""
    @State private var secondPriority = ""
    @State private var thirdPriority = ""
    @State private var errorMessage: String?
    @State private var saveMessage: String?

    private let userContextAPI = UserContextAPI()
    private let checkinAPI = CheckinAPI()

    var body: some View {
        List {
            if isLoading {
                LoadingView(title: "正在整理本周记录")
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            if let context {
                Section("当前工作区") {
                    WeeklyStudioLine(title: "本周重点", value: context.plan.weeklyFocus)
                    WeeklyStudioLine(title: "当前任务", value: context.plan.activeTasks.isEmpty ? "还没有记录当前任务。" : context.plan.activeTasks.joined(separator: "\n"))
                    WeeklyStudioLine(title: "下一步", value: context.plan.nextAction)
                }

                Section("本周归档摘要") {
                    LabeledContent("已完成", value: "\(completedCheckins.count) 条")
                    LabeledContent("未完成归档", value: "\(partialCheckins.count) 条")
                    if recentCheckins.isEmpty {
                        Text("本周还没有归档记录。生成草稿时会以当前计划作为起点。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentCheckins) { checkin in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkin.summary.isEmpty ? "未填写总结" : checkin.summary)
                                    .font(.subheadline)
                                Text(checkin.status == "completed" ? "已完成" : "未完成归档")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Agent 能做什么") {
                    Text("把本周归档、当前计划和未完成项收束成一份可执行的下周安排；它不会替你扩展成完整周报系统。")
                        .font(.subheadline)
                }

                if !hasDraft {
                    Section {
                        Button {
                            generateDraft(from: context)
                        } label: {
                            Label(isGenerating ? "正在生成 Weekly Studio" : "生成 Weekly Studio", systemImage: "sparkles")
                        }
                        .disabled(isGenerating)
                    } footer: {
                        Text("草稿引用当前 UserContext.plan 和本周 Check-in；生成后仍可编辑。")
                    }
                } else {
                    Section("本周完成") {
                        TextField("本周完成", text: $completionSummary, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section("卡点") {
                        TextField("卡点", text: $blockers, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section("下周 3 个优先任务") {
                        TextField("下周重点", text: $nextWeekFocus, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("优先任务 1", text: $firstPriority, axis: .vertical)
                            .lineLimit(2...3)
                        TextField("优先任务 2", text: $secondPriority, axis: .vertical)
                            .lineLimit(2...3)
                        TextField("优先任务 3", text: $thirdPriority, axis: .vertical)
                            .lineLimit(2...3)
                    }

                    if let saveMessage {
                        Section {
                            Text(saveMessage)
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    }

                    Section {
                        Button {
                            Task { await saveNextWeekPlan(from: context) }
                        } label: {
                            Label(isSaving ? "正在保存到计划" : "保存到计划上下文", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(isSaving || priorities.isEmpty || trimmed(nextWeekFocus).isEmpty)
                    } footer: {
                        Text("保存后会更新下一周的重点、当前任务和下一步；本周完成与卡点保留在本次复盘草稿中。")
                    }
                }
            }
        }
        .navigationTitle("Weekly Studio")
        .task {
            await loadWorkspace()
        }
    }

    private var recentCheckins: [Checkin] {
        Array(weekCheckins.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    private var completedCheckins: [Checkin] {
        weekCheckins.filter { $0.status == "completed" }
    }

    private var partialCheckins: [Checkin] {
        weekCheckins.filter { $0.status == "partial" || $0.status == "archived" }
    }

    private var weekCheckins: [Checkin] {
        guard let weekStart = startOfWeek(for: session.date),
              let weekEnd = Calendar(identifier: .iso8601).date(byAdding: .day, value: 6, to: weekStart) else {
            return checkins
        }
        let start = dateString(weekStart)
        let end = dateString(weekEnd)
        return checkins.filter { $0.date >= start && $0.date <= end }
    }

    private var priorities: [String] {
        [firstPriority, secondPriority, thirdPriority].compactMap { trimmed($0).isEmpty ? nil : trimmed($0) }
    }

    private func loadWorkspace() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedContext = userContextAPI.get()
            async let loadedCheckins = checkinAPI.list()
            context = try await loadedContext
            checkins = try await loadedCheckins
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateDraft(from context: UserContext) {
        isGenerating = true
        defer {
            isGenerating = false
            hasDraft = true
        }

        let completed = completedCheckins.map { $0.summary }.filter { !trimmed($0).isEmpty }
        completionSummary = completed.isEmpty
            ? "本周尚未形成归档记录；已确认当前重点是：\(context.plan.weeklyFocus)"
            : completed.prefix(3).joined(separator: "\n")

        let partial = partialCheckins.map { checkin in
            let next = trimmed(checkin.nextAction)
            return next.isEmpty ? checkin.summary : "\(checkin.summary) 下一步：\(next)"
        }.filter { !trimmed($0).isEmpty }
        blockers = partial.isEmpty
            ? "暂无未完成归档；复盘时确认是否有需要缩小范围或延后处理的事项。"
            : partial.prefix(3).joined(separator: "\n")

        nextWeekFocus = context.plan.weeklyFocus
        let existingTasks = context.plan.activeTasks.filter { !trimmed($0).isEmpty }
        firstPriority = existingTasks.indices.contains(0) ? existingTasks[0] : context.plan.nextAction
        secondPriority = existingTasks.indices.contains(1) ? existingTasks[1] : "处理本周未完成项，形成明确的继续、跟踪或放弃判断。"
        thirdPriority = existingTasks.indices.contains(2) ? existingTasks[2] : "完成一次 Check-in，并把结论沉淀到归档。"
        saveMessage = nil
    }

    private func saveNextWeekPlan(from context: UserContext) async {
        isSaving = true
        errorMessage = nil
        saveMessage = nil
        defer { isSaving = false }

        var updated = context
        updated.plan.weeklyFocus = trimmed(nextWeekFocus)
        updated.plan.activeTasks = priorities
        updated.plan.nextAction = priorities.first ?? trimmed(nextWeekFocus)

        do {
            self.context = try await userContextAPI.save(updated)
            saveMessage = "下周计划已保存到计划上下文。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startOfWeek(for value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else {
            return nil
        }
        return Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: date)?.start
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct WeeklyStudioLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "尚未填写。" : value)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
