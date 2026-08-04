import SwiftUI

struct MaterialDetailView: View {
    let title: String
    let summary: String

    var body: some View {
        List {
            Section("摘要") {
                Text(summary)
            }
        }
        .navigationTitle(title)
    }
}

#Preview {
    NavigationStack {
        MaterialDetailView(title: "材料", summary: "材料详情占位。")
    }
}
