import os
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.common import TaskType
from app.schemas.source import CombinedSearchResponse, SourceItem, SourceItemType, SourceType
from app.schemas.user_context import PersonalProfile, UserContext, UserPreference, WorkLearningPlan
from app.agents.tech_radar_agent import MockTechRadarAgent
from app.services.feed_service import FeedService
from app.services.user_context_service import UserContextService


class StaticSearchService:
    def __init__(self) -> None:
        self.queries = []

    def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        self.queries.append(query)
        items = [
            SourceItem(
                id=f"industry_{index}",
                source=SourceType.web,
                item_type=SourceItemType.article,
                title=f"{query} industry radar source {index}",
                url=f"https://example.com/radar/{index}",
                summary=f"{query} public industry signal {index}",
                tags=["public_web"],
            )
            for index in range(1, 7)
        ]
        return CombinedSearchResponse(
            query=query,
            items=items[:max_results],
            fetched_at=datetime.now(timezone.utc),
        )


class FailingSearchService:
    def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        raise RuntimeError("network unavailable")


def test_saved_tech_radar_sessions_exclude_previous_source_urls():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_generation_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        feed.tech_radar_agent.search_service = StaticSearchService()

        first_empty = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        second_empty = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        assert first_empty.payload.digest.items == []
        assert second_empty.payload.digest.items == []

        first = feed.refresh_tech_radar_session(first_empty.id)
        second = feed.refresh_tech_radar_session(second_empty.id)
        assert first is not None
        assert second is not None

        first_urls = {str(item.url) for item in first.payload.digest.items}
        second_urls = {str(item.url) for item in second.payload.digest.items}

        assert len(first_urls) == 3
        assert len(second_urls) == 3
        assert first_urls.isdisjoint(second_urls)
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_tech_radar_override_creates_empty_radar_session_on_non_radar_date():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_override_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = FeedService().generate_and_save_mock_session(
            date(2026, 8, 12),
            task_type=TaskType.tech_radar,
        )

        assert session.task_type == TaskType.tech_radar
        assert session.payload.digest.items == []
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_tech_radar_uses_user_goal_for_queries_and_relevance():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_user_goal_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        now = datetime.now(timezone.utc)
        UserContextService().save(
            UserContext(
                profile=PersonalProfile(
                    goal="量化交易风控平台",
                    background_summary="关注金融科技行业动态。",
                    current_stage="寻找机构和平台的产品信号。",
                    updated_at=now,
                ),
                plan=WorkLearningPlan(
                    long_term_goal="跟踪量化交易风控平台的行业机会。",
                    weekly_focus="观察证券公司和金融科技平台的风控产品发布。",
                    active_tasks=["记录公开网页中的产品发布和机构动作"],
                    tracking_keywords=["量化交易风控", "证券风控平台"],
                    updated_at=now,
                ),
                preferences=UserPreference(
                    fields=["金融科技", "量化交易"],
                    updated_at=now,
                ),
            )
        )
        feed = FeedService()
        search = StaticSearchService()
        feed.tech_radar_agent.search_service = search

        session = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        refreshed = feed.refresh_tech_radar_session(session.id)

        assert refreshed is not None
        assert len(refreshed.payload.digest.items) == 3
        joined_queries = " ".join(search.queries)
        assert "量化交易风控平台" in joined_queries
        assert "autonomous driving" not in joined_queries.lower()
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_radar_relevance_allows_industry_signal_without_exact_goal_sentence():
    agent = MockTechRadarAgent()
    source_item = SourceItem(
        id="web_001",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="某金融科技公司发布新一代风控产品",
        url="https://example.com/fintech-risk-product",
        summary="该产品面向证券机构，提供平台化风险管理能力。",
        tags=["public_web"],
    )

    assert agent._is_relevant_source(source_item, ["量化交易风控平台"])


def test_tech_radar_refresh_does_not_fallback_to_mock_items():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_no_mock_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        feed.tech_radar_agent.search_service = FailingSearchService()

        session = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        refreshed = feed.refresh_tech_radar_session(session.id)

        assert refreshed is not None
        assert refreshed.payload.digest.items == []
        assert "未从公开源检索到" in refreshed.payload.digest.summary
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
