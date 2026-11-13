import SwiftUI
import MacCleanKit

struct CommandLineToolsView: View {
    @Bindable var controller: CommandLineToolsController
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if !controller.selectedNames.isEmpty && !controller.isUninstalling {
                Divider()
                actionBar
            }
        }
        .background(Color.white)
        .task { await controller.reload() }
        .alert("Uninstall \(controller.selectedNames.count) tool\(controller.selectedNames.count == 1 ? "" : "s")?",
               isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) { controller.uninstallSelected() }
        } message: {
            Text("Homebrew removes these tools permanently. They do not go to the Trash. You can install them again with brew install.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Command-Line Tools")
                    .font(.system(size: 20, weight: .semibold))
                Text("Homebrew tools you installed yourself. Tools that only exist to support another one are left alone.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await controller.reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(controller.isLoading || controller.isUninstalling)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var content: some View {
        if controller.isLoading || controller.isUninstalling {
            VStack(spacing: 12) {
                Spacer()
                ProgressView().controlSize(.large)
                Text(controller.isUninstalling ? "Uninstalling…" : "Looking for tools…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !controller.hasHomebrew {
            message("Homebrew is not installed", detail: "There are no Homebrew tools to manage on this Mac.")
        } else if controller.formulae.isEmpty {
            message("No Homebrew tools found", detail: "Nothing was installed with brew install.")
        } else {
            List(controller.formulae) { formula in
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { controller.selectedNames.contains(formula.name) },
                        set: { on in
                            if on { controller.selectedNames.insert(formula.name) }
                            else { controller.selectedNames.remove(formula.name) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                    Image(systemName: "terminal")
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formula.name)
                            .font(.system(size: 13, weight: .medium))
                        Text("Homebrew")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(FileSizeFormatter.format(formula.bytes))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Text("\(controller.selectedNames.count) selected · \(FileSizeFormatter.format(controller.selectedBytes))")
                .font(.system(size: 12.5, weight: .medium))
            if let failure = controller.failures.first {
                Text("\(failure.name): \(failure.detail)")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            Spacer()
            Button("Uninstall…") { showConfirm = true }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color(white: 0.975))
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Text(title).font(.system(size: 13, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
