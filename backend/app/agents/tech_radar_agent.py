from datetime import datetime, timezone
import re
from typing import List, Optional, Set

from pydantic import BaseModel, Field

from app.config import get_settings
from app.schemas.source import SourceItem, SourceItemType, SourceType
from app.schemas.tech_radar import RadarItem, RadarSourcePassage, RecommendedDepth, TechRadarPayload
from app.schemas.user_context import UserContext
from app.services.llm_service import OpenRouterChatService
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

# These are valid user directions, but are too broad to establish relevance
# when the same user has supplied more distinctive method or plan anchors.
BROAD_DOMAIN_TERMS = {
    "ai",
    "model",
    "world",
    "research",
    "product",
    "platform",
    "company",
    "university",
    "人工智能",
    "大模型",
    "自动驾驶",
    "具身智能",
    "计算机视觉",
    "深度学习",
    "机器学习",
    "研究",
    "产品",
    "平台",
    "公司",
    "大学",
    "研究院",
    "实验室",
}


class RadarSearchPlan(BaseModel):
    """Small, user-grounded search contract produced before a Radar run."""

    queries: List[str] = Field(default_factory=list)
    required_terms: List[str] = Field(default_factory=list)
    excluded_terms: List[str] = Field(default_factory=list)


class RadarCandidateRating(BaseModel):
    id: str
    relevance_score: int = Field(ge=1, le=5)
    agent_observation: str = ""


class RadarCandidateSelection(BaseModel):
    selections: List[RadarCandidateRating] = Field(default_factory=list)


class RadarDetailJudgement(BaseModel):
    summary: str = ""
    why_it_matters: str = ""
    noise_judgement: str = ""


RADAR_SEARCH_PLANNER_PROMPT = """
You plan current-news searches for a personal Signal Radar.

Use only the supplied user context. Return 2 or 3 concise, topic-specific web
search queries plus 2 to 8 terms that a result must contain to be relevant.
The user wants current news, product releases, company/lab/university progress,
not papers or code repositories. Do not substitute generic AI-agent content for
the user's actual domain. Do not invent a new career direction. Include a term
such as 4DGS, StreetGaussian, SLAM, world model, autonomous driving, or another
term that is explicitly present in the provided context when applicable.
""".strip()


RADAR_RESULT_SELECTOR_PROMPT = """
You are the final relevance gate for a personal Signal Radar.

Select 2 or 3 candidate IDs when at least two candidates meet the relevance
threshold. Select only one when there is truly only one qualifying candidate.
Each selected result must directly advance the user's current
technical direction. A weak shared category such as AI, autonomous driving,
university, product, or research is insufficient on its own. Prefer concrete
progress on the user's stated methods, systems, applications, or organisations.

Always reject journal homepages, calls for papers, conference notices, generic
university announcements, and generic industry news. Do not globally reject a
topic category such as LLM, large models, or AI agents: it is relevant when it
is explicitly part of this user's current goal or plan, and irrelevant when it
only shares a broad category with the user's direction.
Return an empty list rather than filling the quota with weakly related results.
For each selected candidate, assign relevance_score using this exact rubric:
- 5: directly changes or validates the current week's technical route, with
  concrete progress on the user's core method/system/application.
- 4: directly concerns a primary target direction, but is not an immediate
  decision or evidence for this week's plan.
- 3: a clearly useful secondary or enabling connection.
- 1-2: broad-field or weakly related; do not select these.
Rate candidates comparatively. Do not assign 5 to every selected result; use
5 sparingly, normally for no more than one result in a run.
For every selected candidate, write agent_observation in concise Chinese,
roughly 100-300 Chinese characters: state the concrete signal, explain its
relationship to the current goal/weekly plan, and name one verification caveat.
Do not repeat the title, use generic filler, or write a long research summary.
Return only JSON matching the supplied schema.
""".strip()


