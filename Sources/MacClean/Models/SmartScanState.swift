import Foundation
import MacCleanKit

struct CompletedModule: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let fileCount: Int
    let size: UInt64
}

struct SmartScanModuleInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let group: String
}

enum SmartScanModules {
    static func modules(for mode: SmartScanMode) -> [SmartScanModuleInfo] {
        var list: [SmartScanModuleInfo] = [
            SmartScanModuleInfo(id: "systemJunk", name: String(localized: "System Junk"), icon: "trash.circle.fill", group: String(localized: "Cleanup")),
            SmartScanModuleInfo(id: "browserCleanup", name: String(localized: "Browser Caches"), icon: "globe", group: String(localized: "Cleanup")),
        ]
        if mode == .deep {
            list.append(SmartScanModuleInfo(id: "projectJunk", name: String(localized: "Project Junk"), icon: "chevron.left.forwardslash.chevron.right", group: String(localized: "Cleanup")))
        }
        list.append(contentsOf: [
            SmartScanModuleInfo(id: "mailAttachments", name: String(localized: "Mail Attachments"), icon: "paperclip.circle.fill", group: String(localized: "Cleanup")),
            SmartScanModuleInfo(id: "trashBins", name: String(localized: "Trash Bins"), icon: "trash.fill", group: String(localized: "Cleanup")),
            SmartScanModuleInfo(id: "optimization", name: String(localized: "Optimization"), icon: "gauge.with.dots.needle.67percent", group: String(localized: "Speed")),
            SmartScanModuleInfo(id: "maintenance", name: String(localized: "Maintenance"), icon: "wrench.and.screwdriver", group: String(localized: "Speed")),
            SmartScanModuleInfo(id: "uninstaller", name: String(localized: "Uninstaller"), icon: "xmark.app.fill", group: String(localized: "Apps")),
            SmartScanModuleInfo(id: "updater", name: String(localized: "Updater"), icon: "arrow.triangle.2.circlepath", group: String(localized: "Apps")),
        ])
        return list
    }

    static var order: [SmartScanModuleInfo] {
        modules(for: .deep)
    }
}

enum SmartScanState {
    case idle
    case scanning(phase: String, progress: Double, filesFound: Int, sizeFound: UInt64)
    case results(cleanup: UInt64, protection: Int, performance: Int, totalSize: UInt64, moduleResults: [ModuleScanResult])
    case empty
    case cleaning(progress: Double)
    case done(freedSize: UInt64, breakdown: [SmartScanCleanup.RecentlyCleanedRow])
}
