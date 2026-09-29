import SwiftUI

struct StatusSelectionIndicator: View {
    let statusColor: Color
    let isSelected: Bool
    var isChecking = false

    var body: some View {
        HStack(spacing: 6) {
            if isChecking {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
                .frame(width: 16, height: 16)
        }
        .accessibilityHidden(true)
    }
}
