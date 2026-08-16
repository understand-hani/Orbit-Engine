from datetime import datetime, timezone
from typing import List, Optional

from app.db.repositories import SessionRepository
from app.schemas.common import TaskType
from app.schemas.research_feeder import Paper, PaperReader
from app.schemas.tech_radar import RadarItem, RadarItemMarkRequest, RadarUserMark
from app.agents.tech_radar_agent import MockTechRadarAgent
from app.db.repositories import UserContextRepository


class MaterialService:
    def __init__(self) -> None:
        self.sessions = SessionRepository()
        self.user_contexts = UserContextRepository()
        self.tech_radar_agent = MockTechRadarAgent()

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
    ) -> Optional[PaperReader]:
        session = self.sessions.get_by_id(session_id)
        if session is None or session.task_type != TaskType.research_feeder:
            return None
        if reader.paper_id != paper_id or not any(paper.id == paper_id for paper in session.payload.papers):
            return None

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
