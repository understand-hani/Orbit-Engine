import SwiftUI

struct JDEntryDetailView: View {
    @State private var entry: JDEntry
    @State private var analysisResult: JDFitAnalysisResult?
    @State private var analyses: [JDFitAnalysis] = []
    @State private var storedActions: [CandidateAction] = []
    @State private var isLoading = false
    @State private var message: String?
    @State private var isFavorite = false
    @State private var isInterested = false

    private let api = JDIntelligenceAPI()

    init(entry: JDEntry) {
        _entry = State(initialValue: entry)
    }

    var body: some View {
        List {
            if isLoading {
                LoadingView(title: "处理中")
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("岗位") {
                Text(entry.roleTitle.isEmpty ? "未命名岗位" : entry.roleTitle)
                    .font(.headline)
                LabeledContent("公司", value: entry.company.isEmpty ? "未知" : entry.company)
                LabeledContent("团队", value: entry.teamOrDepartment.isEmpty ? "未设置" : entry.teamOrDepartment)
                LabeledContent("城市", value: entry.city.isEmpty ? "未设置" : entry.city)
                LabeledContent("薪资", value: entry.salaryRange.isEmpty ? "未设置" : entry.salaryRange)
                TagRow(tags: [entry.applicationPriority, entry.status, entry.roleOrientation])
            }

            Section("偏好") {
                LabeledContent("当前", value: displayedPreference)

                Button {
                    Task { await toggleFavorite() }
                } label: {
                    Label(
                        isFavorite ? "已星标" : "星标",
                        systemImage: isFavorite ? "star.fill" : "star"
                    )
                }

                Button {
                    Task { await toggleInterested() }
                } label: {
                    Label(
                        isInterested ? "已感兴趣" : "标记感兴趣",
                        systemImage: isInterested ? "hand.thumbsup.fill" : "hand.thumbsup"
                    )
                }
            }

            Section("技能") {
                if entry.mustHaveSkills.isEmpty && entry.bonusSkills.isEmpty && entry.newKeywords.isEmpty {
                    Text("还没有提取技能。")
                        .foregroundStyle(.secondary)
                }
                if !entry.mustHaveSkills.isEmpty {
                    LabeledContent("硬性要求", value: entry.mustHaveSkills.joined(separator: " / "))
                }
                if !entry.bonusSkills.isEmpty {
                    LabeledContent("加分项", value: entry.bonusSkills.joined(separator: " / "))
                }
                if !entry.newKeywords.isEmpty {
                    LabeledContent("新关键词", value: entry.newKeywords.joined(separator: " / "))
                }
            }

            Section("Agent 分析") {
                Button {
                    Task { await analyze() }
                } label: {
                    Label("分析并推荐行动", systemImage: "wand.and.stars")
                }

                if let analysis = analysisResult?.analysis ?? analyses.first {
                    Text(analysis.recommendation.isEmpty ? "还没有推荐结论。" : analysis.recommendation)
                        .font(.subheadline)
                    LabeledContent("岗位类型", value: analysis.roleType)
                    LabeledContent("匹配度", value: analysis.matchLevel)
                    LabeledContent("时机", value: analysis.timingRecommendation)
                    LabeledContent("优先级", value: analysis.interestAdjustedPriority)
                }
            }

            if let analysis = analysisResult?.analysis ?? analyses.first {
                Section("技术重合") {
                    if analysis.technicalOverlap.isEmpty {
                        Text("还没有提取技术重合点。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.technicalOverlap, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                        }
                    }
                }

                Section("风险信号") {
                    if analysis.redFlags.isEmpty {
                        Text("没有明确风险信号。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.redFlags, id: \.self) { flag in
                            Label(flag, systemImage: "exclamationmark.triangle")
                        }
                    }
                    LabeledContent("TPM 风险", value: analysis.tpmRiskLevel)
                    LabeledContent("公司风格风险", value: analysis.companyStyleRisk)
                }

                Section("能力差距") {
                    if analysis.fatalGaps.isEmpty && analysis.trainableGaps.isEmpty && analysis.missingSkills.isEmpty {
                        Text("还没有提取能力差距。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(analysis.fatalGaps, id: \.self) { gap in
                        Label(gap, systemImage: "xmark.octagon")
                    }
                    ForEach(analysis.trainableGaps, id: \.self) { gap in
                        Label(gap, systemImage: "wrench.and.screwdriver")
                    }
                    ForEach(analysis.missingSkills, id: \.self) { skill in
                        Label(skill, systemImage: "questionmark.circle")
                    }
                }

                Section("需要补的证据") {
                    if analysis.evidenceNeeded.isEmpty {
                        Text("还没有提取证据要求。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.evidenceNeeded, id: \.self) { evidence in
                            Label(evidence, systemImage: "doc.text.magnifyingglass")
                        }
                    }
                }

                Section("简历建议") {
                    if analysis.resumeSuggestions.isEmpty {
                        Text("还没有简历建议。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.resumeSuggestions, id: \.self) { suggestion in
                            Label(suggestion, systemImage: "person.text.rectangle")
                        }
                    }
                }

                Section("可问招聘方的问题") {
                    if analysis.questionsToAskRecruiter.isEmpty {
                        Text("还没有可问招聘方的问题。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.questionsToAskRecruiter, id: \.self) { question in
                            Label(question, systemImage: "bubble.left")
                        }
                    }
                }

                Section("面试卖点") {
                    if analysis.interviewSellingPoints.isEmpty {
                        Text("还没有面试卖点。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.interviewSellingPoints, id: \.self) { point in
                            Label(point, systemImage: "star")
                        }
                    }
                }

                Section("推理依据") {
                    Text(analysis.recommendation)
                        .font(.subheadline)
                    if !analysis.reasoning.isEmpty {
                        Text(analysis.reasoning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let actions = analysisResult?.candidateActions, !actions.isEmpty {
                Section("候选行动") {
                    ForEach(actions) { action in
                        CandidateActionRow(action: action)
                    }
                }
            } else if !storedActions.isEmpty {
                Section("候选行动") {
                    ForEach(storedActions) { action in
                        CandidateActionRow(action: action)
                    }
                }
            }

            Section("JD 文本") {
                Text(entry.jdText.isEmpty ? "没有保存 JD 文本。" : entry.jdText)
                    .foregroundStyle(entry.jdText.isEmpty ? .secondary : .primary)
            }

            if !entry.recruiterContext.isEmpty || !entry.notes.isEmpty {
                Section("上下文") {
                    if !entry.recruiterContext.isEmpty {
                        Text(entry.recruiterContext)
                    }
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("JD 详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadLocalPreference()
            await loadAnalyses()
            await loadStoredActions()
        }
    }

    private func toggleFavorite() async {
        isFavorite.toggle()
        LocalJDPreferenceStore.setFavorite(isFavorite, entryID: entry.id)
        if isFavorite {
            entry = entry.withStatus("favorite")
            await savePreference(level: "favorite", feeling: "exciting")
        }
    }

    private func toggleInterested() async {
        isInterested.toggle()
        LocalJDPreferenceStore.setInterested(isInterested, entryID: entry.id)
        if isInterested {
            if entry.status != "favorite" {
                entry = entry.withStatus("watching")
            }
            await savePreference(level: "interested", feeling: "practical")
        }
    }

    private func savePreference(level: String, feeling: String) async {
        do {
            _ = try await api.savePreference(
                entryID: entry.id,
                request: JDPreferenceMarkCreate(
                    interestLevel: level,
                    fitFeeling: feeling,
                    userTags: [],
                    whyLiked: "",
                    whyHesitated: "",
                    followUpIntent: level == "favorite" ? "build_contact_only" : "keep_watching"
                )
            )
            let remoteEntry = try await api.entry(id: entry.id)
            if level == "favorite" || !isFavorite {
                entry = remoteEntry
            }
        } catch {
            return
        }
    }

    private var displayedPreference: String {
        let tags = LocalJDPreferenceStore.preferenceTags(for: entry)
        if tags.isEmpty {
            return "none"
        }
        return tags.joined(separator: " + ")
    }

    private func loadLocalPreference() {
        isFavorite = LocalJDPreferenceStore.isFavorite(entry)
        isInterested = LocalJDPreferenceStore.isInterested(entry)
    }

    private func analyze() async {
        isLoading = true
        defer { isLoading = false }

        do {
            analysisResult = try await api.analyze(entryID: entry.id)
            entry = try await api.entry(id: entry.id)
            await loadAnalyses()
            await loadStoredActions()
            message = "分析已生成"
        } catch {
            message = error.localizedDescription
        }
    }

    private func loadAnalyses() async {
        do {
            analyses = try await api.analyses(entryID: entry.id)
        } catch {
            if analyses.isEmpty {
                message = nil
            }
        }
    }

    private func loadStoredActions() async {
        guard let analysis = analysisResult?.analysis ?? analyses.first else {
            storedActions = []
            return
        }
        do {
            let actions = try await api.actions()
            storedActions = actions.filter { action in
                action.sourceAnalysisIDs.contains(analysis.id)
            }
        } catch {
            storedActions = []
        }
    }
}
