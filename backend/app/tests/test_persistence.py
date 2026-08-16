import os
from datetime import date
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.user_context import (
    DirectionProfileSuggestion,
    DirectionProfileSuggestionRequest,
    MaterialSourceType,
)
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
                        "source_preferences": [
                            MaterialSourceType.arxiv,
                            MaterialSourceType.pdf,
                            MaterialSourceType.manual,
                            MaterialSourceType.url,
                        ],
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
        assert loaded.preferences.source_preferences == [
            MaterialSourceType.arxiv,
            MaterialSourceType.url,
        ]
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
        assert "Week " not in suggestion.full_cycle_plan[0]
        assert "/ Day" not in suggestion.full_cycle_plan[0]
        assert "材料" in suggestion.full_cycle_plan[0]
        assert "新能源行业研究" in suggestion.weekly_focus
        assert suggestion.next_action
        assert suggestion.active_tasks
        assert suggestion.tracking_keywords
        assert suggestion.fields == ["新能源行业研究"]
        assert suggestion.source_preferences
        assert "45" in suggestion.constraints[0]
        assert suggestion.generation_mode == "fallback"
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
        assert all("Week " not in item and "/ Day" not in item for item in suggestion.full_cycle_plan)
        assert "先搭建储能产业链地图并划分关键公司" in suggestion.full_cycle_plan[0]
        assert "跟踪政策、价格和龙头公司季度变化" in suggestion.full_cycle_plan[1]
        assert "形成一份储能公司对比和后续跟踪模板" in suggestion.full_cycle_plan[2]
        assert "必须回答的问题" in suggestion.full_cycle_plan[0]
        assert "比较维度" in suggestion.full_cycle_plan[1]
        assert "最小验证任务" in suggestion.full_cycle_plan[2]
        execution_sections = [item.split("具体执行计划：", 1)[1].split("产出：", 1)[0] for item in suggestion.full_cycle_plan]
        output_sections = [item.split("产出：", 1)[1] for item in suggestion.full_cycle_plan]
        assert len(set(execution_sections)) == len(suggestion.full_cycle_plan)
        assert len(set(output_sections)) == len(suggestion.full_cycle_plan)
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


def test_direction_strategy_rejects_unrelated_demo_defaults():
    service = UserContextService()
    request = DirectionProfileSuggestionRequest(
        long_term_goal="建立 SLAM、4DGS 与自动驾驶世界模型的差异化能力线",
        current_direction="SLAM 几何直觉 x 4DGS 动态重建 x 自动驾驶 World Model",
        current_stage="比较 reconstruction 与 generation 技术路线",
        background_summary="有自动驾驶定位与 SLAM 工程经验",
        target_cycle="3 个月",
        time_budget_min=30,
        full_cycle_plan=[
            "第 1 阶段：精读 StreetGaussian 与 4DGS 动态重建材料",
            "第 2 阶段：比较 reconstruction 与 driving video generation",
            "第 3 阶段：验证轻量 World Model pipeline",
        ],
        weekly_focus="本周聚焦 4DGS / World Model 路线判断",
        active_tasks=["比较 StreetGaussian 与 driving scene generation"],
        next_action="选择一篇自动驾驶世界模型论文",
    )
    unrelated = DirectionProfileSuggestion(
        full_cycle_plan=request.full_cycle_plan,
        weekly_focus=request.weekly_focus,
        next_action=request.next_action,
        active_tasks=request.active_tasks,
        tracking_keywords=[
            "personal agent",
            "learning workflow",
            "material source",
            "execution loop",
        ],
        fields=["AI workflow", "career capability", "self-directed learning"],
        source_preferences=[],
        constraints=[],
    )

    normalized = service._normalize_direction_profile_suggestion(request, unrelated)

    lowered_keywords = {value.lower() for value in normalized.tracking_keywords}
    assert "4dgs" in lowered_keywords
    assert "world model" in lowered_keywords
    assert "streetgaussian" in lowered_keywords
    assert "personal agent" not in lowered_keywords
    assert "learning workflow" not in lowered_keywords
    assert normalized.fields == [request.current_direction]
    assert [value.value for value in normalized.source_preferences] == [
        "arxiv",
        "official_doc",
        "url",
    ]


