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
        }
        .navigationTitle("打卡记录")
    }
}
