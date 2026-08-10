import Foundation
import SwiftUI

struct MoreView: View {
    @State private var context: UserContext?
    @State private var isLoading = false
    @State private var message: String?

    private let api = UserContextAPI()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("我的")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("管理个人情况、偏好、材料来源和后端连接。")
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

                Section("个人信息") {
                    if let context {
                        MoreProfileSummaryView(context: context)
                    } else if isLoading {
                        ProgressView("加载个人情况中")
                    } else {
                        Text("暂无个人情况。可先进入方向配置生成。")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        DirectionProfileView()
                    } label: {
                        Label("方向配置", systemImage: "scope")
                    }

                    NavigationLink {
                        ResumeView()
                    } label: {
                        Label("个人情况 / 简历摘要", systemImage: "person.text.rectangle")
                    }
                }

                Section("应用设置") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("后端与偏好设置", systemImage: "gearshape")
                    }
                }

                Section("本地数据") {
                    LabeledContent("资料记录", value: "本地优先")
                    LabeledContent("后端地址", value: AppConfig.backendBaseURL.host ?? AppConfig.backendBaseURL.absoluteString)
                }
            }
            .navigationTitle("我的")
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
            message = nil
        } catch {
            message = "加载个人情况失败：\(error.localizedDescription)"
        }
    }
}

private struct MoreProfileSummaryView: View {
    let context: UserContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayName)
                    .font(.headline)
                Spacer()
                Text("个人情况")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SummaryLine(title: "长期目标", value: context.profile.goal)
            SummaryLine(title: "当前阶段", value: context.profile.currentStage)
            SummaryLine(title: "背景 / 已有基础", value: context.profile.backgroundSummary)
        }
        .padding(.vertical, 6)
    }

    private var displayName: String {
        let value = context.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "未设置姓名" : value
    }
}

private struct SummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayValue)
                .font(.subheadline)
                .foregroundStyle(displayValue == "未设置" ? .secondary : .primary)
                .lineLimit(3)
        }
    }

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未设置" : trimmed
    }
}

#Preview {
    MoreView()
}
