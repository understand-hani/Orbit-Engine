import SwiftUI

struct ResearchReaderView: View {
    let session: BaseSession
    let payload: ResearchFeederPayload
    var onArchiveRequested: ((CompletionStartMode) -> Void)?

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

                Section {
                    ForEach(completionCriteria) { criterion in
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(criterion.description)
                                Text(criterion.required ? "必须完成" : "可选")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: criterionIcon(criterion.status))
                        }
                    }
                } header: {
                    Text("完成标准")
                } footer: {
                    Text("这些标准定义本次 Deep Dive 做到什么程度可以归档，避免阅读结束后不知道如何收束。")
                }

                Section("30 / 60 / 90 分钟路径") {
                    TimePathRow(
                        title: "30 分钟",
                        detail: "读摘要、结论和方法图，写清楚问题、核心思路和是否相关。"
                    )
                    TimePathRow(
                        title: "60 分钟",
                        detail: "在 30 分钟基础上补读方法和实验，记录 2-3 个关键技术点。"
                    )
                    TimePathRow(
                        title: "90 分钟",
                        detail: "在 60 分钟基础上做横向比较，形成继续、跟踪或放弃判断。"
                    )
                }

                Section {
                    Button {
                        onArchiveRequested?(.agent)
                    } label: {
                        Label("Agent Guidance", systemImage: "sparkles")
                    }

                    Button {
                        onArchiveRequested?(.manual)
                    } label: {
                        Label("Check-in / 归档", systemImage: "checkmark.circle.fill")
                    }
                } footer: {
                    Text("Agent Guidance 会先生成 Check-in 草稿；保存后写入 History，并从未完成队列中移除。")
                }
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

    private var completionCriteria: [CompletionCriterion] {
        if !session.completion.criteria.isEmpty {
            return session.completion.criteria
        }
        return [
            CompletionCriterion(
                id: "understand_problem",
                description: "说明这份材料解决的问题和核心输入输出。",
                required: true,
                status: "not_started"
            ),
            CompletionCriterion(
                id: "capture_insight",
                description: "记录一个对当前方向判断有价值的技术 insight。",
                required: true,
                status: "not_started"
            ),
            CompletionCriterion(
                id: "decide_next_action",
                description: "给出继续、跟踪或放弃判断，并写出下一步行动。",
                required: true,
                status: "not_started"
            )
        ]
    }

    private func criterionIcon(_ status: String) -> String {
        switch status {
        case "met":
            return "checkmark.circle.fill"
        case "in_progress":
            return "circle.lefthalf.filled"
        case "skipped":
            return "minus.circle"
        default:
            return "circle"
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

private struct TimePathRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
