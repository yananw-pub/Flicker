# Flicker

**[中文](README.md)** | English

<p align="center">
  <img src="screenshots/app-logo.png" alt="Flicker" width="256" />
</p>

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" /></a>
</p>

A minimalist macOS Finder right-click menu extension — open files and folders with your pre-configured apps instantly, copy paths, and create common files without leaving Finder.

## Screenshots

<p align="center">
  <img src="screenshots/image1.png" alt="Configuration UI" width="480" />
  <br/>
  <em>App configuration — set file extensions for each app</em>
</p>

<p align="center">
  <img src="screenshots/image2.png" alt="Finder context menu" width="480" />
  <br/>
  <em>Finder context menu — one-click open & path copying</em>
</p>

## Features

- Right-click files/folders to open with pre-configured applications
- Place configured apps either inside the Open With submenu or directly in the Finder context menu
- Copy absolute paths, relative paths, or file names to clipboard
- Create common file types from the Finder context menu, with optional auto-open after creation
- Configure app list with per-app file extension filters inside the container app
- "Folders only" mode for fine-grained menu visibility control
- Toggle Flicker's Finder context menu output, hide the Dock icon, and reduce main-window visibility in window managers

## Project Structure

```
Flicker/
├── App/          # App entry, config list, add/edit panels, store
├── Shared/       # AppEntry (data model), SharedStore (shared config I/O)
└── Resources/    # Info.plist, entitlements, Assets

FlickerExtension/   # Finder Sync extension (FIFinderSync subclass)
```

## Getting Started

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ (for building)

### Build & Run

```bash
# Command-line build
xcodebuild -project Flicker.xcodeproj -scheme Flicker -configuration Debug build

# Or open Flicker.xcodeproj in Xcode, select the Flicker scheme and hit Run
```

### Package as DMG

```bash
./scripts/build_dmg.sh
# Output: dist/Flicker-<version>.dmg

# Optional suffix for test builds
./scripts/build_dmg.sh sandbox-fix
# → dist/Flicker-<version>-sandbox-fix.dmg
```

GitHub Actions (`.github/workflows/release-dmg.yml`) builds the DMG on push / manual dispatch:

- Download from **Actions → Build DMG** artifacts
- Pushing a `v*` tag creates a GitHub Release with the DMG attached

### Enable the Extension

1. Launch Flicker, click **Add** to select a `.app`, then set its name, file extensions, and menu collapse behavior
2. Click **Manage Finder Extension…** at the bottom, then check Flicker under **System Settings → Privacy & Security → Extensions → Finder**
3. Restart Finder (`killall Finder`) — right-click in Finder to see the menu

## Configuration After Forking

If you fork this project and plan to build your own copy, update these values to your own:

| Setting | Current Value | Location |
|---------|---------------|----------|
| Bundle Identifier (App) | `com.wangyanan.flicker` | `project.pbxproj` |
| Bundle Identifier (Extension) | `com.wangyanan.flicker.extension` | `project.pbxproj` |
| URL Scheme | `flicker` | `Resources/Info.plist` |

> **Tip:** For local development, ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) works without a developer account. Settings are shared via the extension container (no App Group / temporary-exception required).

## Technical Notes

- Relative paths are based on the current Finder window folder (`targetedURL`); falls back to absolute path when unavailable
- Configuration lives in the Finder Sync **extension container** (`~/Library/Containers/com.wangyanan.flicker.extension/Data/Library/Application Support/Flicker/`) so both the unsandboxed app and sandboxed extension share one folder—no temporary-exception or hardcoded username. Legacy `~/Library/Application Support/Flicker/` is migrated automatically and mirrored on save
- On launch, Flicker re-registers its embedded Finder Sync extension; Open With panel has **Repair Extension Registration** to recover when duplicate builds hide the menu
- Finder Sync extensions are hosted by macOS; quitting Flicker does not unload the extension. To temporarily hide Flicker's menu output, disable **Enable Finder Context Menu** in Action Control
- Minimum deployment target: macOS 14.0 (Sonoma)

## Contributing

Issues and Pull Requests are welcome!

- Make sure the code compiles and runs before submitting a PR
- Open an issue first to discuss new features
- Keep code style consistent with the existing codebase

## License

This project is licensed under the [MIT License](LICENSE).
