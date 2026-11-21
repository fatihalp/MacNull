# MacNull - Agent Guidelines & Architecture

## Core Architectural Principles

### 1. MVC (Model-View-Controller)
- **Model**: Located in `Models/` and `MacCleanKit/`. Encapsulates domain data, immutable findings, file items, and configuration. Models do not render UI and do not observe application state.
- **View**: Located in `Views/`. Pure SwiftUI views strictly responsible for presentation and layout. Views delegate all state mutations and actions to controllers.
- **Controller**: Located in `Controllers/`. Manages lifecycle, workflow orchestration, asynchronous tasks, state machines, and bindings between views and scanning/cleaning engines.

### 2. SOLID Principles
- **Single Responsibility Principle (SRP)**: Each class, struct, actor, and protocol has one clearly bounded responsibility. Scanners scan, engines clean, coordinators schedule, controllers manage view state.
- **Open/Closed Principle (OCP)**: New junk types and scanner targets extend `ScanModule` or `JunkCategory` without altering core scanning loops.
- **Liskov Substitution Principle (LSP)**: All `ScanModule` conformers can be scanned, sized, and reviewed interchangeably by `ScanCoordinator`.
- **Interface Segregation Principle (ISP)**: Protocols are focused and lean. Modules only conform to behaviors they actively supply.
- **Dependency Inversion Principle (DIP)**: High-level coordinators depend on protocols (`ScanModule`, `JunkCategory`) rather than concrete scanner internals.

### 3. KISS, DRY, and YAGNI
- **KISS**: Favor clear, sequential async workflows over convoluted actor hops or complex state machinery.
- **DRY**: Shared directory sizing, file filtering, and size formatting logic reside in unified utilities in `MacCleanKit`.
- **YAGNI**: No speculative abstractions, uncalled methods, mock placeholders, or dead code. Unused features must be removed immediately.

### 4. Self-Documenting Code & Zero Comments
- **No Comments**: Do not write inline, block, or docstring comments (`//`, `/* */`, `///`).
- Express intent purely through clear, descriptive, and unambiguous type, function, and variable names.
- Type signatures, protocols, and control flow should communicate behavior directly.

### 5. English Only, No Language Support
- All user-facing strings, category names, descriptions, and log messages are plain English string literals written directly in code.
- There is no language or localization structure of any kind: no localization layer, string catalogs, `.lproj` resources, `String(localized:)` lookups, language settings, or language-file cleanup. Do not reintroduce any of them.
- Non-English string literals are not permitted.

---

## Workspace Structure

```
MacNull/
├── Package.swift                    # SwiftPM manifest (MacClean, MacCleanMenu, MacCleanKit)
├── agents.md                        # Agent guidelines and architectural documentation
├── Sources/
│   ├── MacClean/
│   │   ├── Main.swift               # Dual-mode entry point (dispatches to GUI App or CLI)
│   │   ├── App/                     # AppState, App Delegate, MacCleanApp, ContentView
│   │   ├── CLI/                     # CLIRunner command-line processing engine
│   │   ├── Controllers/             # Observable controllers owning view state and workflows
│   │   ├── Models/                  # View models and module interfaces (ScanModule, ReviewData)
│   │   ├── Modules/                 # Individual module implementations (SystemJunk, ProjectJunk, etc.)
│   │   ├── Services/                # Scanners, CleaningEngine, AppIconProvider, ReviewDataBuilder
│   │   └── Views/                   # SwiftUI presentation only
│   ├── MacCleanKit/
│   │   ├── Categories/              # Junk category definitions (Developer, System, App Caches)
│   │   ├── Cleaner/                 # Binary thinning and Mach-O operations
│   │   ├── Models/                  # Core primitives (FileItem, ScanResult, SmartScanMode)
│   │   ├── SystemStats/             # CPU, memory, disk, and network samplers
│   │   └── *.swift                  # Domain policies, safety guards, shared utilities
│   └── MacCleanMenu/
│       ├── MacCleanMenuApp.swift    # Menu bar scene
│       ├── Controllers/             # Process-level guards
│       ├── SystemStats/             # Stat collectors and tips
│       └── Views/                   # Menu bar presentation
```

---

## CLI & Execution Modes

The unified entry point in `Sources/MacClean/Main.swift` inspects arguments on startup:
- **No arguments**: Launches the native SwiftUI application (`MacCleanApp.main()`).
- **With arguments**: Invokes `CLIRunner.run(args:)`.

### CLI Commands
- `macclean status`: Reports root volume capacity, used space, and free space.
- `macclean scan [--mode <safe|deep>] [--module <name>] [--verbose] [--json]`: Scans system for cleanable files.
- `macclean clean [--mode <safe|deep>] [--module <name>] [--dry-run] [--permanent|--trash] [-y]`: Cleans detected files.
- `macclean help`: Displays usage and options.

---

## Refactoring Rules

- Views never touch `FileManager`, `NSWorkspace` lookups, `Process`, or background tasks directly; that work lives in a controller or service.
- Byte sizes are formatted only through `FileSizeFormatter.format(_:)`.
- App and file icons are resolved only through `AppIconProvider`.
- Finder reveals, URL opens, and clipboard writes from the UI go through `WorkspaceActions`.
- There are no test targets; correctness is verified with `swift build` and the CLI.

## Build & Verification Standards

When making changes:
1. Verify clean compilation:
   ```bash
   swift build
   ```
2. Verify CLI scan execution:
   ```bash
   swift run MacClean scan --module trash_bins
   ```
3. Ensure no comment lines were introduced:
   ```bash
   git grep -n "//" Sources/
   ```
4. Verify non-English characters are not present in user-facing code:
   ```bash
   LC_ALL=C grep -rn '[^ -~	]' Sources/
   ```

## Apple Silicon Builds and Releases

- Build and distribute MacNull only for Apple silicon (`arm64`) on macOS 14 or later. This applies to both `MacClean` and the bundled `MacCleanMenu` helper. Use `scripts/build-dmg.sh` for packaging. It passes `--arch arm64` to SwiftPM.
- For a release, update `VERSION` and `MCConstants.appVersion` in `Sources/MacCleanKit/Constants.swift` together. Run `bash scripts/check-version-sync.sh` before pushing the matching `vX.Y.Z` tag.
- The tag triggers `.github/workflows/release.yml` on a GitHub-hosted macOS runner. It builds the project, smoke-tests the CLI, and checks that `lipo -archs` returns exactly `arm64` for both packaged executables. It verifies the app signature and disk image before publishing the DMG and its SHA-256 checksum.
- For Visiosoft-signed releases, use the team `TJUL8932F9` Developer ID Application identity and a validated `NOTARY_PROFILE`. Run `bash scripts/build-dmg.sh --notarize` with `APPLE_DEVELOPER_ID` set, then stage the notarized assets in a GitHub draft release before pushing the tag. The tag workflow skips tags with an existing release draft or published release. Match the release notes to the actual signing status.
- Confirm the successful Actions run, the published release, and the downloaded DMG's checksum. Use a new version for changes to a published package so existing downloads retain their published checksum.
- Direct users to the [latest release](https://github.com/fatihalp/MacNull/releases/latest) and the DMG under **Assets**. Keep the README instructions suitable for installation through Finder.
