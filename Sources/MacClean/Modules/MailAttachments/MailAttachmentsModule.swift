import Foundation
import MacCleanKit

public struct MailAttachmentsModule: ScanModule {
    public let id = "mail_attachments"
    public var name: String { String(localized: "Mail Attachments") }
    public let category = ModuleCategory.cleanup

    private let scanner = TargetedScanner()

    public init() {}

    public func scan() async -> [ScanResult] {
        await scan(onProgress: nil)
    }

    public func scan(
        onProgress: (@Sendable (_ phase: String, _ count: Int, _ bytes: UInt64, _ fraction: Double) -> Void)?
    ) async -> [ScanResult] {
        let targets = [
            ScanTarget(
                path: MCConstants.mailDownloads,
                recursive: true
            ),
            ScanTarget(
                path: MCConstants.mailContainerDownloads,
                recursive: true
            ),
            ScanTarget(
                path: MCConstants.userContainers
                    .appending(path: "com.apple.mail/Data/Library/Caches"),
                recursive: true
            ),
            ScanTarget(
                path: MCConstants.userContainers
                    .appending(path: "com.microsoft.Outlook/Data/Library/Caches"),
                recursive: true
            ),
            ScanTarget(
                path: MCConstants.userContainers
                    .appending(path: "com.readdle.smartemail/Data/Library/Caches"),
                recursive: true
            ),
        ]

        let items = await scanner.scan(targets: targets) { count, bytes in
            onProgress?(name, count, bytes, 0.5)
        }
        guard !items.isEmpty else { return [] }

        let results = [ScanResult(category: .mailAttachments, items: items)]
            .filteringUncleanable()
        let totalCount = results.reduce(0) { $0 + $1.fileCount }
        let totalBytes = results.reduce(0) { $0 + $1.totalSize }
        onProgress?(name, totalCount, totalBytes, 1.0)
        return results
    }
}
