import os
import tempfile
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.chat import AIChatThreadCreate
from app.schemas.common import TaskType
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


def test_chat_openrouter_mode_falls_back_without_api_key():
    original_path = os.environ.get("DATABASE_PATH")
    original_provider = os.environ.get("LLM_PROVIDER")
    original_key = os.environ.get("OPENROUTER_API_KEY")
    db_path = Path(tempfile.mkdtemp()) / "infra_chat_openrouter_fallback_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    os.environ["LLM_PROVIDER"] = "openrouter"
    os.environ.pop("OPENROUTER_API_KEY", None)
    get_settings.cache_clear()
    try:
        init_db()
        session = FeedService().generate_and_save_mock_session()
        chat_service = ChatService()
        thread = chat_service.create_thread(
            AIChatThreadCreate(session_id=session.id, context_refs=[session.id])
        )
        assert thread is not None

        response = chat_service.send_message(thread.id, "请解释这篇材料的阅读重点")

        assert response is not None
        assert "Mock fallback" in response.assistant_message.content
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        if original_provider is None:
            os.environ.pop("LLM_PROVIDER", None)
        else:
            os.environ["LLM_PROVIDER"] = original_provider
        if original_key is None:
            os.environ.pop("OPENROUTER_API_KEY", None)
        else:
            os.environ["OPENROUTER_API_KEY"] = original_key
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


def test_deep_dive_chat_messages_include_real_material_context():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_chat_context_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = FeedService().generate_and_save_mock_session(task_type=TaskType.research_feeder)
        chat_service = ChatService()
        payload = session.payload
        paper = payload.papers[0]
        reader = payload.paper_readers[0]
        section = reader.sections[0]
        passage = reader.selected_passages[0]
        figure = reader.key_figures[0]
        thread = chat_service.create_thread(
            AIChatThreadCreate(
                session_id=session.id,
                context_refs=[paper.id, section.id, passage.id, figure.id],
            )
        )
        assert thread is not None

        messages = chat_service._messages_for(thread, "这篇论文最值得读哪里？")
        material_context = "\n".join(message["content"] for message in messages)

        assert paper.title in material_context
        assert paper.summary in material_context
        assert str(paper.pdf_url) in material_context
        assert section.extracted_text in material_context
        assert passage.text_excerpt in material_context
        assert figure.visual.caption in material_context
        assert "不要把 paper_id 当成唯一信息" in material_context
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
