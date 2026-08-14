import SwiftUI

enum CompletionStartMode {
    case manual
    case agent
}

struct CheckinSourceContext {
    let sourceTitle: String
    let sourceURL: String?
    let sourceSummary: String?
    let userNotes: String?
}

struct SessionQueueView: View {
    let seedSession: BaseSession

    @State private var sessions: [BaseSession] = []
    @State private var isCreating = false
    @State private var processingSessionIDs: Set<String> = []
    @State private var pendingDiscardSession: BaseSession?
    @State private var isShowingDiscardConfirmation = false
    @State private var renamingSession: BaseSession?
    @State private var renameSuffix = ""
    @State private var renameErrorMessage: String?
    @State private var errorMessage: String?

    private let sessionAPI = SessionAPI()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sessionDisplayTitle(seedSession))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("管理当前未完成的 \(sessionDisplayTitle(seedSession))，或新建一个同类型工作区。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            Section("进行中 / 未完成") {
                if activeSessions.isEmpty {
                    EmptyStateView(
                        title: "暂无未完成工作区",
                        systemImage: "tray",
                        message: "已完成和已暂存的记录会进入归档区；已丢弃的任务不会再显示。"
                    )
                } else {
                    ForEach(Array(activeSessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            SessionDestinationView(session: session) { completedSession in
                                updateSession(completedSession)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(displayName(for: session, index: index))
                                    .font(.headline)
                                Text(session.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                TagRow(tags: [session.date, sessionDisplayType(session), session.status.rawValue])
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDiscardSession = session
                                isShowingDiscardConfirmation = true
                            } label: {
                                Label("丢弃", systemImage: "trash")
                            }
                            .disabled(processingSessionIDs.contains(session.id))

                            Button {
                                Task { await archiveSession(session) }
                            } label: {
                                Label("暂存", systemImage: "archivebox")
                            }
                            .tint(.orange)
                            .disabled(processingSessionIDs.contains(session.id))

                            Button {
                                startRenaming(session)
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            .tint(.blue)
                            .disabled(processingSessionIDs.contains(session.id))
                        }
                    }
                }
            }

            Section("新建") {
                Button {
                    Task { await createSession() }
                } label: {
                    if isCreating {
                        Label("正在新建", systemImage: "hourglass")
                    } else {
                        Label("新建 \(sessionDisplayTitle(seedSession))", systemImage: "plus.circle")
                    }
                }
                .disabled(isCreating)

                Text("当前版本先复用后端 mock session 生成同类工作区；真实多实例列表将在后端增加按类型和状态查询后接入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(sessionDisplayTitle(seedSession))
        .onAppear {
            reconcileSeedSession()
            Task { await refreshSeedSessionStatus() }
        }
        .confirmationDialog(
            "丢弃这个工作区？",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("丢弃", role: .destructive) {
                if let pendingDiscardSession {
                    Task { await discardSession(pendingDiscardSession) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("丢弃后会从未完成队列移除，不会进入归档。")
        }
        .sheet(isPresented: Binding(
            get: { renamingSession != nil },
            set: { isPresented in
                if !isPresented {
                    renamingSession = nil
                    renameErrorMessage = nil
                }
            }
        )) {
            RenameSessionView(
                prefix: renamingSession.map { renamePrefix(for: $0) } ?? "",
                suffix: $renameSuffix,
                errorMessage: renameErrorMessage,
                onCancel: {
                    renamingSession = nil
                    renameErrorMessage = nil
                },
                onSave: {
                    if let renamingSession {
                        Task { await renameSession(renamingSession) }
                    }
                }
            )
        }
    }

    private func updateSession(_ session: BaseSession) {
        guard belongsToCurrentQueue(session) else {
            return
        }
        if !isActive(session) {
            sessions.removeAll { $0.id == session.id }
            return
        }
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
    }

    private func reconcileSeedSession() {
        sessions.removeAll { !isActive($0) || !belongsToCurrentQueue($0) }
        if sessions.isEmpty && isActive(seedSession) {
            sessions = [seedSession]
        }
    }

    private func refreshSeedSessionStatus() async {
        guard isActive(seedSession) else {
            sessions.removeAll { $0.id == seedSession.id }
            return
        }

        do {
            let latestSession = try await sessionAPI.session(id: seedSession.id)
            updateSession(latestSession)
        } catch {
            sessions.removeAll { $0.id == seedSession.id }
        }
    }

    private func createSession() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let date = nextManualDate()
            let session = try await sessionAPI.generateAndSaveMock(date: date, taskType: taskTypeOverrideForNewSession())
            guard belongsToCurrentQueue(session) else {
                errorMessage = "后端返回了 \(sessionDisplayTitle(session))，不是当前 \(sessionDisplayTitle(seedSession)) 队列的工作区。"
                return
            }
            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.insert(session, at: 0)
            } else if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discardSession(_ session: BaseSession) async {
        processingSessionIDs.insert(session.id)
        errorMessage = nil
        defer { processingSessionIDs.remove(session.id) }

        do {
            try await sessionAPI.delete(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveSession(_ session: BaseSession) async {
        processingSessionIDs.insert(session.id)
        errorMessage = nil
        defer { processingSessionIDs.remove(session.id) }

        do {
            try await sessionAPI.archive(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startRenaming(_ session: BaseSession) {
        renamingSession = session
        renameSuffix = suffixForRename(session)
        renameErrorMessage = nil
    }

    private func renameSession(_ session: BaseSession) async {
        let trimmedSuffix = renameSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuffix.isEmpty else {
            renameErrorMessage = "序号不能为空。"
            return
        }

        do {
            let updatedSession = try await sessionAPI.rename(id: session.id, suffix: trimmedSuffix)
            updateSession(updatedSession)
            renamingSession = nil
            renameErrorMessage = nil
        } catch {
            renameErrorMessage = error.localizedDescription
        }
    }

    private func nextManualDate() -> String {
        if seedSession.taskType == .researchFeeder && !isWeeklyStudio(seedSession) {
            return seedSession.date
        }
        let dates = manualDates(for: seedSession)
        let existingDates = Set(sessions.filter(belongsToCurrentQueue).map(\.date))
        return dates.first { !existingDates.contains($0) } ?? dates.last ?? seedSession.date
    }

    private var activeSessions: [BaseSession] {
        sessions.filter { isActive($0) && belongsToCurrentQueue($0) }
    }

    private func instanceLabel(for session: BaseSession, index: Int) -> String {
        "第 \(index + 1) 个 · \(session.date)"
    }

    private func displayName(for session: BaseSession, index: Int) -> String {
        if session.taskType == .researchFeeder {
            return deepDiveDisplayName(for: session, index: index)
        }
        return "\(sessionDisplayTitle(session)) · \(instanceLabel(for: session, index: index))"
    }

    private func deepDiveDisplayName(for session: BaseSession, index: Int) -> String {
        let prefix = renamePrefix(for: session)
        if session.title.hasPrefix(prefix) {
            return session.title
        }
        return "\(prefix)\(index + 1)"
    }

    private func renamePrefix(for session: BaseSession) -> String {
        if session.taskType == .researchFeeder {
            return "Deep Dive-\(displayDateForTitle(session.date))-"
        }
        return "\(sessionDisplayTitle(session))-\(session.date)-"
    }

    private func displayDateForTitle(_ date: String) -> String {
        date.replacingOccurrences(of: "-", with: "/")
    }

    private func suffixForRename(_ session: BaseSession) -> String {
        let prefix = renamePrefix(for: session)
        if session.title.hasPrefix(prefix) {
            return String(session.title.dropFirst(prefix.count))
        }
        return "1"
    }

    private func isActive(_ session: BaseSession) -> Bool {
        session.status != .completed &&
            session.status != .archived &&
            session.status != .skipped
    }

    private func belongsToCurrentQueue(_ session: BaseSession) -> Bool {
        guard session.taskType == seedSession.taskType else {
            return false
        }
        guard session.taskType == .researchFeeder else {
            return true
        }
        return isWeeklyStudio(session) == isWeeklyStudio(seedSession)
    }

    private func taskTypeOverrideForNewSession() -> TaskType? {
        if seedSession.taskType == .techRadar {
            return .techRadar
        }
        if seedSession.taskType == .researchFeeder && !isWeeklyStudio(seedSession) {
            return .researchFeeder
        }
        return nil
    }
}

struct SessionDestinationView: View {
    let session: BaseSession
    var onCompleted: ((BaseSession) -> Void)?

    @State private var isShowingCompletion = false
    @State private var completionStartMode: CompletionStartMode = .manual
    @State private var checkinSourceContext: CheckinSourceContext?

    var body: some View {
        Group {
            switch session.payload {
            case .techRadar(let payload):
                TechRadarView(session: session, payload: payload)
            case .jdAnalysis:
                JDIntelligenceView()
            case .researchFeeder(let payload):
                if isWeeklyStudio(session) {
                    WeeklyStudioView(session: session) { mode, context in
                        completionStartMode = mode
                        checkinSourceContext = context
                        isShowingCompletion = true
                    }
                } else {
                    ResearchReaderView(session: session, payload: payload) { mode, context in
                        completionStartMode = mode
                        checkinSourceContext = context
                        isShowingCompletion = true
                    } onSourceContextChanged: { context in
                        checkinSourceContext = context
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    completionStartMode = .manual
                    checkinSourceContext = checkinSourceContext ?? defaultCheckinContext(for: session)
                    isShowingCompletion = true
                } label: {
                    Label("完成/归档", systemImage: "checkmark.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingCompletion) {
            CompletionArchiveView(session: session, initialMode: completionStartMode, sourceContext: checkinSourceContext) { completedSession in
                onCompleted?(completedSession)
                isShowingCompletion = false
            }
        }
    }
}

private struct RenameSessionView: View {
    let prefix: String
    @Binding var suffix: String
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    LabeledContent("固定部分", value: prefix)
                    TextField("序号", text: $suffix)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                    Text("只能修改日期后面的序号部分。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                    }
                }
            }
        }
    }
}

func defaultCheckinContext(for session: BaseSession) -> CheckinSourceContext? {
    guard case .researchFeeder(let payload) = session.payload else {
        return nil
    }
    let primaryPaper = payload.papers.first { $0.id == payload.readingPack.primaryPaperID } ?? payload.papers.first
    guard let primaryPaper else {
        return nil
    }
    return CheckinSourceContext(
        sourceTitle: primaryPaper.title,
        sourceURL: primaryPaper.url?.absoluteString,
        sourceSummary: nonEmpty(payload.notes.coreIdea) ?? nonEmpty(primaryPaper.summary),
        userNotes: nil
    )
}

func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

struct CompletionArchiveView: View {
    let session: BaseSession
    let initialMode: CompletionStartMode
    let sourceContext: CheckinSourceContext?
    let onCompleted: (BaseSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var durationMin = 30
    @State private var draftMode = "manual"
    @State private var summary = ""
    @State private var keyInsight = ""
    @State private var nextAction = ""
    @State private var didPrepareInitialDraft = false
    @State private var isGeneratingDraft = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let checkinAPI = CheckinAPI()

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage)
                    }
                }

                Section("Check-in 方式") {
                    Picker("Check-in 方式", selection: $draftMode) {
                        Text("自己编辑").tag("manual")
                        Text("Agent 生成初稿").tag("agent")
                    }
                    .pickerStyle(.segmented)

                    if draftMode == "agent" {
                        Button {
                            Task { await generateAgentDraft() }
                        } label: {
                            if isGeneratingDraft {
                                Label("正在生成草稿", systemImage: "hourglass")
                            } else {
                                Label("生成 Check-in 草稿", systemImage: "sparkles")
                            }
                        }
                        .disabled(isGeneratingDraft)
                    }
                }

                Section("归档内容") {
                    Stepper("用时 \(durationMin) 分钟", value: $durationMin, in: 5...180, step: 5)
                    TextField("简单总结", text: $summary, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("关键收获", text: $keyInsight, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("下一步", text: $nextAction, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let sourceContext {
                    Section("回看线索") {
                        Text(sourceContext.sourceTitle)
                        if let sourceURL = sourceContext.sourceURL, let url = URL(string: sourceURL) {
                            Link("打开网页", destination: url)
                        }
                        if let sourceSummary = nonEmpty(sourceContext.sourceSummary) {
                            Text(sourceSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let userNotes = nonEmpty(sourceContext.userNotes) {
                            Text(userNotes)
                                .font(.subheadline)
                        }
                    }
                }

                Section("去向") {
                    LabeledContent("状态", value: "completed")
                    Text("保存后会写入归档区；返回队列页后，该 session 不再出现在未完成列表中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("完成/归档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                prepareInitialDraftIfNeeded()
            }
        }
    }

    private func prepareInitialDraftIfNeeded() {
        guard !didPrepareInitialDraft else {
            return
        }
        didPrepareInitialDraft = true

        switch initialMode {
        case .agent:
            draftMode = "agent"
            Task { await generateAgentDraft() }
            return
        case .manual:
            break
        }
    }

    private func generateAgentDraft() async {
        isGeneratingDraft = true
        errorMessage = nil
        defer { isGeneratingDraft = false }

        do {
            let draft = try await checkinAPI.draftCompletion(
                sessionID: session.id,
                request: CompletionDraftRequest(
                    durationMin: durationMin,
                    sourceTitle: sourceContext?.sourceTitle,
                    sourceURL: sourceContext?.sourceURL,
                    sourceSummary: sourceContext?.sourceSummary,
                    userNotes: sourceContext?.userNotes
                )
            )
            summary = draft.summary
            keyInsight = draft.keyInsight
            nextAction = draft.nextAction
        } catch {
            generateLocalFallbackDraft()
            errorMessage = "Agent 草稿接口失败，已使用本地草稿：\(error.localizedDescription)"
        }
    }

    private func generateLocalFallbackDraft() {
        switch session.payload {
        case .researchFeeder(let payload):
            let primaryTitle = sourceContext?.sourceTitle
                ?? payload.papers.first { $0.id == payload.readingPack.primaryPaperID }?.title
                ?? payload.papers.first?.title
                ?? "本次 Deep Dive 材料"
            summary = "完成了 Deep Dive：围绕「\(primaryTitle)」梳理了材料目标、推荐理由和阅读重点。"
            keyInsight = nonEmpty(payload.notes.coreIdea)
                ?? nonEmpty(sourceContext?.sourceSummary)
                ?? nonEmpty(payload.readingPack.readingGoal)
                ?? "本次材料的关键价值在于帮助判断它是否值得继续投入时间。"
            nextAction = nonEmpty(payload.notes.nextAction)
                ?? "根据本次阅读结果，决定继续精读、加入跟踪列表或归档为阶段性参考。"
        case .techRadar:
            summary = "完成了 Signal Radar session：浏览并筛选了本次外部信号。"
            keyInsight = "记录一个值得继续跟踪的技术、产品或市场变化。"
            nextAction = "把高价值信号转入 Deep Dive 或下周继续跟踪。"
        case .jdAnalysis:
            summary = "完成了 Opportunity Alignment：对当前机会和能力差距做了初步判断。"
            keyInsight = "记录一个影响方向选择或准备优先级的关键信号。"
            nextAction = "决定继续观察、补能力，或暂时放弃该机会。"
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let response = try await checkinAPI.confirmCompletion(
                sessionID: session.id,
                request: CompletionConfirmRequest(
                    durationMin: durationMin,
                    status: "completed",
                    summary: summary,
                    keyInsight: keyInsight,
                    nextAction: nextAction,
                    sourceTitle: sourceContext?.sourceTitle,
                    sourceURL: sourceContext?.sourceURL,
                    sourceSummary: sourceContext?.sourceSummary,
                    userNotes: sourceContext?.userNotes
                )
            )
            onCompleted(response.session)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func sessionDisplayTitle(_ session: BaseSession) -> String {
    switch session.taskType {
    case .techRadar:
        return "Signal Radar"
    case .researchFeeder:
        if isWeeklyStudio(session) {
            return "Weekly Studio"
        }
        return "Deep Dive"
    case .jdAnalysis:
        return "Opportunity Alignment"
    }
}

private func sessionDisplayType(_ session: BaseSession) -> String {
    switch session.taskType {
    case .techRadar:
        return "radar"
    case .researchFeeder:
        if isWeeklyStudio(session) {
            return "weekly_studio"
        }
        return "deep_dive"
    case .jdAnalysis:
        return "opportunity_alignment"
    }
}

private func manualDates(for session: BaseSession) -> [String] {
    switch session.taskType {
    case .techRadar:
        return ["2026-08-04", "2026-08-10", "2026-08-11"]
    case .jdAnalysis:
        return ["2026-08-05", "2026-08-12"]
    case .researchFeeder:
        if isWeeklyStudio(session) {
            return ["2026-08-09", "2026-08-16"]
        }
        return ["2026-08-06", "2026-08-07", "2026-08-08", "2026-08-13", "2026-08-14", "2026-08-15"]
    }
}

private func isWeeklyStudio(_ session: BaseSession) -> Bool {
    session.date == "2026-08-09" || session.date == "2026-08-16"
}
