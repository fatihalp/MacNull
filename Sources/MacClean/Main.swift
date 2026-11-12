import Foundation
import MacCleanKit

@main
enum Main {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        if !args.isEmpty {
            await CLIRunner.run(args: args)
        } else {
            await MainActor.run {
                MacCleanApp.main()
            }
        }
    }
}
