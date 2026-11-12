import Foundation
import Darwin
import MacCleanKit

final class ProgressAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var bytes: UInt64 = 0
    private var lastReportUptime: UInt64 = 0
    private let onProgress: (@Sendable (Int, UInt64) -> Void)?

    init(onProgress: (@Sendable (Int, UInt64) -> Void)?) {
        self.onProgress = onProgress
    }

    func add(count: Int, bytes: UInt64) {
        guard let onProgress else { return }
        lock.lock()
        self.count += count
        self.bytes += bytes
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now - lastReportUptime
        let shouldReport = elapsed > 50_000_000
        if shouldReport {
            lastReportUptime = now
            let currentCount = self.count
            let currentBytes = self.bytes
            lock.unlock()
            onProgress(currentCount, currentBytes)
        } else {
            lock.unlock()
        }
    }

    func flush() {
        guard let onProgress else { return }
        lock.lock()
        let currentCount = self.count
        let currentBytes = self.bytes
        lock.unlock()
        onProgress(currentCount, currentBytes)
    }
}

public actor TargetedScanner {
    private let resourceKeys: [URLResourceKey] = [
        .fileSizeKey, .fileAllocatedSizeKey,
        .totalFileSizeKey, .totalFileAllocatedSizeKey,
        .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
        .contentModificationDateKey, .creationDateKey,
        .contentTypeKey, .nameKey,
    ]

    public init() {}

    public func scan(
        targets: [ScanTarget],
        onProgress: (@Sendable (_ itemsFound: Int, _ bytesFound: UInt64) -> Void)? = nil
    ) async -> [FileItem] {
        await scanReportingPermissions(targets: targets, onProgress: onProgress).items
    }

    public func scanReportingPermissions(
        targets: [ScanTarget],
        onProgress: (@Sendable (_ itemsFound: Int, _ bytesFound: UInt64) -> Void)? = nil
    ) async -> ScanOutcome {
        let keys = resourceKeys
        let accumulator = ProgressAccumulator(onProgress: onProgress)
        return await withTaskGroup(of: (items: [FileItem], deniedPath: URL?).self) { group in
            for target in targets {
                group.addTask {
                    Self.scanTarget(target, keys: keys, onBatch: { count, bytes in
                        accumulator.add(count: count, bytes: bytes)
                    })
                }
            }

            var allItems: [FileItem] = []
            var seenURLs = Set<URL>()
            var deniedPaths: [URL] = []
            for await result in group {
                for item in result.items where seenURLs.insert(item.url).inserted {
                    allItems.append(item)
                }
                if let denied = result.deniedPath {
                    deniedPaths.append(denied)
                }
            }
            accumulator.flush()
            return ScanOutcome(items: allItems, permissionDeniedPaths: deniedPaths)
        }
    }

    private static func isPermissionDenied(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        if access(path, R_OK) == 0 { return false }
        return errno == EPERM || errno == EACCES
    }

    private static func scanTarget(
        _ target: ScanTarget,
        keys: [URLResourceKey],
        onBatch: (@Sendable (Int, UInt64) -> Void)? = nil
    ) -> (items: [FileItem], deniedPath: URL?) {
        let fm = FileManager.default

        guard fm.fileExists(atPath: target.path.path(percentEncoded: false)) else {
            return ([], nil)
        }

        if isPermissionDenied(target.path) {
            return ([], target.path)
        }

        var results: [FileItem] = []
        let activeConv = ProcessInfo.processInfo.environment["ANTIGRAVITY_CONVERSATION_ID"]
        let hasActiveConv = !(activeConv?.isEmpty ?? true)
        let checkActiveConv = hasActiveConv && target.path.path(percentEncoded: false).contains(".gemini")

        if target.recursive {
            guard let enumerator = fm.enumerator(
                at: target.path,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            ) else { return ([], nil) }

            while let obj = enumerator.nextObject() {
                if Task.isCancelled { break }
                guard let fileURL = obj as? URL else { continue }

                if let maxDepth = target.maxDepth {
                    let relPath = fileURL.path(percentEncoded: false)
                        .dropFirst(target.path.path(percentEncoded: false).count)
                    let depth = relPath.components(separatedBy: "/").count - 1
                    if depth > maxDepth {
                        enumerator.skipDescendants()
                        continue
                    }
                }

                if target.skipHiddenDirectories && ScanTarget.isHiddenEntry(fileURL) {
                    let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                if target.isExcludedPath(fileURL) {
                    enumerator.skipDescendants()
                    continue
                }

                if checkActiveConv, let activeConv {
                    if fileURL.path(percentEncoded: false).contains(activeConv) {
                        enumerator.skipDescendants()
                        continue
                    }
                }

                if matchesExcludePattern(url: fileURL, target: target) {
                    let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                if matchesTarget(url: fileURL, target: target),
                   let item = makeFileItem(from: fileURL, keys: keys) {
                    results.append(item)
                    onBatch?(1, item.size)
                }
            }
        } else {
            guard let contents = try? fm.contentsOfDirectory(
                at: target.path,
                includingPropertiesForKeys: keys
            ) else { return ([], nil) }

            for fileURL in contents {
                if Task.isCancelled { break }
                if target.isExcludedPath(fileURL) { continue }
                if matchesTarget(url: fileURL, target: target),
                   let item = makeFileItem(from: fileURL, keys: keys, computeDirSizeIfNeeded: true) {
                    results.append(item)
                    onBatch?(1, item.size)
                }
            }
        }

        return (results, nil)
    }

    private static func matchesExcludePattern(url: URL, target: ScanTarget) -> Bool {
        let name = url.lastPathComponent
        for pattern in target.excludePatterns {
            if name.localizedCaseInsensitiveContains(pattern) {
                return true
            }
        }
        return false
    }

    private static func matchesTarget(url: URL, target: ScanTarget) -> Bool {
        if matchesExcludePattern(url: url, target: target) {
            return false
        }

        if let extensions = target.fileExtensions {
            let ext = url.pathExtension.lowercased()
            if !extensions.contains(ext) && !extensions.isEmpty {
                return false
            }
        }

        if target.minSize != nil || target.minAge != nil || target.maxAge != nil {
            guard let values = try? url.resourceValues(forKeys: Set([
                .fileSizeKey, .contentModificationDateKey,
            ])) else { return false }

            if let minSize = target.minSize {
                let size = UInt64(values.fileSize ?? 0)
                if size < minSize { return false }
            }

            if let modDate = values.contentModificationDate {
                let age = Date().timeIntervalSince(modDate)
                if let minAge = target.minAge, age < minAge { return false }
                if let maxAge = target.maxAge, age > maxAge { return false }
            }
        }

        return true
    }

    public static func directorySize(at url: URL) -> UInt64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            if let values = try? fileURL.resourceValues(forKeys: Set(keys)),
               values.isRegularFile == true {
                total += UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }

    private static func makeFileItem(from url: URL, keys: [URLResourceKey], computeDirSizeIfNeeded: Bool = false) -> FileItem? {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }

        let isDir = values.isDirectory ?? false
        var size = UInt64(values.totalFileSize ?? values.fileSize ?? 0)
        var allocated = UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)

        if isDir && computeDirSizeIfNeeded {
            let dirSize = directorySize(at: url)
            if dirSize > 0 {
                size = dirSize
                allocated = dirSize
            }
        }

        return FileItem(
            url: url,
            name: values.name ?? url.lastPathComponent,
            size: size,
            allocatedSize: allocated,
            isDirectory: isDir,
            isSymlink: values.isSymbolicLink ?? false,
            isPackage: values.isPackage ?? false,
            contentType: values.contentType,
            creationDate: values.creationDate,
            modificationDate: values.contentModificationDate,
            inode: 0,
            deviceID: 0
        )
    }
}
