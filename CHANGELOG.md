# Changelog

All notable changes to Screenshot Renamer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.15.1] - 2026-06-13

### Fixed
- **Auto-update checks now start automatically for fresh installs** — Sparkle no longer depends on the second-launch permission prompt before scheduling weekly background update checks.
- **Debug log rotation** — `screenshotrenamer-debug.log` now rotates to `screenshotrenamer-debug.log.1` when it grows past 1 MiB, and Clear removes both files.

### Changed
- **Updater diagnostics** — Sparkle lifecycle events (appcast loaded, update found/not found, aborted, installing) are now recorded in the debug log for easier troubleshooting.

## [1.15.0] - 2026-06-08

### Changed
- **Sparkle updated 2.8.1 → 2.9.2** — pulls in two upstream security fixes: a symlink guard when applying delta updates, and validation of the installer connection before appcast item data is received. Also includes appcast improvements and localization/accessibility polish.

### Documentation
- **README badges reworked** — added a CodeQL status badge, renamed the CI badge to "CI" (workflow renamed from "Swift CI" → "CI"), switched the release badge to semver tag display, and removed the redundant License and Platform badges. Badge style now matches the other tpak projects.

## [1.14.2] - 2026-05-21

### Added
- **Main-thread heartbeat logging** — 60s diagnostic timer logs to `os_log` and `~/Library/Logs/ScreenshotRenamer/screenshotrenamer-debug.log` (when debug enabled). Gaps between heartbeats indicate a stalled main run loop; continuous beats during an unresponsive menu bar icon point at NSStatusItem itself.
- **Integration tests for `ScreenshotWatcher`** — exercise FSEvents wiring, the 300ms debounce, and the end-to-end rename flow (test count: 79 → 82).

## [1.12.0] - 2026-03-17

### Changed
- **README updated** — Homebrew install now recommended as primary installation method
- **CONTRIBUTING.md updated** — release process now documents local signing workflow with `Scripts/release.sh`
- Updated test count references (74 → 79)

## [1.11.0] - 2026-03-17

### Added
- **Code signing with Developer ID** — app is now signed with `Developer ID Application: Christopher Tirpak` and hardened runtime
- **Apple notarization** — app is notarized and stapled, no more Gatekeeper warnings
- **Homebrew Cask distribution** — install via `brew tap tpak/screenshotrenamer && brew install --cask screenshot-renamer`
- **Local release script** (`Scripts/release.sh`) — automates full release: build, sign, notarize, Sparkle EdDSA sign, GitHub release, appcast, Homebrew update
- **`--sign` flag for `build-app.sh`** — Developer ID signing with inside-out Sparkle framework re-signing
- **Entitlements file** — hardened runtime without App Sandbox (app needs file system access, defaults, FSEvents)

### Changed
- **Releases are now local** — CI simplified to test-only verification on tags; signing and notarization done locally
- **auto-tag.yml** — no longer triggers release workflow (tags created by release script)

## [1.10.0] - 2026-03-10

### Changed
- **Settings reorganized into sections** — Screenshot Options, App Options, and Debug for clearer organization
- **Removed "Check for Updates..." from menu bar** — update controls now live exclusively in Settings

### Added
- **"Automatically download and install updates" toggle** in Settings — controls whether Sparkle downloads updates automatically

## [1.9.1] - 2026-03-10

### Fixed
- **Show thumbnail preview toggle now works** — removed unnecessary `killall SystemUIServer` after toggling screenshot preferences (thumbnail, cursor, shadow, date); on macOS 14+ `screencaptureui` reads these preferences fresh on each launch

## [1.9.0] - 2026-03-09

### Added
- **"Check Now" button in Settings** — check for updates directly from the Settings dialog without using the menu bar

## [1.7.0] - 2026-02-26

### Added
- **Update check frequency** — choose Daily, Weekly, or Monthly in Settings (dropdown disabled when auto-check is off)

### Fixed
- **Check for Updates dialog now appears immediately** — previously the Sparkle dialog was hidden behind other windows because the app wasn't activated as the frontmost app

