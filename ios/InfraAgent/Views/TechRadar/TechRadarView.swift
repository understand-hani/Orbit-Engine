import Foundation
import SwiftUI

struct TechRadarView: View {
    let session: BaseSession
    let payload: TechRadarPayload
    let onCompleted: ((BaseSession) -> Void)?

    @State private var currentSession: BaseSession
    @State private var currentPayload: TechRadarPayload
    @State private var context: UserContext?
    @State private var radarRun: RadarRun?
    @State private var isGeneratingRadar = false
    @State private var message: String?
    @State private var isShowingRadarInput = false

    private let contextAPI = UserContextAPI()
    private let sessionAPI = SessionAPI()

    init(
        session: BaseSession,
        payload: TechRadarPayload,
        onCompleted: ((BaseSession) -> Void)? = nil
    ) {
        self.session = session
        self.payload = payload
        self.onCompleted = onCompleted
        _currentSession = State(initialValue: session)
        _currentPayload = State(initialValue: payload)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日信号")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("把你已经信任的信息源带进来，再决定它是否值得占用今天的注意力。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("添加可信信号") {
                Button {
                    isShowingRadarInput = true
                } label: {
                    HStack {
                        Label("粘贴文章或材料链接", systemImage: "plus.circle")
                        Spacer()
                        if isGeneratingRadar {
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingRadar)

                Text("支持公众号文章、论文、GitHub 和官方发布页。页面无法读取时仍会保存原始链接，并清楚标记证据状态。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if activeSignals.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "link.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("还没有今日信号")
                            .font(.headline)
                        Text("粘贴一篇今天想看的公众号文章、论文或官方链接。Agent 会以你的主线帮你判断，而不是重新做一次全网搜索。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    Section("已收录的信号") {
                        ForEach(activeSignals) { item in
                            NavigationLink {
                                TechRadarItemDetailView(session: currentSession, item: item)
                            } label: {
                                SignalInboxCardView(item: item)
                            }
                        }
                    }
                }
            }

            if let context {
                Section("当前主线") {
                    RadarSummaryLine(title: "本周重点", value: context.plan.weeklyFocus)
                    RadarSummaryLine(title: "下一步", value: context.plan.nextAction)
                    if !context.plan.trackingKeywords.isEmpty {
                        TagRow(tags: Array(context.plan.trackingKeywords.prefix(5)))
                    }
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("今日信号")
        .task {
            await loadContext()
        }
        .sheet(isPresented: $isShowingRadarInput) {
            NavigationStack {
                RadarInputSheet(
                    context: context,
                    payload: currentPayload,
                    isGenerating: isGeneratingRadar,
                    onGenerate: { input in
                        isShowingRadarInput = false
                        Task {
                            await generateRadar(input: input)
                        }
                    }
                )
            }
        }
    }

    private var activeSignals: [RadarItem] {
        currentPayload.digest.items.filter { $0.userMark != "archived" }
    }

    private var contextSources: String {
        if context == nil {
            return "当前 Signal Radar 引用 payload 中的 scope、top signals 和外部信号；用户上下文加载后会补充计划关键词、领域偏好和材料源偏好。"
        }
        return "引用字段：UserContext.plan.weekly_focus、next_action、tracking_keywords，UserContext.preferences.fields、source_preferences，以及当前 Signal Radar payload 的 top_signals、items 和 noise_filtered。"
    }

    private var radarArchiveKeyInsight: String {
        if let topSignal = currentPayload.digest.topSignals.first,
           !topSignal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return topSignal
        }
        return "本轮 Signal Radar 已完成材料筛选、相关度判断和后续路由。"
    }

    private var radarArchiveNotes: String {
        let items = currentPayload.digest.items.prefix(3).map {
            "\($0.title)（相关度 \($0.relevanceScore) / 5）"
        }
        return items.isEmpty ? "本轮没有可归档的外部信号。" : items.joined(separator: "\n")
    }

    private func loadContext() async {
        do {
            context = try await contextAPI.get()
        } catch {
            message = "用户上下文加载失败：\(error.localizedDescription)"
        }
    }

    private func generateRadar(input: RadarInput) async {
        isGeneratingRadar = true
        defer { isGeneratingRadar = false }

        if input.source == .url {
            do {
                let updatedSession = try await sessionAPI.addSignalLink(
                    sessionID: currentSession.id,
                    link: SignalLinkCreate(
                        url: input.url.trimmingCharacters(in: .whitespacesAndNewlines),
                        title: input.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        sourceName: "",
                        note: input.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
                guard case .techRadar(let updatedPayload) = updatedSession.payload else {
                    message = "添加信号失败：后端返回了非 Signal Inbox session。"
                    return
                }
                currentSession = updatedSession
                currentPayload = updatedPayload
                message = "已收录链接。打开该信号可查看原文、证据状态，并和 Agent 一起判断是否追踪。"
            } catch {
                message = "添加链接失败：\(error.localizedDescription)"
            }
            return
        }

        if input.source == .agent {
            do {
                let updatedSession = try await sessionAPI.refreshRadar(sessionID: currentSession.id)
                guard case .techRadar(let updatedPayload) = updatedSession.payload else {
                    message = "Signal Radar 生成失败：后端返回了非 Signal Radar session。"
                    return
                }
                currentSession = updatedSession
                currentPayload = updatedPayload
                let generatedItems = realRadarItems(updatedPayload.digest.items)
                guard !generatedItems.isEmpty else {
                    radarRun = nil
                    message = updatedPayload.digest.summary
                    return
                }
                radarRun = makeRadarRun(
                    input: input,
                    items: generatedItems
                )
                message = nil
            } catch {
                message = "Signal Radar 生成失败：\(error.localizedDescription)"
            }
            return
        }

        let sourceItems = radarItems(for: input)
        radarRun = makeRadarRun(input: input, items: sourceItems)
    }

    private func restoreRadarRunIfNeeded() {
        let restorableItems = realRadarItems(currentPayload.digest.items)
        guard radarRun == nil, !restorableItems.isEmpty else { return }
        radarRun = makeRadarRun(
            input: RadarInput(source: .agent, title: "", url: "", summary: ""),
            items: restorableItems
        )
    }

    private func makeRadarRun(input: RadarInput, items: [RadarItem]) -> RadarRun {
        let decisions = Array(items.prefix(3)).enumerated().map { index, item in
            RadarDecision(
                id: item.id,
                title: item.title,
                whatChanged: item.summary,
                whyRelevant: item.whyItMatters.isEmpty ? item.technicalSubstance : item.whyItMatters,
                noiseJudgement: noiseJudgement(for: item),
                route: route(for: item, index: index),
                introduction: introduction(for: item, input: input),
                observation: observation(for: item),
                sourceReference: sourceReference(for: item, input: input),
                keyPassages: keyPassages(for: item),
                evidenceStatus: evidenceStatusText(for: item),
                sourceType: input.sourceLabel,
                sourceDetail: input.sourceDetail,
                publishedAt: item.publishedAt,
                relevanceScore: item.relevanceScore,
                userMark: item.userMark,
                sourceURL: item.url?.absoluteString
            )
        }

        return RadarRun(
            title: "本轮 Signal Radar 扫描",
            summary: radarSummary(input: input, count: decisions.count),
            decisions: decisions
        )
    }

    private func radarSummary(input: RadarInput, count: Int) -> String {
        let focus = context?.plan.weeklyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        if let focus, !focus.isEmpty {
            return "围绕本周重点「\(focus)」和\(input.sourceLabel)完成一次广度扫描，输出 \(count) 条信号的追踪优先级和路由决策。"
        }
        return "基于\(input.sourceLabel)完成一次广度扫描，输出 \(count) 条信号的追踪优先级和路由决策。"
    }

    private func radarItems(for input: RadarInput) -> [RadarItem] {
        switch input.source {
        case .agent:
            let items = realRadarItems(currentPayload.digest.items)
            if !items.isEmpty {
                return items
            }
            return [manualRadarItem(input: input, suffix: "agent")]
        case .topic:
            return [
                manualRadarItem(input: input, suffix: "topic_strategy"),
                manualRadarItem(
                    input: input,
                    suffix: "topic_noise",
                    title: "围绕「\(input.titleOrFallback)」的噪音和反例扫描",
                    summary: "检查这个主题里哪些说法只是热度、营销或不适合当前计划，避免误转 Deep Dive。",
                    noise: "主题热度可能高于真实证据，需要用来源、复现成本和与当前计划的关系过滤。"
                )
            ]
        case .url:
            return [manualRadarItem(input: input, suffix: "url")]
        case .pdf:
            return [manualRadarItem(input: input, suffix: "pdf")]
        case .manual:
            return [manualRadarItem(input: input, suffix: "manual")]
        }
    }

    private func realRadarItems(_ items: [RadarItem]) -> [RadarItem] {
        items.filter { !$0.id.hasPrefix("mock_") }
    }

    private func route(for item: RadarItem, index: Int) -> String {
        if index == 0 {
            return "转 Deep Dive：优先验证它是否改变当前计划。"
        }
        if item.recommendedDepth.lowercased().contains("deep") {
            return "暂存：补一条具体问题后再决定是否 Deep Dive。"
        }
        if item.marketingNoise.isEmpty {
            return "加入本周任务：用 15 分钟确认是否有后续价值。"
        }
        return "忽略或低优先级：下次 Weekly Studio 再复查。"
    }

    private func noiseJudgement(for item: RadarItem) -> String {
        if item.marketingNoise.isEmpty {
            return "噪音较低：当前摘要中没有明显营销噪音，需要继续看证据。"
        }
        return "需要降噪：\(item.marketingNoise)"
    }

    private func introduction(for item: RadarItem, input: RadarInput) -> String {
        let sourcePart = "来源是\(input.sourceLabel)，当前信号指向「\(item.title)」。"
        let changePart = "它反映的核心变化是：\(item.summary)"
        let actionPart = "Signal Radar 的作用不是让用户立刻精读，而是先判断这条变化是否会影响当前计划、是否值得转入 Deep Dive。"
        return [sourcePart, changePart, actionPart].joined(separator: "\n\n")
    }

    private func observation(for item: RadarItem) -> String {
        let agentObservation = item.agentObservation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !agentObservation.isEmpty {
            return agentObservation
        }
        let substance = item.technicalSubstance.trimmingCharacters(in: .whitespacesAndNewlines)
        if !substance.isEmpty, substance != item.summary {
            return substance
        }
        let relevance = item.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines)
        if !relevance.isEmpty {
            return relevance
        }
        return "这条信号需要继续确认：它是否只是信息热度，还是已经对学习路线、项目选择或本周任务产生实际影响。"
    }

    private func sourceReference(for item: RadarItem, input: RadarInput) -> RadarSourceReference {
        if let url = item.url {
            return RadarSourceReference(
                title: item.title,
                displayType: input.source == .url ? "网页 / 原文链接" : "外部来源链接",
                detail: url.absoluteString,
                url: url,
                note: "点击链接可打开原始网页。当前 Signal Radar 先保存链接和 Agent 判断；网页正文抓取、截图和引用定位后续接后端。"
            )
        }

        switch input.source {
        case .pdf:
            return RadarSourceReference(
                title: item.title,
                displayType: "PDF / 文件登记",
                detail: input.titleOrFallback,
                url: nil,
                note: "当前版本先登记文件标题和说明作为原文入口；真实 PDF 上传、正文抽取、页码定位需要后端文件接口。"
            )
        case .manual:
            return RadarSourceReference(
                title: item.title,
                displayType: "手动材料",
                detail: input.summaryOrFallback,
                url: nil,
                note: "这条信号来自用户手动输入，原文以输入内容保存。"
            )
        case .topic:
            return RadarSourceReference(
                title: item.title,
                displayType: "主题扫描",
                detail: input.titleOrFallback,
                url: nil,
                note: "这条信号由 Agent 围绕主题生成，后续如果进入 Deep Dive，需要补充一手材料或链接。"
            )
        case .agent:
            return RadarSourceReference(
                title: item.title,
                displayType: "Agent 自动扫描",
                detail: item.source.isEmpty ? input.sourceDetail : item.source,
                url: nil,
                note: "这条信号来自当前 Signal Radar payload。若没有 URL，说明后端暂未提供可点击原文。"
            )
        case .url:
            return RadarSourceReference(
                title: item.title,
                displayType: "网页 / 原文链接",
                detail: input.sourceDetail,
                url: nil,
                note: "输入中没有可解析 URL，当前仅保存标题和说明。"
            )
        }
    }

    private func keyPassages(for item: RadarItem) -> [RadarKeyPassage] {
        if !item.sourcePassages.isEmpty {
            return item.sourcePassages.prefix(5).map { passage in
                RadarKeyPassage(
                    title: passage.title.isEmpty ? "关键段落" : passage.title,
                    excerpt: passage.excerpt,
                    analysis: passage.analysis,
                    suggestion: passage.suggestion,
                    sourceURL: passage.sourceURL,
                    location: passage.location
                )
            }
        }

        return []
    }

    private func evidenceStatusText(for item: RadarItem) -> String {
        switch item.evidenceStatus {
        case "excerpt_available":
            return "已抓到正文摘录：可用摘录辅助判断，但进入 Deep Dive 前仍要打开原文确认上下文。"
        case "full_text_available":
            return "已获取全文：Signal Radar 仍只做初筛，深入结论放到 Deep Dive。"
        case "metadata_with_structured_summary":
            return "结构化摘要判断：基于论文摘要、仓库描述或来源 metadata，未额外抓取网页正文。"
        default:
            return "元数据判断：当前基于标题、摘要、来源和链接做初筛，没有把网页正文抓取作为必要前提。"
        }
    }

    private func manualRadarItem(
        input: RadarInput,
        suffix: String,
        title: String? = nil,
        summary: String? = nil,
        noise: String = ""
    ) -> RadarItem {
        RadarItem(
            id: "radar_\(suffix)",
            radarType: currentPayload.radarType,
            title: title ?? input.titleOrFallback,
            source: input.sourceLabel,
            url: input.urlValue,
            signalType: input.source.rawValue,
            summary: summary ?? input.summaryOrFallback,
            technicalSubstance: input.summaryOrFallback,
            marketingNoise: noise,
            whyItMatters: input.relevanceOrFallback(context: context),
            evidenceStatus: "metadata_only",
            sourcePassages: [],
            visuals: [],
            recommendedDepth: "radar",
            userMark: "unmarked",
            archivedAt: nil,
            archiveNote: "",
            tags: input.tags
        )
    }
}

private enum RadarInputSource: String, CaseIterable, Identifiable {
    case agent
    case topic
    case url
    case pdf
    case manual

    static let availableCases: [RadarInputSource] = [.url]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agent:
            return "Agent 自动扫描"
        case .topic:
            return "输入主题"
        case .url:
            return "粘贴网址"
        case .pdf:
            return "个人上传"
        case .manual:
            return "手动材料"
        }
    }

    var detail: String {
        switch self {
        case .agent:
            return "按当前计划、关键词和已有 Signal Radar payload 自动扫描。"
        case .topic:
            return "输入一个方向或问题，让 Agent 做广度信号判断。"
        case .url:
            return "粘贴网页、论文、产品页或新闻链接。"
        case .pdf:
            return "登记个人文件或 PDF，先以标题和说明进入 Signal Radar。"
        case .manual:
            return "直接写下你观察到的一条变化。"
        }
    }

    var systemImage: String {
        switch self {
        case .agent:
            return "sparkles"
        case .topic:
            return "text.magnifyingglass"
        case .url:
            return "link"
        case .pdf:
            return "doc.text"
        case .manual:
            return "keyboard"
        }
    }
}

private struct RadarInput {
    let source: RadarInputSource
    let title: String
    let url: String
    let summary: String

    var titleOrFallback: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch source {
        case .agent:
            return "Agent 自动扫描当前计划相关信号"
        case .topic:
            return "用户输入主题"
        case .url:
            return "用户提供的网址信号"
        case .pdf:
            return "用户登记的 PDF / 文件信号"
        case .manual:
            return "用户手动输入的 Signal Radar 信号"
        }
    }

    var summaryOrFallback: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch source {
        case .agent:
            return "Agent 根据当前计划、关键词和 Signal Radar payload 生成本轮信号判断。"
        case .topic:
            return "围绕该主题扫描外部变化、方向变化和下一步机会。"
        case .url:
            return "基于用户提供的网址生成一条 Signal Radar 信号判断。"
        case .pdf:
            return "基于用户登记的 PDF / 文件材料生成一条 Signal Radar 信号判断。"
        case .manual:
            return "基于用户手动输入内容生成一条 Signal Radar 信号判断。"
        }
    }

