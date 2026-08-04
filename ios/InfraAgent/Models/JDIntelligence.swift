import Foundation

struct JDEntry: Codable, Identifiable {
    let id: String
    let company: String
    let teamOrDepartment: String
    let roleTitle: String
    let city: String
    let sourceType: String
    let sourceName: String
    let sourceURL: URL?
    let recordDate: String
    let jdText: String
    let recruiterContext: String
    let notes: String
    let mustHaveSkills: [String]
    let bonusSkills: [String]
    let newKeywords: [String]
    let salaryRange: String
    let salaryMinK: Int?
    let salaryMaxK: Int?
    let salaryMonths: String
    let equity: String
    let educationRequirement: String
    let majorRequirement: String
    let experienceYears: String
    let paperOrPatentRequirement: String
    let domainExperienceRequirement: String
    let roleOrientation: String
    let acceptsTransition: String
    let languageOrOverseasRequirement: String
    let monthChange: String
    let personalGapAssessment: String
    let applicationPriority: String
    let status: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case company
        case teamOrDepartment = "team_or_department"
        case roleTitle = "role_title"
        case city
        case sourceType = "source_type"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case recordDate = "record_date"
        case jdText = "jd_text"
        case recruiterContext = "recruiter_context"
        case notes
        case mustHaveSkills = "must_have_skills"
        case bonusSkills = "bonus_skills"
        case newKeywords = "new_keywords"
        case salaryRange = "salary_range"
        case salaryMinK = "salary_min_k"
        case salaryMaxK = "salary_max_k"
        case salaryMonths = "salary_months"
        case equity
        case educationRequirement = "education_requirement"
        case majorRequirement = "major_requirement"
        case experienceYears = "experience_years"
        case paperOrPatentRequirement = "paper_or_patent_requirement"
        case domainExperienceRequirement = "domain_experience_requirement"
        case roleOrientation = "role_orientation"
        case acceptsTransition = "accepts_transition"
        case languageOrOverseasRequirement = "language_or_overseas_requirement"
        case monthChange = "month_change"
        case personalGapAssessment = "personal_gap_assessment"
        case applicationPriority = "application_priority"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func withStatus(_ status: String) -> JDEntry {
        JDEntry(
            id: id,
            company: company,
            teamOrDepartment: teamOrDepartment,
            roleTitle: roleTitle,
            city: city,
            sourceType: sourceType,
            sourceName: sourceName,
            sourceURL: sourceURL,
            recordDate: recordDate,
            jdText: jdText,
            recruiterContext: recruiterContext,
            notes: notes,
            mustHaveSkills: mustHaveSkills,
            bonusSkills: bonusSkills,
            newKeywords: newKeywords,
            salaryRange: salaryRange,
            salaryMinK: salaryMinK,
            salaryMaxK: salaryMaxK,
            salaryMonths: salaryMonths,
            equity: equity,
            educationRequirement: educationRequirement,
            majorRequirement: majorRequirement,
            experienceYears: experienceYears,
            paperOrPatentRequirement: paperOrPatentRequirement,
            domainExperienceRequirement: domainExperienceRequirement,
            roleOrientation: roleOrientation,
            acceptsTransition: acceptsTransition,
            languageOrOverseasRequirement: languageOrOverseasRequirement,
            monthChange: monthChange,
            personalGapAssessment: personalGapAssessment,
            applicationPriority: applicationPriority,
            status: status,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

struct LocalJDPreferenceStore {
    private static let favoriteKey = "jd_local_favorite_ids"
    private static let favoriteRemovedKey = "jd_local_favorite_removed_ids"
    private static let interestedKey = "jd_local_interested_ids"
    private static let interestedRemovedKey = "jd_local_interested_removed_ids"

    static func isFavorite(_ entry: JDEntry) -> Bool {
        if favoriteRemovedIDs.contains(entry.id) {
            return false
        }
        return entry.status == "favorite" || favoriteIDs.contains(entry.id)
    }

    static func isFavorite(_ entryID: String) -> Bool {
        favoriteIDs.contains(entryID) && !favoriteRemovedIDs.contains(entryID)
    }

    static func isInterested(_ entry: JDEntry) -> Bool {
        if interestedRemovedIDs.contains(entry.id) {
            return false
        }
        return entry.status == "watching" || interestedIDs.contains(entry.id)
    }

    static func isInterested(_ entryID: String) -> Bool {
        interestedIDs.contains(entryID) && !interestedRemovedIDs.contains(entryID)
    }

    static func setFavorite(_ isFavorite: Bool, entryID: String) {
        var ids = favoriteIDs
        var removed = favoriteRemovedIDs
        if isFavorite {
            ids.insert(entryID)
            removed.remove(entryID)
        } else {
            ids.remove(entryID)
            removed.insert(entryID)
        }
        UserDefaults.standard.set(Array(ids), forKey: favoriteKey)
        UserDefaults.standard.set(Array(removed), forKey: favoriteRemovedKey)
    }

    static func setInterested(_ isInterested: Bool, entryID: String) {
        var ids = interestedIDs
        var removed = interestedRemovedIDs
        if isInterested {
            ids.insert(entryID)
            removed.remove(entryID)
        } else {
            ids.remove(entryID)
            removed.insert(entryID)
        }
        UserDefaults.standard.set(Array(ids), forKey: interestedKey)
        UserDefaults.standard.set(Array(removed), forKey: interestedRemovedKey)
    }

    static func apply(to entries: [JDEntry]) -> [JDEntry] {
        entries.map { entry in
            if isFavorite(entry) {
                return entry.withStatus("favorite")
            }
            if isInterested(entry) && entry.status != "favorite" {
                return entry.withStatus("watching")
            }
            if entry.status == "favorite" || entry.status == "watching" {
                return entry.withStatus("new")
            }
            return entry
        }
    }

    static func preferenceTags(for entry: JDEntry) -> [String] {
        var tags: [String] = []
        if isFavorite(entry) {
            tags.append("favorite")
        }
        if isInterested(entry) {
            tags.append("interested")
        }
        return tags
    }

    private static var favoriteIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: favoriteKey) ?? [])
    }

