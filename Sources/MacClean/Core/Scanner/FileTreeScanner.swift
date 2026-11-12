import Foundation
import MacCleanKit

public actor FileTreeScanner {
    private let resourceKeys: Set<URLResourceKey> = [
        .fileSizeKey, .fileAllocatedSizeKey,
        .totalFileSizeKey, .totalFileAllocatedSizeKey,
        .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
        .contentModificationDateKey, .creationDateKey,
        .contentTypeKey, .nameKey, .isHiddenKey,
    ]

    public init() {}

    public nonisolated func scan(root: URL, skipHidden: Bool = false) -> AsyncStream<FileItem> {
        let keys = resourceKeys

        return AsyncStream { continuation in
            let options: FileManager.DirectoryEnumerationOptions = skipHidden
                ? [.skipsHiddenFiles, .skipsPackageDescendants]
                : [.skipsPackageDescendants]

            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: options
            ) else {
                continuation.finish()
                return
            }

            while let obj = enumerator.nextObject() {
                if Task.isCancelled { break }
                guard let fileURL = obj as? URL else { continue }
                guard let item = Self.makeFileItem(from: fileURL, keys: keys) else { continue }
                continuation.yield(item)
            }

            continuation.finish()
        }
    }

    public func topLevelSizes(
        root: URL,
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async -> [FileNode] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .fileAllocatedSizeKey],
            options: []
        ) else {
            return []
        }

        var nodes: [FileNode] = []
        var scanned = 0

        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if Task.isCancelled { break }

            let values = try? child.resourceValues(
                forKeys: [.isDirectoryKey, .nameKey, .fileAllocatedSizeKey])
            let isDir = values?.isDirectory ?? false
            let name = values?.name ?? child.lastPathComponent
            let ext = (name as NSString).pathExtension.lowercased()
            var total = UInt64(values?.fileAllocatedSize ?? 0)

            if isDir, let enumerator = fm.enumerator(
                at: child,
                includingPropertiesForKeys: [.fileAllocatedSizeKey],
                options: [.skipsPackageDescendants]
            ) {

                while let obj = enumerator.nextObject() {
                    if Task.isCancelled { break }
                    scanned += 1
                    if scanned % 2000 == 0 {
                        onProgress?(scanned)
                        await Task.yield()
                    }
                    guard let url = obj as? URL,
                          let v = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey])
                    else { continue }
                    total += UInt64(v.fileAllocatedSize ?? 0)
                }
            } else {
                scanned += 1
            }

            onProgress?(scanned)
            nodes.append(FileNode(
                url: child,
                name: name,
                size: total,
                isDirectory: isDir,
                fileExtension: ext
            ))
            await Task.yield()
        }

        return nodes
    }

    private static func makeFileItem(from url: URL, keys: Set<URLResourceKey>) -> FileItem? {
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }

        return FileItem(
            url: url,
            name: values.name ?? url.lastPathComponent,
            size: UInt64(values.totalFileSize ?? values.fileSize ?? 0),
            allocatedSize: UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0),
            isDirectory: values.isDirectory ?? false,
            isSymlink: values.isSymbolicLink ?? false,
            isPackage: values.isPackage ?? false,
            contentType: values.contentType,
            creationDate: values.creationDate,
            modificationDate: values.contentModificationDate
        )
    }
}

public final class FileNode: @unchecked Sendable {
    public let url: URL
    public let name: String
    public private(set) var size: UInt64
    public let isDirectory: Bool
    public let fileExtension: String
    public private(set) var children: [FileNode] = []
    public private(set) var totalSize: UInt64 = 0

    public init(url: URL, name: String, size: UInt64 = 0, isDirectory: Bool = true, fileExtension: String = "") {
        self.url = url
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.fileExtension = fileExtension
        self.totalSize = size
    }

    public func addChild(_ child: FileNode) {
        children.append(child)
    }

    @discardableResult
    public func computeTotalSize() -> UInt64 {
        if children.isEmpty {
            totalSize = size
        } else {
            totalSize = size + children.reduce(0) { $0 + $1.computeTotalSize() }
        }
        return totalSize
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}
