from datetime import datetime
from enum import Enum
from typing import List

from pydantic import BaseModel

from app.schemas.common import TaskType


class ChatRole(str, Enum):
    system = "system"
    user = "user"
    assistant = "assistant"
    tool = "tool"


class AIChatMessage(BaseModel):
    id: str
    role: ChatRole
    content: str
    created_at: datetime


class AIChatThread(BaseModel):
    id: str
    session_id: str
    task_type: TaskType
    context_refs: List[str] = []
    messages: List[AIChatMessage] = []
    created_at: datetime
    updated_at: datetime


class AIChatThreadCreate(BaseModel):
    session_id: str
    context_refs: List[str] = []


class AIChatSendRequest(BaseModel):
    content: str


class AIChatSendResponse(BaseModel):
    thread: AIChatThread
    user_message: AIChatMessage
    assistant_message: AIChatMessage


class AIChatSummary(BaseModel):
    thread_id: str
    session_id: str
    suggested_title: str
    summary: str
    key_insights: List[str] = []
    action_items: List[str] = []
    context_refs: List[str] = []
