import os
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

from app.config import get_settings
from app.db.migrations import init_db
from app.schemas.common import TaskType
from app.schemas.source import CombinedSearchResponse, SourceItem, SourceItemType, SourceType
from app.schemas.tech_radar import RadarDigest, RadarScope, RadarType, TechRadarPayload
from app.schemas.user_context import PersonalProfile, UserContext, UserPreference, WorkLearningPlan
from app.agents.tech_radar_agent import MockTechRadarAgent, RadarDetailJudgement
from app.services.feed_service import FeedService
from app.services.user_context_service import UserContextService


class StaticSearchService:
    def __init__(self) -> None:
        self.queries = []

    def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        self.queries.append(query)
        items = [
            SourceItem(
                id=f"industry_{index}",
                source=SourceType.web,
                item_type=SourceItemType.article,
                title=f"{query} industry radar source {index}",
                url=f"https://example.com/radar/{index}",
                summary=f"{query} public industry signal {index}",
                tags=["public_web"],
            )
            for index in range(1, 7)
        ]
        return CombinedSearchResponse(
            query=query,
            items=items[:max_results],
            fetched_at=datetime.now(timezone.utc),
        )

    def fetch_web_passages(self, url: str, max_passages: int = 5):
        return [
            f"{url} 原文第一段：某机构发布了面向行业场景的新平台，并说明了产品能力和试点范围。",
            f"{url} 原文第二段：材料提到平台已经在真实业务中完成测试，覆盖数据接入、风险识别和结果回传。",
            f"{url} 原文第三段：报道列出了研发团队、合作机构和后续迭代方向，可用于判断信号来源。",
        ][:max_passages]


class FailingSearchService:
    def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        raise RuntimeError("network unavailable")


class EmptyPassageSearchService:
    def fetch_web_passages(self, url: str, max_passages: int = 5):
        return []


class RaisingPassageSearchService:
    def fetch_web_passages(self, url: str, max_passages: int = 5):
        raise AssertionError("Radar generation should not fetch web passages by default")


def test_saved_tech_radar_sessions_exclude_previous_source_urls():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_generation_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        feed.tech_radar_agent.search_service = StaticSearchService()

        first_empty = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        second_empty = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        assert first_empty.payload.digest.items == []
        assert second_empty.payload.digest.items == []

        first = feed.refresh_tech_radar_session(first_empty.id)
        second = feed.refresh_tech_radar_session(second_empty.id)
        assert first is not None
        assert second is not None

        first_urls = {str(item.url) for item in first.payload.digest.items}
        second_urls = {str(item.url) for item in second.payload.digest.items}

        assert len(first_urls) == 3
        assert len(second_urls) == 3
        assert first_urls.isdisjoint(second_urls)
        assert max(item.relevance_score for item in first.payload.digest.items) == 5
        assert max(item.relevance_score for item in second.payload.digest.items) == 5
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_tech_radar_override_creates_empty_radar_session_on_non_radar_date():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_override_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        session = FeedService().generate_and_save_mock_session(
            date(2026, 8, 12),
            task_type=TaskType.tech_radar,
        )

        assert session.task_type == TaskType.tech_radar
        assert session.payload.digest.items == []
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_tech_radar_uses_user_goal_for_queries_and_relevance():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_user_goal_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        now = datetime.now(timezone.utc)
        UserContextService().save(
            UserContext(
                profile=PersonalProfile(
                    goal="量化交易风控平台",
                    background_summary="关注金融科技行业动态。",
                    current_stage="寻找机构和平台的产品信号。",
                    updated_at=now,
                ),
                plan=WorkLearningPlan(
                    long_term_goal="跟踪量化交易风控平台的行业机会。",
                    weekly_focus="观察证券公司和金融科技平台的风控产品发布。",
                    active_tasks=["记录公开网页中的产品发布和机构动作"],
                    tracking_keywords=["量化交易风控", "证券风控平台"],
                    updated_at=now,
                ),
                preferences=UserPreference(
                    fields=["金融科技", "量化交易"],
                    updated_at=now,
                ),
            )
        )
        feed = FeedService()
        search = StaticSearchService()
        feed.tech_radar_agent.search_service = search

        session = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        refreshed = feed.refresh_tech_radar_session(session.id)

        assert refreshed is not None
        assert len(refreshed.payload.digest.items) == 3
        joined_queries = " ".join(search.queries)
        assert "量化交易风控" in joined_queries
        assert "autonomous driving" not in joined_queries.lower()
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()


def test_radar_relevance_allows_signal_matching_a_specific_goal_term():
    agent = MockTechRadarAgent()
    source_item = SourceItem(
        id="web_001",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="某金融科技公司发布量化交易风控产品",
        url="https://example.com/fintech-risk-product",
        summary="该产品面向证券机构，提供平台化风险管理能力。",
        tags=["public_web"],
    )

    assert agent._is_relevant_source(source_item, ["量化交易风控平台"])


