from __future__ import annotations

import re
from datetime import date, datetime, timezone
from typing import Optional
from uuid import uuid4

from app.agents.jd_career_agent import MockJDCareerAgent
from app.agents.research_feeder_agent import MockResearchFeederAgent
from app.agents.tech_radar_agent import MockTechRadarAgent
from app.agents.weekly_coordinator import WeeklyCoordinator
from app.db.repositories import CheckinRepository, SessionRepository
from app.db.repositories import UserContextRepository
from app.schemas.checkin import Checkin, CheckinStatus
from app.schemas.common import SessionStatus, SuggestedAction, TaskType
from app.schemas.jd_analysis import JDInput, JDInputCreate
from app.schemas.research_feeder import ConfirmedResearchMaterial, ResearchFeederPayload
from app.schemas.session import BaseSession
from app.schemas.tech_radar import TechRadarPayload


class FeedService:
    def __init__(self) -> None:
        self.coordinator = WeeklyCoordinator()
        self.tech_radar_agent = MockTechRadarAgent()
        self.jd_agent = MockJDCareerAgent()
        self.research_agent = MockResearchFeederAgent()
        self.sessions = SessionRepository()
        self.checkins = CheckinRepository()
        self.user_contexts = UserContextRepository()

    def preview_session(
        self,
        target_date: Optional[date] = None,
        task_type: Optional[TaskType] = None,
    ) -> BaseSession:
        return self.coordinator.create_session(target_date, task_type_override=task_type)

    def generate_mock_session(
        self,
        target_date: Optional[date] = None,
        task_type: Optional[TaskType] = None,
        excluded_radar_keys: Optional[set] = None,
    ) -> BaseSession:
        session = self.coordinator.create_session(target_date, task_type_override=task_type)
        payload = session.payload
        action = session.suggested_action

        if session.task_type == TaskType.tech_radar:
            payload = self.tech_radar_agent.generate(
                session.payload,
                excluded_source_keys=excluded_radar_keys,
            )
            action = SuggestedAction.open_weekly_radar
        elif session.task_type == TaskType.jd_analysis:
            payload = self.jd_agent.generate(session.payload)
            action = SuggestedAction.open_analysis_report
        elif session.task_type == TaskType.research_feeder:
            payload = self.research_agent.generate(session.payload)
            action = SuggestedAction.open_paper_reader

        session = session.model_copy(update={"payload": payload, "suggested_action": action})
        return self._apply_default_title(session, exclude_self=False)

    def generate_and_save_mock_session(
        self,
        target_date: Optional[date] = None,
        task_type: Optional[TaskType] = None,
    ) -> BaseSession:
        seed_session = self.coordinator.create_session(target_date, task_type_override=task_type)
        if seed_session.task_type == TaskType.tech_radar:
            session = seed_session
        else:
            excluded_radar_keys = self._radar_source_keys()
            session = self.generate_mock_session(
                target_date,
                task_type=task_type,
                excluded_radar_keys=excluded_radar_keys,
            )
        if self.sessions.get_by_id(session.id) is not None:
            suffix = uuid4().hex[:8]
            session = session.model_copy(
                update={
                    "id": f"{session.id}_{suffix}",
                    "ai_chat_thread_id": f"{session.ai_chat_thread_id}_{suffix}",
                    "created_at": datetime.now(timezone.utc),
                    "updated_at": datetime.now(timezone.utc),
                }
            )
        self._normalize_existing_research_titles(session)
        session = self._apply_default_title(session)
        return self.sessions.save(session)

    def get_session(self, session_id: str) -> Optional[BaseSession]:
        return self.sessions.get_by_id(session_id)

    def refresh_tech_radar_session(self, session_id: str) -> Optional[BaseSession]:
        session = self.sessions.get_by_id(session_id)
        if session is None or session.task_type != TaskType.tech_radar:
            return None

        excluded_radar_keys = self._radar_source_keys(exclude_session_id=session_id)
        user_context = self.user_contexts.get()
        enriched_payload = self._enrich_radar_payload_with_user_context(session.payload, user_context)
        payload = self.tech_radar_agent.generate(
            enriched_payload,
            excluded_source_keys=excluded_radar_keys,
            user_context=user_context,
        )
        if not payload.digest.items and self._has_real_radar_items(session):
            payload = session.payload

        updated_session = session.model_copy(
            update={
                "payload": payload,
                "suggested_action": SuggestedAction.open_weekly_radar,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.sessions.save(updated_session)

    def get_sessions_by_date(self, target_date: date) -> list:
        return self.sessions.get_by_date(target_date.isoformat())

    def delete_session(self, session_id: str) -> bool:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return False
        if session.status in {
            SessionStatus.completed,
            SessionStatus.skipped,
            SessionStatus.archived,
        }:
            return True

        discarded_at = datetime.now(timezone.utc)
        updated_session = session.model_copy(
            update={
                "status": SessionStatus.skipped,
                "updated_at": discarded_at,
            }
        )
        self.sessions.save(updated_session)
        return True

    def archive_session(self, session_id: str) -> bool:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return False
        if session.status in {
            SessionStatus.completed,
            SessionStatus.skipped,
            SessionStatus.archived,
        }:
            return True

        archived_at = datetime.now(timezone.utc)
        self._normalize_existing_research_titles(session)
        session = self._ensure_default_title(session)
        updated_session = session.model_copy(
            update={
                "status": SessionStatus.archived,
                "updated_at": archived_at,
            }
        )
        self.sessions.save(updated_session)
        self._save_session_marker(
            session=updated_session,
            status=CheckinStatus.archived,
            summary=f"已暂存：{updated_session.title}",
            next_action="以后可以从归档区找回并继续。",
            created_at=archived_at,
        )
        return True

    def restore_session(self, session_id: str) -> Optional[BaseSession]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None

        session = self._ensure_default_title(session)
        restored_session = session.model_copy(
            update={
                "status": SessionStatus.active,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.sessions.save(restored_session)

    def save_selected_materials(
        self, session_id: str, materials: list[ConfirmedResearchMaterial]
    ) -> Optional[BaseSession]:
        session = self.sessions.get_by_id(session_id) or self._recover_missing_research_session(session_id)
        if session is None or not isinstance(session.payload, ResearchFeederPayload):
            return None

        updated_payload = session.payload.model_copy(update={"selected_materials": materials})
        updated_session = session.model_copy(
            update={
                "payload": updated_payload,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.sessions.save(updated_session)

    def rename_session(self, session_id: str, suffix: str) -> Optional[BaseSession]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None

        cleaned_suffix = suffix.strip()
        if not cleaned_suffix:
            raise ValueError("名称后缀不能为空")
        if cleaned_suffix.startswith(self._title_prefix(session)):
            raise ValueError("只能填写日期后面的序号部分")

        new_title = f"{self._title_prefix(session)}{cleaned_suffix}"
        same_day_sessions = self.sessions.get_by_date_and_task(
            session.date.isoformat(),
            session.task_type.value,
        )
        if any(item.id != session.id and item.title == new_title for item in same_day_sessions):
            raise ValueError("名称已存在")

        updated_session = session.model_copy(
            update={
                "title": new_title,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.sessions.save(updated_session)

    def _recover_missing_research_session(self, session_id: str) -> Optional[BaseSession]:
        prefix = "session_"
        suffix = "_research_feeder"
        if not session_id.startswith(prefix) or suffix not in session_id:
            return None

        date_value = session_id.removeprefix(prefix).split(suffix, maxsplit=1)[0]
        try:
            target_date = date.fromisoformat(date_value)
        except ValueError:
            return None

        session = self.generate_mock_session(target_date, task_type=TaskType.research_feeder)
        session = session.model_copy(update={"id": session_id})
        session = self._apply_default_title(session, exclude_self=False)
        return self.sessions.save(session)

    def _radar_source_keys(self, exclude_session_id: Optional[str] = None) -> set:
        keys = set()
        for session in self.sessions.list_by_task(TaskType.tech_radar.value):
            if session.id == exclude_session_id or not isinstance(session.payload, TechRadarPayload):
                continue
            for item in session.payload.digest.items:
                if item.url:
                    keys.add(str(item.url))
                elif item.source and item.id:
                    keys.add(f"{item.source}:{item.id}")
        return keys

    def _has_real_radar_items(self, session: BaseSession) -> bool:
        if not isinstance(session.payload, TechRadarPayload):
            return False
        return any(item.id.startswith("radar_real_") for item in session.payload.digest.items)

    def _enrich_radar_payload_with_user_context(
        self,
        payload: TechRadarPayload,
        user_context,
    ) -> TechRadarPayload:
        if user_context is None:
            return payload
        topics = self._dedupe_strings(
            [
                user_context.profile.goal,
                user_context.profile.current_stage,
                user_context.plan.long_term_goal,
                user_context.plan.weekly_focus,
                *user_context.plan.active_tasks,
                *user_context.plan.tracking_keywords,
                *user_context.preferences.fields,
                *payload.scope.companies,
                *payload.scope.research_groups,
            ]
        )
        updated_scope = payload.scope.model_copy(update={"topics": topics})
        return payload.model_copy(update={"scope": updated_scope})

    def _dedupe_strings(self, values: list[str]) -> list[str]:
        deduped: list[str] = []
        seen = set()
        for value in values:
            cleaned = value.strip()
            if not cleaned:
                continue
            key = cleaned.lower()
            if key in seen:
                continue
            seen.add(key)
            deduped.append(cleaned)
        return deduped

    def _apply_default_title(self, session: BaseSession, exclude_self: bool = True) -> BaseSession:
        if session.task_type != TaskType.research_feeder:
            return session

        existing = self.sessions.get_by_date_and_task(
            session.date.isoformat(),
            session.task_type.value,
        )
        used_titles = {
            item.title
            for item in existing
            if item.status != SessionStatus.skipped and (not exclude_self or item.id != session.id)
        }
        if self._title_sequence(session) is not None and session.title not in used_titles:
            return session

        sequence = self._next_title_sequence(session, existing, exclude_self)
        title = f"{self._title_prefix(session)}{sequence}"
        while title in used_titles:
            sequence += 1
            title = f"{self._title_prefix(session)}{sequence}"
        return session.model_copy(update={"title": title})

    def _ensure_default_title(self, session: BaseSession) -> BaseSession:
        if session.task_type != TaskType.research_feeder:
            return session
        if self._title_sequence(session) is not None:
            return session
        return self._apply_default_title(session)

    def _normalize_existing_research_titles(self, session: BaseSession) -> None:
        if session.task_type != TaskType.research_feeder:
            return

        existing = self.sessions.get_by_date_and_task(
            session.date.isoformat(),
            session.task_type.value,
        )
        used_sequences = {
            sequence
            for item in existing
            if item.status != SessionStatus.skipped
            if (sequence := self._title_sequence(item)) is not None
        }
        next_sequence = (max(used_sequences) + 1) if used_sequences else 1

        for item in existing:
            if item.status == SessionStatus.skipped or self._title_sequence(item) is not None:
                continue
            while next_sequence in used_sequences:
                next_sequence += 1
            normalized = item.model_copy(
                update={
                    "title": f"{self._title_prefix(session)}{next_sequence}",
                    "updated_at": datetime.now(timezone.utc),
                }
            )
            self.sessions.save(normalized)
            used_sequences.add(next_sequence)
            next_sequence += 1

    def _title_prefix(self, session: BaseSession) -> str:
        if session.task_type == TaskType.research_feeder:
            return f"Deep Dive-{session.date.strftime('%Y/%m/%d')}-"
        return f"{session.title}-{session.date.isoformat()}-"

    def _title_sequence(self, session: BaseSession) -> Optional[int]:
        if session.task_type != TaskType.research_feeder:
            return None

        date_slash = session.date.strftime("%Y/%m/%d")
        date_dash = session.date.isoformat()
        pattern = re.compile(rf"^Deep Dive-(?:{re.escape(date_slash)}|{re.escape(date_dash)})-(\d+)$")
        match = pattern.match(session.title)
        return int(match.group(1)) if match else None

    def _next_title_sequence(
        self,
        session: BaseSession,
        existing: list[BaseSession],
        exclude_self: bool,
    ) -> int:
        if session.task_type != TaskType.research_feeder:
            return 1

        used_sequences = set()
        for item in existing:
            if item.status == SessionStatus.skipped:
                continue
            if exclude_self and item.id == session.id:
                continue
            sequence = self._title_sequence(item)
            if sequence is not None:
                used_sequences.add(sequence)

        return (max(used_sequences) + 1) if used_sequences else 1

    def _save_session_marker(
        self,
        session: BaseSession,
        status: CheckinStatus,
        summary: str,
        next_action: str,
        created_at: datetime,
    ) -> None:
        self.checkins.save(
            Checkin(
                id=f"checkin_{uuid4().hex[:12]}",
                session_id=session.id,
                date=session.date,
                task_type=session.task_type,
                duration_min=0,
                status=status,
                summary=summary,
                key_insight="",
                next_action=next_action,
                created_at=created_at,
            )
        )

    def get_or_create_mock_session(self, target_date: Optional[date] = None) -> BaseSession:
        day = target_date or date.today()
        existing = self.sessions.get_latest_active_by_date(day.isoformat())
        if existing is not None:
            titled_existing = self._apply_default_title(existing)
            if titled_existing.title != existing.title:
                return self.sessions.save(titled_existing)
            return titled_existing
        latest = self.sessions.get_latest_by_date(day.isoformat())
        if latest is not None and latest.status == SessionStatus.skipped:
            return latest
        return self.generate_and_save_mock_session(day)

    def analyze_jd(self, session_id: str, jd_input: JDInputCreate) -> Optional[BaseSession]:
        session = self.sessions.get_by_id(session_id)
        if session is None or session.task_type != TaskType.jd_analysis:
            return None

        payload = session.payload.model_copy(
            update={
                "jd_input": JDInput(
                    id=f"jd_input_{uuid4().hex[:12]}",
                    source_type=jd_input.source_type,
                    company=jd_input.company,
                    role_title=jd_input.role_title,
                    location=jd_input.location,
                    url=jd_input.url,
                    jd_text=jd_input.jd_text,
                    recruiter_context=jd_input.recruiter_context,
                    user_question=jd_input.user_question,
                    created_at=datetime.now(timezone.utc),
                )
            }
        )
        analyzed_payload = self.jd_agent.generate(payload)
        updated_session = session.model_copy(
            update={
                "payload": analyzed_payload,
                "suggested_action": SuggestedAction.open_analysis_report,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        return self.sessions.save(updated_session)
