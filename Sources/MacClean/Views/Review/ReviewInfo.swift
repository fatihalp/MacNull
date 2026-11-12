import SwiftUI
import AppKit
import MacCleanKit

enum ReviewSectionInfo {
    static func description(for moduleID: String) -> String? {
        switch moduleID {
        case "system_junk":
            String(localized: "Redundant files that clog up device storage and impede optimal performance.")
        case "mail_attachments":
            String(localized: "Local copies of attachments saved by your mail apps.")
        case "trash_bins":
            String(localized: "Items still taking up space in your Trash bins.")
        case "malware":
            String(localized: "Suspicious files found on your disk.")
        case "privacy", "browser_cleanup":
            String(localized: "Temporary files, caches, and web storage from web browsers.")
        default:
            nil
        }
    }

    static func icon(for moduleID: String) -> String {
        switch moduleID {
        case "system_junk": "trash.circle.fill"
        case "mail_attachments": "paperclip.circle.fill"
        case "trash_bins": "trash.fill"
        case "malware": "shield.lefthalf.filled"
        case "privacy", "browser_cleanup": "globe"
        default: "folder.fill"
        }
    }
}

enum ReviewCategoryInfo {
    static func description(for category: ScanCategory) -> String {
        switch category {
        case .userCaches, .packageManagerCaches, .ideCaches, .aiToolCaches, .appCaches:
            String(localized: "Originally intended to improve startup times, the cache files of your applications ultimately accumulate and result in improper functioning or an overall performance drop.")
        case .systemLogs:
            String(localized: "The activity of your system applications and services is being captured into numerous logs, which may be helpful for debugging purposes only and can be removed without a second thought.")
        case .userLogs:
            String(localized: "The activity of your applications is constantly being captured into numerous log files, which start using quite a lot of space after some time but are rather useless, especially if they are old.")
        default:
            category.safetyRationale
        }
    }
}
