import re
from typing import List, Optional
from urllib.parse import urlparse

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
from app.services.search_service import SearchService


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

        terms = self._search_terms(payload, user_context, query)
        sources = self._search_sources(terms)
        papers = [self._paper_from_source(item, terms) for item in sources[:3]]
        if not papers:
            return payload.model_copy(
                update={
                    "reading_pack": payload.reading_pack.model_copy(
                        update={
                            "primary_paper_id": "pending_primary_paper",
                            "candidate_paper_id": None,
                            "selection_reason": "未检索到符合当前方向的 arXiv 论文，请稍后重试或输入更具体的检索主题。",
                        }
                    ),
                    "papers": [],
                    "paper_reader": None,
                    "paper_readers": [],
                    "notes": PaperNotes(),
                    "archive_plan": None,
                }
            )

        readers = [self._reader_from_source(paper, source) for paper, source in zip(papers, sources)]
        primary = papers[0]
        candidate = papers[1] if len(papers) > 1 else None
        return payload.model_copy(
            update={
                "reading_pack": ReadingPack(
                    primary_paper_id=primary.id,
                    candidate_paper_id=candidate.id if candidate else None,
                    selection_reason=(
                        "候选来自实时公开检索，并按与当前目标、周计划和跟踪关键词的匹配程度排序；"
                        "确认前请核对原始页面与发布时间。"
                    ),
                    reading_goal=payload.reading_pack.reading_goal,
                ),
                "papers": papers,
                "paper_reader": readers[0],
                "paper_readers": readers,
                "notes": PaperNotes(),
                "archive_plan": ArchivePlan(
                    target_archive=["research_note"],
                    tags=terms[:6],
                ),
            }
        )

    def _search_sources(self, terms: List[str]) -> List[SourceItem]:
        arxiv_query = " OR ".join(f'all:"{term}"' for term in terms[:4])
        try:
            arxiv_items = self.search_service.search_arxiv(arxiv_query, max_results=8).items
        except Exception:
            arxiv_items = []
        usable = self._rank_sources(self._validated_arxiv_sources(arxiv_items), terms)
        if usable:
            return usable

        # Bocha is only a transport fallback. The content contract remains
        # arXiv-only, so journal homepages, news and generic web pages can never
        # enter a Deep Dive pack.
        web_query = "site:arxiv.org/abs " + " ".join(terms[:4])
        try:
            web_items = self.search_service.search_public_web(web_query, max_results=10).items
        except Exception:
            web_items = []
        return self._rank_sources(self._validated_arxiv_sources(web_items), terms)

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

    def _rank_sources(self, items: List[SourceItem], terms: List[str]) -> List[SourceItem]:
        usable = [item for item in items if not item.id.endswith("_search_error") and item.title.strip()]
        return sorted(
            usable,
            key=lambda item: (
                self._match_count(item, terms),
                (item.published_at or item.updated_at).isoformat()
                if (item.published_at or item.updated_at)
                else "",
            ),
            reverse=True,
        )

    def _match_count(self, item: SourceItem, terms: List[str]) -> int:
        haystack = f"{item.title} {item.summary} {' '.join(item.tags)}".lower()
        return sum(term.lower() in haystack for term in terms)

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
                    user_context.plan.weekly_focus,
                    user_context.plan.next_action,
                    user_context.profile.goal,
                ]
            )
        values.extend(
            [
                payload.research_context.current_direction,
                payload.research_context.related_project,
                payload.research_context.week_goal,
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
        return terms[:8] or ["computer vision"]

    def _terms_from_value(self, value: str) -> List[str]:
        cleaned = " ".join(value.split()).strip()
        if not cleaned:
            return []
        terms: List[str] = []
        if len(cleaned) <= 48:
            terms.append(cleaned)
        tokens = re.findall(r"[A-Za-z0-9][A-Za-z0-9+./-]{1,30}", cleaned)
        stop = {"current", "week", "goal", "plan", "research", "paper", "model"}
        terms.extend(token for token in tokens if token.lower() not in stop)
        terms.extend(re.findall(r"[\u4e00-\u9fff]{3,12}", cleaned))
        return terms

    def _paper_from_source(self, source: SourceItem, terms: List[str]) -> Paper:
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
            url=source.url,
            pdf_url=pdf_url or None,
            summary=source.summary.strip() or "公开来源未提供摘要，请打开原始页面核对。",
            why_selected=(
                "与当前方向中的「" + "、".join(matched[:4]) + "」直接匹配。"
                if matched
                else "来自当前检索式的近期公开结果，需要打开原始页面复核相关性。"
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
