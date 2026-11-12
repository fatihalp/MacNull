import Foundation

public struct PackageManagerCachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.packageManagerCaches
    public var targets: [ScanTarget] {
        [
            MCConstants.npmCacache,
            MCConstants.npxCache,
            MCConstants.npmLogs,
            MCConstants.yarnCache,
            MCConstants.pnpmStore,
            MCConstants.bunCache,
            MCConstants.cargoRegistryCache,
            MCConstants.cargoRegistrySrc,
            MCConstants.cargoGit,
            MCConstants.rustupDownloads,
            MCConstants.rustupTmp,
            MCConstants.pubCache,
            MCConstants.dartServer,
            MCConstants.gradleCaches,
            MCConstants.gradleDaemon,
            MCConstants.gradleWrapperDists,
            MCConstants.homebrewCache,
            MCConstants.pipCache,
            MCConstants.uvCache,
            MCConstants.ruffCache,
            MCConstants.cocoapodsCache,
            MCConstants.composerCache,
            MCConstants.composerHomeCache,
            MCConstants.swiftpmCache,
            MCConstants.playwrightCache,
            MCConstants.cypressCache,
            MCConstants.dockerInstaller,
            MCConstants.puppeteerCache,
            MCConstants.vcpkgCache,
            MCConstants.vcpkgDownloads,
            MCConstants.turboHomeCache,
        ].map { ScanTarget(path: $0, recursive: false) }
    }
}

public struct IDECachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.ideCaches
    public var targets: [ScanTarget] {
        (MCConstants.cursorCaches
            + MCConstants.vscodeCaches
            + MCConstants.windsurfCaches
            + [MCConstants.zedCache, MCConstants.phpactorCache])
            .map { ScanTarget(path: $0, recursive: false) }
    }
}

public struct AIToolCachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.aiToolCaches
    public var targets: [ScanTarget] {
        (MCConstants.antigravityCaches
            + MCConstants.claudeCaches
            + MCConstants.codexCaches
            + [
                MCConstants.opencodeCache,
                MCConstants.copilotSdkCache,
                MCConstants.copilotCache,
            ])
            .map { ScanTarget(path: $0, recursive: false) }
    }
}

public struct AppCachesCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.appCaches
    public var targets: [ScanTarget] {
        (MCConstants.whatsAppCaches
            + MCConstants.chromeAppCaches
            + MCConstants.braveAppCaches
            + MCConstants.desktopAppCaches)
            .map { ScanTarget(path: $0, recursive: false) }
    }
}
