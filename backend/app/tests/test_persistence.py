import os
from datetime import date
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.user_context import DirectionProfileSuggestionRequest
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
                        "target_cycle": "3 个月",
                        "full_cycle_plan": [
                            "第 1 阶段：明确目标领域，整理核心问题、关键词和材料范围。",
                            "第 2 阶段：完成 2 次 Deep Dive，并写出方法差异和阶段判断。",
                            "第 3 阶段：做一份小输出，验证前两阶段形成的判断。",
                        ],
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
        assert loaded.plan.target_cycle == "3 个月"
        assert len(loaded.plan.full_cycle_plan) == 3
        assert loaded.plan.full_cycle_plan[0].startswith("第 1 阶段（")
        assert "整理核心问题" in loaded.plan.full_cycle_plan[0]
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


def test_direction_profile_suggestion_falls_back_without_llm(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    original_provider = os.environ.get("LLM_PROVIDER")
    original_key = os.environ.get("OPENROUTER_API_KEY")
    db_path = tmp_path / "infra_direction_suggestion_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    os.environ["LLM_PROVIDER"] = "openrouter"
    os.environ.pop("OPENROUTER_API_KEY", None)
    get_settings.cache_clear()
    try:
        init_db()
        suggestion = UserContextService().suggest_direction_profile(
            DirectionProfileSuggestionRequest(
                long_term_goal="建立一个投资研究体系",
                current_direction="新能源行业研究",
                current_stage="入门到形成第一篇笔记",
                background_summary="用户有基础财务知识，但行业研究经验少。",
                target_cycle="半年",
                time_budget_min=45,
            )
        )

        assert suggestion.full_cycle_plan
        assert 3 <= len(suggestion.full_cycle_plan) <= 4
        assert "（" in suggestion.full_cycle_plan[0]
        assert "目标：" in suggestion.full_cycle_plan[0]
        assert "具体执行计划：" in suggestion.full_cycle_plan[0]
        assert "产出：" in suggestion.full_cycle_plan[0]
        assert "\n1. " in suggestion.full_cycle_plan[0]
        assert "新能源行业研究" in suggestion.weekly_focus
        assert suggestion.next_action
        assert suggestion.active_tasks
        assert suggestion.tracking_keywords
        assert suggestion.fields == ["新能源行业研究"]
        assert suggestion.source_preferences
        assert "45" in suggestion.constraints[0]
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


def test_direction_profile_suggestion_uses_edited_full_cycle_plan(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    original_provider = os.environ.get("LLM_PROVIDER")
    original_key = os.environ.get("OPENROUTER_API_KEY")
    db_path = tmp_path / "infra_direction_refine_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    os.environ["LLM_PROVIDER"] = "openrouter"
    os.environ.pop("OPENROUTER_API_KEY", None)
    get_settings.cache_clear()
    try:
        init_db()
        suggestion = UserContextService().suggest_direction_profile(
            DirectionProfileSuggestionRequest(
                long_term_goal="形成自己的行业研究方法",
                current_direction="储能产业链研究",
                current_stage="建立框架",
                background_summary="有财报基础，但缺行业跟踪框架。",
                target_cycle="3 个月",
                time_budget_min=30,
                full_cycle_plan=[
                    "第 1 阶段：先搭建储能产业链地图并划分关键公司",
                    "第 2 阶段：跟踪政策、价格和龙头公司季度变化",
                    "第 3 阶段：形成一份储能公司对比和后续跟踪模板",
                ],
            )
        )

        assert all("目标：\n1. " in item for item in suggestion.full_cycle_plan)
        assert all("具体执行计划：\n1. " in item for item in suggestion.full_cycle_plan)
        assert all("产出：\n1. " in item for item in suggestion.full_cycle_plan)
        assert "先搭建储能产业链地图并划分关键公司" in suggestion.full_cycle_plan[0]
        assert "跟踪政策、价格和龙头公司季度变化" in suggestion.full_cycle_plan[1]
        assert "形成一份储能公司对比和后续跟踪模板" in suggestion.full_cycle_plan[2]
        assert "储能产业链地图" in suggestion.weekly_focus
        assert any("阶段" in task or "本周" in task for task in suggestion.active_tasks)
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


def test_existing_context_plan_is_normalized_on_read(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    db_path = tmp_path / "infra_plan_normalize_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        service = UserContextService()
        context = service.get_or_create()
        noisy = context.model_copy(
            update={
                "plan": context.plan.model_copy(
                    update={
                        "full_cycle_plan": [
                            "第1阶段：学习世界模型基础",
                            "掌握World Models",
                            "Dreamer",
                            "vista等",
                            "深入自动驾驶世界模型方向",
                            "复现一个基础世界模型代码",
                        ]
                    }
                )
            }
        )
        service.repository.save(noisy)

        loaded = service.get_or_create()

        assert len(loaded.plan.full_cycle_plan) == 4
        assert all(item.startswith("第 ") for item in loaded.plan.full_cycle_plan)
        assert all("目标：" in item and "具体执行计划：" in item and "产出：" in item for item in loaded.plan.full_cycle_plan)
        assert all("\n1. " in item for item in loaded.plan.full_cycle_plan)
        assert all("Dreamer；vista等" not in item for item in loaded.plan.full_cycle_plan)
        assert all("vista等" not in item for item in loaded.plan.full_cycle_plan)
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_old_structured_phases_are_migrated_without_repeating_content():
    service = UserContextService()
    old_phase = (
        "第 1 阶段（第 1 个月）\n"
        "目标：搭建行业地图。\n"
        "子阶段：\n- 搭建行业地图。\n"
        "动作：\n- 搜集资料。\n"
        "产出：\n- 行业地图。"
    )

    normalized = service._normalize_plan_items(
        [old_phase, old_phase.replace("第 1 阶段", "第 2 阶段"), old_phase.replace("第 1 阶段", "第 3 阶段")],
        "行业研究",
        "3 个月",
    )

    assert len(normalized) == 3
    assert all(item.count("搭建行业地图") == 1 for item in normalized)
    assert all("子阶段：" not in item and "动作：" not in item for item in normalized)
    assert all("目标：\n1. " in item and "具体执行计划：\n1. " in item and "产出：\n1. " in item for item in normalized)
