import Foundation
import MacCleanKit

public enum CleanActions {

    @discardableResult
    public static func executeUserClean(
        results: [ScanResult],
        selectedItems: Set<URL>,
        engine: CleaningEngine,
        onProgress: (@Sendable (CleaningEngine.Progress) -> Void)? = nil
    ) async -> CleaningEngine.CleanResult {
        var deleteItems: [FileItem] = []
        var thinItems: [FileItem] = []
        for result in results {
            for item in result.items where selectedItems.contains(item.url) {
                switch result.category {
                case .universalBinaries:
                    thinItems.append(item)
                default:
                    deleteItems.append(item)
                }
            }
        }

        let dedupedItems = Self.prunedToParents(deleteItems)
        let totalItemsCount = max(dedupedItems.count, 1)

        onProgress?(CleaningEngine.Progress(
            totalItems: totalItemsCount,
            processedItems: 0,
            removedSoFar: 0,
            freedBytesSoFar: 0
        ))

        let deleteResult = await engine.clean(
            items: dedupedItems,
            mode: .permanent,
            onProgress: onProgress
        )
        if Task.isCancelled {
            return deleteResult
        }

        let thinResult = await thinSelectedBinaries(thinItems)
        return deleteResult.merging(thinResult)
    }

    private static func thinSelectedBinaries(
        _ items: [FileItem]
    ) async -> CleaningEngine.CleanResult {
        guard !items.isEmpty else {
            return CleaningEngine.CleanResult(
                removedCount: 0, freedBytes: 0, removedURLs: [],
                errors: [], skippedCount: 0
            )
        }
        let op = ThinAppBundleOperation()
        let targetArch = BundleHostInfo.current.hostArch
        var bundleCount = 0
        var savedBytes: UInt64 = 0
        var removedURLs = Set<URL>()
        var errors: [CleaningEngine.CleanError] = []
        for item in items {
            if Task.isCancelled { break }

            do {
                let r = try await op.thin(bundle: item.url, to: targetArch)
                if r.binariesThinned > 0 {
                    bundleCount += 1
                }
                savedBytes += r.bytesSaved
                removedURLs.insert(item.url)
                for (path, msg) in r.perBinaryErrors {
                    errors.append(CleaningEngine.CleanError(
                        path: path, error: "binary thin failed: \(msg)"
                    ))
                }
            } catch {
                errors.append(CleaningEngine.CleanError(
                    path: item.url.path(percentEncoded: false),
                    error: "bundle thin failed: \(error.localizedDescription)"
                ))
            }
        }
        return CleaningEngine.CleanResult(
            removedCount: bundleCount,
            freedBytes: savedBytes,
            removedURLs: removedURLs,
            errors: errors,
            skippedCount: 0
        )
    }

    @discardableResult
    public static func executeUserClean(
        items: [FileItem],
        selectedItems: Set<URL>,
        engine: CleaningEngine,
        onProgress: (@Sendable (CleaningEngine.Progress) -> Void)? = nil
    ) async -> CleaningEngine.CleanResult {
        let filtered = items.filter { selectedItems.contains($0.url) }
        let deduped = Self.prunedToParents(filtered)
        let result = await engine.clean(items: deduped, mode: .permanent,
                                  onProgress: onProgress)
        return result
    }

    static func prunedToParents(_ items: [FileItem]) -> [FileItem] {
        guard items.count > 1 else { return items }
        let sorted = items.sorted {
            $0.url.path(percentEncoded: false).count < $1.url.path(percentEncoded: false).count
        }
        var keptPaths: Set<String> = []
        keptPaths.reserveCapacity(sorted.count)
        var kept: [FileItem] = []
        kept.reserveCapacity(sorted.count)
        for item in sorted {
            let rawPath = item.url.path(percentEncoded: false)
            let path = (rawPath as NSString).standardizingPath
            guard !keptPaths.contains(path) else { continue }
            var parentPath = (path as NSString).deletingLastPathComponent
            var hasAncestor = false
            while parentPath != "/" && !parentPath.isEmpty {
                if keptPaths.contains(parentPath) {
                    hasAncestor = true
                    break
                }
                let next = (parentPath as NSString).deletingLastPathComponent
                if next == parentPath { break }
                parentPath = next
            }
            if !hasAncestor {
                kept.append(item)
                keptPaths.insert(path)
            }
        }
        return kept
    }
}
