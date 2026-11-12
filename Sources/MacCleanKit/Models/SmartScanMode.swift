import Foundation

public enum SmartScanMode: String, CaseIterable, Identifiable, Sendable {
    case safe = "safe"
    case deep = "deep"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .safe: String(localized: "Safe Clean")
        case .deep: String(localized: "Deep Clean")
        }
    }

    public var subtitle: String {
        switch self {
        case .safe:
            String(localized: "Cleans temporary system and application caches safely. Project builds, source code, and developer packages remain untouched.")
        case .deep:
            String(localized: "For low-disk emergencies: removes regenerable project build outputs (target, build, .dart_tool) and heavy developer caches to recover maximum space.")
        }
    }

    public var icon: String {
        switch self {
        case .safe: "shield.checkmark.fill"
        case .deep: "bolt.shield.fill"
        }
    }

    public var badge: String {
        switch self {
        case .safe: String(localized: "Recommended")
        case .deep: String(localized: "Maximum Space")
        }
    }
}
