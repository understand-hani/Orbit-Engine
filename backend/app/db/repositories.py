import json
from typing import List, Optional

from app.schemas.chat import AIChatThread
from app.db.sqlite import connect
from app.schemas.checkin import Checkin
from app.schemas.jd_intelligence import (
    CandidateAction,
    CandidateActionStatus,
    JDEntry,
    JDFitAnalysis,
    JDPreferenceMark,
    SkillStackSnapshot,
    TaskStateSnapshot,
)
from app.schemas.profile import ResearchArchive, ResumeProfile
from app.schemas.session import BaseSession
from app.schemas.user_context import UserContext


class SessionRepository:
    def save(self, session: BaseSession) -> BaseSession:
        payload = session.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO sessions (
                    id,
                    date,
                    weekday,
                    task_type,
                    session_mode,
                    status,
                    suggested_action,
                    payload_type,
                    payload_json,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    session.id,
                    session.date.isoformat(),
                    session.weekday,
                    session.task_type.value,
                    session.session_mode.value,
                    session.status.value,
                    session.suggested_action.value,
                    session.payload_type.value,
                    json.dumps(payload, ensure_ascii=False),
                    session.created_at.isoformat(),
                    session.updated_at.isoformat(),
                ),
            )
        return session

    def get_by_id(self, session_id: str) -> Optional[BaseSession]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM sessions WHERE id = ?",
                (session_id,),
            ).fetchone()
        if row is None:
            return None
        return BaseSession(**json.loads(row["payload_json"]))

    def get_by_date(self, date_value: str) -> List[BaseSession]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM sessions
                WHERE date = ?
                ORDER BY updated_at DESC
                """,
                (date_value,),
            ).fetchall()
        return [BaseSession(**json.loads(row["payload_json"])) for row in rows]

    def get_by_date_and_task(self, date_value: str, task_type: str) -> List[BaseSession]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM sessions
                WHERE date = ? AND task_type = ?
                ORDER BY created_at ASC
                """,
                (date_value, task_type),
            ).fetchall()
        return [BaseSession(**json.loads(row["payload_json"])) for row in rows]

    def get_latest_by_date(self, date_value: str) -> Optional[BaseSession]:
        sessions = self.get_by_date(date_value)
        return sessions[0] if sessions else None

    def get_latest_active_by_date(self, date_value: str) -> Optional[BaseSession]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM sessions
                WHERE date = ?
                ORDER BY updated_at DESC
                """,
                (date_value,),
            ).fetchall()

        for row in rows:
            session = BaseSession(**json.loads(row["payload_json"]))
            if session.status.value not in {"completed", "archived", "skipped"}:
                return session
        return None

    def delete(self, session_id: str) -> bool:
        with connect() as conn:
            cursor = conn.execute(
                "DELETE FROM sessions WHERE id = ?",
                (session_id,),
            )
        return cursor.rowcount > 0


class CheckinRepository:
    def save(self, checkin: Checkin) -> Checkin:
        payload = checkin.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO checkins (
                    id,
                    session_id,
                    date,
                    task_type,
                    status,
                    duration_min,
                    payload_json,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    checkin.id,
                    checkin.session_id,
                    checkin.date.isoformat(),
                    checkin.task_type.value,
                    checkin.status.value,
                    checkin.duration_min,
                    json.dumps(payload, ensure_ascii=False),
                    checkin.created_at.isoformat(),
                ),
            )
        return checkin

    def get_by_id(self, checkin_id: str) -> Optional[Checkin]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM checkins WHERE id = ?",
                (checkin_id,),
            ).fetchone()
        if row is None:
            return None
        return Checkin(**json.loads(row["payload_json"]))

    def delete(self, checkin_id: str) -> bool:
        with connect() as conn:
            cursor = conn.execute(
                "DELETE FROM checkins WHERE id = ?",
                (checkin_id,),
            )
        return cursor.rowcount > 0

    def list_by_date(self, date_value: Optional[str] = None) -> List[Checkin]:
        if date_value is None:
            with connect() as conn:
                rows = conn.execute(
                    """
                    SELECT payload_json FROM checkins
                    ORDER BY created_at DESC
                    """
                ).fetchall()
        else:
            with connect() as conn:
                rows = conn.execute(
                    """
                    SELECT payload_json FROM checkins
                    WHERE date = ?
                    ORDER BY created_at DESC
                    """,
                    (date_value,),
                ).fetchall()
        return [Checkin(**json.loads(row["payload_json"])) for row in rows]


class ChatRepository:
    def save_thread(self, thread: AIChatThread) -> AIChatThread:
        payload = thread.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO chat_threads (
                    id,
                    session_id,
                    task_type,
                    payload_json,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    thread.id,
                    thread.session_id,
                    thread.task_type.value,
                    json.dumps(payload, ensure_ascii=False),
                    thread.created_at.isoformat(),
                    thread.updated_at.isoformat(),
                ),
            )
        return thread

    def get_thread(self, thread_id: str) -> Optional[AIChatThread]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM chat_threads WHERE id = ?",
                (thread_id,),
            ).fetchone()
        if row is None:
            return None
        return AIChatThread(**json.loads(row["payload_json"]))

    def get_by_session(self, session_id: str) -> List[AIChatThread]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM chat_threads
                WHERE session_id = ?
                ORDER BY updated_at DESC
                """,
                (session_id,),
            ).fetchall()
        return [AIChatThread(**json.loads(row["payload_json"])) for row in rows]


