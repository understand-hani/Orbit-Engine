import re
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime, timedelta, timezone
from math import ceil
from time import monotonic
from typing import List, Optional
from urllib.parse import urlparse

from pydantic import BaseModel, Field

from app.config import get_settings
from app.schemas.research_feeder import (
    ArchivePlan,
    Paper,
    PaperNotes,
    PaperReader,
    ReadingPack,
    ReadingSection,
    ReadMode,
    ResearchDayRole,
    ResearchFeederPayload,
)
from app.schemas.source import SourceItem, SourceItemType, SourceType
from app.schemas.user_context import UserContext
from app.services.llm_service import OpenRouterChatService
from app.services.search_service import SearchService


RESEARCH_ITEM_LIMIT = 3
RESEARCH_SEARCH_FETCH_LIMIT = 16
RESEARCH_FRESHNESS_DAYS = 366
RESEARCH_MIN_SCORE = 3
RESEARCH_PRIMARY_SCORE = 5
RESEARCH_LLM_TIMEOUT_SEC = 6.0
RESEARCH_SOURCE_DEADLINE_SEC = 12.0
RESEARCH_BROAD_TERMS = {
    "ai",
    "artificial intelligence",
    "agent",
    "agents",
    "model",
    "models",
    "world",
    "research",
    "paper",
    "auto",
    "autonomous",
    "driving",
    "video",
    "generation",
    "scene",
    "人工智能",
    "大模型",
    "模型",
    "研究",
    "论文",
    "计算机视觉",
    "机器学习",
    "深度学习",
}


class ResearchSearchPlan(BaseModel):
    queries: List[str] = Field(default_factory=list)
    required_terms: List[str] = Field(default_factory=list)


class ResearchCandidateRating(BaseModel):
    id: str
    relevance_score: int = Field(ge=1, le=5)


class ResearchCandidateSelection(BaseModel):
    selections: List[ResearchCandidateRating] = Field(default_factory=list)


RESEARCH_RESULT_SELECTOR_PROMPT = """
You are the final relevance gate for a personal arXiv Deep Dive.

Use the complete user direction and active plan, not merely a shared broad field.
Consider only papers published within the supplied one-year window. Select up to
3 papers and assign relevance_score using this exact rubric:
- 5: directly supports, challenges, or changes the user's core technical route
  or current-week task; its title/abstract contains concrete core method,
  system, application, or evaluation anchors from the user's plan.
- 4: directly concerns a primary target direction, but is not immediate evidence
  for the current task or technical decision.
- 3: a clearly useful enabling or secondary connection.
- 1-2: broad-field similarity or weak connection; do not select it.

Do not manufacture a 5-star paper just to fill the primary slot. A paper sharing
only AI, model, agent, autonomous driving, computer vision, or another broad
category is not enough. Return an empty selection when none qualifies. If a
genuine 5-star paper exists, place it first. Return only candidate IDs and scores
as JSON matching the supplied schema.
""".strip()


