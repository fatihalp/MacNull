import Foundation

public struct UserCacheCategory: JunkCategory {
    public init() {}
    public let scanCategory: ScanCategory = ScanCategory.userCaches
    public var targets: [ScanTarget] {
        var list: [ScanTarget] = [
            ScanTarget(
                path: MCConstants.userCaches,
                recursive: false,
                excludePatterns: ["com.spotify.client", "org.gradle"],
                excludedPaths: MCConstants.userCachesExcludedPaths
            ),
            ScanTarget(
                path: MCConstants.coreSpotlightPipelineStorage,
                recursive: false
            ),
            ScanTarget(
                path: MCConstants.assistantLLMCache,
                recursive: false
            ),
        ]
        if let darwinCache: URL = MCConstants.darwinUserCacheDir {
            list.append(ScanTarget(path: darwinCache, recursive: false))
        }
        if let darwinTemp: URL = MCConstants.darwinUserTempDir {
            list.append(ScanTarget(path: darwinTemp, recursive: false))
        }
        return list
    }
}

public struct SystemCacheCategory: JunkCategory {
    public init() {}
    public let scanCategory: ScanCategory = ScanCategory.systemCaches
    public var targets: [ScanTarget] {
        [
            ScanTarget(path: MCConstants.systemCaches, recursive: false),
            ScanTarget(path: MCConstants.osSystemCaches, recursive: false),
        ]
    }
}

public struct UserLogCategory: JunkCategory {
    public init() {}
    public let scanCategory: ScanCategory = ScanCategory.userLogs
    public var targets: [ScanTarget] {
        [
            ScanTarget(path: MCConstants.userLogs, recursive: true),
            ScanTarget(path: MCConstants.userDiagnosticReports, recursive: true),
            ScanTarget(path: MCConstants.openClawLogs, recursive: true),
            ScanTarget(
                path: MCConstants.openClawHome,
                recursive: false,
                fileExtensions: ["log"],
                excludedPaths: [MCConstants.openClawLogs, MCConstants.openClawWorkspace]
            ),
        ]
    }
}

public struct SystemLogCategory: JunkCategory {
    public init() {}
    public let scanCategory: ScanCategory = ScanCategory.systemLogs
    public var targets: [ScanTarget] {
        [
            ScanTarget(path: MCConstants.systemLogs, recursive: true),
            ScanTarget(path: MCConstants.varLog, recursive: true),
            ScanTarget(path: MCConstants.varLogSymlink, recursive: true),
            ScanTarget(path: MCConstants.systemDiagnosticReports, recursive: true),
        ]
    }
}

public struct DocumentVersionsCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.documentVersions
    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.documentVersions,
                recursive: true,
                minAge: 14400
            ),
        ]
    }
}

public struct BrokenDownloadsCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.brokenDownloads
    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.downloads,
                recursive: true,
                maxDepth: 3,
                fileExtensions: ["download", "crdownload", "part", "partial"]
            ),
        ]
    }
}

public struct IOSDeviceBackupsCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.iosDeviceBackups
    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.mobileBackups,
                recursive: false,
                minAge: 30 * 24 * 3600
            ),
        ]
    }
}

public struct OldUpdatesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.oldUpdates
    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userAppSupport,
                recursive: true,
                maxDepth: 3,
                fileExtensions: ["pkg", "mpkg"],
                minAge: 7 * 24 * 3600
            ),
        ]
    }
}

public struct UnusedDiskImagesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.unusedDiskImages
    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.downloads,
                recursive: true,
                maxDepth: 3,
                fileExtensions: ["dmg", "iso", "sparseimage", "pkg"],
                minAge: 7 * 24 * 3600
            ),
        ]
    }
}

public struct XcodeJunkCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.xcodeJunk
    public var targets: [ScanTarget] {
        [
            ScanTarget(path: MCConstants.xcodeDerivedData, recursive: false),
            ScanTarget(path: MCConstants.xcodeArchives, recursive: false),
            ScanTarget(path: MCConstants.xcodeDeviceSupport, recursive: false),
            ScanTarget(path: MCConstants.coreSimulator.appending(path: "Caches"), recursive: false),
            ScanTarget(path: MCConstants.xcodePreviews, recursive: false),
            ScanTarget(path: MCConstants.userLibrary.appending(path: "Developer/Xcode/iOS Device Logs"), recursive: false),
            ScanTarget(path: MCConstants.userLibrary.appending(path: "Developer/Xcode/UserData/IB Support"), recursive: false),
        ]
    }
}

public struct IncompleteDownloadsCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.incompleteDownloads
    public var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.downloads,
                recursive: false,
                fileExtensions: ["download", "crdownload", "part", "partial", "tmp"]
            ),
            ScanTarget(
                path: FileManager.default.temporaryDirectory,
                recursive: true,
                maxDepth: 2,
                minAge: 24 * 3600
            ),
        ]
    }
}
