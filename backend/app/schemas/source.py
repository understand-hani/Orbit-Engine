from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, HttpUrl


class SourceType(str, Enum):
    arxiv = "arxiv"
    github = "github"
    web = "web"


class SourceItemType(str, Enum):
    paper = "paper"
    repo = "repo"
    article = "article"
    product_update = "product_update"
    company_update = "company_update"


class SourceItem(BaseModel):
    id: str
    source: SourceType
    item_type: SourceItemType
    title: str
    url: Optional[HttpUrl] = None
    summary: str = ""
    authors: List[str] = []
    published_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    tags: List[str] = []
    extra: dict = {}


class SourceSearchRequest(BaseModel):
    query: str
    max_results: int = 5


class SourceSearchResponse(BaseModel):
    query: str
    source: SourceType
    items: List[SourceItem]
    fetched_at: datetime


class CombinedSearchResponse(BaseModel):
    query: str
    items: List[SourceItem]
    fetched_at: datetime
