from datetime import date
from typing import Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query, Response

from app.schemas.checkin import Checkin, CheckinCreate
from app.schemas.completion import CompletionConfirmRequest, CompletionDraftRequest, CompletionDraftResponse, WeeklyStudioDraftResponse
from app.services.checkin_service import CheckinService


router = APIRouter(tags=["checkins"])
checkin_service = CheckinService()


@router.post("/checkins", response_model=Checkin)
def create_checkin(request: CheckinCreate) -> Checkin:
    return checkin_service.create_checkin(request)


@router.get("/checkins", response_model=List[Checkin])
def list_checkins(target_date: Optional[date] = Query(default=None, alias="date")) -> List[Checkin]:
    return checkin_service.list_checkins(target_date.isoformat() if target_date else None)


@router.get("/checkins/{checkin_id}", response_model=Checkin)
def get_checkin(checkin_id: str) -> Checkin:
    checkin = checkin_service.get_checkin(checkin_id)
    if checkin is None:
        raise HTTPException(status_code=404, detail="Checkin not found")
    return checkin


@router.delete("/checkins/{checkin_id}", status_code=204)
def delete_checkin(checkin_id: str) -> Response:
    deleted = checkin_service.delete_checkin(checkin_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Checkin not found")
    return Response(status_code=204)


@router.post("/sessions/{session_id}/completion/confirm")
def confirm_session_completion(session_id: str, request: CompletionConfirmRequest) -> Dict[str, object]:
    result = checkin_service.confirm_completion(session_id, request)
    if result is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return result


@router.post("/sessions/{session_id}/completion/draft", response_model=CompletionDraftResponse)
def draft_session_completion(
    session_id: str,
    request: CompletionDraftRequest,
) -> CompletionDraftResponse:
    result = checkin_service.draft_completion(session_id, request)
    if result is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return result


@router.post("/sessions/{session_id}/weekly-studio/draft", response_model=WeeklyStudioDraftResponse)
def draft_weekly_studio(session_id: str) -> WeeklyStudioDraftResponse:
    result = checkin_service.draft_weekly_studio(session_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Weekly Studio session or user context not found")
    return result
