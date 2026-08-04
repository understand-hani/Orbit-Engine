from typing import List, Optional

from app.db.repositories import SessionRepository
from app.schemas.common import TaskType
from app.schemas.research_feeder import Paper, PaperReader
from app.schemas.tech_radar import RadarItem


class MaterialService:
    def __init__(self) -> None:
        self.sessions = SessionRepository()

    def list_radar_items(self, session_id: str) -> Optional[List[RadarItem]]:
        session = self.sessions.get_by_id(session_id)
        if session is None:
            return None
        if session.task_type != TaskType.tech_radar:
            return []
        return session.payload.digest.items

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
