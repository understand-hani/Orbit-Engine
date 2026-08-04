from typing import List

from fastapi import APIRouter, HTTPException

from app.schemas.profile import ResumeProfile, ResumeProfileCreate
from app.services.resume_service import ResumeService


router = APIRouter(tags=["resume"])
resume_service = ResumeService()


@router.post("/resume/profiles", response_model=ResumeProfile)
def create_resume_profile(request: ResumeProfileCreate) -> ResumeProfile:
    return resume_service.create(request)


@router.get("/resume/profiles", response_model=List[ResumeProfile])
def list_resume_profiles() -> List[ResumeProfile]:
    return resume_service.list()


@router.get("/resume/profiles/latest", response_model=ResumeProfile)
def latest_resume_profile() -> ResumeProfile:
    profile = resume_service.latest()
    if profile is None:
        raise HTTPException(status_code=404, detail="Resume profile not found")
    return profile


@router.get("/resume/profiles/{profile_id}", response_model=ResumeProfile)
def get_resume_profile(profile_id: str) -> ResumeProfile:
    profile = resume_service.get(profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Resume profile not found")
    return profile
