import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
public final class ScanCoordinator {
    public enum ScanState: Sendable {
        case idle
        case scanning(progress: Double, currentModule: String, phase: String, filesScanned: Int, sizeFound: UInt64)
        case completed(results: [ModuleScanResult])
        case failed(Error)
    }

    public private(set) var state: ScanState = .idle
    public private(set) var filesScanned: Int = 0
    public private(set) var totalSizeFound: UInt64 = 0
    public private(set) var completedResults: [ModuleScanResult] = []

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    private var modules: [ScanModule] = []

    public init() {}

    public func registerModules(_ newModules: [ScanModule]) {
        modules.append(contentsOf: newModules)
    }

    public func scanSmart(mode: SmartScanMode, onStateChange: (@MainActor (ScanState) -> Void)? = nil) {
        let targets: [ScanModule]
        switch mode {
        case .safe:
            targets = modules.filter { $0.includedInSmartScan && $0.id != "projectJunk" }
        case .deep:
            targets = modules.filter { $0.includedInSmartScan }
        }
        scanModules(targets, onStateChange: onStateChange)
    }

    public func cancel() {
        scanTask?.cancel()
        scanTask = nil
        filesScanned = 0
        totalSizeFound = 0
        completedResults = []
        state = .idle
    }

    private func scanModules(
        _ modulesToScan: [ScanModule],
        onStateChange: (@MainActor (ScanState) -> Void)? = nil
    ) {
        scanTask?.cancel()

        filesScanned = 0
        totalSizeFound = 0
        completedResults = []

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            var results: [ModuleScanResult] = []
            let totalModules = modulesToScan.count
            var runningBaseFiles = 0
            var runningBaseBytes: UInt64 = 0

            for (index, module) in modulesToScan.enumerated() {
                if Task.isCancelled { break }

                let baseProgress = Double(index) / Double(totalModules)
                let moduleFraction = 1.0 / Double(totalModules)

                await self.updateProgress(
                    progress: baseProgress,
                    currentModule: module.name,
                    phase: module.name,
                    files: runningBaseFiles,
                    size: runningBaseBytes,
                    onStateChange: onStateChange
                )

                let start = Date()
                let currentBaseFiles = runningBaseFiles
                let currentBaseBytes = runningBaseBytes

                let rawResults = await module.scan(onProgress: { [weak self] phase, count, bytes, fraction in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let currentProgress = min(0.99, baseProgress + (moduleFraction * fraction))
                        self.updateProgress(
                            progress: currentProgress,
                            currentModule: module.name,
                            phase: phase,
                            files: currentBaseFiles + count,
                            size: currentBaseBytes + bytes,
                            onStateChange: onStateChange
                        )
                    }
                })

                if Task.isCancelled { break }

                let duration = Date().timeIntervalSince(start)
                let moduleResult = ModuleScanResult(
                    moduleID: module.id,
                    moduleName: module.name,
                    categories: rawResults,
                    scanDuration: duration
                )
                results.append(moduleResult)

                runningBaseFiles += moduleResult.totalFileCount
                runningBaseBytes += moduleResult.totalSize

                let completedProgress = Double(index + 1) / Double(totalModules)
                await self.recordModuleCompleted(
                    result: moduleResult,
                    progress: completedProgress,
                    onStateChange: onStateChange
                )
            }

            if !Task.isCancelled {
                await self.completeScan(results: results, onStateChange: onStateChange)
            }
        }
    }

    @MainActor
    private func updateProgress(
        progress: Double,
        currentModule: String,
        phase: String,
        files: Int,
        size: UInt64,
        onStateChange: (@MainActor (ScanState) -> Void)?
    ) {
        self.state = .scanning(
            progress: progress,
            currentModule: currentModule,
            phase: phase,
            filesScanned: files,
            sizeFound: size
        )
        onStateChange?(self.state)
    }

    @MainActor
    private func recordModuleCompleted(
        result: ModuleScanResult,
        progress: Double,
        onStateChange: (@MainActor (ScanState) -> Void)?
    ) {
        self.completedResults.append(result)
        self.filesScanned += result.totalFileCount
        self.totalSizeFound += result.totalSize
        self.state = .scanning(
            progress: progress,
            currentModule: result.moduleName,
            phase: result.moduleName,
            filesScanned: self.filesScanned,
            sizeFound: self.totalSizeFound
        )
        onStateChange?(self.state)
    }

    @MainActor
    private func completeScan(
        results: [ModuleScanResult],
        onStateChange: (@MainActor (ScanState) -> Void)?
    ) {
        self.state = .completed(results: results)
        onStateChange?(self.state)
    }
}
