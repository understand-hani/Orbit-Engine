import SwiftUI

struct KeyFigureDetailView: View {
    let session: BaseSession
    let paperID: String
    let figure: KeyFigure

    var body: some View {
        List {
            Section("图") {
                Text(figure.figureLabel.isEmpty ? "关键图" : figure.figureLabel)
                    .font(.headline)
                if let page = figure.page {
                    LabeledContent("页码", value: "\(page)")
                }
                Text(figure.visual.caption)
                    .foregroundStyle(.secondary)
                if !figure.visual.localPath.isEmpty {
                    PDFKitView(
                        documentURL: URL(fileURLWithPath: figure.visual.localPath),
                        initialPage: figure.page
                    )
                    .frame(minHeight: 420)
                }
            }

            Section("Agent 分析") {
                Text(figure.whyImportant)
            }

            Section("阅读问题") {
                Text(figure.readingQuestion)
            }

            Section("Agent 讨论") {
                NavigationLink {
                    AgentChatView(
                        session: session,
                        contextRefs: [paperID, figure.id],
                        title: "Agent 讨论"
                    )
                } label: {
                    Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                }
            }

            PartRecordFormView(
                session: session,
                defaultSummary: figure.figureLabel.isEmpty ? "复盘关键图" : "复盘 \(figure.figureLabel)",
                defaultKeyInsight: figure.whyImportant
            )
        }
        .navigationTitle("图")
        .navigationBarTitleDisplayMode(.inline)
    }
}
