import SwiftUI

struct ResearchReaderView: View {
    let session: BaseSession
    let payload: ResearchFeederPayload

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
                LabeledContent("主读", value: payload.readingPack.primaryPaperID)
                if let candidateID = payload.readingPack.candidatePaperID {
                    LabeledContent("候选", value: candidateID)
                }
            }

            Section("论文") {
                ForEach(payload.papers) { paper in
                    NavigationLink {
                        PaperDetailView(
                            session: session,
                            paper: paper,
                            reader: reader(for: paper),
                            notes: notes(for: paper)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(paper.title)
                                .font(.headline)
                            Text(paper.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                            TagRow(tags: paper.tags)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("研究")
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