def test_new_user_context_is_blank_outside_explicit_demo_mode(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    original_env = os.environ.get("APP_ENV")
    os.environ["DATABASE_PATH"] = str(tmp_path / "blank_user.db")
    os.environ["APP_ENV"] = "development"
    get_settings.cache_clear()
    try:
        init_db()
        context = UserContextService().get_or_create()

        assert context.profile.display_name == "新用户"
        assert context.profile.goal == ""
        assert context.plan.full_cycle_plan == []
        assert context.plan.tracking_keywords == []
        assert context.preferences.fields == []
        assert context.materials == []
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        if original_env is None:
            os.environ.pop("APP_ENV", None)
        else:
            os.environ["APP_ENV"] = original_env
        get_settings.cache_clear()


def test_demo_context_requires_explicit_demo_environment(tmp_path):
    original_path = os.environ.get("DATABASE_PATH")
    original_env = os.environ.get("APP_ENV")
    os.environ["DATABASE_PATH"] = str(tmp_path / "demo_user.db")
    os.environ["APP_ENV"] = "demo"
    get_settings.cache_clear()
    try:
        init_db()
        context = UserContextService().get_or_create()

        assert context.profile.display_name == "Demo User"
        assert "4DGS" in context.profile.goal
        assert context.plan.full_cycle_plan
        assert context.materials
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        if original_env is None:
            os.environ.pop("APP_ENV", None)
        else:
            os.environ["APP_ENV"] = original_env
        get_settings.cache_clear()


def test_direction_strategy_filters_numeric_ranges_and_generic_baseline():
    service = UserContextService()
    request = DirectionProfileSuggestionRequest(
        current_direction="SLAM 与 4DGS 动态重建",
        full_cycle_plan=[
            "Week 1-2 / Day 1-5：围绕 StreetGaussian 与 4DGS 筛出 5-8 份材料并建立 baseline",
            "比较 SLAM filtering 与动态场景重建",
            "形成路线判断",
        ],
        weekly_focus="比较 StreetGaussian 与 SLAM filtering",
    )

    suggestion = service.suggest_direction_profile(request)

    lowered = {value.lower() for value in suggestion.tracking_keywords}
    assert "5-8" not in lowered
    assert "baseline" not in lowered
    assert "streetgaussian" in lowered
    assert "slam filtering" in lowered
    assert all("week" not in value and "day" not in value for value in lowered)
    assert suggestion.generation_mode == "deterministic"


def test_confirmed_full_cycle_plan_does_not_call_llm_again():
    class OpenRouterSettings:
        llm_provider = "openrouter"

    class LLMShouldNotRun:
        def generate_json(self, **kwargs):
            raise AssertionError("confirmed plan refinement must not call the LLM")

    service = UserContextService()
    service.settings = OpenRouterSettings()
    service.llm = LLMShouldNotRun()
    request = DirectionProfileSuggestionRequest(
        long_term_goal="建立自动驾驶世界模型研究能力",
        current_direction="SLAM x 4DGS x Driving World Model",
        current_stage="比较 reconstruction 与 generation",
        full_cycle_plan=[
            "第 1 阶段：精读 StreetGaussian 与 4DGS",
            "第 2 阶段：比较 driving video generation",
            "第 3 阶段：验证 World Model pipeline",
        ],
        weekly_focus="本周聚焦 4DGS 与 World Model",
        active_tasks=["比较 StreetGaussian 与 WorldSplat"],
    )

    suggestion = service.suggest_direction_profile(request)

    assert "4DGS" in suggestion.tracking_keywords
    assert "World Model" in suggestion.tracking_keywords
    assert suggestion.weekly_focus == request.weekly_focus


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
        "目标：搭建行业地图。明确重点公司。\n"
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
    objective_sections = [item.split("目标：", 1)[1].split("具体执行计划：", 1)[0] for item in normalized]
    assert all(section.count("搭建行业地图") == 1 for section in objective_sections)
    assert all("目标：\n1. 搭建行业地图。\n2. 明确重点公司。" in item for item in normalized)
    assert all("子阶段：" not in item and "动作：" not in item for item in normalized)
    assert all("目标：\n1. " in item and "具体执行计划：\n1. " in item and "产出：\n1. " in item for item in normalized)
    assert all("Week " not in item and "/ Day" not in item for item in normalized)


def test_legacy_nested_phase_text_is_reparsed_as_numbered_goals():
    service = UserContextService()
    legacy_phase = (
        "第 1 阶段（第 1-3 个月）\n"
        "目标：\n"
        "1. 第1阶段（第1-3个月）；目标：围绕「自动驾驶或具身智能的世界模型方向」完成这一阶段的连续子任务：第1-3个月：学习世界模型基础、阅读5-10篇关键论文、围绕 World Models 方向的核心方法。\n"
        "具体执行计划：\n"
        "1. 明确本阶段需要解决的 2-3 个关键问题和判断标准。\n"
        "2. 按关键词筛选材料，完成 Deep Dive，并记录证据与结论。\n"
        "产出：\n"
        "1. 一份阶段研究笔记。"
    )

    normalized = service._normalize_plan_items(
        [
            legacy_phase,
            legacy_phase.replace("第 1 阶段", "第 2 阶段").replace("第1阶段", "第2阶段"),
            legacy_phase.replace("第 1 阶段", "第 3 阶段").replace("第1阶段", "第3阶段"),
            legacy_phase.replace("第 1 阶段", "第 4 阶段").replace("第1阶段", "第4阶段"),
        ],
        "自动驾驶世界模型",
        "12 个月",
    )

    assert len(normalized) == 4
    assert all("目标：\n1. 学习世界模型基础。\n2. 阅读5-10篇关键论文。\n3. 围绕 World Models 方向的核心方法。" in item for item in normalized)
    assert all("第1阶段（第1-3个月）；目标：" not in item for item in normalized)
    assert all(item.split("目标：", 1)[1].split("具体执行计划：", 1)[0].count("目标：") == 0 for item in normalized)
    execution_sections = [item.split("具体执行计划：", 1)[1].split("产出：", 1)[0] for item in normalized]
    assert len(set(execution_sections)) == len(normalized)
    assert all("Week " not in item and "/ Day" not in item for item in normalized)
    first_steps = [line for line in execution_sections[0].splitlines() if line.strip()]
    assert len(first_steps) == len(set(first_steps))


def test_structured_but_generic_phase_is_upgraded_to_concrete_action_plan():
    service = UserContextService()
    generic_phase = (
        "第 1 阶段（第 1 个月）\n"
        "目标：\n"
        "1. 学习世界模型基础。\n"
        "具体执行计划：\n"
        "1. 界定研究范围、核心概念与判断标准。\n"
        "2. 收集代表性材料，建立关键词、来源与问题之间的索引。\n"
        "产出：\n"
        "1. 一份概念地图。"
    )

    normalized = service._normalize_plan_items(
        [
            generic_phase,
            generic_phase.replace("第 1 阶段", "第 2 阶段"),
            generic_phase.replace("第 1 阶段", "第 3 阶段"),
        ],
        "自动驾驶世界模型",
        "3 个月",
    )

    assert len(normalized) == 3
    assert all("Week " not in item and "/ Day" not in item for item in normalized)
    assert "状态表示、时序预测、训练信号、评估指标" in normalized[0]
    assert "界定研究范围、核心概念与判断标准" not in normalized[0]


def test_structured_short_week_plan_is_upgraded_when_phase_is_longer():
    service = UserContextService()
    short_phase = (
        "第 1 阶段（第 1-3 个月）\n"
        "目标：\n"
        "1. 学习世界模型基础。\n"
        "具体执行计划：\n"
        "1. Week 1 / Day 1-5：拆问题。\n"
        "2. Week 2 / Day 1-5：读材料。\n"
        "产出：\n"
        "1. 一份概念地图。"
    )

    normalized = service._normalize_plan_items(
        [
            short_phase,
            short_phase.replace("第 1 阶段", "第 2 阶段"),
            short_phase.replace("第 1 阶段", "第 3 阶段"),
            short_phase.replace("第 1 阶段", "第 4 阶段"),
        ],
        "自动驾驶世界模型",
        "12 个月",
    )

    assert len(normalized) == 4
    assert all("Week " not in item and "/ Day" not in item for item in normalized)
    assert all("读材料" not in item for item in normalized)
