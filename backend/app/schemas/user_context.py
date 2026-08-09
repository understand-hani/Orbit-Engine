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
    display_name: str = "Demo User"
    goal: str = "在一个自定义领域内持续学习、探索并形成可验证进展。"
    background_summary: str = "用户可以在这里维护个人情况、简历摘要、当前基础和约束。"
    current_stage: str = "建立稳定的学习/探索闭环。"
    constraints: List[str] = ["每天 30-60 分钟", "优先形成小产出", "避免开放式阅读"]
    updated_at: datetime


class WorkLearningPlan(BaseModel):
    id: str = "active_plan"
    long_term_goal: str = "围绕目标领域建立可持续的能力建设节奏。"
    weekly_focus: str = "本周先跑通 Deep Dive：从材料选择到阅读、打卡、历史记录。"
    active_tasks: List[str] = [
        "选择一份和当前目标相关的材料",
        "完成一次 30 分钟 Deep Dive",
        "写入关键洞察和下一步",
    ]
    next_action: str = "用一份用户材料或公开材料生成今天的 Deep Dive。"
    tracking_keywords: List[str] = ["agent workflow", "personal learning system", "deep dive"]
    updated_at: datetime


class UserPreference(BaseModel):
    id: str = "default_preferences"
    fields: List[str] = ["AI application", "career capability", "research workflow"]
    source_preferences: List[MaterialSourceType] = [
        MaterialSourceType.pdf,
        MaterialSourceType.url,
        MaterialSourceType.official_doc,
        MaterialSourceType.arxiv,
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
    time_budget_min: int = 30


class DirectionProfileSuggestion(BaseModel):
    weekly_focus: str
    next_action: str
    active_tasks: List[str] = []
    tracking_keywords: List[str] = []
    fields: List[str] = []
    source_preferences: List[MaterialSourceType] = []
    constraints: List[str] = []


class RecommendationContext(BaseModel):
    derived_from: List[str] = []
    tracking_keywords: List[str] = []
    related_plan: str = ""
    user_preference: str = ""
    why_this_material_now: str = ""
