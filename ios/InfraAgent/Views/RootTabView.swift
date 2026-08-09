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
    @State private var context: UserContext?
    @State private var isLoading = false
    @State private var message: String?

    private let api = UserContextAPI()

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

                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let context {
                    Section("当前目标") {
                        LabeledContent("长期目标", value: context.plan.longTermGoal)
                        LabeledContent("目标周期", value: context.plan.targetCycle.isEmpty ? "未设置" : context.plan.targetCycle)
                    }

                    Section("全周期计划") {
                        if context.plan.fullCyclePlan.isEmpty {
                            Text("还没有全周期计划。去“我的 > 方向配置”生成后会显示在这里。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(context.plan.fullCyclePlan.enumerated()), id: \.offset) { index, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("阶段 \(index + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("第一周计划") {
                        LabeledContent("本周重点", value: context.plan.weeklyFocus)
                        LabeledContent("下一步", value: context.plan.nextAction)
                    }

                    Section("当前任务") {
                        if context.plan.activeTasks.isEmpty {
                            Text("暂无任务")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(context.plan.activeTasks, id: \.self) { task in
                                Text(task)
                            }
                        }
                    }

                    Section("Tracking Keywords") {
                        TagRow(tags: context.plan.trackingKeywords)
                    }
                } else if isLoading {
                    Section {
                        ProgressView("加载计划中")
                    }
                } else {
                    Section {
                        Text("暂无计划数据")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("计划")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("编辑") {
                        DirectionProfileView()
                    }
                }
            }
            .task {
                await load()
            }
            .refreshable {
                await load(force: true)
            }
        }
    }

    private func load(force: Bool = false) async {
        if isLoading { return }
        if context != nil && !force { return }
        isLoading = true
        defer { isLoading = false }

        do {
            context = try await api.get()
            message = "这里展示的是当前已保存到用户上下文的计划，Agent 会直接引用这些内容。"
        } catch {
            message = "加载计划失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    RootTabView()
}
