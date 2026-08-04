import os
import tempfile
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.chat import AIChatThreadCreate
from app.services.chat_service import ChatService
from app.services.feed_service import FeedService


def test_create_thread_and_send_mock_message():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_chat_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = FeedService().generate_and_save_mock_session()
        chat_service = ChatService()
        thread = chat_service.create_thread(
            AIChatThreadCreate(session_id=session.id, context_refs=[session.id])
        )
        assert thread is not None
        response = chat_service.send_message(thread.id, "这个信号值得继续跟踪吗？")
        assert response is not None
        assert len(response.thread.messages) == 2
        assert "mock" in response.assistant_message.content
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_summarize_thread_returns_mock_history_draft():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_chat_summary_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = FeedService().generate_and_save_mock_session()
        chat_service = ChatService()
        thread = chat_service.create_thread(
            AIChatThreadCreate(session_id=session.id, context_refs=["tech_radar", "signal:mock"])
        )
        assert thread is not None
        response = chat_service.send_message(thread.id, "这条技术信号应该怎么判断价值？")
        assert response is not None

        summary = chat_service.summarize_thread(thread.id)

        assert summary is not None
        assert summary.thread_id == thread.id
        assert summary.session_id == session.id
        assert summary.summary
        assert summary.key_insights
        assert summary.action_items
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
