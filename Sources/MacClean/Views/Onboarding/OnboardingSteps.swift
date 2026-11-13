import SwiftUI
import AppKit
import MacCleanKit

struct OnboardingWelcomeStep: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(MCConstants.appName)
                    .font(.system(size: 40, weight: .semibold))
            }
            Text("Free up space safely. Nothing is deleted for good until you empty the Trash.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            OnboardingPrimaryButton(title: "Get started", systemImage: "arrow.right", action: onStart)
        }
    }
}

struct OnboardingScanStep: View {
    let scan: SmartScanController

    var body: some View {
        VStack(spacing: 20) {
            Text("Running your first scan…")
                .font(.system(size: 22, weight: .semibold))
            ProgressView(value: progress)
                .frame(maxWidth: 420)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(scan.completedModules.filter { $0.size > 0 }) { module in
                        HStack(spacing: 10) {
                            Image(systemName: module.icon)
                                .frame(width: 22)
                                .foregroundStyle(.secondary)
                            Text(module.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(FileSizeFormatter.format(module.size))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                }
                .animation(.easeOut(duration: 0.25), value: scan.completedModules.count)
            }
            .frame(maxWidth: 420, maxHeight: 280)
        }
    }

    private var progress: Double {
        if case .scanning(_, let progress, _, _) = scan.scanState { return progress }
        return 1
    }
}

struct OnboardingResultsStep: View {
    let bytes: UInt64
    let breakdown: [(name: String, bytes: UInt64)]
    let onClean: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 4) {
                Text(FileSizeFormatter.format(bytes))
                    .font(.system(size: 52, weight: .semibold))
                Text("safe to clean on your Mac")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(breakdown, id: \.name) { row in
                    HStack {
                        Text(row.name)
                        Spacer()
                        Text(FileSizeFormatter.format(row.bytes)).monospacedDigit()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 300)
            VStack(spacing: 10) {
                OnboardingPrimaryButton(
                    title: "Move \(FileSizeFormatter.format(bytes)) to Trash",
                    systemImage: "trash",
                    action: onClean
                )
                Button("Review everything first", action: onReview)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
    }
}

struct OnboardingProgressStep: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(title)
                .font(.system(size: 16, weight: .medium))
        }
    }
}

struct OnboardingCleanedStep: View {
    let bytes: UInt64
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("\(FileSizeFormatter.format(bytes)) moved to the Trash")
                .font(.system(size: 22, weight: .semibold))
            Text("You can put anything back until you empty the Trash. Space is freed once you do.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            OnboardingPrimaryButton(title: "Continue", systemImage: nil, action: onContinue)
        }
    }
}

struct OnboardingFullDiskAccessStep: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Want \(MCConstants.appName) to look deeper?")
                    .font(.system(size: 22, weight: .semibold))
                Text("Some clutter hides in folders macOS keeps locked.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                promise("eye", "Only cleans when you say")
                promise("icloud.slash", "Nothing leaves your Mac")
                promise("trash", "Everything goes to the Trash")
            }
            Text("macOS calls this Full Disk Access. Turn it off anytime in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            VStack(spacing: 10) {
                OnboardingPrimaryButton(title: "Let \(MCConstants.appName) in", systemImage: "arrow.up.right", action: onAllow)
                Button("Not now", action: onSkip)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
    }

    private func promise(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text).font(.system(size: 13))
        }
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(minWidth: 220)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
