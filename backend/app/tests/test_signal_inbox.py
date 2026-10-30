import os
import tempfile
from pathlib import Path

from app.config import get_settings
from app.schemas.common import TaskType
from app.db.migrations import init_db
from app.schemas.tech_radar import SignalLinkCreate
from app.services.feed_service import FeedService


class StaticPassageSearchService:
    def fetch_web_passages(self, url: str, max_passages: int = 5):
        assert url == "https://mp.weixin.qq.com/s/example"
        assert max_passages == 5
        return ["这是用户提供文章中可见的第一段原文证据。"]


def test_signal_inbox_persists_user_link_and_keeps_evidence_status():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "signal_inbox_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        feed.tech_radar_agent.search_service = StaticPassageSearchService()
        session = feed.generate_and_save_mock_session(task_type=TaskType.tech_radar)

        updated = feed.add_signal_link(
            session.id,
            SignalLinkCreate(
                url="https://mp.weixin.qq.com/s/example",
                title="可信公众号文章",
                source_name="测试公众号",
                note="和当前动态重建方向相关。",
            ),
        )

        assert updated is not None
        signal = updated.payload.digest.items[0]
        assert signal.title == "可信公众号文章"
        assert str(signal.url) == "https://mp.weixin.qq.com/s/example"
        assert signal.evidence_status == "excerpt_available"
        assert signal.source_passages[0].excerpt == "这是用户提供文章中可见的第一段原文证据。"

        deduplicated = feed.add_signal_link(
            session.id,
            SignalLinkCreate(url="https://mp.weixin.qq.com/s/example"),
        )
        assert deduplicated is not None
        assert len(deduplicated.payload.digest.items) == len(updated.payload.digest.items)
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
