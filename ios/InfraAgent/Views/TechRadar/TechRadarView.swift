import SwiftUI

struct TechRadarView: View {
    let session: BaseSession
    let payload: TechRadarPayload

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
