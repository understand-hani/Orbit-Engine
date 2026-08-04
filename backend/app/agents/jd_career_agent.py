from app.schemas.jd_analysis import (
    CapabilityAction,
    JDAnalysis,
    JDAnalysisPayload,
    MatchLevel,
    ResumeRevisionSuggestion,
    RoleType,
    TimingRecommendation,
)


class MockJDCareerAgent:
    def generate(self, payload: JDAnalysisPayload) -> JDAnalysisPayload:
        jd_input = payload.jd_input
        jd_text = jd_input.jd_text
        lower_text = jd_text.lower()
        coordination_terms = ["项目管理", "供应商", "协调", "推进", "tpm", "project management"]
        technical_terms = ["world model", "世界模型", "3dgs", "4dgs", "slam", "重建", "pytorch", "仿真", "自动驾驶"]
        has_coordination_red_flag = any(term in lower_text or term in jd_text for term in coordination_terms)
        technical_hits = [term for term in technical_terms if term in lower_text or term in jd_text]

        role_type = RoleType.research_engineer if technical_hits else RoleType.unclear
        if has_coordination_red_flag and not technical_hits:
            role_type = RoleType.tpm_variant

        match_level = MatchLevel.medium_high if technical_hits else MatchLevel.medium
        if role_type == RoleType.tpm_variant:
            match_level = MatchLevel.low

        red_flags = []
        if has_coordination_red_flag:
            red_flags.append("JD 中出现项目管理、供应商或协调推进信号，需要确认是否是 TPM 变体。")

        company = jd_input.company or "未填写公司"
        role_title = jd_input.role_title or "未填写岗位"

        return payload.model_copy(
            update={
                "jd_input": jd_input,
                "analysis": JDAnalysis(
                    role_type=role_type,
                    match_level=match_level,
                    technical_overlap=[
                        "GNSS/IMU 融合定位和自动驾驶工程经验",
                        "SLAM 几何直觉",
                        "正在建设 3DGS / 4DGS / WM 项目证据",
                    ],
                    red_flags=red_flags,
                    fatal_gaps=[],
                    trainable_gaps=[
                        "深度学习训练工程和实验纪律需要更多可展示记录。",
                        "WM / driving video generation 需要至少跑通一个轻量 pipeline。",
                    ],
                    timing_recommendation=TimingRecommendation.build_contact_only,
                    overall_recommendation=(
                        f"Mock analysis for {company} - {role_title}: 当前建议先保持联系，"
                        "用 Week 7-12 的 reconstruction / WM 输出补强项目证据后再判断是否投递。"
                    ),
                ),
                "resume_revision_suggestions": [
                    ResumeRevisionSuggestion(
                        id="mock_resume_suggestion_001",
                        target_section="project_experience",
                        current_text="负责高精定位相关项目推进。",
                        suggested_text=(
                            "负责量产级 GNSS/IMU 融合高精定位模块的问题定位、算法验证和工程闭环，"
                            "支撑自动驾驶定位系统稳定交付。"
                        ),
                        reason="把表达从项目推进改成技术责任、算法模块和交付证据。",
                        risk="需要后续用具体指标或案例支撑，避免泛泛而谈。",
                    )
                ],
                "capability_actions": [
                    CapabilityAction(
                        id="mock_capability_action_001",
                        title="补一条 4DGS / WM 可展示项目证据",
                        reason="JD 强调 3D/4D reconstruction 和 world model，需要代码、视频或指标佐证。",
                        related_gap="WM / 4DGS hands-on evidence",
                        suggested_timeframe="2-4 weeks",
                    )
                ],
            }
        )
