import os
import tempfile
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
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

        assert first.title == f"Deep Dive-{first.date.isoformat()}-1"
        assert second.title == f"Deep Dive-{first.date.isoformat()}-2"
        assert preview.title == f"Deep Dive-{first.date.isoformat()}-3"

        renamed = feed_service.rename_session(second.id, "3")
        assert renamed is not None
        assert renamed.title == f"Deep Dive-{first.date.isoformat()}-3"

        try:
            feed_service.rename_session(renamed.id, "1")
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
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