    private static var favoriteRemovedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: favoriteRemovedKey) ?? [])
    }

    private static var interestedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: interestedKey) ?? [])
    }

    private static var interestedRemovedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: interestedRemovedKey) ?? [])
    }
}

struct JDEntryCreate: Codable {
    let company: String
    let teamOrDepartment: String
    let roleTitle: String
    let city: String
    let sourceType: String
    let sourceName: String
    let sourceURL: URL?
    let jdText: String
    let recruiterContext: String
    let notes: String
    let mustHaveSkills: [String]
    let bonusSkills: [String]
    let newKeywords: [String]
    let salaryRange: String
    let roleOrientation: String
    let applicationPriority: String

    enum CodingKeys: String, CodingKey {
        case company
        case teamOrDepartment = "team_or_department"
        case roleTitle = "role_title"
        case city
        case sourceType = "source_type"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case jdText = "jd_text"
        case recruiterContext = "recruiter_context"
        case notes
        case mustHaveSkills = "must_have_skills"
        case bonusSkills = "bonus_skills"
        case newKeywords = "new_keywords"
        case salaryRange = "salary_range"
        case roleOrientation = "role_orientation"
        case applicationPriority = "application_priority"
    }
}

struct JDImageImportRequest: Codable {
    let imageBase64: String
    let filename: String
    let sourceName: String

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case filename
        case sourceName = "source_name"
    }
}

struct JDImageImportResult: Codable {
    let ocrText: String
    let draftEntry: JDEntryCreate
    let confidence: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case ocrText = "ocr_text"
        case draftEntry = "draft_entry"
        case confidence
        case notes
    }
}

