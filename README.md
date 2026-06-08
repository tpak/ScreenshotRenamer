# Screenshot Renamer

[![CI](https://github.com/tpak/ScreenshotRenamer/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/tpak/ScreenshotRenamer/actions/workflows/swift.yml)
[![CodeQL](https://github.com/tpak/ScreenshotRenamer/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/tpak/ScreenshotRenamer/actions/workflows/codeql.yml)
[![Latest release](https://img.shields.io/github/v/release/tpak/ScreenshotRenamer?display_name=tag&sort=semver)](https://github.com/tpak/ScreenshotRenamer/releases/latest)

Native macOS menu bar app that automatically renames screenshots from 12-hour to 24-hour format so they sort chronologically in Finder.

**Before:** `Screenshot 2024-05-24 at 1.23.45 PM.png`
**After:** `screenshot 2024-05-24 at 13.23.45.png`

Also handles 24-hour timestamps (prefix lowercasing) and parenthesized sequence numbers like `(2)`.

## Installation

### Homebrew (Recommended)

```bash
brew tap tpak/tpak
brew install --cask screenshot-renamer
```

The app is code-signed and notarized by Apple — no Gatekeeper warnings. Sparkle handles updates automatically after install.

### Download

1. Download **ScreenshotRenamer.dmg** from [GitHub Releases](https://github.com/tpak/ScreenshotRenamer/releases/latest)
2. Open the DMG and drag the app to Applications
3. The camera icon appears in your menu bar — screenshots are now automatically renamed

### Build from Source

```bash
git clone https://github.com/tpak/ScreenshotRenamer.git
cd ScreenshotRenamer
./Scripts/build-app.sh
open ScreenshotRenamer.app
```

Requires macOS 11.0+ and Swift 5.7+. No external dependencies.

## Features

- **Auto-rename** — watches for new screenshots via FSEvents, renames in real-time
- **Quick Rename** — batch rename existing screenshots in one click
- **Unified Settings** — all preferences in one dialog:
  - Save location (editable field or folder picker)
  - Thumbnail preview, mouse pointer, window shadow, date in filename toggles
  - Launch at login
  - Format (PNG/JPG/PDF/TIFF)
  - Debug logging with custom log location
  - Reset to defaults
- **Menu Quick-Reference** — current settings displayed in menu bar dropdown
- **Single Instance** — prevents duplicate app instances from running
- **Native App Icon** — camera icon displays in Finder and About dialog
- **Lightweight** — native Swift, no dependencies, instant startup

## Usage

Click the camera icon in your menu bar:

| Menu Item | Description |
|-----------|-------------|
| Stop/Start Watcher | Toggle automatic renaming |
| Quick Rename... | Rename all existing screenshots now |
| Settings... | Open the unified settings dialog |
| About | App version and GitHub link |
| Quit | Exit the app |

Below the menu items, you'll see a quick-reference display of your current settings (location, prefix, format, options, debug status).

The app auto-detects your macOS screenshot location and prefix via `com.apple.screencapture` defaults.

## Development

```bash
swift test                      # Run all 79 tests
swift build                     # Debug build
./Scripts/build-app.sh          # Build app bundle (ad-hoc signed)
./Scripts/build-app.sh --sign   # Build with Developer ID signing
./Scripts/build-app.sh --bump   # Build and increment patch version
./Scripts/bump-version.sh minor # Manually bump minor version
./Scripts/release.sh X.Y.Z     # Full release: sign, notarize, publish, update Homebrew
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development workflow and release process.

## Uninstallation

```bash
# If installed via Homebrew:
brew uninstall --cask screenshot-renamer

# If installed manually:
pkill ScreenshotRenamer; rm -rf /Applications/ScreenshotRenamer.app
```

## License

MIT License — see [LICENSE](LICENSE) for details.

Created by [Chris Tirpak](https://github.com/tpak)
