from datetime import date

from app.agents.weekly_coordinator import WeeklyCoordinator
from app.schemas.common import SessionMode, SuggestedAction, TaskType
from app.schemas.research_feeder import ResearchDayRole
from app.schemas.tech_radar import RadarType


def test_weekday_schedule():
    coordinator = WeeklyCoordinator()

    monday = coordinator.create_session(date(2026, 7, 13))
    assert monday.weekday == "monday"
    assert monday.task_type == TaskType.tech_radar
    assert monday.session_mode == SessionMode.scheduled
    assert monday.payload.radar_type == RadarType.product_strategy_radar

    tuesday = coordinator.create_session(date(2026, 7, 14))
    assert tuesday.weekday == "tuesday"
    assert tuesday.task_type == TaskType.tech_radar
    assert tuesday.payload.radar_type == RadarType.technical_method_radar

    wednesday = coordinator.create_session(date(2026, 7, 15))
    assert wednesday.weekday == "wednesday"
    assert wednesday.task_type == TaskType.jd_analysis
    assert wednesday.suggested_action == SuggestedAction.add_jd_input

    thursday = coordinator.create_session(date(2026, 7, 16))
    assert thursday.weekday == "thursday"
    assert thursday.task_type == TaskType.research_feeder
    assert thursday.payload.research_day_role == ResearchDayRole.select_and_start

    friday = coordinator.create_session(date(2026, 7, 17))
    assert friday.weekday == "friday"
    assert friday.task_type == TaskType.research_feeder
    assert friday.payload.research_day_role == ResearchDayRole.continue_and_archive


def test_weekend_modes_keep_three_task_types():
    coordinator = WeeklyCoordinator()

    saturday = coordinator.create_session(date(2026, 7, 18))
    assert saturday.task_type == TaskType.research_feeder
    assert saturday.session_mode == SessionMode.catch_up

    sunday = coordinator.create_session(date(2026, 7, 19))
    assert sunday.task_type == TaskType.research_feeder
    assert sunday.session_mode == SessionMode.review
    assert sunday.payload.research_day_role == ResearchDayRole.manual_deep_dive
    assert [criterion.id for criterion in sunday.completion.criteria] == [
        "weekly_review_summary",
        "weekly_next_priorities",
    ]


def test_manual_weekly_studio_keeps_review_role_on_any_date():
    session = WeeklyCoordinator().create_session(
        date(2026, 8, 14),
        weekly_studio=True,
    )

    assert session.date == date(2026, 8, 14)
    assert session.session_mode == SessionMode.review
    assert session.title == "Weekly Studio"
    assert session.payload.research_day_role == ResearchDayRole.manual_deep_dive
