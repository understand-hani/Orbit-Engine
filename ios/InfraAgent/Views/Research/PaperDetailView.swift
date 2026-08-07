import SwiftUI

struct PaperDetailView: View {
    let session: BaseSession
    let paper: Paper
    let reader: PaperReader?
    let notes: PaperNotes?

    @State private var extractionStatus: String?
    @State private var hasExtractedReadingSignals = false
    @State private var isExtracting = false
    @State private var didLoadNoteDraft = false
    @State private var noteCoreIdea = ""
    @State private var noteNextAction = ""
    @State private var noteRelationToPlan = ""

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
            }

            Section("Agent 阅读提取") {
                Button {
                    extractReadingSignals()
                } label: {
                    if isExtracting {
                        Label("Agent 正在读取", systemImage: "hourglass")
                    } else {
                        Label("Agent 自动读取并提取关键段落", systemImage: "sparkles")
                    }
                }
                .disabled(isExtracting)

                if let extractionStatus {
                    Text(extractionStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("点击后生成阅读章节、精选段落和关键图，后续讨论会围绕这些上下文展开。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let reader, hasExtractedReadingSignals {
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

            Section("我的笔记") {
                TextField("核心理解", text: $noteCoreIdea, axis: .vertical)
                    .lineLimit(2...5)
                TextField("下一步", text: $noteNextAction, axis: .vertical)
                    .lineLimit(2...4)
                TextField("和当前计划的关系", text: $noteRelationToPlan, axis: .vertical)
                    .lineLimit(2...5)
            } footer: {
                Text("这里由用户记录阅读判断；Agent 可以提供初稿或讨论输入，但不替代你的最终笔记。")
            }

            if let url = paper.url {
                Section("链接") {
                    Link("打开论文页面", destination: url)
                }
            }
        }
        .navigationTitle("论文")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadNoteDraftIfNeeded()
        }
    }

    private func loadNoteDraftIfNeeded() {
        guard !didLoadNoteDraft else {
            return
        }
        didLoadNoteDraft = true
        noteCoreIdea = notes?.coreIdea ?? ""
        noteNextAction = notes?.nextAction ?? ""
        noteRelationToPlan = notes?.relationToMyPlan ?? ""
    }

    private func extractReadingSignals() {
        isExtracting = true
        defer { isExtracting = false }

        guard let reader else {
            extractionStatus = "当前材料还没有可读取正文。下一步需要先完成 PDF/网页正文抓取，再提取章节、段落和关键图。"
            return
        }

        let sectionCount = reader.sections.count
        let passageCount = reader.selectedPassages.count
        let figureCount = reader.keyFigures.count
        hasExtractedReadingSignals = true
        extractionStatus = "已生成 \(sectionCount) 个阅读章节、\(passageCount) 个精选段落、\(figureCount) 个关键图。当前版本使用后端结构化阅读结果；下一步会改为真实读取正文后生成。"
    }
}
