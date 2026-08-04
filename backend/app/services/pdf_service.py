from typing import Optional

from app.schemas.research_feeder import PaperReader
from app.services.material_service import MaterialService


class PDFService:
    def __init__(self) -> None:
        self.materials = MaterialService()

    def get_reader(self, session_id: str) -> Optional[PaperReader]:
        return self.materials.get_paper_reader(session_id)
