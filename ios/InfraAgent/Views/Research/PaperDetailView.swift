import SwiftUI

struct PaperDetailView: View {
    let session: BaseSession
    let paper: Paper
    let reader: PaperReader?

    @State private var extractionStatus: String?
    @State private var extractedReader: PaperReader?
    @State private var hasExtractedReadingSignals = false
    @State private var isExtracting = false

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
                if let publishedAt = paper.publishedAt {
                    LabeledContent(
                        "发布日期",
                        value: publishedAt.formatted(date: .numeric, time: .omitted)
                    )
                } else if let year = paper.year {
                    LabeledContent("年份", value: "\(year)")
                }
                if let score = paper.relevanceScore {
                    LabeledContent("与当前目标和计划的关联度") {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= max(1, min(score, 5)) ? "star.fill" : "star")
                                    .foregroundStyle(index <= max(1, min(score, 5)) ? .orange : .secondary)
                            }
                        }
                    }
                }
                TagRow(tags: paper.tags)
            }

            Section("为什么选它") {
                Text(paper.whySelected)
            }

            Section("Abstract") {
                Text(abstractText)
            }

            if let currentReader = activeReader {
                Section("阅读器") {
                    NavigationLink {
                        PaperPDFReaderView(reader: currentReader)
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
                    Task { await extractReadingSignals() }
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

            if let currentReader = activeReader, hasExtractedReadingSignals {
                Section("阅读章节") {
                    ForEach(currentReader.sections) { section in
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
                    if currentReader.selectedPassages.isEmpty {
                        Text("这份 PDF 没有提取出足够完整的文本段落，可能是扫描件或正文编码不可读。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(currentReader.selectedPassages) { passage in
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
                    if currentReader.keyFigures.isEmpty {
                        Text("未在 PDF 文本层识别到 Figure / Table 标题，不会用虚构图表补位。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(currentReader.keyFigures) { figure in
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

            if let url = paper.url {
                Section("链接") {
                    Link("打开论文页面", destination: url)
                }
            }
        }
        .navigationTitle("论文")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let reader, !reader.selectedPassages.isEmpty || !reader.keyFigures.isEmpty {
                hasExtractedReadingSignals = true
            }
        }
    }

    private var activeReader: PaperReader? {
        extractedReader ?? reader
    }

    private var abstractText: String {
        if let abstractSection = reader?.sections.first(where: { section in
            section.sectionName.localizedCaseInsensitiveContains("abstract")
        }) {
            let text = abstractSection.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }
        return paper.summary
    }

    private func extractReadingSignals() async {
        isExtracting = true
        defer { isExtracting = false }

        guard let reader else {
            extractionStatus = "当前材料还没有可读取正文。下一步需要先完成 PDF/网页正文抓取，再提取章节、段落和关键图。"
            return
        }

        do {
            extractionStatus = "正在下载并校验真实 PDF…"
            let localURL = try await PaperPDFLoader.localURL(for: reader)
            extractionStatus = "正在读取 PDF 文本层并识别关键段落与图表标题…"
            let signals = try PDFReadingSignalExtractor.extract(from: localURL, paper: paper)
            let updatedReader = PaperReader(
                paperID: reader.paperID,
                pdfLocalPath: localURL.path,
                pdfURL: reader.pdfURL,
                sections: reader.sections,
                selectedPassages: signals.selectedPassages,
                keyFigures: signals.keyFigures,
                annotations: reader.annotations
            )
            extractedReader = updatedReader
            hasExtractedReadingSignals = true

            do {
                let analyzedReader = try await MaterialAPI().savePaperReader(
                    sessionID: session.id,
                    paperID: paper.id,
                    reader: updatedReader
                )
                extractedReader = analyzedReader
                extractionStatus = "已从真实 PDF 提取 \(analyzedReader.selectedPassages.count) 个精选段落、\(analyzedReader.keyFigures.count) 个图表标题，并完成 Agent 分析。"
            } catch {
                let fallbackReader = localFallbackAnalyzedReader(updatedReader)
                extractedReader = fallbackReader
                extractionStatus = "原文已完整提取；远端 Agent 分析超时，已先生成本地保守分析。可稍后重试同步。"
            }
        } catch {
            extractionStatus = "读取失败：\(error.localizedDescription)"
        }
    }

    private func localFallbackAnalyzedReader(_ reader: PaperReader) -> PaperReader {
        PaperReader(
            paperID: reader.paperID,
            pdfLocalPath: reader.pdfLocalPath,
            pdfURL: reader.pdfURL,
            sections: reader.sections,
            selectedPassages: reader.selectedPassages.map { passage in
                SelectedPassage(
                    id: passage.id,
                    paperID: passage.paperID,
                    page: passage.page,
                    sectionName: passage.sectionName,
                    textExcerpt: passage.textExcerpt,
                    whySelected: localPassageAnalysis(passage),
                    readingQuestion: "作者在这段中提出了什么可验证判断，证据是否足以支持它，在哪些条件下可能不成立？",
                    status: passage.status
                )
            },
            keyFigures: reader.keyFigures.map { figure in
                KeyFigure(
                    id: figure.id,
                    paperID: figure.paperID,
                    page: figure.page,
                    figureLabel: figure.figureLabel,
                    visual: figure.visual,
                    whyImportant: localFigureAnalysis(figure),
                    readingQuestion: "这张图实际比较了什么，图中的变化是否足以支持正文对应结论？"
                )
            },
            annotations: reader.annotations
        )
    }

    private func localPassageAnalysis(_ passage: SelectedPassage) -> String {
        let excerpt = passage.textExcerpt
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .prefix(180)
        return "这段原文适合作为精读入口。阅读时先拆出作者的问题定义、方法假设和证据链，再判断结论是否依赖特定数据集、指标或实验设置。摘录线索：\(excerpt)"
    }

    private func localFigureAnalysis(_ figure: KeyFigure) -> String {
        let label = figure.figureLabel.isEmpty ? "这张图表" : figure.figureLabel
        return "\(label) 需要结合图中变量、模块、对照组和趋势来核对。当前只能从图题和截图定位判断它是关键证据入口，不能仅凭标题推断具体数值或因果关系。"
    }
}
