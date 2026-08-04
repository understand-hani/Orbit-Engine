from enum import Enum
from typing import Optional

from pydantic import BaseModel, HttpUrl


class TaskType(str, Enum):
    tech_radar = "tech_radar"
    jd_analysis = "jd_analysis"
    research_feeder = "research_feeder"


class SessionMode(str, Enum):
    scheduled = "scheduled"
    manual = "manual"
    catch_up = "catch_up"
    review = "review"


class SessionStatus(str, Enum):
    draft = "draft"
    active = "active"
    completed = "completed"
    partial = "partial"
    skipped = "skipped"
    archived = "archived"


class SuggestedAction(str, Enum):
    generate_weekly_radar = "generate_weekly_radar"
    open_weekly_radar = "open_weekly_radar"
    discuss_signal = "discuss_signal"
    mark_radar_done = "mark_radar_done"
    add_jd_input = "add_jd_input"
    analyze_jd = "analyze_jd"
    open_analysis_report = "open_analysis_report"
    revise_resume = "revise_resume"
    open_gap_plan = "open_gap_plan"
    mark_jd_done = "mark_jd_done"
    generate_reading_pack = "generate_reading_pack"
    open_paper_reader = "open_paper_reader"
    continue_reading = "continue_reading"
    edit_notes = "edit_notes"
    archive_paper = "archive_paper"
    mark_research_done = "mark_research_done"


class VisualType(str, Enum):
    image = "image"
    video = "video"
    pdf_figure = "pdf_figure"
    chart = "chart"
    screenshot = "screenshot"
    table = "table"


class VisualUsage(str, Enum):
    cover = "cover"
    evidence = "evidence"
    method_figure = "method_figure"
    product_screenshot = "product_screenshot"
    architecture = "architecture"
    benchmark = "benchmark"
    teaser = "teaser"
    chart = "chart"


class VisualAsset(BaseModel):
    id: str
    type: VisualType
    url: Optional[HttpUrl] = None
    local_path: str = ""
    caption: str
    source: str
    usage: VisualUsage

