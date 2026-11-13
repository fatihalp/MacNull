import Foundation
import AppKit
import MacCleanKit

enum ReviewDataBuilder {

    private static let mergedUserCacheCategories: Set<ScanCategory> = [
        .packageManagerCaches,
        .ideCaches,
        .aiToolCaches,
        .appCaches,
    ]

    static func build(
        modules: [ModuleScanResult],
        runningBundleIDs: Set<String>,
        includeEmptySystemJunkCategories: Bool = false
    ) -> ReviewData {
        var items: [ReviewItem] = []
        items.reserveCapacity(modules.reduce(0) { $0 + $1.totalFileCount })
        var categories: [ReviewCategory] = []
        var sections: [ReviewSection] = []
        var appLookup: [String: URL?] = [:]
        _ = modules.count > 1

        for module in modules {
            var categoryIDs: [Int] = []
            var sectionSize: UInt64 = 0
            var sectionCount = 0

            let nonEmptyResults = module.categories.filter { !$0.items.isEmpty }
            let hasUserCaches = nonEmptyResults.contains { $0.category == .userCaches }

            struct PreparedCategory {
                let category: ScanCategory
                let autoSelect: Bool
                let bucketInputs: [(bucket: ReviewGrouping.Bucket, autoSelect: Bool)]
                let totalSize: UInt64
            }

            var prepared: [PreparedCategory] = []
            if module.moduleID == "system_junk" && hasUserCaches {
                var bucketByName: [String: (bucket: ReviewGrouping.Bucket, autoSelect: Bool)] = [:]
                for result in nonEmptyResults where result.category == .userCaches || mergedUserCacheCategories.contains(result.category) {
                    let buckets = ReviewGrouping.buckets(
                        for: result.category,
                        items: result.items.map(ReviewItem.init)
                    )
                    for b in buckets {
                        if var existing = bucketByName[b.name] {
                            existing.bucket.items.append(contentsOf: b.items)
                            existing.bucket.size += b.size
                            existing.bucket.roots.formUnion(b.roots)
                            existing.autoSelect = existing.autoSelect && result.autoSelect
                            bucketByName[b.name] = existing
                        } else {
                            bucketByName[b.name] = (b, result.autoSelect)
                        }
                    }
                }
                var userCacheBuckets = Array(bucketByName.values)
                userCacheBuckets.sort { $0.bucket.size > $1.bucket.size }
                let userCacheSize = userCacheBuckets.reduce(0 as UInt64) { $0 + $1.bucket.size }
                prepared.append(PreparedCategory(
                    category: .userCaches,
                    autoSelect: true,
                    bucketInputs: userCacheBuckets,
                    totalSize: userCacheSize
                ))

                for result in nonEmptyResults where result.category != .userCaches && !mergedUserCacheCategories.contains(result.category) {
                    let buckets = ReviewGrouping.buckets(
                        for: result.category,
                        items: result.items.map(ReviewItem.init)
                    ).sorted { $0.size > $1.size }
                    let size = buckets.reduce(0 as UInt64) { $0 + $1.size }
                    prepared.append(PreparedCategory(
                        category: result.category,
                        autoSelect: result.autoSelect,
                        bucketInputs: buckets.map { ($0, result.autoSelect) },
                        totalSize: size
                    ))
                }
            } else {
                for result in nonEmptyResults {
                    let buckets = ReviewGrouping.buckets(
                        for: result.category,
                        items: result.items.map(ReviewItem.init)
                    ).sorted { $0.size > $1.size }
                    let size = buckets.reduce(0 as UInt64) { $0 + $1.size }
                    prepared.append(PreparedCategory(
                        category: result.category,
                        autoSelect: result.autoSelect,
                        bucketInputs: buckets.map { ($0, result.autoSelect) },
                        totalSize: size
                    ))
                }
            }

            prepared.sort { $0.totalSize > $1.totalSize }

            var seenCategories = Set<ScanCategory>()
            for entry in prepared {
                seenCategories.insert(entry.category)
                let categoryStart = items.count
                var groups: [ReviewNode] = []
                groups.reserveCapacity(entry.bucketInputs.count)
                for (bucket, bucketAutoSelect) in entry.bucketInputs {
                    let sorted = bucket.items.sorted { ReviewPath.precedes($0.path, $1.path) }
                    let start = items.count
                    items.append(contentsOf: sorted)
                    let range = start..<items.count
                    groups.append(makeGroup(
                        bucket, sortedItems: sorted, range: range,
                        autoSelect: bucketAutoSelect,
                        runningBundleIDs: runningBundleIDs, appLookup: &appLookup
                    ))
                }
                let range = categoryStart..<items.count
                let size = groups.reduce(0) { $0 + $1.size }
                guard size > 0 else { continue }
                let id = categories.count
                categories.append(ReviewCategory(
                    id: id, category: entry.category, autoSelect: entry.autoSelect,
                    range: range, size: size, groups: groups
                ))
                categoryIDs.append(id)
                sectionSize += size
                sectionCount += range.count
            }

            guard !categoryIDs.isEmpty, sectionSize > 0 else { continue }
            categoryIDs.sort { categories[$0].size > categories[$1].size }
            sections.append(ReviewSection(
                id: module.moduleID, name: module.moduleName,
                categoryIDs: categoryIDs, size: sectionSize, itemCount: sectionCount
            ))
        }

        sections.sort { $0.size > $1.size }
        for i in sections.indices {
            sections[i].categoryIDs.sort { categories[$0].size > categories[$1].size }
        }

        return ReviewData(items: items, categories: categories, sections: sections)
    }