    var sourceLabel: String {
        source.title
    }

    var sourceDetail: String {
        switch source {
        case .url:
            return url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? titleOrFallback : url
        case .pdf:
            return "\(titleOrFallback)（文件内容当前以登记信息进入 Signal Radar；真实二进制上传和正文抽取仍需后端接口支持。）"
        default:
            return titleOrFallback
        }
    }

    var urlValue: URL? {
        URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var tags: [String] {
        [source.title, "Signal Radar", "路由决策"]
    }

    func relevanceOrFallback(context: UserContext?) -> String {
        if let context {
            return "它需要和当前计划「\(context.plan.weeklyFocus)」对齐，并判断是否值得转入 Deep Dive、暂存或忽略。"
        }
        return "它需要被判断是否值得转入 Deep Dive、暂存或忽略。"
    }
}

private struct RadarRun: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let decisions: [RadarDecision]
}

private struct RadarDecision: Identifiable {
    let id: String
    let title: String
    let whatChanged: String
    let whyRelevant: String
    let noiseJudgement: String
    let route: String
    let introduction: String
    let observation: String
    let sourceReference: RadarSourceReference
    let keyPassages: [RadarKeyPassage]
    let evidenceStatus: String
    let sourceType: String
    let sourceDetail: String
    let publishedAt: Date?
    let relevanceScore: Int
    let userMark: String
    let sourceURL: String?
}

