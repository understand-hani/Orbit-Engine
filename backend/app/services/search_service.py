from datetime import datetime, timezone
from typing import List
from urllib.parse import urlencode
from xml.etree import ElementTree as ET

import httpx

from app.config import get_settings
from app.schemas.source import (
    CombinedSearchResponse,
    SourceItem,
    SourceItemType,
    SourceSearchResponse,
    SourceType,
)


ATOM_NS = "{http://www.w3.org/2005/Atom}"
ARXIV_NS = "{http://arxiv.org/schemas/atom}"


class SearchService:
    def __init__(self) -> None:
        self.settings = get_settings()

    def search_arxiv(self, query: str, max_results: int = 5) -> SourceSearchResponse:
        params = {
            "search_query": query,
            "start": 0,
            "max_results": max(1, min(max_results, 20)),
            "sortBy": "submittedDate",
            "sortOrder": "descending",
        }
        url = "https://export.arxiv.org/api/query?" + urlencode(params)
        response = httpx.get(
            url,
            timeout=self.settings.source_timeout_sec,
            trust_env=False,
        )
        response.raise_for_status()
        items = self._parse_arxiv(response.text)
        return SourceSearchResponse(
            query=query,
            source=SourceType.arxiv,
            items=items,
            fetched_at=datetime.now(timezone.utc),
        )

    def search_github_repositories(self, query: str, max_results: int = 5) -> SourceSearchResponse:
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if self.settings.github_token:
            headers["Authorization"] = f"Bearer {self.settings.github_token}"
        response = httpx.get(
            "https://api.github.com/search/repositories",
            params={
                "q": query,
                "sort": "updated",
                "order": "desc",
                "per_page": max(1, min(max_results, 20)),
            },
            headers=headers,
            timeout=self.settings.source_timeout_sec,
            trust_env=False,
        )
        response.raise_for_status()
        items = self._parse_github_repositories(response.json())
        return SourceSearchResponse(
            query=query,
            source=SourceType.github,
            items=items,
            fetched_at=datetime.now(timezone.utc),
        )

    def search_technical_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        items: List[SourceItem] = []
        per_source = max(1, min(max_results, 10))
        try:
            items.extend(self.search_arxiv(query, per_source).items)
        except Exception as exc:
            items.append(self._error_item(SourceType.arxiv, query, exc))
        try:
            items.extend(self.search_github_repositories(query, per_source).items)
        except Exception as exc:
            items.append(self._error_item(SourceType.github, query, exc))
        return CombinedSearchResponse(
            query=query,
            items=items[: max(1, max_results)],
            fetched_at=datetime.now(timezone.utc),
        )

    def search_product_strategy_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        return CombinedSearchResponse(
            query=query,
            items=[
                SourceItem(
                    id="web_search_not_configured",
                    source=SourceType.web,
                    item_type=SourceItemType.article,
                    title="Web search provider is not configured",
                    summary=(
                        "产品、车企、法规类搜索需要接入搜索 API、RSS 或指定站点源。"
                        "当前版本不做不稳定网页爬虫。"
                    ),
                    tags=["todo", "web_search"],
                )
            ][:max_results],
            fetched_at=datetime.now(timezone.utc),
        )

    def _parse_arxiv(self, xml_text: str) -> List[SourceItem]:
        root = ET.fromstring(xml_text)
        items: List[SourceItem] = []
        for entry in root.findall(f"{ATOM_NS}entry"):
            arxiv_id = self._text(entry, f"{ATOM_NS}id")
            title = " ".join(self._text(entry, f"{ATOM_NS}title").split())
            summary = " ".join(self._text(entry, f"{ATOM_NS}summary").split())
            authors = [
                self._text(author, f"{ATOM_NS}name")
                for author in entry.findall(f"{ATOM_NS}author")
            ]
            published = self._parse_datetime(self._text(entry, f"{ATOM_NS}published"))
            updated = self._parse_datetime(self._text(entry, f"{ATOM_NS}updated"))
            pdf_url = ""
            for link in entry.findall(f"{ATOM_NS}link"):
                if link.attrib.get("title") == "pdf":
                    pdf_url = link.attrib.get("href", "")
            categories = [
                category.attrib.get("term", "")
                for category in entry.findall(f"{ATOM_NS}category")
            ]
            items.append(
                SourceItem(
                    id=arxiv_id.rsplit("/", 1)[-1],
                    source=SourceType.arxiv,
                    item_type=SourceItemType.paper,
                    title=title,
                    url=arxiv_id or None,
                    summary=summary,
                    authors=authors,
                    published_at=published,
                    updated_at=updated,
                    tags=[tag for tag in categories if tag],
                    extra={"pdf_url": pdf_url},
                )
            )
        return items

    def _parse_github_repositories(self, payload: dict) -> List[SourceItem]:
        items: List[SourceItem] = []
        for repo in payload.get("items", []):
            items.append(
                SourceItem(
                    id=str(repo.get("id", "")),
                    source=SourceType.github,
                    item_type=SourceItemType.repo,
                    title=repo.get("full_name") or repo.get("name") or "",
                    url=repo.get("html_url") or None,
                    summary=repo.get("description") or "",
                    updated_at=self._parse_datetime(repo.get("updated_at") or ""),
                    tags=[topic for topic in repo.get("topics", []) if topic],
                    extra={
                        "stars": repo.get("stargazers_count"),
                        "forks": repo.get("forks_count"),
                        "language": repo.get("language"),
                    },
                )
            )
        return items

    def _error_item(self, source: SourceType, query: str, exc: Exception) -> SourceItem:
        return SourceItem(
            id=f"{source.value}_search_error",
            source=source,
            item_type=SourceItemType.article,
            title=f"{source.value} search failed",
            summary=f"Query '{query}' failed: {type(exc).__name__}: {exc}",
            tags=["error"],
        )

    def _text(self, node: ET.Element, path: str) -> str:
        child = node.find(path)
        if child is None or child.text is None:
            return ""
        return child.text.strip()

    def _parse_datetime(self, value: str):
        if not value:
            return None
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
