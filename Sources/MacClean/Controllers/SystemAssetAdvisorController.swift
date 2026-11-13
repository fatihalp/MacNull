import Foundation
import Observation
import AppKit
import MacCleanKit

@MainActor
@Observable
public final class SystemAssetAdvisorController {
    public private(set) var report: SystemAssetReport? = nil
    public private(set) var isLoading: Bool = false
    public private(set) var isCleaning: Bool = false
    public private(set) var cleanedMessage: String? = nil

    public init() {}

    public func scan() async {
        isLoading = true
        let generatedReport: SystemAssetReport = await SystemAssetAdvisor.generateReport()
        self.report = generatedReport
        self.isLoading = false
    }

    public func cleanUserCache() async {
        guard !isCleaning else { return }
        isCleaning = true
        let freedBytes: UInt64 = await Task.detached(priority: .userInitiated) {
            SystemAssetAdvisor.cleanUserAssistantCaches()
        }.value
        self.cleanedMessage = "\(FileSizeFormatter.format(freedBytes)) cleaned successfully."
        self.isCleaning = false
        await scan()
    }

    public func openSettings(for item: SystemAssetItem) {
        guard let url: URL = item.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }
}
