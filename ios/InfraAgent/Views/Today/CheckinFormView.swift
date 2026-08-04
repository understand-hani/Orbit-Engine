import SwiftUI

struct CheckinFormView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("打卡")
                .font(.headline)
            Text("完成确认会在任务详情流程稳定后接入。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    CheckinFormView()
}
