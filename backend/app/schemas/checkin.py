from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel

from app.schemas.common import TaskType


class CheckinStatus(str, Enum):
    completed = "completed"
    partial = "partial"
    skipped = "skipped"
    archived = "archived"


class Checkin(BaseModel):
    id: str
    session_id: str
    session_title: str = ""
    date: date
    task_type: TaskType
    duration_min: int
    status: CheckinStatus
    summary: str
    key_insight: str = ""
    next_action: str = ""
    source_title: str = ""
    source_url: str = ""
    source_summary: str = ""
    user_notes: str = ""
    created_at: datetime


class CheckinCreate(BaseModel):
    session_id: str
    date: date
    task_type: TaskType
    duration_min: int
    status: CheckinStatus
    summary: str
    key_insight: str = ""
    next_action: str = ""
    source_title: str = ""
    source_url: str = ""
    source_summary: str = ""
    user_notes: str = ""
