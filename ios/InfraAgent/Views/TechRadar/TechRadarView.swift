import Foundation
import SwiftUI

struct TechRadarView: View {
    let session: BaseSession
    let payload: TechRadarPayload

    @State private var context: UserContext?
    @State private var draft: RadarDraft?
    @State private var isGeneratingDraft = false
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
                    RadarSummaryLine(title: "下一步动作", value: context?.plan.nextAction ?? "从当前信号中选择一个进入 Deep Dive。")
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
                    title: "扫描新材料",
                    detail: "根据计划关键词、材料源偏好和当前 Radar 信号，筛出值得追踪的新材料。"
                )
                RadarCapabilityRow(
                    systemImage: "arrow.triangle.branch",
                    title: "识别方向变化",
                    detail: "判断哪些信号会改变当前学习 / 研究路线，哪些只是噪音。"
                )
                RadarCapabilityRow(
                    systemImage: "arrow.right.doc.on.clipboard",
                    title: "生成下一步机会",
                    detail: "把信号转成 Deep Dive 候选、暂存建议或本周任务。"
                )
            }

            Section("新建 Radar") {
                Button {
                    generateDraft()
                } label: {
                    HStack {
                        Label("生成轻量扫描草稿", systemImage: "dot.radiowaves.left.and.right")
                        Spacer()
                        if isGeneratingDraft {
                            ProgressView()
                        }
                    }
                }
                .disabled(isGeneratingDraft)

                Text("当前版本先生成可录屏的轻量草稿：3-5 条信号、相关理由和建议动作；暂不做完整信号 CRUD。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let draft {
                Section("Radar 草稿") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(draft.title)
                            .font(.headline)
                        Text(draft.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    ForEach(draft.signals) { signal in
                        RadarDraftSignalView(signal: signal)
                    }
                }
            }

            Section("上下文来源") {
                Text(contextSources)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("信号") {
                ForEach(payload.digest.items) { item in
                    NavigationLink {
                        TechRadarItemDetailView(session: session, item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                            TagRow(tags: item.tags)
                        }
                        .padding(.vertical, 4)
                    }
                }
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
            return "当前草稿引用 Radar payload 中的 scope、top signals 和候选信号；用户上下文加载后会补充计划关键词、领域偏好和材料源偏好。"
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

    private func generateDraft() {
        isGeneratingDraft = true
        defer { isGeneratingDraft = false }

        let signals = Array(payload.digest.items.prefix(5)).enumerated().map { index, item in
            RadarDraftSignal(
                id: item.id,
                title: item.title,
                whyRelevant: item.whyItMatters.isEmpty ? item.summary : item.whyItMatters,
                suggestedAction: suggestedAction(for: item, index: index)
            )
        }

        draft = RadarDraft(
            title: "Radar 扫描草稿",
            summary: draftSummary,
            signals: signals
        )
    }

    private var draftSummary: String {
        let focus = context?.plan.weeklyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        if let focus, !focus.isEmpty {
            return "围绕本周重点「\(focus)」筛出 \(min(payload.digest.items.count, 5)) 条可追踪信号，优先判断是否值得进入 Deep Dive。"
        }
        return "基于当前 Radar payload 筛出 \(min(payload.digest.items.count, 5)) 条可追踪信号，先判断哪些值得继续追。"
    }

    private func suggestedAction(for item: RadarItem, index: Int) -> String {
        if index == 0 {
            return "优先进入 Deep Dive，验证它是否改变当前计划。"
        }
        if item.recommendedDepth.lowercased().contains("deep") {
            return "暂存为 Deep Dive 候选，补一条具体阅读问题。"
        }
        return "先暂存为 Radar 信号，下次 Weekly Studio 再决定是否推进。"
    }
}

private struct RadarDraft: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let signals: [RadarDraftSignal]
}

private struct RadarDraftSignal: Identifiable {
    let id: String
    let title: String
    let whyRelevant: String
    let suggestedAction: String
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

private struct RadarDraftSignalView: View {
    let signal: RadarDraftSignal

    @State private var localMark: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(signal.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            RadarSummaryLine(title: "为什么相关", value: signal.whyRelevant)
            RadarSummaryLine(title: "建议动作", value: signal.suggestedAction)
            HStack {
                Button("作为 Deep Dive 候选") {
                    localMark = "已标记为 Deep Dive 候选"
                }
                .buttonStyle(.bordered)

                Button("暂存建议") {
                    localMark = "已暂存为 Radar 建议"
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
