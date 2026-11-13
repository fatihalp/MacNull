import Foundation
import MacCleanKit

struct CommandLineToolsClient: Sendable {
    struct Failure: Equatable, Sendable {
        let name: String
        let detail: String
    }

    private static let listTimeout: Duration = .seconds(30)
    private static let uninstallTimeout: Duration = .seconds(300)

    var brewPath: String? {
        HomebrewFormulae.brewCandidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func formulae() async -> [HomebrewFormula] {
        guard let brew = brewPath else { return [] }
        async let leaves = BoundedProcess.run(brew, ["leaves"], timeout: Self.listTimeout)
        async let cellar = BoundedProcess.run(brew, ["--cellar"], timeout: Self.listTimeout)
        let leavesOutcome = await leaves
        let cellarOutcome = await cellar
        guard leavesOutcome.succeeded, cellarOutcome.succeeded else { return [] }
        let cellarURL = URL(filePath: cellarOutcome.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines))
        return HomebrewFormulae.parseLeaves(leavesOutcome.stdoutText)
            .map { name in
                HomebrewFormula(
                    name: name,
                    bytes: TargetedScanner.directorySize(at: cellarURL.appending(path: name))
                )
            }
            .sorted { $0.bytes > $1.bytes }
    }

    func uninstall(_ names: [String]) async -> [Failure] {
        guard let brew = brewPath else {
            return names.map { Failure(name: $0, detail: "Homebrew not found") }
        }
        var failures: [Failure] = []
        for name in names {
            if Task.isCancelled { break }
            guard let arguments = HomebrewFormulae.uninstallArguments(name: name) else {
                failures.append(Failure(name: name, detail: "Invalid name"))
                continue
            }
            let outcome = await BoundedProcess.run(brew, arguments, timeout: Self.uninstallTimeout)
            if !outcome.succeeded {
                failures.append(Failure(name: name, detail: outcome.failureDetail))
            }
        }
        return failures
    }
}
