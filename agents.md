# MacClean (MacSai) - Agent Guidelines & Architecture

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

### 5. English-Only Localization
- All user-facing strings, category names, descriptions, log messages, and resource files must remain strictly in English.
- No multi-language translation files or non-English string literals are permitted in the codebase.

---

## Workspace Structure

```
MacSai/
├── Package.swift                    # SwiftPM manifest (MacClean, macclean, MacCleanMenu, MacCleanKit)
├── agents.md                        # Agent guidelines and architectural documentation
├── Sources/
│   ├── MacClean/
│   │   ├── Main.swift               # Dual-mode entry point (dispatches to GUI App or CLI)
│   │   ├── App/                     # AppState, App Delegate, MacCleanApp, ContentView
│   │   ├── CLI/                     # CLIRunner command-line processing engine
│   │   ├── Controllers/             # Observable controllers (SmartScanController, ScanCoordinator, etc.)
│   │   ├── Models/                  # View models and module interfaces (ScanModule, SmartScanState)
│   │   ├── Modules/                 # Individual module implementations (SystemJunk, ProjectJunk, etc.)
│   │   ├── Services/                # ReviewService, ReviewDataBuilder, SystemSpecsProvider
│   │   └── Views/                   # SwiftUI presentation layers
│   ├── MacCleanKit/
│   │   ├── Categories/              # Junk category definitions (Developer, System, App Caches)
│   │   ├── Cleaner/                 # File removal and trash execution
│   │   ├── Models/                  # Core primitives (FileItem, ScanTarget, ScanResult, SmartScanMode)
│   │   ├── Resources/               # Pure English string catalogs (en.lproj)
│   │   └── TargetedScanner.swift   # High-throughput asynchronous target scanner
│   └── MacCleanMenu/                # Lightweight menu bar accessory
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

## Build & Verification Standards

When making changes:
1. Verify clean compilation:
   ```bash
   swift build
   ```
2. Verify CLI scan execution:
   ```bash
   swift run macclean scan --module trash_bins
   ```
3. Ensure no comment lines were introduced:
   ```bash
   git grep -n "//" Sources/
   ```
4. Verify non-English characters are not present in user-facing code:
   ```bash
   LC_ALL=C grep -rn '[^ -~	]' Sources/
   ```
