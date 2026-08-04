import SwiftUI

struct SkillStackView: View {
    @State private var snapshot: SkillStackSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = JDIntelligenceAPI()

    init(snapshot: SkillStackSnapshot? = nil) {
        _snapshot = State(initialValue: snapshot)
    }

    var body: some View {
        List {
            if isLoading {
                LoadingView(title: "正在加载能力栈")
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            if let snapshot {
                Section("快照") {
                    Text(snapshot.summary)
                    LabeledContent("技能数", value: "\(snapshot.skills.count)")
                }

                Section("技能") {
                    ForEach(snapshot.skills) { skill in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(skill.name)
                                .font(.headline)
                            Text(skill.gapNotes.isEmpty ? "暂无差距说明。" : skill.gapNotes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TagRow(tags: [skill.category, skill.level, "目标: \(skill.targetLevel)", skill.priority])
                            if !skill.evidence.isEmpty {
                                ForEach(skill.evidence, id: \.self) { evidence in
                                    Label(evidence, systemImage: "checkmark.circle")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                EmptyStateView(
                    title: "暂无能力快照",
                    systemImage: "chart.bar",
                    message: "加载最新能力快照。"
                )
            }
        }
        .navigationTitle("能力栈")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            if snapshot == nil {
                await load()
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await api.latestSkillSnapshot()
            errorMessage = nil
        } catch {
            snapshot = MockJDIntelligence.skillSnapshot
            errorMessage = "正在使用本地 Mock 数据：\(error.localizedDescription)"
        }
    }
}
