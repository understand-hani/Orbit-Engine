import SwiftUI

struct ResumeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("结构化简历")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("简历信息编辑和 JD 关联证据会在核心任务流程稳定后接入。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("计划模块") {
                    NavigationLink {
                        ResumeSectionDetailView(title: "基础信息", message: "个人定位、教育背景、当前角色和目标岗位定位。")
                    } label: {
                        Label("基础信息", systemImage: "person")
                    }
                    NavigationLink {
                        ResumeSectionDetailView(title: "项目经历", message: "量产定位、SLAM/4DGS 研究、World Model 实践和 app 工程项目。")
                    } label: {
                        Label("项目经历", systemImage: "folder")
                    }
                    NavigationLink {
                        ResumeSectionDetailView(title: "技能", message: "GNSS/IMU 融合、SLAM、3D/4D 重建、Python/C++、模型训练和工程交付证据。")
                    } label: {
                        Label("技能", systemImage: "hammer")
                    }
                    NavigationLink {
                        ResumeSectionDetailView(title: "论文与开源", message: "论文进展、阅读归档、代码仓库、技术笔记和公开证据。")
                    } label: {
                        Label("论文与开源", systemImage: "doc.text")
                    }
                    NavigationLink {
                        ResumeSectionDetailView(title: "目标版本", message: "面向研究工程师、算法工程师和技术负责人方向的简历版本。")
                    } label: {
                        Label("目标版本", systemImage: "square.stack.3d.up")
                    }
                }
            }
            .navigationTitle("简历")
        }
    }
}

#Preview {
    ResumeView()
}
