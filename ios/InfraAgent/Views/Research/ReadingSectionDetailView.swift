import SwiftUI

struct ReadingSectionDetailView: View {
    let session: BaseSession
    let paperID: String
    let section: ReadingSection

    var body: some View {
        List {
            Section("提取内容") {
                Text(section.sectionName)
                    .font(.headline)
                if let pageStart = section.pageStart {
                    let pageEnd = section.pageEnd ?? pageStart
                    LabeledContent("页码", value: pageStart == pageEnd ? "\(pageStart)" : "\(pageStart)-\(pageEnd)")
                }
                LabeledContent("模式", value: section.readMode)
                LabeledContent("状态", value: section.status)
                Text(section.extractedText.isEmpty ? "Agent 还没有提取这一节的文本。" : section.extractedText)
            }

            Section("Agent 分析") {
                Text(section.whyRead)
            }

            Section("需要理解的知识点") {
                Text(section.agentInstruction)
                ForEach(section.knowledgePoints, id: \.self) { point in
                    Label(point, systemImage: "checkmark.circle")
                }
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: [paperID, section.id],
                        title: "Agent 讨论"
                    )
                } label: {
                    Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                }
            }

            PartRecordFormView(
                session: session,
                defaultSummary: "阅读 \(section.sectionName)",
                defaultKeyInsight: section.whyRead
            )
        }
        .navigationTitle(section.sectionName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
