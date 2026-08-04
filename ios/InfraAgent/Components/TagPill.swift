import SwiftUI

struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.10), in: Capsule())
            .foregroundStyle(.blue)
    }
}

#Preview {
    TagPill(text: "World Model")
        .padding()
}
