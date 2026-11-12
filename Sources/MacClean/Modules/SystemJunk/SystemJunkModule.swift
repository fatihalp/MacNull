import Foundation
import AppKit
import MacCleanKit

public struct SystemJunkModule: ScanModule {
    public let id = "system_junk"
    public var name: String { String(localized: "System Junk") }
    public let category = ModuleCategory.cleanup

    private let scanner = TargetedScanner()

    public init() {}

    public static let allCategories: [JunkCategory] = [
        UserCacheCategory(),
        SystemCacheCategory(),
        UserLogCategory(),
        SystemLogCategory(),
        LanguageFilesCategory(),
        BrokenPreferencesCategory(),
        BrokenLoginItemsCategory(),
        DocumentVersionsCategory(),
        BrokenDownloadsCategory(),
        IOSDeviceBackupsCategory(),
        OldUpdatesCategory(),
        UniversalBinariesCategory(),
        XcodeJunkCategory(),
        DeletedUsersCategory(),
        UnusedDiskImagesCategory(),
        IncompleteDownloadsCategory(),
        AppLeftoversCategory(),
        PackageManagerCachesCategory(),
        IDECachesCategory(),
        AIToolCachesCategory(),
        AppCachesCategory(),
    ]

    public func scan() async -> [ScanResult] {
        await scan(onProgress: nil)
    }

    public func scan(
        onProgress: (@Sendable (_ phase: String, _ count: Int, _ bytes: UInt64, _ fraction: Double) -> Void)?
    ) async -> [ScanResult] {
        let categories = Self.allCategories
        var results: [ScanResult] = []
        var runningCount = 0
        var runningBytes: UInt64 = 0
        let total = Double(categories.count)

        for (index, cat) in categories.enumerated() {
            if Task.isCancelled { break }

            let startFraction = Double(index) / total
            let endFraction = Double(index + 1) / total
            onProgress?(cat.scanCategory.displayName, runningCount, runningBytes, startFraction)

            if cat.scanCategory == .universalBinaries {
                let items = await Task.detached(priority: .userInitiated) {
                    UniversalBinariesScanner.scanAllApplicationsDirectories()
                }.value
                if !items.isEmpty {
                    let res = ScanResult(
                        category: .universalBinaries,
                        items: items,
                        autoSelect: cat.scanCategory.autoSelect
                    )
                    results.append(res)
                    runningCount += res.fileCount
                    runningBytes += res.totalSize
                }
                onProgress?(cat.scanCategory.displayName, runningCount, runningBytes, endFraction)
                continue
            }

            if cat.scanCategory == .appLeftovers {
                let items = await Task.detached(priority: .userInitiated) {
                    AppLeftoversScanner.scan()
                }.value
                if !items.isEmpty {
                    let res = ScanResult(
                        category: .appLeftovers,
                        items: items,
                        autoSelect: cat.scanCategory.autoSelect
                    )
                    results.append(res)
                    runningCount += res.fileCount
                    runningBytes += res.totalSize
                }
                onProgress?(cat.scanCategory.displayName, runningCount, runningBytes, endFraction)
                continue
            }

            if cat.scanCategory == .deletedUsers {
                let items = await Task.detached(priority: .userInitiated) {
                    DeletedUsersScanner.scanForDeletedUserFolders()
                }.value
                if !items.isEmpty {
                    let res = ScanResult(
                        category: .deletedUsers,
                        items: items,
                        autoSelect: cat.scanCategory.autoSelect
                    )
                    results.append(res)
                    runningCount += res.fileCount
                    runningBytes += res.totalSize
                }
                onProgress?(cat.scanCategory.displayName, runningCount, runningBytes, endFraction)
                continue
            }

            let currentBaseCount = runningCount
            let currentBaseBytes = runningBytes

            if cat.scanCategory == .packageManagerCaches {
                let standardItems: [FileItem] = await scanner.scan(targets: cat.targets) { count, bytes in
                    let intraFraction = startFraction + (endFraction - startFraction) * 0.5
                    onProgress?(cat.scanCategory.displayName, currentBaseCount + count, currentBaseBytes + bytes, intraFraction)
                }
                let oldToolchainItems: [FileItem] = await Task.detached(priority: .userInitiated) {
                    OldToolchainsScanner.scan()
                }.value
                let combined: [FileItem] = standardItems + oldToolchainItems
                if !combined.isEmpty {
                    let res = ScanResult(
                        category: .packageManagerCaches,
                        items: combined,
                        autoSelect: cat.scanCategory.autoSelect
                    )
                    results.append(res)
                    runningCount += res.fileCount
                    runningBytes += res.totalSize
                }
                onProgress?(cat.scanCategory.displayName, runningCount, runningBytes, endFraction)
                continue
            }

            let items = await scanner.scan(targets: cat.targets) { count, bytes in
                let intraFraction = startFraction + (endFraction - startFraction) * 0.5
                onProgress?(cat.scanCategory.displayName, currentBaseCount + count, currentBaseBytes + bytes, intraFraction)
            }
            var filtered = items

            if let brokenPrefs = cat as? BrokenPreferencesCategory {
                filtered = brokenPrefs.filterBroken(
                    items,
                    loadData: { try? Data(contentsOf: $0) },
                    appExistsForBundleID: {
                        NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
                    }
                )
            } else if let brokenLogin = cat as? BrokenLoginItemsCategory {
                filtered = brokenLogin.filterBroken(
                    items,
                    loadData: { try? Data(contentsOf: $0) },
                    fileExists: { FileManager.default.fileExists(atPath: $0) },
                    appExistsForBundleID: {
                        NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
                    }
                )
            }

            if !filtered.isEmpty {
                let res = ScanResult(
                    category: cat.scanCategory,
                    items: filtered,
                    autoSelect: cat.scanCategory.autoSelect
                )
                results.append(res)
                runningCount += res.fileCount
                runningBytes += res.totalSize
            }
            onProgress?(cat.scanCategory.displayName, runningCount, runningBytes, endFraction)
        }

        return results
            .filteringUncleanable()
            .sorted { $0.totalSize > $1.totalSize }
    }
}
