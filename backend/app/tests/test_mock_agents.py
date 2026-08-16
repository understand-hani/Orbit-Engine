from datetime import date
from datetime import datetime, timedelta, timezone
from threading import Barrier

from app.agents.tech_radar_agent import MockTechRadarAgent
from app.agents.research_feeder_agent import ResearchFeederAgent, ResearchSearchPlan
from app.schemas.common import SuggestedAction, TaskType
from app.schemas.research_feeder import ResearchDayRole
from app.schemas.source import CombinedSearchResponse, SourceItem, SourceItemType, SourceSearchResponse, SourceType
from app.schemas.tech_radar import RadarDigest, RadarScope, RadarType, TechRadarPayload
from app.schemas.user_context import PersonalProfile, UserContext, UserPreference, WorkLearningPlan
from app.services.feed_service import FeedService


def test_mock_product_radar_session_has_items():
    session = FeedService().generate_mock_session(date(2026, 7, 13))
    assert session.task_type == TaskType.tech_radar
    assert session.suggested_action == SuggestedAction.open_weekly_radar
    assert session.payload.radar_type == RadarType.product_strategy_radar
    assert len(session.payload.digest.items) >= 1


def test_mock_technical_radar_session_has_items():
    session = FeedService().generate_mock_session(date(2026, 7, 14))
    assert session.task_type == TaskType.tech_radar
    assert session.payload.radar_type == RadarType.technical_method_radar
    assert len(session.payload.digest.items) >= 1


def test_technical_radar_agent_uses_search_results():
    class FakeSearchService:
        def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
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
    assert item.source_passages == []
    assert item.evidence_status == "metadata_with_structured_summary"
    assert "公开网页" in generated.digest.summary


def test_mock_jd_session_has_analysis_and_resume_suggestion():
    session = FeedService().generate_mock_session(date(2026, 7, 15))
    assert session.task_type == TaskType.jd_analysis
    assert session.suggested_action == SuggestedAction.open_analysis_report
    assert session.payload.analysis.role_type.value == "research_engineer"
    assert len(session.payload.resume_revision_suggestions) == 1
    assert len(session.payload.capability_actions) == 1


def test_mock_research_session_has_primary_and_candidate_papers():
    class FakeResearchSearchService:
        def search_arxiv(self, query: str, max_results: int = 5) -> SourceSearchResponse:
            return SourceSearchResponse(
                query=query,
                source=SourceType.arxiv,
                items=[
                    SourceItem(
                        id=f"2608.0000{index}",
                        source=SourceType.arxiv,
                        item_type=SourceItemType.paper,
                        title=f"3DGS World Model for Driving Research {index}",
                        url=f"https://arxiv.org/abs/2608.0000{index}",
                        summary=(
                            f"Public arXiv abstract about 3DGS, world models, driving video generation, "
                            f"and dynamic scene reconstruction {index}."
                        ),
                        authors=[f"Author {index}"],
                        published_at=datetime.now(timezone.utc)
                        - timedelta(days=400 if index == 3 else index),
                        tags=["cs.CV"],
                        extra={"pdf_url": f"https://arxiv.org/pdf/2608.0000{index}"},
                    )
                    for index in range(1, 4)
                ],
                fetched_at=datetime.now(timezone.utc),
            )

    feed = FeedService()
    feed.research_agent = ResearchFeederAgent(search_service=FakeResearchSearchService())
    feed.user_contexts = type("NoUserContextRepository", (), {"get": lambda self: None})()
    session = feed.generate_mock_session(date(2026, 7, 16))
    assert session.task_type == TaskType.research_feeder
    assert session.suggested_action == SuggestedAction.open_paper_reader
    assert session.payload.research_day_role == ResearchDayRole.select_and_start
    assert len(session.payload.papers) == 2
    assert session.payload.papers[0].pdf_url is not None
    assert session.payload.paper_reader is not None
    assert session.payload.paper_reader.pdf_url is not None
    assert len(session.payload.paper_readers) == 2
    assert session.payload.paper_readers[1].pdf_url is not None
    assert session.payload.papers[0].id.startswith("real_arxiv_")
    assert session.payload.papers[0].relevance_score == 5
    assert session.payload.papers[0].published_at is not None
    assert all(paper.relevance_score >= 3 for paper in session.payload.papers)
    assert all(paper.relevance_score <= 4 for paper in session.payload.papers[1:])
    cutoff = datetime.now(timezone.utc) - timedelta(days=366)
    assert all(paper.published_at >= cutoff for paper in session.payload.papers)
    assert session.payload.paper_reader.selected_passages == []
    assert session.payload.paper_reader.key_figures == []
    assert session.payload.paper_reader.sections[0].extracted_text
    assert session.payload.paper_reader.sections[0].knowledge_points == []


