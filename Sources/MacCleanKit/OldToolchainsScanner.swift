import Foundation

public enum OldToolchainsScanner {
    public static func scan() -> [FileItem] {
        var results: [FileItem] = []
        results.append(contentsOf: scanRustToolchains())
        results.append(contentsOf: scanGradleWrappers())
        return results
    }

    private static func scanRustToolchains() -> [FileItem] {
        let toolchainsDir: URL = MCConstants.home.appending(path: ".rustup/toolchains")
        let fm: FileManager = FileManager.default
        guard let entries: [URL] = try? fm.contentsOfDirectory(
            at: toolchainsDir,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let dirEntries: [URL] = entries.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
        guard dirEntries.count > 1 else { return [] }

        let keptToolchain: URL? = determineLatestRustToolchain(from: dirEntries)
        var items: [FileItem] = []
        let hashesDir: URL = MCConstants.home.appending(path: ".rustup/update-hashes")

        for dir: URL in dirEntries {
            if let kept: URL = keptToolchain, dir.lastPathComponent == kept.lastPathComponent {
                continue
            }
            let size: UInt64 = directorySize(at: dir)
            items.append(FileItem(
                url: dir,
                name: dir.lastPathComponent,
                size: size,
                allocatedSize: size,
                isDirectory: true
            ))

            let hashFile: URL = hashesDir.appending(path: dir.lastPathComponent)
            if fm.fileExists(atPath: hashFile.path(percentEncoded: false)) {
                let hashSize: UInt64 = (try? hashFile.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init) ?? 0
                items.append(FileItem(
                    url: hashFile,
                    name: hashFile.lastPathComponent,
                    size: hashSize,
                    allocatedSize: hashSize,
                    isDirectory: false
                ))
            }
        }
        return items
    }

    private static func determineLatestRustToolchain(from urls: [URL]) -> URL? {
        if let stable: URL = urls.first(where: { $0.lastPathComponent.lowercased().hasPrefix("stable") }) {
            return stable
        }
        return urls.sorted { a, b in
            compareVersions(a.lastPathComponent, b.lastPathComponent)
        }.last
    }

    private static func scanGradleWrappers() -> [FileItem] {
        let distsDir: URL = MCConstants.home.appending(path: ".gradle/wrapper/dists")
        let fm: FileManager = FileManager.default
        guard let entries: [URL] = try? fm.contentsOfDirectory(
            at: distsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let dirEntries: [URL] = entries.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
        guard dirEntries.count > 1 else { return [] }

        let sorted: [URL] = dirEntries.sorted { a, b in
            compareVersions(a.lastPathComponent, b.lastPathComponent)
        }
        guard let latest: URL = sorted.last else { return [] }

        var items: [FileItem] = []
        for dir: URL in sorted where dir.lastPathComponent != latest.lastPathComponent {
            let size: UInt64 = directorySize(at: dir)
            items.append(FileItem(
                url: dir,
                name: dir.lastPathComponent,
                size: size,
                allocatedSize: size,
                isDirectory: true
            ))
        }
        return items
    }

    private static func compareVersions(_ a: String, _ b: String) -> Bool {
        let aNums: [Int] = extractNumbers(from: a)
        let bNums: [Int] = extractNumbers(from: b)
        for i: Int in 0..<min(aNums.count, bNums.count) {
            if aNums[i] != bNums[i] {
                return aNums[i] < bNums[i]
            }
        }
        return aNums.count < bNums.count
    }

    private static func extractNumbers(from string: String) -> [Int] {
        let components: [String] = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
        return components.compactMap { Int($0) }
    }

    private static func directorySize(at url: URL) -> UInt64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator: FileManager.DirectoryEnumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            }
        }
        return total
    }
}
