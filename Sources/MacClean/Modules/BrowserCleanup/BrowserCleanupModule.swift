import Foundation
import MacCleanKit

public struct BrowserCleanupModule: ScanModule {
    public let id = "browser_cleanup"
    public var name: String { "Browser Caches" }
    public let category = ModuleCategory.cleanup
    public let includedInSmartScan = true

    public enum TimeFilter: Sendable {
        case today
        case lastWeek
        case lastMonth
        case lastYear
        case allTime

        var maxAge: TimeInterval? {
            switch self {
            case .today: 24 * 3600
            case .lastWeek: 7 * 24 * 3600
            case .lastMonth: 30 * 24 * 3600
            case .lastYear: 365 * 24 * 3600
            case .allTime: nil
            }
        }
    }

    private let scanner = TargetedScanner()
    private let timeFilter: TimeFilter

    public init(timeFilter: TimeFilter = .allTime) {
        self.timeFilter = timeFilter
    }

    public func scan() async -> [ScanResult] {
        await scan(onProgress: nil)
    }

    public func scan(
        onProgress: (@Sendable (_ phase: String, _ count: Int, _ bytes: UInt64, _ fraction: Double) -> Void)?
    ) async -> [ScanResult] {
        let browserItems = await scanBrowserData(onProgress: { count, bytes in
            onProgress?(name, count, bytes, 0.5)
        })
        var results: [ScanResult] = []
        if !browserItems.isEmpty {
            results.append(ScanResult(category: .browserPrivacy, items: browserItems))
        }
        let totalCount = results.reduce(0) { $0 + $1.fileCount }
        let totalBytes = results.reduce(0) { $0 + $1.totalSize }
        onProgress?(name, totalCount, totalBytes, 1.0)
        return results.filteringUncleanable()
    }

    private func scanBrowserData(
        onProgress: (@Sendable (_ count: Int, _ bytes: UInt64) -> Void)? = nil
    ) async -> [FileItem] {
        var targets: [ScanTarget] = []

        targets.append(ScanTarget(
            path: MCConstants.safariCache,
            recursive: true,
            maxAge: timeFilter.maxAge
        ))
        targets.append(ScanTarget(
            path: MCConstants.userContainers.appending(path: "com.apple.Safari/Data/Library/Caches"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))
        targets.append(ScanTarget(
            path: MCConstants.userLibrary.appending(path: "Safari/Favicon Cache"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))
        targets.append(ScanTarget(
            path: MCConstants.userLibrary.appending(path: "Safari/Touch Icons Cache"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.chromeCache,
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.firefoxCache,
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.userCaches.appending(path: "company.thebrowser.Browser"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.userCaches.appending(path: "BraveSoftware/Brave-Browser"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.userCaches.appending(path: "Microsoft Edge"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.userCaches.appending(path: "com.operasoftware.Opera"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        targets.append(ScanTarget(
            path: MCConstants.userCaches.appending(path: "Vivaldi"),
            recursive: true,
            maxAge: timeFilter.maxAge
        ))

        return await scanner.scan(targets: targets, onProgress: onProgress)
    }
}