    private static func makeGroup(
        _ bucket: ReviewGrouping.Bucket,
        sortedItems: [ReviewItem],
        range: Range<Int>,
        autoSelect: Bool,
        runningBundleIDs: Set<String>,
        appLookup: inout [String: URL?]
    ) -> ReviewNode {
        var name = bucket.name
        var iconPath = bucket.base
        var owner = AppCacheOwnership.owningBundleID(for: URL(filePath: bucket.base))

        if owner == nil && ReviewGrouping.looksLikeBundleID(bucket.name) {
            owner = bucket.name
        }

        let knownAppBundleIDs: [String: [String]] = [
            "WhatsApp": ["net.whatsapp.WhatsApp"],
            "Claude": ["com.anthropic.claudefordesktop", "com.anthropic.claudedesktop"],
            "Codex": ["com.openai.codex"],
            "Antigravity": ["com.google.antigravity"],
            "Antigravity (Gemini)": ["com.google.antigravity"],
            "Chrome": ["com.google.Chrome"],
            "Google": ["com.google.Chrome"],
            "Google Chrome": ["com.google.Chrome"],
            "Firefox": ["org.mozilla.firefox"],
            "Safari": ["com.apple.Safari"],
            "Brave": ["com.brave.Browser"],
            "Edge": ["com.microsoft.edgemac"],
            "Arc": ["company.thebrowser.Browser"],
            "Vivaldi": ["com.vivaldi.Vivaldi"],
            "Opera": ["com.operasoftware.Opera"],
        ]

        if owner == nil, let bundleIDs = knownAppBundleIDs[bucket.name] {
            owner = bundleIDs.first
        }

        let lowerBase = bucket.base.lowercased()
        if owner == nil {
            if lowerBase.contains("google/chrome") || lowerBase.contains("google chrome") {
                owner = "com.google.Chrome"
            } else if lowerBase.contains("firefox") {
                owner = "org.mozilla.firefox"
            } else if lowerBase.contains("safari") {
                owner = "com.apple.Safari"
            } else if lowerBase.contains("bravesoftware") || lowerBase.contains("brave") {
                owner = "com.brave.Browser"
            } else if lowerBase.contains("microsoft edge") || lowerBase.contains("edgemac") {
                owner = "com.microsoft.edgemac"
            } else if lowerBase.contains("arc") {
                owner = "company.thebrowser.Browser"
            }
        }

        if let ownerID = owner {
            let appURL: URL?
            if let cached = appLookup[ownerID] {
                appURL = cached
            } else {
                appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ownerID)
                appLookup[ownerID] = appURL
            }

            if let appURL {
                iconPath = appURL.path(percentEncoded: false)
            }

            let appName = appURL?.deletingPathExtension().lastPathComponent ?? ReviewGrouping.friendlyAppName(for: ownerID)

            let lowerName = bucket.name.lowercased()
            if ownerID == "com.apple.Safari" {
                if lowerName == "com.apple.safari" || lowerName == "webkitcache" || lowerName == "cache" || lowerName == "caches" {
                    name = "Safari"
                } else if !bucket.name.isEmpty {
                    name = "Safari (\(bucket.name))"
                } else {
                    name = "Safari"
                }
            } else if lowerName == "default" {
                name = "\(appName) (Default Profile)"
            } else if lowerName.hasPrefix("profile ") {
                name = "\(appName) (\(bucket.name))"
            } else if lowerName.contains(".default") || lowerName.hasSuffix("-release") {
                name = "\(appName) (\(bucket.name))"
            } else if ReviewGrouping.looksLikeBundleID(bucket.name) || lowerName == "chrome" || lowerName == "google" || lowerName == "firefox" || lowerName == "safari" || lowerName == "brave" || lowerName == "edge" || lowerName == "arc" {
                name = appName
            } else if !bucket.name.isEmpty && bucket.name != appName {
                name = "\(appName) (\(bucket.name))"
            } else {
                name = appName
            }
        }

