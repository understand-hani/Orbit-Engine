from datetime import datetime, timezone
import re
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
            self._radar_item_from_source(payload, item, index, radar_context)
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
        meaningful_context = self._context_match_terms(radar_context)
        if not meaningful_context:
            return any(term in haystack for term in GENERIC_INDUSTRY_TERMS)
        return any(term in haystack for term in meaningful_context) or any(
            term in haystack for term in GENERIC_INDUSTRY_TERMS
        )

    def _context_match_terms(self, radar_context: List[str]) -> List[str]:
        terms: List[str] = []
        for value in radar_context:
            lowered = value.lower().strip()
            if not lowered:
                continue
            terms.append(lowered)
            terms.extend(re.findall(r"[a-z0-9][a-z0-9\-/+.]{2,}", lowered))
            for chunk in re.findall(r"[\u4e00-\u9fff]{2,}", lowered):
                if len(chunk) <= 8:
                    terms.append(chunk)
                    continue
                for size in (4, 3):
                    terms.extend(chunk[index : index + size] for index in range(0, len(chunk) - size + 1))
        stop_terms = {"当前", "目标", "计划", "本周", "材料", "生成", "记录", "观察", "行业", "动态", "平台"}
        return self._dedupe_terms(
            [term for term in terms if len(term) >= 2 and term not in stop_terms]
        )

    def _industry_queries(self, payload: TechRadarPayload, radar_context: List[str]) -> List[str]:
        topics = [topic.strip() for topic in payload.scope.topics if topic.strip()]
        companies = [company.strip() for company in payload.scope.companies if company.strip()]
        research_groups = [group.strip() for group in payload.scope.research_groups if group.strip()]
        seeds = self._query_seed_terms(radar_context)[:8] + topics[:3] + companies[:3] + research_groups[:2]
        seeds = self._dedupe_terms(seeds)
        if not seeds:
            seeds = ["AI industry research product release", "technology platform university lab"]
        queries: List[str] = []
        for seed in seeds:
            if self._has_cjk(seed):
                queries.extend(
                    [
                        seed,
                        f"{seed} 发布 产品 研究院 公司",
                        f"{seed} 大学 研究机构 平台 成果",
                        f"{seed} 新闻 行业动态",
                    ]
                )
            else:
                queries.extend(
                    [
                        seed,
                        f"{seed} product release research lab company",
                        f"{seed} university research institute platform breakthrough",
                        f"{seed} industry news public report",
                    ]
                )
        return queries[:6]

    def _query_seed_terms(self, radar_context: List[str]) -> List[str]:
        seeds: List[str] = []
        for value in radar_context:
            cleaned = value.strip()
            if not cleaned:
                continue
            lowered = cleaned.lower()
            if "week " not in lowered and len(cleaned) <= 18:
                seeds.append(cleaned)
        seeds.extend(self._context_match_terms(radar_context))
        return [
            seed
            for seed in self._dedupe_terms(seeds)
            if seed not in GENERIC_INDUSTRY_TERMS and len(seed) >= 2
        ]

    def _has_cjk(self, value: str) -> bool:
        return bool(re.search(r"[\u4e00-\u9fff]", value))

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

    def _radar_item_from_source(
        self,
        payload: TechRadarPayload,
        source_item: SourceItem,
        index: int,
        radar_context: List[str],
    ) -> RadarItem:
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
            source_passages=self._source_passages(source_item, summary, radar_context),
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

    def _source_passages(
        self,
        source_item: SourceItem,
        summary: str,
        radar_context: List[str],
    ) -> List[RadarSourcePassage]:
        passages: List[RadarSourcePassage] = []
        self._append_source_passage(
            passages,
            source_item,
            title="标题信号",
            excerpt=source_item.title,
            analysis=(
                "标题是本条 Radar 的第一层事实入口。Agent 只据此判断它可能涉及产品、机构成果、"
                "平台动作或研究方向变化；是否有实质内容仍需要打开原文确认。"
            ),
            location=f"{source_item.source.value} title",
        )
        self._append_source_passage(
            passages,
            source_item,
            title="摘要摘录",
            excerpt=summary,
            analysis=self._summary_analysis(source_item, summary),
            location=f"{source_item.source.value} description",
        )
        self._append_source_passage(
            passages,
            source_item,
            title="来源与时间",
            excerpt=self._source_metadata_text(source_item),
            analysis=(
                "这段用于判断来源可信度和时效性。优先看发布方是否是官方、机构媒体、行业媒体或代码/论文平台，"
                "以及发布时间是否足够新。"
            ),
            location="source metadata",
        )
        matched_context = self._matched_context_text(source_item, radar_context)
        self._append_source_passage(
            passages,
            source_item,
            title="与当前目标的匹配依据",
            excerpt=matched_context,
            analysis=(
                "这些关键词来自用户方向配置、当前计划或材料偏好，并在标题、摘要或来源标签中命中。"
                "如果命中词很泛，后续应降低优先级；如果命中词对应当前阶段任务，可考虑转入 Deep Dive。"
            ),
            location="radar context match",
        )
        tag_text = self._source_tag_text(source_item)
        self._append_source_passage(
            passages,
            source_item,
            title="来源标签 / 类型线索",
            excerpt=tag_text,
            analysis=self._verification_analysis(source_item),
            location="source tags",
        )
        return passages[:5]

    def _append_source_passage(
        self,
        passages: List[RadarSourcePassage],
        source_item: SourceItem,
        title: str,
        excerpt: str,
        analysis: str,
        location: str,
    ) -> None:
        cleaned = excerpt.strip()
        if not cleaned:
            return
        passage_id = f"{source_item.id}_p{len(passages) + 1}".replace("/", "_")
        passages.append(
            RadarSourcePassage(
                id=passage_id,
                title=title,
                excerpt=cleaned,
                analysis=analysis,
                source_url=source_item.url,
                location=location,
            )
        )

    def _summary_analysis(self, source_item: SourceItem, summary: str) -> str:
        if source_item.source == SourceType.web:
            return (
                "这是公开网页/RSS 摘要，不等同于完整正文。它适合初筛这条动态是否涉及产品发布、机构动作、"
                "研发成果或平台变化；下一步需要打开原文确认细节和证据。"
            )
        if source_item.source == SourceType.arxiv:
            return "这是论文摘要，可用于初步判断问题定义、方法假设和实验对象，但仍需要阅读全文确认贡献与局限。"
        if source_item.source == SourceType.github:
            return "这是仓库描述，可用于判断项目主题和工程入口，但需要进一步检查 README、release、commit 和 issue 活跃度。"
        return "这是来源摘要，可用于初筛材料价值，但不能替代原文阅读。"

    def _matched_context_text(self, source_item: SourceItem, radar_context: List[str]) -> str:
        haystack = " ".join(
            [
                source_item.title,
                source_item.summary,
                " ".join(source_item.tags),
                str(source_item.extra.get("publisher", "")),
            ]
        ).lower()
        matched = [
            term
            for term in self._display_context_terms(radar_context)
            if term.lower() in haystack
        ]
        matched = self._compact_overlapping_terms(matched)
        if matched:
            return "命中用户目标关键词：" + "、".join(matched[:8])
        return "未命中明确用户关键词，但命中了产品 / 平台 / 发布 / 公司 / 大学 / 研究院 / 成果等通用行业动态线索。"

    def _compact_overlapping_terms(self, terms: List[str]) -> List[str]:
        compacted: List[str] = []
        for term in sorted(self._dedupe_terms(terms), key=len, reverse=True):
            if any(term in kept for kept in compacted):
                continue
            compacted.append(term)
        return sorted(compacted, key=lambda value: terms.index(value))

    def _display_context_terms(self, radar_context: List[str]) -> List[str]:
        terms: List[str] = []
        for value in radar_context:
            cleaned = value.strip()
            if not cleaned:
                continue
            if len(cleaned) <= 18 and "week " not in cleaned.lower():
                terms.append(cleaned)
            terms.extend(re.findall(r"[a-z0-9][a-z0-9\-/+.]{2,}", cleaned.lower()))
            terms.extend(re.findall(r"[\u4e00-\u9fff]{2,8}", cleaned))
        stop_terms = {"当前", "目标", "计划", "本周", "材料", "生成", "记录", "观察", "行业", "动态", "平台"}
        return self._dedupe_terms(
            [term for term in terms if len(term) >= 2 and term not in stop_terms]
        )

    def _source_tag_text(self, source_item: SourceItem) -> str:
        tags = [tag for tag in source_item.tags[:8] if tag]
        if not tags:
            return ""
        return "、".join(tags)

    def _verification_analysis(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.web:
            return "打开原文后确认：具体是哪家机构/平台/企业，发布了什么产品、成果或动作，是否有技术细节、时间、场景和证据。"
        if source_item.source == SourceType.arxiv:
            return "打开论文后确认：核心问题、方法差异、实验支撑和局限是否足够清楚，再判断是否进入精读。"
        if source_item.source == SourceType.github:
            return "打开仓库后确认：README、release、demo、benchmark 和维护状态是否足够支撑当前计划。"
        return "打开来源后确认：这条材料是否有明确事实、来源、时间、证据和与当前目标的关系。"

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
            for key in ["publisher", "publisher_url", "stars", "forks", "language", "pdf_url"]:
                value = source_item.extra.get(key)
                if value:
                    details.append(f"{key}={value}")
            if details:
                lines.append("补充信息：" + "，".join(details))
        return "\n".join(lines)
