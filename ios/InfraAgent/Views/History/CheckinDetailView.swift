import SwiftUI

struct CheckinDetailView: View {
    let checkin: Checkin

    var body: some View {
        List {
            Section("总结") {
                Text(checkin.summary)
                LabeledContent("状态", value: checkin.status)
                LabeledContent("时长", value: "\(checkin.durationMin) 分钟")
            }

            Section("关键洞察") {
                Text(checkin.keyInsight.isEmpty ? "没有记录洞察。" : checkin.keyInsight)
            }

            Section("下一步") {
                Text(checkin.nextAction.isEmpty ? "没有记录下一步。" : checkin.nextAction)
            }

            if hasSourceContext {
                Section("回看线索") {
                    if let sourceTitle = nonEmpty(checkin.sourceTitle) {
                        Text(sourceTitle)
                            .font(.headline)
                    }
                    if let sourceURL = nonEmpty(checkin.sourceURL), let url = URL(string: sourceURL) {
                        Link("打开网页", destination: url)
                    }
                    if let sourceSummary = nonEmpty(checkin.sourceSummary) {
                        Text(sourceSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let userNotes = nonEmpty(checkin.userNotes) {
                        Text(userNotes)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("打卡记录")
    }

    private var hasSourceContext: Bool {
        nonEmpty(checkin.sourceTitle) != nil ||
            nonEmpty(checkin.sourceURL) != nil ||
            nonEmpty(checkin.sourceSummary) != nil ||
            nonEmpty(checkin.userNotes) != nil
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
