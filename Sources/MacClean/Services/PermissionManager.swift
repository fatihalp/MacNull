import Foundation
import AppKit

public final class PermissionManager: Sendable {
    public static let shared = PermissionManager()

    private init() {}

    public var hasFullDiskAccess: Bool {
        let safariFolder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Safari")
        return (try? FileManager.default.contentsOfDirectory(atPath: safariFolder.path(percentEncoded: false))) != nil
    }

    public func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