def test_deep_dive_web_fallback_accepts_only_arxiv_paper_pages():
    agent = ResearchFeederAgent()
    sources = [
        SourceItem(
            id="journal_home",
            source=SourceType.web,
            item_type=SourceItemType.article,
            title="Journal of Zhejiang University",
            url="https://www.zju.edu.cn/journal",
            summary="Journal introduction.",
        ),
        SourceItem(
            id="news_page",
            source=SourceType.web,
            item_type=SourceItemType.article,
            title="A news report about a paper",
            url="https://news.example.com/paper-report",
            summary="News article.",
        ),
        SourceItem(
            id="bocha_result",
            source=SourceType.web,
            item_type=SourceItemType.article,
            title="A valid arXiv research paper",
            url="https://arxiv.org/abs/2608.12345v1",
            summary="Paper abstract returned by the search fallback.",
        ),
        SourceItem(
            id="classic_arxiv_result",
            source=SourceType.web,
            item_type=SourceItemType.article,
            title="A classic arXiv research paper",
            url="https://arxiv.org/abs/hep-th/9901001",
            summary="Classic paper metadata returned by the search fallback.",
        ),
    ]

    validated = agent._validated_arxiv_sources(sources)

    assert len(validated) == 2
    assert validated[0].source == SourceType.arxiv
    assert validated[0].item_type == SourceItemType.paper
    assert str(validated[0].url) == "https://arxiv.org/abs/2608.12345v1"
    assert validated[0].extra["pdf_url"] == "https://arxiv.org/pdf/2608.12345v1"
    assert validated[1].id == "hep-th/9901001"
    assert str(validated[1].url) == "https://arxiv.org/abs/hep-th/9901001"


