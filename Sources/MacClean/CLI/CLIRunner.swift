import Foundation
import MacCleanKit

public enum CLIRunner {
    private struct CLIConfig {
        var command: String = "help"
        var mode: SmartScanMode = .deep
        var targetModule: String? = nil
        var isDryRun: Bool = false
        var isPermanent: Bool = true
        var isVerbose: Bool = false
        var isJson: Bool = false
        var autoConfirm: Bool = false
    }

    public static func run(args: [String]) async {
        let config = parseArgs(args)

        switch config.command {
        case "help", "--help", "-h":
            printHelp()
        case "status", "--status", "info":
            await printStatus(config: config)
        case "scan", "--scan":
            _ = await runScan(config: config)
        case "clean", "--clean":
            await runClean(config: config)
        default:
            print("Unknown command: '\(config.command)'. Use 'macclean help' for usage instructions.")
        }
    }

    private static func parseArgs(_ args: [String]) -> CLIConfig {
        var config = CLIConfig()
        var i = 0

        if !args.isEmpty && !args[0].hasPrefix("-") {
            config.command = args[0].lowercased()
            i = 1
        } else if !args.isEmpty {
            let first = args[0].lowercased()
            if first == "--scan" { config.command = "scan"; i = 1 }
            else if first == "--clean" { config.command = "clean"; i = 1 }
            else if first == "--status" { config.command = "status"; i = 1 }
            else if first == "--help" || first == "-h" { config.command = "help"; i = 1 }
        }

        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--mode":
                if i + 1 < args.count {
                    let m = args[i + 1].lowercased()
                    if m == "safe" { config.mode = .safe }
                    else if m == "deep" { config.mode = .deep }
                    i += 1
                }
            case "--module":
                if i + 1 < args.count {
                    config.targetModule = args[i + 1].lowercased()
                    i += 1
                }
            case "--dry-run":
                config.isDryRun = true
            case "--permanent":
                config.isPermanent = true
            case "--trash":
                config.isPermanent = false
            case "-v", "--verbose":
                config.isVerbose = true
            case "--json":
                config.isJson = true
            case "-y", "--yes":
                config.autoConfirm = true
            default:
                break
            }
            i += 1
        }

        return config
    }

    private static func printHelp() {
        print("""
\u{001B}[1mMacClean (MacSai) - High-Performance macOS Storage Cleaner\u{001B}[0m

\u{001B}[1mUSAGE:\u{001B}[0m
    macclean <command> [options]

\u{001B}[1mCOMMANDS:\u{001B}[0m
    \u{001B}[32mscan\u{001B}[0m       Scan the system and report cleanable junk, caches, and bloat
    \u{001B}[32mclean\u{001B}[0m      Clean detected files and free up disk space
    \u{001B}[32mstatus\u{001B}[0m     Display current disk capacity, free space, and volume statistics
    \u{001B}[32mhelp\u{001B}[0m       Show this help message

\u{001B}[1mOPTIONS:\u{001B}[0m
    --mode <safe|deep>   Scan depth mode (default: deep)
    --module <name>      Limit to a specific module (e.g. system_junk, trash_bins, project_junk, browser_cleanup)
    --dry-run            Simulate cleaning without actually deleting any files
    --permanent          Delete permanently (default for clean)
    --trash              Move items to Trash instead of permanent deletion
    -y, --yes            Skip confirmation prompt before cleaning
    -v, --verbose        Display detailed file lists and categories
    --json               Output scan results formatted as JSON

\u{001B}[1mEXAMPLES:\u{001B}[0m
    macclean scan
    macclean scan --verbose
    macclean scan --module project_junk
    macclean clean --dry-run
    macclean clean --yes
    macclean status
""")
    }

    private static func getDiskStats() -> (total: UInt64, free: UInt64, used: UInt64, path: String)? {
        let path = "/"
        var stat = statfs()
        guard statfs(path, &stat) == 0 else { return nil }
        let blockSize = UInt64(stat.f_bsize)
        let total = UInt64(stat.f_blocks) * blockSize
        let free = UInt64(stat.f_bavail) * blockSize
        let used = total > free ? total - free : 0
        return (total, free, used, path)
    }

    private static func padR(_ str: String, _ len: Int) -> String {
        if str.count >= len { return String(str.prefix(len)) }
        return str + String(repeating: " ", count: len - str.count)
    }

    private static func padL(_ str: String, _ len: Int) -> String {
        if str.count >= len { return str }
        return String(repeating: " ", count: len - str.count) + str
    }

    private static func printStatus(config: CLIConfig) async {
        guard let stats = getDiskStats() else {
            print("Failed to retrieve disk statistics.")
            return
        }

        let totalStr = FileSizeFormatter.format(stats.total)
        let usedStr = FileSizeFormatter.format(stats.used)
        let freeStr = FileSizeFormatter.format(stats.free)
        let usedPct = stats.total > 0 ? (Double(stats.used) / Double(stats.total)) * 100.0 : 0

        if config.isJson {
            let json: [String: Any] = [
                "total_bytes": stats.total,
                "used_bytes": stats.used,
                "free_bytes": stats.free,
                "used_percentage": usedPct,
                "formatted": [
                    "total": totalStr,
                    "used": usedStr,
                    "free": freeStr
                ]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
            return
        }

        print("\u{001B}[1m=== MacClean System & Disk Status ===\u{001B}[0m")
        print("Root Volume:        /")
        print("Total Capacity:     \(totalStr)")
        print("Used Space:         \(usedStr) (\(String(format: "%.1f", usedPct))%)")
        print("Available Space:    \u{001B}[1;\(stats.free < 15_000_000_000 ? "31" : "32")m\(freeStr)\u{001B}[0m")

        if stats.free < 15_000_000_000 {
            print("\u{001B}[33m[!] Warning: Low disk space detected (< 15 GB available). Consider running 'macclean clean'.\u{001B}[0m")
        }
    }

    private static func getModules(config: CLIConfig) -> [ScanModule] {
        var modules: [ScanModule] = [
            SystemJunkModule(),
            TrashBinsModule(),
            BrowserCleanupModule(),
            MailAttachmentsModule(),
        ]

        if config.mode == .deep {
            modules.append(ProjectJunkModule())
        }

        if let target = config.targetModule {
            modules = modules.filter {
                $0.id.lowercased() == target ||
                $0.name.lowercased() == target ||
                $0.id.replacingOccurrences(of: "_", with: "").lowercased() == target
            }
        }

        return modules
    }

    private static func runScan(config: CLIConfig) async -> [ModuleScanResult] {
        let modules = getModules(config: config)
        if !config.isJson {
            print("\u{001B}[1mScanning system for cleanable files [Mode: \(config.mode == .deep ? "Deep" : "Safe")]...\u{001B}[0m")
        }

        var results: [ModuleScanResult] = []
        let startTime = Date()

        for (index, module) in modules.enumerated() {
            if !config.isJson {
                print("[\(index + 1)/\(modules.count)] Scanning \(module.name)...", terminator: "\r")
                fflush(stdout)
            }
            let moduleStart = Date()
            let scanResults = await module.scan()
            let duration = Date().timeIntervalSince(moduleStart)
            let modResult = ModuleScanResult(
                moduleID: module.id,
                moduleName: module.name,
                categories: scanResults,
                scanDuration: duration
            )
            results.append(modResult)
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        let totalFiles = results.reduce(0) { $0 + $1.totalFileCount }
        let totalBytes = results.reduce(0) { $0 + $1.totalSize }

        if config.isJson {
            var modulesJson: [[String: Any]] = []
            for m in results {
                var catsJson: [[String: Any]] = []
                for c in m.categories {
                    catsJson.append([
                        "name": c.category.displayName,
                        "key": c.category.rawValue,
                        "file_count": c.fileCount,
                        "total_bytes": c.totalSize,
                        "formatted_size": c.formattedSize
                    ])
                }
                modulesJson.append([
                    "id": m.moduleID,
                    "name": m.moduleName,
                    "file_count": m.totalFileCount,
                    "total_bytes": m.totalSize,
                    "formatted_size": m.formattedSize,
                    "categories": catsJson
                ])
            }
            let rootJson: [String: Any] = [
                "total_bytes": totalBytes,
                "formatted_total": FileSizeFormatter.format(totalBytes),
                "total_files": totalFiles,
                "scan_duration_seconds": totalDuration,
                "modules": modulesJson
            ]
            if let data = try? JSONSerialization.data(withJSONObject: rootJson, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
            return results
        }

        print("\u{001B}[2K", terminator: "\r")
        print("\u{001B}[1m\n=== Scan Results Summary ===\u{001B}[0m")
        print(String(repeating: "-", count: 68))
        print("\(padR("Module / Category", 30)) | \(padL("Items", 10)) | \(padL("Cleanable Size", 18))")
        print(String(repeating: "-", count: 68))

        for m in results {
            print("\u{001B}[1m\(padR(m.moduleName, 30))\u{001B}[0m | \u{001B}[1m\(padL("\(m.totalFileCount)", 10))\u{001B}[0m | \u{001B}[1;32m\(padL(m.formattedSize, 18))\u{001B}[0m")
            for cat in m.categories where cat.totalSize > 0 || config.isVerbose {
                print("  ↳ \(padR(cat.category.displayName, 26)) | \(padL("\(cat.fileCount)", 10)) | \(padL(cat.formattedSize, 18))")
                if config.isVerbose {
                    let sortedItems = cat.items.sorted { $0.size > $1.size }.prefix(5)
                    for item in sortedItems {
                        print("      • \(padR((item.url.path as NSString).lastPathComponent, 45)) \(padL(FileSizeFormatter.format(item.size), 12))")
                    }
                }
            }
            print(String(repeating: "-", count: 68))
        }

        print("\u{001B}[1mTotal Cleanable Space: \(padL(FileSizeFormatter.format(totalBytes), 43))\u{001B}[0m")
        print("Total Files Scanned:   \(padL("\(totalFiles)", 43))")
        print("Scan Duration:         \(padL(String(format: "%.2f s", totalDuration), 43))")
        print(String(repeating: "=", count: 68))

        if let stats = getDiskStats() {
            let potentialFree = stats.free + totalBytes
            let currentFreeStr = FileSizeFormatter.format(stats.free)
            let potentialFreeStr = FileSizeFormatter.format(potentialFree)
            print("Current Free Space:   \(currentFreeStr)")
            print("Space After Cleaning: \u{001B}[1;32m\(potentialFreeStr)\u{001B}[0m")
        }

        return results
    }

    private static func runClean(config: CLIConfig) async {
        let scanResults = await runScan(config: config)
        var allItems: [FileItem] = []
        for m in scanResults {
            for c in m.categories {
                allItems.append(contentsOf: c.items)
            }
        }

        guard !allItems.isEmpty else {
            print("\nNo cleanable items found.")
            return
        }

        let totalBytes = allItems.reduce(0) { $0 + $1.size }
        let totalFormatted = FileSizeFormatter.format(totalBytes)

        if config.isDryRun {
            print("\n\u{001B}[1;33m[DRY RUN] Simulation complete. No files were removed.\u{001B}[0m")
            print("Would have cleaned \(allItems.count) files freeing up \(totalFormatted).")
            return
        }

        if !config.autoConfirm {
            print("\nAre you sure you want to clean \(allItems.count) files freeing up \(totalFormatted)? [y/N]: ", terminator: "")
            guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  response == "y" || response == "yes" else {
                print("Cleanup cancelled by user.")
                return
            }
        }

        print("\n\u{001B}[1mCleaning files...\u{001B}[0m")
        let engine = CleaningEngine()
        let mode: CleaningEngine.CleanMode = config.isPermanent ? .permanent : .trash

        let result = await engine.clean(items: allItems, mode: mode) { progress in
            let pct = Int(progress.fraction * 100)
            print("Progress: \(pct)% (\(progress.processedItems)/\(progress.totalItems) items processed)", terminator: "\r")
            fflush(stdout)
        }

        print("\u{001B}[2K", terminator: "\r")
        print("\n\u{001B}[1;32m=== Cleanup Completed Successfully ===\u{001B}[0m")
        print("Items Removed: \(result.removedCount)")
        print("Space Freed:   \(FileSizeFormatter.format(result.freedBytes))")
        if result.skippedCount > 0 {
            print("Items Skipped: \(result.skippedCount)")
        }
        if !result.errors.isEmpty {
            print("\u{001B}[33mErrors encountered: \(result.errors.count)\u{001B}[0m")
            if config.isVerbose {
                for err in result.errors.prefix(10) {
                    print("  - \(err.path): \(err.error)")
                }
            }
        }

        if let stats = getDiskStats() {
            print("New Free Space: \u{001B}[1;32m\(FileSizeFormatter.format(stats.free))\u{001B}[0m")
        }
    }
}
