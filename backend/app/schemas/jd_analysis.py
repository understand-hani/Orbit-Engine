from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, HttpUrl


class JDSourceType(str, Enum):
    pasted_text = "pasted_text"
    link = "link"
    screenshot_ocr = "screenshot_ocr"
    manual_note = "manual_note"
    recruiter_message = "recruiter_message"


class RoleType(str, Enum):
    research_engineer = "research_engineer"
    algorithm_engineer = "algorithm_engineer"
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


class ResumeSuggestionStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    needs_evidence = "needs_evidence"


class JDInput(BaseModel):
    id: str
    source_type: JDSourceType
    company: str = ""
    role_title: str = ""
    location: str = ""
    url: Optional[HttpUrl] = None
    jd_text: str = ""
    recruiter_context: str = ""
    user_question: str = ""
    created_at: datetime


class JDInputCreate(BaseModel):
    source_type: JDSourceType = JDSourceType.pasted_text
    company: str = ""
    role_title: str = ""
    location: str = ""
    url: Optional[HttpUrl] = None
    jd_text: str = ""
    recruiter_context: str = ""
    user_question: str = ""


class JDAnalysis(BaseModel):
    role_type: RoleType
    match_level: MatchLevel
    technical_overlap: List[str] = []
    red_flags: List[str] = []
    fatal_gaps: List[str] = []
    trainable_gaps: List[str] = []
    timing_recommendation: TimingRecommendation
    overall_recommendation: str


class ResumeRevisionSuggestion(BaseModel):
    id: str
    target_section: str
    current_text: str = ""
    suggested_text: str
    reason: str
    risk: str = ""
    status: ResumeSuggestionStatus = ResumeSuggestionStatus.pending


class CapabilityAction(BaseModel):
    id: str
    title: str
    reason: str
    related_gap: str
    suggested_timeframe: str = ""
    status: str = "pending"


class JDAnalysisPayload(BaseModel):
    jd_input: JDInput
    resume_profile_snapshot_id: Optional[str] = None
    learning_plan_snapshot_id: Optional[str] = None
    analysis: JDAnalysis
    resume_revision_suggestions: List[ResumeRevisionSuggestion] = []
    capability_actions: List[CapabilityAction] = []
