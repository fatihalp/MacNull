import Foundation
import MacCleanKit

public struct SpaceLensModule: ScanModule {
    public let id = "space_lens"
    public var name: String { "Space Lens" }
    public let category = ModuleCategory.files
    public let includedInSmartScan = false

    public init() {}

    public func scan() async -> [ScanResult] { [] }
}

public extension VolumeInfo {
}
