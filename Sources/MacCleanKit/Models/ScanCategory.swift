import Foundation

public enum ScanCategory: String, CaseIterable, Identifiable, Sendable {

    case userCaches = "user_caches"
    case systemCaches = "system_caches"
    case userLogs = "user_logs"
    case systemLogs = "system_logs"
    case brokenPreferences = "broken_preferences"
    case brokenLoginItems = "broken_login_items"
    case documentVersions = "document_versions"
    case brokenDownloads = "broken_downloads"
    case iosDeviceBackups = "ios_device_backups"
    case oldUpdates = "old_updates"
    case universalBinaries = "universal_binaries"
    case xcodeJunk = "xcode_junk"
    case deletedUsers = "deleted_users"
    case unusedDiskImages = "unused_disk_images"
    case incompleteDownloads = "incomplete_downloads"
    case appLeftovers = "app_leftovers"
    case packageManagerCaches = "package_manager_caches"
    case ideCaches = "ide_caches"
    case aiToolCaches = "ai_tool_caches"
    case appCaches = "app_caches"

    case mailAttachments = "mail_attachments"

    case trashBins = "trash_bins"

    case malware = "malware"
    case browserPrivacy = "browser_privacy"
    case systemPrivacy = "system_privacy"

    case largeFiles = "large_files"
    case oldFiles = "old_files"
    case duplicates = "duplicates"

