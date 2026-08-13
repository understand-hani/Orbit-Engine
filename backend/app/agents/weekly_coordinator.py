from datetime import date, datetime, timezone
from typing import Dict, Optional

from app.core.constants import (
    PRODUCT_RADAR_COMPANIES,
    PRODUCT_RADAR_SIGNAL_TYPES,
    PRODUCT_RADAR_TOPICS,
    RESEARCH_DIRECTION,
    RESEARCH_PROJECT,
    SCHEDULED_TASK_CONFIG,
    TECHNICAL_RADAR_RESEARCH_GROUPS,
    TECHNICAL_RADAR_SIGNAL_TYPES,
    TECHNICAL_RADAR_TOPICS,
    WEEKDAY_FRIDAY,
    WEEKDAY_SATURDAY,
    WEEKDAY_SUNDAY,
)
from app.core.time_utils import week_bounds, weekday_name
from app.schemas.common import SessionMode, SessionStatus, SuggestedAction, TaskType
from app.schemas.completion import CompletionCriterion, CompletionState
from app.schemas.jd_analysis import (
    JDAnalysis,
    JDAnalysisPayload,
    JDInput,
    JDSourceType,
    MatchLevel,
    RoleType,
    TimingRecommendation,
)
from app.schemas.research_feeder import (
    PaperNotes,
    ReadingPack,
    ResearchContext,
    ResearchDayRole,
    ResearchFeederPayload,
)
from app.schemas.session import BaseSession
from app.schemas.tech_radar import RadarDigest, RadarScope, RadarType, TechRadarPayload


