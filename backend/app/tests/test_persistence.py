import os
from datetime import date
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.services.feed_service import FeedService
from app.services.user_context_service import UserContextService


def test_generate_save_and_read_session(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    db_path = tmp_path / "infra_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        service = FeedService()
        saved = service.generate_and_save_mock_session(date(2026, 7, 13))
        loaded = service.get_session(saved.id)
        by_date = service.get_sessions_by_date(date(2026, 7, 13))

        assert loaded is not None
        assert loaded.id == saved.id
        assert len(by_date) == 1
        assert Path(db_path).exists()
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_save_and_read_user_context_direction_profile(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    db_path = tmp_path / "infra_user_context_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        service = UserContextService()
        context = service.get_or_create()
        updated = context.model_copy(
            update={
                "profile": context.profile.model_copy(
                    update={
                        "goal": "学习自定义领域并让 Agent 自动推荐 Deep Dive 材料。",
                        "current_stage": "先配置方向，再做自动选材。",
                    }
                ),
                "plan": context.plan.model_copy(
                    update={
                        "weekly_focus": "验证方向配置能驱动 Deep Dive Agent 选材。",
                        "tracking_keywords": ["deep dive", "agent material recommendation"],
                    }
                ),
                "preferences": context.preferences.model_copy(
                    update={
                        "fields": ["custom domain"],
                        "session_time_budget_min": 45,
                    }
                ),
            }
        )
        service.save(updated)

        loaded = service.get_or_create()

        assert loaded.profile.goal == "学习自定义领域并让 Agent 自动推荐 Deep Dive 材料。"
        assert loaded.profile.current_stage == "先配置方向，再做自动选材。"
        assert loaded.plan.weekly_focus == "验证方向配置能驱动 Deep Dive Agent 选材。"
        assert loaded.plan.tracking_keywords == ["deep dive", "agent material recommendation"]
        assert loaded.preferences.fields == ["custom domain"]
        assert loaded.preferences.session_time_budget_min == 45
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
