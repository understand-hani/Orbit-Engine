from typing import List

from fastapi import APIRouter, HTTPException

from app.schemas.chat import (
    AIChatSendRequest,
    AIChatSendResponse,
    AIChatSummary,
    AIChatThread,
    AIChatThreadCreate,
)
from app.services.chat_service import ChatService


router = APIRouter(tags=["chat"])
chat_service = ChatService()


@router.post("/chat/threads", response_model=AIChatThread)
def create_thread(request: AIChatThreadCreate) -> AIChatThread:
    thread = chat_service.create_thread(request)
    if thread is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return thread


@router.get("/chat/threads/{thread_id}", response_model=AIChatThread)
def get_thread(thread_id: str) -> AIChatThread:
    thread = chat_service.get_thread(thread_id)
    if thread is None:
        raise HTTPException(status_code=404, detail="Chat thread not found")
    return thread


@router.get("/sessions/{session_id}/chat/threads", response_model=List[AIChatThread])
def get_threads_by_session(session_id: str) -> List[AIChatThread]:
    return chat_service.get_threads_by_session(session_id)


@router.post("/chat/threads/{thread_id}/messages", response_model=AIChatSendResponse)
def send_message(thread_id: str, request: AIChatSendRequest) -> AIChatSendResponse:
    response = chat_service.send_message(thread_id, request.content)
    if response is None:
        raise HTTPException(status_code=404, detail="Chat thread not found")
    return response


@router.post("/chat/threads/{thread_id}/summarize", response_model=AIChatSummary)
def summarize_thread(thread_id: str) -> AIChatSummary:
    summary = chat_service.summarize_thread(thread_id)
    if summary is None:
        raise HTTPException(status_code=404, detail="Chat thread not found")
    return summary
