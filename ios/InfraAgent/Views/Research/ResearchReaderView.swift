import SwiftUI

struct ResearchReaderView: View {
    let session: BaseSession
    let payload: ResearchFeederPayload
    var onArchiveRequested: ((CompletionStartMode, CheckinSourceContext?) -> Void)?

    @State private var isShowingMaterialSheet = false
    @State private var confirmedMaterials: [ConfirmedResearchMaterial] = []
    @State private var userNotesByPaperID: [String: UserPaperNote] = [:]

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

            if confirmedMaterials.isEmpty {
                Section {
                    Button {
                        isShowingMaterialSheet = true
                    } label: {
                        Label("材料生成", systemImage: "sparkles")
                    }
                } header: {
                    Text("Deep Dive 材料入口")
                } footer: {
                    Text("先确认本次 Deep Dive 要读的材料，再进入正文阅读、Agent 讨论和归档。")
                }
            }

            if !confirmedMaterials.isEmpty {
                Section("已确认材料") {
                    ForEach(confirmedMaterials) { material in
                        if let paper = paper(for: material) {
                            paperLink(paper)
                        } else {
                            materialSummary(material)
                        }
                    }
                }

                let extraPapers = supportingPapers.filter { paper in
                    !confirmedMaterials.contains { $0.paperID == paper.id }
                }
                if !extraPapers.isEmpty {
                    Section("其他候选") {
                        ForEach(extraPapers) { paper in
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
                                .foregroundStyle(criterion.status == "met" ? .green : .secondary)
                        }
                    }
                } header: {
                    Text("完成标准")
                } footer: {
                    Text("这些标准定义本次 Deep Dive 做到什么程度可以归档，避免阅读结束后不知道如何收束。")
                }

                Section {
                    Button {
                        onArchiveRequested?(.manual, primaryCheckinContext)
                    } label: {
                        Label("Check-in / 归档", systemImage: "checkmark.circle.fill")
                    }
                } footer: {
                    Text("归档会写入 History，并保存材料标题、链接、主旨和你写下的笔记，方便之后回看。")
                }
            }
        }
        .navigationTitle("研究")
        .sheet(isPresented: $isShowingMaterialSheet) {
            DeepDiveMaterialSheet(payload: payload) { materials in
                confirmedMaterials = materials
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

    private func paper(for material: ConfirmedResearchMaterial) -> Paper? {
        guard let paperID = material.paperID else {
            return nil
        }
        return payload.papers.first { $0.id == paperID }
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
            return "checkmark.seal.fill"
        case "in_progress":
            return "hourglass"
        case "skipped":
            return "minus"
        default:
            return "flag"
        }
    }

    private func paperLink(_ paper: Paper) -> some View {
        NavigationLink {
            PaperDetailView(
                session: session,
                paper: paper,
                reader: reader(for: paper),
                notes: notes(for: paper),
                userNote: userNotesByPaperID[paper.id]
            ) { note in
                userNotesByPaperID[paper.id] = note
            }
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

    private var primaryCheckinContext: CheckinSourceContext? {
        guard let material = confirmedMaterials.first else {
            return nil
        }
        let note = material.paperID.flatMap { userNotesByPaperID[$0] }
        return CheckinSourceContext(
            sourceTitle: material.title,
            sourceURL: material.url,
            sourceSummary: nonEmpty(material.summary),
            userNotes: note?.combinedText
        )
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func materialSummary(_ material: ConfirmedResearchMaterial) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(material.title)
                .font(.headline)
            Text(material.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let url = material.url, let destination = URL(string: url) {
                Link("打开网页", destination: destination)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ConfirmedResearchMaterial: Identifiable {
    let id: String
    let paperID: String?
    let title: String
    let summary: String
    let url: String?
    let sourceType: String
}

private struct MaterialCandidate: Identifiable {
    let id: String
    let paperID: String?
    let title: String
    let summary: String
    let url: String?
    let sourceType: String

    var confirmed: ConfirmedResearchMaterial {
        ConfirmedResearchMaterial(
            id: id,
            paperID: paperID,
            title: title,
            summary: summary,
            url: url,
            sourceType: sourceType
        )
    }
}

private struct DeepDiveMaterialSheet: View {
    let payload: ResearchFeederPayload
    let onGenerated: ([ConfirmedResearchMaterial]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedSource = "public_source"
    @State private var agentSearchMode = "auto"
    @State private var title = ""
    @State private var url = ""
    @State private var summary = ""
    @State private var message: String?
    @State private var isSaving = false
    @State private var candidates: [MaterialCandidate] = []
    @State private var selectedCandidateID: String?

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
                        Text("Agent 会先给出候选材料；确认后才进入研究页。")
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

                if !candidates.isEmpty {
                    Section("候选材料") {
                        ForEach(candidates) { candidate in
                            Button {
                                selectedCandidateID = candidate.id
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selectedCandidateID == candidate.id ? "checkmark.seal.fill" : "doc.text")
                                        .foregroundStyle(selectedCandidateID == candidate.id ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(candidate.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(candidate.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                        if let url = candidate.url {
                                            Text(url)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
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
                    Button(candidates.isEmpty ? "生成候选" : "确认") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        if !candidates.isEmpty {
            return selectedCandidateID != nil
        }
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
            if candidates.isEmpty {
                candidates = makeCandidates(
                    title: trimmedTitle,
                    summary: trimmedSummary,
                    url: trimmedURL
                )
                selectedCandidateID = candidates.first?.id
                message = "请选择一个材料并确认。"
                return
            }

            guard let selected = candidates.first(where: { $0.id == selectedCandidateID }) else {
                message = "请先选择一个候选材料。"
                return
            }
            _ = try await api.add(
                DeepDiveMaterialCreate(
                    title: selected.title,
                    sourceType: selected.sourceType,
                    summary: selected.summary,
                    url: selected.url,
                    relatedPlan: "Deep Dive"
                )
            )
            onGenerated([selected.confirmed])
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func makeCandidates(title: String, summary: String, url: String) -> [MaterialCandidate] {
        if selectedSource == "url" {
            return [
                MaterialCandidate(
                    id: "url_candidate",
                    paperID: nil,
                    title: title,
                    summary: summary.isEmpty ? "用户提供的网址材料，等待阅读后补全主旨。" : summary,
                    url: url.isEmpty ? nil : url,
                    sourceType: selectedSource
                )
            ]
        }

        if selectedSource == "pdf" {
            return [
                MaterialCandidate(
                    id: "pdf_candidate",
                    paperID: nil,
                    title: title,
                    summary: summary.isEmpty ? "用户提供的 PDF 材料，等待阅读后补全主旨。" : summary,
                    url: nil,
                    sourceType: selectedSource
                )
            ]
        }

        let generated = payload.papers.prefix(3).map { paper in
            MaterialCandidate(
                id: paper.id,
                paperID: paper.id,
                title: paper.title,
                summary: summary.isEmpty ? paper.summary : summary,
                url: paper.url?.absoluteString,
                sourceType: selectedSource
            )
        }
        if !generated.isEmpty {
            return Array(generated)
        }
        return [
            MaterialCandidate(
                id: "agent_candidate",
                paperID: nil,
                title: title.isEmpty ? "Agent 推荐材料" : title,
                summary: summary.isEmpty ? payload.readingPack.readingGoal : summary,
                url: nil,
                sourceType: selectedSource
            )
        ]
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
