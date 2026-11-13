import SwiftUI
import MacCleanKit

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @State private var controller: OnboardingController

    init(scan: SmartScanController, onFinish: @escaping () -> Void) {
        _controller = State(initialValue: OnboardingController(scan: scan, onFinish: onFinish))
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            Group {
                switch controller.step {
                case .welcome:
                    OnboardingWelcomeStep(onStart: controller.start)
                case .scanning:
                    OnboardingScanStep(scan: appState.smartScanController)
                case .results:
                    OnboardingResultsStep(
                        bytes: controller.safeBytes,
                        breakdown: controller.breakdown,
                        onClean: controller.moveSafeItemsToTrash,
                        onReview: controller.reviewEverything
                    )
                case .cleaning:
                    OnboardingProgressStep(title: "Moving to Trash…")
                case .cleaned:
                    OnboardingCleanedStep(bytes: controller.safeBytes, onContinue: controller.continueAfterCleaning)
                case .fullDiskAccess:
                    OnboardingFullDiskAccessStep(
                        onAllow: controller.openFullDiskAccess,
                        onSkip: controller.skipFullDiskAccess
                    )
                }
            }
            .id(controller.step)
            .transition(.opacity)
            .padding(40)
        }
        .animation(.easeInOut(duration: 0.3), value: controller.step)
        .onChange(of: appState.smartScanController.scanState.phaseKey) { controller.scanStateChanged() }
    }
}
