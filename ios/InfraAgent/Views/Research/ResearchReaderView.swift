import SwiftUI

struct ResearchReaderView: View {
    let session: BaseSession
    let payload: ResearchFeederPayload
    var onArchiveRequested: (() -> Void)?

    @State private var isShowingMaterialSheet = false
    @State private var hasGeneratedMaterials = false

    var body: some View {
        List {
            Section("目标") {
                Text(payload.researchContext.currentTask)
                Text(payload.readingPack.readingGoal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("计划") {
                Text(payload.readingPack.selectionReason)
                    .font(.subheadline)
                LabeledContent("预计用时", value: payload.readingPack.expectedFinishWindow)
            }

            Section {
                Button {
                    isShowingMaterialSheet = true
                } label: {
                    Label("材料生成", systemImage: "sparkles")
                }
            } header: {
                Text("Deep Dive 材料入口")
            } footer: {
                Text("先生成本次 Deep Dive 的材料包，再进入正文阅读、Agent 讨论和归档。")
            }

            if hasGeneratedMaterials {
                if let primaryPaper {
                    Section("主文献") {
                        paperLink(primaryPaper)
                    }
                }

                if let candidatePaper {
                    Section("候选文献") {
                        paperLink(candidatePaper)
                    }
                }

                if !supportingPapers.isEmpty {
                    Section("补充材料") {
                        ForEach(supportingPapers) { paper in
                            paperLink(paper)
                        }
                    }
                }
            }

            Section {
                Button {
                    onArchiveRequested?()
                } label: {
                    Label("已完成，归档", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } footer: {
                Text("完成本次阅读后写入 History，并从未完成队列中移除。")
            }
        }
        .navigationTitle("研究")
        .sheet(isPresented: $isShowingMaterialSheet) {
            DeepDiveMaterialSheet {
                hasGeneratedMaterials = true
            }
        }
    }

    private var primaryPaper: Paper? {
        payload.papers.first { $0.id == payload.readingPack.primaryPaperID } ?? payload.papers.first
    }

    private var candidatePaper: Paper? {
        guard let candidatePaperID = payload.readingPack.candidatePaperID else {
            return nil
        }
        return payload.papers.first { $0.id == candidatePaperID }
    }

    private var supportingPapers: [Paper] {
        payload.papers.filter { paper in
            let isPrimary = paper.id == payload.readingPack.primaryPaperID
            let isCandidate = payload.readingPack.candidatePaperID.map { paper.id == $0 } ?? false
            return !isPrimary && !isCandidate
        }
    }

    private func paperLink(_ paper: Paper) -> some View {
        NavigationLink {
            PaperDetailView(
                session: session,
                paper: paper,
                reader: reader(for: paper),
                notes: notes(for: paper)
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(paper.title)
                    .font(.headline)
                Text(paper.whySelected.isEmpty ? paper.summary : paper.whySelected)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                paperMetadataRow(paper)
                TagRow(tags: paper.tags)
            }
            .padding(.vertical, 4)
        }
    }

    private func paperMetadataRow(_ paper: Paper) -> some View {
        HStack(spacing: 8) {
            if !paper.venue.isEmpty {
                Text(paper.venue)
            }
            if let year = paper.year {
                Text("\(year)")
            }
            if reader(for: paper) != nil {
                Label("可读 PDF", systemImage: "doc.richtext")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func reader(for paper: Paper) -> PaperReader? {
        if let reader = payload.paperReaders?.first(where: { $0.paperID == paper.id }) {
            return reader
        }
        if payload.paperReader?.paperID == paper.id {
            return payload.paperReader
        }
        return nil
    }

    private func notes(for paper: Paper) -> PaperNotes? {
        paper.id == payload.readingPack.primaryPaperID ? payload.notes : nil
    }
}

private struct DeepDiveMaterialSheet: View {
    let onGenerated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedSource = "public_source"
    @State private var agentSearchMode = "auto"
    @State private var title = ""
    @State private var url = ""
    @State private var summary = ""
    @State private var message: String?
    @State private var isSaving = false

    private let api = DeepDiveMaterialAPI()

    var body: some View {
        NavigationStack {
            Form {
                Section("来源") {
                    Picker("来源", selection: $selectedSource) {
                        Text("Agent 检索").tag("public_source")
                        Text("粘贴网址").tag("url")
                        Text("个人上传").tag("pdf")
                    }
                    .pickerStyle(.segmented)
                }

                if selectedSource == "public_source" {
                    Section("Agent 检索") {
                        Picker("检索方式", selection: $agentSearchMode) {
                            Text("Agent 自动生成").tag("auto")
                            Text("输入检索主题").tag("manual")
                        }
                        .pickerStyle(.segmented)

                        if agentSearchMode == "manual" {
                            TextField("检索主题", text: $title)
                        }

                        TextField("补充说明", text: $summary, axis: .vertical)
                            .lineLimit(3...5)
                        Text("当前版本先记录检索需求；下一步接入 arXiv/GitHub 搜索后，Agent 会把候选材料放回同一个入口。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if selectedSource == "pdf" {
                    Section("个人上传") {
                        TextField("材料标题", text: $title)
                        TextField("材料说明", text: $summary, axis: .vertical)
                            .lineLimit(3...5)
                        Text("当前后端还没有二进制文件上传接口。这里先保留入口语义；真实 PDF 上传需要补文件上传、正文抽取和页码索引。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("粘贴网址") {
                        TextField("标题", text: $title)
                        TextField("https://...", text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                        TextField("材料说明", text: $summary, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("材料生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedSource == "public_source" && agentSearchMode == "auto" {
            return true
        }
        return !trimmedTitle.isEmpty
    }

    private func save() async {
        isSaving = true
        message = nil
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let materialTitle: String
            if selectedSource == "public_source" && agentSearchMode == "auto" {
                materialTitle = "Agent 自动生成检索主题"
            } else {
                materialTitle = trimmedTitle
            }

            _ = try await api.add(
                DeepDiveMaterialCreate(
                    title: materialTitle,
                    sourceType: selectedSource,
                    summary: trimmedSummary.isEmpty ? "待 Agent 读取后补全摘要。" : trimmedSummary,
                    url: selectedSource == "url" && !trimmedURL.isEmpty ? trimmedURL : nil,
                    relatedPlan: "Deep Dive"
                )
            )
            message = "材料包已生成。"
            onGenerated()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct DeepDiveMaterialAPI {
    var client: APIClient?

    private var resolvedClient: APIClient {
        client ?? .shared
    }

    func add(_ request: DeepDiveMaterialCreate) async throws -> DeepDiveMaterialResponse {
        try await resolvedClient.post("/api/user-context/materials", body: request)
    }
}

private struct DeepDiveMaterialCreate: Encodable {
    let title: String
    let sourceType: String
    let summary: String
    let url: String?
    let relatedPlan: String

    enum CodingKeys: String, CodingKey {
        case title
        case sourceType = "source_type"
        case summary
        case url
        case relatedPlan = "related_plan"
    }
}

private struct DeepDiveMaterialResponse: Decodable {
    let id: String
}
