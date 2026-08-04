import SwiftUI

struct JDAnalysisView: View {
    @State private var session: BaseSession
    @State private var payload: JDAnalysisPayload
    @State private var isShowingInput = false

    init(session: BaseSession, payload: JDAnalysisPayload) {
        _session = State(initialValue: session)
        _payload = State(initialValue: payload)
    }

    var body: some View {
        List {
            Section("JD 输入") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(payload.jdInput.jdText.isEmpty ? "还没有添加真实 JD。" : payload.jdInput.jdText)
                        .font(.subheadline)
                        .foregroundStyle(payload.jdInput.jdText.isEmpty ? .secondary : .primary)
                        .lineLimit(6)

                    Button {
                        isShowingInput = true
                    } label: {
                        Label(payload.jdInput.jdText.isEmpty ? "添加 JD" : "编辑并分析 JD", systemImage: "square.and.pencil")
                    }
                }
                .padding(.vertical, 4)
            }

            Section("岗位") {
                LabeledContent("公司", value: payload.jdInput.company)
                LabeledContent("岗位", value: payload.jdInput.roleTitle)
                LabeledContent("类型", value: payload.analysis.roleType)
                LabeledContent("匹配度", value: payload.analysis.matchLevel)
                Text(payload.analysis.overallRecommendation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("技术重合") {
                ForEach(payload.analysis.technicalOverlap, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle")
                }
            }

            Section("差距") {
                ForEach(payload.analysis.trainableGaps, id: \.self) { item in
                    Label(item, systemImage: "wrench.and.screwdriver")
                }
            }

            Section("简历建议") {
                ForEach(payload.resumeRevisionSuggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.targetSection)
                            .font(.headline)
                        Text(suggestion.suggestedText)
                        Text(suggestion.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("行动") {
                ForEach(payload.capabilityActions) { action in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(action.title)
                            .font(.headline)
                        Text(action.reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("JD 分析")
        .sheet(isPresented: $isShowingInput) {
            JDInputFormView(session: session, initialInput: payload.jdInput) { updatedSession in
                session = updatedSession
                if case .jdAnalysis(let updatedPayload) = updatedSession.payload {
                    payload = updatedPayload
                }
            }
        }
    }
}

struct JDInputFormView: View {
    let session: BaseSession
    let initialInput: JDInput
    let onSaved: (BaseSession) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var company: String
    @State private var roleTitle: String
    @State private var location: String
    @State private var urlText: String
    @State private var jdText: String
    @State private var recruiterContext: String
    @State private var userQuestion: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let sessionAPI = SessionAPI()

    init(session: BaseSession, initialInput: JDInput, onSaved: @escaping (BaseSession) -> Void) {
        self.session = session
        self.initialInput = initialInput
        self.onSaved = onSaved
        _company = State(initialValue: initialInput.company)
        _roleTitle = State(initialValue: initialInput.roleTitle)
        _location = State(initialValue: initialInput.location)
        _urlText = State(initialValue: initialInput.url?.absoluteString ?? "")
        _jdText = State(initialValue: initialInput.jdText)
        _recruiterContext = State(initialValue: initialInput.recruiterContext)
        _userQuestion = State(initialValue: initialInput.userQuestion)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage)
                    }
                }

                Section("岗位") {
                    TextField("公司", text: $company)
                    TextField("岗位名称", text: $roleTitle)
                    TextField("地点", text: $location)
                    TextField("JD 链接", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("JD 文本") {
                    TextField("在这里粘贴完整 JD", text: $jdText, axis: .vertical)
                        .lineLimit(8...18)
                }

                Section("上下文") {
                    TextField("招聘方消息或真实上下文", text: $recruiterContext, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("你想问 Agent 的问题", text: $userQuestion, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button {
                        Task { await analyze() }
                    } label: {
                        Label(isSaving ? "正在分析" : "分析 JD", systemImage: "wand.and.stars")
                    }
                    .disabled(isSaving || jdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("JD 输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func analyze() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)

        do {
            let updated = try await sessionAPI.analyzeJD(
                sessionID: session.id,
                request: JDInputCreate(
                    sourceType: "pasted_text",
                    company: company,
                    roleTitle: roleTitle,
                    location: location,
                    url: url,
                    jdText: jdText,
                    recruiterContext: recruiterContext,
                    userQuestion: userQuestion
                )
            )
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
