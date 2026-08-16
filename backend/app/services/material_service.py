import logging
from datetime import datetime, timezone
from typing import List, Optional

from pydantic import BaseModel

from app.db.repositories import SessionRepository
from app.schemas.common import TaskType
from app.schemas.research_feeder import Paper, PaperReader
from app.schemas.tech_radar import RadarItem, RadarItemMarkRequest, RadarUserMark
from app.agents.tech_radar_agent import MockTechRadarAgent
from app.db.repositories import UserContextRepository
from app.config import get_settings
from app.services.llm_service import OpenRouterChatService


logger = logging.getLogger(__name__)


class PassageAgentAnalysis(BaseModel):
    passage_id: str
    analysis: str
    reading_question: str


class FigureAgentAnalysis(BaseModel):
    figure_id: str
    analysis: str
    reading_question: str


class PaperReaderAgentAnalysis(BaseModel):
    passages: List[PassageAgentAnalysis]
    figures: List[FigureAgentAnalysis]


PAPER_READER_ANALYSIS_PROMPT = """
你是个人研究助理。请分析从一篇真实论文 PDF 中逐字提取的段落和图表标题。

要求：
- 不得改写 passage 原文，也不得编造原文未提供的实验结果、数字或结论。
- passage analysis 使用中文，约 80-150 字，说明该段的核心论述、在论文论证链中的作用、关键假设或边界，以及它和用户当前目标/计划的关系。
- analysis 不要只说“来自 PDF”“位于某页”“包含关键词”或复述来源信息。
- reading_question 必须是读者核对方法、证据、假设或适用边界时真正需要回答的问题。
- figure analysis 根据真实图题说明应重点核对哪些变量、模块、对照或结论；无法从图题确认的内容要明确说需要查看图本身，不能猜测。
- 必须为输入中的每个 passage_id 和 figure_id 各返回一项，ID 保持不变。
""".strip()