class ResumeRepository:
    def save(self, profile: ResumeProfile) -> ResumeProfile:
        payload = profile.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO resume_profiles (
                    id,
                    version,
                    payload_json,
                    updated_at
                )
                VALUES (?, ?, ?, ?)
                """,
                (
                    profile.id,
                    profile.version,
                    json.dumps(payload, ensure_ascii=False),
                    profile.updated_at.isoformat(),
                ),
            )
        return profile

    def get(self, profile_id: str) -> Optional[ResumeProfile]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM resume_profiles WHERE id = ?",
                (profile_id,),
            ).fetchone()
        if row is None:
            return None
        return ResumeProfile(**json.loads(row["payload_json"]))

    def list(self) -> List[ResumeProfile]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM resume_profiles
                ORDER BY updated_at DESC
                """
            ).fetchall()
        return [ResumeProfile(**json.loads(row["payload_json"])) for row in rows]

    def latest(self) -> Optional[ResumeProfile]:
        profiles = self.list()
        return profiles[0] if profiles else None


class JDEntryRepository:
    def save(self, entry: JDEntry) -> JDEntry:
        payload = entry.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO jd_entries (
                    id,
                    company,
                    role_title,
                    city,
                    record_date,
                    application_priority,
                    status,
                    payload_json,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    entry.id,
                    entry.company,
                    entry.role_title,
                    entry.city,
                    entry.record_date.isoformat(),
                    entry.application_priority.value,
                    entry.status.value,
                    json.dumps(payload, ensure_ascii=False),
                    entry.created_at.isoformat(),
                    entry.updated_at.isoformat(),
                ),
            )
        return entry

    def get(self, entry_id: str) -> Optional[JDEntry]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM jd_entries WHERE id = ?",
                (entry_id,),
            ).fetchone()
        if row is None:
            return None
        return JDEntry(**json.loads(row["payload_json"]))

    def list(self) -> List[JDEntry]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM jd_entries
                ORDER BY record_date DESC, updated_at DESC
                """
            ).fetchall()
        return [JDEntry(**json.loads(row["payload_json"])) for row in rows]

    def delete(self, entry_id: str) -> bool:
        with connect() as conn:
            result = conn.execute("DELETE FROM jd_entries WHERE id = ?", (entry_id,))
        return result.rowcount > 0


class JDPreferenceRepository:
    def save(self, mark: JDPreferenceMark) -> JDPreferenceMark:
        payload = mark.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO jd_preference_marks (
                    id,
                    jd_entry_id,
                    interest_level,
                    payload_json,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    mark.id,
                    mark.jd_entry_id,
                    mark.interest_level.value,
                    json.dumps(payload, ensure_ascii=False),
                    mark.created_at.isoformat(),
                    mark.updated_at.isoformat(),
                ),
            )
        return mark

    def latest_for_entry(self, entry_id: str) -> Optional[JDPreferenceMark]:
        with connect() as conn:
            row = conn.execute(
                """
                SELECT payload_json FROM jd_preference_marks
                WHERE jd_entry_id = ?
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                (entry_id,),
            ).fetchone()
        if row is None:
            return None
        return JDPreferenceMark(**json.loads(row["payload_json"]))


class SkillStackRepository:
    def save(self, snapshot: SkillStackSnapshot) -> SkillStackSnapshot:
        payload = snapshot.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO skill_stack_snapshots (
                    id,
                    payload_json,
                    created_at
                )
                VALUES (?, ?, ?)
                """,
                (
                    snapshot.id,
                    json.dumps(payload, ensure_ascii=False),
                    snapshot.created_at.isoformat(),
                ),
            )
        return snapshot

    def latest(self) -> Optional[SkillStackSnapshot]:
        with connect() as conn:
            row = conn.execute(
                """
                SELECT payload_json FROM skill_stack_snapshots
                ORDER BY created_at DESC
                LIMIT 1
                """
            ).fetchone()
        if row is None:
            return None
        return SkillStackSnapshot(**json.loads(row["payload_json"]))


class TaskStateRepository:
    def save(self, snapshot: TaskStateSnapshot) -> TaskStateSnapshot:
        payload = snapshot.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO task_state_snapshots (
                    id,
                    payload_json,
                    created_at
                )
                VALUES (?, ?, ?)
                """,
                (
                    snapshot.id,
                    json.dumps(payload, ensure_ascii=False),
                    snapshot.created_at.isoformat(),
                ),
            )
        return snapshot

    def latest(self) -> Optional[TaskStateSnapshot]:
        with connect() as conn:
            row = conn.execute(
                """
                SELECT payload_json FROM task_state_snapshots
                ORDER BY created_at DESC
                LIMIT 1
                """
            ).fetchone()
        if row is None:
            return None
        return TaskStateSnapshot(**json.loads(row["payload_json"]))


