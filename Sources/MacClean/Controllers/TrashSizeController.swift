import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class TrashSizeController {
    private(set) var bytes: UInt64 = 0

    func refresh() {
        Task {
            bytes = await Task.detached(priority: .utility) {
                TargetedScanner.directorySize(at: MCConstants.userTrash)
            }.value
        }
    }
}
