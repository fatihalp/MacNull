import Foundation

public enum SafetyLevel: Sendable, Equatable {
    case safe
    case checkFirst

    public var label: String {
        switch self {
        case .safe: "Safe to Clean"
        case .checkFirst: "Check First"
        }
    }
}

public extension ScanCategory {
    var safetyLevel: SafetyLevel {
        autoSelect ? .safe : .checkFirst
    }
}
