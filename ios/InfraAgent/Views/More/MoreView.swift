import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("更多") {
                    NavigationLink {
                        ResumeView()
                    } label: {
                        Label("简历", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreView()
}
