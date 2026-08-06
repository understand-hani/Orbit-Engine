from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, HttpUrl

from app.schemas.common import VisualAsset


class ResearchDayRole(str, Enum):
    select_and_start = "select_and_start"
    continue_and_archive = "continue_and_archive"
    manual_deep_dive = "manual_deep_dive"


class PaperStatus(str, Enum):
    unread = "unread"
    reading = "reading"
    done = "done"
    track_later = "track_later"
    discarded = "discarded"


class ReadMode(str, Enum):
    skim = "skim"
    normal = "normal"
    deep_read = "deep_read"
    skip = "skip"


class ReadStatus(str, Enum):
    unread = "unread"
    reading = "reading"
    done = "done"
    skipped = "skipped"


class AnnotationType(str, Enum):
    note = "note"
    bookmark = "bookmark"
    highlight = "highlight"
    underline = "underline"
    comment = "comment"


class ContinueDecision(str, Enum):
    continue_ = "continue"
    track_later = "track_later"
    drop = "drop"
    unsure = "unsure"


class UsableFor(str, Enum):
    research_note = "research_note"
    paper_writing = "paper_writing"
    blog = "blog"
    resume = "resume"
    experiment = "experiment"
    jd_evidence = "jd_evidence"


class ResearchContext(BaseModel):
    current_direction: str
    current_task: str
    week_goal: str
    related_project: str = ""


class ReadingPack(BaseModel):
    primary_paper_id: str
    candidate_paper_id: Optional[str] = None
    selection_reason: str
    reading_goal: str
    expected_finish_window: str = "thursday_friday"


class Paper(BaseModel):
    id: str
    title: str
    authors: List[str] = []
    venue: str = ""
    year: Optional[int] = None
    url: Optional[HttpUrl] = None
    pdf_url: Optional[HttpUrl] = None
    repo_url: Optional[HttpUrl] = None
    summary: str
    why_selected: str
    visuals: List[VisualAsset] = []
    tags: List[str] = []
    status: PaperStatus = PaperStatus.unread


class ReadingSection(BaseModel):
    id: str
    section_name: str
    page_start: Optional[int] = None
    page_end: Optional[int] = None
    read_mode: ReadMode
    extracted_text: str = ""
    why_read: str
    agent_instruction: str
    knowledge_points: List[str] = []
    status: ReadStatus = ReadStatus.unread


class SelectedPassage(BaseModel):
    id: str
    paper_id: str
    page: Optional[int] = None
    section_name: str = ""
    text_excerpt: str
    why_selected: str
    reading_question: str
    status: ReadStatus = ReadStatus.unread


class KeyFigure(BaseModel):
    id: str
    paper_id: str
    page: Optional[int] = None
    figure_label: str = ""
    visual: VisualAsset
    why_important: str
    reading_question: str


class PaperAnnotation(BaseModel):
    id: str
    paper_id: str
    annotation_type: AnnotationType
    page: Optional[int] = None
    section_name: str = ""
    text_excerpt: str = ""
    comment: str = ""
    color: str = "yellow"
    pdf_quadpoints: Optional[List[float]] = None
    created_at: datetime


class PaperReader(BaseModel):
    paper_id: str
    pdf_local_path: str = ""
    pdf_url: Optional[HttpUrl] = None
    sections: List[ReadingSection] = []
    selected_passages: List[SelectedPassage] = []
    key_figures: List[KeyFigure] = []
    annotations: List[PaperAnnotation] = []


class PaperNotes(BaseModel):
    input_output: str = ""
    problem_definition: str = ""
    core_idea: str = ""
    training_or_inference_logic: str = ""
    evidence: str = ""
    limitations: str = ""
    relation_to_my_plan: str = ""
    usable_for: List[UsableFor] = []
    continue_or_drop: ContinueDecision = ContinueDecision.unsure
    next_action: str = ""


class ArchivePlan(BaseModel):
    target_archive: List[str] = []
    tags: List[str] = []
    summary_md: str = ""


class ResearchFeederPayload(BaseModel):
    research_day_role: ResearchDayRole
    research_context: ResearchContext
    reading_pack: ReadingPack
    papers: List[Paper] = []
    paper_reader: Optional[PaperReader] = None
    paper_readers: List[PaperReader] = []
    notes: PaperNotes = PaperNotes()
    archive_plan: Optional[ArchivePlan] = None
