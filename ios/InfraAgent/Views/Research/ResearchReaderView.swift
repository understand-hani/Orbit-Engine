import SwiftUI

struct ResearchReaderView: View {
    let session: BaseSession
    let payload: ResearchFeederPayload
    var onArchiveRequested: (() -> Void)?

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
