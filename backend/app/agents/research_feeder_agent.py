from app.schemas.common import VisualAsset, VisualType, VisualUsage
from app.schemas.research_feeder import (
    ArchivePlan,
    KeyFigure,
    Paper,
    PaperNotes,
    PaperReader,
    ReadingPack,
    ReadingSection,
    ReadMode,
    ResearchDayRole,
    ResearchFeederPayload,
    SelectedPassage,
    UsableFor,
)


class MockResearchFeederAgent:
    def generate(self, payload: ResearchFeederPayload) -> ResearchFeederPayload:
        primary = Paper(
            id="mock_paper_primary",
            title="Mock Driving World Model with Temporally Consistent Scene Generation",
            authors=["Mock Author A", "Mock Author B"],
            venue="arXiv",
            year=2026,
            url="https://arxiv.org/abs/2410.13571",
            pdf_url="https://arxiv.org/pdf/2410.13571",
            summary="样例主论文：关注驾驶视频生成中的时序一致性、可控条件和场景评测。",
            why_selected="它适合用来理解生成线的输入输出、训练监督和评价方式。",
            visuals=[
                VisualAsset(
                    id="mock_paper_visual_001",
                    type=VisualType.pdf_figure,
                    caption="样例 teaser：展示多视角驾驶视频生成效果。",
                    source="mock",
                    usage=VisualUsage.teaser,
                )
            ],
            tags=["World Model", "Driving Video Generation", "Temporal Consistency"],
        )
        candidate = Paper(
            id="mock_paper_candidate",
            title="Mock 4D Gaussian Scene Representation for Dynamic Driving Scenes",
            authors=["Mock Author C"],
            venue="arXiv",
            year=2026,
            url="https://arxiv.org/abs/2312.07920",
            pdf_url="https://arxiv.org/pdf/2312.07920",
            summary="样例候选论文：关注动态驾驶场景的 4D 表征与时序一致性。",
            why_selected="它可作为 reconstruction 路线对照，帮助比较生成和重建的技术边界。",
            visuals=[
                VisualAsset(
                    id="mock_paper_visual_002",
                    type=VisualType.pdf_figure,
                    caption="样例方法图：展示动态 4D Gaussian pipeline。",
                    source="mock",
                    usage=VisualUsage.method_figure,
                )
            ],
            tags=["4DGS", "Dynamic Reconstruction"],
        )
        primary_reader = PaperReader(
            paper_id=primary.id,
            pdf_url=primary.pdf_url,
            sections=[
                ReadingSection(
                    id="mock_section_abstract",
                    section_name="Abstract / Introduction",
                    read_mode=ReadMode.skim,
                    extracted_text="本文关注驾驶世界模型如何在给定历史观测和动作条件时，生成时间上更一致的未来场景。引言部分强调，单帧质量不足以评价驾驶生成模型，时序一致性、可控性和下游评测价值同样关键。",
                    why_read="先确认论文要解决的问题和方法定位。",
                    agent_instruction="读完后用一句话判断它是 generation、reconstruction 还是 hybrid。",
                    knowledge_points=["world model 的输入输出定义", "驾驶视频生成的时序一致性", "generation 与 reconstruction 的边界"],
                ),
                ReadingSection(
                    id="mock_section_method",
                    section_name="Method",
                    page_start=3,
                    page_end=5,
                    read_mode=ReadMode.deep_read,
                    extracted_text="方法部分描述了一个条件生成 pipeline：使用历史多视角图像、动作或轨迹条件、场景 token 作为输入，预测未来多视角驾驶视频。核心关注点是如何把运动条件注入时序模块，以及如何避免未来帧中目标位置漂移和外观不一致。",
                    why_read="理解输入、输出、条件控制和时序建模。",
                    agent_instruction="重点摘出模型输入、训练监督、生成目标和关键模块。",
                    knowledge_points=["条件生成结构", "时序模块", "训练监督", "评估指标"],
                ),
            ],
            selected_passages=[
                SelectedPassage(
                    id="mock_passage_001",
                    paper_id=primary.id,
                    page=3,
                    section_name="Method",
                    text_excerpt="模型使用历史多视角图像、动作条件和场景 token 预测未来视角。",
                    why_selected="这段定义了生成线的输入输出形式。",
                    reading_question="这个输入输出形式和 4DGS 重建 pipeline 的差别是什么？",
                )
            ],
            key_figures=[
                KeyFigure(
                    id="mock_key_figure_001",
                    paper_id=primary.id,
                    page=4,
                    figure_label="Figure 2",
                    visual=VisualAsset(
                        id="mock_key_figure_visual_001",
                        type=VisualType.pdf_figure,
                        caption="样例 Figure 2：整体 world model 训练和生成 pipeline。",
                        source="mock",
                        usage=VisualUsage.method_figure,
                    ),
                    why_important="这张图是理解论文输入、输出和模块关系的入口。",
                    reading_question="模型的可控条件、时序模块和生成目标分别是什么？",
                )
            ],
        )
        candidate_reader = PaperReader(
            paper_id=candidate.id,
            pdf_url=candidate.pdf_url,
            sections=[
                ReadingSection(
                    id="mock_candidate_section_problem",
                    section_name="Problem Setup",
                    read_mode=ReadMode.skim,
                    extracted_text="该类动态重建论文通常从多帧、多视角驾驶数据出发，试图构建可渲染的 3D/4D 表征。核心挑战是运动物体、遮挡、视角变化和稀疏观测共同导致的 temporal inconsistency。",
                    why_read="先看它如何定义动态驾驶场景重建问题。",
                    agent_instruction="重点判断它依赖哪些先验：相机、LiDAR、车辆框或位姿。",
                    knowledge_points=["动态/静态分解", "moving-camera 数据", "遮挡与时序一致性"],
                ),
                ReadingSection(
                    id="mock_candidate_section_representation",
                    section_name="Scene Representation",
                    page_start=3,
                    page_end=6,
                    read_mode=ReadMode.normal,
                    extracted_text="表征部分通常将静态背景和动态目标分开建模：背景负责长期稳定结构，动态目标通过目标级或时间相关参数表达运动。你需要关注它是否依赖 GT box，以及这种分解能否被 SLAM 几何一致性过滤替代。",
                    why_read="理解静态背景和动态目标分别如何建模。",
                    agent_instruction="摘出 static/dynamic 分解方式，并和你的 SLAM 几何过滤方案对照。",
                    knowledge_points=["Gaussian scene representation", "foreground/background decomposition", "SLAM geometric filtering 替代标注的可能性"],
                ),
            ],
            selected_passages=[
                SelectedPassage(
                    id="mock_candidate_passage_001",
                    paper_id=candidate.id,
                    page=4,
                    section_name="Scene Representation",
                    text_excerpt="动态驾驶场景通常需要把静态背景和运动目标分开建模，再处理遮挡和多视角一致性。",
                    why_selected="这段对应你的 reconstruction line 核心问题。",
                    reading_question="这里的动态分离依赖标注还是几何一致性？能否替换成你的 SLAM filtering？",
                )
            ],
            key_figures=[
                KeyFigure(
                    id="mock_candidate_key_figure_001",
                    paper_id=candidate.id,
                    page=3,
                    figure_label="Figure 1",
                    visual=VisualAsset(
                        id="mock_candidate_key_figure_visual_001",
                        type=VisualType.pdf_figure,
                        caption="样例 Figure 1：动态驾驶场景 Gaussian 表征 pipeline。",
                        source="mock",
                        usage=VisualUsage.method_figure,
                    ),
                    why_important="这张图帮助你把重建线和生成线的输入输出差异放在一起比较。",
                    reading_question="它的 foreground/background 分解和 StreetGaussian baseline 的关系是什么？",
                )
            ],
        )
        notes = PaperNotes()
        if payload.research_day_role == ResearchDayRole.continue_and_archive:
            notes = PaperNotes(
                input_output="输入：历史多视角图像和动作条件；输出：未来驾驶场景视频。",
                core_idea="用时序生成模型学习场景演化，服务仿真和规划评测。",
                evidence="样例证据：视频质量、时序一致性和与 baseline 的对比。",
                relation_to_my_plan="用于理解 WM/生成线和 4DGS 重建线的差异。",
                usable_for=[UsableFor.research_note, UsableFor.blog, UsableFor.resume],
                next_action="补读实验设置，判断是否值得找真实 repo 跑 demo。",
            )

        return payload.model_copy(
            update={
                "reading_pack": ReadingPack(
                    primary_paper_id=primary.id,
                    candidate_paper_id=candidate.id,
                    selection_reason="主论文用于理解生成线，候选论文用于和 4DGS 动态重建线对照。",
                    reading_goal="周四/周五至少读完主论文，形成输入输出、方法、证据和方向判断。",
                ),
                "papers": [primary, candidate],
                "paper_reader": primary_reader,
                "paper_readers": [primary_reader, candidate_reader],
                "notes": notes,
                "archive_plan": ArchivePlan(
                    target_archive=["research_note", "blog", "resume_material"],
                    tags=["World Model", "Generation", "4DGS"],
                ),
            }
        )
