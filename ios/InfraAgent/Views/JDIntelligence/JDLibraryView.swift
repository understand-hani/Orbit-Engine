import SwiftUI

struct JDLibraryView: View {
    @State private var entries: [JDEntry] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingAddOptions = false
    @State private var isShowingAddJD = false
    @State private var isShowingImageImport = false
    @State private var draftEntry: JDEntryCreate?

    private let api = JDIntelligenceAPI()

    var filteredEntries: [JDEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return entries
        }
        let query = searchText.lowercased()
        return entries.filter { entry in
            [
                entry.company,
                entry.roleTitle,
                entry.city,
                entry.jdText,
                entry.mustHaveSkills.joined(separator: " "),
                entry.bonusSkills.joined(separator: " "),
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    var body: some View {
        List {
            if isLoading {
                LoadingView(title: "正在加载机会库")
            }

            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
            }

            Section("条目") {
                ForEach(filteredEntries) { entry in
                    NavigationLink {
                        JDEntryDetailView(entry: entry)
                    } label: {
                        JDEntryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("机会库")
        .searchable(text: $searchText, prompt: "公司、岗位、技能")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                Button {
                    draftEntry = nil
                    isShowingAddOptions = true
                } label: {
                    Image(systemName: "plus")
                }
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
        .sheet(isPresented: $isShowingAddJD) {
            JDEntryFormView(initialDraft: draftEntry) { request in
                do {
                    _ = try await api.createEntry(request)
                    await load()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
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
            await load()
        }
        .onAppear {
            Task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            entries = LocalJDPreferenceStore.apply(to: try await api.entries())
            if entries.isEmpty {
                entries = LocalJDPreferenceStore.apply(to: MockJDIntelligence.entries)
            }
            errorMessage = nil
        } catch {
            entries = LocalJDPreferenceStore.apply(to: MockJDIntelligence.entries)
            errorMessage = "正在使用本地 Mock 数据：\(error.localizedDescription)"
        }
    }
}