class MaterialService:
    def __init__(self) -> None:
        self.sessions = SessionRepository()
        self.user_contexts = UserContextRepository()
        self.tech_radar_agent = MockTechRadarAgent()
        self.settings = get_settings()
        self.llm = OpenRouterChatService()

    def list_radar_items(self, session_id: str) -> Optional[List[RadarItem]]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None
        if session.task_type != TaskType.tech_radar:
            return []
        return session.payload.digest.items

    def update_radar_item_mark(
        self,
        session_id: str,
        item_id: str,
        request: RadarItemMarkRequest,
    ) -> Optional[RadarItem]:
        session = self.sessions.get_by_id(session_id)
        if session is None or session.task_type != TaskType.tech_radar:
            return None

        updated_item: Optional[RadarItem] = None
        updated_items: List[RadarItem] = []
        for item in session.payload.digest.items:
            if item.id == item_id:
                mark = request.user_mark
                update = {
                    "user_mark": mark,
                    "archive_note": request.archive_note,
                }
                if mark in {RadarUserMark.archived, RadarUserMark.done}:
                    update["archived_at"] = datetime.now(timezone.utc)
                updated_item = item.model_copy(update=update)
                updated_items.append(updated_item)
            else:
                updated_items.append(item)

        if updated_item is None:
            return None

        updated_digest = session.payload.digest.model_copy(update={"items": updated_items})
        updated_payload = session.payload.model_copy(update={"digest": updated_digest})
        updated_session = session.model_copy(
            update={
                "payload": updated_payload,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        self.sessions.save(updated_session)
        return updated_item

    def archive_radar_item(self, session_id: str, item_id: str, note: str = "") -> Optional[RadarItem]:
        return self.update_radar_item_mark(
            session_id,
            item_id,
            RadarItemMarkRequest(user_mark=RadarUserMark.archived, archive_note=note),
        )

    def generate_radar_item_judgement(self, session_id: str, item_id: str) -> Optional[RadarItem]:
        session = self.sessions.get_by_id(session_id)
        if session is None or session.task_type != TaskType.tech_radar:
            return None

        updated_item: Optional[RadarItem] = None
        updated_items: List[RadarItem] = []
        user_context = self.user_contexts.get()
        for item in session.payload.digest.items:
            if item.id == item_id:
                updated_item = self.tech_radar_agent.generate_detail_judgement(item, user_context)
                updated_items.append(updated_item)
            else:
                updated_items.append(item)

        if updated_item is None:
            return None

        updated_payload = session.payload.model_copy(
            update={"digest": session.payload.digest.model_copy(update={"items": updated_items})}
        )
        self.sessions.save(
            session.model_copy(
                update={"payload": updated_payload, "updated_at": datetime.now(timezone.utc)}
            )
        )
        return updated_item

    def list_papers(self, session_id: str) -> Optional[List[Paper]]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None
        if session.task_type != TaskType.research_feeder:
            return []
        return session.payload.papers

    def get_paper(self, session_id: str, paper_id: str) -> Optional[Paper]:
        papers = self.list_papers(session_id)
        if papers is None:
            return None
        for paper in papers:
            if paper.id == paper_id:
                return paper
        return None

    def get_paper_reader(self, session_id: str) -> Optional[PaperReader]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None
        if session.task_type != TaskType.research_feeder:
            return None
        return session.payload.paper_reader

    def save_paper_reader(
        self,
        session_id: str,
        paper_id: str,
        reader: PaperReader,
        enrich: bool = False,
    ) -> Optional[PaperReader]:
        session = self.sessions.get_by_id(session_id)
        if session is None or session.task_type != TaskType.research_feeder:
            return None
        if reader.paper_id != paper_id or not any(paper.id == paper_id for paper in session.payload.papers):
            return None

        if enrich:
            paper = next(item for item in session.payload.papers if item.id == paper_id)
            reader = self._enrich_paper_reader(reader, paper)

        readers = [item for item in session.payload.paper_readers if item.paper_id != paper_id]
        readers.append(reader)
        primary_reader = session.payload.paper_reader
        if primary_reader is None or primary_reader.paper_id == paper_id:
            primary_reader = reader

        updated_payload = session.payload.model_copy(
            update={
                "paper_reader": primary_reader,
                "paper_readers": readers,
            }
        )
        self.sessions.save(
            session.model_copy(
                update={
                    "payload": updated_payload,
                    "updated_at": datetime.now(timezone.utc),
                }
            )
        )
        return reader

    def _enrich_paper_reader(self, reader: PaperReader, paper: Paper) -> PaperReader:
        if not reader.selected_passages and not reader.key_figures:
            return reader

        fallback = self._fallback_reader_analysis(reader)
        if self.settings.llm_provider != "openrouter" or not self.settings.openrouter_api_key:
            return self._apply_reader_analysis(reader, fallback)

        user_context = self.user_contexts.get()
        payload = {
            "paper": {
                "title": paper.title,
                "summary": paper.summary,
                "why_selected": paper.why_selected,
                "tags": paper.tags,
            },
            "user_context": {
                "goal": user_context.profile.goal if user_context else "",
                "long_term_goal": user_context.plan.long_term_goal if user_context else "",
                "weekly_focus": user_context.plan.weekly_focus if user_context else "",
                "active_tasks": user_context.plan.active_tasks if user_context else [],
            },
            "passages": [
                {
                    "passage_id": item.id,
                    "page": item.page,
                    "section_name": item.section_name,
                    "verbatim_text": item.text_excerpt,
                }
                for item in reader.selected_passages
            ],
            "figures": [
                {
                    "figure_id": item.id,
                    "page": item.page,
                    "label": item.figure_label,
                    "caption": item.visual.caption,
                }
                for item in reader.key_figures
            ],
        }
        try:
            output = self.llm.generate_json(
                system_prompt=PAPER_READER_ANALYSIS_PROMPT,
                user_payload=payload,
                output_model=PaperReaderAgentAnalysis,
                schema_name="paper_reader_agent_analysis",
                timeout_sec=self.settings.openrouter_timeout_sec,
                max_tokens=1600,
            )
            # Apply the grounded fallback first so a partially valid model response
            # cannot leave any passage with the old provenance-only placeholder.
            grounded_reader = self._apply_reader_analysis(reader, fallback)
            return self._apply_reader_analysis(grounded_reader, output)
        except Exception as exc:
            logger.warning(
                "paper_reader_analysis_failed paper_id=%s error_type=%s error=%s",
                paper.id,
                type(exc).__name__,
                str(exc)[:240],
            )
            return self._apply_reader_analysis(reader, fallback)

    def _fallback_reader_analysis(self, reader: PaperReader) -> PaperReaderAgentAnalysis:
        passages = []
        for item in reader.selected_passages:
            claim = " ".join(item.text_excerpt.split())[:180]
            passages.append(
                PassageAgentAnalysis(
                    passage_id=item.id,
                    analysis=(
                        f"这段的核心论述可从“{claim}”展开核对。阅读时应区分作者提出的判断、"
                        "支撑判断的方法或证据，以及没有在本段得到验证的适用边界，避免只记结论而忽略前提。"
                    ),
                    reading_question="作者在这段中提出了什么可验证判断，证据是否足以支持它，在哪些条件下可能不成立？",
                )
            )
        figures = [
            FigureAgentAnalysis(
                figure_id=item.id,
                analysis=(
                    f"图题为“{item.visual.caption[:180]}”。需要结合图本身核对变量、模块、对照组和趋势；"
                    "仅凭图题无法确认的数值或因果关系不作推断。"
                ),
                reading_question="这张图实际比较了什么，图中的变化是否足以支持正文对应结论？",
            )
            for item in reader.key_figures
        ]
        return PaperReaderAgentAnalysis(passages=passages, figures=figures)

    def _apply_reader_analysis(
        self,
        reader: PaperReader,
        analysis: PaperReaderAgentAnalysis,
    ) -> PaperReader:
        passage_map = {item.passage_id: item for item in analysis.passages}
        figure_map = {item.figure_id: item for item in analysis.figures}
        passages = [
            item.model_copy(
                update={
                    "why_selected": passage_map[item.id].analysis,
                    "reading_question": passage_map[item.id].reading_question,
                }
            )
            if item.id in passage_map
            else item
            for item in reader.selected_passages
        ]
        figures = [
            item.model_copy(
                update={
                    "why_important": figure_map[item.id].analysis,
                    "reading_question": figure_map[item.id].reading_question,
                }
            )
            if item.id in figure_map
            else item
            for item in reader.key_figures
        ]
        return reader.model_copy(update={"selected_passages": passages, "key_figures": figures})
