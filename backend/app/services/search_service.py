import hashlib
import html
import re
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from typing import List
from urllib.parse import quote_plus, urlencode
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
RSS_NS = "{http://www.w3.org/2005/Atom}"
ARTICLE_TEXT_TAGS = {"article", "p", "li", "h1", "h2", "h3"}
SKIP_TEXT_TAGS = {"script", "style", "noscript", "svg", "nav", "footer", "header", "form", "button"}


class _ReadableHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._capture_stack: List[str] = []
        self._skip_depth = 0
        self._current: List[str] = []
        self.paragraphs: List[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:
        lowered = tag.lower()
        if lowered in SKIP_TEXT_TAGS:
            self._skip_depth += 1
            return
        if self._skip_depth:
            return
        if lowered in ARTICLE_TEXT_TAGS:
            self._flush_current()
            self._capture_stack.append(lowered)

    def handle_endtag(self, tag: str) -> None:
        lowered = tag.lower()
        if lowered in SKIP_TEXT_TAGS and self._skip_depth:
            self._skip_depth -= 1
            return
        if self._skip_depth:
            return
        if lowered in ARTICLE_TEXT_TAGS and self._capture_stack:
            self._flush_current()
            self._capture_stack.pop()

    def handle_data(self, data: str) -> None:
        if self._skip_depth or not self._capture_stack:
            return
        cleaned = " ".join(data.split())
        if cleaned:
            self._current.append(cleaned)

    def _flush_current(self) -> None:
        if not self._current:
            return
        text = " ".join(self._current)
        text = re.sub(r"\s+", " ", html.unescape(text)).strip()
        if text:
            self.paragraphs.append(text)
        self._current = []


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
            items.extend(self.search_public_web(query, per_source).items)
        except Exception as exc:
            items.append(self._error_item(SourceType.web, query, exc))
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

    def search_public_web(self, query: str, max_results: int = 5) -> SourceSearchResponse:
        url = (
            "https://news.google.com/rss/search?q="
            + quote_plus(query)
            + "&hl=zh-CN&gl=CN&ceid=CN:zh-Hans"
        )
        response = httpx.get(
            url,
            timeout=self.settings.source_timeout_sec,
            trust_env=False,
            headers={"User-Agent": "OrbitEngineRadar/0.1"},
        )
        response.raise_for_status()
        return SourceSearchResponse(
            query=query,
            source=SourceType.web,
            items=self._parse_rss(response.text, max_results),
            fetched_at=datetime.now(timezone.utc),
        )

    def search_industry_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        items: List[SourceItem] = []
        per_source = max(1, min(max_results, 10))
        try:
            items.extend(self.search_public_web(query, per_source).items)
        except Exception as exc:
            items.append(self._error_item(SourceType.web, query, exc))
        return CombinedSearchResponse(
            query=query,
            items=items[: max(1, max_results)],
            fetched_at=datetime.now(timezone.utc),
        )

    def search_product_strategy_sources(self, query: str, max_results: int = 5) -> CombinedSearchResponse:
        return self.search_industry_sources(query, max_results=max_results)

    def fetch_web_passages(self, url: str, max_passages: int = 5) -> List[str]:
        if not url:
            return []
        response = httpx.get(
            url,
            timeout=self.settings.source_timeout_sec,
            trust_env=False,
            follow_redirects=True,
            headers={"User-Agent": "OrbitEngineRadar/0.1"},
        )
        response.raise_for_status()
        content_type = response.headers.get("content-type", "")
        if "html" not in content_type.lower():
            return []
        parser = _ReadableHTMLParser()
        parser.feed(response.text)
        parser.close()
        return self._clean_readable_paragraphs(parser.paragraphs, max_passages=max_passages)

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

    def _parse_rss(self, xml_text: str, max_results: int) -> List[SourceItem]:
        root = ET.fromstring(xml_text)
        items: List[SourceItem] = []
        channel = root.find("channel")
        nodes = channel.findall("item") if channel is not None else root.findall(f"{RSS_NS}entry")
        for node in nodes[:max_results]:
            title = " ".join(self._text(node, "title").split())
            link = self._text(node, "link")
            if not link:
                link_node = node.find(f"{RSS_NS}link")
                link = link_node.attrib.get("href", "") if link_node is not None else ""
            description = self._clean_html(self._text(node, "description") or self._text(node, "summary"))
            published = self._parse_rss_datetime(self._text(node, "pubDate") or self._text(node, "published"))
            source_node = node.find("source")
            source_name = source_node.text.strip() if source_node is not None and source_node.text else ""
            source_url = source_node.attrib.get("url", "") if source_node is not None else ""
            item_id = hashlib.sha1((link or title).encode("utf-8")).hexdigest()[:16]
            items.append(
                SourceItem(
                    id=item_id,
                    source=SourceType.web,
                    item_type=SourceItemType.article,
                    title=title,
                    url=link or None,
                    summary=description,
                    published_at=published,
                    updated_at=published,
                    tags=[tag for tag in ["public_web", source_name] if tag],
                    extra={
                        key: value
                        for key, value in {
                            "publisher": source_name,
                            "publisher_url": source_url,
                        }.items()
                        if value
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

    def _parse_rss_datetime(self, value: str):
        if not value:
            return None
        try:
            parsed = parsedate_to_datetime(value)
            if parsed.tzinfo is None:
                return parsed.replace(tzinfo=timezone.utc)
            return parsed
        except (TypeError, ValueError):
            return self._parse_datetime(value)

    def _clean_html(self, value: str) -> str:
        text = re.sub(r"<[^>]+>", " ", value)
        text = html.unescape(text)
        text = text.replace("\xa0", " ")
        text = re.sub(r"\s+", " ", text)
        return text.strip()

    def _clean_readable_paragraphs(self, paragraphs: List[str], max_passages: int) -> List[str]:
        cleaned: List[str] = []
        seen = set()
        for paragraph in paragraphs:
            text = html.unescape(paragraph).replace("\xa0", " ")
            text = re.sub(r"\s+", " ", text).strip()
            if not self._is_useful_paragraph(text):
                continue
            if len(text) > 700:
                text = text[:697].rstrip() + "..."
            key = text.lower()
            if key in seen:
                continue
            seen.add(key)
            cleaned.append(text)
            if len(cleaned) >= max(1, max_passages):
                break
        return cleaned

    def _is_useful_paragraph(self, text: str) -> bool:
        if not text:
            return False
        cjk_count = len(re.findall(r"[\u4e00-\u9fff]", text))
        if len(text) < 80 and cjk_count < 30:
            return False
        lowered = text.lower()
        boilerplate_terms = [
            "cookie",
            "privacy policy",
            "terms of service",
            "subscribe",
            "sign in",
            "版权所有",
            "隐私政策",
            "用户协议",
            "广告",
            "登录",
            "注册",
            "转载",
        ]
        return not any(term in lowered for term in boilerplate_terms)
