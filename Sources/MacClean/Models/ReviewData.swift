import Foundation
import AppKit
import MacCleanKit

enum ReviewPath {

    @inline(__always)
    static func precedes(_ a: String, _ b: String) -> Bool {
        let aCount = a.utf8.count
        let bCount = b.utf8.count
        let minCount = min(aCount, bCount)

        let contiguousResult: Bool? = a.utf8.withContiguousStorageIfAvailable { aBuf in
            b.utf8.withContiguousStorageIfAvailable { bBuf in
                for i in 0..<minCount {
                    let ax = aBuf[i]
                    let bx = bBuf[i]
                    if ax != bx {
                        let av = (ax == 0x2F ? 0 : ax)
                        let bv = (bx == 0x2F ? 0 : bx)
                        return av < bv
                    }
                }
                return aCount < bCount
            }
        } ?? nil

        if let contiguousResult {
            return contiguousResult
        }

        var ai = a.utf8.makeIterator()
        var bi = b.utf8.makeIterator()
        while true {
            let x = ai.next()
            let y = bi.next()
            guard let x else { return y != nil }
            guard let y else { return false }
            if x != y {
                return (x == 0x2F ? 0 : x) < (y == 0x2F ? 0 : y)
            }
        }
    }

    @inline(__always)
    static func isDescendant(_ path: String, of base: String) -> Bool {
        let pCount = path.utf8.count
        let bCount = base.utf8.count
        guard pCount > bCount else { return false }
        if base == "/" { return true }

        let contiguousResult: Bool? = path.utf8.withContiguousStorageIfAvailable { pBuf in
            base.utf8.withContiguousStorageIfAvailable { bBuf in
                for i in 0..<bCount {
                    if pBuf[i] != bBuf[i] { return false }
                }
                return pBuf[bCount] == 0x2F
            }
        } ?? nil

        if let contiguousResult {
            return contiguousResult
        }

        let p = path.utf8
        let b = base.utf8
        guard p.starts(with: b) else { return false }
        return p[p.index(p.startIndex, offsetBy: b.count)] == 0x2F
    }

    static func isSameOrDescendant(_ path: String, of base: String) -> Bool {
        path == base || isDescendant(path, of: base)
    }

    static func normalized(_ url: URL) -> String {
        var p = url.path(percentEncoded: false)
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    static func firstComponent(of path: String, below base: String) -> Substring {
        let offset = base == "/" ? 1 : base.utf8.count + 1
        let start = path.utf8.index(path.utf8.startIndex, offsetBy: offset)
        let rest = path[start...]
        if let slash = rest.firstIndex(of: "/") { return rest[..<slash] }
        return rest
    }

    static func join(_ base: String, _ component: some StringProtocol) -> String {
        base == "/" ? "/" + component : base + "/" + component
    }

    static func lastComponent(_ path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return path }
        let name = path[path.index(after: slash)...]
        return name.isEmpty ? path : String(name)
    }

    static func commonDirectory(_ paths: [String]) -> String {
        guard var common = paths.first?.split(separator: "/", omittingEmptySubsequences: true) else { return "/" }
        for path in paths.dropFirst() {
            let parts = path.split(separator: "/", omittingEmptySubsequences: true)
            var n = 0
            while n < common.count, n < parts.count, common[n] == parts[n] { n += 1 }
            common = Array(common.prefix(n))
        }
        return "/" + common.joined(separator: "/")
    }
}

struct ReviewItem: Sendable {
    let url: URL
    let path: String
    let name: String
    let size: UInt64
    let isDirectory: Bool

    init(_ item: FileItem) {
        url = item.url
        path = ReviewPath.normalized(item.url)
        name = item.name
        size = item.size
        isDirectory = item.isDirectory
    }
}

struct ReviewNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    let basePath: String
    let range: Range<Int>
    let size: UInt64

    let isLeaf: Bool

    let iconPath: String

    let appIsRunning: Bool

    let autoSelect: Bool

    let isSensitive: Bool
    let isAIConversation: Bool
    let isOldVersion: Bool

    init(
        id: String,
        name: String,
        basePath: String,
        range: Range<Int>,
        size: UInt64,
        isLeaf: Bool,
        iconPath: String,
        appIsRunning: Bool,
        autoSelect: Bool = true,
        isSensitive: Bool? = nil,
        isAIConversation: Bool? = nil,
        isOldVersion: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.basePath = basePath
        self.range = range
        self.size = size
        self.isLeaf = isLeaf
        self.iconPath = iconPath
        self.appIsRunning = appIsRunning
        self.autoSelect = autoSelect
        self.isSensitive = isSensitive ?? SensitiveRemnantMatcher.isSensitive(path: basePath)
        self.isAIConversation = isAIConversation ?? AIConversationMatcher.isConversation(path: basePath)
        self.isOldVersion = isOldVersion ?? Self.isOldVersionPath(basePath)
    }

    private static func isOldVersionPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.contains("/.rustup/toolchains/") && !lower.contains("/stable-") {
            return true
        }
        if lower.contains("/.gradle/wrapper/dists/") {
            return true
        }
        return false
    }
}

