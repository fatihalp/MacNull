import Foundation

public enum SystemAssetKind: String, Sendable, CaseIterable {
    case siriAndAppleIntelligence = "siri_apple_intelligence"
    case dictation = "dictation"
    case assistantCache = "assistant_cache"
    case coreSpotlightIndex = "core_spotlight_index"
}

public struct SystemAssetItem: Identifiable, Sendable {
    public let id: String
    public let kind: SystemAssetKind
    public let title: String
    public let subtitle: String
    public let paths: [URL]
    public let size: UInt64
    public let isServiceActive: Bool
    public let serviceStatusText: String
    public let safeReclaimExplanation: String
    public let settingsURL: URL?
    public let isDirectlyCleanable: Bool

    public init(
        id: String,
        kind: SystemAssetKind,
        title: String,
        subtitle: String,
        paths: [URL],
        size: UInt64,
        isServiceActive: Bool,
        serviceStatusText: String,
        safeReclaimExplanation: String,
        settingsURL: URL?,
        isDirectlyCleanable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.paths = paths
        self.size = size
        self.isServiceActive = isServiceActive
        self.serviceStatusText = serviceStatusText
        self.safeReclaimExplanation = safeReclaimExplanation
        self.settingsURL = settingsURL
        self.isDirectlyCleanable = isDirectlyCleanable
    }

    public var formattedSize: String {
        FileSizeFormatter.format(size)
    }
}

public struct SystemAssetReport: Sendable {
    public let items: [SystemAssetItem]
    public let totalAssetSize: UInt64
    public let purgeableSystemSize: UInt64
    public let directlyCleanableSize: UInt64
    public let isSiriDisabled: Bool

    public init(
        items: [SystemAssetItem],
        totalAssetSize: UInt64,
        purgeableSystemSize: UInt64,
        directlyCleanableSize: UInt64,
        isSiriDisabled: Bool
    ) {
        self.items = items
        self.totalAssetSize = totalAssetSize
        self.purgeableSystemSize = purgeableSystemSize
        self.directlyCleanableSize = directlyCleanableSize
        self.isSiriDisabled = isSiriDisabled
    }

    public var totalFormattedSize: String {
        FileSizeFormatter.format(totalAssetSize)
    }

    public var purgeableFormattedSize: String {
        FileSizeFormatter.format(purgeableSystemSize)
    }

    public var directlyCleanableFormattedSize: String {
        FileSizeFormatter.format(directlyCleanableSize)
    }
}

