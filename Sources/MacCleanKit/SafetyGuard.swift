import Foundation
import Darwin

public struct SafetyGuard: Sendable {
    public enum SafetyError: Error, LocalizedError, Equatable {
        case protectedPath(String)
        case tooManyFiles(Int)
        case symlinkTarget(String)
        case sipProtected(String)
        case outsideUserScope(String)
        case invalidPath(String)
        case userExcluded(String)

        public var errorDescription: String? {
            switch self {
            case .protectedPath(let path):
                "Cannot modify protected system path: \(path)"
            case .tooManyFiles(let count):
                "Operation exceeds safety limit of \(MCConstants.maxFilesPerOperation) files (attempted: \(count))"
            case .symlinkTarget(let path):
                "Path resolves through symlink to unexpected location: \(path)"
            case .sipProtected(let path):
                "Path is protected by System Integrity Protection: \(path)"
            case .outsideUserScope(let path):
                "Path is outside the allowed user scope: \(path)"
            case .invalidPath(let path):
                "Path is invalid or contains illegal characters: \(path)"
            case .userExcluded(let path):
                "Path is inside an excluded folder: \(path)"
            }
        }
    }

    public init() {}

    public func validateDeletion(paths: [URL]) throws {
        if paths.count > MCConstants.maxFilesPerOperation {
            throw SafetyError.tooManyFiles(paths.count)
        }

        for path in paths {
            try validatePath(path)
        }
    }

    public func validatePath(
        _ url: URL,
        excludedFolders: [String] = FolderExclusionPreferences.paths
    ) throws {
        let original = url.path(percentEncoded: false)
        guard url.isFileURL, original.hasPrefix("/"), !original.contains("\0"),
              !original.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw SafetyError.invalidPath(original)
        }

        let standardized = url.standardizedFileURL
        let resolved = standardized.resolvingSymlinksInPath()
        let originalCanonical = Self.canonicalizeMacOSFirmlinks(standardized.path(percentEncoded: false))
        let resolvedPath = resolved.path(percentEncoded: false)
        let resolvedCanonical = Self.canonicalizeMacOSFirmlinks(resolvedPath)

        for candidate in [originalCanonical, resolvedCanonical] {
            let path = Self.canonicalizeMacOSFirmlinks(candidate.lowercased())
            if PathExclusion.isInside(path, root: "/system") {
                throw SafetyError.sipProtected(resolvedPath)
            }

            if Self.protectedRoots.contains(path)
                || PathExclusion.isExcluded(path: path, by: Self.protectedTrees)
                || Self.isProtectedSystemDataPath(path) {
                throw SafetyError.protectedPath(resolvedPath)
            }
        }

        if PathExclusion.isExcluded(path: resolvedCanonical, by: excludedFolders)
            || PathExclusion.isExcluded(path: originalCanonical, by: excludedFolders) {
            throw SafetyError.userExcluded(resolvedPath)
        }

        guard originalCanonical == resolvedCanonical else {
            throw SafetyError.symlinkTarget(resolvedPath)
        }

        do {
            let resources = try resolved.resourceValues(forKeys: [.isVolumeKey, .volumeURLKey])
            if resources.isVolume == true || Self.isVolumeTrashRoot(resolvedCanonical, volume: resources.volume) {
                throw SafetyError.protectedPath(resolvedPath)
            }
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return
        }
    }

    private static func isProtectedSystemDataPath(_ path: String) -> Bool {
        if PathExclusion.isInside(path, root: "/library") {
            return !path.hasPrefix("/library/caches/") && !path.hasPrefix("/library/logs/")
        }
        if PathExclusion.isInside(path, root: "/var") {
            return !allowedVarPrefixes.contains(where: path.hasPrefix)
        }
        return PathExclusion.isInside(path, root: "/private")
    }

    private static let allowedVarPrefixes = ["/var/log/"] + [
        MCConstants.darwinUserCacheDir,
        MCConstants.darwinUserTempDir,
    ].compactMap { url in
        url.map { canonicalizeMacOSFirmlinks($0.standardizedFileURL.path(percentEncoded: false)).lowercased() + "/" }
    }

    private static func isVolumeTrashRoot(_ path: String, volume: URL?) -> Bool {
        guard let volume else { return false }
        let root = volume.appending(path: ".Trashes").path(percentEncoded: false)
        let canonicalRoot = canonicalizeMacOSFirmlinks(root)
        let canonicalUserTrash = canonicalizeMacOSFirmlinks(volumeTrash(on: volume).path(percentEncoded: false))
        return path.lowercased() == canonicalRoot.lowercased() || path.lowercased() == canonicalUserTrash.lowercased()
    }

    private static let protectedTrees = MCConstants.protectedPaths.map { $0.lowercased() }

    private static let protectedRoots: Set<String> = [
        "/applications", "/users", "/volumes", "/tmp",
        canonicalizeMacOSFirmlinks(MCConstants.home.path(percentEncoded: false)).lowercased(),
        canonicalizeMacOSFirmlinks(MCConstants.userLibrary.path(percentEncoded: false)).lowercased(),
        canonicalizeMacOSFirmlinks(MCConstants.userTrash.path(percentEncoded: false)).lowercased(),
    ]

    public static func volumeTrash(on volume: URL) -> URL {
        volume.appending(path: ".Trashes/\(getuid())")
    }

    public static func isInTrash(_ url: URL) -> Bool {
        let path = canonicalizeMacOSFirmlinks(url.standardizedFileURL.path(percentEncoded: false))
        let homeTrash = canonicalizeMacOSFirmlinks(MCConstants.userTrash.path(percentEncoded: false))
        if path != homeTrash, PathExclusion.isInside(path, root: homeTrash) {
            return true
        }
        guard let volume = try? url.resourceValues(forKeys: [.volumeURLKey]).volume else {
            return false
        }
        let volumeTrashPath = canonicalizeMacOSFirmlinks(volumeTrash(on: volume).path(percentEncoded: false))
        return path != volumeTrashPath && PathExclusion.isInside(path, root: volumeTrashPath)
    }

    static func canonicalizeMacOSFirmlinks(_ rawPath: String) -> String {
        var path = rawPath
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        let dataVolume = "/System/Volumes/Data"
        if path == dataVolume { return "/" }
        let dataRelativePath = path.hasPrefix(dataVolume + "/") ? String(path.dropFirst(dataVolume.count)) : path
        for firmlink in ["var", "tmp", "etc"] {
            let privatePrefix = "/private/\(firmlink)"
            if dataRelativePath == privatePrefix {
                return "/\(firmlink)"
            }
            if dataRelativePath.hasPrefix(privatePrefix + "/") {
                return "/\(firmlink)" + dataRelativePath.dropFirst(privatePrefix.count)
            }
        }
        return dataRelativePath
    }

    public func isProtectedApp(_ bundleID: String) -> Bool {
        MCConstants.protectedApps.contains(bundleID)
    }
}