class ResearchFeederAgent:
    """Build a Deep Dive pack from real public-source metadata.

    The agent never invents paper passages, figures, authors, or results.  When
    only search metadata is available, the reader exposes that metadata as such.
    """

    def __init__(self, search_service: Optional[SearchService] = None) -> None:
        self.search_service = search_service or SearchService()

    def generate(
        self,
        payload: ResearchFeederPayload,
        user_context: Optional[UserContext] = None,
        query: str = "",
    ) -> ResearchFeederPayload:
        if payload.research_day_role == ResearchDayRole.manual_deep_dive:
            return payload

        search_plan = self._build_search_plan(payload, user_context, query)
        rated_sources = self._search_sources(search_plan, payload, user_context)
        papers = [
            self._paper_from_source(item, search_plan.required_terms, score)
            for item, score in rated_sources[:RESEARCH_ITEM_LIMIT]
        ]
        if not papers or papers[0].relevance_score != RESEARCH_PRIMARY_SCORE:
            return payload.model_copy(
                update={
                    "reading_pack": payload.reading_pack.model_copy(
                        update={
                            "primary_paper_id": "pending_primary_paper",
                            "candidate_paper_id": None,
                            "selection_reason": (
                                "近一年内未检索到与当前个人方向和计划达到 5 星关联度的 arXiv 主论文；"
                                "未使用宽泛领域论文凑数，请稍后重试或输入更具体的技术主题。"
                            ),
                        }
                    ),
                    "papers": [],
                    "paper_reader": None,
                    "paper_readers": [],
                    "notes": PaperNotes(),
                    "archive_plan": None,
                }
            )

        readers = [
            self._reader_from_source(paper, source)
            for paper, (source, _) in zip(papers, rated_sources)
        ]
        primary = papers[0]
        candidate = papers[1] if len(papers) > 1 else None
        return payload.model_copy(
            update={
                "reading_pack": ReadingPack(
                    primary_paper_id=primary.id,
                    candidate_paper_id=candidate.id if candidate else None,
                    selection_reason=(
                        "主论文与当前目标、领域偏好和本周计划达到 5 星关联度；"
                        "其余候选按同一标准排序，且均为近一年 arXiv 论文。"
                    ),
                    reading_goal=payload.reading_pack.reading_goal,
                ),
                "papers": papers,
                "paper_reader": readers[0],
                "paper_readers": readers,
                "notes": PaperNotes(),
                "archive_plan": ArchivePlan(
                    target_archive=["research_note"],
                    tags=search_plan.required_terms[:6],
                ),
            }
        )

    def _search_sources(
        self,
        plan: ResearchSearchPlan,
        payload: ResearchFeederPayload,
        user_context: Optional[UserContext],
    ) -> List[tuple[SourceItem, int]]:
        candidates: List[SourceItem] = []
        seen_ids = set()
        # Keep one network call, but search several distinctive anchors with OR.
        # Wrapping an entire planner sentence as one quoted arXiv phrase makes
        # recall collapse because the abstract must contain that exact sentence.
        arxiv_query = self._combined_arxiv_query(plan)
        web_query = self._combined_web_query(plan)
        # The remote Mac may reach arXiv slowly while Bocha remains available.
        # Run both independent transports together so one timeout does not delay
        # the other by another full source-timeout window.
        executor = ThreadPoolExecutor(max_workers=2)
        arxiv_future = executor.submit(self._search_arxiv_items, arxiv_query)
        web_future = executor.submit(self._search_web_items, web_query)
        started_at = monotonic()
        done, pending = wait(
            {arxiv_future, web_future},
            timeout=RESEARCH_SOURCE_DEADLINE_SEC,
            return_when=FIRST_COMPLETED,
        )
        arxiv_items = self._completed_source_items(arxiv_future, done)
        web_items = self._completed_source_items(web_future, done)
        if pending and not self._has_sufficient_source_items(
            [*arxiv_items, *web_items],
            plan.required_terms,
        ):
            remaining = max(0.0, RESEARCH_SOURCE_DEADLINE_SEC - (monotonic() - started_at))
            additional_done, pending = wait(pending, timeout=remaining)
            done.update(additional_done)
            arxiv_items = self._completed_source_items(arxiv_future, done)
            web_items = self._completed_source_items(web_future, done)
        for future in pending:
            future.cancel()
        # Do not let a transport that ignores its socket timeout hold the API
        # response open. Running requests may finish in the background, but the
        # current material-generation request observes the explicit deadline.
        executor.shutdown(wait=False, cancel_futures=True)

        self._append_research_candidates(candidates, seen_ids, arxiv_items, plan.required_terms)
        self._append_research_candidates(candidates, seen_ids, web_items, plan.required_terms)

        return self._select_research_candidates(candidates, payload, user_context, plan.required_terms)

    def _search_arxiv_items(self, query: str) -> List[SourceItem]:
        return self.search_service.search_arxiv(
            query,
            max_results=RESEARCH_SEARCH_FETCH_LIMIT,
        ).items

    def _search_web_items(self, query: str) -> List[SourceItem]:
        return self.search_service.search_public_web(
            query,
            max_results=RESEARCH_SEARCH_FETCH_LIMIT,
            freshness="oneYear",
        ).items

    def _completed_source_items(self, future, done: set) -> List[SourceItem]:
        if future not in done:
            return []
        try:
            return future.result()
        except Exception:
            return []

    def _has_sufficient_source_items(
        self,
        items: List[SourceItem],
        required_terms: List[str],
    ) -> bool:
        eligible = [
            item
            for item in self._validated_arxiv_sources(items)
            if self._is_recent(item)
            and self._deterministic_relevance_score(item, required_terms) >= RESEARCH_MIN_SCORE
        ]
        return len(eligible) >= 2 and any(
            self._deterministic_relevance_score(item, required_terms) == RESEARCH_PRIMARY_SCORE
            for item in eligible
        )

    def _combined_arxiv_query(self, plan: ResearchSearchPlan) -> str:
        anchors = self._specific_search_anchors(plan)
        escaped = [term.replace('"', "").strip() for term in anchors if term.strip()]
        return " OR ".join(f'all:"{term}"' for term in escaped) or 'all:"computer vision"'

    def _combined_web_query(self, plan: ResearchSearchPlan) -> str:
        queries = [query.replace('"', "").strip() for query in self._specific_search_anchors(plan)]
        joined = " OR ".join(f'"{query}"' for query in queries)
        return f"site:arxiv.org/abs ({joined})"

    def _specific_search_anchors(self, plan: ResearchSearchPlan) -> List[str]:
        anchors = plan.required_terms or plan.queries
        ranked = sorted(
            enumerate(anchors),
            key=lambda pair: (-len(self._normalized_anchor_tokens(pair[1])), pair[0]),
        )
        specific = [
            value
            for _, value in ranked
            if len(self._normalized_anchor_tokens(value)) >= 3
        ]
        # When concrete route/application phrases exist, broad two-word fields
        # such as "World Models" must not dominate newest-first recall.
        return (specific or [value for _, value in ranked])[:6]

    def _append_research_candidates(
        self,
        candidates: List[SourceItem],
        seen_ids: set,
        items: List[SourceItem],
        required_terms: List[str],
    ) -> None:
        for item in self._validated_arxiv_sources(items):
            if item.id in seen_ids or not self._is_recent(item):
                continue
            if self._deterministic_relevance_score(item, required_terms) < RESEARCH_MIN_SCORE:
                continue
            seen_ids.add(item.id)
            candidates.append(item)

    def _validated_arxiv_sources(self, items: List[SourceItem]) -> List[SourceItem]:
        validated: List[SourceItem] = []
        seen_ids = set()
        for item in items:
            arxiv_id = self._arxiv_id(item)
            if not arxiv_id or arxiv_id in seen_ids:
                continue
            seen_ids.add(arxiv_id)
            canonical_url = f"https://arxiv.org/abs/{arxiv_id}"
            extra = dict(item.extra)
            extra["pdf_url"] = f"https://arxiv.org/pdf/{arxiv_id}"
            validated.append(
                item.model_copy(
                    update={
                        "id": arxiv_id,
                        "source": SourceType.arxiv,
                        "item_type": SourceItemType.paper,
                        "url": canonical_url,
                        "extra": extra,
                        "tags": ["arxiv", *[tag for tag in item.tags if tag != "public_web"]],
                    }
                )
            )
        return validated

    def _arxiv_id(self, item: SourceItem) -> str:
        if not item.url:
            return ""
        parsed = urlparse(str(item.url))
        host = (parsed.hostname or "").lower()
        if host not in {"arxiv.org", "www.arxiv.org", "export.arxiv.org"}:
            return ""
        prefix = "/abs/"
        if not parsed.path.startswith(prefix):
            return ""
        return parsed.path[len(prefix) :].strip("/")

    def _is_recent(self, item: SourceItem) -> bool:
        published = item.published_at or item.updated_at
        if published is None:
            return False
        if published.tzinfo is None:
            published = published.replace(tzinfo=timezone.utc)
        cutoff = datetime.now(timezone.utc) - timedelta(days=RESEARCH_FRESHNESS_DAYS)
        return published >= cutoff

    def _select_research_candidates(
        self,
        candidates: List[SourceItem],
        payload: ResearchFeederPayload,
        user_context: Optional[UserContext],
        required_terms: List[str],
    ) -> List[tuple[SourceItem, int]]:
        if not candidates:
            return []
        settings = get_settings()
        if user_context is None or settings.llm_provider.lower() != "openrouter" or not settings.openrouter_api_key:
            rated = [
                (item, self._deterministic_relevance_score(item, required_terms))
                for item in candidates
            ]
        else:
            candidate_by_id = {item.id: item for item in candidates}
            deterministic_scores = {
                item.id: self._deterministic_relevance_score(item, required_terms)
                for item in candidates
            }
            try:
                selection = OpenRouterChatService().generate_json(
                    system_prompt=RESEARCH_RESULT_SELECTOR_PROMPT,
                    user_payload={
                        "user_direction": self._user_direction_payload(payload, user_context),
                        "freshness_window": "published within the last 366 days",
                        "required_terms": required_terms,
                        "candidates": [
                            {
                                "id": item.id,
                                "title": item.title,
                                "abstract": item.summary[:1600],
                                "categories": item.tags,
                                "published_at": (item.published_at or item.updated_at).isoformat(),
                            }
                            for item in candidates
                        ],
                    },
                    output_model=ResearchCandidateSelection,
                    schema_name="research_candidate_selection",
                    timeout_sec=RESEARCH_LLM_TIMEOUT_SEC,
                )
                rated = [
                    (
                        candidate_by_id[result.id],
                        (
                            RESEARCH_PRIMARY_SCORE
                            if deterministic_scores[result.id] == RESEARCH_PRIMARY_SCORE
                            else min(result.relevance_score, deterministic_scores[result.id])
                        ),
                    )
                    for result in selection.selections
                    if result.id in candidate_by_id and result.relevance_score >= RESEARCH_MIN_SCORE
                ]
                selected_ids = {item.id for item, _ in rated}
                rated.extend(
                    (item, RESEARCH_PRIMARY_SCORE)
                    for item in candidates
                    if deterministic_scores[item.id] == RESEARCH_PRIMARY_SCORE
                    and item.id not in selected_ids
                )
            except Exception:
                rated = [
                    (item, self._deterministic_relevance_score(item, required_terms))
                    for item in candidates
                ]

        deduped: List[tuple[SourceItem, int]] = []
        seen_ids = set()
        has_five_star = False
        for item, score in sorted(
            rated,
            key=lambda pair: (
                pair[1],
                (pair[0].published_at or pair[0].updated_at).isoformat(),
            ),
            reverse=True,
        ):
            if item.id in seen_ids or score < RESEARCH_MIN_SCORE:
                continue
            seen_ids.add(item.id)
            normalized_score = min(score, RESEARCH_PRIMARY_SCORE)
            if normalized_score == RESEARCH_PRIMARY_SCORE:
                if has_five_star:
                    normalized_score = 4
                else:
                    has_five_star = True
            deduped.append((item, normalized_score))
        # A primary paper is never created by promoting a weaker candidate.
        if not deduped or deduped[0][1] != RESEARCH_PRIMARY_SCORE:
            return []
        return deduped[:RESEARCH_ITEM_LIMIT]

    def _deterministic_relevance_score(self, item: SourceItem, required_terms: List[str]) -> int:
        title = item.title.lower()
        abstract = item.summary.lower()
        meaningful = self._meaningful_terms(required_terms)
        title_matches = {term for term in meaningful if term in title}
        all_matches = {term for term in meaningful if term in f"{title} {abstract}"}
        title_tokens = self._normalized_anchor_tokens(title)
        # A concrete multi-token route can establish 5-star relevance even
        # when wording varies (for example "Driving World Models" versus
        # "Auto Driving World Model"). A generic "World Models" match alone
        # remains at most 4 stars.
        for term in meaningful:
            anchor_tokens = self._normalized_anchor_tokens(term)
            if len(anchor_tokens) < 3:
                continue
            overlap = len(anchor_tokens & title_tokens)
            if overlap >= max(2, ceil(len(anchor_tokens) * 0.67)):
                return 5
        if len(all_matches) >= 2 and title_matches:
            return 5
        if title_matches or len(all_matches) >= 2:
            return 4
        if all_matches:
            return 3
        return 1

    def _normalized_anchor_tokens(self, value: str) -> set[str]:
        tokens = set()
        for token in re.findall(r"[a-z0-9]+", value.lower()):
            if token in {"a", "an", "and", "for", "of", "the", "to", "with"}:
                continue
            if len(token) > 4 and token.endswith("s"):
                token = token[:-1]
            tokens.add(token)
        return tokens

    def _build_search_plan(
        self,
        payload: ResearchFeederPayload,
        user_context: Optional[UserContext],
        query: str,
    ) -> ResearchSearchPlan:
        fallback_terms = self._search_terms(payload, user_context, query)
        fallback_queries = self._dedupe_terms(
            [query.strip(), *fallback_terms]
        )[:3]
        fallback = ResearchSearchPlan(
            queries=fallback_queries or ["computer vision"],
            required_terms=self._meaningful_terms(fallback_terms)[:8],
        )
        return fallback

    def _user_direction_payload(
        self,
        payload: ResearchFeederPayload,
        user_context: UserContext,
    ) -> dict:
        return {
            "goal": user_context.profile.goal,
            "current_stage": user_context.profile.current_stage,
            "background_summary": user_context.profile.background_summary,
            "long_term_goal": user_context.plan.long_term_goal,
            "full_cycle_plan": user_context.plan.full_cycle_plan,
            "weekly_focus": user_context.plan.weekly_focus,
            "active_tasks": user_context.plan.active_tasks,
            "next_action": user_context.plan.next_action,
            "tracking_keywords": user_context.plan.tracking_keywords,
            "field_preferences": user_context.preferences.fields,
            "source_preferences": [value.value for value in user_context.preferences.source_preferences],
            "deep_dive": {
                "current_direction": payload.research_context.current_direction,
                "current_task": payload.research_context.current_task,
                "week_goal": payload.research_context.week_goal,
                "related_project": payload.research_context.related_project,
            },
        }

    def _meaningful_terms(self, terms: List[str]) -> List[str]:
        cleaned = self._dedupe_terms(
            [re.sub(r"\s+", " ", term).strip().lower() for term in terms if term.strip()]
        )
        distinctive = [
            term
            for term in cleaned
            if len(term) >= 3 and term not in RESEARCH_BROAD_TERMS
        ]
        # As with Signal Radar, a broad term remains legitimate when it is the
        # user's only declared direction; it just cannot override stronger anchors.
        return distinctive or [term for term in cleaned if len(term) >= 2]

    def _dedupe_terms(self, terms: List[str]) -> List[str]:
        deduped: List[str] = []
        seen = set()
        for term in terms:
            key = term.lower()
            if not key or key in seen:
                continue
            seen.add(key)
            deduped.append(term)
        return deduped

    def _search_terms(
        self,
        payload: ResearchFeederPayload,
        user_context: Optional[UserContext],
        query: str,
    ) -> List[str]:
        values: List[str] = [query]
        if user_context is not None:
            values.extend(
                [
                    *user_context.plan.tracking_keywords,
                    *user_context.preferences.fields,
                    *user_context.plan.active_tasks,
                    *user_context.plan.full_cycle_plan,
                    user_context.plan.weekly_focus,
                    user_context.plan.next_action,
                    user_context.profile.goal,
                    user_context.plan.long_term_goal,
                    user_context.profile.current_stage,
                ]
            )
        values.extend(
            [
                payload.research_context.current_direction,
                payload.research_context.related_project,
                payload.research_context.week_goal,
                payload.research_context.current_task,
            ]
        )

        terms: List[str] = []
        seen = set()
        for value in values:
            for term in self._terms_from_value(value):
                key = term.lower()
                if key in seen:
                    continue
                seen.add(key)
                terms.append(term)
        # Keep a wider raw pool because generic fragments are removed later.
        # Truncating here let tokens such as world/model/driving crowd out
        # distinctive project anchors such as 4DGS, SLAM or StreetGaussian.
        return terms[:24] or ["computer vision"]

    def _terms_from_value(self, value: str) -> List[str]:
        cleaned = " ".join(value.split()).strip()
        if not cleaned:
            return []
        terms: List[str] = []
        if len(cleaned) <= 48:
            configured_terms = [
                term.strip()
                for term in re.split(r"\s*(?:/|,|，|;|；|\|)\s*", cleaned)
                if term.strip()
            ]
            terms.extend(configured_terms if len(configured_terms) > 1 else [cleaned])
            # Direction settings already provide curated tracking phrases.
            # Splitting them into world/model/deep/learning overwhelms arXiv's
            # newest-first results with broad-field noise.
            return terms
        tokens = re.findall(r"[A-Za-z0-9][A-Za-z0-9+./-]{1,30}", cleaned)
        stop = {"current", "week", "goal", "plan", "research", "paper", "model"}
        terms.extend(token for token in tokens if token.lower() not in stop)
        terms.extend(re.findall(r"[\u4e00-\u9fff]{3,12}", cleaned))
        return terms

    def _paper_from_source(self, source: SourceItem, terms: List[str], relevance_score: int) -> Paper:
        matched = [term for term in terms if term.lower() in f"{source.title} {source.summary}".lower()]
        published = source.published_at or source.updated_at
        venue = "arXiv"
        pdf_url = source.extra.get("pdf_url")
        return Paper(
            id=f"real_{source.source.value}_{source.id}".replace("/", "_"),
            title=source.title.strip(),
            authors=source.authors,
            venue=venue,
            year=published.year if published else None,
            published_at=published,
            relevance_score=relevance_score,
            url=source.url,
            pdf_url=pdf_url or None,
            summary=source.summary.strip() or "公开来源未提供摘要，请打开原始页面核对。",
            why_selected=(
                f"相关度 {relevance_score} / 5；与当前方向和计划中的「"
                + "、".join(matched[:4])
                + "」匹配。"
                if matched
                else f"相关度 {relevance_score} / 5；由 Agent 根据当前目标和计划综合评定。"
            ),
            visuals=[],
            tags=[source.source.value, *source.tags[:5]],
        )

    def _reader_from_source(self, paper: Paper, source: SourceItem) -> PaperReader:
        summary = source.summary.strip()
        sections = []
        if summary:
            sections.append(
                ReadingSection(
                    id=f"{paper.id}_source_summary",
                    section_name="Abstract / Source Summary",
                    read_mode=ReadMode.skim,
                    extracted_text=summary,
                    why_read="这是真实公开来源返回的摘要信息，可用于决定是否打开原文继续阅读。",
                    agent_instruction="核对原始页面后，再提炼问题、方法、证据和局限性。",
                    knowledge_points=[],
                )
            )
        return PaperReader(
            paper_id=paper.id,
            pdf_url=paper.pdf_url,
            sections=sections,
            selected_passages=[],
            key_figures=[],
        )