public enum SystemAssetAdvisor {
    public static func generateReport() async -> SystemAssetReport {
        let isSiriActive: Bool = readBooleanPreference(
            domain: "com.apple.assistant.support",
            key: "Assistant Enabled",
            defaultValue: true
        )

        let isDictationActive: Bool = readBooleanPreference(
            domain: "com.apple.speech.recognition.AppleSpeechRecognition.prefs",
            key: "DictationIMUseOnlyOfflineDictation",
            defaultValue: false
        )

        let siriUnderstandingSize: UInt64 = computeDirectorySize(MCConstants.siriUnderstandingAsset)
        let siriTTSSize: UInt64 = computeDirectorySize(MCConstants.siriTTSAsset)
        let totalSiriSize: UInt64 = siriUnderstandingSize + siriTTSSize

        let speechSize: UInt64 = computeDirectorySize(MCConstants.speechRecognitionAsset)

        let assistantCacheSize: UInt64 = computeDirectorySize(MCConstants.assistantLLMCache)
        let siriactionsdTempSize: UInt64 = computeDirectorySize(darwinSiriActionsTempDir)
        let totalCleanableSize: UInt64 = assistantCacheSize + siriactionsdTempSize

        let spotlightPipelineSize: UInt64 = computeDirectorySize(MCConstants.coreSpotlightPipelineStorage)

        var items: [SystemAssetItem] = []

        if totalSiriSize > 0 {
            let statusText: String = isSiriActive ? "Siri Active" : "Siri Disabled"
            let explanation: String = isSiriActive
                ? "System models are SIP protected. Disabling Siri or Apple Intelligence allows macOS to automatically purge these models in the background."
                : "Siri is disabled on your system, but offline AI models are stored on disk. Reviewing System Settings > Apple Intelligence & Siri triggers macOS to purge them."

            items.append(SystemAssetItem(
                id: "siri_apple_intelligence",
                kind: .siriAndAppleIntelligence,
                title: "Apple Intelligence & Siri Models",
                subtitle: "com_apple_MobileAsset_UAF_Siri_Understanding (\(FileSizeFormatter.format(siriUnderstandingSize)))",
                paths: [MCConstants.siriUnderstandingAsset, MCConstants.siriTTSAsset],
                size: totalSiriSize,
                isServiceActive: isSiriActive,
                serviceStatusText: statusText,
                safeReclaimExplanation: explanation,
                settingsURL: URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension"),
                isDirectlyCleanable: false
            ))
        }

        if speechSize > 0 {
            let explanation: String = "Offline speech recognition models occupy disk space. Disabling offline dictation in System Settings > Keyboard > Dictation triggers macOS to purge this asset."

            items.append(SystemAssetItem(
                id: "dictation_offline_models",
                kind: .dictation,
                title: "Offline Dictation & Speech Models",
                subtitle: "com_apple_MobileAsset_UAF_Speech_AutomaticSpeechRecognition",
                paths: [MCConstants.speechRecognitionAsset],
                size: speechSize,
                isServiceActive: isDictationActive,
                serviceStatusText: "Offline Speech Package",
                safeReclaimExplanation: explanation,
                settingsURL: URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"),
                isDirectlyCleanable: false
            ))
        }

        items.append(SystemAssetItem(
            id: "assistant_user_cache",
            kind: .assistantCache,
            title: "Siri & Assistant Machine Learning Caches",
            subtitle: "~/Library/Assistant/LLMCache and temporary caches",
            paths: [MCConstants.assistantLLMCache, darwinSiriActionsTempDir].compactMap { $0 },
            size: totalCleanableSize,
            isServiceActive: false,
            serviceStatusText: totalCleanableSize > 0 ? "Directly Cleanable" : "Clean",
            safeReclaimExplanation: "Local model and embedding vector caches accumulated by Siri and system AI processes in the user directory. Safe to clean directly without affecting system stability.",
            settingsURL: nil,
            isDirectlyCleanable: true
        ))

        if spotlightPipelineSize > 0 {
            items.append(SystemAssetItem(
                id: "core_spotlight_index",
                kind: .coreSpotlightIndex,
                title: "CoreSpotlight Document Pipeline Storage",
                subtitle: "~/Library/Metadata/CoreSpotlight/DocumentProcessing/PipelineStorage",
                paths: [MCConstants.coreSpotlightPipelineStorage],
                size: spotlightPipelineSize,
                isServiceActive: true,
                serviceStatusText: "Spotlight AI Index",
                safeReclaimExplanation: "Local semantic document index for Spotlight. Can be cleaned directly or rebuilt via the Maintenance menu.",
                settingsURL: nil,
                isDirectlyCleanable: true
            ))
        }

        let totalAssetSize: UInt64 = items.reduce(0 as UInt64) { $0 + $1.size }
        let purgeableSystemSize: UInt64 = totalSiriSize + speechSize
        let directlyCleanableSize: UInt64 = totalCleanableSize + spotlightPipelineSize

        return SystemAssetReport(
            items: items,
            totalAssetSize: totalAssetSize,
            purgeableSystemSize: purgeableSystemSize,
            directlyCleanableSize: directlyCleanableSize,
            isSiriDisabled: !isSiriActive
        )
    }

    public static func cleanUserAssistantCaches() -> UInt64 {
        var freedBytes: UInt64 = 0
        let fileManager: FileManager = FileManager.default

        let targets: [URL] = [
            MCConstants.assistantLLMCache,
            darwinSiriActionsTempDir
        ].compactMap { $0 }

        for target in targets {
            let path: String = target.path(percentEncoded: false)
            guard fileManager.fileExists(atPath: path) else { continue }
            if let enumerator = fileManager.enumerator(
                at: target,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
                options: []
            ) {
                while let itemURL = enumerator.nextObject() as? URL {
                    if let values = try? itemURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]),
                       let size = values.totalFileAllocatedSize ?? values.fileSize {
                        freedBytes += UInt64(size)
                    }
                }
            }
            if let contents = try? fileManager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil) {
                for fileURL in contents {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
        return freedBytes
    }

    public static var darwinSiriActionsTempDir: URL? {
        MCConstants.darwinUserTempDir?.appending(path: "com.apple.siriactionsd")
    }

    private static func readBooleanPreference(domain: String, key: String, defaultValue: Bool) -> Bool {
        let domainCF: CFString = domain as CFString
        let keyCF: CFString = key as CFString
        guard let value = CFPreferencesCopyAppValue(keyCF, domainCF) else {
            return defaultValue
        }
        if let boolVal = value as? Bool {
            return boolVal
        }
        if let numVal = value as? NSNumber {
            return numVal.boolValue
        }
        return defaultValue
    }

    public static func computeDirectorySize(_ url: URL?) -> UInt64 {
        guard let url else { return 0 }
        let path: String = url.path(percentEncoded: false)
        let fileManager: FileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return 0 }

        var total: UInt64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
            options: []
        ) else {
            return 0
        }

        while let itemURL = enumerator.nextObject() as? URL {
            if let values = try? itemURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]),
               values.isDirectory == false,
               let size = values.totalFileAllocatedSize ?? values.fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}
