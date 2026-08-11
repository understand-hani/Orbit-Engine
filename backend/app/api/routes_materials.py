from typing import List

from fastapi import APIRouter, HTTPException

from app.schemas.research_feeder import Paper, PaperReader
from app.schemas.tech_radar import RadarItem, RadarItemMarkRequest
from app.services.material_service import MaterialService
from app.services.pdf_service import PDFService


router = APIRouter(tags=["materials"])
material_service = MaterialService()
pdf_service = PDFService()


@router.get("/sessions/{session_id}/radar-items", response_model=List[RadarItem])
def list_radar_items(session_id: str) -> List[RadarItem]:
    items = material_service.list_radar_items(session_id)
    if items is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return items


@router.post("/sessions/{session_id}/radar-items/{item_id}/mark", response_model=RadarItem)
def mark_radar_item(session_id: str, item_id: str, request: RadarItemMarkRequest) -> RadarItem:
    item = material_service.update_radar_item_mark(session_id, item_id, request)
    if item is None:
        raise HTTPException(status_code=404, detail="Radar item not found")
    return item


@router.post("/sessions/{session_id}/radar-items/{item_id}/archive", response_model=RadarItem)
def archive_radar_item(session_id: str, item_id: str, request: RadarItemMarkRequest) -> RadarItem:
    item = material_service.archive_radar_item(session_id, item_id, request.archive_note)
    if item is None:
        raise HTTPException(status_code=404, detail="Radar item not found")
    return item


@router.get("/sessions/{session_id}/papers", response_model=List[Paper])
def list_papers(session_id: str) -> List[Paper]:
    papers = material_service.list_papers(session_id)
    if papers is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return papers


@router.get("/sessions/{session_id}/papers/{paper_id}", response_model=Paper)
def get_paper(session_id: str, paper_id: str) -> Paper:
    paper = material_service.get_paper(session_id, paper_id)
    if paper is None:
        raise HTTPException(status_code=404, detail="Paper not found")
    return paper


@router.get("/sessions/{session_id}/paper-reader", response_model=PaperReader)
def get_paper_reader(session_id: str) -> PaperReader:
    reader = pdf_service.get_reader(session_id)
    if reader is None:
        raise HTTPException(status_code=404, detail="Paper reader not found")
    return reader
