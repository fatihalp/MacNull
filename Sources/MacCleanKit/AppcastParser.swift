import Foundation

public final class AppcastParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private static let shortVersionKey = "sparkle:shortVersionString"
    private static let buildVersionKey = "sparkle:version"

    private var bestShortVersion: String?
    private var bestShortDownloadURL: URL?
    private var bestBuildVersion: String?
    private var bestBuildDownloadURL: URL?
    private var inItem = false
    private var inDeltas = false
    private var currentDownloadURL: URL?
    private var currentAttributeShortVersion: String?
    private var currentAttributeBuildVersion: String?
    private var currentElementShortVersion: String?
    private var currentElementBuildVersion: String?

    private var capturingElement: String?
    private var capturedText = ""

    public override init() { super.init() }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    public static func preferredAppcastVersion(
        shortVersion: String?,
        buildVersion: String?
    ) -> String? {
        shortVersion ?? buildVersion
    }

    public func parseLatestItem(from data: Data) -> (version: String?, downloadURL: URL?) {
        bestShortVersion = nil
        bestShortDownloadURL = nil
        bestBuildVersion = nil
        bestBuildDownloadURL = nil
        inItem = false
        resetCurrentItem()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        let version = Self.preferredAppcastVersion(
            shortVersion: bestShortVersion,
            buildVersion: bestBuildVersion
        )
        let downloadURL = bestShortVersion == nil
            ? bestBuildDownloadURL
            : bestShortDownloadURL
        return (version, downloadURL)
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String] = [:]) {
        switch elementName {
        case "item":
            inItem = true
            resetCurrentItem()
        case "sparkle:deltas" where inItem:
            inDeltas = true
        case "enclosure" where inItem && !inDeltas:

            if currentDownloadURL == nil {
                currentDownloadURL = attributes["url"].flatMap(URL.init(string:))
            }
            if currentAttributeShortVersion == nil {
                currentAttributeShortVersion = attributes[Self.shortVersionKey]
            }
            if currentAttributeBuildVersion == nil {
                currentAttributeBuildVersion = attributes[Self.buildVersionKey]
            }
        case Self.shortVersionKey where inItem && !inDeltas,
             Self.buildVersionKey where inItem && !inDeltas:
            capturingElement = elementName
            capturedText = ""
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingElement != nil { capturedText += string }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "sparkle:deltas":
            inDeltas = false
        case Self.shortVersionKey where capturingElement == elementName:
            currentElementShortVersion = trimmedCapture()
        case Self.buildVersionKey where capturingElement == elementName:
            currentElementBuildVersion = trimmedCapture()
        case "item":
            finishItem()
        default:
            break
        }
    }

    private func trimmedCapture() -> String? {
        let text = capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        capturingElement = nil
        capturedText = ""
        return text.isEmpty ? nil : text
    }

    private func finishItem() {
        inItem = false

        if let version = currentElementShortVersion ?? currentAttributeShortVersion,
           shouldReplace(bestShortVersion, with: version) {
            bestShortVersion = version
            bestShortDownloadURL = currentDownloadURL
        }
        if let version = currentElementBuildVersion ?? currentAttributeBuildVersion,
           shouldReplace(bestBuildVersion, with: version) {
            bestBuildVersion = version
            bestBuildDownloadURL = currentDownloadURL
        }
        resetCurrentItem()
    }

    private func shouldReplace(_ bestVersion: String?, with candidate: String) -> Bool {
        guard let bestVersion else { return true }
        return Self.isNewer(candidate, than: bestVersion)
    }

    private func resetCurrentItem() {
        inDeltas = false
        currentDownloadURL = nil
        currentAttributeShortVersion = nil
        currentAttributeBuildVersion = nil
        currentElementShortVersion = nil
        currentElementBuildVersion = nil
        capturingElement = nil
        capturedText = ""
    }
}
