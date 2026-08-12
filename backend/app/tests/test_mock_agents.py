from datetime import date
from datetime import datetime, timezone

from app.agents.tech_radar_agent import MockTechRadarAgent
from app.schemas.common import SuggestedAction, TaskType
from app.schemas.research_feeder import ResearchDayRole
from app.schemas.source import CombinedSearchResponse, SourceItem, SourceItemType, SourceType
from app.schemas.tech_radar import RadarDigest, RadarScope, RadarType, TechRadarPayload
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


def test_technical_radar_agent_uses_search_results():
    class FakeSearchService:
        def search_technical_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
            return CombinedSearchResponse(
                query=query,
                items=[
                    SourceItem(
                        id="2501.00001",
                        source=SourceType.arxiv,
                        item_type=SourceItemType.paper,
                        title="Driving World Model Test",
                        url="https://arxiv.org/abs/2501.00001",
                        summary="A test paper about action-conditioned driving video generation.",
                        authors=["A. Researcher"],
                        published_at=datetime(2026, 8, 1, tzinfo=timezone.utc),
                        tags=["cs.CV", "world-model"],
                        extra={"pdf_url": "https://arxiv.org/pdf/2501.00001"},
                    )
                ],
                fetched_at=datetime.now(timezone.utc),
            )

    payload = TechRadarPayload(
        radar_type=RadarType.technical_method_radar,
        scope=RadarScope(topics=["driving world model"]),
        digest=RadarDigest(
            week_start=date(2026, 8, 10),
            week_end=date(2026, 8, 16),
            summary="pending",
        ),
    )

    generated = MockTechRadarAgent(search_service=FakeSearchService()).generate(payload)
    item = generated.digest.items[0]
    assert item.source == "arxiv"
    assert item.title == "Driving World Model Test"
    assert item.url is not None
    assert len(item.source_passages) >= 3
    assert "公开源" in generated.digest.summary


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