    case projectJunk = "project_junk"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userCaches: "User Cache Files"
        case .systemCaches: "System Cache Files"
        case .userLogs: "User Log Files"
        case .systemLogs: "System Log Files"
        case .brokenPreferences: "Broken Preferences"
        case .brokenLoginItems: "Broken Login Items"
        case .documentVersions: "Document Versions"
        case .brokenDownloads: "Broken Downloads"
        case .iosDeviceBackups: "iOS Device Backups"
        case .oldUpdates: "Old Updates"
        case .universalBinaries: "Universal Binaries"
        case .xcodeJunk: "Xcode Junk"
        case .deletedUsers: "Deleted Users"
        case .unusedDiskImages: "Disk & Restore Images"
        case .incompleteDownloads: "Incomplete Downloads"
        case .appLeftovers: "Leftovers from Deleted Apps"
        case .packageManagerCaches: "Package Manager Caches"
        case .ideCaches: "IDE & Editor Caches"
        case .aiToolCaches: "AI Tool Caches"
        case .appCaches: "Application Caches"
        case .mailAttachments: "Mail Attachments"
        case .trashBins: "Trash Bins"
        case .malware: "Malware"
        case .browserPrivacy: "Browser Caches"
        case .systemPrivacy: "System Privacy"
        case .largeFiles: "Large Files"
        case .oldFiles: "Old Files"
        case .duplicates: "Duplicates"
        case .projectJunk: "Project Junk"
        }
    }

    public var subtitle: String {
        switch self {
        case .userCaches: "App temporary files. Regenerated next launch."
        case .systemCaches: "macOS-managed caches. Rebuilt automatically."
        case .userLogs: "Diagnostic logs written by your apps."
        case .systemLogs: "macOS diagnostic logs."
        case .brokenPreferences: "Corrupt or orphaned preference files."
        case .brokenLoginItems: "Login items pointing at apps that are gone."
        case .documentVersions: "Old autosaved document revisions."
        case .brokenDownloads: "Failed or orphaned download leftovers."
        case .iosDeviceBackups: "Local backups of iPhone and iPad devices."
        case .oldUpdates: "Installer packages left behind after updating."
        case .universalBinaries: "Unused CPU slices inside app binaries."
        case .xcodeJunk: "Derived data, archives, and simulator caches."
        case .deletedUsers: "Leftover data from removed user accounts."
        case .unusedDiskImages: "Installer disk images and macOS or iOS restore images (.ipsw) you no longer need."
        case .incompleteDownloads: "Partially downloaded files."
        case .appLeftovers: "Support files from apps you've deleted."
        case .packageManagerCaches: "Regenerable caches from npm, pnpm, Cargo, Pub, pip, uv, Composer, Homebrew, and Gradle."
        case .ideCaches: "Caches from code editors like Cursor and Windsurf."
        case .aiToolCaches: "Caches, runtimes, and sessions from AI coding tools (Gemini, Claude, Codex)."
        case .appCaches: "Caches and temporary files from messaging and desktop applications (WhatsApp, etc.)."
        case .mailAttachments: "Saved copies of Mail attachments."
        case .trashBins: "Items currently sitting in the Trash."
        case .malware: "Known malicious files found on disk."
        case .browserPrivacy: "Temporary cache files and web storage from web browsers."
        case .systemPrivacy: "Recent-items lists and other privacy traces."
        case .largeFiles: "The files taking up the most space."
        case .oldFiles: "Files you haven't opened in a long time."
        case .duplicates: "Identical copies of the same file."
        case .projectJunk: "Dependency and build folders inside your code projects."
        }
    }

    public var tooltip: String {
        "\(displayName)\n\(subtitle)"
    }

    public var safetyRationale: String {
        switch self {
        case .userCaches: "App temp files. Recreated automatically the next time each app launches."
        case .systemCaches: "Caches macOS manages itself. It rebuilds them automatically as needed."
        case .packageManagerCaches: "Download and build caches. npm, pnpm, Cargo, pip, uv, Homebrew, and Gradle re-download what they need on the next install or build."
        case .ideCaches: "Editor caches only. Cursor and Antigravity recreate them on next launch; your settings and extensions aren't touched."
        case .aiToolCaches: "AI tools accumulate heavy models, runtimes, and sessions. Safe Clean preserves conversations; Deep Clean recovers maximum space."
        case .appCaches: "Temporary files and media caches from apps like WhatsApp. The app regenerates them as needed."
        case .userLogs: "Diagnostic text your apps wrote for troubleshooting. Apps don't read old logs back, and they start new ones as they run."
        case .systemLogs: "macOS diagnostic logs. Only useful when investigating a past problem; macOS keeps writing fresh ones."
        case .brokenPreferences: "Settings files that can't be read, or whose app is no longer installed. Nothing on this Mac uses them."
        case .brokenLoginItems: "Login entries that point to apps that no longer exist, so they can't start anything."
        case .brokenDownloads: "Leftovers of downloads that failed or were abandoned. Download the file again if you still want it."
        case .incompleteDownloads: "Partial files from unfinished downloads and day-old temp files. Don't clean while a download is still running."
        case .oldUpdates: "Installer packages apps downloaded more than a week ago. Installers aren't needed once they've run, and can be downloaded again."
        case .appLeftovers: "Support folders named after an app that's no longer installed (the name on each row is that app's ID). Reinstalling the app later starts it fresh."
        case .documentVersions: "Older autosaved revisions of your documents. The current version stays, but older ones can't be browsed after cleaning."
        case .iosDeviceBackups: "Local iPhone and iPad backups older than 30 days. If it's a device's only backup, keep it or back up to iCloud first."
        case .universalBinaries: "Removes CPU code this Mac can't run from inside apps. Changes the apps in place; only reinstalling them undoes it."
        case .xcodeJunk: "DerivedData and Previews are rebuilt on the next build, and Device Support is copied again when a device connects. Archives and simulator data can't be regenerated; keep them if you need old builds or crash symbols."
        case .deletedUsers: "Whole home folders of accounts no longer on this Mac. Check each name: a network account that's briefly offline looks the same."
        case .unusedDiskImages: "Disk images and restore images (.ipsw, often 15 to 25 GB) in Downloads older than a week. They are only needed to set up a Mac or device again, and can be downloaded again."
        case .mailAttachments: "Copies of attachments Mail saved on disk. Mail can download them again from the server for IMAP and Exchange accounts, not for POP."
        case .trashBins: "Already in the Trash. Emptying it is permanent and can't be undone."
        case .malware: "Matched a known malware signature. Check the path first if it belongs to software you installed on purpose."
        case .browserPrivacy: "Temporary files and web caches from web browsers. Can be safely removed to free up disk space while preserving logins and cookies."
        case .systemPrivacy: "Recent-items lists and similar traces. Apps' Open Recent menus will start empty."
        case .largeFiles: "Your own files, picked only by size. Nothing here is junk by definition; check each one."
        case .oldFiles: "Your own files you haven't opened in a long time. Old doesn't mean unneeded; check each one."
        case .duplicates: "Byte-for-byte identical copies. Keep at least one copy of each file you need."
        case .projectJunk: "Installed dependencies and build output inside your projects. Running the project's install or build command brings them back; the first build afterwards takes longer."
        }
    }

    public var systemImage: String {
        switch self {
        case .userCaches, .systemCaches: "folder.badge.gearshape"
        case .userLogs, .systemLogs: "doc.text"
        case .brokenPreferences: "gearshape.triangle.fill"
        case .brokenLoginItems: "person.crop.circle.badge.exclamationmark"
        case .documentVersions: "doc.on.doc"
        case .brokenDownloads, .incompleteDownloads: "arrow.down.circle.dotted"
        case .iosDeviceBackups: "iphone"
        case .oldUpdates: "arrow.triangle.2.circlepath"
        case .universalBinaries: "cpu"
        case .xcodeJunk: "hammer"
        case .deletedUsers: "person.crop.circle.badge.minus"
        case .unusedDiskImages: "opticaldisc"
        case .appLeftovers: "shippingbox.and.arrow.backward"
        case .packageManagerCaches: "shippingbox"
        case .ideCaches: "macwindow"
        case .aiToolCaches: "sparkles"
        case .appCaches: "bubble.left.and.bubble.right"
        case .mailAttachments: "paperclip"
        case .trashBins: "trash"
        case .malware: "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .browserPrivacy: "globe"
        case .systemPrivacy: "hand.raised"
        case .largeFiles: "arrow.up.right.square"
        case .oldFiles: "clock.arrow.circlepath"
        case .duplicates: "plus.square.on.square"
        case .projectJunk: "chevron.left.forwardslash.chevron.right"
        }
    }

    public var autoSelect: Bool {
        switch self {
        case .unusedDiskImages, .largeFiles, .oldFiles, .duplicates, .projectJunk,
             .universalBinaries, .appLeftovers, .deletedUsers,
             .packageManagerCaches, .ideCaches, .aiToolCaches, .appCaches:

            false
        default:
            true
        }
    }
}