struct JDPreferenceMarkCreate: Codable {
    let interestLevel: String
    let fitFeeling: String
    let userTags: [String]
    let whyLiked: String
    let whyHesitated: String
    let followUpIntent: String

    enum CodingKeys: String, CodingKey {
        case interestLevel = "interest_level"
        case fitFeeling = "fit_feeling"
        case userTags = "user_tags"
        case whyLiked = "why_liked"
        case whyHesitated = "why_hesitated"
        case followUpIntent = "follow_up_intent"
    }
}

struct JDPreferenceMark: Codable, Identifiable {
    let id: String
    let jdEntryID: String
    let interestLevel: String
    let fitFeeling: String
    let userTags: [String]
    let whyLiked: String
    let whyHesitated: String
    let followUpIntent: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case jdEntryID = "jd_entry_id"
        case interestLevel = "interest_level"
        case fitFeeling = "fit_feeling"
        case userTags = "user_tags"
        case whyLiked = "why_liked"
        case whyHesitated = "why_hesitated"
        case followUpIntent = "follow_up_intent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SkillStackSnapshot: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let summary: String
    let skills: [SkillProfile]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case summary
        case skills
    }
}

struct SkillProfile: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let level: String
    let confidence: String
    let evidence: [String]
    let relatedProjects: [String]
    let lastPracticedAt: String?
    let targetLevel: String
    let gapNotes: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case level
        case confidence
        case evidence
        case relatedProjects = "related_projects"
        case lastPracticedAt = "last_practiced_at"
        case targetLevel = "target_level"
        case gapNotes = "gap_notes"
        case priority
    }
}

struct TaskStateSnapshot: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let currentPhase: String
    let summary: String
    let tasks: [TaskProfile]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case currentPhase = "current_phase"
        case summary
        case tasks
    }
}

struct TaskProfile: Codable, Identifiable {
    let id: String
    let title: String
    let category: String
    let status: String
    let currentPhase: String
    let relatedSkillIDs: [String]
    let deadline: String?
    let weeklySlot: String
    let progressSummary: String
    let blockers: [String]
    let nextMilestone: String
    let evidenceOutputs: [String]
    let adjustability: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case status
        case currentPhase = "current_phase"
        case relatedSkillIDs = "related_skill_ids"
        case deadline
        case weeklySlot = "weekly_slot"
        case progressSummary = "progress_summary"
        case blockers
        case nextMilestone = "next_milestone"
        case evidenceOutputs = "evidence_outputs"
        case adjustability
    }
}

struct JDFitAnalysis: Codable, Identifiable {
    let id: String
    let jdEntryID: String
    let skillSnapshotID: String
    let taskSnapshotID: String
    let roleType: String
    let matchLevel: String
    let interestAdjustedPriority: String
    let timingRecommendation: String
    let technicalOverlap: [String]
    let missingSkills: [String]
    let fatalGaps: [String]
    let trainableGaps: [String]
    let evidenceNeeded: [String]
    let redFlags: [String]
    let tpmRiskLevel: String
    let companyStyleRisk: String
    let resumeSuggestions: [String]
    let interviewSellingPoints: [String]
    let questionsToAskRecruiter: [String]
    let recommendation: String
    let reasoning: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case jdEntryID = "jd_entry_id"
        case skillSnapshotID = "skill_snapshot_id"
        case taskSnapshotID = "task_snapshot_id"
        case roleType = "role_type"
        case matchLevel = "match_level"
        case interestAdjustedPriority = "interest_adjusted_priority"
        case timingRecommendation = "timing_recommendation"
        case technicalOverlap = "technical_overlap"
        case missingSkills = "missing_skills"
        case fatalGaps = "fatal_gaps"
        case trainableGaps = "trainable_gaps"
        case evidenceNeeded = "evidence_needed"
        case redFlags = "red_flags"
        case tpmRiskLevel = "tpm_risk_level"
        case companyStyleRisk = "company_style_risk"
        case resumeSuggestions = "resume_suggestions"
        case interviewSellingPoints = "interview_selling_points"
        case questionsToAskRecruiter = "questions_to_ask_recruiter"
        case recommendation
        case reasoning
        case createdAt = "created_at"
    }
}

