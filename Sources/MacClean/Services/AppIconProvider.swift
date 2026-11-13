import AppKit

@MainActor
enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static var genericApplicationIcon: NSImage {
        NSWorkspace.shared.icon(for: .application)
    }

    static func icon(forPath path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }

    static func icon(forExistingPath path: String) -> NSImage? {
        FileManager.default.fileExists(atPath: path) ? icon(forPath: path) : nil
    }

    static func icon(forBundleID bundleID: String) -> NSImage? {
        applicationPath(forBundleID: bundleID).map(icon(forPath:))
    }

    static func icon(forPathOrBundleID identifier: String) -> NSImage {
        icon(forExistingPath: identifier) ?? icon(forBundleID: identifier) ?? icon(forPath: identifier)
    }

    static func displayName(forBundleID bundleID: String) -> String? {
        applicationPath(forBundleID: bundleID).map { FileManager.default.displayName(atPath: $0) }
    }

    private static func applicationPath(forBundleID bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path(percentEncoded: false)
    }
}
