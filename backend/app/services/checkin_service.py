from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
from uuid import uuid4

from app.db.repositories import ChatRepository, CheckinRepository, SessionRepository, UserContextRepository
from app.schemas.chat import ChatRole
from app.schemas.checkin import Checkin, CheckinCreate, CheckinStatus
from app.schemas.common import SessionStatus, TaskType
from app.schemas.completion import (
    CompletionConfirmRequest,
    CompletionDraftRequest,
    CompletionDraftResponse,
    CompletionSuggestion,
    WeeklyStudioDraftResponse,
)
from app.schemas.research_feeder import ResearchFeederPayload
from app.schemas.session import BaseSession
from app.schemas.tech_radar import TechRadarPayload
from app.config import get_settings
from app.services.llm_service import (
    DEEP_DIVE_COMPLETION_DRAFT_SYSTEM_PROMPT,
    LLMCompletionDraftOutput,
    LLMWeeklyStudioDraftOutput,
    OpenRouterChatService,
    WEEKLY_STUDIO_DRAFT_SYSTEM_PROMPT,
)


class CheckinService:
    def __init__(self) -> None:
        self.checkins = CheckinRepository()
        self.sessions = SessionRepository()
        self.chats = ChatRepository()
        self.user_contexts = UserContextRepository()
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

    def draft_weekly_studio(self, session_id: str) -> Optional[WeeklyStudioDraftResponse]:
        session = self.sessions.get_by_id(session_id)
        context = self.user_contexts.get()
        if session is None or context is None:
            return None

        checkins = self._week_checkins(session.date)
        weekly_sessions = self._week_sessions(session)
        payload = {
            "plan": context.plan.model_dump(mode="json"),
            "checkins": [item.model_dump(mode="json") for item in checkins],
            "weekly_evidence": self._weekly_evidence(weekly_sessions),
        }
        if self.settings.llm_provider == "openrouter":
            try:
                output = self.llm.generate_json(
                    system_prompt=WEEKLY_STUDIO_DRAFT_SYSTEM_PROMPT,
                    user_payload=payload,
                    output_model=LLMWeeklyStudioDraftOutput,
                    schema_name="weekly_studio_draft",
                )
                return WeeklyStudioDraftResponse(
                    completion_summary=output.completion_summary,
                    suggested_priorities=output.suggested_priorities[:3],
                    provider="openrouter",
                )
            except Exception:
                pass

        priorities = [item for item in context.plan.active_tasks if item][:3]
        if not priorities and context.plan.next_action:
            priorities = [context.plan.next_action]
        return WeeklyStudioDraftResponse(
            completion_summary=self._structured_weekly_summary(
                weekly_sessions,
                checkins,
                context.plan.weekly_focus,
            ),
            suggested_priorities=priorities,
            provider="mock",
        )

    def _week_checkins(self, session_date) -> List[Checkin]:
        week_start = session_date - timedelta(days=session_date.weekday())
        week_end = week_start + timedelta(days=6)
        return [
            item for item in self.checkins.list_by_date()
            if week_start <= item.date <= week_end
        ]

    def _week_sessions(self, weekly_studio: BaseSession) -> List[BaseSession]:
        week_start = weekly_studio.date - timedelta(days=weekly_studio.date.weekday())
        sessions = []
        for offset in range(7):
            sessions.extend(self.sessions.get_by_date((week_start + timedelta(days=offset)).isoformat()))
        return [item for item in sessions if item.id != weekly_studio.id]

    def _weekly_evidence(self, sessions: List[BaseSession]) -> List[dict]:
        evidence = []
        for item in sessions:
            if isinstance(item.payload, TechRadarPayload):
                evidence.append(
                    {
                        "type": "radar",
                        "title": item.title,
                        "digest_summary": item.payload.digest.summary,
                        "top_signals": item.payload.digest.top_signals[:3],
                        "signals": [
                            {
                                "title": signal.title,
                                "technical_substance": signal.technical_substance,
                                "why_it_matters": signal.why_it_matters,
                                "evidence_status": signal.evidence_status,
                                "recommended_depth": signal.recommended_depth.value,
                                "user_mark": signal.user_mark.value,
                            }
                            for signal in item.payload.digest.items[:3]
                        ],
                    }
                )
            elif isinstance(item.payload, ResearchFeederPayload):
                primary = next(
                    (paper for paper in item.payload.papers if paper.id == item.payload.reading_pack.primary_paper_id),
                    item.payload.papers[0] if item.payload.papers else None,
                )
                evidence.append(
                    {
                        "type": "deep_dive",
                        "title": item.title,
                        "current_task": item.payload.research_context.current_task,
                        "reading_goal": item.payload.reading_pack.reading_goal,
                        "primary_material": primary.title if primary else "",
                        "selected_materials": [material.title for material in item.payload.selected_materials[:3]],
                        "notes": {
                            "core_idea": item.payload.notes.core_idea,
                            "evidence": item.payload.notes.evidence,
                            "limitations": item.payload.notes.limitations,
                            "relation_to_my_plan": item.payload.notes.relation_to_my_plan,
                            "next_action": item.payload.notes.next_action,
                        },
                    }
                )
        return evidence

    def _structured_weekly_summary(
        self,
        sessions: List[BaseSession],
        checkins: List[Checkin],
        weekly_focus: str,
    ) -> str:
        conclusions = []
        radar = next((item.payload for item in sessions if isinstance(item.payload, TechRadarPayload)), None)
        if radar:
            signal = next(
                (item for item in radar.digest.items if item.technical_substance or item.why_it_matters),
                None,
            )
            if signal:
                detail = signal.technical_substance or signal.summary
                conclusions.append(
                    f"Radar 聚焦「{signal.title}」：{detail}。这对当前方向的意义是 {signal.why_it_matters}。"
                )
            elif radar.digest.summary:
                conclusions.append(f"Radar 本周的核心判断是：{radar.digest.summary}")

        deep_dive = next((item.payload for item in sessions if isinstance(item.payload, ResearchFeederPayload)), None)
        if deep_dive:
            primary = next(
                (paper for paper in deep_dive.papers if paper.id == deep_dive.reading_pack.primary_paper_id),
                deep_dive.papers[0] if deep_dive.papers else None,
            )
            learning = deep_dive.notes.core_idea or deep_dive.notes.evidence or deep_dive.reading_pack.reading_goal
            implication = deep_dive.notes.relation_to_my_plan or deep_dive.notes.next_action
            if learning:
                title = primary.title if primary else "本周 Deep Dive"
                suffix = f" 对原计划的含义是：{implication}" if implication else ""
                conclusions.append(f"Deep Dive 围绕「{title}」沉淀：{learning.rstrip('。')}。{suffix}")

        if conclusions:
            return "\n\n".join(conclusions[:2])

        completed = [item.summary for item in checkins if item.status == CheckinStatus.completed and item.summary]
        if completed:
            return f"本周围绕「{weekly_focus}」推进：{'；'.join(completed[:2])}。下一周应继续把这些记录沉淀为可复用的技术判断。"
        return f"本周尚无足够的 Radar、Deep Dive 或归档记录可供总结；下周继续围绕「{weekly_focus}」完成一个可验证的最小学习闭环。"

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
                "selected_materials": [
                    material.model_dump(mode="json") for material in session.payload.selected_materials
                ],
                "paper_reader": self._reader_payload(session.payload, primary_paper.id if primary_paper else ""),
                "notes": session.payload.notes.model_dump(mode="json"),
                "agent_discussions": self._discussion_payload(session.id),
            }
        return payload

    def _reader_payload(self, payload: ResearchFeederPayload, paper_id: str) -> dict:
        reader = next((item for item in payload.paper_readers if item.paper_id == paper_id), None)
        if reader is None and payload.paper_reader and payload.paper_reader.paper_id == paper_id:
            reader = payload.paper_reader
        if reader is None:
            return {}

        return {
            "paper_id": reader.paper_id,
            "pdf_url": str(reader.pdf_url) if reader.pdf_url else "",
            "sections": [
                {
                    "id": section.id,
                    "section_name": section.section_name,
                    "page_start": section.page_start,
                    "page_end": section.page_end,
                    "read_mode": section.read_mode.value,
                    "extracted_text": section.extracted_text,
                    "why_read": section.why_read,
                    "agent_instruction": section.agent_instruction,
                    "knowledge_points": section.knowledge_points,
                    "status": section.status.value,
                }
                for section in reader.sections[:5]
            ],
            "selected_passages": [
                {
                    "id": passage.id,
                    "page": passage.page,
                    "section_name": passage.section_name,
                    "text_excerpt": passage.text_excerpt,
                    "why_selected": passage.why_selected,
                    "reading_question": passage.reading_question,
                    "status": passage.status.value,
                }
                for passage in reader.selected_passages[:5]
            ],
            "key_figures": [
                {
                    "id": figure.id,
                    "page": figure.page,
                    "figure_label": figure.figure_label,
                    "caption": figure.visual.caption,
                    "why_important": figure.why_important,
                    "reading_question": figure.reading_question,
                }
                for figure in reader.key_figures[:5]
            ],
        }

    def _discussion_payload(self, session_id: str) -> list[dict[str, object]]:
        threads = self.chats.get_by_session(session_id)
        discussion_payload = []
        for thread in threads[:3]:
            messages = [
                {
                    "role": message.role.value,
                    "content": message.content,
                    "created_at": message.created_at.isoformat(),
                }
                for message in thread.messages[-6:]
                if message.role in {ChatRole.user, ChatRole.assistant}
            ]
            if messages:
                discussion_payload.append(
                    {
                        "thread_id": thread.id,
                        "context_refs": thread.context_refs,
                        "messages": messages,
                    }
                )
        return discussion_payload

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
