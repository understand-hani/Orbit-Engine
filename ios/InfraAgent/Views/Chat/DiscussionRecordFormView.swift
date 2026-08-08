import SwiftUI

struct DiscussionRecordFormView: View {
    let session: BaseSession
    let threadID: String

    @Environment(\.dismiss) private var dismiss

    @State private var summary = ""
    @State private var keyInsight = ""
    @State private var nextAction = ""
    @State private var durationMin = 15
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var message: String?

    private let chatAPI = ChatAPI()
    private let checkinAPI = CheckinAPI()

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    LoadingView(title: "正在准备总结")
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("讨论总结") {
                    TextField("总结", text: $summary, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("关键洞察") {
                    TextField("关键洞察", text: $keyInsight, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("行动项") {
                    TextField("下一步行动", text: $nextAction, axis: .vertical)
                        .lineLimit(2...6)
                    Stepper("时长：\(durationMin) 分钟", value: $durationMin, in: 5...120, step: 5)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        Label(isSaving ? "正在保存" : "保存到归档", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(isSaving || isLoading || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("保存讨论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSummary()
            }
        }
    }

    private func loadSummary() async {
        guard summary.isEmpty && keyInsight.isEmpty && nextAction.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let draft = try await chatAPI.summarize(threadID: threadID)
            summary = draft.summary
            keyInsight = draft.keyInsights.joined(separator: "\n")
            nextAction = draft.actionItems.joined(separator: "\n")
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await checkinAPI.create(
                CheckinCreate(
                    sessionID: session.id,
                    date: session.date,
                    taskType: session.taskType,
                    durationMin: durationMin,
                    status: "partial",
                    summary: "讨论记录：\(summary)",
                    keyInsight: keyInsight,
                    nextAction: nextAction,
                    sourceTitle: nil,
                    sourceURL: nil,
                    sourceSummary: nil,
                    userNotes: nil
                )
            )
            message = "已保存到归档"
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
