from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, HttpUrl


class MaterialSourceType(str, Enum):
    pdf = "pdf"
    url = "url"
    manual = "manual"
    public_source = "public_source"
    arxiv = "arxiv"
    github = "github"
    official_doc = "official_doc"


class PersonalProfile(BaseModel):
    id: str = "default_profile"
    display_name: str = "新用户"
    goal: str = ""
    background_summary: str = ""
    current_stage: str = ""
    constraints: List[str] = []
    updated_at: datetime


class WorkLearningPlan(BaseModel):
    id: str = "active_plan"
    long_term_goal: str = ""
    target_cycle: str = ""
    full_cycle_plan: List[str] = []
    weekly_focus: str = ""
    active_tasks: List[str] = []
    next_action: str = ""
    tracking_keywords: List[str] = []
    updated_at: datetime


class UserPreference(BaseModel):
    id: str = "default_preferences"
    fields: List[str] = []
    source_preferences: List[MaterialSourceType] = [
        MaterialSourceType.arxiv,
        MaterialSourceType.official_doc,
        MaterialSourceType.url,
    ]
    session_time_budget_min: int = 30
    language: str = "zh-CN"
    updated_at: datetime


class UserMaterial(BaseModel):
    id: str
    title: str
    source_type: MaterialSourceType
    summary: str
    url: Optional[HttpUrl] = None
    file_path: str = ""
    authors_or_owner: List[str] = []
    published_date: str = ""
    tags: List[str] = []
    related_plan: str = ""
    why_selected: str = ""
    fetched_at: datetime


class UserMaterialCreate(BaseModel):
    title: str
    source_type: MaterialSourceType = MaterialSourceType.manual
    summary: str
    url: Optional[HttpUrl] = None
    file_path: str = ""
    authors_or_owner: List[str] = []
    published_date: str = ""
    tags: List[str] = []
    related_plan: str = ""


class UserContext(BaseModel):
    profile: PersonalProfile
    plan: WorkLearningPlan
    preferences: UserPreference
    materials: List[UserMaterial] = []


class DirectionProfileSuggestionRequest(BaseModel):
    long_term_goal: str = ""
    current_direction: str
    current_stage: str = ""
    background_summary: str = ""
    target_cycle: str = ""
    time_budget_min: int = 30
    full_cycle_plan: List[str] = []
    weekly_focus: str = ""
    active_tasks: List[str] = []
    next_action: str = ""


class DirectionProfileSuggestion(BaseModel):
    full_cycle_plan: List[str] = []
    weekly_focus: str
    next_action: str
    active_tasks: List[str] = []
    tracking_keywords: List[str] = []
    fields: List[str] = []
    source_preferences: List[MaterialSourceType] = []
    constraints: List[str] = []
    generation_mode: str = "fallback"


class RecommendationContext(BaseModel):
    derived_from: List[str] = []
    tracking_keywords: List[str] = []
    related_plan: str = ""
    user_preference: str = ""
    why_this_material_now: str = ""