def test_deep_dive_uses_personal_direction_and_rejects_old_or_unrelated_papers(monkeypatch):
    now = datetime.now(timezone.utc)
    context = UserContext(
        profile=PersonalProfile(
            goal="用 StreetGaussian 和 4DGS 做自动驾驶动态场景重建",
            current_stage="验证动态场景重建技术路线",
            updated_at=now,
        ),
        plan=WorkLearningPlan(
            long_term_goal="建立可用于自动驾驶仿真的动态场景重建系统",
            weekly_focus="比较 StreetGaussian 与 4DGS 的动态建模路线",
            active_tasks=["确认动态高斯表示和时序一致性方案"],
            next_action="精读一篇直接支持当前路线的论文",
            tracking_keywords=["StreetGaussian", "4DGS", "dynamic scene reconstruction"],
            updated_at=now,
        ),
        preferences=UserPreference(
            fields=["3D Gaussian Splatting", "autonomous driving reconstruction"],
            updated_at=now,
        ),
    )

    class PersonalDirectionSearchService:
        def __init__(self) -> None:
            self.arxiv_calls = 0
            self.web_calls = 0
            self.queries = []
            self.search_barrier = Barrier(2)

        def search_arxiv(self, query: str, max_results: int = 5) -> SourceSearchResponse:
            self.arxiv_calls += 1
            self.queries.append(query)
            self.search_barrier.wait(timeout=1)
            return SourceSearchResponse(
                query=query,
                source=SourceType.arxiv,
                items=[
                    SourceItem(
                        id="2608.01001",
                        source=SourceType.arxiv,
                        item_type=SourceItemType.paper,
                        title="StreetGaussian and 4DGS for Dynamic Driving Scenes",
                        url="https://arxiv.org/abs/2608.01001",
                        summary="Dynamic scene reconstruction for autonomous driving.",
                        published_at=now - timedelta(days=10),
                    ),
                    SourceItem(
                        id="2607.01002",
                        source=SourceType.arxiv,
                        item_type=SourceItemType.paper,
                        title="4DGS Dynamic Scene Reconstruction with Temporal Consistency",
                        url="https://arxiv.org/abs/2607.01002",
                        summary="A secondary route for driving reconstruction.",
                        published_at=now - timedelta(days=30),
                    ),
                    SourceItem(
                        id="2608.01003",
                        source=SourceType.arxiv,
                        item_type=SourceItemType.paper,
                        title="General Language Agent Benchmark",
                        url="https://arxiv.org/abs/2608.01003",
                        summary="A benchmark for language agents.",
                        published_at=now - timedelta(days=5),
                    ),
                    SourceItem(
                        id="2501.01004",
                        source=SourceType.arxiv,
                        item_type=SourceItemType.paper,
                        title="StreetGaussian and 4DGS for Dynamic Driving Scenes",
                        url="https://arxiv.org/abs/2501.01004",
                        summary="An old but relevant dynamic reconstruction paper.",
                        published_at=now - timedelta(days=400),
                    ),
                ],
                fetched_at=now,
            )

        def search_public_web(
            self,
            query: str,
            max_results: int = 5,
            freshness: str = "oneMonth",
        ) -> SourceSearchResponse:
            self.web_calls += 1
            self.search_barrier.wait(timeout=1)
            return SourceSearchResponse(
                query=query,
                source=SourceType.web,
                items=[],
                fetched_at=now,
            )

    class MockSettings:
        llm_provider = "mock"
        openrouter_api_key = None

    monkeypatch.setattr("app.agents.research_feeder_agent.get_settings", lambda: MockSettings())
    payload = FeedService().preview_session(
        date(2026, 8, 15),
        task_type=TaskType.research_feeder,
    ).payload
    search_service = PersonalDirectionSearchService()
    generated = ResearchFeederAgent(search_service=search_service).generate(
        payload,
        user_context=context,
    )

    assert search_service.arxiv_calls == 1
    assert search_service.web_calls == 1
    assert " OR " in search_service.queries[0]
    assert search_service.queries[0].count('all:"') >= 2
    assert len(generated.papers) == 2
    assert [paper.relevance_score for paper in generated.papers] == [5, 4]
    assert generated.reading_pack.primary_paper_id == generated.papers[0].id
    assert all(paper.published_at and paper.published_at >= now - timedelta(days=366) for paper in generated.papers)
    assert all("Language Agent" not in paper.title for paper in generated.papers)


def test_missing_manual_deep_dive_is_recovered_without_duplicate_material_generation():
    class MemorySessionRepository:
        def __init__(self) -> None:
            self.saved = None

        def get_by_id(self, session_id: str):
            return self.saved if self.saved and self.saved.id == session_id else None

        def get_by_date_and_task(self, date_value: str, task_type: str):
            return []

        def save(self, session):
            self.saved = session
            return session

    class CountingResearchAgent:
        def __init__(self) -> None:
            self.calls = 0

        def generate(self, payload, user_context=None, query: str = ""):
            self.calls += 1
            return payload

    feed = FeedService()
    feed.sessions = MemorySessionRepository()
    feed.research_agent = CountingResearchAgent()

    session = feed.refresh_research_materials(
        "session_2026-08-16_research_feeder_manual",
        query="StreetGaussian 4DGS",
    )

    assert session is not None
    assert session.id == "session_2026-08-16_research_feeder_manual"
    assert feed.research_agent.calls == 1


