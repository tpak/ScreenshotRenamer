# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands
- **Build:** `swift build`
- **Test all:** `swift test` (95 tests, ~9 seconds)
- **Test single:** `swift test --filter ScreenshotRenamerTests.PatternMatcherTests/testDefaultPattern`
- **Build app bundle:** `./Scripts/build-app.sh`
- **Lint:** `swiftlint lint --strict` (also runs as a pre-commit hook — install it once with `./Scripts/install-hooks.sh`)

## Versioning Workflow
When making any code change (feature, fix, refactor):
1. Create a feature branch from main
2. Make code changes and add/update tests
3. Bump version: `./Scripts/bump-version.sh [major|minor|patch]`
   - `fix:` commits → patch
   - `feat:` commits → minor
   - Breaking changes → major
4. Update CHANGELOG.md with a new version section (Keep a Changelog format)
5. Commit, push, and create PR
6. After merge, the maintainer releases locally with `./Scripts/release.sh X.Y.Z` — CI does **not** create tags or releases (see CI/CD below)

## Commit Convention
Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`

## Architecture

Native macOS menu bar app (no dock icon) that renames screenshots from 12-hour to 24-hour format. Swift + macOS frameworks, with [Sparkle](https://sparkle-project.org) as the only external dependency (auto-updates).

**Component flow:**
```
main.swift → AppDelegate → MenuBarController (orchestrator)
                              ├─ ScreenshotWatcher (FSEvents, debounced 300ms)
                              │   └─ ScreenshotRenamer → PatternMatcher + FileValidator
                              ├─ ScreenshotDetector (reads/writes com.apple.screencapture defaults)
                              │   └─ ShellExecutor (defaults read/write, killall SystemUIServer)
                              ├─ SettingsWindowController (unified settings dialog)
                              ├─ UpdateManager (Sparkle 2.x, EdDSA-signed appcast)
                              ├─ BackgroundModeManager (hide menu bar icon; `RunInBackground` default)
                              └─ SettingsSnapshot (persist/restore settings across Sparkle updates)
```

- **PatternMatcher** — regex extracts date, time, AM/PM (optional), sequence number from screenshot filenames; `ScreenshotMatch.to24Hour()` converts 12h→24h
- **FileValidator** — whitelist-based directory security, path traversal prevention; uses `.standardizedFileURL` for URL comparisons (avoids trailing slash mismatches)
- **ScreenshotWatcher** — FSEvents with debounced `DispatchWorkItem` on a serial queue; coalesces rapid events into a single rename scan
- **DebugLogger** — singleton (`DebugLogger.shared`), writes to `~/Library/Logs/ScreenshotRenamer/screenshotrenamer-debug.log`

## Key Constraints

- **SwiftLint function body limit: 60 lines** — split long test functions rather than removing assertions
- **`testRestartSystemUIServer` is flaky** — use lenient assertions (just check it doesn't crash)
- **URL comparisons** — always use `.standardizedFileURL` to avoid trailing slash mismatches
- **Custom SwiftLint rule `no_nslog`** — use `os_log()` instead of `NSLog()`
- **VERSION file** is the single source of truth for version; `Info.plist` version is injected at build time by `Scripts/inject-version.sh`

## CI/CD

CI **never** creates tags or releases. `Scripts/release.sh` is the single owner of the release process (it builds, signs, notarizes, staples, EdDSA-signs, tags, publishes the GitHub Release, deploys the appcast, and updates the Homebrew cask). Earlier `auto-tag.yml` / `release-main.yml` workflows were removed — competing tag creators caused races, and GitHub's immutable releases permanently lock a tag once used, which broke the rolling `latest` prerelease.

Workflows currently in `.github/workflows/`:

- `swift.yml` (**CI**): swiftlint + build-and-test on every push and PR to main
- `release-tag.yml` (**Verify Release Tag**): on `v*` tags, checks the VERSION file matches the tag and runs the tests — verification only, it does not build or publish artifacts
- `codeql.yml`: CodeQL analysis, weekly cron (Wed 03:17 UTC) plus manual dispatch
- `deploy-docs.yml`: deploys `docs/` to gh-pages on changes to main; stages only docs files so it can't clobber the appcast
