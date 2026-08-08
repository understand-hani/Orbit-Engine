from datetime import date, datetime, timezone
from typing import Optional
from uuid import uuid4

from app.agents.jd_career_agent import MockJDCareerAgent
from app.agents.research_feeder_agent import MockResearchFeederAgent
from app.agents.tech_radar_agent import MockTechRadarAgent
from app.agents.weekly_coordinator import WeeklyCoordinator
from app.db.repositories import CheckinRepository, SessionRepository
from app.schemas.checkin import Checkin, CheckinStatus
from app.schemas.common import SessionStatus, SuggestedAction, TaskType
from app.schemas.jd_analysis import JDInput, JDInputCreate
from app.schemas.research_feeder import ConfirmedResearchMaterial, ResearchFeederPayload
from app.schemas.session import BaseSession


class FeedService:
    def __init__(self) -> None:
        self.coordinator = WeeklyCoordinator()
        self.tech_radar_agent = MockTechRadarAgent()
        self.jd_agent = MockJDCareerAgent()
        self.research_agent = MockResearchFeederAgent()
        self.sessions = SessionRepository()
        self.checkins = CheckinRepository()

    def preview_session(self, target_date: Optional[date] = None) -> BaseSession:
        return self.coordinator.create_session(target_date)

    def generate_mock_session(self, target_date: Optional[date] = None) -> BaseSession:
        session = self.coordinator.create_session(target_date)
        payload = session.payload
        action = session.suggested_action

        if session.task_type == TaskType.tech_radar:
            payload = self.tech_radar_agent.generate(session.payload)
            action = SuggestedAction.open_weekly_radar
        elif session.task_type == TaskType.jd_analysis:
            payload = self.jd_agent.generate(session.payload)
            action = SuggestedAction.open_analysis_report
        elif session.task_type == TaskType.research_feeder:
            payload = self.research_agent.generate(session.payload)
            action = SuggestedAction.open_paper_reader

        return session.model_copy(update={"payload": payload, "suggested_action": action})

    def generate_and_save_mock_session(self, target_date: Optional[date] = None) -> BaseSession:
        session = self.generate_mock_session(target_date)
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
        return self.sessions.save(session)

    def get_session(self, session_id: str) -> Optional[BaseSession]:
        return self.sessions.get_by_id(session_id)

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

        archived_at = datetime.now(timezone.utc)
        updated_session = session.model_copy(
            update={
                "status": SessionStatus.skipped,
                "updated_at": archived_at,
            }
        )
        self.sessions.save(updated_session)

        self._save_session_marker(
            session=session,
            status=CheckinStatus.skipped,
            summary=f"已丢弃：{session.title}",
            next_action="该工作区已从当前队列移除。",
            created_at=archived_at,
        )
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
        updated_session = session.model_copy(
            update={
                "status": SessionStatus.archived,
                "updated_at": archived_at,
            }
        )
        self.sessions.save(updated_session)
        self._save_session_marker(
            session=session,
            status=CheckinStatus.archived,
            summary=f"已暂存：{session.title}",
            next_action="以后可以从归档区找回并继续。",
            created_at=archived_at,
        )
        return True

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

        session = self.generate_mock_session(target_date)
        session = session.model_copy(update={"id": session_id})
        return self.sessions.save(session)

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
            return existing
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