struct CandidateAction: Codable, Identifiable {
    let id: String
    let sourceJDIDs: [String]
    let sourceAnalysisIDs: [String]
    let relatedSkillIDs: [String]
    let relatedTaskIDs: [String]
    let actionType: String
    let title: String
    let reason: String
    let expectedOutput: String
    let effortEstimateMin: Int
    let priority: String
    let timeSensitivity: String
    let risk: String
    let suggestedSlot: String
    let status: String
    let userDecisionReason: String
    let convertedTaskID: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sourceJDIDs = "source_jd_ids"
        case sourceAnalysisIDs = "source_analysis_ids"
        case relatedSkillIDs = "related_skill_ids"
        case relatedTaskIDs = "related_task_ids"
        case actionType = "action_type"
        case title
        case reason
        case expectedOutput = "expected_output"
        case effortEstimateMin = "effort_estimate_min"
        case priority
        case timeSensitivity = "time_sensitivity"
        case risk
        case suggestedSlot = "suggested_slot"
        case status
        case userDecisionReason = "user_decision_reason"
        case convertedTaskID = "converted_task_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func withConvertedStatus(note: String) -> CandidateAction {
        withStatus("converted_to_task", note: note, convertedTaskID: "converted_\(id)")
    }

    func withStatus(_ status: String, note: String = "", convertedTaskID: String? = nil) -> CandidateAction {
        CandidateAction(
            id: id,
            sourceJDIDs: sourceJDIDs,
            sourceAnalysisIDs: sourceAnalysisIDs,
            relatedSkillIDs: relatedSkillIDs,
            relatedTaskIDs: relatedTaskIDs,
            actionType: actionType,
            title: title,
            reason: reason,
            expectedOutput: expectedOutput,
            effortEstimateMin: effortEstimateMin,
            priority: priority,
            timeSensitivity: timeSensitivity,
            risk: risk,
            suggestedSlot: suggestedSlot,
            status: status,
            userDecisionReason: note,
            convertedTaskID: convertedTaskID ?? self.convertedTaskID,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

struct LocalCandidateActionDecisionStore {
    private static let key = "jd_candidate_action_decisions"

    static func status(for actionID: String) -> String? {
        decisions[actionID]
    }

    static func save(_ action: CandidateAction) {
        var values = decisions
        values[action.id] = action.status
        UserDefaults.standard.set(values, forKey: key)
        if action.status == "converted_to_task" {
            LocalConvertedTaskStore.add(action, note: action.userDecisionReason)
        }
    }

    static func apply(to actions: [CandidateAction]) -> [CandidateAction] {
        actions.map { action in
            guard let status = status(for: action.id) else { return action }
            if status == "converted_to_task" {
                return action.withConvertedStatus(note: action.userDecisionReason)
            }
            return action.withStatus(status, note: action.userDecisionReason)
        }
    }

    private static var decisions: [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}

struct CandidateActionDecision: Codable {
    let reason: String
    let convertedTaskID: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case convertedTaskID = "converted_task_id"
    }
}

struct JDFitAnalysisResult: Codable {
    let analysis: JDFitAnalysis
    let candidateActions: [CandidateAction]

    enum CodingKeys: String, CodingKey {
        case analysis
        case candidateActions = "candidate_actions"
    }
}

struct JDDiscussionMessagePayload: Codable {
    let role: String
    let content: String
}

struct JDDiscussionRequest: Codable {
    let messages: [JDDiscussionMessagePayload]
    let content: String
}

struct JDDiscussionResponse: Codable {
    let content: String
}
