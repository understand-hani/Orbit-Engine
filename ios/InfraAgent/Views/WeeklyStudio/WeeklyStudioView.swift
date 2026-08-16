import SwiftUI

struct WeeklyStudioView: View {
    let session: BaseSession
    var onArchived: ((BaseSession) -> Void)?
    @State private var context: UserContext?
    @State private var checkins: [Checkin] = []
    @State private var weekSessions: [BaseSession] = []
    @State private var isLoading = true
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var isArchiving = false
    @State private var hasDraft = false
    @State private var completionSummary = ""
    @State private var firstPriority = ""
    @State private var secondPriority = ""
    @State private var thirdPriority = ""
    @State private var errorMessage: String?
    @State private var saveMessage: String?
    @State private var draftProvider = ""

    private let userContextAPI = UserContextAPI()
    private let checkinAPI = CheckinAPI()
    private let sessionAPI = SessionAPI()

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

                Section {
                    ForEach(weekPlanItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.statusText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("本周计划进度")
                } footer: {
                    Text("本周归档：已完成 \(completedCheckins.count) 条 · 未完成归档 \(partialCheckins.count) 条")
                }

                if !hasDraft {
                    Section {
                        Button {
                            Task { await generateDraft() }
                        } label: {
                            Label(isGenerating ? "正在生成 Weekly Studio" : "生成 Weekly Studio", systemImage: "sparkles")
                        }
                        .disabled(isGenerating)
                    } footer: {
                        Text("Agent 基于本周 Radar、Deep Dive 和 Check-in 总结；优先顺序只在原计划内做小范围调整。")
                    }
                } else {
                    Section("本周学习总结（已完成归档）") {
                        Text(completionSummary)
                            .font(.subheadline)
                    }

                    Section("下周优先顺序") {
                        TextField("优先任务 1", text: $firstPriority, axis: .vertical)
                            .lineLimit(2...3)
                        TextField("优先任务 2", text: $secondPriority, axis: .vertical)
                            .lineLimit(2...3)
                        TextField("优先任务 3", text: $thirdPriority, axis: .vertical)
                            .lineLimit(2...3)
                    }

                    if !draftProvider.isEmpty {
                        Text(draftProvider == "openrouter"
                            ? "Agent 已读取本周 Radar、Deep Dive 与 Check-in；不重写本周重点或任务列表。"
                            : "当前为结构化总结：已读取本周 Radar、Deep Dive 与 Check-in；不重写本周重点或任务列表。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                            Task { await saveNextAction(from: context) }
                        } label: {
                            Label(isSaving ? "正在同步下一步" : "同步下一步到计划", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(isSaving || priorities.isEmpty)
                    } footer: {
                        Text("只同步首项优先任务为下一步；本周重点和任务列表保持不变。")
                    }
                }
            }

            Section("Weekly Studio 去向") {
                Button {
                    Task { await archiveWeeklyStudio() }
                } label: {
                    Label(isArchiving ? "正在加入暂存" : "加入暂存", systemImage: "archivebox")
                }
                .disabled(isArchiving)

                Text("暂存后会以「\(session.title)」整卡进入归档页，可在那里恢复。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Weekly Studio")
        .task {
            await loadWorkspace()
        }
    }

    private var weekPlanItems: [WeekPlanItem] {
        guard let weekStart = startOfWeek(for: session.date) else { return [] }
        let calendar = Calendar(identifier: .iso8601)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dateValue = dateString(day)
            let weekday = calendar.component(.weekday, from: day)
            guard scheduleTypeTitle(weekday) != "Weekly Studio" else { return nil }
            let daySessions = weekSessions.filter { $0.date == dateValue }
            let isCompleted = daySessions.contains { $0.status == .completed || $0.status == .archived }
            return WeekPlanItem(
                id: dateValue,
                title: "\(weekdayLabel(weekday)) \(shortDate(dateValue)) · \(scheduleTypeTitle(weekday))",
                isCompleted: isCompleted,
                subtitle: daySessions.first?.title ?? ""
            )
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        default: return "周日"
        }
    }

    private func scheduleTypeTitle(_ weekday: Int) -> String {
        switch weekday {
        case 1, 2: return "Signal Radar"
        case 3: return "Opportunity Alignment"
        case 4, 5: return "Deep Dive"
        default: return "Weekly Studio"
        }
    }

    private func shortDate(_ value: String) -> String {
        String(value.dropFirst(5))
    }

    private func loadWeekSessions() async throws -> [BaseSession] {
        guard let weekStart = startOfWeek(for: session.date) else { return [] }
        let calendar = Calendar(identifier: .iso8601)
        var all: [BaseSession] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            all += try await sessionAPI.sessionsByDate(dateString(day))
        }
        return all
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
            async let loadedWeekSessions = loadWeekSessions()
            context = try await loadedContext
            checkins = try await loadedCheckins
            weekSessions = try await loadedWeekSessions
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyLocalDraft() {
        let insights = completedCheckins.compactMap { checkin -> String? in
            let insight = trimmed(checkin.keyInsight)
            if !insight.isEmpty {
                return String(insight.prefix(180))
            }
            let summary = trimmed(checkin.summary)
            return summary.isEmpty ? nil : String(summary.prefix(180))
        }
        if insights.isEmpty {
            completionSummary = "本周尚无完成归档可供总结；下一周继续完成一个可验证的最小学习闭环。"
        } else {
            completionSummary = "本周已沉淀：\(insights.prefix(2).joined(separator: "；"))"
        }

        let fallbackPriorities = context?.plan.activeTasks.filter { !trimmed($0).isEmpty }.prefix(3) ?? []
        let priorities = Array(fallbackPriorities)
        firstPriority = priorities.indices.contains(0) ? priorities[0] : (context?.plan.nextAction ?? "")
        secondPriority = priorities.indices.contains(1) ? priorities[1] : ""
        thirdPriority = priorities.indices.contains(2) ? priorities[2] : ""
        draftProvider = "local"
        hasDraft = true
    }

    private func generateDraft() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            let draft = try await sessionAPI.draftWeeklyStudio(sessionID: session.id)
            completionSummary = draft.completionSummary
            let priorities = draft.suggestedPriorities
            firstPriority = priorities.indices.contains(0) ? priorities[0] : ""
            secondPriority = priorities.indices.contains(1) ? priorities[1] : ""
            thirdPriority = priorities.indices.contains(2) ? priorities[2] : ""
            draftProvider = draft.provider
            saveMessage = nil
            hasDraft = true
        } catch {
            applyLocalDraft()
            errorMessage = nil
            saveMessage = "远端 Agent 暂未响应，已使用本周记录生成结构化草稿。"
        }
    }

    private func saveNextAction(from context: UserContext) async {
        isSaving = true
        errorMessage = nil
        saveMessage = nil
        defer { isSaving = false }

        var updated = context
        updated.plan.nextAction = priorities[0]

        do {
            self.context = try await userContextAPI.save(updated)
            saveMessage = "下一步已同步到计划；本周重点和任务列表未改动。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveWeeklyStudio() async {
        isArchiving = true
        errorMessage = nil
        defer { isArchiving = false }

        do {
            try await sessionAPI.archive(id: session.id)
            let archivedSession = try await sessionAPI.session(id: session.id)
            onArchived?(archivedSession)
        } catch {
            errorMessage = "Weekly Studio 暂存失败：\(error.localizedDescription)"
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

private struct WeekPlanItem: Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let subtitle: String

    var statusText: String { isCompleted ? "已完成" : "未完成" }
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
