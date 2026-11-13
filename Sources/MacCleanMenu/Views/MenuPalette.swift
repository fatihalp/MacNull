import SwiftUI

enum MenuPalette {
    static let card = Color(nsColor: .controlBackgroundColor)
    static let teal = Color.accentColor
    static let yellow = Color.orange
    static let green = Color.accentColor
    static let red = Color.red
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static func barColor(_ v: Double) -> Color {
        if v > 0.85 { return .red }
        if v > 0.65 { return yellow }
        return teal
    }
}