def test_radar_relevance_rejects_generic_industry_news_when_user_has_focus():
    agent = MockTechRadarAgent()
    unrelated_item = SourceItem(
        id="web_003",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="自动化运维任务执行的可追踪性与日志存储",
        url="https://example.com/linux-task-log",
        summary="某公司发布面向 Linux 运维的平台产品。",
        tags=["public_web", "bocha_web"],
    )

    assert not agent._is_relevant_source(unrelated_item, ["4DGS / World Model"])


def test_radar_relevance_uses_generic_fallback_only_without_user_context():
    agent = MockTechRadarAgent()
    source_item = SourceItem(
        id="web_004",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="某研究机构发布新产品",
        url="https://example.com/research-product",
        summary="研究团队公布平台能力更新。",
        tags=["public_web"],
    )

    assert agent._is_relevant_source(source_item, [])


def test_radar_rejects_calls_for_papers_and_journal_homepages_before_selection():
    agent = MockTechRadarAgent()
    call_for_papers = SourceItem(
        id="web_005",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="Foundation Models for Intelligent Control 征稿通知",
        url="https://example.com/cfp",
        summary="学术期刊征稿，欢迎投稿。",
        tags=["public_web"],
    )

    assert agent._is_obvious_radar_noise(call_for_papers)


def test_radar_selection_fills_to_two_related_candidates_without_inflating_score():
    agent = MockTechRadarAgent()
    first = SourceItem(
        id="web_006",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="4DGS driving scene reconstruction update",
        url="https://example.com/4dgs",
        summary="A concrete 4D Gaussian Splatting update for driving scenes.",
    )
    second = SourceItem(
        id="web_007",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="World model evaluation for autonomous driving",
        url="https://example.com/world-model",
        summary="A secondary update relevant to the driving world-model route.",
    )

    selected = agent._fill_minimum_radar_candidates(
        [(first, 5)],
        [first, second],
        ["4DGS", "World Model"],
    )

    assert [item.id for item, _ in selected] == ["web_006", "web_007"]
    assert selected[0][1] == 5
    assert selected[1][1] == 3


def test_radar_uses_distinctive_user_anchors_instead_of_bare_model_terms():
    agent = MockTechRadarAgent()
    anchors = agent._relevance_anchor_terms(["4DGS / World Model", "人工智能"])
    unrelated_llm = SourceItem(
        id="web_008",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="新一代大模型发布",
        url="https://example.com/llm-release",
        summary="通用人工智能助手能力升级。",
    )
    related_world_model = SourceItem(
        id="web_009",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="Driving world model uses 4DGS scene representation",
        url="https://example.com/driving-world-model",
        summary="A concrete 4DGS update for driving-world-model reconstruction.",
    )

    assert "model" not in anchors
    assert not agent._is_relevant_source(unrelated_llm, anchors)
    assert agent._is_relevant_source(related_world_model, anchors)


def test_radar_keeps_llm_material_for_a_user_with_ai_agent_as_direction():
    agent = MockTechRadarAgent()
    anchors = agent._relevance_anchor_terms(["AI Agent workflow"])
    agent_source = SourceItem(
        id="web_010",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="AI Agent workflow product update",
        url="https://example.com/agent-workflow",
        summary="A concrete agent workflow release.",
    )

    assert agent._is_relevant_source(agent_source, anchors)


def test_radar_source_passages_separate_excerpt_and_agent_analysis():
    agent = MockTechRadarAgent(search_service=StaticSearchService())
    source_item = SourceItem(
        id="web_002",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="某金融科技公司发布新一代风控产品",
        url="https://example.com/fintech-risk-product",
        summary="该产品面向证券机构，提供平台化风险管理能力。",
        published_at=datetime(2026, 8, 12, tzinfo=timezone.utc),
        tags=["public_web", "金融科技日报"],
        extra={
            "publisher": "金融科技日报",
            "publisher_url": "https://example.com",
            "agent_summary": "该公司公布了面向证券机构的风控产品更新，当前仅有来源摘要可核对。",
            "agent_why_it_matters": "它与量化交易风控平台方向直接相连，可用于判断产品能力是否覆盖当前计划的风险管理环节。",
            "agent_noise_judgement": "需要核对官网功能说明和真实客户案例，不能仅凭媒体摘要判断产品效果。",
        },
    )

    passages = agent._source_passages(source_item, source_item.summary, ["量化交易风控平台"])

    assert len(passages) >= 3
    assert "原文第一段" in passages[0].excerpt
    assert "Agent" not in passages[0].excerpt
    assert passages[0].analysis
    assert "产品" in passages[0].analysis or "平台" in passages[0].analysis
    # title 改为段落主旨短句，不再是固定编号
    assert passages[0].title != "原文摘录 1"
    assert len(passages[0].title) <= 32
    # 每条 passage 带针对性建议
    assert all(passage.suggestion for passage in passages)
    assert "建议" in passages[0].suggestion