class WeeklyCoordinator:
    def create_session(
        self,
        target_date: Optional[date] = None,
        task_type_override: Optional[TaskType] = None,
    ) -> BaseSession:
        day = target_date or date.today()
        config = self._resolve_config(day, task_type_override)
        payload = self._build_payload(day, config)
        now = datetime.now(timezone.utc)

        return BaseSession(
            id=self._session_id(day, config["task_type"]),
            date=day,
            weekday=weekday_name(day),
            task_type=config["task_type"],
            session_mode=config["session_mode"],
            title=config["title"],
            subtitle=config["subtitle"],
            status=SessionStatus.active,
            suggested_action=config["suggested_action"],
            payload_type=config["task_type"],
            payload=payload,
            ai_chat_thread_id=self._chat_thread_id(day, config["task_type"]),
            completion=self._completion_for(config["task_type"]),
            created_at=now,
            updated_at=now,
        )

    def _resolve_config(
        self,
        target_date: date,
        task_type_override: Optional[TaskType] = None,
    ) -> Dict:
        if task_type_override == TaskType.tech_radar:
            return {
                "task_type": TaskType.tech_radar,
                "session_mode": SessionMode.manual,
                "title": "技术雷达",
                "subtitle": "根据用户目标扫描公开行业动态、机构成果、平台与产品信号",
                "suggested_action": SuggestedAction.generate_weekly_radar,
                "radar_type": RadarType.technical_method_radar,
            }

        if task_type_override == TaskType.research_feeder:
            return {
                "task_type": TaskType.research_feeder,
                "session_mode": SessionMode.manual,
                "title": "Deep Dive",
                "subtitle": "围绕一个材料完成深入阅读和小产出",
                "suggested_action": SuggestedAction.generate_reading_pack,
                "research_day_role": ResearchDayRole.select_and_start,
            }

        weekday = target_date.weekday()
        if weekday in SCHEDULED_TASK_CONFIG:
            config = dict(SCHEDULED_TASK_CONFIG[weekday])
            config["session_mode"] = SessionMode.scheduled
            return config

        if weekday == WEEKDAY_SATURDAY:
            return {
                "task_type": TaskType.research_feeder,
                "session_mode": SessionMode.catch_up,
                "title": "研究阅读补做",
                "subtitle": "补做本周未完成的论文阅读与笔记",
                "suggested_action": SuggestedAction.continue_reading,
                "research_day_role": ResearchDayRole.continue_and_archive,
            }

        if weekday == WEEKDAY_SUNDAY:
            return {
                "task_type": TaskType.research_feeder,
                "session_mode": SessionMode.review,
                "title": "本周研究复盘",
                "subtitle": "回看本周材料、打卡和下周重点",
                "suggested_action": SuggestedAction.edit_notes,
                "research_day_role": ResearchDayRole.manual_deep_dive,
            }

        return dict(SCHEDULED_TASK_CONFIG[WEEKDAY_FRIDAY])

    def _build_payload(self, target_date: date, config: Dict):
        task_type = config["task_type"]
        if task_type == TaskType.tech_radar:
            return self._tech_radar_payload(target_date, config["radar_type"])
        if task_type == TaskType.jd_analysis:
            return self._jd_analysis_payload(target_date)
        if task_type == TaskType.research_feeder:
            return self._research_payload(config["research_day_role"])
        raise ValueError(f"Unsupported task type: {task_type}")

    def _tech_radar_payload(self, target_date: date, radar_type: RadarType) -> TechRadarPayload:
        week_start, week_end = week_bounds(target_date)
        if radar_type == RadarType.product_strategy_radar:
            scope = RadarScope(
                topics=PRODUCT_RADAR_TOPICS,
                companies=PRODUCT_RADAR_COMPANIES,
                signal_types=PRODUCT_RADAR_SIGNAL_TYPES,
                exclude=["纯融资新闻", "销量新闻", "营销口号"],
            )
            summary = "等待生成本周产品、功能、路线与法规信号。"
        else:
            scope = RadarScope(
                topics=TECHNICAL_RADAR_TOPICS,
                research_groups=TECHNICAL_RADAR_RESEARCH_GROUPS,
                signal_types=TECHNICAL_RADAR_SIGNAL_TYPES,
                exclude=["纯产品营销", "无技术细节的新闻"],
            )
            summary = "等待生成本周技术方法、论文、开源与 benchmark 信号。"

        return TechRadarPayload(
            radar_type=radar_type,
            scope=scope,
            digest=RadarDigest(
                week_start=week_start,
                week_end=week_end,
                summary=summary,
            ),
        )

    def _jd_analysis_payload(self, target_date: date) -> JDAnalysisPayload:
        now = datetime.now(timezone.utc)
        return JDAnalysisPayload(
            jd_input=JDInput(
                id=f"jd_input_{target_date.isoformat()}",
                source_type=JDSourceType.manual_note,
                user_question="请粘贴或录入一个真实 JD，Agent 将结合结构化简历和学习计划分析。",
                jd_text=(
                    "岗位名称：世界模型研发工程师（自动驾驶仿真方向）\n"
                    "职位描述：\n"
                    "1. 负责基于世界模型（World Model）的自动驾驶仿真场景生成与评测；\n"
                    "2. 使用 3DGS / 4DGS 对真实场景进行重建，构建可控的仿真环境；\n"
                    "3. 基于 PyTorch 实现视频生成模型的训练、评估与调优；\n"
                    "4. 与 SLAM 与重建团队协作，把几何信息融入生成式 pipeline。\n"
                    "任职要求：\n"
                    "1. 有自动驾驶或仿真领域项目经验；\n"
                    "2. 熟悉深度学习训练工程，具备实验纪律与结果记录习惯；\n"
                    "3. 对 reconstruction vs generation 方向有技术判断力。"
                ),
                created_at=now,
            ),
            analysis=JDAnalysis(
                role_type=RoleType.unclear,
                match_level=MatchLevel.medium,
                timing_recommendation=TimingRecommendation.pause_and_prepare,
                overall_recommendation="等待 JD 输入后分析。",
            ),
        )

    def _research_payload(self, research_day_role: ResearchDayRole) -> ResearchFeederPayload:
        if research_day_role == ResearchDayRole.select_and_start:
            current_task = "选择 1 篇主论文和 1 篇候选论文，并开始精读主论文。"
            reading_goal = "明确论文输入、输出、核心方法、证据和是否值得继续。"
        elif research_day_role == ResearchDayRole.continue_and_archive:
            current_task = "继续阅读主论文，完成笔记、AI 讨论和归档。"
            reading_goal = "补齐实验证据、局限性、与个人方向关系和下一步。"
        else:
            current_task = "复盘本周研究阅读，整理可复用素材。"
            reading_goal = "总结本周论文阅读收益，并形成下周阅读判断。"

        return ResearchFeederPayload(
            research_day_role=research_day_role,
            research_context=ResearchContext(
                current_direction=RESEARCH_DIRECTION,
                current_task=current_task,
                week_goal="为 reconstruction vs generation 方向判断提供证据。",
                related_project=RESEARCH_PROJECT,
            ),
            reading_pack=ReadingPack(
                primary_paper_id="pending_primary_paper",
                candidate_paper_id="pending_candidate_paper",
                selection_reason="等待 research feeder agent 根据当前方向选择论文。",
                reading_goal=reading_goal,
            ),
            notes=PaperNotes(),
        )

    def _completion_for(self, task_type: TaskType) -> CompletionState:
        if task_type == TaskType.tech_radar:
            criteria = [
                CompletionCriterion(
                    id="radar_read_signals",
                    description="阅读本次 radar 的主要信号。",
                ),
                CompletionCriterion(
                    id="radar_mark_values",
                    description="标记至少一条 valuable / noise / track_later。",
                ),
            ]
        elif task_type == TaskType.jd_analysis:
            criteria = [
                CompletionCriterion(
                    id="jd_input_added",
                    description="录入或粘贴一个真实 JD / 猎头信息 / 岗位线索。",
                ),
                CompletionCriterion(
                    id="jd_action_confirmed",
                    description="确认至少一个能力提升或简历优化动作。",
                ),
            ]
        else:
            criteria = [
                CompletionCriterion(
                    id="research_reading_progress",
                    description="完成主论文的一个精读段落、关键图或笔记字段。",
                ),
                CompletionCriterion(
                    id="research_next_action",
                    description="确认论文继续/稍后/放弃判断和下一步。",
                ),
            ]
        return CompletionState(criteria=criteria)

    def _session_id(self, target_date: date, task_type: TaskType) -> str:
        return f"session_{target_date.isoformat()}_{task_type.value}"

    def _chat_thread_id(self, target_date: date, task_type: TaskType) -> str:
        return f"chat_{target_date.isoformat()}_{task_type.value}"
