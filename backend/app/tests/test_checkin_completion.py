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
            ),
        )

        assert result is not None
        updated_session = result["session"]
        checkin = result["checkin"]
        assert updated_session.completion.user_confirmed_status == CompletionSuggestion.partial
        assert checkin.session_id == session.id
        assert len(checkin_service.list_checkins(session.date.isoformat())) == 1
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
