from datetime import date, datetime, timezone

from app.schemas.common import (
    SessionMode,
    SuggestedAction,
    TaskType,
    VisualAsset,
    VisualType,
    VisualUsage,
)
from app.schemas.completion import CompletionCriterion, CompletionItemStatus, CompletionState
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
    Paper,
    ReadingPack,
    ResearchContext,
    ResearchDayRole,
    ResearchFeederPayload,
)
from app.schemas.session import BaseSession
from app.schemas.tech_radar import (
    FeedGenerationMode,
    RadarDigest,
    RadarItem,
    RadarScope,
    RadarType,
    TechRadarPayload,
)


def now():
    return datetime.now(timezone.utc)


def test_schema_smoke():
    visual = VisualAsset(
        id="visual_001",
        type=VisualType.image,
        caption="A product screenshot that explains the signal.",
        source="official",
        usage=VisualUsage.product_screenshot,
    )

    radar_item = RadarItem(
        id="radar_item_001",
        radar_type=RadarType.product_strategy_radar,
        title="Example product update",
        source="official",
        signal_type="功能更新",
        summary="A company updated an ADAS feature.",
        why_it_matters="It shows a product direction signal.",
        visuals=[visual],
    )
    tech_payload = TechRadarPayload(
        radar_type=RadarType.product_strategy_radar,
        scope=RadarScope(topics=["ADAS"], companies=["ExampleCo"]),
        generation_mode=FeedGenerationMode.on_demand,
        digest=RadarDigest(
            week_start=date(2026, 7, 6),
            week_end=date(2026, 7, 12),
            summary="Weekly product strategy radar.",
            items=[radar_item],
        ),
    )

    jd_payload = JDAnalysisPayload(
        jd_input=JDInput(
            id="jd_001",
            source_type=JDSourceType.pasted_text,
            company="ExampleCo",
            role_title="Research Engineer",
            jd_text="Need 3D reconstruction and world-model experience.",
            created_at=now(),
        ),
        analysis=JDAnalysis(
            role_type=RoleType.research_engineer,
            match_level=MatchLevel.medium_high,
            timing_recommendation=TimingRecommendation.build_contact_only,
            overall_recommendation="Build contact only.",
        ),
    )

    paper = Paper(
        id="paper_001",
        title="Example paper",
        summary="A short paper summary.",
        why_selected="It matches this week's reading goal.",
        visuals=[visual],
    )
    research_payload = ResearchFeederPayload(
        research_day_role=ResearchDayRole.select_and_start,
        research_context=ResearchContext(
            current_direction="3DGS / World Model / Driving Video Generation",
            current_task="Understand input-output and training logic.",
            week_goal="Support reconstruction vs generation direction decision.",
        ),
        reading_pack=ReadingPack(
            primary_paper_id="paper_001",
            candidate_paper_id="paper_002",
            selection_reason="Primary paper best matches the week goal.",
            reading_goal="Understand method and evidence.",
        ),
        papers=[paper],
    )

    completion = CompletionState(
        criteria=[
            CompletionCriterion(
                id="criterion_001",
                description="Read at least one selected signal or paper section.",
                status=CompletionItemStatus.met,
            )
        ]
    )

    for task_type, payload, action in [
        (TaskType.tech_radar, tech_payload, SuggestedAction.open_weekly_radar),
        (TaskType.jd_analysis, jd_payload, SuggestedAction.open_analysis_report),
        (TaskType.research_feeder, research_payload, SuggestedAction.open_paper_reader),
    ]:
        session = BaseSession(
            id=f"session_{task_type.value}",
            date=date(2026, 7, 10),
            weekday="friday",
            task_type=task_type,
            session_mode=SessionMode.scheduled,
            title="Smoke session",
            suggested_action=action,
            payload_type=task_type,
            payload=payload,
            ai_chat_thread_id="chat_001",
            completion=completion,
            created_at=now(),
            updated_at=now(),
        )
        assert session.task_type == task_type