class JDFitAnalysisRepository:
    def save(self, analysis: JDFitAnalysis) -> JDFitAnalysis:
        payload = analysis.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO jd_fit_analyses (
                    id,
                    jd_entry_id,
                    skill_snapshot_id,
                    task_snapshot_id,
                    payload_json,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    analysis.id,
                    analysis.jd_entry_id,
                    analysis.skill_snapshot_id,
                    analysis.task_snapshot_id,
                    json.dumps(payload, ensure_ascii=False),
                    analysis.created_at.isoformat(),
                ),
            )
        return analysis

    def list_by_entry(self, entry_id: str) -> List[JDFitAnalysis]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM jd_fit_analyses
                WHERE jd_entry_id = ?
                ORDER BY created_at DESC
                """,
                (entry_id,),
            ).fetchall()
        return [JDFitAnalysis(**json.loads(row["payload_json"])) for row in rows]

    def latest_by_entry(self, entry_id: str) -> Optional[JDFitAnalysis]:
        analyses = self.list_by_entry(entry_id)
        return analyses[0] if analyses else None


class CandidateActionRepository:
    def save(self, action: CandidateAction) -> CandidateAction:
        payload = action.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO candidate_actions (
                    id,
                    status,
                    priority,
                    payload_json,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    action.id,
                    action.status.value,
                    action.priority.value,
                    json.dumps(payload, ensure_ascii=False),
                    action.created_at.isoformat(),
                    action.updated_at.isoformat(),
                ),
            )
        return action

    def get(self, action_id: str) -> Optional[CandidateAction]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM candidate_actions WHERE id = ?",
                (action_id,),
            ).fetchone()
        if row is None:
            return None
        return CandidateAction(**json.loads(row["payload_json"]))

    def list(self, status: Optional[CandidateActionStatus] = None) -> List[CandidateAction]:
        if status is None:
            with connect() as conn:
                rows = conn.execute(
                    """
                    SELECT payload_json FROM candidate_actions
                    ORDER BY updated_at DESC
                    """
                ).fetchall()
        else:
            with connect() as conn:
                rows = conn.execute(
                    """
                    SELECT payload_json FROM candidate_actions
                    WHERE status = ?
                    ORDER BY updated_at DESC
                    """,
                    (status.value,),
                ).fetchall()
        return [CandidateAction(**json.loads(row["payload_json"])) for row in rows]

    def list_by_analysis(self, analysis_id: str) -> List[CandidateAction]:
        actions = self.list()
        return [action for action in actions if analysis_id in action.source_analysis_ids]


class ResearchArchiveRepository:
    def save(self, archive: ResearchArchive) -> ResearchArchive:
        payload = archive.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO research_archives (
                    id,
                    paper_id,
                    note_id,
                    payload_json,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    archive.id,
                    archive.paper_id,
                    archive.note_id,
                    json.dumps(payload, ensure_ascii=False),
                    archive.created_at.isoformat(),
                ),
            )
        return archive

    def get(self, archive_id: str) -> Optional[ResearchArchive]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM research_archives WHERE id = ?",
                (archive_id,),
            ).fetchone()
        if row is None:
            return None
        return ResearchArchive(**json.loads(row["payload_json"]))

    def list(self) -> List[ResearchArchive]:
        with connect() as conn:
            rows = conn.execute(
                """
                SELECT payload_json FROM research_archives
                ORDER BY created_at DESC
                """
            ).fetchall()
        return [ResearchArchive(**json.loads(row["payload_json"])) for row in rows]


class UserContextRepository:
    context_id = "default"

    def save(self, context: UserContext) -> UserContext:
        payload = context.model_dump(mode="json")
        with connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO user_contexts (
                    id,
                    payload_json,
                    updated_at
                )
                VALUES (?, ?, ?)
                """,
                (
                    self.context_id,
                    json.dumps(payload, ensure_ascii=False),
                    context.profile.updated_at.isoformat(),
                ),
            )
        return context

    def get(self) -> Optional[UserContext]:
        with connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM user_contexts WHERE id = ?",
                (self.context_id,),
            ).fetchone()
        if row is None:
            return None
        return UserContext(**json.loads(row["payload_json"]))
