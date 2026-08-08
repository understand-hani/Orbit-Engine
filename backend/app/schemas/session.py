from datetime import date, datetime
from typing import Union

from pydantic import BaseModel

from app.schemas.common import SessionMode, SessionStatus, SuggestedAction, TaskType
from app.schemas.completion import CompletionState
from app.schemas.jd_analysis import JDAnalysisPayload
from app.schemas.research_feeder import ResearchFeederPayload
from app.schemas.tech_radar import TechRadarPayload


SessionPayload = Union[TechRadarPayload, JDAnalysisPayload, ResearchFeederPayload]


class BaseSession(BaseModel):
    id: str
    date: date
    weekday: str
    task_type: TaskType
    session_mode: SessionMode
    title: str
    subtitle: str = ""
    status: SessionStatus = SessionStatus.active
    suggested_action: SuggestedAction
    payload_type: TaskType
    payload: SessionPayload
    ai_chat_thread_id: str
    completion: CompletionState
    created_at: datetime
    updated_at: datetime


class SessionRenameRequest(BaseModel):
    suffix: str
