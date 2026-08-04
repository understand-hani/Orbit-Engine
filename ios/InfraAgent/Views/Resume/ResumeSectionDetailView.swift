import SwiftUI

struct ResumeSectionDetailView: View {
    let title: String
    let message: String

    var body: some View {
        List {
            Section(title) {
                Text(message)
            }
        }
        .navigationTitle(title)
    }
}
