import os
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.chat import AIChatThreadCreate
from app.schemas.common import TaskType
from app.schemas.source import CombinedSearchResponse, SourceItem, SourceItemType, SourceType
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


class FakeRadarSearchService:
    def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        items = [
            SourceItem(
                id=f"industry_{index}",
                source=SourceType.web,
                item_type=SourceItemType.article,
                title=f"{query} radar source {index}",
                url=f"https://example.com/radar/{index}",
                summary=f"{query} public industry signal {index}",
                tags=["public_web"],
                extra={"fetch_passages": True},
            )
            for index in range(1, 7)
        ]
        return CombinedSearchResponse(
            query=query,
            items=items[:max_results],
            fetched_at=datetime.now(timezone.utc),
        )

    def fetch_web_passages(self, url: str, max_passages: int = 5):
        return [
            f"{url} 原文第一段：某机构发布了面向行业场景的新平台。",
            f"{url} 原文第二段：平台已在真实业务中完成测试，覆盖数据接入、风险识别。",
        ][:max_passages]


def _generate_radar_session_with_items():
    feed = FeedService()
    feed.tech_radar_agent.search_service = FakeRadarSearchService()
    seed = feed.generate_and_save_mock_session(
        date(2026, 8, 13),
        task_type=TaskType.tech_radar,
    )
    refreshed = feed.refresh_tech_radar_session(seed.id)
    assert refreshed is not None
    assert len(refreshed.payload.digest.items) >= 2
    return refreshed


def test_radar_chat_messages_include_real_signal_context():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_chat_radar_context_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = _generate_radar_session_with_items()
        chat_service = ChatService()
        item = session.payload.digest.items[0]

        thread = chat_service.create_thread(
            AIChatThreadCreate(
                session_id=session.id,
                context_refs=["tech_radar", f"signal:{item.id}"],
            )
        )
        assert thread is not None

        messages = chat_service._messages_for(thread, "这条信号值得跟踪吗？")
        material_context = "\n".join(message["content"] for message in messages)

        assert item.title in material_context
        assert item.summary in material_context
        assert item.technical_substance in material_context
        assert item.source_passages[0].excerpt in material_context
        assert "不要把 signal id 当成唯一信息" in material_context
        assert "不要把 paper_id 当成唯一信息" not in material_context
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_radar_per_item_threads_do_not_clobber_each_other():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_chat_radar_threads_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = _generate_radar_session_with_items()
        chat_service = ChatService()
        item_a = session.payload.digest.items[0]
        item_b = session.payload.digest.items[1]

        thread_a = chat_service.create_thread(
            AIChatThreadCreate(
                session_id=session.id,
                context_refs=["tech_radar", f"signal:{item_a.id}"],
            )
        )
        thread_b = chat_service.create_thread(
            AIChatThreadCreate(
                session_id=session.id,
                context_refs=["tech_radar", f"signal:{item_b.id}"],
            )
        )
        assert thread_a is not None
        assert thread_b is not None
        assert thread_a.id != thread_b.id

        thread_a_again = chat_service.create_thread(
            AIChatThreadCreate(
                session_id=session.id,
                context_refs=["tech_radar", f"signal:{item_a.id}"],
            )
        )
        assert thread_a_again is not None
        assert thread_a_again.id == thread_a.id
        assert chat_service.get_thread(thread_b.id) is not None
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
