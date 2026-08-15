import SwiftUI

struct DailyHistoryView: View {
    let date: String
    let checkins: [Checkin]
    let sessionTitlesByID: [String: String]

    private var totalDuration: Int {
        checkins.reduce(0) { $0 + $1.durationMin }
    }

    var body: some View {
        List {
            Section("日期总结") {
                LabeledContent("日期", value: date)
                LabeledContent("归档数", value: "\(checkins.count)")
                LabeledContent("时长", value: "\(totalDuration) 分钟")
            }

            Section("归档记录") {
                ForEach(checkins) { checkin in
                    NavigationLink {
                        CheckinDetailView(
                            checkin: checkin,
                            sessionTitle: cardTitle(for: checkin)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(cardTitle(for: checkin))
                                .font(.headline)
                            Text(checkin.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text("\(checkin.taskType.rawValue) · \(statusLabel(checkin.status)) · \(checkin.durationMin) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(date)
    }

    private func cardTitle(for checkin: Checkin) -> String {
        if let title = nonEmpty(checkin.sessionTitle) {
            return title
        }
        if let title = nonEmpty(sessionTitlesByID[checkin.sessionID]) {
            return title
        }
        return nonEmpty(checkin.sourceTitle) ?? checkin.summary
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "completed":
            return "已完成"
        case "skipped":
            return "已丢弃"
        case "archived":
            return "已暂存"
        case "partial":
            return "未完成归档"
        default:
            return status
        }
    }
}
