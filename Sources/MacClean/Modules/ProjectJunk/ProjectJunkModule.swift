import Foundation
import MacCleanKit

public struct ProjectJunkModule: ScanModule {
    public let id = "projectJunk"
    public var name: String { "Project Junk" }
    public let category = ModuleCategory.cleanup
    public var includedInSmartScan: Bool { true }

    private let scanner = ProjectJunkScanner()

    public init() {}

    public func scan() async -> [ScanResult] {
        await scan(onProgress: nil)
    }

    public func scan(
        onProgress: (@Sendable (_ phase: String, _ count: Int, _ bytes: UInt64, _ fraction: Double) -> Void)?
    ) async -> [ScanResult] {
        let roots = ProjectJunkScanner.defaultProjectRoots()
        guard !roots.isEmpty else { return [] }
        let scanner = self.scanner
        let results = await Task.detached(priority: .userInitiated) {
            let items = scanner.scan(roots: roots, onProgress: { progress, count, bytes in
                onProgress?(name, count, bytes, progress)
            })
            return scanner.asScanResults(items)
        }.value
        let totalCount = results.reduce(0) { $0 + $1.fileCount }
        let totalBytes = results.reduce(0) { $0 + $1.totalSize }
        onProgress?("Done", totalCount, totalBytes, 1.0)
        return results
    }
}
