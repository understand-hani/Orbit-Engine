import SwiftUI

struct PaperDetailView: View {
    let session: BaseSession
    let paper: Paper
    let reader: PaperReader?
    let notes: PaperNotes?

    var body: some View {
        List {
            Section("论文") {
                Text(paper.title)
                    .font(.headline)
                if !paper.authors.isEmpty {
                    Text(paper.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("会议/期刊", value: paper.venue)
                if let year = paper.year {
                    LabeledContent("年份", value: "\(year)")
                }
                TagRow(tags: paper.tags)
            }

            Section("为什么选它") {
                Text(paper.whySelected)
            }

            Section("摘要") {
                Text(paper.summary)
            }

            if let reader {
                Section("阅读器") {
                    NavigationLink {
                        PaperPDFReaderView(reader: reader)
                    } label: {
                        Label("打开 PDF 阅读器", systemImage: "doc.richtext")
                    }

                    NavigationLink {
                        AgentChatView(
                            session: session,
                            contextRefs: [paper.id],
                            title: "Agent 讨论"
                        )
                    } label: {
                        Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                    }
                }

                Section("阅读章节") {
                    ForEach(reader.sections) { section in
                        NavigationLink {
                            ReadingSectionDetailView(session: session, paperID: paper.id, section: section)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.sectionName)
                                    .font(.headline)
                                Text(section.whyRead)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("精选段落") {
                    ForEach(reader.selectedPassages) { passage in
                        NavigationLink {
                            SelectedPassageDetailView(session: session, paperID: paper.id, passage: passage)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(passage.sectionName.isEmpty ? "精选段落" : passage.sectionName)
                                    .font(.headline)
                                Text(passage.textExcerpt)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("关键图") {
                    ForEach(reader.keyFigures) { figure in
                        NavigationLink {
                            KeyFigureDetailView(session: session, paperID: paper.id, figure: figure)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(figure.figureLabel.isEmpty ? "关键图" : figure.figureLabel)
                                    .font(.headline)
                                Text(figure.whyImportant)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            if let notes {
                Section("笔记") {
                    LabeledContent("核心", value: notes.coreIdea.isEmpty ? "未开始" : notes.coreIdea)
                    LabeledContent("下一步", value: notes.nextAction.isEmpty ? "未设置" : notes.nextAction)
                    if !notes.relationToMyPlan.isEmpty {
                        Text(notes.relationToMyPlan)
                    }
                }
            }

            if let url = paper.url {
                Section("链接") {
                    Link("打开论文页面", destination: url)
                }
            }
        }
        .navigationTitle("论文")
        .navigationBarTitleDisplayMode(.inline)
    }
}
