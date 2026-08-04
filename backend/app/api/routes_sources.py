from fastapi import APIRouter, Query

from app.schemas.source import CombinedSearchResponse, SourceSearchResponse
from app.services.search_service import SearchService


router = APIRouter(tags=["sources"])
search_service = SearchService()


@router.get("/sources/arxiv", response_model=SourceSearchResponse)
def search_arxiv(q: str = Query(...), max_results: int = 5) -> SourceSearchResponse:
    return search_service.search_arxiv(q, max_results)


@router.get("/sources/github/repositories", response_model=SourceSearchResponse)
def search_github_repositories(q: str = Query(...), max_results: int = 5) -> SourceSearchResponse:
    return search_service.search_github_repositories(q, max_results)


@router.get("/sources/technical", response_model=CombinedSearchResponse)
def search_technical_sources(q: str = Query(...), max_results: int = 5) -> CombinedSearchResponse:
    return search_service.search_technical_sources(q, max_results)


@router.get("/sources/product-strategy", response_model=CombinedSearchResponse)
def search_product_strategy_sources(
    q: str = Query(...), max_results: int = 5
) -> CombinedSearchResponse:
    return search_service.search_product_strategy_sources(q, max_results)
