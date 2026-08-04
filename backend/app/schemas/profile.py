from datetime import datetime
from typing import List

from pydantic import BaseModel


class ResumeProfile(BaseModel):
    id: str
    version: str
    basic_profile: dict = {}
    education: List[dict] = []
    work_experience: List[dict] = []
    projects: List[dict] = []
    skills: List[dict] = []
    papers: List[dict] = []
    open_source: List[dict] = []
    target_versions: List[dict] = []
    updated_at: datetime


class ResumeProfileCreate(BaseModel):
    version: str = "v0.1"
    basic_profile: dict = {}
    education: List[dict] = []
    work_experience: List[dict] = []
    projects: List[dict] = []
    skills: List[dict] = []
    papers: List[dict] = []
    open_source: List[dict] = []
    target_versions: List[dict] = []


class LearningPlanSnapshot(BaseModel):
    id: str
    current_phase: str
    weekly_focus: str
    active_projects: List[str] = []
    capability_gaps: List[str] = []
    updated_at: datetime


class ResearchArchive(BaseModel):
    id: str
    paper_id: str
    note_id: str
    tags: List[str] = []
    usable_for: List[str] = []
    summary_md: str = ""
    created_at: datetime


class ResearchArchiveCreate(BaseModel):
    paper_id: str
    note_id: str
    tags: List[str] = []
    usable_for: List[str] = []
    summary_md: str = ""
