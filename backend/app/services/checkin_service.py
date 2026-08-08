from datetime import datetime, timezone
from typing import Dict, List, Optional
from uuid import uuid4

from app.db.repositories import CheckinRepository, SessionRepository
from app.schemas.checkin import Checkin, CheckinCreate, CheckinStatus
from app.schemas.common import SessionStatus, TaskType
from app.schemas.completion import (
    CompletionConfirmRequest,
    CompletionDraftRequest,
    CompletionDraftResponse,
    CompletionSuggestion,
)
from app.schemas.research_feeder import ResearchFeederPayload
from app.schemas.session import BaseSession
from app.config import get_settings
from app.services.llm_service import (
    DEEP_DIVE_COMPLETION_DRAFT_SYSTEM_PROMPT,
    LLMCompletionDraftOutput,
    OpenRouterChatService,
)


class CheckinService:
    def __init__(self) -> None:
        self.checkins = CheckinRepository()
        self.sessions = SessionRepository()
        self.settings = get_settings()
        self.llm = OpenRouterChatService()

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

    def draft_completion(
        self,
        session_id: str,
        request: CompletionDraftRequest,
    ) -> Optional[CompletionDraftResponse]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None

        if self.settings.llm_provider == "openrouter":
            try:
                output = self.llm.generate_json(
                    system_prompt=DEEP_DIVE_COMPLETION_DRAFT_SYSTEM_PROMPT,
                    user_payload=self._draft_payload(session, request),
                    output_model=LLMCompletionDraftOutput,
                    schema_name="deep_dive_completion_draft",
                )
                return CompletionDraftResponse(
                    summary=output.summary,
                    key_insight=output.key_insight,
                    next_action=output.next_action,
                    provider="openrouter",
                )
            except Exception:
                pass

        mock = self._mock_draft(session, request)
        return mock.model_copy(update={"provider": "mock"})

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

    def _draft_payload(self, session: BaseSession, request: CompletionDraftRequest) -> dict:
        payload = {
            "session": {
                "id": session.id,
                "date": session.date.isoformat(),
                "task_type": session.task_type.value,
                "title": session.title,
                "subtitle": session.subtitle,
                "duration_min": request.duration_min,
                "completion_criteria": [item.model_dump(mode="json") for item in session.completion.criteria],
            },
            "source": request.model_dump(mode="json"),
        }
        if session.task_type == TaskType.research_feeder and isinstance(session.payload, ResearchFeederPayload):
            primary_paper = next(
                (paper for paper in session.payload.papers if paper.id == session.payload.reading_pack.primary_paper_id),
                session.payload.papers[0] if session.payload.papers else None,
            )
            payload["deep_dive"] = {
                "research_context": session.payload.research_context.model_dump(mode="json"),
                "reading_pack": session.payload.reading_pack.model_dump(mode="json"),
                "primary_paper": primary_paper.model_dump(mode="json") if primary_paper else None,
                "notes": session.payload.notes.model_dump(mode="json"),
            }
        return payload

    def _mock_draft(
        self,
        session: BaseSession,
        request: CompletionDraftRequest,
    ) -> CompletionDraftResponse:
        if session.task_type == TaskType.research_feeder and isinstance(session.payload, ResearchFeederPayload):
            primary_paper = next(
                (paper for paper in session.payload.papers if paper.id == session.payload.reading_pack.primary_paper_id),
                session.payload.papers[0] if session.payload.papers else None,
            )
            primary_title = request.source_title or (primary_paper.title if primary_paper else "本次 Deep Dive 材料")
            key_insight = (
                session.payload.notes.core_idea
                or request.source_summary
                or session.payload.reading_pack.reading_goal
                or "本次材料帮助判断它是否值得继续投入阅读时间。"
            )
            next_action = (
                session.payload.notes.next_action
                or "根据本次阅读结果，决定继续精读、加入跟踪列表或归档为阶段性参考。"
            )
            return CompletionDraftResponse(
                summary=f"完成了 Deep Dive：围绕「{primary_title}」梳理了材料目标、推荐理由和阅读重点。",
                key_insight=key_insight,
                next_action=next_action,
                provider="mock",
            )
        return CompletionDraftResponse(
            summary=f"完成了 {session.title}：记录了本次 session 的主要进展。",
            key_insight=request.source_summary or "本次 session 产生了一个可继续跟踪的判断。",
            next_action="把本次结果写入归档，并决定下一步是否继续推进。",
            provider="mock",
        )

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
