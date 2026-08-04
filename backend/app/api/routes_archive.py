from typing import List

from fastapi import APIRouter, HTTPException

from app.schemas.profile import ResearchArchive, ResearchArchiveCreate
from app.services.archive_service import ArchiveService


router = APIRouter(tags=["archive"])
archive_service = ArchiveService()


@router.post("/research/archives", response_model=ResearchArchive)
def create_archive(request: ResearchArchiveCreate) -> ResearchArchive:
    return archive_service.create(request)


@router.get("/research/archives", response_model=List[ResearchArchive])
def list_archives() -> List[ResearchArchive]:
    return archive_service.list()


@router.get("/research/archives/{archive_id}", response_model=ResearchArchive)
def get_archive(archive_id: str) -> ResearchArchive:
    archive = archive_service.get(archive_id)
    if archive is None:
        raise HTTPException(status_code=404, detail="Research archive not found")
    return archive
