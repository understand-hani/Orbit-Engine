from datetime import datetime, timedelta, timezone

from app.schemas.source import SourceItem, SourceItemType, SourceSearchResponse, SourceType


class StaticResearchSearchService:
    def search_arxiv(self, query: str, max_results: int = 5) -> SourceSearchResponse:
        return SourceSearchResponse(
            query=query,
            source=SourceType.arxiv,
            items=[
                SourceItem(
                    id=f"2608.1000{index}",
                    source=SourceType.arxiv,
                    item_type=SourceItemType.paper,
                    title=f"3DGS World Model for Driving Research {index}",
                    url=f"https://arxiv.org/abs/2608.1000{index}",
                    summary=(
                        f"A real-source abstract about 3DGS, world models, driving video generation, "
                        f"and dynamic scene reconstruction for material {index}."
                    ),
                    authors=[f"Researcher {index}"],
                    published_at=datetime.now(timezone.utc) - timedelta(days=index),
                    tags=["cs.CV"],
                    extra={"pdf_url": f"https://arxiv.org/pdf/2608.1000{index}"},
                )
                for index in range(1, 3)
            ][:max_results],
            fetched_at=datetime.now(timezone.utc),
        )
