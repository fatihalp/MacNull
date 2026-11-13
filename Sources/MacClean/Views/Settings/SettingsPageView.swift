import SwiftUI
import AppKit
import ServiceManagement
import MacCleanKit

struct SettingsPageView: View {
    @State private var controller = SettingsController()

    @AppStorage("showMenuBarWidget") private var showMenuBarWidget = true
    @AppStorage(MenuBarMetric.defaultsKey, store: SharedAppState.defaults) private var menuBarMetricRaw = MenuBarMetric.diskFree.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @AppStorage(AppearanceManager.defaultsKey) private var appearanceRaw = AppearanceMode.light.rawValue
    @State private var launcher = MenuBarLauncher.shared
    @State private var loginLauncher = LaunchAtLoginManager.shared

    var body: some View {
        Form {
            headerSection
            generalSection
            appearanceSection
            excludedFoldersSection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .task {
            launchAtLogin = loginLauncher.refreshStatus()
            controller.loadPreferences()
        }
    }

    private var headerSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MCConstants.appName)
                        .font(.title2.weight(.semibold))
                    Text("Version \(MCConstants.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { requestedValue in
                launchAtLogin = requestedValue
                Task {
                    launchAtLogin = await loginLauncher.setEnabled(requestedValue)
                }
            }
        )
    }

    private var generalSection: some View {
        Section("General") {

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                    Text("Open \(MCConstants.appName) automatically when you sign in to macOS. You can also manage this in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if loginLauncher.isBusy {
                    ProgressView().controlSize(.small)
                }
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(loginLauncher.isBusy)
            }
            .animation(.easeInOut(duration: 0.18), value: loginLauncher.isBusy)
            if loginLauncher.status == .requiresApproval {
                Label("Needs approval in System Settings → General → Login Items",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            if let err = loginLauncher.lastError {
                Label(err.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show \(MCConstants.appName) in the menu bar")
                    Text("Live CPU, memory, disk, battery, and network at the top of your screen. Click to expand the popover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if launcher.isBusy {
                    ProgressView().controlSize(.small)
                }
                Toggle("Show \(MCConstants.appName) in the menu bar", isOn: $showMenuBarWidget)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(launcher.isBusy)
            }
            .animation(.easeInOut(duration: 0.18), value: launcher.isBusy)
            .onChange(of: showMenuBarWidget) { _, newValue in
                Task { await launcher.setEnabled(newValue) }
            }
            widgetStatusRow
            Picker(selection: $menuBarMetricRaw) {
                ForEach(MenuBarMetric.allCases) { metric in
                    Text(metric.displayName).tag(metric.rawValue)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu bar display")
                    Text("Choose the compact value shown next to the app icon. Unavailable GPU or battery sensors appear as --.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .pickerStyle(.menu)
            .disabled(!showMenuBarWidget)
            if let err = launcher.lastError {
                Label(err.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appearanceRaw) { _, newValue in
                AppearanceManager.apply(AppearanceMode(rawValue: newValue) ?? .system)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove background colors")
                    Text("Replace module gradient backgrounds with a neutral dark color for better readability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Remove background colors", isOn: $removeBackgroundColors)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var excludedFoldersSection: some View {
        Section("Excluded Folders") {
            Text("These folders and their contents are hidden from cleanup scans and cannot be deleted by \(MCConstants.appName) (including Shredder). Only paths under your home folder or /Volumes.")
            .font(.caption)
            .foregroundStyle(.secondary)

            if controller.excludedFolders.isEmpty {
                Text("No folders excluded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(controller.excludedFolders, id: \.self) { path in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Spacer(minLength: 8)
                        Button("Remove", role: .destructive) {
                            controller.removeExcludedFolder(path)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button("Add Folder…") {
                controller.addExcludedFolder()
            }

            if let exclusionError = controller.exclusionError {
                Label(exclusionError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            aboutRow(icon: "chevron.left.forwardslash.chevron.right", tint: .orange,
                     title: "Source code", caption: "Browse the codebase on GitHub",
                     url: MCConstants.repoURL)
            aboutRow(icon: "exclamationmark.bubble", tint: .blue,
                     title: "Report an issue", caption: "Bug reports and feature requests",
                     url: MCConstants.issuesURL)
            aboutRow(icon: "tag", tint: .green,
                     title: "Release notes", caption: "Changelog and previous versions",
                     url: MCConstants.releasesURL)
            aboutRow(icon: "cup.and.saucer.fill", tint: .yellow,
                     title: "Support Mac Sai", caption: "Buy the developer a coffee",
                     url: MCConstants.supportURL)
        }
    }

    private func aboutRow(icon: String, tint: Color, title: String, caption: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }

    @ViewBuilder
    private var widgetStatusRow: some View {
        HStack {
            Image(systemName: statusGlyph)
                .foregroundStyle(statusColor)
            Text("Widget status:")
                .foregroundStyle(.secondary)
            Text(statusText)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
        .font(.caption)
    }

    private var statusGlyph: String {
        switch launcher.statusSnapshot {
        case .enabled: return "checkmark.circle.fill"
        case .notRegistered: return "minus.circle"
        case .notFound: return "questionmark.circle"
        case .requiresApproval: return "exclamationmark.triangle.fill"
        @unknown default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch launcher.statusSnapshot {
        case .enabled: return .green
        case .requiresApproval: return .orange
        default: return .secondary
        }
    }

    private var statusText: String {
        switch launcher.statusSnapshot {
        case .enabled: return "Running"
        case .notRegistered: return "not registered"
        case .notFound: return "helper not found in bundle"
        case .requiresApproval: return "needs approval in System Settings → Login Items"
        @unknown default: return "Unknown"
        }
    }
}
