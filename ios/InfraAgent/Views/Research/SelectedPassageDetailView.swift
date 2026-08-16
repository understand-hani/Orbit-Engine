import SwiftUI

struct SelectedPassageDetailView: View {
    let session: BaseSession
    let paperID: String
    let passage: SelectedPassage

    var body: some View {
        List {
            Section("原文段落") {
                if let page = passage.page {
                    LabeledContent("页码", value: "\(page)")
                }
                if !passage.sectionName.isEmpty {
                    LabeledContent("章节", value: passage.sectionName)
                }
                Text("以下内容直接提取自 PDF 文本层，保持原文，不由 Agent 改写。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(passage.textExcerpt)
            }

            Section("Agent 分析") {
                Text(passage.whySelected)
            }

            Section("阅读问题") {
                Text(passage.readingQuestion)
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: [paperID, passage.id],
                        title: "Agent 讨论"
                    )
                } label: {
                    Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                }
            }

        }
        .navigationTitle("段落")
        .navigationBarTitleDisplayMode(.inline)
    }
}
