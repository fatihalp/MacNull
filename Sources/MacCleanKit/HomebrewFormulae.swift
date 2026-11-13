import Foundation

public struct HomebrewFormula: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let bytes: UInt64

    public init(name: String, bytes: UInt64) {
        self.name = name
        self.bytes = bytes
    }
}

public enum HomebrewFormulae {
    public static let brewCandidatePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    public static func parseLeaves(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(isSafeName)
    }

    public static func isSafeName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(first) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@._+-"))
        return name.unicodeScalars.allSatisfy(allowed.contains)
    }

    public static func uninstallArguments(name: String) -> [String]? {
        isSafeName(name) ? ["uninstall", "--formula", name] : nil
    }
}
