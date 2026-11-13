import Foundation

public enum DiskHogsText {
    public static var title: String { "Disk Hogs" }
    public static var subtitle: String {
        "Space used by Docker and Xcode simulators. Only the tools found on this Mac are shown, and nothing is selected for you."
    }
    public static var refresh: String { "Refresh" }
    public static var size: String { "Size" }
    public static var xcodeSection: String { "Xcode Simulators" }
    public static var unavailableSimulator: String { "Unavailable simulator" }
    public static var olderRuntime: String { "Older runtime" }
    public static var pruneButton: String {
        "Prune Selected Docker Items…"
    }
    public static var deleteButton: String {
        "Delete Selected Simulator Items…"
    }
    public static var dockerNotResponding: String {
        "Docker is installed but not responding. Start Docker Desktop, then click Refresh."
    }
    public static var dockerDiskImage: String {
        "Docker Desktop disk image"
    }
    public static var dockerDiskImageNote: String {
        "Docker's virtual disk. It holds all your images, containers, and volumes, so Mac Sai never deletes it. Pruning Docker items frees space inside it, and Docker Desktop then gives that space back to macOS. To cap its size, lower the disk limit in Docker Desktop's Resources settings."
    }
    public static var nothingFound: String {
        "No Docker or Xcode simulators found on this Mac."
    }
    public static var pruneConfirmTitle: String {
        "Permanently prune the selected Docker items?"
    }
    public static var pruneConfirmButton: String { "Prune Permanently" }
    public static var deleteConfirmTitle: String {
        "Permanently delete the selected simulator items?"
    }
    public static var deleteConfirmButton: String { "Delete Permanently" }
    public static var runtimeShutdownNote: String {
        "Deleting a runtime first shuts down any simulator using it, and those simulators become unavailable."
    }
    public static var permanentNote: String {
        "This is permanent. Nothing goes to the Trash."
    }
    public static var cancel: String { "Cancel" }
    public static var pruned: String { "Pruned" }
    public static var deleted: String { "Deleted" }
    public static var failed: String { "Failed" }
    public static var timedOut: String { "Timed out and was stopped" }
    public static var stopped: String { "Stopped" }

    static var all: [String] {
        [title, subtitle, refresh, size, xcodeSection, unavailableSimulator, olderRuntime, pruneButton,
         deleteButton, dockerNotResponding, dockerDiskImage, dockerDiskImageNote, nothingFound, pruneConfirmTitle, pruneConfirmButton,
         deleteConfirmTitle, deleteConfirmButton, runtimeShutdownNote, permanentNote, cancel, pruned,
         deleted, failed, timedOut, stopped]
        + DockerDiskCategory.allCases.flatMap { [$0.label, $0.pruneNote] }
    }

    public static func statusLine(name: String, outcome: BoundedProcess.Outcome, success: String) -> String {
        switch outcome {
        case .exited(0, _, _):
            return "\(name): \(success)"
        case .timedOut:
            return "\(name): \(timedOut)"
        case .cancelled:
            return "\(name): \(stopped)"
        case .exited, .launchFailed:
            let detail = outcome.failureDetail
            return detail.isEmpty ? "\(name): \(failed)" : "\(name): \(failed) (\(detail))"
        }
    }
}
