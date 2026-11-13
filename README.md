<div align="center">

<img src="brand/brands/macnull/exports/logos/appmark/appmark.png" width="128" alt="MacNull app icon" />

<h1>MacNull</h1>

<p><b>Deep cleaning for developers' Macs.</b></p>

<p>
A free, open-source native macOS cleaner built for people who write code.<br/>
It finds the build output, dependency folders and tool caches your repos leave behind, and clears them safely.
</p>

</div>

---

Every repo you clone grows a `node_modules`, a `target`, a `build`, a `.dart_tool`. Every toolchain keeps its own cache: npm, pnpm, Cargo, Gradle, pub, Homebrew, Xcode. None of it is your work, and all of it can be rebuilt. MacNull finds it, tells you what each item is, and moves it to the Trash.

> [!NOTE]
> Cleaned files go to the **Trash**, not into the void. Nothing is gone until you empty the Trash yourself, and every clean is listed in Clean History so you can put things back.

## Features

### Repos and dev tools

- **Project Junk**: dependency and build folders inside your projects (`node_modules`, Rust `target`, Flutter and Gradle `build`, `.dart_tool`, `Pods`, Python virtual environments), grouped by project with their git status shown
- **Developer caches**: npm, pnpm, Yarn, Bun, Cargo, rustup, pub, Gradle, Homebrew, pip, uv, Composer, CocoaPods, Swift Package Manager, Playwright, Puppeteer and more
- **Xcode**: DerivedData, Archives, Device Support, Previews and simulator caches
- **Disk Hogs**: Docker disk usage with safe prune options, and unused iOS simulators and runtimes
- **AI and editor caches**: Cursor, VS Code, Windsurf, Zed, Claude, Codex and other coding tools
- **Command-Line Tools**: lists the Homebrew tools you installed yourself and removes the ones you no longer use

### Safety first

- **Safety labels** on every category: **Safe to Clean** for caches and build output that rebuild on their own, **Check First** for anything that needs a look
- **Trash by default**, with a running "in Trash" total in the sidebar
- **Clean History** with restore
- **In-use check**: files another app has open are skipped, not deleted
- **Quick Look** and **Reveal in Finder** on every item before you clean it
- **Protected paths**: system locations and excluded folders are never touched

### The rest of your Mac

- **Smart Scan** across system junk, browser caches, mail attachments and Trash bins
- **Uninstaller** that removes apps together with their leftovers, plus **Unused Apps**
- **Space Lens**, **Large & Old Files** (including `.ipsw` restore images), **Duplicates** and **Shredder**
- **Maintenance** tasks, login item and background agent management, and a menu bar companion

### First run

A short onboarding scans your Mac and shows what is safe to clean. One button moves those items to the Trash, or you can review everything first. It then offers Full Disk Access, only if MacNull does not have it yet.

## Command line

The same engine runs from the terminal:

```bash
swift run MacClean scan --module project_junk
```

```bash
swift run MacClean clean --mode safe --dry-run
```

| Command | What it does |
|---------|--------------|
| `status` | Root volume capacity, used and free space |
| `scan [--mode safe\|deep] [--module <name>] [--verbose] [--json]` | Finds cleanable files |
| `clean [--mode safe\|deep] [--module <name>] [--dry-run] [--permanent] [-y]` | Moves found files to the Trash; `--permanent` deletes them instead |
| `help` | Usage and options |

## Build from source

Requires macOS 14 or later and Swift 6.

```bash
swift build
```

```bash
swift run MacClean
```

Running without arguments opens the app; any argument runs the CLI.

## Brand

The identity lives in [`brand/brands/macnull`](brand/brands/macnull). The final `l` of the wordmark is drawn hollow: still there, but emptied, the way a cleaned file still sits in the Trash. The icon is that `ll` pair on its own.

- App icon: [`exports/macos/AppIcon.icns`](brand/brands/macnull/exports/macos/AppIcon.icns)
- Logos: [`exports/logos`](brand/brands/macnull/exports/logos)
- Guidelines: [`exports/guidelines/index.html`](brand/brands/macnull/exports/guidelines/index.html)
- Colours: blue `#3b82f6`, ink `#0f172a`, paper `#f8fafc`. Type: Space Grotesk (OFL).

## License

BSD 3-Clause. See [LICENSE](LICENSE).
