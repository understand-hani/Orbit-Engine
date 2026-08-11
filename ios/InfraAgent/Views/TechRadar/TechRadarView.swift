import Foundation
import SwiftUI

struct TechRadarView: View {
    let session: BaseSession
    let payload: TechRadarPayload

    @State private var context: UserContext?
    @State private var radarRun: RadarRun?
    @State private var isGeneratingRadar = false
    @State private var message: String?
    @State private var isShowingRadarInput = false

    private let contextAPI = UserContextAPI()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(payload.digest.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("当前工作区") {
                VStack(alignment: .leading, spacing: 10) {
                    RadarSummaryLine(title: "本周重点", value: context?.plan.weeklyFocus ?? payload.digest.summary)
                    RadarSummaryLine(title: "下一步动作", value: context?.plan.nextAction ?? "生成本轮 Radar 后，把最重要的信号分流到 Deep Dive、暂存或忽略。")
                    if let context, !context.plan.trackingKeywords.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("计划关键词")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TagRow(tags: Array(context.plan.trackingKeywords.prefix(6)))
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Agent 能做什么") {
                RadarCapabilityRow(
                    systemImage: "sparkle.magnifyingglass",
                    title: "扫描外部信号",
                    detail: "根据计划关键词、材料源偏好和外部信号，直接判断哪些变化值得追。"
                )
                RadarCapabilityRow(
                    systemImage: "arrow.triangle.branch",
                    title: "识别方向变化",
                    detail: "判断哪些信号会改变当前学习 / 研究路线，哪些只是噪音。"
                )
                RadarCapabilityRow(
                    systemImage: "arrow.right.doc.on.clipboard",
                    title: "做路由决策",
                    detail: "把信号分流为转 Deep Dive、暂存、忽略或加入本周任务。"
                )
            }

            Section("新建 Radar") {
                Button {
                    isShowingRadarInput = true
                } label: {
                    HStack {
                        Label("生成本轮 Radar", systemImage: "dot.radiowaves.left.and.right")
                        Spacer()
                        if isGeneratingRadar {
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingRadar)

                Text("Radar 不做候选池；点击后直接生成本轮扫描结果：摘要、为什么和我有关、噪音判断和路由动作。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let radarRun {
                Section("本轮 Radar") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(radarRun.title)
                            .font(.headline)
                        Text(radarRun.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    ForEach(radarRun.decisions) { decision in
                        NavigationLink {
                            RadarDecisionDetailView(
                                session: session,
                                decision: decision,
                                onArchived: { archivedID in
                                    removeRadarDecision(id: archivedID)
                                }
                            )
                        } label: {
                            RadarDecisionCardView(decision: decision)
                        }
                    }
                }
            }

            Section("上下文来源") {
                Text(contextSources)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !payload.digest.followUpQuestions.isEmpty {
                Section("Agent 讨论") {
                    ForEach(payload.digest.followUpQuestions, id: \.self) { question in
                        NavigationLink {
                            AgentChatView(
                                session: session,
                                contextRefs: ["tech_radar", "question:\(question)"],
                                title: "Agent 讨论"
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                                Text(question)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("技术雷达")
        .task {
            await loadContext()
        }
        .sheet(isPresented: $isShowingRadarInput) {
            NavigationStack {
                RadarInputSheet(
                    context: context,
                    payload: payload,
                    isGenerating: isGeneratingRadar,
                    onGenerate: { input in
                        generateRadar(input: input)
                        isShowingRadarInput = false
                    }
                )
            }
        }
    }

    private var contextSources: String {
        if context == nil {
            return "当前 Radar 引用 payload 中的 scope、top signals 和外部信号；用户上下文加载后会补充计划关键词、领域偏好和材料源偏好。"
        }
        return "引用字段：UserContext.plan.weekly_focus、next_action、tracking_keywords，UserContext.preferences.fields、source_preferences，以及当前 Radar payload 的 top_signals、items 和 noise_filtered。"
    }

    private func loadContext() async {
        do {
            context = try await contextAPI.get()
        } catch {
            message = "用户上下文加载失败：\(error.localizedDescription)"
        }
    }

    private func generateRadar(input: RadarInput) {
        isGeneratingRadar = true
        defer { isGeneratingRadar = false }

        let sourceItems = radarItems(for: input)
        let decisions = Array(sourceItems.prefix(5)).enumerated().map { index, item in
            RadarDecision(
                id: item.id,
                title: item.title,
                whatChanged: item.summary,
                whyRelevant: item.whyItMatters.isEmpty ? item.technicalSubstance : item.whyItMatters,
                noiseJudgement: noiseJudgement(for: item),
                route: route(for: item, index: index),
                introduction: introduction(for: item, input: input),
                observation: observation(for: item),
                validationQuestions: validationQuestions(for: item),
                sourceReference: sourceReference(for: item, input: input),
                keyPassages: keyPassages(for: item),
                sourceType: input.sourceLabel,
                sourceDetail: input.sourceDetail,
                userMark: item.userMark,
                sourceURL: item.url?.absoluteString
            )
        }

        radarRun = RadarRun(
            title: "本轮 Radar 扫描",
            summary: radarSummary(input: input, count: decisions.count),
            decisions: decisions
        )
    }

    private func removeRadarDecision(id: String) {
        guard let radarRun else {
            return
        }
        self.radarRun = RadarRun(
            title: radarRun.title,
            summary: radarRun.summary,
            decisions: radarRun.decisions.filter { $0.id != id }
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
            if !payload.digest.items.isEmpty {
                return payload.digest.items
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
        let actionPart = "Radar 的作用不是让用户立刻精读，而是先判断这条变化是否会影响当前计划、是否值得转入 Deep Dive。"
        return [sourcePart, changePart, actionPart].joined(separator: "\n\n")
    }

    private func observation(for item: RadarItem) -> String {
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

    private func validationQuestions(for item: RadarItem) -> [String] {
        [
            "这条信号是否会改变当前计划中的优先级或本周重点？",
            "是否存在可验证的一手来源、数据、代码、论文、产品发布或真实案例？",
            "如果转入 Deep Dive，最小验证问题是什么：机制、应用场景、风险，还是行动机会？",
            "如果暂不深入，下一次复查应该看什么触发条件？"
        ]
    }

    private func sourceReference(for item: RadarItem, input: RadarInput) -> RadarSourceReference {
        if let url = item.url {
            return RadarSourceReference(
                title: item.title,
                displayType: input.source == .url ? "网页 / 原文链接" : "外部来源链接",
                detail: url.absoluteString,
                url: url,
                note: "点击链接可打开原始网页。当前 Radar 先保存链接和 Agent 判断；网页正文抓取、截图和引用定位后续接后端。"
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
                note: "这条信号来自当前 Radar payload。若没有 URL，说明后端暂未提供可点击原文。"
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
                    sourceURL: passage.sourceURL,
                    location: passage.location
                )
            }
        }

        let substance = item.technicalSubstance.trimmingCharacters(in: .whitespacesAndNewlines)
        let visualEvidence = item.visuals
            .map { "\($0.caption)（来源：\($0.source)）" }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceEvidence = [
            item.source.isEmpty ? "" : "来源：\(item.source)",
            item.signalType.isEmpty ? "" : "信号类型：\(item.signalType)",
            item.url?.absoluteString ?? "",
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let tagEvidence = item.tags.isEmpty ? "" : "标签：\(item.tags.joined(separator: "、"))"
        let depthEvidence = item.recommendedDepth.isEmpty ? "" : "建议处理深度：\(item.recommendedDepth)"

        var passages: [RadarKeyPassage] = []
        appendPassage(
            to: &passages,
            excerpt: substance,
            analysis: "这是 Agent 从当前 Radar 材料字段中抽出的核心信息。进入 Deep Dive 前，应优先回到原文确认这段是否有足够事实、方法或数据支撑。"
        )
        appendPassage(
            to: &passages,
            excerpt: sourceEvidence,
            analysis: "这是用于定位原始材料的来源线索。它帮助判断这条推送是论文、开源项目、产品发布、新闻还是手动材料。"
        )
        appendPassage(
            to: &passages,
            excerpt: visualEvidence,
            analysis: "这是 Agent 记录的图像、视频、图表或方法图线索。视觉材料适合用来快速判断这条信号是否值得进一步打开原文。"
        )
        appendPassage(
            to: &passages,
            excerpt: tagEvidence,
            analysis: "这是 Agent 给这条推送打上的主题标签，用来判断它和当前 Radar 方向、后续 Deep Dive 队列的关系。"
        )
        appendPassage(
            to: &passages,
            excerpt: depthEvidence,
            analysis: "这是 Agent 对处理深度的判断，用来决定这条推送应该略读、暂存，还是转入 Deep Dive。"
        )

        while passages.count < 3 {
            passages.append(
                RadarKeyPassage(
                    title: "关键段落 \(passages.count + 1)",
                    excerpt: "当前后端还没有返回更多原文正文摘录。需要接入网页/PDF 正文抽取后，才能在这里补齐更多一手段落。",
                    analysis: "这是一条占位摘录，用来明确当前数据缺口：Radar 已有结构化判断，但还没有足够的一手正文片段。",
                    sourceURL: nil,
                    location: ""
                )
            )
        }
        return Array(passages.prefix(5))
    }

    private func appendPassage(to passages: inout [RadarKeyPassage], excerpt: String, analysis: String) {
        let trimmed = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        passages.append(
            RadarKeyPassage(
                title: "关键段落 \(passages.count + 1)",
                excerpt: trimmed,
                analysis: analysis,
                sourceURL: nil,
                location: ""
            )
        )
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
            radarType: payload.radarType,
            title: title ?? input.titleOrFallback,
            source: input.sourceLabel,
            url: input.urlValue,
            signalType: input.source.rawValue,
            summary: summary ?? input.summaryOrFallback,
            technicalSubstance: input.summaryOrFallback,
            marketingNoise: noise,
            whyItMatters: input.relevanceOrFallback(context: context),
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
            return "按当前计划、关键词和已有 Radar payload 自动扫描。"
        case .topic:
            return "输入一个方向或问题，让 Agent 做广度信号判断。"
        case .url:
            return "粘贴网页、论文、产品页或新闻链接。"
        case .pdf:
            return "登记个人文件或 PDF，先以标题和说明进入 Radar。"
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
            return "用户手动输入的 Radar 信号"
        }
    }

    var summaryOrFallback: String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch source {
        case .agent:
            return "Agent 根据当前计划、关键词和 Radar payload 生成本轮信号判断。"
        case .topic:
            return "围绕该主题扫描外部变化、方向变化和下一步机会。"
        case .url:
            return "基于用户提供的网址生成一条 Radar 信号判断。"
        case .pdf:
            return "基于用户登记的 PDF / 文件材料生成一条 Radar 信号判断。"
        case .manual:
            return "基于用户手动输入内容生成一条 Radar 信号判断。"
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
            return "\(titleOrFallback)（文件内容当前以登记信息进入 Radar；真实二进制上传和正文抽取仍需后端接口支持。）"
        default:
            return titleOrFallback
        }
    }

    var urlValue: URL? {
        URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var tags: [String] {
        [source.title, "Radar", "路由决策"]
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
    let validationQuestions: [String]
    let sourceReference: RadarSourceReference
    let keyPassages: [RadarKeyPassage]
    let sourceType: String
    let sourceDetail: String
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
    let sourceURL: URL?
    let location: String
}

private struct RadarInputSheet: View {
    let context: UserContext?
    let payload: TechRadarPayload
    let isGenerating: Bool
    let onGenerate: (RadarInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var source: RadarInputSource = .agent
    @State private var title = ""
    @State private var url = ""
    @State private var summary = ""

    var body: some View {
        Form {
            Section("来源") {
                ForEach(RadarInputSource.allCases) { option in
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
                    Text("Agent 会基于计划关键词、领域偏好、材料源偏好和当前 Radar payload，直接生成本轮信号路由结果。")
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
                    Text("当前后端还没有 Radar 文件上传接口。这里先支持文件材料登记，后续可接真实上传、正文抽取和页码索引。")
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

            Section("Radar 输出") {
                Text("生成后不会进入候选池，而是直接得到本轮 Radar：每条信号包含摘要、为什么相关、噪音判断和路由动作。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("生成 Radar")
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
            RadarSummaryLine(title: "路由动作", value: decision.route)
            TagRow(tags: [decision.sourceType, "可点开详情"])
        }
        .padding(.vertical, 4)
    }
}

private struct RadarDecisionDetailView: View {
    let session: BaseSession
    let decision: RadarDecision
    let onArchived: (String) -> Void

    @State private var currentMark: String
    @State private var statusMessage: String?
    @State private var isUpdatingMark = false
    private let materialAPI = MaterialAPI()
    private let checkinAPI = CheckinAPI()

    init(session: BaseSession, decision: RadarDecision, onArchived: @escaping (String) -> Void) {
        self.session = session
        self.decision = decision
        self.onArchived = onArchived
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
                RadarSummaryLine(title: "摘要", value: decision.whatChanged)
                RadarSummaryLine(title: "为什么和我有关", value: decision.whyRelevant)
                RadarSummaryLine(title: "噪音 / 可信度判断", value: decision.noiseJudgement)
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

            Section("关键信息摘录") {
                ForEach(decision.keyPassages) { passage in
                    NavigationLink {
                        RadarPassageDetailView(passage: passage)
                    } label: {
                        RadarPassageCardView(passage: passage)
                    }
                }
            }

            Section("具体观察") {
                Text(decision.observation)
                    .font(.subheadline)
                ForEach(Array(decision.validationQuestions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                        Text(question)
                            .font(.subheadline)
                    }
                }
            }

            Section("路由动作") {
                RadarSummaryLine(title: "Agent 建议", value: decision.route)
                RadarSummaryLine(title: "当前状态", value: markLabel(currentMark))
                Button("转 Deep Dive") {
                    updateMark("deep_dive", message: "已标记为待转 Deep Dive")
                }
                .disabled(isUpdatingMark)
                Button("暂存决策") {
                    updateMark("track_later", message: "已暂存为 Radar 决策")
                }
                .disabled(isUpdatingMark)
                Button("忽略") {
                    updateMark("noise", message: "已标记为忽略")
                }
                .disabled(isUpdatingMark)
                Button("归档") {
                    archiveItem()
                }
                .disabled(isUpdatingMark || currentMark == "archived")
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            PartRecordFormView(
                session: session,
                defaultSummary: "Radar 判断：\(decision.title)。\(decision.whatChanged)",
                defaultKeyInsight: decision.whyRelevant,
                sourceTitle: decision.title,
                sourceURL: decision.sourceURL,
                sourceSummary: decision.introduction,
                userNotes: "来源方式：\(decision.sourceType)\n来源详情：\(decision.sourceDetail)\n噪音判断：\(decision.noiseJudgement)\n路由动作：\(decision.route)",
                sectionTitle: "Radar Check-in",
                status: "completed"
            )
        }
        .navigationTitle("Radar 详情")
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

    private func archiveItem() {
        isUpdatingMark = true
        Task {
            do {
                let updated = try await materialAPI.archiveRadarItem(
                    sessionID: session.id,
                    itemID: decision.id,
                    archiveNote: "从 Radar 详情页归档。"
                )
                _ = try await checkinAPI.create(
                    CheckinCreate(
                        sessionID: session.id,
                        date: session.date,
                        taskType: session.taskType,
                        durationMin: 5,
                        status: "archived",
                        summary: "已归档 Radar 信号：\(decision.title)",
                        keyInsight: decision.whyRelevant,
                        nextAction: "以后可以从归档区找回这条 Radar 信号，再决定是否转入 Deep Dive。",
                        sourceTitle: decision.title,
                        sourceURL: decision.sourceURL,
                        sourceSummary: decision.introduction,
                        userNotes: "来源方式：\(decision.sourceType)\n来源详情：\(decision.sourceDetail)\n噪音判断：\(decision.noiseJudgement)\n路由动作：\(decision.route)"
                    )
                )
                currentMark = updated.userMark
                statusMessage = "已归档这条 Radar 推送，可在归档页查看。"
                onArchived(decision.id)
            } catch {
                statusMessage = "归档失败：\(error.localizedDescription)"
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
            Text("点击查看完整摘录和 Agent 解析")
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
            Section("Agent 摘录") {
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

struct TechRadarItemDetailView: View {
    let session: BaseSession
    let item: RadarItem

    var body: some View {
        List {
            Section {
                Text(item.summary)
                if !item.whyItMatters.isEmpty {
                    LabeledContent("为什么重要", value: item.whyItMatters)
                }
            }

            Section("信号") {
                Text(item.technicalSubstance)
                if !item.marketingNoise.isEmpty {
                    Text(item.marketingNoise)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: ["tech_radar", "signal:\(item.id)"],
                        title: "Agent 讨论"
                    )
                } label: {
                    Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                }
            }

            PartRecordFormView(
                session: session,
                defaultSummary: item.summary,
                defaultKeyInsight: item.whyItMatters.isEmpty ? item.technicalSubstance : item.whyItMatters,
                sourceTitle: item.title,
                sourceURL: item.url?.absoluteString,
                sourceSummary: item.summary,
                userNotes: "来源：\(item.source)\n噪音判断：\(item.marketingNoise)",
                sectionTitle: "Radar Check-in",
                status: "completed"
            )

            Section("视觉材料") {
                ForEach(item.visuals) { visual in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(visual.caption, systemImage: "photo")
                        Text(visual.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(item.title)
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
