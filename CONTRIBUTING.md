# Contributing to Screenshot Renamer

Thank you for your interest in contributing to Screenshot Renamer! This document provides guidelines and workflows for development and releases.

## Development Workflow

### Prerequisites

- **macOS 11.0 (Big Sur)** or later
- **Xcode 14+** with command line tools
- **Swift 5.7+**
- **Git**

### Setting Up

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ScreenshotRenamer.git
   cd ScreenshotRenamer
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/tpak/ScreenshotRenamer.git
   ```
4. Install the git hooks:
   ```bash
   ./Scripts/install-hooks.sh
   ```
   This installs a pre-commit hook that runs `swiftlint lint --strict`. CI runs the
   same check, so without the hook a lint slip only surfaces after you push.

### Making Changes

1. **Create a feature branch** from `main`:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Follow Swift API design guidelines
   - Write clear, descriptive commit messages
   - Add/update tests for new functionality
   - Keep changes focused and atomic

3. **Update CHANGELOG.md**:
   - Add your changes under the "Unreleased" section
   - Follow the format: `- Description (#PR-number if available)`
   - Categorize under: Added, Changed, Deprecated, Removed, Fixed, or Security

4. **Run tests**:
   ```bash
   swift test
   ```
   All tests must pass before submitting.

5. **Build locally**:
   ```bash
   ./Scripts/build-app.sh
   ```
   Verify the app builds and runs correctly.

6. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

7. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

8. **Create a Pull Request**:
   - Go to the original repository on GitHub
   - Click "New Pull Request"
   - Select your feature branch
   - Provide a clear description of your changes
   - Reference any related issues

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear, standardized commit messages:

### Format

```
<type>: <description>

[optional body]

[optional footer]
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no logic changes)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks (dependencies, build, etc.)

### Examples

```bash
feat: add thumbnail preview toggle

fix: resolve initialization crash on launch

docs: update installation instructions

test: add duplicate filename handling tests

chore: bump version to 1.1.0
```

## Automated Builds

### Continuous Integration

The `CI` workflow (`.github/workflows/swift.yml`) runs on every push to `main` and on
every PR targeting `main`:

- **SwiftLint** (`--strict`) — must pass before the build job starts
- **Build and test** on macOS latest (`swift build -c release`, then `swift test`)
- **App bundle build** via `./Scripts/build-app.sh`, uploaded as an artifact with 7-day retention

CodeQL security analysis runs on its own schedule (weekly, Wednesdays at 03:17 UTC) and on
manual dispatch — **not** on pushes or PRs, because the analysis is slow.

CI does not publish releases of any kind. An earlier workflow that pushed a rolling `latest`
pre-release on every push to main was removed; releases come only from `Scripts/release.sh`
(see below).

## Creating a Release

### Version Numbering

We use [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes, incompatible API
- **MINOR** (1.0.0 → 1.1.0): New features, backwards compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes, backwards compatible

### Prerequisites

Releases are done locally (not in CI) because they require code signing and notarization:

- **Developer ID Application certificate** in your Keychain
- **Notarization credentials** stored via `xcrun notarytool store-credentials "screenshotrenamer-notary"`
- **Sparkle EdDSA private key** in your Keychain (for update signing)

### Release Process

#### 1. Update CHANGELOG.md

Move "Unreleased" changes to a new version section:

```markdown
## [Unreleased]

## [1.1.0] - 2026-01-15

### Added
- New feature description

### Fixed
- Bug fix description
```

#### 2. Run the Release Script

```bash
./Scripts/release.sh 1.1.0
```

The script handles everything:
- Bumps VERSION file and commits
- Builds release binary with Developer ID signing (hardened runtime)
- Re-signs Sparkle framework components inside-out
- Notarizes with Apple and staples the ticket
- Signs the ZIP with Sparkle EdDSA for update verification
- Creates DMG and SHA256 checksums
- Creates git tag and GitHub release with artifacts
- Deploys appcast.xml to GitHub Pages
- Updates the Homebrew Cask formula

#### 3. Verify Release

1. Visit https://github.com/tpak/ScreenshotRenamer/releases
2. Download and test on another Mac — should open without Gatekeeper warnings
3. Test Homebrew install: `brew tap tpak/tpak && brew install --cask screenshot-renamer`
4. Test Sparkle auto-update from the previous version

### Build Variants

```bash
./Scripts/build-app.sh          # Ad-hoc signed (local development)
./Scripts/build-app.sh --sign   # Developer ID signed (hardened runtime)
./Scripts/build-app.sh --bump   # Ad-hoc signed + increment patch version
```

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter ScreenshotRenamerTests

# Run with verbose output
swift test --verbose
```

### Test Coverage

We maintain comprehensive test coverage:
- Pattern matching (22 tests)
- File validation (12 tests)
- Screenshot detection (11 tests)
- Launch at login (10 tests)
- Screenshot renaming (9 tests)
- Shell command execution (5 tests)
- Debug logger (5 tests)

**Total: 79 tests**

### Writing Tests

- Follow existing patterns in `Tests/ScreenshotRenamerTests/`
- Use descriptive test names: `testHandlesDuplicateFilenames()`
- Test both success and failure cases
- Clean up test files in teardown
- Use XCTest framework conventions

## Code Style

### Swift Guidelines

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and single-purpose
- Prefer immutability (`let` over `var`)

### Project Structure

```
Sources/ScreenshotRenamer/
├── App/              # Application lifecycle and UI
├── Core/             # Core business logic
├── FileWatcher/      # File monitoring
├── Models/           # Data models
├── Utilities/        # Helper utilities
└── Resources/        # Assets and configuration
```

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/tpak/ScreenshotRenamer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tpak/ScreenshotRenamer/discussions)
- **Email**: Check the repository for contact information

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the issue, not the person
- Help create a welcoming environment

## License

By contributing to Screenshot Renamer, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be acknowledged in:
- Release notes
- GitHub Contributors page
- CHANGELOG.md (for significant contributions)

Thank you for contributing to Screenshot Renamer! 🎉
