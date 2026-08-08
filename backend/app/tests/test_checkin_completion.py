import os
import tempfile
from datetime import date
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.common import SessionStatus, TaskType
from app.schemas.completion import CompletionConfirmRequest, CompletionSuggestion
from app.services.checkin_service import CheckinService
from app.services.feed_service import FeedService


def test_confirm_completion_updates_session_and_creates_checkin():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_checkin_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        checkin_service = CheckinService()

        session = feed_service.generate_and_save_mock_session()
        result = checkin_service.confirm_completion(
            session.id,
            CompletionConfirmRequest(
                duration_min=45,
                status=CompletionSuggestion.partial,
                summary="读完一部分材料并记录了下一步。",
                key_insight="样例洞察。",
                next_action="继续补读。",
                source_title="Boundless Agents",
                source_url="https://example.com/paper",
                source_summary="论文主旨摘要。",
                user_notes="用户自己的阅读笔记。",
            ),
        )

        assert result is not None
        updated_session = result["session"]
        checkin = result["checkin"]
        assert updated_session.completion.user_confirmed_status == CompletionSuggestion.partial
        assert checkin.session_id == session.id
        assert checkin.source_title == "Boundless Agents"
        assert checkin.source_url == "https://example.com/paper"
        assert checkin.source_summary == "论文主旨摘要。"
        assert checkin.user_notes == "用户自己的阅读笔记。"
        assert len(checkin_service.list_checkins(session.date.isoformat())) == 1
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()

