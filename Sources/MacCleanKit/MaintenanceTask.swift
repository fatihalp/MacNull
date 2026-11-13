import Foundation

public enum MaintenanceTask: String, CaseIterable, Identifiable, Sendable {
    case freeUpRAM = "Free Up RAM"
    case freeUpPurgeableSpace = "Free Up Purgeable Space"
    case runMaintenanceScripts = "Run Maintenance Scripts"

    case verifyStartupDisk = "Verify Startup Disk"
    case speedUpMail = "Speed Up Mail"
    case rebuildLaunchServices = "Rebuild Launch Services"
    case reindexSpotlight = "Reindex Spotlight"
    case flushDNSCache = "Flush DNS Cache"
    case thinTimeMachineSnapshots = "Thin Time Machine Snapshots"
    case pruneDocker = "Reclaim Docker Space"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .freeUpRAM: rawValue
        case .freeUpPurgeableSpace: rawValue
        case .runMaintenanceScripts: rawValue
        case .verifyStartupDisk: rawValue
        case .speedUpMail: rawValue
        case .rebuildLaunchServices: rawValue
        case .reindexSpotlight: rawValue
        case .flushDNSCache: rawValue
        case .thinTimeMachineSnapshots: rawValue
        case .pruneDocker: rawValue
        }
    }

    public var icon: String {
        switch self {
        case .freeUpRAM: "memorychip"
        case .freeUpPurgeableSpace: "internaldrive"
        case .runMaintenanceScripts: "terminal"
        case .verifyStartupDisk: "checkmark.shield"
        case .speedUpMail: "envelope"
        case .rebuildLaunchServices: "arrow.triangle.2.circlepath"
        case .reindexSpotlight: "magnifyingglass"
        case .flushDNSCache: "network"
        case .thinTimeMachineSnapshots: "clock.arrow.circlepath"
        case .pruneDocker: "shippingbox"
        }
    }

    public var description: String {
        switch self {
        case .freeUpRAM:
            "Purge inactive memory to give active apps more breathing room"
        case .freeUpPurgeableSpace:
            "Reclaim purgeable disk space by thinning low-priority local snapshots"
        case .runMaintenanceScripts:
            "Execute macOS built-in daily, weekly, and monthly maintenance routines"
        case .verifyStartupDisk:
            "Check file system integrity of the boot disk"
        case .speedUpMail:
            "Reindex the Mail.app database to fix search and performance issues"
        case .rebuildLaunchServices:
            "Repair Finder's file-type-to-application mapping database"
        case .reindexSpotlight:
            "Rebuild the Spotlight search index for improved search accuracy"
        case .flushDNSCache:
            "Clear the local DNS cache and force fresh lookups"
        case .thinTimeMachineSnapshots:
            "Reduce local Time Machine snapshot sizes to reclaim disk space"
        case .pruneDocker:
            "Remove unused Docker images, stopped containers, and build cache"
        }
    }

    public enum Severity: Sendable {
        case safe
        case advanced
    }

    public var severity: Severity {
        switch self {

        case .freeUpRAM,
             .freeUpPurgeableSpace,
             .verifyStartupDisk,
             .flushDNSCache,
             .runMaintenanceScripts:
            .safe

        case .speedUpMail,
             .rebuildLaunchServices,
             .reindexSpotlight,
             .thinTimeMachineSnapshots,
             .pruneDocker:
            .advanced
        }
    }

    public var sideEffects: String {
        switch self {
        case .freeUpRAM:
            "Apps that had memory paged out may take a moment to come back to foreground."
        case .freeUpPurgeableSpace:
            "Time Machine local snapshots that macOS already flagged for cleanup are removed; nothing the user actively needs is deleted."
        case .runMaintenanceScripts:
            "No visible effect — these are the same scripts macOS runs on its own overnight."
        case .verifyStartupDisk:
            "A few minutes of disk activity. Read-only — nothing on disk is changed regardless of the outcome."
        case .speedUpMail:
            "Mail.app's search index is rebuilt from scratch. Mail search and unread counts will be wrong until the rebuild finishes (typically 10–30 minutes on a large mailbox)."
        case .rebuildLaunchServices:
            "macOS's database of \"which app opens which file type\" is erased and rebuilt. Until it finishes (often several hours), double-clicking files may fail or open the wrong app, default-app settings may reset, and launching apps via Spotlight may not work. A reboot speeds this up."
        case .reindexSpotlight:
            "Spotlight's entire search index is erased and rebuilt. Spotlight search will return empty results for several hours (longer for large home directories). System search and Smart Folders are affected too."
        case .flushDNSCache:
            "Browsers and other network apps re-resolve hostnames on next request — milliseconds of impact."
        case .thinTimeMachineSnapshots:
            "Local Time Machine snapshots are deleted to free disk space. Remote/backup-drive snapshots are unaffected; you can still restore from the Time Machine backup itself."
        case .pruneDocker:
            "Runs docker system prune, removing unused images, stopped containers, unused networks, and build cache. This is irreversible (it does not go to the Trash). Running containers, in-use images, and named volumes are untouched, and the Docker.raw disk image is never deleted directly."
        }
    }

    public var requiresAdmin: Bool {
        switch self {

        case .freeUpRAM, .freeUpPurgeableSpace, .runMaintenanceScripts,
             .reindexSpotlight, .thinTimeMachineSnapshots:
            true

        case .verifyStartupDisk, .speedUpMail, .rebuildLaunchServices,
             .flushDNSCache, .pruneDocker:
            false
        }
    }

    public var systemCommand: (executable: String, arguments: [String])? {
        switch self {
        case .freeUpRAM:
            ("/usr/sbin/purge", [])
        case .freeUpPurgeableSpace:

            ("/usr/bin/tmutil", ["thinlocalsnapshots", "/", "999999999999", "1"])
        case .runMaintenanceScripts:
            ("/usr/sbin/periodic", ["daily", "weekly", "monthly"])
        case .verifyStartupDisk:
            ("/usr/sbin/diskutil", ["verifyVolume", "/"])
        case .speedUpMail:
            nil
        case .rebuildLaunchServices:
            ("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
             ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
        case .reindexSpotlight:
            ("/usr/bin/mdutil", ["-E", "/"])
        case .flushDNSCache:
            ("/usr/bin/dscacheutil", ["-flushcache"])
        case .thinTimeMachineSnapshots:
            ("/usr/bin/tmutil", ["thinlocalsnapshots", "/", "999999999999", "4"])
        case .pruneDocker:
            nil
        }
    }

    public static let dockerCandidatePaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]

    public static func resolveDockerPath(existing: (String) -> Bool) -> String? {
        dockerCandidatePaths.first(where: existing)
    }

    public func systemCommandIsAvailable(existing: (String) -> Bool) -> Bool {
        guard let command = systemCommand else { return true }
        return existing(command.executable)
    }
}
