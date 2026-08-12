from datetime import datetime, timezone
from typing import List, Optional, Set

from app.schemas.source import SourceItem, SourceItemType, SourceType
from app.schemas.tech_radar import RadarItem, RadarSourcePassage, RecommendedDepth, TechRadarPayload
from app.schemas.user_context import UserContext
from app.services.search_service import SearchService


RADAR_ITEM_LIMIT = 3
RADAR_SEARCH_FETCH_LIMIT = 12
GENERIC_INDUSTRY_TERMS = [
    "research",
    "product",
    "platform",
    "release",
    "launch",
    "company",
    "university",
    "institute",
    "lab",
    "startup",
    "open source",
    "breakthrough",
    "研发",
    "产品",
    "平台",
    "发布",
    "上线",
    "公司",
    "大学",
    "研究院",
    "实验室",
    "开源",
    "成果",
]


class MockTechRadarAgent:
    def __init__(self, search_service: Optional[SearchService] = None) -> None:
        self.search_service = search_service or SearchService()

    def generate(
        self,
        payload: TechRadarPayload,
        excluded_source_keys: Optional[Set[str]] = None,
        user_context: Optional[UserContext] = None,
    ) -> TechRadarPayload:
        radar_context = self._radar_context_terms(payload, user_context)
        items = self._industry_items_from_search(payload, excluded_source_keys or set(), radar_context)
        if items:
            summary = "本轮 Radar 已基于公开网页、新闻/RSS、开源与论文 metadata 生成行业动态信号。"
            top_signals = [items[0].summary]
            follow_up = ["哪条行业动态值得转入 Deep Dive，进一步确认原文、产品/成果边界和与你当前计划的关系？"]
        else:
            summary = "本轮 Radar 未从公开源检索到可用行业动态；请稍后重试，或输入具体主题/URL。"
            top_signals = []
            follow_up = ["是否需要换一个更具体的行业主题、机构、公司、平台或产品关键词重新扫描？"]

        return payload.model_copy(
            update={
                "source_refresh_time": datetime.now(timezone.utc),
                "digest": payload.digest.model_copy(
                    update={
                        "summary": summary,
                        "items": items,
                        "top_signals": top_signals,
                        "noise_filtered": ["纯融资新闻", "只有口号、没有技术证据的发布稿"],
                        "follow_up_questions": follow_up,
                    }
                ),
            }
        )

    def _industry_items_from_search(
        self,
        payload: TechRadarPayload,
        excluded_source_keys: Set[str],
        radar_context: List[str],
    ) -> List[RadarItem]:
        queries = self._industry_queries(payload, radar_context)
        collected: List[SourceItem] = []
        seen_urls = set()
        for query in queries:
            try:
                response = self.search_service.search_industry_sources(
                    query,
                    max_results=RADAR_SEARCH_FETCH_LIMIT,
                )
            except Exception:
                continue
            for source_item in response.items:
                if source_item.id.endswith("_search_error") or "error" in source_item.tags:
                    continue
                if not self._is_relevant_source(source_item, radar_context):
                    continue
                dedupe_key = self._source_key(source_item)
                if dedupe_key in excluded_source_keys:
                    continue
                if dedupe_key in seen_urls:
                    continue
                seen_urls.add(dedupe_key)
                collected.append(source_item)
                if len(collected) >= RADAR_ITEM_LIMIT:
                    break
            if len(collected) >= RADAR_ITEM_LIMIT:
                break
        return [
            self._radar_item_from_source(payload, item, index)
            for index, item in enumerate(collected[:RADAR_ITEM_LIMIT], start=1)
        ]

    def _source_key(self, source_item: SourceItem) -> str:
        return str(source_item.url) if source_item.url else f"{source_item.source.value}:{source_item.id}"

    def _is_relevant_source(self, source_item: SourceItem, radar_context: List[str]) -> bool:
        haystack = " ".join(
            [
                source_item.title,
                source_item.summary,
                " ".join(source_item.tags),
                str(source_item.extra.get("publisher", "")),
            ]
        ).lower()
        meaningful_context = [term.lower() for term in radar_context if len(term.strip()) >= 2]
        if not meaningful_context:
            return any(term in haystack for term in GENERIC_INDUSTRY_TERMS)
        return any(term in haystack for term in meaningful_context)

    def _industry_queries(self, payload: TechRadarPayload, radar_context: List[str]) -> List[str]:
        topics = [topic.strip() for topic in payload.scope.topics if topic.strip()]
        companies = [company.strip() for company in payload.scope.companies if company.strip()]
        research_groups = [group.strip() for group in payload.scope.research_groups if group.strip()]
        seeds = radar_context[:5] + topics[:3] + companies[:3] + research_groups[:2]
        seeds = self._dedupe_terms(seeds)
        if not seeds:
            seeds = ["AI industry research product release", "technology platform university lab"]
        queries: List[str] = []
        for seed in seeds:
            queries.extend(
                [
                    f"{seed} product release research lab company",
                    f"{seed} university research institute platform breakthrough",
                    f"{seed} industry news public report",
                ]
            )
        return queries[:6]

    def _radar_context_terms(
        self,
        payload: TechRadarPayload,
        user_context: Optional[UserContext],
    ) -> List[str]:
        terms: List[str] = []
        if user_context is not None:
            terms.extend(
                [
                    user_context.profile.goal,
                    user_context.profile.current_stage,
                    user_context.plan.long_term_goal,
                    user_context.plan.weekly_focus,
                    user_context.plan.next_action,
                    *user_context.plan.active_tasks,
                    *user_context.plan.tracking_keywords,
                    *user_context.preferences.fields,
                ]
            )
        else:
            terms.extend(
                [
                    *payload.scope.topics,
                    *payload.scope.companies,
                    *payload.scope.research_groups,
                    *payload.scope.signal_types,
                ]
            )
        return self._dedupe_terms([term.strip() for term in terms if term.strip()])

    def _dedupe_terms(self, terms: List[str]) -> List[str]:
        deduped: List[str] = []
        seen = set()
        for term in terms:
            key = term.lower()
            if key in seen:
                continue
            seen.add(key)
            deduped.append(term)
        return deduped

    def _radar_item_from_source(self, payload: TechRadarPayload, source_item: SourceItem, index: int) -> RadarItem:
        source_label = source_item.source.value
        summary = source_item.summary.strip() or "该来源缺少摘要，需要打开原文确认核心内容。"
        signal_type = self._signal_type(source_item)
        title = source_item.title.strip() or f"{source_label} source {index}"
        tags = [source_label, signal_type, *source_item.tags[:4]]
        return RadarItem(
            id=f"radar_real_{source_label}_{source_item.id}".replace("/", "_"),
            radar_type=payload.radar_type,
            title=title,
            source=source_label,
            url=source_item.url,
            signal_type=signal_type,
            summary=self._summary_for_source(source_item),
            technical_substance=summary,
            marketing_noise=self._noise_for_source(source_item),
            why_it_matters=self._why_source_matters(source_item),
            source_passages=self._source_passages(source_item, summary),
            visuals=[],
            recommended_depth=self._recommended_depth(source_item),
            tags=tags,
        )

    def _signal_type(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.web:
            publisher = source_item.extra.get("publisher")
            return f"公开网页 / {publisher}" if publisher else "公开网页"
        if source_item.source == SourceType.arxiv or source_item.item_type == SourceItemType.paper:
            return "论文"
        if source_item.source == SourceType.github or source_item.item_type == SourceItemType.repo:
            return "开源项目"
        return "外部材料"

    def _summary_for_source(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.web:
            publisher = source_item.extra.get("publisher")
            source_text = f"（{publisher}）" if publisher else ""
            return f"发现一条公开行业动态{source_text}：{source_item.title}。"
        if source_item.source == SourceType.arxiv:
            return f"发现一篇可作为技术证据的近期论文：{source_item.title}。"
        if source_item.source == SourceType.github:
            stars = source_item.extra.get("stars")
            star_text = f"，stars={stars}" if stars is not None else ""
            return f"发现一个近期更新的开源项目：{source_item.title}{star_text}。"
        return f"发现一条公开外部材料：{source_item.title}。"

    def _why_source_matters(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.web:
            return "公开网页/新闻信号适合判断机构、平台或企业是否出现新产品、新成果、新合作或新研发方向，再决定是否转入 Deep Dive 查原文。"
        if source_item.source == SourceType.arxiv:
            return "论文只是行业动态的技术证据之一，可用于确认方法假设、评价指标和成果是否有实质内容。"
        if source_item.source == SourceType.github:
            return "开源项目信号可用于判断代码复现入口、工程活跃度、数据/评估接口和可实践性。"
        return "外部材料可用于补充当前计划的行业信号和下一步阅读候选。"

    def _noise_for_source(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.web and not source_item.summary.strip():
            return "公开网页摘要缺失，需要打开原文确认是否有实际产品、成果、机构动作或技术细节。"
        if source_item.source == SourceType.github and not source_item.summary.strip():
            return "仓库缺少描述，需打开 README 判断是否只是占位项目。"
        if source_item.source == SourceType.arxiv and not source_item.summary.strip():
            return "论文摘要缺失，需打开 arXiv 页面确认内容。"
        return "仍需检查原文是否有实验、代码、数据或清晰问题定义，避免只凭标题判断。"

    def _recommended_depth(self, source_item: SourceItem) -> RecommendedDepth:
        if source_item.source == SourceType.web:
            return RecommendedDepth.skim
        if source_item.source == SourceType.arxiv:
            return RecommendedDepth.read
        if source_item.source == SourceType.github:
            stars = source_item.extra.get("stars")
            if isinstance(stars, int) and stars >= 100:
                return RecommendedDepth.read
        return RecommendedDepth.skim

    def _source_passages(self, source_item: SourceItem, summary: str) -> List[RadarSourcePassage]:
        passages = [
            RadarSourcePassage(
                id=f"{source_item.id}_p1".replace("/", "_"),
                title="来源摘要",
                excerpt=summary,
                analysis="这是从公开源 metadata 中抽出的核心摘要，用来初筛是否值得打开原文。",
                source_url=source_item.url,
                location=f"{source_item.source.value} metadata",
            ),
            RadarSourcePassage(
                id=f"{source_item.id}_p2".replace("/", "_"),
                title="来源线索",
                excerpt=self._source_metadata_text(source_item),
                analysis="这段用于定位材料类型、发布时间、作者或仓库活跃度，帮助判断是否适合进入本周 Deep Dive。",
                source_url=source_item.url,
                location="source metadata",
            ),
            RadarSourcePassage(
                id=f"{source_item.id}_p3".replace("/", "_"),
                title="Agent 初筛",
                excerpt=self._why_source_matters(source_item),
                analysis="这是 Agent 对该来源和当前 Radar 任务关系的初步判断，后续需要用原文细读验证。",
                source_url=source_item.url,
                location="agent routing",
            ),
        ]
        tag_text = "、".join(source_item.tags[:8])
        if tag_text:
            passages.append(
                RadarSourcePassage(
                    id=f"{source_item.id}_p4".replace("/", "_"),
                    title="主题标签",
                    excerpt=tag_text,
                    analysis="标签用于快速判断它是否落在当前方向的关键词范围内。",
                    source_url=source_item.url,
                    location="source tags",
                )
            )
        return passages[:5]

    def _source_metadata_text(self, source_item: SourceItem) -> str:
        lines = [f"来源：{source_item.source.value}", f"类型：{self._signal_type(source_item)}"]
        if source_item.authors:
            lines.append(f"作者：{'、'.join(source_item.authors[:5])}")
        if source_item.published_at:
            lines.append(f"发布时间：{source_item.published_at.date().isoformat()}")
        if source_item.updated_at:
            lines.append(f"更新时间：{source_item.updated_at.date().isoformat()}")
        if source_item.extra:
            details = []
            for key in ["stars", "forks", "language", "pdf_url"]:
                value = source_item.extra.get(key)
                if value:
                    details.append(f"{key}={value}")
            if details:
                lines.append("补充信息：" + "，".join(details))
        return "\n".join(lines)
