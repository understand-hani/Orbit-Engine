import PhotosUI
import SwiftUI

struct JDEntryRow: View {
    let entry: JDEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.roleTitle.isEmpty ? "未命名岗位" : entry.roleTitle)
                    .font(.headline)
                if LocalJDPreferenceStore.isFavorite(entry) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("星标")
                }
                if LocalJDPreferenceStore.isInterested(entry) {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundStyle(.blue)
                        .accessibilityLabel("感兴趣")
                }
            }
            Text([entry.company, entry.city].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TagRow(tags: [entry.applicationPriority, entry.status] + Array(entry.mustHaveSkills.prefix(3)))
        }
        .padding(.vertical, 4)
    }
}

struct CandidateActionRow: View {
    let action: CandidateAction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(action.title)
                .font(.headline)
            if !action.reason.isEmpty {
                Text(action.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            if !action.expectedOutput.isEmpty {
                LabeledContent("产出", value: action.expectedOutput)
                    .font(.caption)
            }
            if !action.suggestedSlot.isEmpty {
                LabeledContent("时间槽", value: action.suggestedSlot)
                    .font(.caption)
            }
            TagRow(tags: [action.priority, action.status, action.timeSensitivity, action.actionType])
        }
        .padding(.vertical, 4)
    }
}

struct FieldListEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text, axis: .vertical)
            .lineLimit(1...4)
    }

    static func split(_ value: String) -> [String] {
        value
            .split(whereSeparator: { $0 == "," || $0 == "/" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct JDAddOptionsView: View {
    let onManualInput: () -> Void
    let onImageInput: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("添加机会") {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onManualInput()
                        }
                    } label: {
                        Label("手动输入", systemImage: "keyboard")
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onImageInput()
                        }
                    } label: {
                        Label("图片导入", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .navigationTitle("添加机会")
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
}

struct JDEntryFormView: View {
    let initialDraft: JDEntryCreate?
    let onSave: (JDEntryCreate) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var company: String
    @State private var team: String
    @State private var roleTitle: String
    @State private var city: String
    @State private var sourceName: String
    @State private var sourceURL: String
    @State private var jdText: String
    @State private var recruiterContext: String
    @State private var notes: String
    @State private var mustSkills: String
    @State private var bonusSkills: String
    @State private var newKeywords: String
    @State private var salaryRange: String
    @State private var roleOrientation: String
    @State private var applicationPriority: String
    @State private var isSaving = false

    init(initialDraft: JDEntryCreate? = nil, onSave: @escaping (JDEntryCreate) async -> Void) {
        self.initialDraft = initialDraft
        self.onSave = onSave
        _company = State(initialValue: initialDraft?.company ?? "")
        _team = State(initialValue: initialDraft?.teamOrDepartment ?? "")
        _roleTitle = State(initialValue: initialDraft?.roleTitle ?? "")
        _city = State(initialValue: initialDraft?.city ?? "")
        _sourceName = State(initialValue: initialDraft?.sourceName ?? "")
        _sourceURL = State(initialValue: initialDraft?.sourceURL?.absoluteString ?? "")
        _jdText = State(initialValue: initialDraft?.jdText ?? "")
        _recruiterContext = State(initialValue: initialDraft?.recruiterContext ?? "")
        _notes = State(initialValue: initialDraft?.notes ?? "")
        _mustSkills = State(initialValue: initialDraft?.mustHaveSkills.joined(separator: " / ") ?? "")
        _bonusSkills = State(initialValue: initialDraft?.bonusSkills.joined(separator: " / ") ?? "")
        _newKeywords = State(initialValue: initialDraft?.newKeywords.joined(separator: " / ") ?? "")
        _salaryRange = State(initialValue: initialDraft?.salaryRange ?? "")
        _roleOrientation = State(initialValue: initialDraft?.roleOrientation ?? "unclear")
        _applicationPriority = State(initialValue: initialDraft?.applicationPriority ?? "unknown")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("岗位") {
                    TextField("公司", text: $company)
                    TextField("团队/部门", text: $team)
                    TextField("岗位名称", text: $roleTitle)
                    TextField("城市", text: $city)
                    TextField("薪资范围", text: $salaryRange)
                }

                Section("来源") {
                    TextField("来源", text: $sourceName)
                    TextField("URL", text: $sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("技能") {
                    FieldListEditor(title: "硬性技能，用逗号或斜杠分隔", text: $mustSkills)
                    FieldListEditor(title: "加分技能", text: $bonusSkills)
                    FieldListEditor(title: "新增关键词", text: $newKeywords)
                }

                Section("JD 文本") {
                    TextField("在这里粘贴完整 JD", text: $jdText, axis: .vertical)
                        .lineLimit(8...18)
                }

                Section("上下文") {
                    TextField("猎头/招聘方上下文", text: $recruiterContext, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("分类") {
                    Picker("方向", selection: $roleOrientation) {
                        Text("不明确").tag("unclear")
                        Text("研究").tag("research")
                        Text("工程").tag("engineering")
                        Text("研究工程").tag("research_engineering")
                        Text("TPM 风险").tag("tpm_variant")
                    }

                    Picker("优先级", selection: $applicationPriority) {
                        Text("未知").tag("unknown")
                        Text("高").tag("high")
                        Text("中").tag("medium")
                        Text("低").tag("low")
                        Text("不投").tag("not_apply")
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        Label(isSaving ? "正在保存" : "保存机会", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(isSaving || roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("添加机会")
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

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        await onSave(
            JDEntryCreate(
                company: company,
                teamOrDepartment: team,
                roleTitle: roleTitle,
                city: city,
                sourceType: "pasted_text",
                sourceName: sourceName,
                sourceURL: trimmedURL.isEmpty ? nil : URL(string: trimmedURL),
                jdText: jdText,
                recruiterContext: recruiterContext,
                notes: notes,
                mustHaveSkills: FieldListEditor.split(mustSkills),
                bonusSkills: FieldListEditor.split(bonusSkills),
                newKeywords: FieldListEditor.split(newKeywords),
                salaryRange: salaryRange,
                roleOrientation: roleOrientation,
                applicationPriority: applicationPriority
            )
        )
        dismiss()
    }
}

struct JDImageImportView: View {
    let onDraftReady: (JDEntryCreate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var message: String?

    private let api = JDIntelligenceAPI()

    var body: some View {
        NavigationStack {
            Form {
                Section("图片") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("选择 JD 截图", systemImage: "photo.on.rectangle")
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await importSelectedImage() }
                    } label: {
                        Label(isImporting ? "正在导入" : "Mock 导入图片", systemImage: "text.viewfinder")
                    }
                    .disabled(isImporting || selectedItem == nil)
                }

                Section("当前模式") {
                    Text("目前使用 Mock OCR/解析器。后续后端可以替换成 OCR 或多模态模型，而不改变这个流程。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("导入 JD 图片")
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

    private func importSelectedImage() async {
        guard let selectedItem else { return }
        isImporting = true
        defer { isImporting = false }

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self) else {
                message = "无法读取图片数据。"
                return
            }
            let result = try await api.importImage(
                JDImageImportRequest(
                    imageBase64: data.base64EncodedString(),
                    filename: "jd_screenshot.jpg",
                    sourceName: "image_upload"
                )
            )
            onDraftReady(result.draftEntry)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
