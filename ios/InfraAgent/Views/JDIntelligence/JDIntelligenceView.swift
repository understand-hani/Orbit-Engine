import SwiftUI

struct JDIntelligenceView: View {
    @StateObject private var viewModel = JDIntelligenceViewModel()
    @State private var isShowingAddOptions = false
    @State private var isShowingAddJD = false
    @State private var isShowingImageImport = false
    @State private var draftEntry: JDEntryCreate?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JD 智能分析")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("集中管理市场信号、能力状态、任务状态和候选行动。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if viewModel.isLoading {
                    LoadingView(title: "正在加载 JD 智能分析")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                    }
                }

                Section("概览") {
                    HStack {
                        MetricCell(title: "JD", value: "\(viewModel.entries.count)")
                        MetricCell(title: "星标", value: "\(viewModel.favoriteEntries.count)")
                        MetricCell(title: "高优先级", value: "\(viewModel.highPriorityEntries.count)")
                        MetricCell(title: "行动", value: "\(viewModel.suggestedActions.count)")
                    }
                    .padding(.vertical, 4)
                }

                Section("工作区") {
                    Button {
                        draftEntry = nil
                        isShowingAddOptions = true
                    } label: {
                        Label("添加 JD", systemImage: "plus.rectangle.on.rectangle")
                    }

                    NavigationLink {
                        JDLibraryView()
                    } label: {
                        Label("JD 库", systemImage: "books.vertical")
                    }

                    NavigationLink {
                        CandidateActionsView()
                    } label: {
                        Label("候选行动", systemImage: "checklist")
                    }

                    NavigationLink {
                        SkillStackView(snapshot: viewModel.skillSnapshot)
                    } label: {
                        Label("能力栈", systemImage: "chart.bar")
                    }

                    NavigationLink {
                        TaskStateView(snapshot: viewModel.taskSnapshot)
                    } label: {
                        Label("任务状态", systemImage: "list.bullet.rectangle")
                    }
                }

                Section("Agent 讨论") {
                    NavigationLink {
                        JDLocalAgentDiscussionView()
                    } label: {
                        Label("和 Agent 讨论", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            .navigationTitle("JD")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddJD) {
                JDEntryFormView(initialDraft: draftEntry) { request in
                    _ = await viewModel.createEntry(request)
                }
            }
            .sheet(isPresented: $isShowingAddOptions) {
                JDAddOptionsView(onManualInput: {
                    draftEntry = nil
                    isShowingAddJD = true
                }, onImageInput: {
                    isShowingImageImport = true
                })
            }
            .sheet(isPresented: $isShowingImageImport) {
                JDImageImportView { draft in
                    draftEntry = draft
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isShowingAddJD = true
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .onAppear {
                Task { await viewModel.load() }
            }
        }
    }
}

struct MetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
