import SwiftUI

struct CheckinDetailView: View {
    let checkin: Checkin

    @State private var loadedSourceContext: CheckinSourceContext?
    @State private var sourceLoadMessage: String?

    private let sessionAPI = SessionAPI()

    var body: some View {
        List {
            Section("总结") {
                Text(checkin.summary)
                LabeledContent("状态", value: checkin.status)
                LabeledContent("时长", value: "\(checkin.durationMin) 分钟")
            }

            Section("关键洞察") {
                Text(checkin.keyInsight.isEmpty ? "没有记录洞察。" : checkin.keyInsight)
            }

            Section("下一步") {
                Text(checkin.nextAction.isEmpty ? "没有记录下一步。" : checkin.nextAction)
            }

            if hasSourceContext {
                Section("回看线索") {
                    if let sourceTitle = nonEmpty(effectiveSourceContext?.sourceTitle) {
                        Text(sourceTitle)
                            .font(.headline)
                    }
                    if let sourceURL = nonEmpty(effectiveSourceContext?.sourceURL), let url = URL(string: sourceURL) {
                        Link("打开网页", destination: url)
                    }
                    if let sourceSummary = nonEmpty(effectiveSourceContext?.sourceSummary) {
                        Text(sourceSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let userNotes = nonEmpty(effectiveSourceContext?.userNotes) {
                        Text(userNotes)
                            .font(.subheadline)
                    }
                }
            } else if let sourceLoadMessage {
                Section("回看线索") {
                    Text(sourceLoadMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("打卡记录")
        .task {
            await loadSourceContextIfNeeded()
        }
    }

    private var hasSourceContext: Bool {
        effectiveSourceContext != nil
    }

    private var effectiveSourceContext: CheckinSourceContext? {
        if nonEmpty(checkin.sourceTitle) != nil ||
            nonEmpty(checkin.sourceURL) != nil ||
            nonEmpty(checkin.sourceSummary) != nil ||
            nonEmpty(checkin.userNotes) != nil {
            return CheckinSourceContext(
                sourceTitle: checkin.sourceTitle ?? "",
                sourceURL: checkin.sourceURL,
                sourceSummary: checkin.sourceSummary,
                userNotes: checkin.userNotes
            )
        }
        return loadedSourceContext
    }

    private func loadSourceContextIfNeeded() async {
        guard effectiveSourceContext == nil else {
            return
        }
        do {
            let session = try await sessionAPI.session(id: checkin.sessionID)
            loadedSourceContext = defaultCheckinContext(for: session)
            if loadedSourceContext == nil {
                sourceLoadMessage = "这条记录没有关联材料。"
            }
        } catch {
            sourceLoadMessage = "无法加载关联材料：\(error.localizedDescription)"
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
