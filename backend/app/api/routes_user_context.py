from fastapi import APIRouter

from app.schemas.user_context import UserContext, UserMaterial, UserMaterialCreate
from app.services.user_context_service import UserContextService


router = APIRouter(tags=["user-context"])
service = UserContextService()


@router.get("/user-context", response_model=UserContext)
def get_user_context() -> UserContext:
    return service.get_or_create()


@router.post("/user-context/materials", response_model=UserMaterial)
def add_user_material(request: UserMaterialCreate) -> UserMaterial:
    return service.add_material(request)