struct ReviewCategory: Identifiable, Sendable {
    let id: Int
    let category: ScanCategory
    let autoSelect: Bool
    let range: Range<Int>
    let size: UInt64
    let groups: [ReviewNode]
}

struct ReviewSection: Identifiable, Sendable {
    let id: String
    let name: String
    var categoryIDs: [Int]
    let size: UInt64
    let itemCount: Int
}

final class ReviewData: Sendable {
    let items: [ReviewItem]
    let categories: [ReviewCategory]
    let sections: [ReviewSection]
    let totalSize: UInt64

    init(items: [ReviewItem], categories: [ReviewCategory], sections: [ReviewSection]) {
        self.items = items
        self.categories = categories
        self.sections = sections
        self.totalSize = sections.reduce(0) { $0 + $1.size }
    }

    func children(of node: ReviewNode) -> [ReviewNode] {
        let base = node.basePath
        var out: [ReviewNode] = []
        var i = node.range.lowerBound
        let end = node.range.upperBound
        while i < end {
            let item = items[i]
            if item.path == base { i += 1; continue }
            guard ReviewPath.isDescendant(item.path, of: base) else {
                out.append(ReviewNode(
                    id: item.path + "#\(i)", name: ReviewPath.lastComponent(item.path),
                    basePath: item.path, range: i..<(i + 1), size: item.size,
                    isLeaf: true, iconPath: item.path, appIsRunning: node.appIsRunning,
                    autoSelect: node.autoSelect
                ))
                i += 1
                continue
            }
            let component = ReviewPath.firstComponent(of: item.path, below: base)
            let childPath = ReviewPath.join(base, component)
            var j = i + 1
            var size = item.size
            while j < end, ReviewPath.isSameOrDescendant(items[j].path, of: childPath) {
                size += items[j].size
                j += 1
            }
            out.append(ReviewNode(
                id: childPath + "#\(i)", name: String(component), basePath: childPath,
                range: i..<j, size: size, isLeaf: j == i + 1 && item.path == childPath,
                iconPath: childPath, appIsRunning: node.appIsRunning,
                autoSelect: node.autoSelect
            ))
            i = j
        }
        if out.isEmpty {
            out = diskChildren(of: node)
        }
        out.sort { $0.size > $1.size }
        return out
    }

    private func diskChildren(of node: ReviewNode) -> [ReviewNode] {
        let url = URL(filePath: node.basePath, directoryHint: .isDirectory)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: node.basePath, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey],
            options: []
        ) else { return [] }

        var result: [ReviewNode] = []
        result.reserveCapacity(contents.count)

        for childURL in contents {
            let path = ReviewPath.normalized(childURL)
            let name = childURL.lastPathComponent
            let values = try? childURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey])
            let isDirectory = values?.isDirectory == true && values?.isSymbolicLink != true
            let size: UInt64
            if isDirectory {
                size = quickDirectoryBytes(childURL)
            } else {
                size = UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            }
            result.append(ReviewNode(
                id: path + "#disk",
                name: name,
                basePath: path,
                range: node.range,
                size: size,
                isLeaf: !isDirectory,
                iconPath: path,
                appIsRunning: node.appIsRunning,
                autoSelect: node.autoSelect
            ))
        }
        return result
    }

    private func quickDirectoryBytes(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: []
        ) else { return 0 }
        var total: UInt64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 50_000 { break }
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            }
        }
        return total
    }

    func selectedURLs(flags: [Bool]) -> Set<URL> {
        var unselected: [String] = []
        var selectedCount = 0
        for i in items.indices {
            if flags[i] { selectedCount += 1 } else { unselected.append(items[i].path) }
        }
        unselected.sort(by: ReviewPath.precedes)

        func hasUnselectedDescendant(_ dir: String) -> Bool {
            guard !unselected.isEmpty else { return false }
            let key = dir + "/"
            var lo = 0
            var hi = unselected.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if ReviewPath.precedes(unselected[mid], key) { lo = mid + 1 } else { hi = mid }
            }
            return lo < unselected.count && ReviewPath.isDescendant(unselected[lo], of: dir)
        }

        var urls = Set<URL>(minimumCapacity: selectedCount)
        for i in items.indices where flags[i] {
            let item = items[i]
            if item.isDirectory && hasUnselectedDescendant(item.path) { continue }
            urls.insert(item.url)
        }
        return urls
    }
}

enum ReviewCheckState {
    case off, mixed, on
}

enum ReviewSelectMode {
    case smart, all, none, custom

    var label: String {
        switch self {
        case .smart: String(localized: "Smartly")
        case .all: String(localized: "All")
        case .none: String(localized: "None")
        case .custom: String(localized: "Custom")
        }
    }
}
