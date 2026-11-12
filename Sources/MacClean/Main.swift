import Foundation
import MacCleanKit

@main
@MainActor
enum Main {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst()).filter {
            !$0.hasPrefix("-psn_") && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple")
        }
        if !args.isEmpty {
            Task.detached(priority: .userInitiated) {
                await CLIRunner.run(args: args)
                Foundation.exit(0)
            }
            dispatchMain()
        } else {
            MacCleanApp.main()
        }
    }
}
