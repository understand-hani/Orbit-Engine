from datetime import date, datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, HttpUrl

from app.schemas.common import VisualAsset


class RadarType(str, Enum):
    product_strategy_radar = "product_strategy_radar"
    technical_method_radar = "technical_method_radar"


class FeedGenerationMode(str, Enum):
    on_demand = "on_demand"
    scheduled = "scheduled"


class RecommendedDepth(str, Enum):
    skim = "skim"
    read = "read"
    deep_discuss = "deep_discuss"


class RadarUserMark(str, Enum):
    unread = "unread"
    valuable = "valuable"
    noise = "noise"
    track_later = "track_later"
    deep_dive = "deep_dive"
    archived = "archived"
    done = "done"


class RadarScope(BaseModel):
    topics: List[str] = []
    companies: List[str] = []
    research_groups: List[str] = []
    signal_types: List[str] = []
    exclude: List[str] = []


class RadarSourcePassage(BaseModel):
    id: str
    title: str = ""
    excerpt: str
    analysis: str = ""
    suggestion: str = ""
    source_url: Optional[HttpUrl] = None
    location: str = ""


class RadarItem(BaseModel):
    id: str
    radar_type: RadarType
    title: str
    source: str
    url: Optional[HttpUrl] = None
    signal_type: str
    summary: str
    technical_substance: str = ""
    marketing_noise: str = ""
    why_it_matters: str
    source_passages: List[RadarSourcePassage] = []
    visuals: List[VisualAsset] = []
    recommended_depth: RecommendedDepth = RecommendedDepth.skim
    user_mark: RadarUserMark = RadarUserMark.unread
    archived_at: Optional[datetime] = None
    archive_note: str = ""
    tags: List[str] = []


class RadarItemMarkRequest(BaseModel):
    user_mark: RadarUserMark
    archive_note: str = ""


class RadarDigest(BaseModel):
    week_start: date
    week_end: date
    summary: str
    items: List[RadarItem] = []
    top_signals: List[str] = []
    noise_filtered: List[str] = []
    follow_up_questions: List[str] = []


class TechRadarPayload(BaseModel):
    radar_type: RadarType
    scope: RadarScope
    generation_mode: FeedGenerationMode = FeedGenerationMode.on_demand
    source_refresh_time: Optional[datetime] = None
    is_stale: bool = False
    digest: RadarDigest
