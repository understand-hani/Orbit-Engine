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
        session = self.sessions.get_by_id(request.session_id)
        checkin = Checkin(
            id=f"checkin_{uuid4().hex[:12]}",
            created_at=datetime.now(timezone.utc),
            session_title=session.title if session is not None else "",
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

        mock = self._mock_draft(session, request)
        return mock.model_copy(update={"provider": "mock"})

    def draft_weekly_studio(self, session_id: str) -> Optional[WeeklyStudioDraftResponse]:
        session = self.sessions.get_by_id(session_id)
        context = self.user_contexts.get()
        if session is None or context is None:
            return None

        checkins = self._week_checkins(session.date)
        weekly_sessions = self._week_sessions(session)
        completed_checkins = [item for item in checkins if item.status == CheckinStatus.completed]
        payload = {
            "plan": {
                "weekly_focus": self._truncate(context.plan.weekly_focus, 300),
                "active_tasks": [
                    self._truncate(item, 220)
                    for item in context.plan.active_tasks[:5]
                    if item.strip()
                ],
                "next_action": self._truncate(context.plan.next_action, 220),
            },
            "completed_checkins": [
                {
                    "session_id": item.session_id,
                    "task_type": item.task_type.value,
                    "summary": self._truncate(item.summary, 260),
                    "key_insight": self._truncate(item.key_insight, 320),
                    "next_action": self._truncate(item.next_action, 220),
                }
                for item in completed_checkins[:8]
            ],
            "weekly_evidence": self._weekly_evidence(weekly_sessions, completed_checkins),
        }
        if self.settings.llm_provider == "openrouter":
            try:
                output = self.llm.generate_json(
                    system_prompt=WEEKLY_STUDIO_DRAFT_SYSTEM_PROMPT,
                    user_payload=payload,
                    output_model=LLMWeeklyStudioDraftOutput,
                    schema_name="weekly_studio_draft",
                    timeout_sec=12,
                    max_tokens=480,
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
                completed_checkins,
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

    def _weekly_evidence(self, sessions: List[BaseSession], checkins: List[Checkin]) -> List[dict]:
        completed_by_session = {item.session_id: item for item in checkins}
        evidence = []
        for item in sessions:
            if len(evidence) >= 6:
                break
            checkin = completed_by_session.get(item.id)
            if checkin is None:
                continue
            completion = {
                "summary": self._truncate(checkin.summary, 220),
                "key_insight": self._truncate(checkin.key_insight, 280),
                "user_notes": self._truncate(checkin.user_notes or "", 220),
                "source_summary": self._truncate(checkin.source_summary or "", 260),
            }
            if isinstance(item.payload, TechRadarPayload):
                evidence.append(
                    {
                        "type": "radar",
                        "completion": completion,
                        "signals": [
                            {
                                "title": self._truncate(signal.title, 160),
                                "technical_substance": self._truncate(signal.technical_substance, 300),
                                "why_it_matters": self._truncate(signal.why_it_matters, 240),
                                "evidence_status": signal.evidence_status,
                                "recommended_depth": signal.recommended_depth.value,
                                "user_mark": signal.user_mark.value,
                            }
                            for signal in item.payload.digest.items[:2]
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
                        "completion": completion,
                        "material_evidence": {
                            "summary": self._truncate(primary.summary if primary else "", 500),
                            "selected_passages": self._weekly_passage_evidence(
                                item.payload, primary.id if primary else ""
                            ),
                        },
                        "notes": {
                            "core_idea": self._truncate(item.payload.notes.core_idea, 260),
                            "evidence": self._truncate(item.payload.notes.evidence, 280),
                            "limitations": self._truncate(item.payload.notes.limitations, 220),
                            "relation_to_my_plan": self._truncate(
                                item.payload.notes.relation_to_my_plan, 220
                            ),
                            "next_action": self._truncate(item.payload.notes.next_action, 180),
                        },
                    }
                )
        return evidence

    def _weekly_passage_evidence(self, payload: ResearchFeederPayload, paper_id: str) -> List[dict]:
        reader = next((item for item in payload.paper_readers if item.paper_id == paper_id), None)
        if reader is None and payload.paper_reader and payload.paper_reader.paper_id == paper_id:
            reader = payload.paper_reader
        if reader is None:
            return []
        return [
            {
                "section_name": self._truncate(passage.section_name, 100),
                "text_excerpt": self._truncate(passage.text_excerpt, 320),
                "why_selected": self._truncate(passage.why_selected, 180),
            }
            for passage in reader.selected_passages[:2]
        ]

    def _structured_weekly_summary(
        self,
        sessions: List[BaseSession],
        checkins: List[Checkin],
        weekly_focus: str,
    ) -> str:
        completed_by_session = {item.session_id: item for item in checkins}
        conclusions = []
        for session in sessions:
            if session.id not in completed_by_session:
                continue
            if isinstance(session.payload, ResearchFeederPayload):
                conclusion = self._deep_dive_weekly_conclusion(session.payload)
            elif isinstance(session.payload, TechRadarPayload):
                conclusion = self._radar_weekly_conclusion(session.payload)
            else:
                conclusion = ""
            if conclusion:
                conclusions.append(conclusion)

        if conclusions:
            return "\n\n".join(conclusions[:3])

        insights = []
        for item in checkins:
            insight = next(
                (
                    value.strip()
                    for value in (item.key_insight, item.user_notes, item.summary)
                    if self._contains_chinese(value)
                ),
                "",
            )
            if insight:
                insights.append(insight)

        if insights:
            return f"本周完成的学习沉淀：{'；'.join(insights[:2])}。下一周继续围绕「{weekly_focus}」把这些判断落到一个可验证的小任务。"
        if checkins:
            return "本周已有完成归档，但没有记录可供提炼的中文关键洞察；为避免复制英文原文，本次不展示材料摘要。请在归档时补充一句“关键洞察”，再生成周总结。"
        return f"本周尚无完成归档可供总结；下周继续围绕「{weekly_focus}」完成一个可验证的最小学习闭环。"

    def _deep_dive_weekly_conclusion(self, payload: ResearchFeederPayload) -> str:
        core_idea = self._first_chinese(payload.notes.core_idea, payload.notes.evidence)
        input_output = self._first_chinese(payload.notes.input_output)
        relation = self._first_chinese(payload.notes.relation_to_my_plan)
        if not core_idea:
            primary = next(
                (paper for paper in payload.papers if paper.id == payload.reading_pack.primary_paper_id),
                payload.papers[0] if payload.papers else None,
            )
            reader = self._reader_payload(payload, primary.id if primary else "")
            core_idea = self._first_chinese(
                *(item.get("text_excerpt", "") for item in reader.get("selected_passages", [])),
                primary.summary if primary else "",
            )
        if not core_idea:
            return ""

        sentences = [f"Deep Dive：{core_idea.rstrip('。')}。"]
        if input_output:
            sentences.append(f"已厘清{input_output.rstrip('。')}。")
        if relation:
            sentences.append(f"对当前计划的意义是：{relation.rstrip('。')}。")
        return "".join(sentences)

    def _radar_weekly_conclusion(self, payload: TechRadarPayload) -> str:
        signal = next(
            (
                item
                for item in payload.digest.items
                if self._contains_chinese(item.technical_substance)
                or self._contains_chinese(item.summary)
            ),
            None,
        )
        if signal is None:
            return ""
        substance = self._first_chinese(signal.technical_substance, signal.summary)
        implication = self._first_chinese(signal.why_it_matters)
        if not substance:
            return ""
        sentence = f"Radar：{substance.rstrip('。')}。"
        if implication:
            sentence += f"这提示：{implication.rstrip('。')}。"
        return sentence

    def _first_chinese(self, *values: str) -> str:
        return next((value.strip() for value in values if self._contains_chinese(value)), "")

    def _contains_chinese(self, value: str) -> bool:
        return any("\u4e00" <= char <= "\u9fff" for char in value)

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
                "reading_goal": session.payload.reading_pack.reading_goal,
                "selection_reason": session.payload.reading_pack.selection_reason,
                "primary_paper": self._paper_brief(primary_paper),
                "selected_materials": [
                    material.model_dump(mode="json") for material in session.payload.selected_materials
                ],
                "paper_reader": self._reader_brief(session.payload, primary_paper.id if primary_paper else ""),
                "notes": {
                    "core_idea": session.payload.notes.core_idea,
                    "evidence": session.payload.notes.evidence,
                    "next_action": session.payload.notes.next_action,
                },
            }
        return payload

    def _paper_brief(self, paper) -> Optional[dict]:
        if paper is None:
            return None
        return {
            "title": paper.title,
            "authors": paper.authors[:6],
            "venue": paper.venue,
            "published_at": paper.published_at.isoformat() if paper.published_at else None,
            "url": str(paper.url) if paper.url else "",
            "abstract": self._truncate(paper.summary, 900),
            "why_selected": self._truncate(paper.why_selected, 360),
            "tags": paper.tags[:6],
        }

    def _reader_brief(self, payload: ResearchFeederPayload, paper_id: str) -> dict:
        reader = next((item for item in payload.paper_readers if item.paper_id == paper_id), None)
        if reader is None and payload.paper_reader and payload.paper_reader.paper_id == paper_id:
            reader = payload.paper_reader
        if reader is None:
            return {}

        return {
            "abstract": self._truncate(
                next(
                    (
                        section.extracted_text
                        for section in reader.sections
                        if "abstract" in section.section_name.lower() and section.extracted_text
                    ),
                    "",
                ),
                900,
            ),
            "sections": [
                {
                    "section_name": section.section_name,
                    "why_read": self._truncate(section.why_read, 180),
                }
                for section in reader.sections[:2]
            ],
            "selected_passages": [
                {
                    "section_name": passage.section_name,
                    "why_selected": self._truncate(passage.why_selected, 220),
                }
                for passage in reader.selected_passages[:2]
            ],
            "key_figures": [
                {
                    "figure_label": figure.figure_label,
                    "why_important": self._truncate(figure.why_important, 220),
                }
                for figure in reader.key_figures[:2]
            ],
        }

    def _truncate(self, value: str, limit: int) -> str:
        normalized = " ".join((value or "").split())
        return normalized if len(normalized) <= limit else normalized[:limit].rstrip() + "…"

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
