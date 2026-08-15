from datetime import date
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query, Response

from app.schemas.common import TaskType
from app.schemas.session import BaseSession, SessionRenameRequest
from app.schemas.jd_analysis import JDInputCreate
from app.schemas.research_feeder import ConfirmedResearchMaterial, ResearchMaterialSearchRequest
from app.services.feed_service import FeedService


router = APIRouter(tags=["sessions"])
feed_service = FeedService()


@router.get("/sessions/preview", response_model=BaseSession)
def preview_session(
    target_date: Optional[date] = Query(default=None, alias="date"),
    task_type: Optional[TaskType] = Query(default=None),
    weekly_studio: bool = False,
) -> BaseSession:
    return feed_service.preview_session(target_date, task_type, weekly_studio)


@router.get("/sessions/mock", response_model=BaseSession)
def mock_session(
    target_date: Optional[date] = Query(default=None, alias="date"),
    task_type: Optional[TaskType] = Query(default=None),
    weekly_studio: bool = False,
) -> BaseSession:
    return feed_service.generate_mock_session(target_date, task_type, weekly_studio=weekly_studio)


@router.post("/sessions/mock", response_model=BaseSession)
def generate_and_save_mock_session(
    target_date: Optional[date] = Query(default=None, alias="date"),
    task_type: Optional[TaskType] = Query(default=None),
    weekly_studio: bool = False,
) -> BaseSession:
    return feed_service.generate_and_save_mock_session(target_date, task_type, weekly_studio=weekly_studio)


@router.get("/sessions/today", response_model=BaseSession)
def get_or_create_today_session(
    target_date: Optional[date] = Query(default=None, alias="date")
) -> BaseSession:
    return feed_service.get_or_create_mock_session(target_date)


@router.get("/sessions/by-date", response_model=List[BaseSession])
def get_sessions_by_date(target_date: date = Query(alias="date")) -> List[BaseSession]:
    return feed_service.get_sessions_by_date(target_date)


@router.delete("/sessions/{session_id}", status_code=204)
def delete_session(session_id: str) -> Response:
    deleted = feed_service.delete_session(session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found")
    return Response(status_code=204)


@router.post("/sessions/{session_id}/delete", status_code=204)
def delete_session_via_post(session_id: str) -> Response:
    deleted = feed_service.delete_session(session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found")
    return Response(status_code=204)


@router.post("/sessions/{session_id}/archive", status_code=204)
def archive_session(session_id: str) -> Response:
    archived = feed_service.archive_session(session_id)
    if not archived:
        raise HTTPException(status_code=404, detail="Session not found")
    return Response(status_code=204)


@router.post("/sessions/{session_id}/restore", response_model=BaseSession)
def restore_session(session_id: str) -> BaseSession:
    session = feed_service.restore_session(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.post("/sessions/{session_id}/rename", response_model=BaseSession)
def rename_session(session_id: str, request: SessionRenameRequest) -> BaseSession:
    try:
        session = feed_service.rename_session(session_id, request.suffix)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.post("/sessions/{session_id}/radar/refresh", response_model=BaseSession)
def refresh_radar_session(session_id: str) -> BaseSession:
    session = feed_service.refresh_tech_radar_session(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Radar session not found")
    return session


@router.post("/sessions/{session_id}/research/selected-materials", response_model=BaseSession)
def save_selected_research_materials(
    session_id: str, materials: List[ConfirmedResearchMaterial]
) -> BaseSession:
    session = feed_service.save_selected_materials(session_id, materials)
    if session is None:
        raise HTTPException(status_code=404, detail="Research session not found")
    return session


@router.post("/sessions/{session_id}/research/materials/refresh", response_model=BaseSession)
def refresh_research_materials(
    session_id: str,
    request: ResearchMaterialSearchRequest,
) -> BaseSession:
    query = " ".join(value for value in [request.query.strip(), request.note.strip()] if value)
    session = feed_service.refresh_research_materials(session_id, query=query)
    if session is None:
        raise HTTPException(status_code=404, detail="Deep Dive session not found")
    return session


@router.get("/sessions/{session_id}", response_model=BaseSession)
def get_session(session_id: str) -> BaseSession:
    session = feed_service.get_session(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.post("/sessions/{session_id}/jd-analysis", response_model=BaseSession)
def analyze_jd(session_id: str, request: JDInputCreate) -> BaseSession:
    session = feed_service.analyze_jd(session_id, request)
    if session is None:
        raise HTTPException(status_code=404, detail="JD analysis session not found")
    return session
