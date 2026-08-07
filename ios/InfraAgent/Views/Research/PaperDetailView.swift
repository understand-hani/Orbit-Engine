import SwiftUI

struct PaperDetailView: View {
    let session: BaseSession
    let paper: Paper
    let reader: PaperReader?
    let notes: PaperNotes?
    let userNote: UserPaperNote?
    var onNoteSaved: ((UserPaperNote) -> Void)?

    @State private var extractionStatus: String?
    @State private var hasExtractedReadingSignals = false
    @State private var isExtracting = false
    @State private var didLoadNoteDraft = false
    @State private var noteCoreIdea = ""
    @State private var noteNextAction = ""
    @State private var noteRelationToPlan = ""
    @State private var isShowingNoteSheet = false

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

            Section {
                Button {
                    isShowingNoteSheet = true
                } label: {
                    Label("写入笔记", systemImage: "square.and.pencil")
                }
            } header: {
                Text("我的笔记")
            } footer: {
                Text("用户可以自己记录，也可以让 Agent 生成初稿后再修改。")
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
        .sheet(isPresented: $isShowingNoteSheet) {
            PaperNoteSheet(
                notes: notes,
                onSave: { note in
                    onNoteSaved?(note)
                },
                coreIdea: $noteCoreIdea,
                nextAction: $noteNextAction,
                relationToPlan: $noteRelationToPlan
            )
        }
    }

    private func loadNoteDraftIfNeeded() {
        guard !didLoadNoteDraft else {
            return
        }
        didLoadNoteDraft = true
        noteCoreIdea = userNote?.coreIdea ?? ""
        noteNextAction = userNote?.nextAction ?? ""
        noteRelationToPlan = userNote?.relationToPlan ?? ""
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

struct UserPaperNote {
    let coreIdea: String
    let nextAction: String
    let relationToPlan: String

    var combinedText: String {
        [
            labeledLine("核心理解", coreIdea),
            labeledLine("下一步", nextAction),
            labeledLine("和当前计划的关系", relationToPlan)
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "\(label)：\(trimmed)"
    }
}

private struct PaperNoteSheet: View {
    let notes: PaperNotes?
    var onSave: (UserPaperNote) -> Void

    @Binding var coreIdea: String
    @Binding var nextAction: String
    @Binding var relationToPlan: String

    @Environment(\.dismiss) private var dismiss
    @State private var noteMode = "manual"

    var body: some View {
        NavigationStack {
            Form {
                Section("笔记方式") {
                    Picker("笔记方式", selection: $noteMode) {
                        Text("自己编辑").tag("manual")
                        Text("Agent 生成初稿").tag("agent")
                    }
                    .pickerStyle(.segmented)

                    if noteMode == "agent" {
                        Button {
                            generateDraft()
                        } label: {
                            Label("生成笔记初稿", systemImage: "sparkles")
                        }
                    }
                }

                Section("笔记内容") {
                    TextField("核心理解", text: $coreIdea, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("下一步", text: $nextAction, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("和当前计划的关系", text: $relationToPlan, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("我的笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave(
                            UserPaperNote(
                                coreIdea: coreIdea,
                                nextAction: nextAction,
                                relationToPlan: relationToPlan
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateDraft() {
        coreIdea = nonEmpty(notes?.coreIdea) ?? "记录这篇材料的核心机制、关键假设和最值得保留的判断。"
        nextAction = nonEmpty(notes?.nextAction) ?? "根据本次阅读决定继续精读、加入追踪或归档。"
        relationToPlan = nonEmpty(notes?.relationToMyPlan) ?? "说明它和当前 Deep Dive 目标、能力建设或方向判断的关系。"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
