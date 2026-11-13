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
MacSai/
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
