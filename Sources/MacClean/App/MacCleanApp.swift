import SwiftUI
import AppKit
import MacCleanKit

struct MacCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @AppStorage(OnboardingController.completedKey) private var hasCompletedOnboarding = false
    @AppStorage("showMenuBarWidget") private var showMenuBarWidget = true
    @AppStorage("menuBarFirstLaunchDone") private var menuBarFirstLaunchDone = false

    var body: some Scene {
        Window(MCConstants.appName, id: "main") {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingFlowView(scan: appState.smartScanController) {
                        hasCompletedOnboarding = true
                    }
                }
            }
                .environment(appState)
                .preferredColorScheme(.light)
                .frame(minWidth: 880, minHeight: 580)
                .onAppear {
                    AppearanceManager.apply(.light)
                    syncMenuBarOnLaunch()
                }
                .onOpenURL { url in
                    guard url.scheme == "macclean", url.host == "module",
                          url.pathComponents.count == 2,
                          let id = url.pathComponents.last,
                          let item = SidebarItem(deepLinkID: id) else { return }
                    appState.selectItem(item)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appState.selectCategory(.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button("Scan") {
                    appState.requestScanShortcut()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Clean Selected") {
                    appState.requestCleanShortcut()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                ForEach(1...9, id: \.self) { digit in
                    if let item = SidebarItem.item(forShortcutDigit: digit) {
                        Button(item.title) {
                            appState.selectItem(item)
                        }
                        .keyboardShortcut(KeyEquivalent(Character(String(digit))), modifiers: .command)
                    }
                }
            }
        }
    }

    private func syncMenuBarOnLaunch() {
        if !menuBarFirstLaunchDone {
            menuBarFirstLaunchDone = true
        }
        Task { await MenuBarLauncher.shared.setEnabled(showMenuBarWidget) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(AppearanceMode.light.rawValue, forKey: AppearanceManager.defaultsKey)
        AppearanceManager.apply(.light)
        MenuBarLauncher.shared.startWatchingHelperTermination()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
