import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TaskDetailView: View {
    let task: TaskProfile

    @State private var plan: TaskHierarchyPlan

    init(task: TaskProfile) {
        self.task = task
        _plan = State(initialValue: TaskHierarchyStore.plan(for: task))
    }

    var body: some View {
        List {
            Section("Period") {
                ForEach(plan.periods) { period in
                    NavigationLink {
                        PeriodDetailView(taskID: task.id, period: period) {
                            reload()
                        }
                    } label: {
                        PeriodCardView(period: period)
                    }
                }
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !TaskHierarchyStore.hasSavedPlan(for: task.id) {
                TaskHierarchyStore.save(plan, for: task.id)
            }
            reload()
        }
    }

    private func reload() {
        plan = TaskHierarchyStore.plan(for: task)
    }

    static func hasSavedLocalProgress(for task: TaskProfile) -> Bool {
        TaskHierarchyStore.hasSavedPlan(for: task.id)
    }
}

struct PeriodCardView: View {
    let period: PeriodPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(period.title)
                    .font(.headline)
                Spacer()
                Text("\(period.completedDayCount)/\(period.totalDayCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(period.goal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            TagRow(tags: [period.duration, "\(period.weeks.count) 周"])
        }
        .padding(.vertical, 4)
    }
}

struct WeekCardView: View {
    let week: WeekPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(week.title)
                    .font(.headline)
                Spacer()
                Text("\(week.completedDayCount)/\(week.days.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(week.goal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if !week.summary.isEmpty {
                Text(week.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DayCardView: View {
    let day: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.title)
                .font(.headline)
            Text(day.workContent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if !day.output.isEmpty {
                LabeledContent("产出", value: day.output)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TaskPlanOverviewEditView: View {
    let task: TaskProfile
    let plan: TaskHierarchyPlan
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var summary: String
    @State private var status: String
    @State private var currentPhase: String
    @State private var weeklySlot: String

    init(task: TaskProfile, plan: TaskHierarchyPlan, onSaved: @escaping () -> Void) {
        self.task = task
        self.plan = plan
        self.onSaved = onSaved
        _title = State(initialValue: plan.title)
        _summary = State(initialValue: plan.summary)
        _status = State(initialValue: plan.status)
        _currentPhase = State(initialValue: plan.currentPhase)
        _weeklySlot = State(initialValue: plan.weeklySlot)
    }

    var body: some View {
        Form {
            Section("任务概要") {
                TextField("标题", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                TextField("概要", text: $summary, axis: .vertical)
                    .lineLimit(3...8)
                TextField("状态", text: $status)
                TextField("当前阶段", text: $currentPhase, axis: .vertical)
                    .lineLimit(1...3)
                TextField("每周时间槽", text: $weeklySlot)
            }

            Section {
                Button {
                    var updated = TaskHierarchyStore.plan(for: task)
                    updated.title = title
                    updated.summary = summary
                    updated.status = status
                    updated.currentPhase = currentPhase
                    updated.weeklySlot = weeklySlot
                    TaskHierarchyStore.save(updated, for: task.id)
                    onSaved()
                    dismiss()
                } label: {
                    Label("保存任务概要", systemImage: "tray.and.arrow.down")
                }
            }
        }
        .navigationTitle("编辑任务概要")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PeriodDetailView: View {
    let taskID: String
    let period: PeriodPlan
    let onSaved: () -> Void

    @State private var localPeriod: PeriodPlan
    @State private var title: String
    @State private var goal: String
    @State private var summary: String
    @State private var duration: String
    @State private var exportMessage: String?
    @State private var isShowingPDFExporter = false
    @State private var pdfDocument = PeriodPDFDocument(data: Data())

    init(taskID: String, period: PeriodPlan, onSaved: @escaping () -> Void) {
        self.taskID = taskID
        self.period = period
        self.onSaved = onSaved
        _localPeriod = State(initialValue: period)
        _title = State(initialValue: period.title)
        _goal = State(initialValue: period.goal)
        _summary = State(initialValue: period.summary)
        _duration = State(initialValue: period.duration)
    }

    var body: some View {
        List {
            Section("Period 目标") {
                TextField("Period 标题", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                TextField("阶段目标", text: $goal, axis: .vertical)
                    .lineLimit(3...8)
                TextField("主要任务概要", text: $summary, axis: .vertical)
                    .lineLimit(3...8)
                TextField("持续时间", text: $duration)
            }

            Section("Week") {
                ForEach(localPeriod.weeks) { week in
                    NavigationLink {
                        WeekDetailView(taskID: taskID, periodID: localPeriod.id, week: week) {
                            reload()
                            onSaved()
                        }
                    } label: {
                        WeekCardView(week: week)
                    }
                }
            }

            Section("导出") {
                Button {
                    exportPDF()
                } label: {
                    Label("导出 PDF 到文件", systemImage: "doc.richtext")
                }

                Button {
                    saveImageToPhotos()
                } label: {
                    Label("保存图片到相册", systemImage: "photo")
                }

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(localPeriod.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reload()
        }
        .onChange(of: title) { _ in
            savePeriodOverview()
        }
        .onChange(of: goal) { _ in
            savePeriodOverview()
        }
        .onChange(of: summary) { _ in
            savePeriodOverview()
        }
        .onChange(of: duration) { _ in
            savePeriodOverview()
        }
        .onDisappear {
            savePeriodOverview()
        }
        .fileExporter(
            isPresented: $isShowingPDFExporter,
            document: pdfDocument,
            contentType: .pdf,
            defaultFilename: PeriodExportBuilder.fileName(for: localPeriod, extensionName: "pdf")
        ) { result in
            switch result {
            case .success:
                exportMessage = "PDF 已保存到文件。"
            case .failure(let error):
                exportMessage = "PDF 保存失败：\(error.localizedDescription)"
            }
        }
    }

    private func reload() {
        if let updated = TaskHierarchyStore.plan(taskID: taskID).periods.first(where: { $0.id == period.id }) {
            localPeriod = updated
            title = updated.title
            goal = updated.goal
            summary = updated.summary
            duration = updated.duration
        }
    }

    private func savePeriodOverview() {
        localPeriod.title = title
        localPeriod.goal = goal
        localPeriod.summary = summary
        localPeriod.duration = duration
        TaskHierarchyStore.updatePeriod(localPeriod, taskID: taskID)
        onSaved()
    }

    private func exportPDF() {
        savePeriodOverview()
        do {
            pdfDocument = PeriodPDFDocument(data: PeriodExportBuilder.pdfData(for: localPeriod))
            isShowingPDFExporter = true
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func saveImageToPhotos() {
        savePeriodOverview()
        let image = PeriodExportBuilder.image(for: localPeriod)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        exportMessage = "图片已保存到相册。"
    }
}

struct WeekDetailView: View {
    let taskID: String
    let periodID: String
    let week: WeekPlan
    let onSaved: () -> Void

    @State private var localWeek: WeekPlan
    @State private var title: String
    @State private var goal: String
    @State private var summary: String

    init(taskID: String, periodID: String, week: WeekPlan, onSaved: @escaping () -> Void) {
        self.taskID = taskID
        self.periodID = periodID
        self.week = week
        self.onSaved = onSaved
        _localWeek = State(initialValue: week)
        _title = State(initialValue: week.title)
        _goal = State(initialValue: week.goal)
        _summary = State(initialValue: week.summary)
    }

    var body: some View {
        List {
            Section("Week 目标") {
                TextField("Week 标题", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                TextField("本周目标", text: $goal, axis: .vertical)
                    .lineLimit(3...8)
                TextField("主要任务概要", text: $summary, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Day") {
                ForEach(localWeek.days) { day in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            toggleDay(day)
                        } label: {
                            Image(systemName: day.isDone ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(day.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.borderless)

                        NavigationLink {
                            DayDetailView(taskID: taskID, periodID: periodID, weekID: localWeek.id, day: day) {
                                reload()
                                onSaved()
                            }
                        } label: {
                            DayCardView(day: day)
                        }
                    }
                }
            }
        }
        .navigationTitle(localWeek.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reload()
        }
        .onChange(of: title) { _ in
            saveWeekOverview()
        }
        .onChange(of: goal) { _ in
            saveWeekOverview()
        }
        .onChange(of: summary) { _ in
            saveWeekOverview()
        }
        .onDisappear {
            saveWeekOverview()
        }
    }

    private func reload() {
        if let updated = TaskHierarchyStore.week(taskID: taskID, periodID: periodID, weekID: week.id) {
            localWeek = updated
            title = updated.title
            goal = updated.goal
            summary = updated.summary
        }
    }

    private func saveWeekOverview() {
        localWeek.title = title
        localWeek.goal = goal
        localWeek.summary = summary
        TaskHierarchyStore.updateWeek(localWeek, taskID: taskID, periodID: periodID)
        onSaved()
    }

    private func toggleDay(_ day: DayPlan) {
        var updated = day
        updated.isDone.toggle()
        TaskHierarchyStore.updateDay(updated, taskID: taskID, periodID: periodID, weekID: localWeek.id)
        reload()
        onSaved()
    }
}

struct DayDetailView: View {
    let taskID: String
    let periodID: String
    let weekID: String
    let day: DayPlan
    let onSaved: () -> Void

    @State private var title: String
    @State private var workContent: String
    @State private var output: String
    @State private var note: String
    @State private var isDone: Bool

    init(taskID: String, periodID: String, weekID: String, day: DayPlan, onSaved: @escaping () -> Void) {
        self.taskID = taskID
        self.periodID = periodID
        self.weekID = weekID
        self.day = day
        self.onSaved = onSaved
        _title = State(initialValue: day.title)
        _workContent = State(initialValue: day.workContent)
        _output = State(initialValue: day.output)
        _note = State(initialValue: day.note)
        _isDone = State(initialValue: day.isDone)
    }

    var body: some View {
        Form {
            Section("Day 任务") {
                TextField("标题", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                TextField("工作内容", text: $workContent, axis: .vertical)
                    .lineLimit(4...10)
                TextField("预期产出", text: $output, axis: .vertical)
                    .lineLimit(2...6)
                TextField("记录/阻塞/证据", text: $note, axis: .vertical)
                    .lineLimit(3...8)
                Toggle("已完成", isOn: $isDone)
                    .onChange(of: isDone) { _ in
                        saveDay()
                    }
            }
        }
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: title) { _ in
            saveDay()
        }
        .onChange(of: workContent) { _ in
            saveDay()
        }
        .onChange(of: output) { _ in
            saveDay()
        }
        .onChange(of: note) { _ in
            saveDay()
        }
        .onDisappear {
            saveDay()
        }
    }

    private func saveDay() {
        let updated = DayPlan(
            id: day.id,
            title: title,
            workContent: workContent,
            output: output,
            note: note,
            isDone: isDone
        )
        TaskHierarchyStore.updateDay(updated, taskID: taskID, periodID: periodID, weekID: weekID)
        onSaved()
    }
}

struct PeriodPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum PeriodExportBuilder {
    static func pdfData(for period: PeriodPlan) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        return renderer.pdfData { context in
            context.beginPage()
            draw(lines: lines(for: period), in: pageBounds) {
                context.beginPage()
            }
        }
    }

    static func image(for period: PeriodPlan) -> UIImage {
        let width: CGFloat = 900
        let margin: CGFloat = 48
        let lines = lines(for: period)
        let height = estimatedHeight(for: lines, width: width - margin * 2) + margin * 2
        let size = CGSize(width: width, height: max(height, 600))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(lines: lines, in: CGRect(origin: .zero, size: size), startsNewPage: nil)
        }
        return image
    }

    private static func lines(for period: PeriodPlan) -> [ExportLine] {
        var output: [ExportLine] = [
            ExportLine(text: period.title, style: .title),
            ExportLine(text: "周期：\(period.duration)", style: .caption),
            ExportLine(text: "目标：\(period.goal)", style: .body),
            ExportLine(text: "概要：\(period.summary)", style: .body),
            ExportLine(text: "", style: .body),
        ]

        for week in period.weeks {
            output.append(ExportLine(text: week.title, style: .heading))
            output.append(ExportLine(text: "目标：\(week.goal)", style: .body))
            if !week.summary.isEmpty {
                output.append(ExportLine(text: "概要：\(week.summary)", style: .body))
            }
            for day in week.days {
                output.append(ExportLine(text: "\(day.isDone ? "[x]" : "[ ]") \(day.title)", style: .subheading))
                output.append(ExportLine(text: day.workContent, style: .body))
                if !day.output.isEmpty {
                    output.append(ExportLine(text: "产出：\(day.output)", style: .caption))
                }
                if !day.note.isEmpty {
                    output.append(ExportLine(text: "记录：\(day.note)", style: .caption))
                }
            }
            output.append(ExportLine(text: "", style: .body))
        }
        return output
    }

    private static func draw(lines: [ExportLine], in bounds: CGRect, startsNewPage: (() -> Void)?) {
        let margin: CGFloat = 48
        let maxWidth = bounds.width - margin * 2
        var y = margin

        for line in lines {
            let attributes = line.attributes
            let height = line.height(width: maxWidth)
            if y + height > bounds.height - margin, let startsNewPage {
                startsNewPage()
                y = margin
            }
            line.text.draw(
                with: CGRect(x: margin, y: y, width: maxWidth, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            y += height + line.spacingAfter
        }
    }

    private static func estimatedHeight(for lines: [ExportLine], width: CGFloat) -> CGFloat {
        lines.reduce(CGFloat(0)) { $0 + $1.height(width: width) + $1.spacingAfter }
    }

    static func fileName(for period: PeriodPlan, extensionName: String) -> String {
        let safeName = period.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "\(safeName).\(extensionName)"
    }
}

private struct ExportLine {
    enum Style {
        case title
        case heading
        case subheading
        case body
        case caption
    }

    let text: String
    let style: Style

    var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        switch style {
        case .title:
            return [.font: UIFont.boldSystemFont(ofSize: 26), .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
        case .heading:
            return [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
        case .subheading:
            return [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
        case .body:
            return [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
        case .caption:
            return [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel, .paragraphStyle: paragraph]
        }
    }

    var spacingAfter: CGFloat {
        switch style {
        case .title:
            return 18
        case .heading:
            return 10
        case .subheading:
            return 6
        case .body:
            return 8
        case .caption:
            return 6
        }
    }

    func height(width: CGFloat) -> CGFloat {
        if text.isEmpty {
            return 8
        }
        return (text as NSString)
            .boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            .height
            .rounded(.up)
    }
}

struct TaskHierarchyPlan: Codable, Identifiable {
    let id: String
    var title: String
    var summary: String
    var status: String
    var currentPhase: String
    var weeklySlot: String
    var periods: [PeriodPlan]
}

struct PeriodPlan: Codable, Identifiable {
    let id: String
    var title: String
    var duration: String
    var goal: String
    var summary: String
    var weeks: [WeekPlan]

    var completedDayCount: Int {
        weeks.reduce(0) { $0 + $1.completedDayCount }
    }

    var totalDayCount: Int {
        weeks.reduce(0) { $0 + $1.days.count }
    }
}

struct WeekPlan: Codable, Identifiable {
    let id: String
    var title: String
    var goal: String
    var summary: String
    var days: [DayPlan]

    var completedDayCount: Int {
        days.filter(\.isDone).count
    }
}

struct DayPlan: Codable, Identifiable {
    let id: String
    var title: String
    var workContent: String
    var output: String
    var note: String
    var isDone: Bool
}

enum TaskHierarchyStore {
    private static let key = "jd_task_hierarchy_plans"
    static let importedTaskID = "local_imported_periods"
    static var importedTask: TaskProfile {
        TaskProfile(
            id: importedTaskID,
            title: "本地导入任务",
            category: "local_import",
            status: "active",
            currentPhase: "本地导入",
            relatedSkillIDs: [],
            deadline: nil,
            weeklySlot: "custom",
            progressSummary: "从本地 JSON 导入的 Period。",
            blockers: [],
            nextMilestone: "",
            evidenceOutputs: [],
            adjustability: "high"
        )
    }

    static func plan(for task: TaskProfile) -> TaskHierarchyPlan {
        if let saved = plans()[task.id] {
            return saved
        }
        return defaultPlan(for: LocalTaskStateStore.apply(to: task))
    }

    static func plan(taskID: String) -> TaskHierarchyPlan {
        plans()[taskID] ?? defaultPlan(for: fallbackTask(taskID: taskID))
    }

    static func save(_ plan: TaskHierarchyPlan, for taskID: String) {
        var values = plans()
        values[taskID] = plan
        persist(values)
    }

    static func reset(taskID: String) {
        var values = plans()
        values.removeValue(forKey: taskID)
        persist(values)
    }

    static func hasSavedPlan(for taskID: String) -> Bool {
        plans()[taskID] != nil
    }

    static func updatePeriod(_ period: PeriodPlan, taskID: String) {
        var plan = plan(taskID: taskID)
        plan.periods = plan.periods.map { $0.id == period.id ? period : $0 }
        save(plan, for: taskID)
    }

    static func appendImportedPeriods(_ periods: [PeriodPlan]) {
        var plan = importedPlan()
        let existingIDs = Set(plan.periods.map(\.id))
        let normalized = periods.enumerated().map { index, period in
            var imported = period
            if existingIDs.contains(imported.id) || imported.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                imported = PeriodPlan(
                    id: "imported_period_\(Int(Date().timeIntervalSince1970))_\(index + 1)",
                    title: period.title,
                    duration: period.duration,
                    goal: period.goal,
                    summary: period.summary,
                    weeks: period.weeks
                )
            }
            return imported
        }
        plan.periods.append(contentsOf: normalized)
        save(plan, for: importedTaskID)
    }

    private static func importedPlan() -> TaskHierarchyPlan {
        if let saved = plans()[importedTaskID] {
            return saved
        }
        return TaskHierarchyPlan(
            id: importedTaskID,
            title: importedTask.title,
            summary: importedTask.progressSummary,
            status: importedTask.status,
            currentPhase: importedTask.currentPhase,
            weeklySlot: importedTask.weeklySlot,
            periods: []
        )
    }

    static func deletePeriod(taskID: String, periodID: String) {
        var plan = plan(taskID: taskID)
        plan.periods.removeAll { $0.id == periodID }
        save(plan, for: taskID)
    }

    static func updateWeek(_ week: WeekPlan, taskID: String, periodID: String) {
        var plan = plan(taskID: taskID)
        plan.periods = plan.periods.map { period in
            guard period.id == periodID else { return period }
            var updated = period
            updated.weeks = period.weeks.map { $0.id == week.id ? week : $0 }
            return updated
        }
        save(plan, for: taskID)
    }

    static func updateDay(_ day: DayPlan, taskID: String, periodID: String, weekID: String) {
        var plan = plan(taskID: taskID)
        plan.periods = plan.periods.map { period in
            guard period.id == periodID else { return period }
            var updatedPeriod = period
            updatedPeriod.weeks = period.weeks.map { week in
                guard week.id == weekID else { return week }
                var updatedWeek = week
                updatedWeek.days = week.days.map { $0.id == day.id ? day : $0 }
                return updatedWeek
            }
            return updatedPeriod
        }
        save(plan, for: taskID)
    }

    static func week(taskID: String, periodID: String, weekID: String) -> WeekPlan? {
        plan(taskID: taskID)
            .periods
            .first(where: { $0.id == periodID })?
            .weeks
            .first(where: { $0.id == weekID })
    }

    private static func plans() -> [String: TaskHierarchyPlan] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode([String: TaskHierarchyPlan].self, from: data) else {
            return [:]
        }
        return values
    }

    private static func persist(_ values: [String: TaskHierarchyPlan]) {
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func fallbackTask(taskID: String) -> TaskProfile {
        TaskProfile(
            id: taskID,
            title: "自定义任务",
            category: "custom",
            status: "active",
            currentPhase: "",
            relatedSkillIDs: [],
            deadline: nil,
            weeklySlot: "",
            progressSummary: "",
            blockers: [],
            nextMilestone: "",
            evidenceOutputs: [],
            adjustability: "medium"
        )
    }

    private static func defaultPlan(for task: TaskProfile) -> TaskHierarchyPlan {
        let periods: [PeriodPlan]
        if task.id.contains("reconstruction") || task.category == "reconstruction_line" {
            periods = [
                PeriodPlan(
                    id: "\(task.id)_period_reconstruction",
                    title: "Period 1：重建线证据收口",
                    duration: "Week 7-8",
                    goal: task.nextMilestone.nonEmptyValue ?? "完成 StreetGaussian / 4DGS 重建线 baseline 与证据整理。",
                    summary: task.progressSummary.nonEmptyValue ?? "跑通 baseline，观察 artifact，产出视频和技术复盘。",
                    weeks: [
                        WeekPlan(
                            id: "\(task.id)_week_7",
                            title: "Week 7：StreetGaussian baseline",
                            goal: "建立可运行的动态场景重建 baseline。",
                            summary: "跑官方 demo、检查渲染质量、记录问题归因。",
                            days: [
                                DayPlan(id: "\(task.id)_w7_d1", title: "Day 1：环境和数据", workContent: "准备 StreetGaussian、Waymo/nuScenes demo 数据和 GT boxes，排除依赖问题。", output: "可运行训练/推理入口", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w7_d2", title: "Day 2：渲染质量检查", workContent: "渲染原始帧和重建帧，检查清晰度、动态物体和 artifact。", output: "before/after 视频或截图", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w7_d3", title: "Day 3：失败模式归因", workContent: "区分背景、天空、SfM、动态车辆造成的问题。", output: "artifact 归因记录", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w7_d4", title: "Day 4：轻量改动判断", workContent: "判断是否值得接入光流/MUSt3R mask，避免无目标试错。", output: "是否继续 mask 实验的判断", note: "", isDone: false),
                            ]
                        ),
                        WeekPlan(
                            id: "\(task.id)_week_8",
                            title: "Week 8：机制理解和收口",
                            goal: "理解 object/background decomposition，并完成重建线阶段复盘。",
                            summary: "解释 GT boxes/tracklets、局部坐标 object Gaussians 和组合渲染逻辑。",
                            days: [
                                DayPlan(id: "\(task.id)_w8_d1", title: "Day 1：背景/物体分解", workContent: "梳理 background Gaussians 和 object Gaussians 如何分离。", output: "机制笔记", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w8_d2", title: "Day 2：tracklet 作用", workContent: "解释 GT tracking boxes 提供的 mask、实例关联、extent 和 pose trajectory。", output: "tracklet 技术说明", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w8_d3", title: "Day 3：渲染组合", workContent: "理解 object local frame 到 world frame 的转换和最终渲染组合。", output: "流程图或文字说明", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w8_d4", title: "Day 4：阶段复盘", workContent: "整理视频、artifact attribution、指标和下一方向判断。", output: "重建线 retrospective", note: "", isDone: false),
                            ]
                        ),
                    ]
                )
            ]
        } else if task.id.contains("world_model") || task.category == "world_model_line" {
            periods = [
                PeriodPlan(
                    id: "\(task.id)_period_world_model",
                    title: "Period 1：Driving World Model 入门",
                    duration: "Week 9-10",
                    goal: task.nextMilestone.nonEmptyValue ?? "跑通一个轻量驾驶视频生成/WM demo。",
                    summary: task.progressSummary.nonEmptyValue ?? "理解 history observation、action/trajectory condition 和 rollout 输出。",
                    weeks: [
                        WeekPlan(
                            id: "\(task.id)_week_9",
                            title: "Week 9：选择并跑通一个候选模型",
                            goal: "用 inference/demo 建立 WM 输入输出直觉。",
                            summary: "选择轻量 repo，跑官方 demo，理解数据接口。",
                            days: [
                                DayPlan(id: "\(task.id)_w9_d1", title: "Day 1：选择 repo", workContent: "比较 Vista/DriveX、DriveDreamer4D 等候选，选择最轻量可跑路径。", output: "候选模型选择记录", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w9_d2", title: "Day 2：跑官方 demo", workContent: "不训练，先跑通 inference/demo，确认输出形式。", output: "demo 输出", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w9_d3", title: "Day 3：数据接口", workContent: "梳理 history、ego trajectory/action、map/text/camera condition。", output: "数据接口笔记", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w9_d4", title: "Day 4：机制记录", workContent: "记录 world state、condition、action-conditioned rollout 与 4DGS 的差异。", output: "WM 机制笔记", note: "", isDone: false),
                            ]
                        ),
                        WeekPlan(
                            id: "\(task.id)_week_10",
                            title: "Week 10：深化接口和方向比较",
                            goal: "比较重建线和生成线，准备方向判断。",
                            summary: "继续 dissect inference path，或切换第二候选 demo。",
                            days: [
                                DayPlan(id: "\(task.id)_w10_d1", title: "Day 1：保留或切换", workContent: "复盘 Week 9 demo，决定继续当前 repo 还是换候选。", output: "候选保留/切换判断", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w10_d2", title: "Day 2：推理路径", workContent: "梳理 config、checkpoint、condition encoding、inference entrypoint。", output: "推理路径笔记", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w10_d3", title: "Day 3：nuScenes/Waymo 小样本", workContent: "确认小样本接入需要的转换、可视化或 blocker。", output: "转换样例或 blocker list", note: "", isDone: false),
                                DayPlan(id: "\(task.id)_w10_d4", title: "Day 4：方向比较", workContent: "按输入输出、状态、控制性、泛化、训练成本和 JD 对齐比较两条线。", output: "重建 vs WM 比较表", note: "", isDone: false),
                            ]
                        ),
                    ]
                )
            ]
        } else {
            periods = [
                PeriodPlan(
                    id: "\(task.id)_period_1",
                    title: "Period 1：阶段任务",
                    duration: task.weeklySlot.nonEmptyValue ?? "待定",
                    goal: task.nextMilestone.nonEmptyValue ?? task.title,
                    summary: task.progressSummary.nonEmptyValue ?? "把任务拆成可执行的周任务和日任务。",
                    weeks: [
                        WeekPlan(
                            id: "\(task.id)_week_1",
                            title: "Week 1：默认周任务",
                            goal: task.nextMilestone.nonEmptyValue ?? task.title,
                            summary: task.progressSummary,
                            days: TaskTodoItem.items(for: task).enumerated().map { index, item in
                                DayPlan(
                                    id: "\(task.id)_day_\(index + 1)",
                                    title: "Day \(index + 1)：\(item.title)",
                                    workContent: item.detail,
                                    output: task.evidenceOutputs.first ?? "",
                                    note: "",
                                    isDone: false
                                )
                            }
                        )
                    ]
                )
            ]
        }

        return TaskHierarchyPlan(
            id: task.id,
            title: task.title,
            summary: task.progressSummary.nonEmptyValue ?? task.nextMilestone,
            status: task.status,
            currentPhase: task.currentPhase,
            weeklySlot: task.weeklySlot,
            periods: periods
        )
    }
}

struct LocalTaskOverride: Codable {
    let title: String
    let status: String
    let currentPhase: String
    let weeklySlot: String
    let progressSummary: String
    let nextMilestone: String
    let adjustability: String
    let blockersText: String
    let evidenceOutputsText: String
}

enum LocalTaskStateStore {
    private static let key = "jd_task_state_overrides"

    static func apply(to task: TaskProfile) -> TaskProfile {
        guard let override = overrides()[task.id] else { return task }
        return TaskProfile(
            id: task.id,
            title: override.title.nonEmptyValue ?? task.title,
            category: task.category,
            status: override.status.nonEmptyValue ?? task.status,
            currentPhase: override.currentPhase.nonEmptyValue ?? task.currentPhase,
            relatedSkillIDs: task.relatedSkillIDs,
            deadline: task.deadline,
            weeklySlot: override.weeklySlot.nonEmptyValue ?? task.weeklySlot,
            progressSummary: override.progressSummary.nonEmptyValue ?? task.progressSummary,
            blockers: lines(from: override.blockersText) ?? task.blockers,
            nextMilestone: override.nextMilestone.nonEmptyValue ?? task.nextMilestone,
            evidenceOutputs: lines(from: override.evidenceOutputsText) ?? task.evidenceOutputs,
            adjustability: override.adjustability.nonEmptyValue ?? task.adjustability
        )
    }

    static func save(_ override: LocalTaskOverride, for taskID: String) {
        var values = overrides()
        values[taskID] = override
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func remove(for taskID: String) {
        var values = overrides()
        values.removeValue(forKey: taskID)
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func hasOverride(for taskID: String) -> Bool {
        overrides()[taskID] != nil
    }

    private static func overrides() -> [String: LocalTaskOverride] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode([String: LocalTaskOverride].self, from: data) else {
            return [:]
        }
        return values
    }

    private static func lines(from value: String) -> [String]? {
        let lines = value
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct TaskTodoItem: Identifiable {
    let id: String
    let title: String
    let detail: String

    static func items(for task: TaskProfile) -> [TaskTodoItem] {
        if task.id.contains("reconstruction") || task.category == "reconstruction_line" {
            return [
                TaskTodoItem(id: "\(task.id)_baseline", title: "跑通 StreetGaussian nuScenes baseline", detail: "建立可运行 baseline，并排除依赖和环境问题。"),
                TaskTodoItem(id: "\(task.id)_render", title: "确认渲染质量", detail: "产出第一版 before/after 视觉信号，并检查 artifact。"),
                TaskTodoItem(id: "\(task.id)_filtering", title: "连接 SLAM 几何过滤", detail: "对比无标注过滤和 GT box 动态分离。"),
                TaskTodoItem(id: "\(task.id)_metrics", title: "记录指标和证据", detail: "记录动态区域 PSNR/SSIM、对比视频和技术结论。"),
            ]
        }

        if task.id.contains("world_model") || task.category == "world_model_line" {
            return [
                TaskTodoItem(id: "\(task.id)_select", title: "选择轻量 WM 候选模型", detail: "优先选择代码完整、有驾驶数据 demo 路径的模型。"),
                TaskTodoItem(id: "\(task.id)_demo", title: "跑官方 inference demo", detail: "在改动前先理解输入/输出形式。"),
                TaskTodoItem(id: "\(task.id)_nuscenes", title: "映射 nuScenes 到目标格式", detail: "记录需要哪些转换，以及卡在哪里。"),
                TaskTodoItem(id: "\(task.id)_compare", title: "比较重建线和生成线", detail: "写清楚 WM 对方向判断带来的变化。"),
            ]
        }

        if task.category == "jd_follow_up" {
            return [
                TaskTodoItem(id: "\(task.id)_clarify", title: "确认放置位置", detail: "确认这个行动属于本周、后续某周，还是新的周任务。"),
                TaskTodoItem(id: "\(task.id)_execute", title: "执行候选行动", detail: task.nextMilestone.isEmpty ? "完成该行动的预期产出。" : task.nextMilestone),
                TaskTodoItem(id: "\(task.id)_record", title: "记录证据", detail: "保存完成记录、输出链接或阻塞点。"),
            ]
        }

        return [
            TaskTodoItem(id: "\(task.id)_read", title: "澄清任务目标", detail: "写下这个任务应该产出什么。"),
            TaskTodoItem(id: "\(task.id)_execute", title: "推进一个具体步骤", detail: "记录输出或阻塞点。"),
            TaskTodoItem(id: "\(task.id)_review", title: "复盘下一步", detail: "决定继续、延后还是转化。"),
        ]
    }
}
