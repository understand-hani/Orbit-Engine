import SwiftUI

struct MoreView: View {
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

                Section("个人信息") {
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
        }
    }
}

#Preview {
    MoreView()
}
