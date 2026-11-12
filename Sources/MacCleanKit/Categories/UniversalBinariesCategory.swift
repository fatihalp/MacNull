import Foundation

public struct UniversalBinariesCategory: JunkCategory {
    public init() {}

    public let scanCategory = ScanCategory.universalBinaries

    public var targets: [ScanTarget] { [] }
}
