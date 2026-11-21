import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class SmartScanController {
    var scanMode: SmartScanMode = .safe
    private(set) var scanState: SmartScanState = .idle
    private(set) var completedModules: [CompletedModule] = []
    private(set) var currentModuleName = ""
    private(set) var askForSupport = false
    private(set) var review: ReviewSelection?
    var showingReview = false
    var reviewSectionID: String?
    @ObservationIgnored private var cleanTask: Task<Void, Never>?
    @ObservationIgnored private var reviewTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    private let coordinator: ScanCoordinator
    private let engine: CleaningEngine
    private var moduleResults: [ModuleScanResult] = []

    init(coordinator: ScanCoordinator, engine: CleaningEngine) {
        self.coordinator = coordinator
        self.engine = engine
    }

    func startScan() {
        startScan(mode: scanMode)
    }

    func startScan(mode: SmartScanMode) {
        if case .cleaning = scanState { return }
        self.scanMode = mode
        resetScan()
        let initialModuleName = "System Junk"
        currentModuleName = initialModuleName
        scanState = .scanning(
            phase: initialModuleName, progress: 0.0, filesFound: 0, sizeFound: 0
        )
        coordinator.scanSmart(mode: scanMode) { [weak self] state in
            self?.receive(state)
        }
    }

    private func receive(_ state: ScanCoordinator.ScanState) {
        completedModules = coordinator.completedResults.map { result in
            CompletedModule(
                name: result.moduleName,
                icon: SmartScanModules.order.first { $0.name == result.moduleName }?.icon ?? "circle",
                fileCount: result.totalFileCount,
                size: result.totalSize
            )
        }
        switch state {
        case .scanning(let progress, let module, let phase, let files, let size):
            currentModuleName = module
            scanState = .scanning(phase: phase, progress: progress, filesFound: files, sizeFound: size)
        case .completed(let results):
            prepareReview(results)
        case .idle, .failed:
            scanState = .idle
        }
    }

    private func prepareReview(_ results: [ModuleScanResult]) {
        let totalSize = results.reduce(UInt64(0)) { $0 + $1.totalSize }
        let fileCount = results.reduce(0) { $0 + $1.totalFileCount }
        guard fileCount > 0 else {
            scanState = .empty
            return
        }
        scanState = .scanning(
            phase: "Preparing results...", progress: 1,
            filesFound: fileCount, sizeFound: totalSize
        )
        let generation = generation
        let currentMode = scanMode
        reviewTask = Task {
            let data = await ReviewService.build(modules: results, includeEmptySystemJunkCategories: true)
            guard !Task.isCancelled, generation == self.generation else { return }
            moduleResults = results
            review = ReviewSelection(data: data, mode: currentMode)
            showingReview = true
            reviewSectionID = nil
            scanState = .results(
                cleanup: totalSize, protection: 0, performance: 0,
                totalSize: totalSize, moduleResults: results
            )
            reviewTask = nil
        }
    }

    var cleanupWarning: String {
        var warnings: [String] = []
        if review?.scanMode == .deep {
            warnings.append(SmartScanMode.deepCleanupWarning)
        }
        if review?.hasSelectedAIConversations() == true {
            warnings.append("The selection includes AI conversation history or session data.")
        }
        if let review, review.data.categories.contains(where: {
            $0.category == .universalBinaries && review.selectedSize(ofCategory: $0.id) > 0
        }) {
            warnings.append("Selected universal binaries are modified in place.")
        }
        warnings.append("Files selected for removal move to the Trash. Files already in the Trash are permanently deleted.")
        return warnings.joined(separator: "\n\n")
    }

    func runCleanup(deepCleanConfirmed: Bool = false) {
        guard case .results = scanState, let review, review.selectedCount > 0,
              review.scanMode != .deep || deepCleanConfirmed else { return }
        let modules = moduleResults
        let results = SmartScanCleanup.allResults(from: modules)
        let data = review.data
        let flags = review.snapshot()
        let generation = generation
        showingReview = false
        scanState = .cleaning(progress: 0)
        cleanTask = Task {
            let selection = await Task.detached(priority: .userInitiated) {
                data.selectedURLs(flags: flags)
            }.value
            guard generation == self.generation else { return }
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selection,
                engine: engine,
                onProgress: { progress in
                    Task { @MainActor in
                        guard generation == self.generation, case .cleaning = self.scanState else { return }
                        self.scanState = .cleaning(progress: progress.fraction)
                    }
                }
            )
            guard generation == self.generation else { return }
            let breakdown = SmartScanCleanup.recentlyCleanedBreakdown(
                from: modules, selectedItems: result.removedURLs
            )
            askForSupport = SupportAskLedger.shared.shouldAsk(for: result.summary(selectedCount: selection.count))
            scanState = .done(freedSize: result.freedBytes, breakdown: breakdown, issueCount: result.errors.count)
            cleanTask = nil
        }
    }

    func cancelCleaning() {
        cleanTask?.cancel()
    }

    func cancelScan() {
        resetScan()
    }

    func resetScan() {
        generation &+= 1
        coordinator.cancel()
        reviewTask?.cancel()
        cleanTask?.cancel()
        reviewTask = nil
        cleanTask = nil
        review = nil
        showingReview = false
        reviewSectionID = nil
        askForSupport = false
        completedModules = []
        moduleResults = []
        currentModuleName = ""
        scanState = .idle
    }
}
