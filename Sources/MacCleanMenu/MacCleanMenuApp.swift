import SwiftUI
import AppKit
import MacCleanKit

@main
struct MacCleanMenuApp: App {
    init() {
        DuplicateInstanceGuard.exitIfAnotherInstanceIsRunning()
    }

    @NSApplicationDelegateAdaptor(MenuAppDelegate.self) private var appDelegate
    @State private var model = MenuStatsModel.shared
    @AppStorage(MenuBarMetric.defaultsKey, store: SharedAppState.defaults) private var menuBarMetricRaw = MenuBarMetric.diskFree.rawValue

    private static let labelIcon: NSImage = {
        let img = NSImage(systemSymbolName: "sparkles",
                          accessibilityDescription: "MacNull")!
        img.isTemplate = true
        return img
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                stats: model.stats,
                networkSpeed: model.networkSpeed,
                devices: model.devices,
                protection: model.protection,
                tips: model.tips,
                onDismissTip: { model.dismissTip(id: $0) }
            )
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: Self.labelIcon)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                if let stats = model.stats,
                   let value = MenuBarMetric.resolve(menuBarMetricRaw).formattedValue(
                       diskFree: stats.diskFree,
                       gpuUsage: stats.gpuUsage,
                       memoryUsage: stats.memoryUsedFraction,
                       batteryTemperature: stats.batteryTemperature
                   ) {
                    Text(value)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
