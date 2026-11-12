import SwiftUI
import AppKit
import MacCleanKit

struct SystemAssetAdvisorView: View {
    @State private var controller: SystemAssetAdvisorController = SystemAssetAdvisorController()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if controller.isLoading && controller.report == nil {
                loadingView
            } else if let report: SystemAssetReport = controller.report {
                ScrollView {
                    VStack(spacing: 16) {
                        overviewCard(report: report)
                        safeWaysList(report: report)
                    }
                    .padding(20)
                }
            } else {
                emptyView
            }
        }
        .task {
            await controller.scan()
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("System Storage Advisor")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Safe Space Reclaim")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .systemBlue).opacity(0.12))
                        .foregroundStyle(Color(nsColor: .systemBlue))
                        .clipShape(Capsule())
                }

                Text("Safely reclaim storage from Apple Intelligence, Siri, and system AI models")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await controller.scan()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(controller.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Scanning system AI and asset models...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(nsColor: .systemGreen))
            Text("No large system AI models detected")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func overviewCard(report: SystemAssetReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .systemIndigo).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .systemIndigo))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Detected System Models & Storage")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        if report.isSiriDisabled {
                            Text("Siri Disabled")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.18))
                                .foregroundStyle(Color.orange)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Total \(report.totalFormattedSize) identified across models and caches.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(report.totalFormattedSize)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Reclaimable Space")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 16) {
                metricSummary(
                    title: "Purgeable System Models",
                    value: report.purgeableFormattedSize,
                    detail: "SIP protected (auto-purged via Settings)",
                    icon: "shield.lefthalf.filled",
                    tint: Color(nsColor: .systemIndigo)
                )

                metricSummary(
                    title: "Directly Cleanable",
                    value: report.directlyCleanableFormattedSize,
                    detail: "Cleanable immediately via MacClean",
                    icon: "sparkles",
                    tint: Color(nsColor: .systemBlue)
                )
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    private func metricSummary(title: String, value: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func safeWaysList(report: SystemAssetReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safe Storage Reclamation Methods")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.leading, 2)

            ForEach(report.items) { item in
                itemCard(item: item)
            }
        }
    }

    private func itemCard(item: SystemAssetItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(badgeColor(for: item.kind).opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName(for: item.kind))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(badgeColor(for: item.kind))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(item.serviceStatusText)
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(badgeColor(for: item.kind).opacity(0.12))
                            .foregroundStyle(badgeColor(for: item.kind))
                            .clipShape(Capsule())
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(item.formattedSize)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(item.safeReclaimExplanation)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                if item.settingsURL != nil {
                    Button {
                        controller.openSettings(for: item)
                    } label: {
                        HStack(spacing: 5) {
                            Text(settingsButtonTitle(for: item.kind))
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.small)
                } else if item.isDirectlyCleanable {
                    Button {
                        Task {
                            await controller.cleanUserCache()
                        }
                    } label: {
                        if controller.isCleaning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Clean Now")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemGreen))
                    .controlSize(.small)
                    .disabled(controller.isCleaning || item.size == 0)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func iconName(for kind: SystemAssetKind) -> String {
        switch kind {
        case .siriAndAppleIntelligence: return "sparkles"
        case .dictation: return "waveform.and.mic"
        case .assistantCache: return "bolt.horizontal.circle.fill"
        case .coreSpotlightIndex: return "magnifyingglass.circle.fill"
        }
    }

    private func badgeColor(for kind: SystemAssetKind) -> Color {
        switch kind {
        case .siriAndAppleIntelligence: return Color(nsColor: .systemIndigo)
        case .dictation: return Color(nsColor: .systemTeal)
        case .assistantCache: return Color(nsColor: .systemGreen)
        case .coreSpotlightIndex: return Color(nsColor: .systemOrange)
        }
    }

    private func settingsButtonTitle(for kind: SystemAssetKind) -> String {
        switch kind {
        case .siriAndAppleIntelligence: return "Open Siri & AI Settings"
        case .dictation: return "Open Keyboard & Dictation Settings"
        default: return "Open Settings"
        }
    }
}
