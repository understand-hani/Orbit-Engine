import SwiftUI

struct SelectedPassageDetailView: View {
    let session: BaseSession
    let paperID: String
    let passage: SelectedPassage

    var body: some View {
        List {
            Section("提取段落") {
                if let page = passage.page {
                    LabeledContent("页码", value: "\(page)")
                }
                if !passage.sectionName.isEmpty {
                    LabeledContent("章节", value: passage.sectionName)
                }
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
