from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel


class CompletionItemStatus(str, Enum):
    not_started = "not_started"
    in_progress = "in_progress"
    met = "met"
    skipped = "skipped"


class CompletionSuggestion(str, Enum):
    completed = "completed"
    partial = "partial"
    skipped = "skipped"


class CompletionCriterion(BaseModel):
    id: str
    description: str
    required: bool = True
    status: CompletionItemStatus = CompletionItemStatus.not_started


class CompletionEvidence(BaseModel):
    id: str
    type: str
    description: str
    created_at: datetime


class CompletionState(BaseModel):
    criteria: List[CompletionCriterion] = []
    evidence: List[CompletionEvidence] = []
    system_suggestion: CompletionSuggestion = CompletionSuggestion.partial
    system_reason: str = ""
    user_confirmed_status: Optional[CompletionSuggestion] = None
    confirmed_at: Optional[datetime] = None


class CompletionConfirmRequest(BaseModel):
    duration_min: int
    status: CompletionSuggestion
    summary: str
    key_insight: str = ""
    next_action: str = ""
    source_title: str = ""
    source_url: str = ""
    source_summary: str = ""
    user_notes: str = ""


class CompletionDraftRequest(BaseModel):
    duration_min: int = 30
    source_title: str = ""
    source_url: str = ""
    source_summary: str = ""
    user_notes: str = ""


class CompletionDraftResponse(BaseModel):
    summary: str
    key_insight: str
    next_action: str
    provider: str = "mock"


class WeeklyStudioDraftResponse(BaseModel):
    completion_summary: str
    blockers: str
    suggested_priorities: List[str] = []
    provider: str = "mock"
