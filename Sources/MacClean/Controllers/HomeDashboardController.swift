import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class HomeDashboardController {
    private static let specsRefreshInterval: Duration = .seconds(5)
    private static let assetAdviceMinimumSize: UInt64 = 500_000_000

    private(set) var specs = SystemSpecsProvider.current()
    private(set) var systemAssetReport: SystemAssetReport?

    var reportWorthAdvising: SystemAssetReport? {
        guard let report = systemAssetReport, report.totalAssetSize > Self.assetAdviceMinimumSize else { return nil }
        return report
    }

    func monitor() async {
        systemAssetReport = await SystemAssetAdvisor.generateReport()
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.specsRefreshInterval)
            specs = SystemSpecsProvider.current()
        }
    }
}
