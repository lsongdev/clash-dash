import SwiftUI

struct StatusSelectionIndicator: View {
    let statusColor: Color
    let isSelected: Bool
    var isChecking = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isChecking ? Color.secondary : statusColor.opacity(0.65), lineWidth: 1.5)
                .frame(width: 22, height: 22)

            Circle()
                .fill(isChecking ? Color.secondary : statusColor)
                .frame(width: 16, height: 16)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
