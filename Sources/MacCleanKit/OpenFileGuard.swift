import Foundation

public enum OpenFileGuard {
    public static func busyURLs(among urls: [URL]) async -> Set<URL> {
        guard !urls.isEmpty else { return [] }
        let outcome = await BoundedProcess.run("/usr/sbin/lsof", ["-nP", "-F", "n"], timeout: .seconds(10))
        guard case .exited(_, let stdout, _) = outcome else { return [] }
        let openPaths = String(decoding: stdout, as: UTF8.self)
            .split(separator: "\n")
            .filter { $0.hasPrefix("n/") }
            .map { String($0.dropFirst()) }
        return busyURLs(among: urls, openPaths: openPaths)
    }

    static func busyURLs(among urls: [URL], openPaths: [String]) -> Set<URL> {
        var byPath: [String: URL] = [:]
        for url in urls {
            byPath[url.standardizedFileURL.path(percentEncoded: false)] = url
        }
        var busy = Set<URL>()
        for open in openPaths {
            var path = open
            while path.count > 1 {
                if let url = byPath[path] {
                    busy.insert(url)
                    break
                }
                path = (path as NSString).deletingLastPathComponent
            }
        }
        return busy
    }
}
