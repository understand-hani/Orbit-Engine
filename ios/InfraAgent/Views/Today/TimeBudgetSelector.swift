import SwiftUI

struct TimeBudgetSelector: View {
    @Binding var minutes: Int

    var body: some View {
        Stepper(value: $minutes, in: 15...180, step: 15) {
            Text("\(minutes) min")
                .font(.subheadline)
        }
    }
}

#Preview {
    TimeBudgetSelector(minutes: .constant(45))
        .padding()
}