## [1.6.3] - 2026-02-26

### Changed
- Simplified release note templates in CI workflows

## [1.6.2] - 2026-02-26

### Changed
- Verify Sparkle auto-update pipeline from v1.6.1 → v1.6.2

## [1.6.1] - 2026-02-26

### Fixed
- Removed stale `Info.plist.backup` from Resources that caused SPM build warning
- Cleaned stale build artifacts from previous repo name (`renamescreenshots`)

## [1.6.0] - 2026-02-26

### Changed
- **Repository renamed** from `renamescreenshots` to `ScreenshotRenamer` to match the app name
- Updated all GitHub and GitHub Pages URLs to new repo path (user guide, appcast feed, badges)
- **Note:** Existing v1.5.2 installations will not auto-discover this update; download manually from [Releases](https://github.com/tpak/ScreenshotRenamer/releases/latest)

### Removed
- Cleaned up old Python LaunchAgent (`com.screenshot-renamer.menubar`) and artifacts from pre-Swift version

## [1.5.2] - 2026-02-25

### Fixed
- **Screenshot settings preserved across updates** — app continuously persists known-good settings to its own UserDefaults and restores them on launch if macOS reset `com.apple.screencapture` defaults (e.g., after a Sparkle update). Replaces the v1.5.1 approach that depended on the Sparkle delegate firing before termination. (closes #21)
- Added debug logging throughout settings detection, snapshot save/restore, and Sparkle update flow for diagnosing future issues

## [1.5.1] - 2026-02-25

### Fixed
- **Sparkle update no longer resets screenshot settings** — app now snapshots all `com.apple.screencapture` settings (location, prefix, format, options, delay) before installing an update and restores them on next launch

## [1.5.0] - 2026-02-24

### Added
- **Prefix field in Settings** — edit the screenshot filename prefix directly from the Settings dialog (closes #17)
- **User Guide menu item** — opens the online user guide from the menu bar (closes #18)
- **User Guide on GitHub Pages** — standalone HTML user guide at `https://tpak.github.io/ScreenshotRenamer/` with getting started, settings reference, screenshot shortcuts, and troubleshooting (closes #19)
- **Docs deployment workflow** — automatically deploys `docs/` to GitHub Pages when changed on main

### Fixed
- **Release workflow no longer destroys gh-pages** — switched from orphan-branch approach to merge-based deploy, preserving existing files (e.g., user guide) when updating the appcast

## [1.4.0] - 2026-02-21

### Added
- **Auto-update toggle** in Settings — "Automatically check for updates" checkbox (defaults to on)
- Auto-update status shown in menu bar options summary

### Fixed
- App crash on launch due to missing `@loader_path/../Frameworks` rpath for embedded Sparkle.framework
- Tests now properly restore all user preferences after `testResetToDefaultsResetsLocationAndPrefix` (previously only restored location/prefix, leaving other settings at defaults)

## [1.3.0] - 2026-02-21

### Added
- **Auto-Update via Sparkle** — "Check for Updates..." menu item checks for new versions and installs them in-place
- Automatic background update checks on app launch
- EdDSA-signed updates for secure delivery via GitHub Releases
- Appcast deployment to GitHub Pages for update discovery
- Sparkle 2.x framework embedded in app bundle

## [1.2.0] - 2026-02-21

### Added
- **Capture Delay** setting in Settings dialog — set a timer (None, 5 Seconds, 10 Seconds) before screenshot capture, matching macOS Screenshot utility's Timer option
- Capture delay shown in menu bar options summary when enabled (e.g., "5s Delay")
- `writeIntDefaults()` utility for integer macOS defaults values

## [1.1.2] - 2026-02-11

### Fixed
- **Watcher race condition** — FSEvents could trigger multiple concurrent directory scans, causing "file doesn't exist" errors when two scans tried to rename the same file (#13)
- Replaced per-file `Task {}` with debounced `DispatchWorkItem` that coalesces rapid events into a single rename operation

## [1.1.1] - 2026-02-08

### Fixed
- **Reset to Defaults** now properly resets screenshot location to Desktop and prefix to "Screenshot"

### Changed
- Default debug log renamed from `debug.log` to `screenshotrenamer-debug.log` to distinguish from other logs in `~/Library/Logs/`

## [1.1.0] - 2026-02-07

### Added
- **Unified Settings Dialog** — all preferences now in one window:
  - Editable save location field (type path directly or use folder picker)
  - All screenshot options with checkboxes
  - Launch at login toggle
  - Debug logging section with Set Location, Open, and Clear buttons
  - Reset to Defaults button
- **App Icon** — camera icon now displays in Finder and Applications folder
- **About Dialog Icon** — camera icon shown in About dialog
- **Menu Quick-Reference** — current settings displayed as info items in menu:
  - Location, Prefix, Format
  - Options summary (Thumb, Cursor, Shadow, Date, Auto-start)
  - Debug status
- **Single Instance Prevention** — app detects and prevents duplicate instances
- **Semantic Versioning Scripts**:
  - `./Scripts/bump-version.sh [major|minor|patch]` for manual version control
  - `./Scripts/build-app.sh --bump` flag for auto-increment on build
- **Icon Generation Script** — `Scripts/generate-icon.swift` creates AppIcon.icns from SF Symbol

### Changed
- Settings menu reorganized: separate items replaced with unified "Settings..." dialog
- Debug submenu moved from menu bar into Settings dialog
- Launch at Login moved from menu bar into Settings dialog
- Window title changed from "Screenshot Settings" to "Settings"
- Settings dialog now 550x480px to accommodate all options

### Fixed
- Version not displaying correctly in About dialog (build script now copies Info.plist before restoring original)
- Tests now restore user's screenshot location after running (previously reset to Desktop)

## [1.0.0] - 2026-01-05

### Added
- Native macOS menu bar app for automatic screenshot renaming
- Converts 12-hour format to 24-hour format for chronological sorting
- Support for 24-hour timestamps (lowercases prefix only)
- Support for parenthesized sequence numbers like `(2)`
- FSEvents-based file watching for real-time monitoring
- Quick rename feature for batch processing existing screenshots
- System screenshot location changer with folder picker
- Comprehensive screenshot settings control:
  - Show/hide thumbnail preview toggle
  - Include/exclude mouse pointer toggle
  - Enable/disable window shadow toggle
  - Include date in filename toggle
  - Screenshot format selector (PNG, JPG, PDF, TIFF)
  - Reset to defaults option
- Duplicate filename handling with sequence numbers
- Menu bar integration with SF Symbol camera icon
- UserNotifications framework for status updates
- Auto-detect screenshot location and prefix from system
- Whitelist security for directory access
- Debug logging with configurable file location
- Launch at Login support (SMAppService on macOS 13+, LaunchAgent on older)
- 74 comprehensive unit tests
- Build automation with version injection
- Ad-hoc code signing for local builds
- Support for macOS 11.0 (Big Sur) and later

### Security
- Path validation to prevent directory traversal
- Filename sanitization to block unsafe characters
- Whitelist support for directory restrictions
- Sandbox-ready architecture

[Unreleased]: https://github.com/tpak/ScreenshotRenamer/compare/v1.12.0...HEAD
[1.12.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.9.1...v1.10.0
[1.9.1]: https://github.com/tpak/ScreenshotRenamer/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.7.0...v1.9.0
[1.7.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.6.3...v1.7.0
[1.6.3]: https://github.com/tpak/ScreenshotRenamer/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/tpak/ScreenshotRenamer/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/tpak/ScreenshotRenamer/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.5.2...v1.6.0
[1.5.2]: https://github.com/tpak/ScreenshotRenamer/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/tpak/ScreenshotRenamer/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/tpak/ScreenshotRenamer/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/tpak/ScreenshotRenamer/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/tpak/ScreenshotRenamer/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/tpak/ScreenshotRenamer/releases/tag/v1.0.0
