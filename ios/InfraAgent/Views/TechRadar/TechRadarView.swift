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

                Text("Radar 不做候选池；点击后直接生成本轮扫描结果：发生了什么、为什么和我有关、噪音判断和路由动作。")
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
                            RadarDecisionDetailView(decision: decision)
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
                sourceType: input.sourceLabel,
                sourceDetail: input.sourceDetail
            )
        }

        radarRun = RadarRun(
            title: "本轮 Radar 扫描",
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
            visuals: [],
            recommendedDepth: "radar",
            userMark: "unmarked",
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
    let sourceType: String
    let sourceDetail: String
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
                Picker("来源", selection: $source) {
                    ForEach(RadarInputSource.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
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
                Text("生成后不会进入候选池，而是直接得到本轮 Radar：每条信号包含发生了什么、为什么相关、噪音判断和路由动作。")
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
            RadarSummaryLine(title: "发生了什么", value: decision.whatChanged)
            RadarSummaryLine(title: "路由动作", value: decision.route)
            TagRow(tags: [decision.sourceType, "可点开详情"])
        }
        .padding(.vertical, 4)
    }
}

private struct RadarDecisionDetailView: View {
    let decision: RadarDecision

    @State private var localMark: String?

    var body: some View {
        List {
            Section {
                Text(decision.title)
                    .font(.headline)
            }

            Section("信号判断") {
                RadarSummaryLine(title: "来源方式", value: decision.sourceType)
                RadarSummaryLine(title: "来源详情", value: decision.sourceDetail)
                RadarSummaryLine(title: "发生了什么", value: decision.whatChanged)
                RadarSummaryLine(title: "为什么和我有关", value: decision.whyRelevant)
                RadarSummaryLine(title: "噪音 / 可信度判断", value: decision.noiseJudgement)
            }

            Section("路由动作") {
                RadarSummaryLine(title: "Agent 建议", value: decision.route)
                Button("转 Deep Dive") {
                    localMark = "已标记为待转 Deep Dive"
                }
                Button("暂存决策") {
                    localMark = "已暂存为 Radar 决策"
                }
                Button("忽略") {
                    localMark = "已标记为忽略"
                }
                if let localMark {
                    Text(localMark)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Radar 详情")
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
                defaultKeyInsight: item.whyItMatters.isEmpty ? item.technicalSubstance : item.whyItMatters
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
