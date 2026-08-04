from datetime import date, datetime
from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, Field, HttpUrl


class JDSourceType(str, Enum):
    pasted_text = "pasted_text"
    link = "link"
    screenshot_ocr = "screenshot_ocr"
    recruiter_message = "recruiter_message"
    manual_note = "manual_note"
    imported_xlsx = "imported_xlsx"


class RoleOrientation(str, Enum):
    research = "research"
    engineering = "engineering"
    research_engineering = "research_engineering"
    tpm_variant = "tpm_variant"
    unclear = "unclear"


class TransitionAcceptance(str, Enum):
    yes = "yes"
    no = "no"
    depends = "depends"
    unclear = "unclear"


class ApplicationPriority(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"
    not_apply = "not_apply"
    unknown = "unknown"


class JDEntryStatus(str, Enum):
    new = "new"
    watching = "watching"
    analyzed = "analyzed"
    favorite = "favorite"
    contacting = "contacting"
    paused = "paused"
    rejected = "rejected"
    archived = "archived"


class InterestLevel(str, Enum):
    dislike = "dislike"
    neutral = "neutral"
    interested = "interested"
    favorite = "favorite"


class FitFeeling(str, Enum):
    exciting = "exciting"
    practical = "practical"
    risky = "risky"
    unclear = "unclear"


class FollowUpIntent(str, Enum):
    no_action = "no_action"
    keep_watching = "keep_watching"
    ask_recruiter = "ask_recruiter"
    build_contact_only = "build_contact_only"
    prepare_later = "prepare_later"


class SkillCategory(str, Enum):
    localization = "localization"
    slam = "slam"
    reconstruction = "reconstruction"
    world_model = "world_model"
    deep_learning_training = "deep_learning_training"
    engineering = "engineering"
    research_writing = "research_writing"
    interview = "interview"


class CapabilityLevel(str, Enum):
    none = "none"
    beginner = "beginner"
    working = "working"
    solid = "solid"
    strong = "strong"
    expert = "expert"


class ConfidenceLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class PriorityLevel(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class TaskCategory(str, Enum):
    reconstruction_line = "reconstruction_line"
    world_model_line = "world_model_line"
    direction_decision = "direction_decision"
    paper_writing = "paper_writing"
    resume_building = "resume_building"
    jd_follow_up = "jd_follow_up"
    habit = "habit"


class TaskStatus(str, Enum):
    planned = "planned"
    active = "active"
    blocked = "blocked"
    paused = "paused"
    completed = "completed"
    archived = "archived"


class Adjustability(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class JDRoleType(str, Enum):
    research_engineer = "research_engineer"
    algorithm_engineer = "algorithm_engineer"
    research_engineering = "research_engineering"
    technical_lead = "technical_lead"
    tpm_variant = "tpm_variant"
    business_operation = "business_operation"
    unclear = "unclear"


class MatchLevel(str, Enum):
    high = "high"
    medium_high = "medium_high"
    medium = "medium"
    low = "low"
    not_match = "not_match"


class TimingRecommendation(str, Enum):
    apply_now = "apply_now"
    build_contact_only = "build_contact_only"
    pause_and_prepare = "pause_and_prepare"
    do_not_apply = "do_not_apply"


class RiskLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    unknown = "unknown"


class CandidateActionType(str, Enum):
    learn = "learn"
    read_paper = "read_paper"
    run_experiment = "run_experiment"
    update_resume = "update_resume"
    contact_recruiter = "contact_recruiter"
    collect_more_jds = "collect_more_jds"
    prepare_interview_answer = "prepare_interview_answer"
    update_tech_radar_scope = "update_tech_radar_scope"


class TimeSensitivity(str, Enum):
    this_week = "this_week"
    this_month = "this_month"
    later = "later"


class CandidateActionStatus(str, Enum):
    suggested = "suggested"
    accepted = "accepted"
    rejected = "rejected"
    deferred = "deferred"
    converted_to_task = "converted_to_task"
    done = "done"


class JDEntryBase(BaseModel):
    company: str = ""
    team_or_department: str = ""
    role_title: str = ""
    city: str = ""
    source_type: JDSourceType = JDSourceType.pasted_text
    source_name: str = ""
    source_url: Optional[HttpUrl] = None
    record_date: date
    jd_text: str = ""
    recruiter_context: str = ""
    notes: str = ""
    must_have_skills: List[str] = []
    bonus_skills: List[str] = []
    new_keywords: List[str] = []
    salary_range: str = ""
    salary_min_k: Optional[int] = None
    salary_max_k: Optional[int] = None
    salary_months: str = ""
    equity: str = ""
    education_requirement: str = ""
    major_requirement: str = ""
    experience_years: str = ""
    paper_or_patent_requirement: str = ""
    domain_experience_requirement: str = ""
    role_orientation: RoleOrientation = RoleOrientation.unclear
    accepts_transition: TransitionAcceptance = TransitionAcceptance.unclear
    language_or_overseas_requirement: str = ""
    month_change: str = ""
    personal_gap_assessment: str = ""
    application_priority: ApplicationPriority = ApplicationPriority.unknown
    status: JDEntryStatus = JDEntryStatus.new


class JDEntryCreate(JDEntryBase):
    record_date: date = Field(default_factory=date.today)


class JDImageImportRequest(BaseModel):
    image_base64: str
    filename: str = ""
    source_name: str = "image_upload"


class JDImageImportResult(BaseModel):
    ocr_text: str
    draft_entry: JDEntryCreate
    confidence: ConfidenceLevel = ConfidenceLevel.medium
    notes: str = ""


class JDEntryUpdate(BaseModel):
    company: Optional[str] = None
    team_or_department: Optional[str] = None
    role_title: Optional[str] = None
    city: Optional[str] = None
    source_type: Optional[JDSourceType] = None
    source_name: Optional[str] = None
    source_url: Optional[HttpUrl] = None
    record_date: Optional[date] = None
    jd_text: Optional[str] = None
    recruiter_context: Optional[str] = None
    notes: Optional[str] = None
    must_have_skills: Optional[List[str]] = None
    bonus_skills: Optional[List[str]] = None
    new_keywords: Optional[List[str]] = None
    salary_range: Optional[str] = None
    salary_min_k: Optional[int] = None
    salary_max_k: Optional[int] = None
    salary_months: Optional[str] = None
    equity: Optional[str] = None
    education_requirement: Optional[str] = None
    major_requirement: Optional[str] = None
    experience_years: Optional[str] = None
    paper_or_patent_requirement: Optional[str] = None
    domain_experience_requirement: Optional[str] = None
    role_orientation: Optional[RoleOrientation] = None
    accepts_transition: Optional[TransitionAcceptance] = None
    language_or_overseas_requirement: Optional[str] = None
    month_change: Optional[str] = None
    personal_gap_assessment: Optional[str] = None
    application_priority: Optional[ApplicationPriority] = None
    status: Optional[JDEntryStatus] = None


class JDEntry(JDEntryBase):
    id: str
    created_at: datetime
    updated_at: datetime


class JDPreferenceMarkCreate(BaseModel):
    interest_level: InterestLevel = InterestLevel.neutral
    fit_feeling: FitFeeling = FitFeeling.unclear
    user_tags: List[str] = []
    why_liked: str = ""
    why_hesitated: str = ""
    follow_up_intent: FollowUpIntent = FollowUpIntent.no_action


class JDPreferenceMark(JDPreferenceMarkCreate):
    id: str
    jd_entry_id: str
    created_at: datetime
    updated_at: datetime


class SkillProfile(BaseModel):
    id: str
    name: str
    category: SkillCategory
    level: CapabilityLevel = CapabilityLevel.beginner
    confidence: ConfidenceLevel = ConfidenceLevel.medium
    evidence: List[str] = []
    related_projects: List[str] = []
    last_practiced_at: Optional[date] = None
    target_level: CapabilityLevel = CapabilityLevel.working
    gap_notes: str = ""
    priority: PriorityLevel = PriorityLevel.medium


class SkillStackSnapshotCreate(BaseModel):
    summary: str = ""
    skills: List[SkillProfile] = []


class SkillStackSnapshot(SkillStackSnapshotCreate):
    id: str
    created_at: datetime


class TaskProfile(BaseModel):
    id: str
    title: str
    category: TaskCategory
    status: TaskStatus = TaskStatus.planned
    current_phase: str = ""
    related_skill_ids: List[str] = []
    deadline: Optional[date] = None
    weekly_slot: str = ""
    progress_summary: str = ""
    blockers: List[str] = []
    next_milestone: str = ""
    evidence_outputs: List[str] = []
    adjustability: Adjustability = Adjustability.medium


class TaskStateSnapshotCreate(BaseModel):
    current_phase: str = ""
    summary: str = ""
    tasks: List[TaskProfile] = []


class TaskStateSnapshot(TaskStateSnapshotCreate):
    id: str
    created_at: datetime


class JDFitAnalysis(BaseModel):
    id: str
    jd_entry_id: str
    skill_snapshot_id: str
    task_snapshot_id: str
    role_type: JDRoleType = JDRoleType.unclear
    match_level: MatchLevel = MatchLevel.medium
    interest_adjusted_priority: PriorityLevel = PriorityLevel.medium
    timing_recommendation: TimingRecommendation = TimingRecommendation.pause_and_prepare
    technical_overlap: List[str] = []
    missing_skills: List[str] = []
    fatal_gaps: List[str] = []
    trainable_gaps: List[str] = []
    evidence_needed: List[str] = []
    red_flags: List[str] = []
    tpm_risk_level: RiskLevel = RiskLevel.unknown
    company_style_risk: RiskLevel = RiskLevel.unknown
    resume_suggestions: List[str] = []
    interview_selling_points: List[str] = []
    questions_to_ask_recruiter: List[str] = []
    recommendation: str = ""
    reasoning: str = ""
    created_at: datetime


class CandidateAction(BaseModel):
    id: str
    source_jd_ids: List[str] = []
    source_analysis_ids: List[str] = []
    related_skill_ids: List[str] = []
    related_task_ids: List[str] = []
    action_type: CandidateActionType
    title: str
    reason: str = ""
    expected_output: str = ""
    effort_estimate_min: int = 30
    priority: PriorityLevel = PriorityLevel.medium
    time_sensitivity: TimeSensitivity = TimeSensitivity.this_month
    risk: str = ""
    suggested_slot: str = ""
    status: CandidateActionStatus = CandidateActionStatus.suggested
    user_decision_reason: str = ""
    converted_task_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class CandidateActionDecision(BaseModel):
    reason: str = ""
    converted_task_id: Optional[str] = None


class JDFitAnalysisResult(BaseModel):
    analysis: JDFitAnalysis
    candidate_actions: List[CandidateAction] = []


class SkillKeywordTrend(BaseModel):
    keyword: str
    category: str = ""
    month_counts: Dict[str, int] = {}
    trend: str = "unknown"
    notes: str = ""


class JDDiscussionMessage(BaseModel):
    role: str
    content: str


class JDDiscussionRequest(BaseModel):
    messages: List[JDDiscussionMessage] = []
    content: str


class JDDiscussionResponse(BaseModel):
    content: str
