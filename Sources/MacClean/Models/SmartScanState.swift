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
            SmartScanModuleInfo(id: "systemJunk", name: "System Junk", icon: "trash.circle.fill", group: "Cleanup"),
            SmartScanModuleInfo(id: "browserCleanup", name: "Browser Caches", icon: "globe", group: "Cleanup"),
        ]
        if mode == .deep {
            list.append(SmartScanModuleInfo(id: "projectJunk", name: "Project Junk", icon: "chevron.left.forwardslash.chevron.right", group: "Cleanup"))
        }
        list.append(contentsOf: [
            SmartScanModuleInfo(id: "mailAttachments", name: "Mail Attachments", icon: "paperclip.circle.fill", group: "Cleanup"),
            SmartScanModuleInfo(id: "trashBins", name: "Trash Bins", icon: "trash.fill", group: "Cleanup"),
            SmartScanModuleInfo(id: "optimization", name: "Optimization", icon: "gauge.with.dots.needle.67percent", group: "Speed"),
            SmartScanModuleInfo(id: "maintenance", name: "Maintenance", icon: "wrench.and.screwdriver", group: "Speed"),
            SmartScanModuleInfo(id: "uninstaller", name: "Uninstaller", icon: "xmark.app.fill", group: "Apps"),
            SmartScanModuleInfo(id: "updater", name: "Updater", icon: "arrow.triangle.2.circlepath", group: "Apps"),
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

extension SmartScanState {
    var phaseKey: String {
        switch self {
        case .idle: "idle"
        case .scanning: "scanning"
        case .results: "results"
        case .empty: "empty"
        case .cleaning: "cleaning"
        case .done: "done"
        }
    }
}
