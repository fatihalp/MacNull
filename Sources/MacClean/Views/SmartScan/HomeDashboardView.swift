import SwiftUI
import AppKit
import MacCleanKit

struct HomeDashboardView: View {
    @Environment(AppState.self) private var appState: AppState
    var onStartScan: ((SmartScanMode) -> Void)? = nil

    @State private var selectedMode: SmartScanMode = .safe
    @State private var controller = HomeDashboardController()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                systemHeaderCard

                if let report = controller.reportWorthAdvising {
                    systemAssetAdviceBanner(report: report)
                }

                smartScanHeroCard

                pillarsSection
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await controller.monitor()
        }
    }

    private var systemHeaderCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: hardwareIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.specs.modelName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(controller.specs.chipName) · \(controller.specs.cpuCores) Cores · \(controller.specs.osVersion)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let level = controller.specs.batteryLevel {
                    HStack(spacing: 5) {
                        Image(systemName: controller.specs.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                            .font(.system(size: 12))
                            .foregroundStyle(controller.specs.isCharging ? Color(nsColor: .systemGreen) : Color.secondary)
                        Text("\(level)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(Capsule())
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(nsColor: .systemIndigo))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(controller.specs.diskName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("\(controller.specs.diskFormat) · \("Internal Storage")")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if controller.specs.isLowDiskSpace {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Low Disk Space")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                    }

                    Text("\(controller.specs.diskFreeFormatted) \("available")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let usedWidth = max(0, min(totalWidth, totalWidth * controller.specs.diskUsedFraction))

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 9)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(nsColor: .systemIndigo), Color(nsColor: .systemPurple)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: usedWidth, height: 9)
                            .animation(.smooth(duration: 0.3), value: controller.specs.diskUsedFraction)
                    }
                }
                .frame(height: 9)

                HStack(spacing: 16) {
                    diskMetricBadge(
                        label: "Used",
                        value: "\(controller.specs.diskUsedFormatted) (\(Int(controller.specs.diskUsedFraction * 100))%)",
                        dotColor: Color(nsColor: .systemIndigo)
                    )

                    diskMetricBadge(
                        label: "Available",
                        value: controller.specs.diskFreeFormatted,
                        dotColor: Color(nsColor: .systemGreen)
                    )

                    if controller.specs.diskPurgeable > 0 {
                        diskMetricBadge(
                            label: "Purgeable",
                            value: controller.specs.diskPurgeableFormatted,
                            dotColor: Color.orange
                        )
                    }

                    Spacer()

                    Text("\("Capacity"): \(controller.specs.diskTotalFormatted)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    private func systemAssetAdviceBanner(report: SystemAssetReport) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .systemIndigo).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .systemIndigo))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\("System Space Opportunity"): \(report.totalFormattedSize)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Offline AI models and Siri caches can be reclaimed safely.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Review") {
                appState.selectedOptimizationTab = 5
                appState.selectItem(.optimization)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .systemIndigo).opacity(0.2), lineWidth: 0.5)
        )
    }

    private var smartScanHeroCard: some View {
        VStack(spacing: 20) {

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (selectedMode == .deep ? Color.orange : Color(nsColor: .systemBlue)).opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 46
                            )
                        )
                        .frame(width: 92, height: 92)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: selectedMode == .deep
                                    ? [Color.orange, Color.red.opacity(0.85)]
                                    : [Color.blue, Color(nsColor: .systemIndigo)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: (selectedMode == .deep ? Color.orange : Color.blue).opacity(0.35),
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                    Image(systemName: selectedMode == .deep ? "bolt.fill" : "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text("Smart Scan")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Clean junk, reclaim storage, and boost performance.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                Picker("", selection: $selectedMode) {
                    Text("Safe Clean").tag(SmartScanMode.safe)
                    Text("Deep Clean").tag(SmartScanMode.deep)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Text(
                    selectedMode == .safe
                        ? "Safe for daily cleanup. Keeps project builds intact."
                        : "Thorough cleanup. Reclaims developer build caches."
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Button {
                onStartScan?(selectedMode)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedMode == .safe ? "Start Scan" : "Start Deep Clean")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(minWidth: 180, minHeight: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedMode == .deep ? Color(nsColor: .systemOrange) : Color(nsColor: .controlAccentColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .keyboardShortcut(.defaultAction)
            .shadow(
                color: (selectedMode == .deep ? Color.orange : Color(nsColor: .controlAccentColor)).opacity(0.25),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }

    private var pillarsSection: some View {
        HStack(spacing: 12) {
            pillarCard(
                category: .cleanup,
                title: "Cleanup",
                subtitle: "Caches & Junk",
                icon: "trash.fill",
                color: Color(nsColor: .systemBlue)
            )

            pillarCard(
                category: .performance,
                title: "Performance",
                subtitle: "Memory & Tasks",
                icon: "gauge.with.dots.needle.67percent",
                color: Color(nsColor: .systemOrange)
            )

            pillarCard(
                category: .applications,
                title: "Applications",
                subtitle: "Uninstall & Updates",
                icon: "square.stack.3d.up.fill",
                color: Color(nsColor: .systemPurple)
            )
        }
    }

    private func pillarCard(
        category: SidebarCategory,
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        Button {
            appState.selectCategory(category)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func diskMetricBadge(label: String, value: String, dotColor: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private var hardwareIcon: String {
        if controller.specs.batteryLevel != nil {
            return "laptopcomputer"
        }
        let lower = controller.specs.modelName.lowercased()
        if lower.contains("mini") {
            return "macmini"
        } else if lower.contains("studio") || (lower.contains("pro") && !lower.contains("book")) {
            return "macstudio"
        } else if lower.contains("imac") {
            return "desktopcomputer"
        }
        return "macbook.gen2"
    }
}
