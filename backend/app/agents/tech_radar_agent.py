from datetime import datetime, timezone
from typing import List, Optional

from app.schemas.common import VisualAsset, VisualType, VisualUsage
from app.schemas.source import SourceItem, SourceItemType, SourceType
from app.schemas.tech_radar import RadarItem, RadarSourcePassage, RadarType, RecommendedDepth, TechRadarPayload
from app.services.search_service import SearchService


RADAR_ITEM_LIMIT = 3


class MockTechRadarAgent:
    def __init__(self, search_service: Optional[SearchService] = None) -> None:
        self.search_service = search_service or SearchService()

    def generate(self, payload: TechRadarPayload) -> TechRadarPayload:
        if payload.radar_type == RadarType.product_strategy_radar:
            items = self._product_strategy_items()
            summary = "本周样例信号覆盖产品功能、技术路线、法规和具身智能产品。"
            top_signals = ["产品功能正在从单点能力展示转向系统体验闭环。"]
            follow_up = ["哪些产品信号能反向说明 WM/仿真/重建方向的工程价值？"]
        else:
            items = self._technical_method_items_from_search(payload)
            if items:
                summary = "本周技术 Radar 已基于 arXiv / GitHub 公开源生成外部信号。"
                top_signals = [items[0].summary]
                follow_up = ["哪条真实外部信号值得转入周四/周五的 Deep Dive？"]
            else:
                items = self._technical_method_items()
                summary = "本周样例信号覆盖 WM、生成式驾驶视频、3D/4D 表征和仿真评测方法。"
                top_signals = ["技术方法正在从单帧感知走向时空生成、闭环评测和可控仿真。"]
                follow_up = ["哪些技术方法值得进入周四/周五的精读候选？"]

        return payload.model_copy(
            update={
                "source_refresh_time": datetime.now(timezone.utc),
                "digest": payload.digest.model_copy(
                    update={
                        "summary": summary,
                        "items": items,
                        "top_signals": top_signals,
                        "noise_filtered": ["纯融资新闻", "只有口号、没有技术证据的发布稿"],
                        "follow_up_questions": follow_up,
                    }
                ),
            }
        )

    def _technical_method_items_from_search(self, payload: TechRadarPayload) -> List[RadarItem]:
        queries = self._technical_queries(payload)
        collected: List[SourceItem] = []
        seen_urls = set()
        for query in queries:
            try:
                response = self.search_service.search_technical_sources(query, max_results=RADAR_ITEM_LIMIT)
            except Exception:
                continue
            for source_item in response.items:
                if source_item.id.endswith("_search_error") or "error" in source_item.tags:
                    continue
                dedupe_key = str(source_item.url) if source_item.url else f"{source_item.source.value}:{source_item.id}"
                if dedupe_key in seen_urls:
                    continue
                seen_urls.add(dedupe_key)
                collected.append(source_item)
                if len(collected) >= RADAR_ITEM_LIMIT:
                    break
            if len(collected) >= RADAR_ITEM_LIMIT:
                break
        return [self._radar_item_from_source(item, index) for index, item in enumerate(collected[:RADAR_ITEM_LIMIT], start=1)]

    def _technical_queries(self, payload: TechRadarPayload) -> List[str]:
        topics = [topic.strip() for topic in payload.scope.topics if topic.strip()]
        research_groups = [group.strip() for group in payload.scope.research_groups if group.strip()]
        seeds = topics[:3] + research_groups[:2]
        if not seeds:
            seeds = ["driving world model", "4D Gaussian Splatting autonomous driving"]
        queries: List[str] = []
        for seed in seeds:
            if any(token.lower() in seed.lower() for token in ["4d", "gaussian", "world model", "driving"]):
                queries.append(seed)
            else:
                queries.append(f"{seed} autonomous driving")
        return queries[:4]

    def _radar_item_from_source(self, source_item: SourceItem, index: int) -> RadarItem:
        source_label = source_item.source.value
        summary = source_item.summary.strip() or "该来源缺少摘要，需要打开原文确认核心内容。"
        signal_type = self._signal_type(source_item)
        title = source_item.title.strip() or f"{source_label} source {index}"
        tags = [source_label, signal_type, *source_item.tags[:4]]
        return RadarItem(
            id=f"radar_real_{source_label}_{source_item.id}".replace("/", "_"),
            radar_type=RadarType.technical_method_radar,
            title=title,
            source=source_label,
            url=source_item.url,
            signal_type=signal_type,
            summary=self._summary_for_source(source_item),
            technical_substance=summary,
            marketing_noise=self._noise_for_source(source_item),
            why_it_matters=self._why_source_matters(source_item),
            source_passages=self._source_passages(source_item, summary),
            visuals=[],
            recommended_depth=self._recommended_depth(source_item),
            tags=tags,
        )

    def _signal_type(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.arxiv or source_item.item_type == SourceItemType.paper:
            return "论文"
        if source_item.source == SourceType.github or source_item.item_type == SourceItemType.repo:
            return "开源项目"
        return "外部材料"

    def _summary_for_source(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.arxiv:
            return f"发现一篇近期论文：{source_item.title}。"
        if source_item.source == SourceType.github:
            stars = source_item.extra.get("stars")
            star_text = f"，stars={stars}" if stars is not None else ""
            return f"发现一个近期更新的开源项目：{source_item.title}{star_text}。"
        return f"发现一条外部技术材料：{source_item.title}。"

    def _why_source_matters(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.arxiv:
            return "论文信号可用于判断技术路线、方法假设、评价指标和是否值得进入 Deep Dive。"
        if source_item.source == SourceType.github:
            return "开源项目信号可用于判断代码复现入口、工程活跃度、数据/评估接口和可实践性。"
        return "外部材料可用于补充当前计划的技术证据和下一步阅读候选。"

    def _noise_for_source(self, source_item: SourceItem) -> str:
        if source_item.source == SourceType.github and not source_item.summary.strip():
            return "仓库缺少描述，需打开 README 判断是否只是占位项目。"
        if source_item.source == SourceType.arxiv and not source_item.summary.strip():
            return "论文摘要缺失，需打开 arXiv 页面确认内容。"
        return "仍需检查原文是否有实验、代码、数据或清晰问题定义，避免只凭标题判断。"

    def _recommended_depth(self, source_item: SourceItem) -> RecommendedDepth:
        if source_item.source == SourceType.arxiv:
            return RecommendedDepth.read
        if source_item.source == SourceType.github:
            stars = source_item.extra.get("stars")
            if isinstance(stars, int) and stars >= 100:
                return RecommendedDepth.read
        return RecommendedDepth.skim

    def _source_passages(self, source_item: SourceItem, summary: str) -> List[RadarSourcePassage]:
        passages = [
            RadarSourcePassage(
                id=f"{source_item.id}_p1".replace("/", "_"),
                title="来源摘要",
                excerpt=summary,
                analysis="这是从公开源 metadata 中抽出的核心摘要，用来初筛是否值得打开原文。",
                source_url=source_item.url,
                location=f"{source_item.source.value} metadata",
            ),
            RadarSourcePassage(
                id=f"{source_item.id}_p2".replace("/", "_"),
                title="来源线索",
                excerpt=self._source_metadata_text(source_item),
                analysis="这段用于定位材料类型、发布时间、作者或仓库活跃度，帮助判断是否适合进入本周 Deep Dive。",
                source_url=source_item.url,
                location="source metadata",
            ),
            RadarSourcePassage(
                id=f"{source_item.id}_p3".replace("/", "_"),
                title="Agent 初筛",
                excerpt=self._why_source_matters(source_item),
                analysis="这是 Agent 对该来源和当前 Radar 任务关系的初步判断，后续需要用原文细读验证。",
                source_url=source_item.url,
                location="agent routing",
            ),
        ]
        tag_text = "、".join(source_item.tags[:8])
        if tag_text:
            passages.append(
                RadarSourcePassage(
                    id=f"{source_item.id}_p4".replace("/", "_"),
                    title="主题标签",
                    excerpt=tag_text,
                    analysis="标签用于快速判断它是否落在当前方向的关键词范围内。",
                    source_url=source_item.url,
                    location="source tags",
                )
            )
        return passages[:5]

    def _source_metadata_text(self, source_item: SourceItem) -> str:
        lines = [f"来源：{source_item.source.value}", f"类型：{self._signal_type(source_item)}"]
        if source_item.authors:
            lines.append(f"作者：{'、'.join(source_item.authors[:5])}")
        if source_item.published_at:
            lines.append(f"发布时间：{source_item.published_at.date().isoformat()}")
        if source_item.updated_at:
            lines.append(f"更新时间：{source_item.updated_at.date().isoformat()}")
        if source_item.extra:
            details = []
            for key in ["stars", "forks", "language", "pdf_url"]:
                value = source_item.extra.get(key)
                if value:
                    details.append(f"{key}={value}")
            if details:
                lines.append("补充信息：" + "，".join(details))
        return "\n".join(lines)

    def _product_strategy_items(self) -> List[RadarItem]:
        return [
            RadarItem(
                id="mock_product_signal_001",
                radar_type=RadarType.product_strategy_radar,
                title="某车企更新城区 NOA 功能边界",
                source="mock_official_release",
                signal_type="功能更新",
                summary="样例：城区 NOA 从覆盖范围扩大转向复杂路口、绕行和泊车衔接体验。",
                technical_substance="重点看感知、规控、地图依赖和端到端模块是否有实质变化。",
                marketing_noise="只说覆盖城市数量但没有展示 corner case 和失败边界，信息价值有限。",
                why_it_matters="它能帮助判断自动驾驶产品路线是否需要更强的仿真、世界模型或场景生成能力。",
                source_passages=[
                    RadarSourcePassage(
                        id="mock_product_signal_001_p1",
                        title="功能边界",
                        excerpt="城区 NOA 的公开信号从覆盖城市数量转向复杂路口、绕行和泊车衔接等连续体验。",
                        analysis="这段适合作为产品路线变化的摘录：它说明值得观察的不只是覆盖范围，而是端到端体验链条是否变长。",
                        location="mock release / feature overview",
                    ),
                    RadarSourcePassage(
                        id="mock_product_signal_001_p2",
                        title="验证重点",
                        excerpt="需要继续确认感知、规控、地图依赖和端到端模块是否有实质变化。",
                        analysis="这段是后续 Deep Dive 的验证入口，能把营销描述转成可检查的技术问题。",
                        location="agent extraction",
                    ),
                    RadarSourcePassage(
                        id="mock_product_signal_001_p3",
                        title="噪音边界",
                        excerpt="如果材料只强调城市数量，却没有展示 corner case 和失败边界，信息价值有限。",
                        analysis="这段提醒不要把覆盖规模直接等同于能力进展，需要看失败场景和约束条件。",
                        location="agent noise filter",
                    ),
                ],
                visuals=[
                    VisualAsset(
                        id="mock_visual_product_001",
                        type=VisualType.screenshot,
                        caption="样例功能截图：用于展示 NOA 功能边界和用户可感知变化。",
                        source="mock",
                        usage=VisualUsage.product_screenshot,
                    )
                ],
                recommended_depth=RecommendedDepth.read,
                tags=["ADAS", "Company Strategy", "Product"],
            ),
            RadarItem(
                id="mock_product_signal_002",
                radar_type=RadarType.product_strategy_radar,
                title="某具身智能团队展示家庭机器人操作能力",
                source="mock_demo_video",
                signal_type="产品能力展示",
                summary="样例：机器人展示抓取、导航和多步骤任务执行能力。",
                technical_substance="重点看空间理解、任务规划、泛化场景和失败案例是否被展示。",
                marketing_noise="剪辑视频如果缺少连续成功率和真实环境约束，不能直接说明产品成熟。",
                why_it_matters="具身智能产品信号能帮助判断空间智能、世界模型和动态场景理解的长期价值。",
                source_passages=[
                    RadarSourcePassage(
                        id="mock_product_signal_002_p1",
                        title="能力链条",
                        excerpt="演示信号集中在抓取、导航和多步骤任务执行能力。",
                        analysis="这段用于判断机器人能力是否已经从单点动作走向任务链条。",
                        location="mock demo video",
                    ),
                    RadarSourcePassage(
                        id="mock_product_signal_002_p2",
                        title="验证重点",
                        excerpt="应关注空间理解、任务规划、泛化场景和失败案例是否被展示。",
                        analysis="这段把观看演示视频的重点转成可验证维度。",
                        location="agent extraction",
                    ),
                    RadarSourcePassage(
                        id="mock_product_signal_002_p3",
                        title="成熟度边界",
                        excerpt="缺少连续成功率和真实环境约束时，剪辑视频不能直接说明产品成熟。",
                        analysis="这段用于过滤展示型视频中的营销噪音。",
                        location="agent noise filter",
                    ),
                ],
                visuals=[
                    VisualAsset(
                        id="mock_visual_product_002",
                        type=VisualType.video,
                        caption="样例演示视频封面：用于观察机器人实际任务链条。",
                        source="mock",
                        usage=VisualUsage.evidence,
                    )
                ],
                recommended_depth=RecommendedDepth.skim,
                tags=["Embodied Intelligence", "Product"],
            ),
        ]

    def _technical_method_items(self) -> List[RadarItem]:
        return [
            RadarItem(
                id="mock_technical_signal_001",
                radar_type=RadarType.technical_method_radar,
                title="某研究团队提出驾驶世界模型的新训练框架",
                source="mock_paper",
                signal_type="论文",
                summary="样例：方法针对多视角驾驶视频生成中的时序一致性和可控性问题。",
                technical_substance="重点看输入条件、时序建模、动作控制和评价指标是否完整。",
                marketing_noise="只展示漂亮视频但没有闭环评价或消融，技术可信度不足。",
                why_it_matters="可作为周四/周五 research feeder 的候选阅读方向。",
                source_passages=[
                    RadarSourcePassage(
                        id="mock_technical_signal_001_p1",
                        title="问题定义",
                        excerpt="方法关注多视角驾驶视频生成中的时序一致性和可控性问题。",
                        analysis="这段是判断是否进入 Deep Dive 的核心：它直接对应 driving WM 的生成质量和控制输入。",
                        location="mock paper abstract",
                    ),
                    RadarSourcePassage(
                        id="mock_technical_signal_001_p2",
                        title="方法检查点",
                        excerpt="需要检查输入条件、时序建模、动作控制和评价指标是否完整。",
                        analysis="这段可直接转成阅读 checklist，避免只看 demo 视频。",
                        location="agent extraction",
                    ),
                    RadarSourcePassage(
                        id="mock_technical_signal_001_p3",
                        title="证据缺口",
                        excerpt="如果论文只展示漂亮视频但没有闭环评价或消融，技术可信度不足。",
                        analysis="这段是噪音过滤依据，适合归档为风险判断。",
                        location="agent noise filter",
                    ),
                ],
                visuals=[
                    VisualAsset(
                        id="mock_visual_technical_001",
                        type=VisualType.pdf_figure,
                        caption="样例方法图：用于理解世界模型训练 pipeline。",
                        source="mock",
                        usage=VisualUsage.method_figure,
                    )
                ],
                recommended_depth=RecommendedDepth.deep_discuss,
                tags=["World Model", "Driving Video Generation"],
            ),
            RadarItem(
                id="mock_technical_signal_002",
                radar_type=RadarType.technical_method_radar,
                title="某开源项目更新 4D 表征动态场景 benchmark",
                source="mock_github",
                signal_type="开源项目",
                summary="样例：benchmark 增加动态物体、相机运动和时序一致性指标。",
                technical_substance="重点看数据格式、指标定义、baseline 和复现实验是否完整。",
                marketing_noise="如果只有 leaderboard 没有评估脚本和数据说明，工程价值有限。",
                why_it_matters="它可能为 4DGS / WM 方向判断提供可量化比较入口。",
                source_passages=[
                    RadarSourcePassage(
                        id="mock_technical_signal_002_p1",
                        title="Benchmark 更新",
                        excerpt="benchmark 增加动态物体、相机运动和时序一致性指标。",
                        analysis="这段是该推送的关键事实，直接关系到 4DGS / WM 方向如何评价动态场景。",
                        location="mock github release",
                    ),
                    RadarSourcePassage(
                        id="mock_technical_signal_002_p2",
                        title="复现检查点",
                        excerpt="需要检查数据格式、指标定义、baseline 和复现实验是否完整。",
                        analysis="这段适合用来判断该 benchmark 是否能真正服务当前研究计划。",
                        location="agent extraction",
                    ),
                    RadarSourcePassage(
                        id="mock_technical_signal_002_p3",
                        title="工程价值边界",
                        excerpt="如果只有 leaderboard，没有评估脚本和数据说明，工程价值有限。",
                        analysis="这段用于判断是否暂存或忽略，避免被榜单表象吸引。",
                        location="agent noise filter",
                    ),
                ],
                visuals=[
                    VisualAsset(
                        id="mock_visual_technical_002",
                        type=VisualType.chart,
                        caption="样例 benchmark 图：用于比较不同方法的时序一致性。",
                        source="mock",
                        usage=VisualUsage.benchmark,
                    )
                ],
                recommended_depth=RecommendedDepth.read,
                tags=["4DGS", "Benchmark", "Simulation"],
            ),
        ]