RADAR_DETAIL_JUDGEMENT_PROMPT = """
You write three concise, evidence-bound Chinese judgments for one Signal Radar
detail page. Use only the supplied signal and user direction. Do not invent
facts, experiments, product capabilities, or source verification.

- summary: objectively state what changed or was reported, 60-120 Chinese characters.
- why_it_matters: explain the specific connection to the user's current goal
  and weekly plan, 60-120 Chinese characters; do not give a generic Radar explanation.
- noise_judgement: state the source/claim limitation and the most important
  thing to verify, 60-120 Chinese characters.

Return only JSON matching the supplied schema.
""".strip()


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
        search_plan = self._build_search_plan(user_context, radar_context)
        relevance_anchors = self._relevance_anchor_terms(radar_context)
        items = self._industry_items_from_search(
            payload,
            excluded_source_keys or set(),
            search_plan.queries,
            relevance_anchors,
            search_plan.excluded_terms,
            user_context,
        )
        if items:
            summary = "本轮 Signal Radar 已基于公开网页、新闻/RSS、开源与论文 metadata 生成行业动态信号。"
            top_signals = [items[0].summary]
            follow_up = ["哪条行业动态值得转入 Deep Dive，进一步确认原文、产品/成果边界和与你当前计划的关系？"]
        else:
            summary = "本轮 Signal Radar 未从公开源检索到可用行业动态；请稍后重试，或输入具体主题/URL。"
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

    def generate_detail_judgement(
        self,
        item: RadarItem,
        user_context: Optional[UserContext],
    ) -> RadarItem:
        """Enrich one opened detail without putting copy generation on the Radar refresh path."""
        settings = get_settings()
        if user_context is None or settings.llm_provider.lower() != "openrouter" or not settings.openrouter_api_key:
            return item
        try:
            judgement = OpenRouterChatService().generate_json(
                system_prompt=RADAR_DETAIL_JUDGEMENT_PROMPT,
                user_payload={
                    "user_direction": {
                        "goal": user_context.profile.goal,
                        "current_stage": user_context.profile.current_stage,
                        "weekly_focus": user_context.plan.weekly_focus,
                        "tracking_keywords": user_context.plan.tracking_keywords,
                        "fields": user_context.preferences.fields,
                    },
                    "signal": {
                        "title": item.title,
                        "source": item.source,
                        "summary": item.summary,
                        "technical_substance": item.technical_substance,
                        "source_passages": [passage.excerpt[:500] for passage in item.source_passages[:3]],
                        "evidence_status": item.evidence_status,
                        "published_at": item.published_at.isoformat() if item.published_at else "",
                    },
                },
                output_model=RadarDetailJudgement,
                schema_name="radar_detail_judgement",
            )
        except Exception:
            # Detail copy is optional: keep the existing evidence-bound fallback
            # rather than turning a readable Radar result into an error.
            return item

        return item.model_copy(
            update={
                "summary": self._normalize_agent_text(judgement.summary, item.summary),
                "why_it_matters": self._normalize_agent_text(judgement.why_it_matters, item.why_it_matters),
                "marketing_noise": self._normalize_agent_text(judgement.noise_judgement, item.marketing_noise),
            }
        )

    def _industry_items_from_search(
        self,
        payload: TechRadarPayload,
        excluded_source_keys: Set[str],
        queries: List[str],
        required_terms: List[str],
        excluded_terms: List[str],
        user_context: Optional[UserContext],
    ) -> List[RadarItem]:
        candidates: List[SourceItem] = []
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
                if self._is_obvious_radar_noise(source_item):
                    continue
                if not self._is_relevant_source(source_item, required_terms, excluded_terms):
                    continue
                dedupe_key = self._source_key(source_item)
                if dedupe_key in excluded_source_keys:
                    continue
                if dedupe_key in seen_urls:
                    continue
                seen_urls.add(dedupe_key)
                candidates.append(source_item)
                if len(candidates) >= 18:
                    break
            if len(candidates) >= 18:
                break
        collected = self._select_radar_candidates(candidates, user_context, required_terms)
        return [
            self._radar_item_from_source(payload, item, index, required_terms, relevance_score)
            for index, (item, relevance_score) in enumerate(collected[:RADAR_ITEM_LIMIT], start=1)
        ]

    def _source_key(self, source_item: SourceItem) -> str:
        return str(source_item.url) if source_item.url else f"{source_item.source.value}:{source_item.id}"

    def _is_relevant_source(
        self,
        source_item: SourceItem,
        required_terms: List[str],
        excluded_terms: Optional[List[str]] = None,
    ) -> bool:
        haystack = " ".join(
            [
                source_item.title,
                source_item.summary,
                " ".join(source_item.tags),
                str(source_item.extra.get("publisher", "")),
            ]
        ).lower()
        meaningful_context = self._context_match_terms(required_terms)
        excluded = self._context_match_terms(excluded_terms or [])
        if any(term in haystack for term in excluded):
            return False
        # When the user has supplied a focus, generic words such as "product",
        # "platform" or "company" must not admit unrelated news.  They are only
        # a fallback for a brand-new user with no usable domain context.
        if meaningful_context:
            return any(term in haystack for term in meaningful_context)
        return any(term in haystack for term in GENERIC_INDUSTRY_TERMS)

    def _is_obvious_radar_noise(self, source_item: SourceItem) -> bool:
        text = " ".join([source_item.title, source_item.summary]).lower()
        noise_markers = [
            "征稿",
            "征文",
            "call for papers",
            "cfp",
            "期刊目录",
            "journal homepage",
            "期刊主页",
        ]
        return any(marker in text for marker in noise_markers)

    def _select_radar_candidates(
        self,
        candidates: List[SourceItem],
        user_context: Optional[UserContext],
        required_terms: List[str],
    ) -> List[tuple[SourceItem, int]]:
        if not candidates:
            return []
        settings = get_settings()
        if user_context is None or settings.llm_provider.lower() != "openrouter" or not settings.openrouter_api_key:
            return [
                (item, self._deterministic_relevance_score(item, required_terms))
                for item in candidates[:RADAR_ITEM_LIMIT]
            ]

        candidate_by_id = {item.id: item for item in candidates}
        try:
            selection = OpenRouterChatService().generate_json(
                system_prompt=RADAR_RESULT_SELECTOR_PROMPT,
                user_payload={
                    "user_direction": {
                        "goal": user_context.profile.goal,
                        "current_stage": user_context.profile.current_stage,
                        "weekly_focus": user_context.plan.weekly_focus,
                        "tracking_keywords": user_context.plan.tracking_keywords,
                        "fields": user_context.preferences.fields,
                    },
                    "candidates": [
                        {
                            "id": item.id,
                            "title": item.title,
                            "summary": item.summary[:800],
                            "publisher": item.extra.get("publisher", ""),
                            "published_at": item.published_at.isoformat() if item.published_at else "",
                        }
                        for item in candidates
                    ],
                },
                output_model=RadarCandidateSelection,
                schema_name="radar_candidate_selection",
            )
            selected = [
                (candidate_by_id[item.id], item.relevance_score)
                for item in selection.selections
                if item.id in candidate_by_id and item.relevance_score >= 3
            ]
            for item in selection.selections:
                source_item = candidate_by_id.get(item.id)
                if source_item is not None and item.relevance_score >= 3:
                    source_item.extra["agent_observation"] = self._normalize_agent_observation(
                        item.agent_observation,
                        source_item,
                    )
            return self._fill_minimum_radar_candidates(selected, candidates, required_terms)
        except Exception:
            # Network/model failure should preserve a useful deterministic
            # result rather than breaking the whole Radar session.
            return [
                (item, self._deterministic_relevance_score(item, required_terms))
                for item in candidates[:RADAR_ITEM_LIMIT]
            ]

    def _fill_minimum_radar_candidates(
        self,
        selected: List[tuple[SourceItem, int]],
        candidates: List[SourceItem],
        required_terms: List[str],
    ) -> List[tuple[SourceItem, int]]:
        deduped: List[tuple[SourceItem, int]] = []
        selected_ids = set()
        for item, score in selected:
            if item.id in selected_ids:
                continue
            selected_ids.add(item.id)
            deduped.append((item, max(3, min(score, 5))))
            if len(deduped) >= RADAR_ITEM_LIMIT:
                return deduped

        # The search layer has already applied the user-specific relevance
        # filter. If the model under-selects, retain the best remaining related
        # candidates so a normal Radar card contains at least two signals.
        minimum = min(2, len(candidates))
        for item in candidates:
            if len(deduped) >= minimum:
                break
            if item.id in selected_ids:
                continue
            selected_ids.add(item.id)
            deduped.append((item, self._deterministic_relevance_score(item, required_terms)))
        return deduped[:RADAR_ITEM_LIMIT]

    def _deterministic_relevance_score(self, source_item: SourceItem, required_terms: List[str]) -> int:
        haystack = " ".join([source_item.title, source_item.summary]).lower()
        # This is a fallback only. It deliberately never gives 5 stars because
        # overlapping CJK fragments can make keyword counts look stronger than
        # the real relationship to the user's active plan.
        direct_terms = [
            term.lower().strip()
            for term in required_terms
            if len(term.strip()) >= 3 and term.lower().strip() not in GENERIC_INDUSTRY_TERMS
        ]
        matches = sum(term in haystack for term in self._dedupe_terms(direct_terms))
        return 4 if matches >= 2 else 3

    def _normalize_agent_observation(self, value: str, source_item: SourceItem) -> str:
        compacted = re.sub(r"\s+", " ", value).strip()
        if len(compacted) >= 40:
            return compacted[:300].rstrip()
        fallback = re.sub(r"\s+", " ", source_item.summary).strip() or source_item.title.strip()
        return fallback[:300].rstrip()

    def _normalize_agent_text(self, value: str, fallback: str) -> str:
        compacted = re.sub(r"\s+", " ", value).strip()
        if compacted:
            return compacted[:140].rstrip()
        return re.sub(r"\s+", " ", fallback).strip()[:140].rstrip()

    def _build_search_plan(
        self,
        user_context: Optional[UserContext],
        radar_context: List[str],
    ) -> RadarSearchPlan:
        fallback = self._fallback_search_plan(radar_context)
        settings = get_settings()
        if user_context is None or settings.llm_provider.lower() != "openrouter" or not settings.openrouter_api_key:
            return fallback

        try:
            planned = OpenRouterChatService().generate_json(
                system_prompt=RADAR_SEARCH_PLANNER_PROMPT,
                user_payload={
                    "goal": user_context.profile.goal,
                    "current_stage": user_context.profile.current_stage,
                    "weekly_focus": user_context.plan.weekly_focus,
                    "next_action": user_context.plan.next_action,
                    "tracking_keywords": user_context.plan.tracking_keywords,
                    "fields": user_context.preferences.fields,
                },
                output_model=RadarSearchPlan,
                schema_name="radar_search_plan",
            )
            queries = self._dedupe_terms([value.strip() for value in planned.queries if value.strip()])[:3]
            required_terms = self._dedupe_terms(
                [value.strip() for value in planned.required_terms if value.strip()]
            )[:8]
            if queries and required_terms:
                return RadarSearchPlan(
                    queries=queries,
                    required_terms=required_terms,
                    excluded_terms=self._dedupe_terms(planned.excluded_terms)[:8],
                )
        except Exception:
            pass
        return fallback

    def _fallback_search_plan(self, radar_context: List[str]) -> RadarSearchPlan:
        seeds = self._query_seed_terms(radar_context)
        if not seeds:
            return RadarSearchPlan(
                queries=["technology company product research news"],
                required_terms=[],
            )
        # Search one query per high-priority seed instead of spending all calls
        # on generic rewrites of the first sentence in the profile.
        queries = [f"{seed} news product research update" for seed in seeds[:3]]
        return RadarSearchPlan(
            queries=queries,
            required_terms=self._context_match_terms(radar_context),
        )

    def _context_match_terms(self, radar_context: List[str]) -> List[str]:
        terms: List[str] = []
        for value in radar_context:
            lowered = value.lower().strip()
            if not lowered:
                continue
            terms.append(lowered)
            english_terms = re.findall(r"[a-z0-9][a-z0-9\-/+.]{1,}", lowered)
            terms.extend(term for term in english_terms if term not in BROAD_DOMAIN_TERMS)
            word_tokens = re.findall(r"[a-z0-9]+", lowered)
            # Keep meaningful multi-word directions intact: “world model” and
            # “AI agent” are directions; a bare “model” is not.
            for width in (3, 2):
                terms.extend(
                    " ".join(word_tokens[index : index + width])
                    for index in range(0, len(word_tokens) - width + 1)
                )
            for chunk in re.findall(r"[\u4e00-\u9fff]{2,}", lowered):
                terms.append(chunk)
                if chunk in BROAD_DOMAIN_TERMS:
                    continue
                # Preserve the full user phrase and add domain-sized segments
                # so “量化交易风控平台” can match a related “量化交易风控产品”.
                for size in (4, 3):
                    terms.extend(chunk[index : index + size] for index in range(0, len(chunk) - size + 1))
        stop_terms = {"当前", "目标", "计划", "本周", "材料", "生成", "记录", "观察", "行业", "动态", "平台"}
        return self._dedupe_terms(
            [term for term in terms if len(term) >= 2 and term not in stop_terms]
        )

    def _relevance_anchor_terms(self, radar_context: List[str]) -> List[str]:
        terms = self._context_match_terms(radar_context)
        distinctive = [term for term in terms if term.lower() not in BROAD_DOMAIN_TERMS]
        # A user whose entire declared direction is “LLM” or “AI” must still
        # receive that material. Broad terms become usable only when no more
        # distinctive user-provided anchor exists.
        return distinctive or terms

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
                    user_context.plan.weekly_focus,
                    *user_context.plan.tracking_keywords,
                    *user_context.preferences.fields,
                    user_context.profile.goal,
                    user_context.plan.long_term_goal,
                    user_context.profile.current_stage,
                    user_context.plan.next_action,
                    *user_context.plan.active_tasks,
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
        relevance_score: int = 3,
    ) -> RadarItem:
        source_label = source_item.source.value
        summary = source_item.summary.strip() or "该来源缺少摘要，需要打开原文确认核心内容。"
        signal_type = self._signal_type(source_item)
        title = source_item.title.strip() or f"{source_label} source {index}"
        tags = [source_label, signal_type, *source_item.tags[:4]]
        source_passages = (
            self._source_passages(source_item, summary, radar_context)
            if self._should_fetch_source_passages(source_item)
            else []
        )
        return RadarItem(
            id=f"radar_real_{source_label}_{source_item.id}".replace("/", "_"),
            radar_type=payload.radar_type,
            title=title,
            source=source_label,
            url=source_item.url,
            signal_type=signal_type,
            summary=self._summary_for_source(source_item),
            published_at=source_item.published_at,
            relevance_score=max(1, min(relevance_score, 5)),
            agent_observation=self._normalize_agent_observation(
                str(source_item.extra.get("agent_observation", "")),
                source_item,
            ),
            technical_substance=summary,
            marketing_noise=self._noise_for_source(source_item),
            why_it_matters=self._why_source_matters(source_item),
            evidence_status=self._evidence_status(source_item, source_passages),
            source_passages=source_passages,
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
        page_passages = self._fetch_source_page_passages(source_item)
        if page_passages:
            for index, excerpt in enumerate(page_passages[:5], start=1):
                self._append_source_passage(
                    passages,
                    source_item,
                    title=self._passage_title(excerpt, index),
                    excerpt=excerpt,
                    analysis=self._passage_analysis(source_item, excerpt, radar_context),
                    suggestion=self._passage_suggestion(source_item, excerpt, radar_context),
                    location=f"web page paragraph {index}",
                )
            return passages[:5]

        return []

    def _evidence_status(self, source_item: SourceItem, source_passages: List[RadarSourcePassage]) -> str:
        if source_passages:
            return "excerpt_available"
        if source_item.source in {SourceType.arxiv, SourceType.github} and source_item.summary.strip():
            return "metadata_with_structured_summary"
        return "metadata_only"

    def _fetch_source_page_passages(self, source_item: SourceItem) -> List[str]:
        if not source_item.url:
            return []
        try:
            return self.search_service.fetch_web_passages(str(source_item.url), max_passages=5)
        except Exception:
            return []

    def _should_fetch_source_passages(self, source_item: SourceItem) -> bool:
        return source_item.extra.get("fetch_passages") is True

    def _passage_title(self, excerpt: str, index: int) -> str:
        cleaned = " ".join(excerpt.split())
        if not cleaned:
            return f"关键段落 {index}"
        sentence = re.split(r"[。！？!?]", cleaned)[0].strip()
        if not sentence:
            sentence = cleaned
        if len(sentence) > 30:
            return sentence[:29].rstrip() + "…"
        return sentence

    def _passage_suggestion(
        self,
        source_item: SourceItem,
        excerpt: str,
        radar_context: List[str],
    ) -> str:
        text = " ".join([source_item.title, excerpt]).lower()
        matched_terms = [
            term
            for term in self._display_context_terms(radar_context)
            if term.lower() in text
        ]
        compacted_terms = self._compact_overlapping_terms(matched_terms)
        related = ""
        if compacted_terms:
            related = " 这段与当前方向中的「" + "、".join(compacted_terms[:4]) + "」直接相关，建议优先核对它是否改变当前计划。"

        if self._contains_any(text, ["融资", "股价", "营收", "market share", "funding", "stock", "revenue"]):
            base = "建议：先忽略估值和热度，确认是否有真实产品、成果或技术证据，再决定是否转入 Deep Dive。"
        elif self._contains_any(text, ["发布", "推出", "上线", "product", "launch", "release", "platform"]):
            base = "建议：确认该产品 / 平台动作的边界和可验证来源（官网、文档、示例），值得时转入 Deep Dive 读原文。"
        elif self._contains_any(text, ["大学", "研究院", "实验室", "团队", "university", "institute", "lab", "researchers"]):
            base = "建议：优先确认机构 / 团队来源和发布时间，判断它是否代表研发主体的正式动作。"
        elif self._contains_any(text, ["实验", "测试", "benchmark", "sota", "performance", "dataset", "评估", "指标"]):
            base = "建议：这段包含实验 / 评估证据，转入 Deep Dive 时应优先核对指标、数据集和对比对象。"
        else:
            base = "建议：先打开原文确认它具体解决什么问题、由谁发布、证据是否充分，再决定是否进入本周任务。"
        return base + related

    def _append_source_passage(
        self,
        passages: List[RadarSourcePassage],
        source_item: SourceItem,
        title: str,
        excerpt: str,
        analysis: str,
        suggestion: str,
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
                suggestion=suggestion,
                source_url=source_item.url,
                location=location,
            )
        )

    def _passage_analysis(
        self,
        source_item: SourceItem,
        excerpt: str,
        radar_context: List[str],
    ) -> str:
        text = " ".join([source_item.title, excerpt]).lower()
        matched_terms = [
            term
            for term in self._display_context_terms(radar_context)
            if term.lower() in text
        ]
        relation = ""
        compacted_terms = self._compact_overlapping_terms(matched_terms)
        if compacted_terms:
            relation = "它与当前方向中的 " + "、".join(compacted_terms[:4]) + " 有直接词面关联。"

        if self._contains_any(text, ["发布", "推出", "上线", "product", "launch", "release", "platform"]):
            base = "这段的价值在于它描述了具体产品、平台或能力动作，可用于判断这条 Signal Radar 是否只是新闻标题，还是有明确落地对象。"
        elif self._contains_any(text, ["大学", "研究院", "实验室", "团队", "university", "institute", "lab", "researchers"]):
            base = "这段的价值在于它给出了机构或团队来源，可用于判断信号是否来自研发主体、平台方或二手报道。"
        elif self._contains_any(text, ["实验", "测试", "benchmark", "sota", "performance", "dataset", "评估", "指标"]):
            base = "这段的价值在于它提供了实验、评估或性能证据线索，后续 Deep Dive 应优先确认指标、数据集和对比对象。"
        elif self._contains_any(text, ["融资", "股价", "营收", "market share", "funding", "stock", "revenue"]):
            base = "这段更偏商业或市场信号，需要谨慎判断是否包含真实技术进展，避免把融资、股价或宣传口径当成研发动态。"
        else:
            base = "这段提供了理解该动态的事实背景，后续应继续确认它具体解决什么问题、由谁发布、证据是否充分。"
        return (base + relation).strip()

    def _contains_any(self, text: str, needles: List[str]) -> bool:
        return any(needle.lower() in text for needle in needles)

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
