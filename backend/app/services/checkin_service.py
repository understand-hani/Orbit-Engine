from datetime import datetime, timezone
from typing import Dict, List, Optional
from uuid import uuid4

from app.db.repositories import CheckinRepository, SessionRepository
from app.schemas.checkin import Checkin, CheckinCreate, CheckinStatus
from app.schemas.common import SessionStatus
from app.schemas.completion import CompletionConfirmRequest, CompletionSuggestion
from app.schemas.session import BaseSession


class CheckinService:
    def __init__(self) -> None:
        self.checkins = CheckinRepository()
        self.sessions = SessionRepository()

    def create_checkin(self, request: CheckinCreate) -> Checkin:
        checkin = Checkin(
            id=f"checkin_{uuid4().hex[:12]}",
            created_at=datetime.now(timezone.utc),
            **request.model_dump(),
        )
        return self.checkins.save(checkin)

    def get_checkin(self, checkin_id: str) -> Optional[Checkin]:
        return self.checkins.get_by_id(checkin_id)

    def list_checkins(self, target_date: Optional[str] = None) -> List[Checkin]:
        return self.checkins.list_by_date(target_date)

    def delete_checkin(self, checkin_id: str) -> bool:
        return self.checkins.delete(checkin_id)

    def confirm_completion(
        self, session_id: str, request: CompletionConfirmRequest
    ) -> Optional[Dict[str, object]]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None

        confirmed_at = datetime.now(timezone.utc)
        updated_completion = session.completion.model_copy(
            update={
                "user_confirmed_status": request.status,
                "confirmed_at": confirmed_at,
            }
        )
        updated_session = session.model_copy(
            update={
                "status": self._to_session_status(request.status),
                "completion": updated_completion,
                "updated_at": confirmed_at,
            }
        )
        self.sessions.save(updated_session)

        checkin = self.create_checkin(
            CheckinCreate(
                session_id=session.id,
                date=session.date,
                task_type=session.task_type,
                duration_min=request.duration_min,
                status=self._to_checkin_status(request.status),
                summary=request.summary,
                key_insight=request.key_insight,
                next_action=request.next_action,
                source_title=request.source_title,
                source_url=request.source_url,
                source_summary=request.source_summary,
                user_notes=request.user_notes,
            )
        )
        return {"session": updated_session, "checkin": checkin}

    def _to_session_status(self, status: CompletionSuggestion) -> SessionStatus:
        if status == CompletionSuggestion.completed:
            return SessionStatus.completed
        if status == CompletionSuggestion.skipped:
            return SessionStatus.skipped
        return SessionStatus.partial

    def _to_checkin_status(self, status: CompletionSuggestion) -> CheckinStatus:
        if status == CompletionSuggestion.completed:
            return CheckinStatus.completed
        if status == CompletionSuggestion.skipped:
            return CheckinStatus.skipped
        return CheckinStatus.partial
