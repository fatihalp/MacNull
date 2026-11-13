import AppKit
import MacCleanKit

enum DuplicateInstanceGuard {
    static func exitIfAnotherInstanceIsRunning() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications
        let ownLaunchDate = running.first { $0.processIdentifier == ownPID }?.launchDate
        let siblings = running.compactMap { app -> MenuBarInstance? in
            guard app.bundleIdentifier == bundleID, app.processIdentifier != ownPID else { return nil }
            return MenuBarInstance(pid: app.processIdentifier, launchDate: app.launchDate)
        }
        if MenuBarInstancePolicy.shouldExitAsDuplicate(selfPID: ownPID, selfLaunchDate: ownLaunchDate, siblings: siblings) {
            exit(0)
        }
    }
}
