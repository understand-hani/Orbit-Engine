import SwiftUI

struct CandidateActionDetailView: View {
    @State private var action: CandidateAction
    @State private var message: String?
    @State private var isShowingConvert = false

    let onChanged: () async -> Void

    private let api = JDIntelligenceAPI()

    init(action: CandidateAction, onChanged: @escaping () async -> Void) {
        _action = State(initialValue: action)
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            if let message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("推荐") {
                Text(action.title)
                    .font(.headline)
                Text(action.reason)
                    .foregroundStyle(.secondary)
                if !action.expectedOutput.isEmpty {
                    LabeledContent("预期产出", value: action.expectedOutput)
                }
                if !action.suggestedSlot.isEmpty {
                    LabeledContent("建议时间槽", value: action.suggestedSlot)
                }
                TagRow(tags: [action.priority, action.status, action.timeSensitivity, action.actionType])
            }

            Section("来源") {
                LabeledContent("关联 JD", value: "\(action.sourceJDIDs.count)")
                LabeledContent("关联技能", value: action.relatedSkillIDs.isEmpty ? "无" : action.relatedSkillIDs.joined(separator: " / "))
                LabeledContent("关联任务", value: action.relatedTaskIDs.isEmpty ? "无" : action.relatedTaskIDs.joined(separator: " / "))
            }

            Section("决策管理") {
                Button {
                    Task { await decide("accept") }
                } label: {
                    Label("接受", systemImage: "checkmark.circle")
                }

                Button {
                    Task { await decide("defer") }
                } label: {
                    Label("延后", systemImage: "clock")
                }

                Button {
                    Task { await decide("reject") }
                } label: {
                    Label("拒绝", systemImage: "xmark.circle")
                }

                Button {
                    isShowingConvert = true
                } label: {
                    Label("转入任务状态", systemImage: "arrow.triangle.branch")
                }
            }

            Section("决策含义") {
                Text("接受：保留为有效建议，但暂时不进入主任务计划。")
                Text("延后：之后可能有用。")
                Text("拒绝：当前不值得做，也不应反复推荐。")
                Text("转任务：把它具体插入任务状态。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("候选行动")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingConvert) {
            ConvertActionPlannerView(action: action) { converted in
                action = converted
                await onChanged()
            }
        }
    }

    private func decide(_ decision: String) async {
        let localStatus = status(for: decision)
        let localAction = action.withStatus(localStatus, note: "Decision: \(decision)")
        action = localAction
        LocalCandidateActionDecisionStore.save(localAction)
        message = "已移动到\(folderName(for: localStatus))"
        await onChanged()

        do {
            let updated: CandidateAction
            switch decision {
            case "accept":
                updated = try await api.acceptAction(id: action.id)
            case "defer":
                updated = try await api.deferAction(id: action.id)
            default:
                updated = try await api.rejectAction(id: action.id)
            }
            action = updated
            LocalCandidateActionDecisionStore.save(updated)
            message = "已移动到\(folderName(for: updated.status))"
            await onChanged()
        } catch {
            message = "已在本地移动到\(folderName(for: localStatus))：\(error.localizedDescription)"
        }
    }

    private func status(for decision: String) -> String {
        switch decision {
        case "accept":
            return "accepted"
        case "defer":
            return "deferred"
        default:
            return "rejected"
        }
    }

    private func folderName(for status: String) -> String {
        switch status {
        case "accepted":
            return "已接受"
        case "deferred":
            return "已延后"
        case "rejected":
            return "已拒绝"
        case "converted_to_task":
            return "已转任务"
        default:
            return "建议"
        }
    }
}

struct ConvertActionPlannerView: View {
    let action: CandidateAction
    let onConverted: (CandidateAction) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isAdjusting = false
    @State private var draft = ""
    @State private var messages: [String] = []
    @State private var message: String?

    private let api = JDIntelligenceAPI()

    var body: some View {
        NavigationStack {
            List {
                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("AI 推荐") {
                    Text(action.title)
                        .font(.headline)
                    Text(action.reason)
                        .foregroundStyle(.secondary)
                    LabeledContent("推荐放置位置", value: recommendedPlacement)
                    if !action.expectedOutput.isEmpty {
                        LabeledContent("任务产出", value: action.expectedOutput)
                    }
                }

                Section("决策") {
                    Button {
                        Task { await agree() }
                    } label: {
                        Label("同意并加入任务状态", systemImage: "checkmark.circle")
                    }

                    Button {
                        isAdjusting = true
                    } label: {
                        Label("和 Agent 调整", systemImage: "bubble.left.and.bubble.right")
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label("取消转入", systemImage: "xmark.circle")
                    }
                }

                if isAdjusting {
                    Section("Agent 讨论") {
                        ForEach(messages, id: \.self) { item in
                            Text(item)
                        }
                        TextField("告诉 Agent 这个任务应该放在哪里...", text: $draft, axis: .vertical)
                            .lineLimit(2...5)
                        Button("发送") {
                            sendAdjustment()
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            Task { await confirmAdjusted() }
                        } label: {
                            Label("确认调整后的计划", systemImage: "checkmark.square")
                        }
                    }
                }
            }
            .navigationTitle("转入任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var recommendedPlacement: String {
        action.suggestedSlot.isEmpty ? "任务状态 / JD 跟进池" : action.suggestedSlot
    }

    private func agree() async {
        await convert(note: "接受 AI 推荐位置：\(recommendedPlacement)")
    }

    private func confirmAdjusted() async {
        let note = messages.isEmpty ? "已确认调整后的位置。" : messages.joined(separator: "\n")
        await convert(note: note)
    }

    private func convert(note: String) async {
        LocalConvertedTaskStore.add(action, note: note)
        do {
            let updated = try await api.convertActionToTask(id: action.id, reason: note)
            LocalCandidateActionDecisionStore.save(updated)
            await onConverted(updated)
        } catch {
            let localAction = action.withConvertedStatus(note: note)
            LocalCandidateActionDecisionStore.save(localAction)
            await onConverted(localAction)
        }
        dismiss()
    }

    private func sendAdjustment() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draft = ""
        messages.append("你：\(content)")
        messages.append("Agent：Mock 计划已调整。确认后，我会按你的调整放置这个候选行动。")
    }
}
