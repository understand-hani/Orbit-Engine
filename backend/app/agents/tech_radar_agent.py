from datetime import datetime, timezone
from typing import List

from app.schemas.common import VisualAsset, VisualType, VisualUsage
from app.schemas.tech_radar import RadarItem, RadarType, RecommendedDepth, TechRadarPayload


class MockTechRadarAgent:
    def generate(self, payload: TechRadarPayload) -> TechRadarPayload:
        if payload.radar_type == RadarType.product_strategy_radar:
            items = self._product_strategy_items()
            summary = "本周样例信号覆盖产品功能、技术路线、法规和具身智能产品。"
            top_signals = ["产品功能正在从单点能力展示转向系统体验闭环。"]
            follow_up = ["哪些产品信号能反向说明 WM/仿真/重建方向的工程价值？"]
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
