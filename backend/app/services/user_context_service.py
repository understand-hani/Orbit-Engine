import re
from datetime import datetime, timezone
from uuid import uuid4

from app.db.repositories import UserContextRepository
from app.schemas.user_context import (
    DirectionProfileSuggestion,
    DirectionProfileSuggestionRequest,
    MaterialSourceType,
    PersonalProfile,
    UserContext,
    UserMaterial,
    UserMaterialCreate,
    UserPreference,
    WorkLearningPlan,
)
from app.config import get_settings
from app.services.llm_service import (
    DIRECTION_PROFILE_SUGGESTION_SYSTEM_PROMPT,
    OpenRouterChatService,
)


class UserContextService:
    def __init__(self) -> None:
        self.repository = UserContextRepository()
        self.settings = get_settings()
        self.llm = OpenRouterChatService()

    def get_or_create(self) -> UserContext:
        existing = self.repository.get()
        if existing is not None:
            normalized = self._normalize_context(existing)
            if normalized != existing:
                return self.repository.save(normalized)
            return normalized
        return self.repository.save(self._default_context())

    def save(self, context: UserContext) -> UserContext:
        return self.repository.save(self._normalize_context(context))

    def suggest_direction_profile(
        self,
        request: DirectionProfileSuggestionRequest,
    ) -> DirectionProfileSuggestion:
        if self.settings.llm_provider == "openrouter":
            try:
                output = self.llm.generate_json(
                    system_prompt=DIRECTION_PROFILE_SUGGESTION_SYSTEM_PROMPT,
                    user_payload=request.model_dump(mode="json"),
                    output_model=DirectionProfileSuggestion,
                    schema_name="direction_profile_suggestion",
                )
                return self._normalize_direction_profile_suggestion(request, output)
            except Exception:
                pass
        return self._normalize_direction_profile_suggestion(request, self._fallback_direction_profile(request))

    def add_material(self, request: UserMaterialCreate) -> UserMaterial:
        context = self.get_or_create()
        now = datetime.now(timezone.utc)
        material = UserMaterial(
            id=f"material_{uuid4().hex[:12]}",
            title=request.title,
            source_type=request.source_type,
            summary=request.summary,
            url=request.url,
            file_path=request.file_path,
            authors_or_owner=request.authors_or_owner,
            published_date=request.published_date,
            tags=request.tags,
            related_plan=request.related_plan or context.plan.weekly_focus,
            why_selected=(
                f"这份材料关联当前计划：{request.related_plan or context.plan.weekly_focus}。"
                f"它适合在 {context.preferences.session_time_budget_min} 分钟内形成一个可记录的 Deep Dive 输出。"
            ),
            fetched_at=now,
        )
        updated = context.model_copy(update={"materials": [material, *context.materials]})
        self.repository.save(updated)
        return material

    def _fallback_direction_profile(
        self,
        request: DirectionProfileSuggestionRequest,
    ) -> DirectionProfileSuggestion:
        direction = request.current_direction.strip() or "当前方向"
        stage = request.current_stage.strip() or "当前阶段"
        full_cycle_plan = [item.strip() for item in request.full_cycle_plan if item.strip()]
        if not full_cycle_plan:
            full_cycle_plan = [
                f"围绕「{direction}」建立基础地图，整理 10-15 个核心概念、代表材料和可直接检索的关键词。",
                f"围绕「{direction}」完成 2-4 次 Deep Dive，把关键路线、方法差异和适用边界写成可复用笔记。",
                f"围绕「{direction}」做一个小型输出，如对比清单、案例拆解或实践草稿，用来验证前两阶段结论。",
            ]

        current_milestone = full_cycle_plan[0]
        weekly_focus = request.weekly_focus.strip() or (
            f"本周先推进「{current_milestone}」，至少完成一次材料筛选、一次 Deep Dive，以及一份可回看的阶段笔记。"
        )
        active_tasks = [item.strip() for item in request.active_tasks if item.strip()]
        if not active_tasks:
            active_tasks = [
                f"从「{current_milestone}」里拆出 2-3 个本周必须回答的具体问题，并写成检索目标。",
                "生成 3-5 个候选材料，标记每份材料能回答什么问题、需要多少时间、为什么值得读。",
                "完成一次 Deep Dive，并产出一份包含关键判断、证据、未解决问题和下一步动作的笔记。",
            ]
        next_action = request.next_action.strip() or "让 Agent 根据本周重点生成候选材料，并先确认一份今天最值得读的主材料。"

        return DirectionProfileSuggestion(
            full_cycle_plan=full_cycle_plan,
            weekly_focus=weekly_focus,
            next_action=next_action,
            active_tasks=active_tasks,
            tracking_keywords=[
                item
                for item in [
                    direction,
                    request.long_term_goal.strip(),
                    stage,
                    current_milestone,
                ]
                if item
            ],
            fields=[direction],
            source_preferences=[
                MaterialSourceType.arxiv,
                MaterialSourceType.github,
                MaterialSourceType.official_doc,
                MaterialSourceType.url,
            ],
            constraints=[
                f"每次 Deep Dive 控制在 {request.time_budget_min} 分钟左右",
                "优先选择能产生明确判断或下一步动作的材料",
                "避免只收藏材料但不完成阅读输出",
            ],
        )

    def _normalize_context(self, context: UserContext) -> UserContext:
        normalized_plan = self._normalize_work_learning_plan(context)
        if normalized_plan == context.plan:
            return context
        return context.model_copy(update={"plan": normalized_plan})

    def _normalize_work_learning_plan(self, context: UserContext) -> WorkLearningPlan:
        direction = context.profile.goal or context.plan.long_term_goal or "当前方向"
        normalized_full_cycle_plan = self._normalize_plan_items(
            context.plan.full_cycle_plan,
            direction,
            context.plan.target_cycle,
        )
        return context.plan.model_copy(
            update={
                "full_cycle_plan": normalized_full_cycle_plan,
            }
        )

    def _normalize_direction_profile_suggestion(
        self,
        request: DirectionProfileSuggestionRequest,
        suggestion: DirectionProfileSuggestion,
    ) -> DirectionProfileSuggestion:
        direction = request.current_direction.strip() or request.long_term_goal.strip() or "当前方向"
        normalized_plan = self._normalize_plan_items(suggestion.full_cycle_plan, direction, request.target_cycle)
        return suggestion.model_copy(update={"full_cycle_plan": normalized_plan})

    def _normalize_plan_items(self, items: list[str], direction: str, target_cycle: str = "") -> list[str]:
        formatted = [item.strip() for item in items if item.strip()]
        if 3 <= len(formatted) <= 4 and all(self._is_structured_phase(item) for item in formatted):
            return formatted

        cleaned = [self._phase_source_text(item) for item in items if item.strip()]
        if not cleaned:
            return []

        grouped = self._group_plan_items(cleaned, max_groups=4)
        ranges = self._phase_time_ranges(target_cycle, len(grouped))
        normalized: list[str] = []
        for index, group in enumerate(grouped, start=1):
            merged = self._merge_group(group, direction, index)
            normalized.append(self._format_phase(index, ranges[index - 1], merged, direction))
        return normalized

    def _group_plan_items(self, items: list[str], max_groups: int) -> list[list[str]]:
        if len(items) <= max_groups:
            return [[item] for item in items]

        group_count = max_groups
        size = len(items) // group_count
        remainder = len(items) % group_count
        groups: list[list[str]] = []
        cursor = 0
        for index in range(group_count):
            group_size = size + (1 if index < remainder else 0)
            groups.append(items[cursor : cursor + group_size])
            cursor += group_size
        return groups

    def _merge_group(self, group: list[str], direction: str, index: int) -> str:
        if len(group) == 1:
            item = group[0]
            if self._is_vague_plan_item(item):
                return self._expand_vague_plan_item(item, direction, index)
            return item

        normalized_group = [
            self._expand_vague_plan_item(item, direction, index) if self._is_vague_plan_item(item) else item
            for item in group
        ]
        details = "；".join(normalized_group)
        return (
            f"围绕「{direction}」完成这一阶段的连续子任务：{details}。"
            "这一阶段结束时要形成一份可回看的阶段笔记或对比结论。"
        )

    def _format_phase(self, index: int, time_range: str, body: str, direction: str) -> str:
        goals = self._phase_goals(body)
        execution_steps, outputs = self._phase_details(index, direction)
        return "\n".join(
            [
                f"第 {index} 阶段（{time_range}）",
                "目标：",
                *[f"{item_index}. {goal}。" for item_index, goal in enumerate(goals, start=1)],
                "具体执行计划：",
                *[f"{item_index}. {step}" for item_index, step in enumerate(execution_steps, start=1)],
                "产出：",
                *[f"{item_index}. {output}" for item_index, output in enumerate(outputs, start=1)],
            ]
        )

    def _phase_goals(self, body: str) -> list[str]:
        goals = self._goal_candidates(body)
        return [goal for goal in goals if goal][:3] or ["完成本阶段目标"]

    def _phase_details(self, index: int, direction: str) -> tuple[list[str], list[str]]:
        if index == 1:
            return (
                [
                    "界定研究范围、核心概念与判断标准。",
                    "收集代表性材料，建立关键词、来源与问题之间的索引。",
                    "整理关键问题，形成后续阶段可直接使用的研究框架。",
                ],
                [
                    f"一份「{direction}」概念与问题地图。",
                    "一份按优先级整理的核心材料目录。",
                    "一份需要在后续阶段验证的关键问题清单。",
                ],
            )
        if index == 2:
            return (
                [
                    "选择关键路线、方法或案例，建立统一的比较维度。",
                    "逐项完成材料深读，记录支持证据、反例与适用边界。",
                    "汇总差异并形成阶段判断，标记仍需验证的争议点。",
                ],
                [
                    "一份关键路线、方法或案例的对比矩阵。",
                    "一组带来源的证据卡片与边界说明。",
                    "一份可供下一阶段验证的阶段判断。",
                ],
            )
        if index == 3:
            return (
                [
                    "把前期判断转化为案例拆解、实验或可执行验证任务。",
                    "按统一标准记录过程、结果、偏差与失败原因。",
                    "复盘验证结果，决定保留、修正或放弃哪些路线。",
                ],
                [
                    "一个可复查的案例、实验或实践结果。",
                    "一份问题、偏差与改进项记录。",
                    "一份基于验证结果的路线取舍结论。",
                ],
            )
        return (
            [
                "整合前序阶段的证据、判断与实践结果。",
                "补齐影响最终结论的关键缺口，并完成交叉检查。",
                "形成最终交付物，明确下一周期的延伸方向。",
            ],
            [
                f"一份完整的「{direction}」阶段成果。",
                "一份结论、证据链与局限性说明。",
                "一份下一周期的优先级路线图。",
            ],
        )

    def _phase_source_text(self, item: str) -> str:
        text = self._strip_phase_prefix(item)
        if "目标：" not in text:
            return text
        objective = text.split("目标：", 1)[1]
        for marker in ["具体执行计划：", "子阶段：", "动作：", "产出："]:
            objective = objective.split(marker, 1)[0]
        return "；".join(self._goal_candidates(objective))

    def _goal_candidates(self, text: str) -> list[str]:
        candidates: list[str] = []
        for line in re.split(r"[\n；;。]+", text):
            should_split_list = "连续子任务" in line
            cleaned = self._clean_goal_candidate(line)
            parts = [part.strip() for part in cleaned.split("、")] if should_split_list else [cleaned]
            for part in parts:
                if part and part not in candidates:
                    candidates.append(part)
        return candidates

    def _clean_goal_candidate(self, line: str) -> str:
        value = line.strip().lstrip("- ").strip()
        value = re.sub(r"^\d+[.、]\s*", "", value).strip()
        if "目标：" in value:
            value = value.rsplit("目标：", 1)[1].strip()
        if "连续子任务：" in value:
            value = value.rsplit("连续子任务：", 1)[1].strip()
        value = re.sub(r"^第\s*\d+\s*[-—~～至到]\s*\d+\s*(个月|月|周)\s*[:：]\s*", "", value).strip()
        value = re.sub(r"^第\s*\d+\s*(个月|月|周)\s*[:：]\s*", "", value).strip()
        for marker in ["具体执行计划：", "子阶段：", "动作：", "产出："]:
            value = value.split(marker, 1)[0].strip()
        value = self._strip_phase_prefix(value)
        value = re.sub(r"^第\s*\d+\s*阶段[（(][^）)]*[）)]\s*[:：;；,，]?\s*", "", value).strip()
        return value.strip("。；;，, ")

    def _phase_time_ranges(self, target_cycle: str, count: int) -> list[str]:
        total_months = self._parse_total_months(target_cycle)
        if total_months is not None:
            return self._number_ranges(total_months, count, "个月")

        total_weeks = self._parse_total_weeks(target_cycle)
        if total_weeks is not None:
            return self._number_ranges(total_weeks, count, "周")

        return [f"阶段 {index}/{count}" for index in range(1, count + 1)]

    def _parse_total_months(self, target_cycle: str) -> int | None:
        text = target_cycle.strip()
        if not text:
            return None
        if "半年" in text:
            return 6
        if "一年" in text or "1年" in text:
            return 12
        digits = "".join(ch for ch in text if ch.isdigit())
        if not digits:
            return None
        value = int(digits)
        if "年" in text:
            return max(value * 12, 1)
        if "月" in text or "个月" in text:
            return max(value, 1)
        return None

    def _parse_total_weeks(self, target_cycle: str) -> int | None:
        text = target_cycle.strip()
        digits = "".join(ch for ch in text if ch.isdigit())
        if digits and "周" in text:
            return max(int(digits), 1)
        return None

    def _number_ranges(self, total: int, count: int, unit: str) -> list[str]:
        ranges: list[str] = []
        cursor = 1
        for index in range(count):
            remaining_groups = count - index
            remaining_units = total - cursor + 1
            span = max(remaining_units // remaining_groups, 1)
            end = min(cursor + span - 1, total)
            if cursor == end:
                ranges.append(f"第 {cursor} {unit}")
            else:
                ranges.append(f"第 {cursor}-{end} {unit}")
            cursor = end + 1
        return ranges

    def _strip_phase_prefix(self, item: str) -> str:
        text = item.strip()
        for prefix in ["第 1 阶段：", "第 2 阶段：", "第 3 阶段：", "第 4 阶段：", "第 5 阶段：", "第 6 阶段：", "第 7 阶段：", "第 8 阶段：", "第 9 阶段：", "第 10 阶段：", "第1阶段：", "第2阶段：", "第3阶段：", "第4阶段：", "第5阶段：", "第6阶段：", "第7阶段：", "第8阶段：", "第9阶段：", "第10阶段："]:
            if text.startswith(prefix):
                return text[len(prefix) :].strip()
        return text

    def _is_vague_plan_item(self, item: str) -> bool:
        text = item.strip()
        if len(text) <= 12:
            return True
        vague_tokens = ["等", "等等", "相关", "基础", "入门", "掌握", "了解", "学习", "vista", "dreamer", "world models"]
        lowered = text.lower()
        if any(token in lowered for token in vague_tokens):
            lacks_detail_markers = all(marker not in text for marker in ["，", "。", "；", "：", "、", "并", "完成", "整理", "形成", "输出", "复现", "对比"])
            if lacks_detail_markers:
                return True
        return False

    def _expand_vague_plan_item(self, item: str, direction: str, index: int) -> str:
        topic = self._normalize_vague_topic(item)
        if index == 1:
            return f"围绕「{topic}」补齐 {direction} 所需的基础概念、代表材料和检索关键词，并整理一份阶段地图。"
        if index == 2:
            return f"围绕「{topic}」完成关键方法或路线对比，记录它和 {direction} 的关系、适用边界以及值得继续追的点。"
        if index == 3:
            return f"围绕「{topic}」完成一次复现、案例拆解或实验草稿，把结果写成可展示的阶段输出。"
        return f"围绕「{topic}」把前面阶段的判断落到一个明确产出上，并说明它如何服务 {direction}。"

    def _normalize_vague_topic(self, item: str) -> str:
        topic = item.strip("。；， ")
        lowered = topic.lower()
        if "vista" in lowered:
            return "一条候选世界模型路线"
        if "dreamer" in lowered:
            return "Dreamer 这类世界模型方法"
        if "world models" in lowered:
            return "World Models 方向的核心方法"
        if topic.endswith("等"):
            topic = topic[:-1].strip()
        return topic

    def _is_structured_phase(self, item: str) -> bool:
        if not (
            "目标：" in item
            and "具体执行计划：" in item
            and "产出：" in item
            and "\n1. " in item
            and "（" in item
            and "）" in item
        ):
            return False
        objective = item.split("目标：", 1)[1].split("具体执行计划：", 1)[0]
        if "目标：" in objective or re.search(r"第\s*\d+\s*阶段", objective):
            return False
        goals = self._goal_candidates(objective)
        return (
            bool(goals)
            and all("\n1. " in item.split(marker, 1)[1] for marker in ["目标：", "具体执行计划：", "产出："])
        )

    def _default_context(self) -> UserContext:
        now = datetime.now(timezone.utc)
        profile = PersonalProfile(
            display_name="Demo User",
            goal="建立 SLAM 几何直觉 x 4DGS 动态重建 x 自动驾驶工程经验的差异化能力线，形成可展示的研究/工程证据。",
            background_summary=(
                "硕士导航制导与控制，本科自动化；约 7 年自动驾驶量产高精定位经验，"
                "熟悉 GNSS/IMU 融合、SLAM、位姿估计、HD Map 和车道级定位。"
                "当前希望把既有几何和工程背景迁移到 4DGS / World Model / Driving Video Generation 方向。"
            ),
            current_stage="先完成 StreetGaussian / 4DGS 动态重建证据，再判断是否进入轻量 World Model / driving video generation pipeline。",
            updated_at=now,
        )
        plan = WorkLearningPlan(
            long_term_goal="建立 SLAM 几何直觉 x 4DGS 动态重建 x 自动驾驶工程经验的差异化能力线，形成可展示的研究/工程证据。",
            target_cycle="3 个月",
            full_cycle_plan=[
                "第 1 阶段：补齐 StreetGaussian / 4DGS 动态重建核心论文和 baseline 认知",
                "第 2 阶段：完成 SLAM filtering 与 GT-box 动态分离路线对照，形成实验或笔记证据",
                "第 3 阶段：进入轻量 World Model / driving video generation pipeline，判断 reconstruction 与 generation 路线取舍",
            ],
            weekly_focus="本周聚焦 4DGS / World Model 方向判断：优先读能帮助比较 reconstruction 与 generation 路线的材料。",
            active_tasks=[
                "维护一个可追踪的个人目标",
                "登记一份用户材料或公开材料",
                "完成一次 30 分钟 Deep Dive",
            ],
            next_action="优先选择能推进本周 Deep Dive 闭环的材料。",
            tracking_keywords=["personal agent", "learning workflow", "material source", "execution loop"],
            updated_at=now,
        )
        preferences = UserPreference(
            fields=["AI workflow", "career capability", "self-directed learning"],
            source_preferences=[
                MaterialSourceType.pdf,
                MaterialSourceType.url,
                MaterialSourceType.official_doc,
                MaterialSourceType.arxiv,
            ],
            updated_at=now,
        )
        materials = [
            UserMaterial(
                id="material_demo_primary",
                title="How to turn a reading material into an executable learning session",
                source_type=MaterialSourceType.manual,
                summary="一份通用示例材料，用来展示 Agent 如何把材料摘要、用户计划和时间预算转换成 Deep Dive 工作区。",
                url=None,
                file_path="",
                authors_or_owner=["Orbit Engine Demo"],
                published_date="2026-08-05",
                tags=["Deep Dive", "Learning Workflow", "Agent"],
                related_plan=plan.weekly_focus,
                why_selected="它直接服务本周计划：验证材料选择、阅读目标、打卡和历史记录这一条闭环。",
                fetched_at=now,
            ),
            UserMaterial(
                id="material_demo_public",
                title="Public source fallback: learning workflow design note",
                source_type=MaterialSourceType.public_source,
                summary="当外部平台暂不可用时，系统仍可使用明确标注的 fallback material 完成演示。",
                url=None,
                file_path="",
                authors_or_owner=["Fallback Source"],
                published_date="2026-08-05",
                tags=["Fallback", "Public Source"],
                related_plan=plan.next_action,
                why_selected="它证明 Deep Dive 不依赖单一论文平台，公开网页、文档、PDF 或手动材料都可以进入同一工作流。",
                fetched_at=now,
            ),
        ]
        return UserContext(profile=profile, plan=plan, preferences=preferences, materials=materials)
