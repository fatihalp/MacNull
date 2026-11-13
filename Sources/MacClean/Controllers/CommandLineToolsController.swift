import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class CommandLineToolsController {
    private(set) var formulae: [HomebrewFormula] = []
    var selectedNames: Set<String> = []
    private(set) var isLoading = true
    private(set) var isUninstalling = false
    private(set) var failures: [CommandLineToolsClient.Failure] = []

    private let client = CommandLineToolsClient()

    var hasHomebrew: Bool { client.brewPath != nil }

    var selectedBytes: UInt64 {
        formulae.filter { selectedNames.contains($0.name) }.reduce(0) { $0 + $1.bytes }
    }

    func reload() async {
        isLoading = true
        let client = client
        formulae = await Task.detached { await client.formulae() }.value
        selectedNames = selectedNames.intersection(Set(formulae.map(\.name)))
        isLoading = false
    }

    func uninstallSelected() {
        let names = formulae.map(\.name).filter { selectedNames.contains($0) }
        guard !names.isEmpty, !isUninstalling else { return }
        isUninstalling = true
        let client = client
        Task {
            failures = await Task.detached { await client.uninstall(names) }.value
            selectedNames.removeAll()
            isUninstalling = false
            await reload()
        }
    }
}
