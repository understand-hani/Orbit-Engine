import SwiftUI

struct PartRecordFormView: View {
    let session: BaseSession
    let defaultSummary: String
    let defaultKeyInsight: String
    let sourceTitle: String?
    let sourceURL: String?
    let sourceSummary: String?
    let userNotes: String?
    let sectionTitle: String
    let status: String

    @State private var summary: String
    @State private var keyInsight: String
    @State private var nextAction = ""
    @State private var durationMin = 15
    @State private var isSaving = false
    @State private var message: String?

    private let checkinAPI = CheckinAPI()

    init(
        session: BaseSession,
        defaultSummary: String,
        defaultKeyInsight: String,
        sourceTitle: String? = nil,
        sourceURL: String? = nil,
        sourceSummary: String? = nil,
        userNotes: String? = nil,
        sectionTitle: String = "记录",
        status: String = "partial"
    ) {
        self.session = session
        self.defaultSummary = defaultSummary
        self.defaultKeyInsight = defaultKeyInsight
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.sourceSummary = sourceSummary
        self.userNotes = userNotes
        self.sectionTitle = sectionTitle
        self.status = status
        _summary = State(initialValue: defaultSummary)
        _keyInsight = State(initialValue: defaultKeyInsight)
    }

    var body: some View {
        Section(sectionTitle) {
            TextField("总结", text: $summary, axis: .vertical)
                .lineLimit(2...5)
            TextField("关键洞察", text: $keyInsight, axis: .vertical)
                .lineLimit(2...5)
            TextField("下一步行动", text: $nextAction, axis: .vertical)
                .lineLimit(1...3)
            Stepper("时长：\(durationMin) 分钟", value: $durationMin, in: 5...120, step: 5)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await save() }
            } label: {
                Label(isSaving ? "正在保存" : "保存到归档", systemImage: "tray.and.arrow.down")
            }
            .disabled(isSaving || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    status: status,
                    summary: summary,
                    keyInsight: keyInsight,
                    nextAction: nextAction,
                    sourceTitle: sourceTitle,
                    sourceURL: sourceURL,
                    sourceSummary: sourceSummary,
                    userNotes: userNotes
                )
            )
            message = "已保存到归档"
        } catch {
            message = error.localizedDescription
        }
    }
}
