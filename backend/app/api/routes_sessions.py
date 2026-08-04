from datetime import date
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query

from app.schemas.session import BaseSession
from app.schemas.jd_analysis import JDInputCreate
from app.services.feed_service import FeedService


router = APIRouter(tags=["sessions"])
feed_service = FeedService()


@router.get("/sessions/preview", response_model=BaseSession)
def preview_session(target_date: Optional[date] = Query(default=None, alias="date")) -> BaseSession:
    return feed_service.preview_session(target_date)


@router.get("/sessions/mock", response_model=BaseSession)
def mock_session(target_date: Optional[date] = Query(default=None, alias="date")) -> BaseSession:
    return feed_service.generate_mock_session(target_date)


@router.post("/sessions/mock", response_model=BaseSession)
def generate_and_save_mock_session(
    target_date: Optional[date] = Query(default=None, alias="date")
) -> BaseSession:
    return feed_service.generate_and_save_mock_session(target_date)


@router.get("/sessions/today", response_model=BaseSession)
def get_or_create_today_session(
    target_date: Optional[date] = Query(default=None, alias="date")
) -> BaseSession:
    return feed_service.get_or_create_mock_session(target_date)


@router.get("/sessions/by-date", response_model=List[BaseSession])
def get_sessions_by_date(target_date: date = Query(alias="date")) -> List[BaseSession]:
    return feed_service.get_sessions_by_date(target_date)


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
