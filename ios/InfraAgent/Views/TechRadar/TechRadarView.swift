import Foundation
import SwiftUI

struct TechRadarView: View {
    let session: BaseSession
    let payload: TechRadarPayload

    @State private var context: UserContext?
    @State private var radarRun: RadarRun?
    @State private var isGeneratingRadar = false
    @State private var message: String?

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
                    generateRadar()
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
                        RadarDecisionView(decision: decision)
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

    private func generateRadar() {
        isGeneratingRadar = true
        defer { isGeneratingRadar = false }

        let decisions = Array(payload.digest.items.prefix(5)).enumerated().map { index, item in
            RadarDecision(
                id: item.id,
                title: item.title,
                whatChanged: item.summary,
                whyRelevant: item.whyItMatters.isEmpty ? item.technicalSubstance : item.whyItMatters,
                noiseJudgement: noiseJudgement(for: item),
                route: route(for: item, index: index)
            )
        }

        radarRun = RadarRun(
            title: "本轮 Radar 扫描",
            summary: radarSummary,
            decisions: decisions
        )
    }

    private var radarSummary: String {
        let focus = context?.plan.weeklyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        if let focus, !focus.isEmpty {
            return "围绕本周重点「\(focus)」完成一次广度扫描，输出 \(min(payload.digest.items.count, 5)) 条信号的追踪优先级和路由决策。"
        }
        return "基于当前 Radar payload 完成一次广度扫描，输出 \(min(payload.digest.items.count, 5)) 条信号的追踪优先级和路由决策。"
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

private struct RadarDecisionView: View {
    let decision: RadarDecision

    @State private var localMark: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(decision.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            RadarSummaryLine(title: "发生了什么", value: decision.whatChanged)
            RadarSummaryLine(title: "为什么和我有关", value: decision.whyRelevant)
            RadarSummaryLine(title: "噪音 / 可信度判断", value: decision.noiseJudgement)
            RadarSummaryLine(title: "路由动作", value: decision.route)
            HStack {
                Button("转 Deep Dive") {
                    localMark = "已标记为待转 Deep Dive"
                }
                .buttonStyle(.bordered)

                Button("暂存建议") {
                    localMark = "已暂存为 Radar 决策"
                }
                .buttonStyle(.bordered)
            }
            if let localMark {
                Text(localMark)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