def test_radar_source_passages_empty_when_page_unreadable():
    agent = MockTechRadarAgent(search_service=EmptyPassageSearchService())
    source_item = SourceItem(
        id="web_003",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="某金融科技公司发布新一代风控产品",
        url="https://example.com/fintech-risk-product",
        summary="该产品面向证券机构，提供平台化风险管理能力。",
        published_at=datetime(2026, 8, 12, tzinfo=timezone.utc),
        tags=["public_web", "金融科技日报"],
        extra={
            "publisher": "金融科技日报",
            "publisher_url": "https://example.com",
            "agent_summary": "该公司公布了面向证券机构的风控产品更新，当前仅有来源摘要可核对。",
            "agent_why_it_matters": "它与量化交易风控平台方向直接相连，可用于判断产品能力是否覆盖当前计划的风险管理环节。",
            "agent_noise_judgement": "需要核对官网功能说明和真实客户案例，不能仅凭媒体摘要判断产品效果。",
        },
    )

    passages = agent._source_passages(source_item, source_item.summary, ["量化交易风控平台"])

    assert passages == []


def test_radar_item_marks_metadata_only_when_page_unreadable():
    agent = MockTechRadarAgent(search_service=RaisingPassageSearchService())
    source_item = SourceItem(
        id="web_004",
        source=SourceType.web,
        item_type=SourceItemType.article,
        title="某金融科技公司发布新一代风控产品",
        url="https://example.com/fintech-risk-product",
        summary="该产品面向证券机构，提供平台化风险管理能力。",
        published_at=datetime(2026, 8, 12, tzinfo=timezone.utc),
        tags=["public_web", "金融科技日报"],
        extra={
            "publisher": "金融科技日报",
            "publisher_url": "https://example.com",
            "agent_summary": "该公司公布了面向证券机构的风控产品更新，当前仅有来源摘要可核对。",
            "agent_why_it_matters": "它与量化交易风控平台方向直接相连，可用于判断产品能力是否覆盖当前计划的风险管理环节。",
            "agent_noise_judgement": "需要核对官网功能说明和真实客户案例，不能仅凭媒体摘要判断产品效果。",
        },
    )

    item = agent._radar_item_from_source(
        TechRadarPayload(
            radar_type=RadarType.product_strategy_radar,
            scope=RadarScope(topics=["量化交易风控平台"]),
            digest=RadarDigest(
                week_start=date(2026, 8, 10),
                week_end=date(2026, 8, 16),
                summary="pending",
            ),
        ),
        source_item,
        1,
        ["量化交易风控平台"],
    )

    assert item.source_passages == []
    assert item.evidence_status == "metadata_only"
    assert item.published_at == source_item.published_at
    assert item.relevance_score == 3
    assert item.agent_observation == ""
    assert item.summary == agent._summary_for_source(source_item)
    assert item.why_it_matters == agent._why_source_matters(source_item)
    assert item.marketing_noise == agent._noise_for_source(source_item)


def test_radar_promotes_one_selected_material_to_five_stars():
    agent = MockTechRadarAgent()
    candidates = [
        SourceItem(
            id=f"candidate_{index}",
            source=SourceType.web,
            item_type=SourceItemType.article,
            title=f"Candidate {index}",
            summary="A relevant update.",
        )
        for index in range(3)
    ]

    rated = agent._ensure_five_star_candidate(
        [(candidates[0], 4), (candidates[1], 3), (candidates[2], 4)]
    )

    assert sum(score == 5 for _, score in rated) == 1
    assert rated[0][1] == 5


def test_radar_detail_observation_is_complete_and_within_requested_length():
    observation = "这是一段基于原文事实进行提炼的完整观察，包含事件变化、实质内容、适用边界与需要继续核验的证据。" * 5
    judgement = RadarDetailJudgement(
        observation=observation,
        summary="该来源报告了一项与当前方向直接相关的具体产品或研发进展。",
        why_it_matters="该变化可用于校准当前目标和本周计划中的技术路线优先级。",
        noise_judgement="目前仍需核对一手来源、适用范围和实际验证数据，避免仅凭报道下结论。",
    )

    assert judgement.observation == observation
    assert 200 <= len(judgement.observation) <= 500


def test_tech_radar_refresh_does_not_fallback_to_mock_items():
    original_path = os.environ.get("DATABASE_PATH")
    db_path = Path(tempfile.mkdtemp()) / "infra_radar_no_mock_test.db"
    os.environ["DATABASE_PATH"] = str(db_path)
    get_settings.cache_clear()
    try:
        init_db()
        feed = FeedService()
        feed.tech_radar_agent.search_service = FailingSearchService()

        session = feed.generate_and_save_mock_session(
            date(2026, 8, 11),
            task_type=TaskType.tech_radar,
        )
        refreshed = feed.refresh_tech_radar_session(session.id)

        assert refreshed is not None
        assert refreshed.payload.digest.items == []
        assert "未从公开源检索到" in refreshed.payload.digest.summary
    finally:
        if original_path is None:
            os.environ.pop("DATABASE_PATH", None)
        else:
            os.environ["DATABASE_PATH"] = original_path
        get_settings.cache_clear()
