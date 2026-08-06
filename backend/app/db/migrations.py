from app.db.sqlite import connect


def init_db() -> None:
    with connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                weekday TEXT NOT NULL,
                task_type TEXT NOT NULL,
                session_mode TEXT NOT NULL,
                status TEXT NOT NULL,
                suggested_action TEXT NOT NULL,
                payload_type TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_sessions_date_task
            ON sessions(date, task_type)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS checkins (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                date TEXT NOT NULL,
                task_type TEXT NOT NULL,
                status TEXT NOT NULL,
                duration_min INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_checkins_date_task
            ON checkins(date, task_type)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_threads (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                task_type TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_chat_threads_session
            ON chat_threads(session_id)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS resume_profiles (
                id TEXT PRIMARY KEY,
                version TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS research_archives (
                id TEXT PRIMARY KEY,
                paper_id TEXT NOT NULL,
                note_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_research_archives_paper
            ON research_archives(paper_id)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS jd_entries (
                id TEXT PRIMARY KEY,
                company TEXT NOT NULL,
                role_title TEXT NOT NULL,
                city TEXT NOT NULL,
                record_date TEXT NOT NULL,
                application_priority TEXT NOT NULL,
                status TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_jd_entries_record_date
            ON jd_entries(record_date)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS jd_preference_marks (
                id TEXT PRIMARY KEY,
                jd_entry_id TEXT NOT NULL,
                interest_level TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_jd_preference_marks_entry
            ON jd_preference_marks(jd_entry_id)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS skill_stack_snapshots (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS task_state_snapshots (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS jd_fit_analyses (
                id TEXT PRIMARY KEY,
                jd_entry_id TEXT NOT NULL,
                skill_snapshot_id TEXT NOT NULL,
                task_snapshot_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_jd_fit_analyses_entry
            ON jd_fit_analyses(jd_entry_id)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS candidate_actions (
                id TEXT PRIMARY KEY,
                status TEXT NOT NULL,
                priority TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_candidate_actions_status
            ON candidate_actions(status)
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS user_contexts (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