        let isLeaf = sortedItems.count == 1 && sortedItems[0].path == bucket.base && !sortedItems[0].isDirectory
        return ReviewNode(
            id: bucket.base + "#\(range.lowerBound)",
            name: name,
            basePath: bucket.base,
            range: range,
            size: bucket.size,
            isLeaf: isLeaf,
            iconPath: iconPath,
            appIsRunning: owner.map { runningBundleIDs.contains($0) } ?? false,
            autoSelect: autoSelect
        )
    }
}

enum ReviewGrouping {
    struct Bucket {
        var name: String
        var base: String
        var items: [ReviewItem] = []
        var size: UInt64 = 0
        var roots: Set<String> = []
    }

    enum Mode {

        case byChild

        case byLogEntry

        case byTool
    }

    static func mode(for category: ScanCategory) -> Mode {
        switch category {
        case .packageManagerCaches, .ideCaches, .aiToolCaches, .appCaches: .byTool
        case .systemLogs, .userLogs: .byLogEntry
        default: .byChild
        }
    }

    static let rootsByCategory: [ScanCategory: [String]] = {
        var map: [ScanCategory: [String]] = [:]
        for junk: JunkCategory in SystemJunkModule.allCategories {
            map[junk.scanCategory, default: []] += junk.targets.map { ReviewPath.normalized($0.path) }
        }
        map[.mailAttachments] = [
            MCConstants.mailDownloads,
            MCConstants.mailContainerDownloads,
            MCConstants.mailData,
            MCConstants.userContainers.appending(path: "com.microsoft.Outlook/Data/Library/Caches"),
            MCConstants.userContainers.appending(path: "com.readdle.smartemail/Data/Library/Caches"),
        ].map(ReviewPath.normalized)
        map[.trashBins] = [ReviewPath.normalized(MCConstants.userTrash)]
        map[.browserPrivacy] = [
            MCConstants.chromeCache,
            MCConstants.firefoxCache,
            MCConstants.userCaches.appending(path: "company.thebrowser.Browser"),
            MCConstants.userCaches.appending(path: "BraveSoftware/Brave-Browser"),
            MCConstants.userCaches.appending(path: "Microsoft Edge"),
            MCConstants.userCaches.appending(path: "com.operasoftware.Opera"),
            MCConstants.userCaches.appending(path: "Vivaldi"),
            MCConstants.userCaches,
        ].map(ReviewPath.normalized)
        map[.packageManagerCaches, default: []] += [
            ReviewPath.normalized(MCConstants.rustupToolchains),
            ReviewPath.normalized(MCConstants.rustupUpdateHashes),
        ]
        for (cat, roots) in map {
            var expanded: Set<String> = []
            for r: String in roots {
                expanded.insert(r)
                if r.hasPrefix("/private/var/") {
                    expanded.insert(String(r.dropFirst(8)))
                } else if r.hasPrefix("/var/") {
                    expanded.insert("/private" + r)
                }
            }
            map[cat] = Array(expanded)
        }
        return map.mapValues { (roots: [String]) -> [String] in
            Array(Set(roots)).sorted { $0.utf8.count > $1.utf8.count }
        }
    }()

    static func buckets(for category: ScanCategory, items: [ReviewItem]) -> [Bucket] {
        let roots = rootsByCategory[category] ?? []
        let mode = mode(for: category)
        var byKey: [String: Bucket] = [:]
        var unmatched: [ReviewItem] = []

        for item in items {
            guard let root = roots.first(where: { ReviewPath.isDescendant(item.path, of: $0) }) else {
                unmatched.append(item)
                continue
            }
            switch mode {
            case .byChild:
                let component = ReviewPath.firstComponent(of: item.path, below: root)
                let base = ReviewPath.join(root, component)
                byKey[base, default: Bucket(name: String(component), base: base)].append(item)
            case .byLogEntry:
                let component = String(ReviewPath.firstComponent(of: item.path, below: root))
                let childPath = ReviewPath.join(root, component)

                if item.path == childPath && !item.isDirectory {
                    let stem = logStem(for: component)
                    let key = ReviewPath.join(root, stem)
                    byKey[key, default: Bucket(name: stem, base: item.path)].append(item)
                } else {
                    byKey[childPath, default: Bucket(name: component, base: childPath)].append(item)
                }
            case .byTool:
                let name = toolName(for: root)
                byKey["tool:" + name, default: Bucket(name: name, base: root)].append(item, root: root)
            }
        }

        var result = Array(byKey.values)
        if mode == .byTool {
            for i in result.indices where result[i].roots.count > 1 {
                result[i].base = ReviewPath.commonDirectory(Array(result[i].roots))
            }
        }

        unmatched.sort { ReviewPath.precedes($0.path, $1.path) }
        var current: Bucket?
        for item in unmatched {
            if current != nil, ReviewPath.isDescendant(item.path, of: current!.base) {
                current!.append(item)
            } else {
                if let done = current { result.append(done) }
                let name: String
                if category == .projectJunk {
                    if !item.name.isEmpty && item.name != ReviewPath.lastComponent(item.path) {
                        name = item.name
                    } else {
                        let parentDir = (item.path as NSString).deletingLastPathComponent
                        let projectName = (parentDir as NSString).lastPathComponent
                        let junkName = ReviewPath.lastComponent(item.path)
                        name = projectName.isEmpty ? junkName : "\(junkName) (\(projectName))"
                    }
                } else {
                    name = ReviewPath.lastComponent(item.path)
                }
                var fresh = Bucket(name: name, base: item.path)
                fresh.append(item)
                current = fresh
            }
        }
        if let done = current { result.append(done) }
        return result
    }

