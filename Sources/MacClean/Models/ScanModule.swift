import Foundation
import MacCleanKit

public protocol ScanModule: Sendable {
    var id: String { get }
    var name: String { get }
    var category: ModuleCategory { get }
    var includedInSmartScan: Bool { get }
    func scan() async -> [ScanResult]
    func scanOutcome() async -> ModuleScanOutcome
    func scan(onProgress: (@Sendable (_ phase: String, _ count: Int, _ bytes: UInt64, _ fraction: Double) -> Void)?) async -> [ScanResult]
}

public extension ScanModule {
    var includedInSmartScan: Bool { true }

    func scanOutcome() async -> ModuleScanOutcome {
        ModuleScanOutcome(results: await scan())
    }

    func scan(onProgress: (@Sendable (_ phase: String, _ count: Int, _ bytes: UInt64, _ fraction: Double) -> Void)?) async -> [ScanResult] {
        await scan()
    }
}

public enum ModuleCategory: String, CaseIterable, Sendable {
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case files = "Files"
}

public struct ModuleScanOutcome: Sendable {
    public let results: [ScanResult]
    public let permissionDenied: Bool

    public init(results: [ScanResult], permissionDenied: Bool = false) {
        self.results = results
        self.permissionDenied = permissionDenied
    }
}