def test_manual_deep_dive_id_does_not_collide_with_sunday_weekly_studio():
    feed = FeedService()
    sunday = date(2026, 8, 16)

    scheduled = feed.preview_session(sunday)
    manual = feed.preview_session(
        sunday,
        task_type=TaskType.research_feeder,
        manual_workspace=True,
    )

    assert scheduled.payload.research_day_role == ResearchDayRole.manual_deep_dive
    assert manual.payload.research_day_role == ResearchDayRole.select_and_start
    assert scheduled.id == "session_2026-08-16_research_feeder"
    assert manual.id == "session_2026-08-16_research_feeder_manual"
    assert scheduled.id != manual.id


def test_manual_deep_dive_create_persists_multiple_empty_workspaces():
    class MemorySessionRepository:
        def __init__(self) -> None:
            self.items = {}

        def get_by_id(self, session_id: str):
            return self.items.get(session_id)

        def get_by_date_and_task(self, date_value: str, task_type: str):
            return [
                item
                for item in self.items.values()
                if item.date.isoformat() == date_value and item.task_type.value == task_type
            ]

        def save(self, session):
            self.items[session.id] = session
            return session

    class SearchMustNotRun:
        def generate(self, *args, **kwargs):
            raise AssertionError("creating a Manual card must not start paper search")

    feed = FeedService()
    feed.sessions = MemorySessionRepository()
    feed.research_agent = SearchMustNotRun()
    sunday = date(2026, 8, 16)

    first = feed.generate_and_save_mock_session(
        sunday,
        task_type=TaskType.research_feeder,
        manual_workspace=True,
    )
    second = feed.generate_and_save_mock_session(
        sunday,
        task_type=TaskType.research_feeder,
        manual_workspace=True,
    )

    assert first.id != second.id
    assert first.title == "Deep Dive-2026/08/16-No.1"
    assert second.title == "Deep Dive-2026/08/16-No.2"
    assert len(feed.sessions.get_by_date_and_task("2026-08-16", "research_feeder")) == 2


def test_deep_dive_search_anchors_keep_phrases_and_drop_generic_fragments():
    agent = ResearchFeederAgent()

    anchors = agent._meaningful_terms(
        ["World Models", "World", "Models", "Autonomous Driving", "Driving"]
    )

    assert anchors == ["world models", "autonomous driving"]


def test_deep_dive_five_star_requires_specific_route_coverage():
    agent = ResearchFeederAgent()
    terms = [
        "world models",
        "auto driving world model",
        "driving scene generation",
    ]
    now = datetime.now(timezone.utc)
    generic = SourceItem(
        id="generic",
        source=SourceType.arxiv,
        item_type=SourceItemType.paper,
        title="A Survey of World Models",
        url="https://arxiv.org/abs/2608.10001",
        summary="A general survey of world models across many domains.",
        published_at=now,
    )
    specific = SourceItem(
        id="specific",
        source=SourceType.arxiv,
        item_type=SourceItemType.paper,
        title="Counterfactual Prediction with Driving World Models",
        url="https://arxiv.org/abs/2608.10002",
        summary="World models for autonomous driving prediction.",
        published_at=now,
    )

    assert agent._deterministic_relevance_score(generic, terms) == 4
    assert agent._deterministic_relevance_score(specific, terms) == 5


def test_deep_dive_query_prefers_specific_routes_over_broad_field():
    agent = ResearchFeederAgent()
    plan = ResearchSearchPlan(
        queries=["World Models", "Auto Driving World Model", "Driving Scene Generation"],
        required_terms=[
            "world models",
            "auto driving world model",
            "driving scene generation",
            "model-based rl for driving",
            "autonomous driving",
        ],
    )

    arxiv_query = agent._combined_arxiv_query(plan)
    web_query = agent._combined_web_query(plan)

    assert 'all:"world models"' not in arxiv_query
    assert '"world models"' not in web_query
    assert "auto driving world model" in arxiv_query
    assert "driving scene generation" in web_query
