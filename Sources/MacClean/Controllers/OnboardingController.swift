import Foundation
import Observation

@MainActor @Observable
final class OnboardingController {
    enum Step {
        case welcome
        case scanning
        case results
        case cleaning
        case cleaned
        case fullDiskAccess
    }

    static let completedKey = "hasCompletedOnboarding"

    private(set) var step: Step = .welcome
    private let scan: SmartScanController
    private let onFinish: () -> Void

    init(scan: SmartScanController, onFinish: @escaping () -> Void) {
        self.scan = scan
        self.onFinish = onFinish
    }

    var safeBytes: UInt64 { scan.review?.selectedSize ?? 0 }

    var breakdown: [(name: String, bytes: UInt64)] {
        guard let review = scan.review else { return [] }
        return review.data.sections
            .map { (name: $0.name, bytes: review.selectedSize(ofSection: $0)) }
            .filter { $0.bytes > 0 }
            .sorted { $0.bytes > $1.bytes }
            .prefix(4)
            .map { $0 }
    }

    func start() {
        step = .scanning
        scan.startScan(mode: .safe)
    }

    func scanStateChanged() {
        switch scan.scanState {
        case .results where step == .scanning:
            if safeBytes > 0 { step = .results } else { askForFullDiskAccessOrFinish() }
        case .empty where step == .scanning:
            askForFullDiskAccessOrFinish()
        case .done where step == .cleaning:
            step = .cleaned
        default:
            break
        }
    }

    func moveSafeItemsToTrash() {
        step = .cleaning
        scan.runCleanup()
    }

    func reviewEverything() {
        finish()
    }

    func continueAfterCleaning() {
        askForFullDiskAccessOrFinish()
    }

    func openFullDiskAccess() {
        PermissionManager.shared.openFullDiskAccessSettings()
        finish()
    }

    func skipFullDiskAccess() {
        finish()
    }

    private func askForFullDiskAccessOrFinish() {
        if PermissionManager.shared.hasFullDiskAccess {
            finish()
        } else {
            step = .fullDiskAccess
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        onFinish()
    }
}
