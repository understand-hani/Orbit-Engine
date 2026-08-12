import os
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.common import TaskType
from app.schemas.source import CombinedSearchResponse, SourceItem, SourceItemType, SourceType
from app.services.feed_service import FeedService


class StaticSearchService:
    def search_technical_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        items = [
            SourceItem(
                id=f"paper_{index}",
                source=SourceType.arxiv,
                item_type=SourceItemType.paper,
                title=f"Radar source {index}",
                url=f"https://arxiv.org/abs/2608.{index:05d}",
                summary=f"Summary {index}",
                tags=["cs.CV"],
            )
            for index in range(1, 7)
        ]
        return CombinedSearchResponse(
            query=query,
            items=items[:max_results],
            fetched_at=datetime.now(timezone.utc),
        )


def test_saved_tech_radar_sessions_exclude_previous_source_urls():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_generation_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        feed.tech_radar_agent.search_service = StaticSearchService()

        first = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        second = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )

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
