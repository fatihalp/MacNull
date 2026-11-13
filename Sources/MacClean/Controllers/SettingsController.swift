import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor @Observable
final class SettingsController {
    private(set) var excludedFolders: [String] = FolderExclusionPreferences.paths
    private(set) var exclusionError: String?

    func addExcludedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Exclude"
        panel.message = "Choose a folder to exclude from cleanup."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path(percentEncoded: false)
        if FolderExclusionPreferences.add(path) {
            excludedFolders = FolderExclusionPreferences.paths
            exclusionError = nil
        } else {
            exclusionError = rejectionMessage(for: path)
        }
    }

    func rejectionMessage(for path: String) -> String {
        switch PathExclusion.candidateDecision(
            for: path,
            home: NSHomeDirectory(),
            maxCount: FolderExclusionPreferences.defaultMaxCount,
            existing: FolderExclusionPreferences.paths
        ) {
        case .allow:
            return "Couldn't add that folder."
        case .reject(.notAbsolute):
            return "Choose an absolute path."
        case .reject(.entireHome):
            return "You can't exclude your entire home folder."
        case .reject(.entireVolumesRoot):
            return "You can't exclude all of /Volumes."
        case .reject(.outsideAllowedRoots):
            return "Only folders under your home directory or /Volumes can be excluded."
        case .reject(.atCapacity):
            return "You can exclude at most \(FolderExclusionPreferences.defaultMaxCount) folders."
        case .reject(.alreadyCovered):
            return "That path is already covered by an existing exclusion."
        }
    }

    func loadPreferences() {
        excludedFolders = FolderExclusionPreferences.paths
    }

    func removeExcludedFolder(_ path: String) {
        FolderExclusionPreferences.remove(path)
        excludedFolders = FolderExclusionPreferences.paths
        exclusionError = nil
    }

}