def test_delete_session_marks_session_skipped_without_checkin():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_delete_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        checkin_service = CheckinService()

        session = feed_service.generate_and_save_mock_session()

        assert feed_service.get_session(session.id) is not None
        assert feed_service.delete_session(session.id) is True
        updated_session = feed_service.get_session(session.id)
        assert updated_session is not None
        assert updated_session.status.value == "skipped"
        checkins = checkin_service.list_checkins(session.date.isoformat())
        assert checkins == []
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_today_does_not_recreate_discarded_session():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_today_discard_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()

        session = feed_service.generate_and_save_mock_session()
        assert feed_service.delete_session(session.id) is True

        today_session = feed_service.get_or_create_mock_session(session.date)
        assert today_session.id == session.id
        assert today_session.status.value == "skipped"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_research_session_default_title_and_rename_rejects_duplicate():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_rename_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()

        first = feed_service.generate_and_save_mock_session()
        second = feed_service.generate_and_save_mock_session(first.date)
        preview = feed_service.generate_mock_session(first.date)
        assert feed_service.delete_session(first.id) is True
        replacement = feed_service.generate_and_save_mock_session(first.date)

        title_date = first.date.strftime("%Y/%m/%d")
        assert first.title == f"Deep Dive-{title_date}-1"
        assert second.title == f"Deep Dive-{title_date}-2"
        assert preview.title == f"Deep Dive-{title_date}-3"
        assert replacement.title == f"Deep Dive-{title_date}-3"

        renamed = feed_service.rename_session(second.id, "4")
        assert renamed is not None
        assert renamed.title == f"Deep Dive-{title_date}-4"

        try:
            feed_service.rename_session(renamed.id, "3")
        except ValueError as exc:
            assert "名称已存在" in str(exc)
        else:
            raise AssertionError("duplicate rename should be rejected")
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_research_session_title_sequence_counts_archived_duplicates():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_duplicate_sequence_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()

        first = feed_service.generate_and_save_mock_session()
        second = feed_service.generate_and_save_mock_session(first.date)
        title_date = first.date.strftime("%Y/%m/%d")
        duplicate_archived = feed_service.generate_mock_session(first.date).model_copy(
            update={
                "id": "duplicate_archived",
                "title": f"Deep Dive-{title_date}-1",
                "status": SessionStatus.archived,
            }
        )
        feed_service.sessions.save(duplicate_archived)

        next_after_duplicate = feed_service.generate_and_save_mock_session(first.date)

        assert first.title == f"Deep Dive-{title_date}-1"
        assert second.title == f"Deep Dive-{title_date}-2"
        assert next_after_duplicate.title == f"Deep Dive-{title_date}-3"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_archive_session_marks_session_archived_and_creates_checkin():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_archive_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        checkin_service = CheckinService()

        session = feed_service.generate_and_save_mock_session()

        assert feed_service.archive_session(session.id) is True
        updated_session = feed_service.get_session(session.id)
        assert updated_session is not None
        assert updated_session.status.value == "archived"
        checkins = checkin_service.list_checkins(session.date.isoformat())
        assert len(checkins) == 1
        assert checkins[0].status.value == "archived"
        title_date = session.date.strftime("%Y/%m/%d")
        assert checkins[0].summary == f"已暂存：Deep Dive-{title_date}-1"

        restored_session = feed_service.restore_session(session.id)
        assert restored_session is not None
        assert restored_session.status.value == "active"
        assert restored_session.title == f"Deep Dive-{title_date}-1"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_archive_and_restore_preserve_deep_dive_title():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_archive_title_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        checkin_service = CheckinService()

        first = feed_service.generate_and_save_mock_session()
        second = feed_service.generate_and_save_mock_session(first.date)
        title_date = first.date.strftime("%Y/%m/%d")

        assert first.title == f"Deep Dive-{title_date}-1"
        assert second.title == f"Deep Dive-{title_date}-2"
        assert feed_service.archive_session(second.id) is True

        archived_second = feed_service.get_session(second.id)
        assert archived_second is not None
        assert archived_second.title == f"Deep Dive-{title_date}-2"
        checkins = checkin_service.list_checkins(second.date.isoformat())
        assert checkins[0].summary == f"已暂存：Deep Dive-{title_date}-2"

        third = feed_service.generate_and_save_mock_session(first.date, task_type=TaskType.research_feeder)
        assert third.title == f"Deep Dive-{title_date}-3"

        restored_second = feed_service.restore_session(second.id)
        assert restored_second is not None
        assert restored_second.title == f"Deep Dive-{title_date}-2"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_archiving_legacy_deep_dive_title_normalizes_once_and_counts_sequence():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_legacy_archive_title_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        legacy = feed_service.generate_and_save_mock_session(task_type=TaskType.research_feeder)
        legacy = legacy.model_copy(update={"title": "研究阅读启动"})
        feed_service.sessions.save(legacy)
        title_date = legacy.date.strftime("%Y/%m/%d")

        assert feed_service.archive_session(legacy.id) is True
        archived_legacy = feed_service.get_session(legacy.id)
        assert archived_legacy is not None
        assert archived_legacy.title == f"Deep Dive-{title_date}-1"

        next_session = feed_service.generate_and_save_mock_session(
            legacy.date,
            task_type=TaskType.research_feeder,
        )
        assert next_session.title == f"Deep Dive-{title_date}-2"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_new_deep_dive_counts_legacy_active_sessions_after_normalization():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_legacy_active_sequence_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        legacy_one = feed_service.generate_and_save_mock_session(task_type=TaskType.research_feeder)
        legacy_two = feed_service.generate_and_save_mock_session(
            legacy_one.date,
            task_type=TaskType.research_feeder,
        )
        legacy_one = legacy_one.model_copy(update={"title": "研究阅读启动"})
        legacy_two = legacy_two.model_copy(update={"title": "研究阅读补做"})
        feed_service.sessions.save(legacy_one)
        feed_service.sessions.save(legacy_two)
        title_date = legacy_one.date.strftime("%Y/%m/%d")

        next_session = feed_service.generate_and_save_mock_session(
            legacy_one.date,
            task_type=TaskType.research_feeder,
        )

        assert feed_service.get_session(legacy_one.id).title == f"Deep Dive-{title_date}-1"
        assert feed_service.get_session(legacy_two.id).title == f"Deep Dive-{title_date}-2"
        assert next_session.title == f"Deep Dive-{title_date}-3"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_today_generates_next_title_after_terminal_archive_or_completion():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_today_sequence_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        checkin_service = CheckinService()

        archived = feed_service.generate_and_save_mock_session()
        title_date = archived.date.strftime("%Y/%m/%d")
        assert archived.title == f"Deep Dive-{title_date}-1"
        assert feed_service.archive_session(archived.id) is True

        after_archive = feed_service.get_or_create_mock_session(archived.date)
        assert after_archive.title == f"Deep Dive-{title_date}-2"

        result = checkin_service.confirm_completion(
            after_archive.id,
            CompletionConfirmRequest(
                duration_min=30,
                status=CompletionSuggestion.completed,
                summary="完成阅读。",
                key_insight="记录重点。",
                next_action="进入下一张。",
            ),
        )
        assert result is not None

        after_completion = feed_service.get_or_create_mock_session(archived.date)
        assert after_completion.title == f"Deep Dive-{title_date}-3"

        assert feed_service.delete_session(after_completion.id) is True
        after_delete = feed_service.get_or_create_mock_session(archived.date)
        assert after_delete.id == after_completion.id
        assert after_delete.status == SessionStatus.skipped
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_can_force_deep_dive_for_current_date_independent_of_weekday_schedule():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_session_forced_deep_dive_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed_service = FeedService()
        monday = date.fromisoformat("2026-08-10")

        scheduled = feed_service.generate_mock_session(monday)
        forced = feed_service.generate_and_save_mock_session(monday, task_type=TaskType.research_feeder)

        title_date = monday.strftime("%Y/%m/%d")
        assert scheduled.task_type == TaskType.tech_radar
        assert forced.task_type == TaskType.research_feeder
        assert forced.title == f"Deep Dive-{title_date}-1"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
