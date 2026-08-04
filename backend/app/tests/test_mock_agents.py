from datetime import date

from app.schemas.common import SuggestedAction, TaskType
from app.schemas.research_feeder import ResearchDayRole
from app.schemas.tech_radar import RadarType
from app.services.feed_service import FeedService


def test_mock_product_radar_session_has_items():
    session = FeedService().generate_mock_session(date(2026, 7, 13))
    assert session.task_type == TaskType.tech_radar
    assert session.suggested_action == SuggestedAction.open_weekly_radar
    assert session.payload.radar_type == RadarType.product_strategy_radar
    assert len(session.payload.digest.items) >= 1
    assert len(session.payload.digest.items[0].visuals) >= 1


def test_mock_technical_radar_session_has_items():
    session = FeedService().generate_mock_session(date(2026, 7, 14))
    assert session.task_type == TaskType.tech_radar
    assert session.payload.radar_type == RadarType.technical_method_radar
    assert len(session.payload.digest.items) >= 1


def test_mock_jd_session_has_analysis_and_resume_suggestion():
    session = FeedService().generate_mock_session(date(2026, 7, 15))
    assert session.task_type == TaskType.jd_analysis
    assert session.suggested_action == SuggestedAction.open_analysis_report
    assert session.payload.analysis.role_type.value == "research_engineer"
    assert len(session.payload.resume_revision_suggestions) == 1
    assert len(session.payload.capability_actions) == 1


def test_mock_research_session_has_primary_and_candidate_papers():
    session = FeedService().generate_mock_session(date(2026, 7, 16))
    assert session.task_type == TaskType.research_feeder
    assert session.suggested_action == SuggestedAction.open_paper_reader
    assert session.payload.research_day_role == ResearchDayRole.select_and_start
    assert len(session.payload.papers) == 2
    assert session.payload.papers[0].pdf_url is not None
    assert session.payload.paper_reader is not None
    assert session.payload.paper_reader.pdf_url is not None
    assert len(session.payload.paper_readers) == 2
    assert session.payload.paper_readers[1].pdf_url is not None
    assert len(session.payload.paper_reader.selected_passages) >= 1
    assert session.payload.paper_reader.sections[0].extracted_text
    assert len(session.payload.paper_reader.sections[0].knowledge_points) >= 1