private struct RadarSourceReference {
    let title: String
    let displayType: String
    let detail: String
    let url: URL?
    let note: String
}

private struct RadarKeyPassage: Identifiable {
    let id = UUID()
    let title: String
    let excerpt: String
    let analysis: String
    let suggestion: String
    let sourceURL: URL?
    let location: String
}

private struct RadarInputSheet: View {
    let context: UserContext?
    let payload: TechRadarPayload
    let isGenerating: Bool
    let onGenerate: (RadarInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var source: RadarInputSource = .url
    @State private var title = ""
    @State private var url = ""
    @State private var summary = ""

    var body: some View {
        Form {
            Section("来源") {
                ForEach(RadarInputSource.availableCases) { option in
                    Button {
                        source = option
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: option.systemImage)
                                .foregroundStyle(source == option ? .blue : .secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(option.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if source == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            switch source {
            case .agent:
                Section("Agent 自动扫描") {
                    Text("Agent 会基于计划关键词、领域偏好、材料源偏好和当前 Signal Radar payload，直接生成本轮信号路由结果。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let context, !context.plan.trackingKeywords.isEmpty {
                        TagRow(tags: Array(context.plan.trackingKeywords.prefix(6)))
                    }
                }
            case .topic:
                Section("输入主题") {
                    TextField("例如：World Model for autonomous driving", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("补充说明：想关注什么变化、机会或噪音", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                }
            case .url:
                Section("粘贴网址") {
                    TextField("标题", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("https://...", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("这条链接为什么可能是信号", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                }
            case .pdf:
                Section("个人上传") {
                    TextField("材料标题", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("描述文件来源、核心内容、为什么可能影响你的方向", text: $summary, axis: .vertical)
                        .lineLimit(4...8)
                    Text("当前后端还没有 Signal Radar 文件上传接口。这里先支持文件材料登记，后续可接真实上传、正文抽取和页码索引。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .manual:
                Section("手动材料") {
                    TextField("信号标题", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("描述发生了什么、来自哪里、你为什么注意到它", text: $summary, axis: .vertical)
                        .lineLimit(4...8)
                }
            }

            Section("保存规则") {
                Text("链接会保存到后端的今日信号列表。网页无法读取时仍保留原始链接，并标明未取得正文。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("添加可信信号")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isGenerating ? "生成中" : "生成") {
                    onGenerate(
                        RadarInput(
                            source: source,
                            title: title,
                            url: url,
                            summary: summary
                        )
                    )
                }
                .disabled(isGenerating || !canGenerate)
            }
        }
    }

    private var canGenerate: Bool {
        switch source {
        case .agent:
            return true
        case .topic, .pdf, .manual:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .url:
            return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

private struct RadarCapabilityRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct RadarDecisionCardView: View {
    let decision: RadarDecision

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(decision.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            RadarSummaryLine(title: "摘要", value: decision.whatChanged)
            HStack(spacing: 10) {
                Label(radarPublishedDate(decision.publishedAt), systemImage: "calendar")
                RadarRelevanceStars(score: decision.relevanceScore)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            RadarSummaryLine(title: "路由动作", value: decision.route)
            TagRow(tags: [decision.sourceType, "可点开详情"])
        }
        .padding(.vertical, 4)
    }
}

private struct RadarDecisionDetailView: View {
    let session: BaseSession
    let decision: RadarDecision

    @State private var currentMark: String
    @State private var enrichedItem: RadarItem?
    @State private var statusMessage: String?
    @State private var isUpdatingMark = false
    @State private var isLoadingJudgement = false
    private let materialAPI = MaterialAPI()

    init(session: BaseSession, decision: RadarDecision) {
        self.session = session
        self.decision = decision
        _currentMark = State(initialValue: decision.userMark)
    }

    var body: some View {
        List {
            Section {
                Text(decision.title)
                    .font(.headline)
                Text(decision.introduction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("信号判断") {
                RadarSummaryLine(title: "来源方式", value: decision.sourceType)
                RadarSummaryLine(title: "来源详情", value: decision.sourceDetail)
                RadarSummaryLine(title: "发布日期", value: radarPublishedDate(decision.publishedAt))
                RadarSummaryLine(title: "Agent 相关度", value: "\(decision.relevanceScore) / 5")
                RadarSummaryLine(title: "摘要", value: enrichedItem?.summary ?? decision.whatChanged)
                RadarSummaryLine(title: "为什么和我有关", value: enrichedItem?.whyItMatters ?? decision.whyRelevant)
                RadarSummaryLine(title: "噪音 / 可信度判断", value: enrichedItem?.marketingNoise ?? decision.noiseJudgement)
                if isLoadingJudgement {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Agent 正在补充这条信号的判断…")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("原文 / 材料入口") {
                RadarSummaryLine(title: "展示方式", value: decision.sourceReference.displayType)
                RadarSummaryLine(title: "原文标题", value: decision.sourceReference.title)
                RadarSummaryLine(title: "原文信息", value: decision.sourceReference.detail)
                if let url = decision.sourceReference.url {
                    Link(destination: url) {
                        Label("打开原文链接", systemImage: "safari")
                    }
                }
                Text(decision.sourceReference.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: ["tech_radar", "signal:\(decision.id)"],
                        title: "Agent 讨论"
                    )
                } label: {
                    Label("和 Agent 讨论这条信号", systemImage: "bubble.left.and.bubble.right")
                }
            }

            Section("关键信息摘录") {
                if decision.keyPassages.isEmpty {
                    Text(decision.evidenceStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    ForEach(decision.keyPassages) { passage in
                        NavigationLink {
                            RadarPassageDetailView(passage: passage)
                        } label: {
                            RadarPassageCardView(passage: passage)
                        }
                    }
                }
            }

            Section("具体观察") {
                Text(enrichedItem?.agentObservation ?? decision.observation)
                    .font(.subheadline)
            }

            Section("路由动作") {
                RadarSummaryLine(title: "Agent 建议", value: decision.route)
                RadarSummaryLine(title: "当前状态", value: markLabel(currentMark))
                Button("转 Deep Dive") {
                    updateMark("deep_dive", message: "已标记为待转 Deep Dive")
                }
                .disabled(isUpdatingMark)
                Button("暂存决策") {
                    updateMark("track_later", message: "已暂存为 Signal Radar 决策")
                }
                .disabled(isUpdatingMark)
                Button("忽略") {
                    updateMark("noise", message: "已标记为忽略")
                }
                .disabled(isUpdatingMark)
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .navigationTitle("Signal Radar 详情")
        .task {
            await loadJudgement()
        }
    }

    private func loadJudgement() async {
        isLoadingJudgement = true
        defer { isLoadingJudgement = false }
        do {
            enrichedItem = try await materialAPI.generateRadarItemJudgement(
                sessionID: session.id,
                itemID: decision.id
            )
        } catch {
            // The deterministic, evidence-bound text remains visible if the
            // optional Agent detail request is unavailable.
        }
    }

    private func updateMark(_ mark: String, message: String) {
        isUpdatingMark = true
        Task {
            do {
                let updated = try await materialAPI.markRadarItem(
                    sessionID: session.id,
                    itemID: decision.id,
                    mark: mark
                )
                currentMark = updated.userMark
                statusMessage = message
            } catch {
                statusMessage = "状态更新失败：\(error.localizedDescription)"
            }
            isUpdatingMark = false
        }
    }

    private func markLabel(_ mark: String) -> String {
        switch mark {
        case "unread":
            return "未读"
        case "valuable":
            return "有价值"
        case "noise":
            return "忽略 / 噪音"
        case "track_later":
            return "暂存"
        case "deep_dive":
            return "待转 Deep Dive"
        case "archived":
            return "已归档"
        case "done":
            return "已完成"
        default:
            return mark.isEmpty ? "未设置" : mark
        }
    }
}

private func radarPublishedDate(_ date: Date?) -> String {
    guard let date else { return "发布日期未知" }
    return date.formatted(.dateTime.year().month().day())
}

private struct RadarRelevanceStars: View {
    let score: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= max(1, min(score, 5)) ? "star.fill" : "star")
                    .foregroundStyle(index <= max(1, min(score, 5)) ? Color.orange : Color.secondary.opacity(0.35))
            }
            Text("相关度")
        }
    }
}

private struct RadarPassageCardView: View {
    let passage: RadarKeyPassage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(passage.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(passage.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("点击查看原文摘录、Agent 解析和建议")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.vertical, 4)
    }
}

private struct RadarPassageDetailView: View {
    let passage: RadarKeyPassage

    var body: some View {
        List {
            Section("Agent 提取的原文") {
                if let url = passage.sourceURL {
                    Link(destination: url) {
                        Label("打开来源", systemImage: "safari")
                    }
                }
                if !passage.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RadarSummaryLine(title: "位置", value: passage.location)
                }
                Text(passage.excerpt)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            Section("Agent 解析") {
                Text(passage.analysis)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            Section("对用户的建议") {
                Text(passage.suggestion.isEmpty ? "当前没有针对该段的额外建议。" : passage.suggestion)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(passage.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RadarSummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayValue)
                .font(.subheadline)
                .foregroundStyle(displayValue == "未设置" ? .secondary : .primary)
        }
    }

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未设置" : trimmed
    }
}

private struct SignalInboxCardView: View {
    let item: RadarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                Text(signalEvidenceLabel(item.evidenceStatus))
                    .font(.caption2)
                    .foregroundStyle(signalEvidenceColor(item.evidenceStatus))
            }
            Text(item.source)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !item.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(item.whyItMatters, systemImage: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TechRadarItemDetailView: View {
    let session: BaseSession
    let item: RadarItem

    @State private var currentItem: RadarItem
    @State private var statusMessage: String?
    @State private var isUpdating = false
    @State private var isGeneratingJudgement = false
    private let materialAPI = MaterialAPI()

    init(session: BaseSession, item: RadarItem) {
        self.session = session
        self.item = item
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        List {
            Section {
                Text(currentItem.title)
                    .font(.headline)
                Text(currentItem.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(signalEvidenceLabel(currentItem.evidenceStatus), systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(signalEvidenceColor(currentItem.evidenceStatus))
            }

            Section("原文与证据") {
                if let url = currentItem.url {
                    Link(destination: url) {
                        Label("打开原文链接", systemImage: "safari")
                    }
                }
                Text(signalEvidenceDescription(currentItem.evidenceStatus))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if currentItem.sourcePassages.isEmpty {
                    Text("当前没有可读取的正文摘录。请打开原文确认具体内容后，再与 Agent 讨论。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(currentItem.sourcePassages) { passage in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(passage.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(passage.excerpt)
                                .font(.subheadline)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("与当前主线的关系") {
                RadarSummaryLine(title: "Agent 初步判断", value: currentItem.whyItMatters)
                RadarSummaryLine(title: "需要核对", value: currentItem.marketingNoise)
                if !currentItem.agentObservation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RadarSummaryLine(title: "补充观察", value: currentItem.agentObservation)
                }
                Button(isGeneratingJudgement ? "正在补充解读…" : "让 Agent 补充解读") {
                    generateJudgement()
                }
                .disabled(isGeneratingJudgement)
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: ["tech_radar", "signal:\(currentItem.id)"],
                        title: "解读这条信号"
                    )
                } label: {
                    Label("和 Agent 一起解读", systemImage: "bubble.left.and.bubble.right")
                }
            }

            Section("我的决定") {
                Text("当前状态：\(signalMarkLabel(currentItem.userMark))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("继续追踪") {
                    updateMark("track_later", message: "已保留为后续追踪信号")
                }
                .disabled(isUpdating)
                Button("保留为研究线索") {
                    updateMark("valuable", message: "已保留为研究线索")
                }
                .disabled(isUpdating)
                Button("忽略这条信号", role: .destructive) {
                    updateMark("noise", message: "已标记为忽略")
                }
                .disabled(isUpdating)
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("信号详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generateJudgement() {
        isGeneratingJudgement = true
        Task {
            defer { isGeneratingJudgement = false }
            do {
                currentItem = try await materialAPI.generateRadarItemJudgement(
                    sessionID: session.id,
                    itemID: currentItem.id
                )
            } catch {
                statusMessage = "暂时无法补充 Agent 解读：\(error.localizedDescription)"
            }
        }
    }

    private func updateMark(_ mark: String, message: String) {
        isUpdating = true
        Task {
            defer { isUpdating = false }
            do {
                currentItem = try await materialAPI.markRadarItem(
                    sessionID: session.id,
                    itemID: currentItem.id,
                    mark: mark
                )
                statusMessage = message
            } catch {
                statusMessage = "状态更新失败：\(error.localizedDescription)"
            }
        }
    }
}

private func signalEvidenceLabel(_ status: String) -> String {
    switch status {
    case "excerpt_available": return "已提取正文"
    case "link_only": return "仅保存链接"
    case "metadata_with_structured_summary": return "摘要证据"
    default: return "待核对原文"
    }
}

private func signalEvidenceDescription(_ status: String) -> String {
    switch status {
    case "excerpt_available": return "已从公开页面提取以下段落。摘录仅用于定位重点，重要判断仍应回到原文确认。"
    case "link_only": return "该页面没有成功读取到正文，可能受公众号或网站访问限制影响。链接已保留，系统不会把未读取内容当作事实。"
    case "metadata_with_structured_summary": return "当前只有结构化摘要或页面元数据，尚未取得完整正文。"
    default: return "当前证据有限，请打开原文核对具体事实与适用边界。"
    }
}

private func signalEvidenceColor(_ status: String) -> Color {
    status == "excerpt_available" ? .green : .orange
}

private func signalMarkLabel(_ mark: String) -> String {
    switch mark {
    case "valuable": return "研究线索"
    case "track_later": return "继续追踪"
    case "noise": return "已忽略"
    case "archived": return "已归档"
    default: return "未决定"
    }
}

struct TagRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    TagPill(text: tag)
                }
            }
        }
    }
}
