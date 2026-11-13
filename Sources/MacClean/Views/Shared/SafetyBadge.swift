import SwiftUI
import MacCleanKit

struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Text(level.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch level {
        case .safe: Color(nsColor: .systemGreen)
        case .checkFirst: Color(nsColor: .systemOrange)
        }
    }
}
