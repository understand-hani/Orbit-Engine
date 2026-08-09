from fastapi import APIRouter

from app.schemas.user_context import UserContext, UserMaterial, UserMaterialCreate
from app.services.user_context_service import UserContextService


router = APIRouter(tags=["user-context"])
service = UserContextService()


@router.get("/user-context", response_model=UserContext)
def get_user_context() -> UserContext:
    return service.get_or_create()


@router.put("/user-context", response_model=UserContext)
def save_user_context(context: UserContext) -> UserContext:
    return service.save(context)


@router.post("/user-context/materials", response_model=UserMaterial)
def add_user_material(request: UserMaterialCreate) -> UserMaterial:
    return service.add_material(request)
