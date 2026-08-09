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
            return existing
        return self.repository.save(self._default_context())

    def save(self, context: UserContext) -> UserContext:
        return self.repository.save(context)

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
                return output
            except Exception:
                pass
        return self._fallback_direction_profile(request)

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
        return DirectionProfileSuggestion(
            weekly_focus=f"围绕「{direction}」选择一份能服务 {stage} 的材料，完成一次可归档 Deep Dive。",
            next_action="让 Agent 自动检索候选材料，先确认一份今天最值得读的主材料。",
            active_tasks=[
                "生成 3-5 个候选材料",
                "选择 1 个主材料和 1 个备选材料",
                "完成一次 Deep Dive 并记录关键判断",
            ],
            tracking_keywords=[
                item
                for item in [
                    direction,
                    request.long_term_goal.strip(),
                    stage,
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
