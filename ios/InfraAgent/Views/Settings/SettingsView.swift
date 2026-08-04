import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section("后端") {
                LabeledContent("已保存", value: viewModel.savedBackendBaseURL)
                TextField("后端 URL", text: $viewModel.backendBaseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let message = viewModel.backendURLMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("保存后端 URL") {
                    viewModel.saveBackendBaseURL()
                }
                .buttonStyle(.borderless)

                Button("恢复默认后端 URL") {
                    viewModel.resetBackendBaseURL()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Section("每周节奏") {
                LabeledContent("周一", value: "产品/战略技术雷达")
                LabeledContent("周二", value: "技术方法雷达")
                LabeledContent("周三", value: "JD 与职业分析")
                LabeledContent("周四", value: "研究材料：选择并开始")
                LabeledContent("周五", value: "研究材料：继续与归档")
            }
        }
        .navigationTitle("设置")
        .onAppear {
            viewModel.reload()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
