import Foundation

public struct ScanTarget: Sendable, Equatable {
    public let path: URL
    public let recursive: Bool
    public let maxDepth: Int?
    public let fileExtensions: Set<String>?
    public let minAge: TimeInterval?
    public let maxAge: TimeInterval?
    public let minSize: UInt64?
    public let excludePatterns: [String]

    public let skipHiddenDirectories: Bool

    public let excludedPaths: [URL]

    public init(
        path: URL,
        recursive: Bool = true,
        maxDepth: Int? = nil,
        fileExtensions: Set<String>? = nil,
        minAge: TimeInterval? = nil,
        maxAge: TimeInterval? = nil,
        minSize: UInt64? = nil,
        excludePatterns: [String] = [],
        skipHiddenDirectories: Bool = false,
        excludedPaths: [URL] = []
    ) {
        self.path = path
        self.recursive = recursive
        self.maxDepth = maxDepth

        self.fileExtensions = fileExtensions.map { Set($0.map { $0.lowercased() }) }
        self.minAge = minAge
        self.maxAge = maxAge
        self.minSize = minSize
        self.excludePatterns = excludePatterns
        self.skipHiddenDirectories = skipHiddenDirectories
        self.excludedPaths = excludedPaths
    }

    public func isExcludedPath(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        return excludedPaths.contains {
            PathExclusion.isInside(path, root: $0.path(percentEncoded: false))
        }
    }

    public static func isHiddenEntry(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".")
    }
}
