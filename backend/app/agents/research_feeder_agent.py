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
from app.schemas.user_context import RecommendationContext, UserContext


class MockResearchFeederAgent:
    def generate(self, payload: ResearchFeederPayload, user_context: UserContext) -> ResearchFeederPayload:
        primary_material = user_context.materials[0]
        candidate_materials = user_context.materials[1:3]
        candidate_material_ids = [material.id for material in candidate_materials]
        recommendation = RecommendationContext(
            derived_from=["个人情况/简历摘要", "当前工作/学习计划", "材料源偏好", "最近 session 记录"],
            tracking_keywords=user_context.plan.tracking_keywords,
            related_plan=user_context.plan.weekly_focus,
            user_preference=" / ".join(user_context.preferences.fields),
            why_this_material_now=(
                f"当前计划要求先验证 Deep Dive 闭环；材料 `{primary_material.title}` "
                f"能在 {user_context.preferences.session_time_budget_min} 分钟内产出摘要、洞察和下一步。"
            ),
        )
        primary = Paper(
            id=primary_material.id,
            title=primary_material.title,
            authors=primary_material.authors_or_owner,
            venue=primary_material.source_type.value,
            year=2026,
            url=primary_material.url,
            summary=primary_material.summary,
            why_selected=primary_material.why_selected or recommendation.why_this_material_now,
            visuals=[
                VisualAsset(
                    id="mock_paper_visual_001",
                    type=VisualType.pdf_figure,
                    caption="样例 teaser：展示多视角驾驶视频生成效果。",
                    source="mock",
                    usage=VisualUsage.teaser,
                )
            ],
            tags=primary_material.tags,
        )
        candidate_material = candidate_materials[0] if candidate_materials else primary_material
        candidate = Paper(
            id=candidate_material.id,
            title=candidate_material.title,
            authors=candidate_material.authors_or_owner,
            venue=candidate_material.source_type.value,
            year=2026,
            url=candidate_material.url,
            summary=candidate_material.summary,
            why_selected=candidate_material.why_selected,
            visuals=[
                VisualAsset(
                    id="mock_paper_visual_002",
                    type=VisualType.pdf_figure,
                    caption="样例方法图：展示动态 4D Gaussian pipeline。",
                    source="mock",
                    usage=VisualUsage.method_figure,
                )
            ],
            tags=candidate_material.tags,
        )
        primary_reader = PaperReader(
            paper_id=primary.id,
            pdf_url=primary.pdf_url,
            sections=[
                ReadingSection(
                    id="mock_section_abstract",
                    section_name="Abstract / Introduction",
                    read_mode=ReadMode.skim,
                    extracted_text=primary_material.summary,
                    why_read="先确认这份材料为什么和当前计划相关。",
                    agent_instruction="读完后用一句话判断它能推进哪个当前任务。",
                    knowledge_points=["材料目标", "和当前计划的关系", "可形成的输出"],
                ),
                ReadingSection(
                    id="mock_section_method",
                    section_name="Method",
                    page_start=3,
                    page_end=5,
                    read_mode=ReadMode.deep_read,
                    extracted_text=f"当前计划：{user_context.plan.weekly_focus}。下一步：{user_context.plan.next_action}",
                    why_read="把材料内容转成可执行行动，而不是开放式阅读。",
                    agent_instruction="摘出输入、输出、证据和下一步。",
                    knowledge_points=["输入输出", "关键证据", "下一步行动"],
                ),
            ],
            selected_passages=[
                SelectedPassage(
                    id="mock_passage_001",
                    paper_id=primary.id,
                    page=3,
                    section_name="Method",
                    text_excerpt=primary_material.summary[:120],
                    why_selected="这段可以作为本次 Deep Dive 的起点。",
                    reading_question="这份材料能帮助当前计划推进到哪一步？",
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
                        caption="样例材料图：后续可接 PDF 图、网页截图、repo 图或用户上传资料截图。",
                        source="mock",
                        usage=VisualUsage.method_figure,
                    ),
                    why_important="Deep Dive 可以处理 PDF、网页、repo、官方文档或手动材料，不绑定论文平台。",
                    reading_question="这份材料的输入、输出、证据和下一步分别是什么？",
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
                    extracted_text=candidate_material.summary,
                    why_read="把候选材料作为对照或后续追踪材料。",
                    agent_instruction="判断它是否比主材料更适合今天处理。",
                    knowledge_points=["候选材料", "对照价值", "后续追踪"],
                ),
                ReadingSection(
                    id="mock_candidate_section_representation",
                    section_name="Scene Representation",
                    page_start=3,
                    page_end=6,
                    read_mode=ReadMode.normal,
                    extracted_text=candidate_material.why_selected,
                    why_read="理解它和当前计划的关系。",
                    agent_instruction="只记录它为什么暂时作为候选，不展开深读。",
                    knowledge_points=["候选原因", "暂不深读", "下一轮 Radar/Weekly Studio"],
                ),
            ],
            selected_passages=[
                SelectedPassage(
                    id="mock_candidate_passage_001",
                    paper_id=candidate.id,
                    page=4,
                    section_name="Scene Representation",
                    text_excerpt=candidate_material.summary[:120],
                    why_selected="候选材料用于证明 Deep Dive 支持多来源材料包。",
                    reading_question="这份候选材料应该今天读，还是进入下周计划？",
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
                        caption="样例候选材料图：可以来自 PDF、网页、repo 或公开资料。",
                        source="mock",
                        usage=VisualUsage.method_figure,
                    ),
                    why_important="候选材料用于展示材料包不是单一文章。",
                    reading_question="它和当前计划的关系是否强于主材料？",
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
                    target_archive=["learning_note", "plan_evidence", "weekly_studio"],
                    tags=primary_material.tags or user_context.plan.tracking_keywords,
                ),
                "materials": user_context.materials,
                "primary_material_id": primary_material.id,
                "candidate_material_ids": candidate_material_ids,
                "recommendation_context": recommendation,
                "user_profile": user_context.profile,
                "active_plan": user_context.plan,
                "user_preferences": user_context.preferences,
            }
        )
