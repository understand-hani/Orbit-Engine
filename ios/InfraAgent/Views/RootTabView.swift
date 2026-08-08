import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            HistoryView()
                .tabItem {
                    Label("归档", systemImage: "archivebox")
                }

            PlanView()
                .tabItem {
                    Label("计划", systemImage: "list.bullet.clipboard")
                }

            MoreView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
    }
}

struct PlanView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("计划")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("维护长期目标、本周重点和当前任务，供 Agent 生成今日 session 时引用。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("当前目标") {
                    LabeledContent("长期目标", value: "建立一个可持续的领域探索闭环")
                    LabeledContent("本周重点", value: "跑通 Deep Dive 主链路")
                    LabeledContent("下一步", value: "让 Today 读取后端并进入工作区")
                }

                Section("Tracking Keywords") {
                    TagRow(tags: ["learning workflow", "material source", "agent loop"])
                }
            }
            .navigationTitle("计划")
        }
    }
}

#Preview {
    RootTabView()
}