    static func logStem(for filename: String) -> String {
        var s: String = filename
        for ext: String in [".bz2", ".gz", ".aapbz"] where s.lowercased().hasSuffix(ext) {
            s = String(s.dropLast(ext.count))
            break
        }
        for ext: String in [".log", ".txt", ".crash", ".diag", ".ips", ".out"] where s.lowercased().hasSuffix(ext) {
            s = String(s.dropLast(ext.count))
            break
        }
        return s.isEmpty ? filename : s
    }

    static func toolName(for root: String) -> String {
        let lower = root.lowercased()
        if lower.contains("whatsapp") { return "WhatsApp" }
        if lower.contains("antigravity") || lower.contains(".gemini") { return "Antigravity (Gemini)" }
        if lower.contains("claude") { return "Claude" }
        if lower.contains("codex") { return "Codex" }
        if lower.contains("puppeteer") { return "Puppeteer" }
        if lower.contains("rustup") || lower.contains(".cargo") || lower.contains("cargo") { return "Rust" }
        if lower.contains("windsurf") { return "Windsurf" }
        if lower.contains("cursor") { return "Cursor" }
        if lower.contains("code") && (lower.contains("vscode") || lower.contains("/code/")) { return "VS Code" }
        if lower.contains("phpactor") { return "Phpactor" }
        if lower.contains("copilot") { return "Copilot" }
        if lower.contains("opencode") { return "Opencode" }
        if lower.contains("corespotlight") || lower.contains("pipelinestorage") { return "Spotlight Document Index" }

        let home = ReviewPath.normalized(MCConstants.home)
        let relative = ReviewPath.isDescendant(root, of: home)
            ? String(root.dropFirst(home.count + 1))
            : root
        let generic: Set<String> = ["Library", "Caches", "Application Support", "Containers", "Data"]
        let component = relative.split(separator: "/").first { !generic.contains(String($0)) }
            .map(String.init) ?? ReviewPath.lastComponent(root)
        var name = component.hasPrefix(".") ? String(component.dropFirst()) : component
        if name == name.lowercased(), !["npm", "pip"].contains(name) {
            name = name.prefix(1).uppercased() + name.dropFirst()
        }
        return name
    }

    static func looksLikeBundleID(_ string: String) -> Bool {
        guard string.split(separator: ".").count >= 3 else { return false }
        return string.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    static func friendlyAppName(for bundleID: String) -> String {
        switch bundleID {
        case "com.google.Chrome": return "Google Chrome"
        case "org.mozilla.firefox": return "Mozilla Firefox"
        case "com.apple.Safari": return "Safari"
        case "com.brave.Browser": return "Brave Browser"
        case "com.microsoft.edgemac": return "Microsoft Edge"
        case "company.thebrowser.Browser": return "Arc"
        case "com.vivaldi.Vivaldi": return "Vivaldi"
        case "com.operasoftware.Opera": return "Opera"
        case "com.spotify.client": return "Spotify"
        case "com.tinyspeck.slackmacgap": return "Slack"
        case "com.microsoft.VSCode": return "Visual Studio Code"
        case "com.apple.dt.Xcode": return "Xcode"
        case "net.whatsapp.WhatsApp": return "WhatsApp"
        case "com.anthropic.claudefordesktop", "com.anthropic.claudedesktop": return "Claude"
        case "com.openai.codex": return "Codex"
        case "com.google.antigravity": return "Antigravity"
        default:
            if let last = bundleID.split(separator: ".").last, !last.isEmpty {
                return String(last)
            }
            return bundleID
        }
    }
}

private extension ReviewGrouping.Bucket {
    mutating func append(_ item: ReviewItem, root: String? = nil) {
        items.append(item)
        size += item.size
        if let root { roots.insert(root) }
    }
}
