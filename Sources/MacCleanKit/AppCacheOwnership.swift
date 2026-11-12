import Foundation

public enum AppCacheOwnership {

    public static func runningOwnedURLs(
        in results: [ScanResult],
        runningBundleIDs: Set<String>
    ) -> Set<URL> {
        guard !runningBundleIDs.isEmpty else { return [] }
        var urls: Set<URL> = []
        for result in results {
            for item in result.items {
                if let id = owningBundleID(for: item.url), runningBundleIDs.contains(id) {
                    urls.insert(item.url)
                }
            }
        }
        return urls
    }

    public static func owningBundleID(for url: URL) -> String? {
        let components: [String] = url.pathComponents

        let anchors: [String] = ["Caches", "Containers", "HTTPStorages", "WebKit", "Application Scripts"]
        for anchor: String in anchors {
            guard let i: Int = components.firstIndex(of: anchor), i + 1 < components.count else { continue }
            let candidate: String = components[i + 1]
            if looksLikeBundleID(candidate) { return candidate }
        }

        let path: String = url.path
        for entry: (needle: String, bundleID: String) in browserMap where path.contains(entry.needle) {
            return entry.bundleID
        }
        return nil
    }

    private static func looksLikeBundleID(_ string: String) -> Bool {
        guard string.split(separator: ".").count >= 2 else { return false }
        return string.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    private static let browserMap: [(needle: String, bundleID: String)] = [
        ("Google/Chrome", "com.google.Chrome"),
        ("com.google.Chrome", "com.google.Chrome"),
        ("Firefox", "org.mozilla.firefox"),
        ("org.mozilla.firefox", "org.mozilla.firefox"),
        ("Safari", "com.apple.Safari"),
        ("com.apple.Safari", "com.apple.Safari"),
        ("Arc", "company.thebrowser.Browser"),
        ("company.thebrowser.Browser", "company.thebrowser.Browser"),
        ("BraveSoftware/Brave-Browser", "com.brave.Browser"),
        ("com.brave.Browser", "com.brave.Browser"),
        ("Microsoft Edge", "com.microsoft.edgemac"),
        ("com.microsoft.edgemac", "com.microsoft.edgemac"),
        ("Vivaldi", "com.vivaldi.Vivaldi"),
        ("com.vivaldi.Vivaldi", "com.vivaldi.Vivaldi"),
        ("Opera", "com.operasoftware.Opera"),
        ("com.operasoftware.Opera", "com.operasoftware.Opera"),
        ("Antigravity", "com.google.antigravity"),
        ("Codex", "com.openai.codex"),
        (".cache/codex-runtimes", "com.openai.codex"),
        ("Claude", "com.anthropic.claudefordesktop"),
        ("WhatsApp", "net.whatsapp.WhatsApp"),
    ]
}
