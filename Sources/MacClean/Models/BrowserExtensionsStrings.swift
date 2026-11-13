import Foundation
import MacCleanKit

enum BrowserExtensionsStrings {
    static var subtitle: String {
        "Extensions from Chrome, Brave, Edge, Arc, Firefox, and Safari. Names that match known adware families are marked Suspicious."
    }

    static var reading: String {
        "Reading extensions…"
    }

    static var empty: String {
        "No extensions found in Chrome, Brave, Edge, Arc, Firefox, or Safari"
    }

    static var safariUnavailable: String {
        "Couldn't read the list of Safari extensions. Check Safari Settings > Extensions instead."
    }

    static var suspicious: String { "Suspicious" }

    static var suspiciousHelp: String {
        "The name matches a known adware family. This is a hint, not a confirmed detection."
    }

    static var policyTag: String { "Installed by policy" }
    static var builtInTag: String { "Built in" }
    static var unknownDate: String { "Unknown date" }
    static var details: String { "Details" }

    static func confirmTitle(for record: BrowserExtensionRecord?) -> String {
        guard let record, record.origin == .user else {
            return "About this extension"
        }
        return "Remove extension?"
    }

    static func confirmMessage(for record: BrowserExtensionRecord) -> String {
        switch record.origin {
        case .safariApp:
            return "Safari extensions come with apps and are managed by macOS, so this list is read-only. Settings will open instead."
        case .policy:
            return fill(policyText, record.browser)
        case .component:
            return fill(builtInText, record.browser)
        case .user:
            return fill("If {browser} is closed, the extension folder moves to the Trash. If it is open, nothing is deleted and you'll see where to remove it. If you use {browser} sync, it may reinstall the extension.", record.browser)
        }
    }

    static func message(for outcome: BrowserExtensionsClient.RemovalOutcome) -> String? {
        switch outcome {
        case .openedSafariSettings:
            return nil
        case .trashed:
            return "The extension was moved to the Trash."
        case .removeInBrowser(let browser):
            return removeInBrowserText(browser)
        case .managedByPolicy(let browser):
            return fill(policyText, browser)
        case .builtIn(let browser):
            return fill(builtInText, browser)
        case .refused:
            return "MacNull couldn't confirm this extension's folder is safe to remove, so nothing was deleted."
        case .failed(let error):
            return "Couldn't move it to the Trash: " + error
        }
    }

    static func removeInBrowserText(_ browser: BrowserKind) -> String {
        switch browser {
        case .chrome:
            return "Chrome is open, so nothing was deleted. Remove the extension in Chrome from Window > Extensions."
        case .firefox:
            return "Firefox is open, so nothing was deleted. Remove the extension in Firefox from Tools > Add-ons and Themes."
        case .brave, .edge, .arc, .safari:
            let url: String
            switch browser {
            case .brave: url = "brave://extensions"
            case .edge: url = "edge://extensions"
            default: url = "arc://extensions"
            }
            return fill("{browser} is open, so nothing was deleted. Remove the extension in {browser} by opening {url} in the address bar.", browser).replacingOccurrences(of: "{url}", with: url)
        }
    }

    static var policyText: String {
        "This extension was installed by a management policy, so {browser} would reinstall it. If you don't recognize it, search System Settings for Profiles or Device Management and remove any profile you don't recognize."
    }

    static var builtInText: String {
        "This extension is built into {browser} and can't be removed."
    }

    static func fill(_ text: String, _ browser: BrowserKind) -> String {
        text.replacingOccurrences(of: "{browser}", with: browser.label)
    }
}
