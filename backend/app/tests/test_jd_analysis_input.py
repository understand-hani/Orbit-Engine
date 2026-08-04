import os
import tempfile
from datetime import date
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.common import TaskType
from app.schemas.jd_analysis import JDInputCreate
from app.services.feed_service import FeedService


def test_analyze_jd_updates_session_payload():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_jd_input_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        session = feed.generate_and_save_mock_session(date(2026, 7, 15))
        assert session.task_type == TaskType.jd_analysis

        updated = feed.analyze_jd(
            session.id,
            JDInputCreate(
                company="Example Robotics",
                role_title="Research Engineer - World Model",
                location="Shanghai",
                jd_text="负责自动驾驶 world model、4DGS、SLAM 与 PyTorch 训练工程。",
                recruiter_context="猎头说偏研究工程，不是项目管理。",
                user_question="这个岗位值得保持联系吗？",
            ),
        )

        assert updated is not None
        assert updated.payload.jd_input.company == "Example Robotics"
        assert updated.payload.jd_input.role_title == "Research Engineer - World Model"
        assert updated.payload.analysis.overall_recommendation
        assert feed.get_session(session.id).payload.jd_input.company == "Example Robotics"
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
