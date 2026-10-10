#!/bin/bash
set -euo pipefail

VERSION=""
REPO="tpak/ScreenshotRenamer"
APPCAST_URL="https://tpak.github.io/ScreenshotRenamer/appcast.xml"

while [[ $# -gt 0 ]]; do
    case "$1" in
        *) [[ -z "$VERSION" ]] && VERSION="$1"; shift ;;
    esac
done

# ── Phase 1: Validate ──────────────────────────────────────────────

if [[ -z "$VERSION" ]]; then
    echo "Usage: Scripts/release.sh X.Y.Z"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: VERSION must match X.Y.Z pattern (got: $VERSION)"
    exit 1
fi

if [[ "$(git branch --show-current)" != "main" ]]; then
    echo "Error: Must be on 'main' branch (currently on '$(git branch --show-current)')"
    exit 1
fi

if [[ -n "$(git diff --stat HEAD)" ]]; then
    echo "Error: Working tree has uncommitted changes. Commit or stash changes first."
    exit 1
fi

for cmd in gh ditto xcrun codesign; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required tool '$cmd' not found"
        exit 1
    fi
done

SIGN_IDENTITY="Developer ID Application"
if ! security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    echo "Error: No '$SIGN_IDENTITY' certificate found in keychain."
    exit 1
fi

NOTARY_PROFILE="screenshotrenamer-notary"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
    echo "Error: Notarization credentials not found. Run:"
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
    echo "    --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --password APP_SPECIFIC_PASSWORD"
    exit 1
fi

# Minimum macOS comes from Info.plist so the appcast and Homebrew cask can't
# drift from what the bundle actually requires. An appcast that under-states it
# makes Sparkle install a build the user's macOS cannot launch.
INFO_PLIST="Sources/ScreenshotRenamer/Resources/Info.plist"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST")"
case "${MIN_MACOS%%.*}" in
    11) CASK_MACOS="big_sur" ;;
    12) CASK_MACOS="monterey" ;;
    13) CASK_MACOS="ventura" ;;
    14) CASK_MACOS="sonoma" ;;
    15) CASK_MACOS="sequoia" ;;
    26) CASK_MACOS="tahoe" ;;
    *)
        echo "Error: No Homebrew macOS symbol known for LSMinimumSystemVersion '$MIN_MACOS'"
        exit 1
        ;;
esac

SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"
if [[ ! -x "$SIGN_UPDATE" ]]; then
    echo "Error: Sparkle sign_update not found at $SIGN_UPDATE"
    echo "       Run 'swift build' first to resolve SPM packages."
    exit 1
fi

# Last builds for dropped macOS versions, kept in the appcast after the new item
LEGACY_ITEMS="$(cat Scripts/appcast-legacy-items.xml)"

echo ""
echo "=== Releasing Screenshot Renamer v$VERSION ==="
echo ""

# ── Phase 2: Version bump (idempotent) ─────────────────────────────

CURRENT_VERSION=$(cat VERSION | tr -d '[:space:]')
if [[ "$CURRENT_VERSION" != "$VERSION" ]]; then
    echo "── Bumping version from $CURRENT_VERSION to $VERSION..."
    echo "$VERSION" > VERSION
    ./Scripts/inject-version.sh
    git add VERSION Sources/ScreenshotRenamer/Resources/Info.plist
    git commit -m "Bump version to $VERSION"
fi

# Push if local is ahead of remote
if [[ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ]]; then
    echo "── Pushing version bump to main..."
    git push origin main
fi

echo "── Version: $VERSION (requires macOS $MIN_MACOS)"

# ── Phase 3: Build & sign ──────────────────────────────────────────

echo "── Building release..."
./Scripts/build-app.sh --sign

APP_NAME="ScreenshotRenamer.app"
if [[ ! -d "$APP_NAME" ]]; then
    echo "Error: $APP_NAME not found after build"
    exit 1
fi

# The binary's deployment target comes from Package.swift; MIN_MACOS comes from
# Info.plist. Both must agree or the appcast and cask advertise the wrong minimum.
BINARY_MIN_MACOS="$(xcrun vtool -show-build "$APP_NAME/Contents/MacOS/ScreenshotRenamer" \
    | awk '/minos/ && !found { print $2; found = 1 }')"
if [[ "$BINARY_MIN_MACOS" != "$MIN_MACOS" ]]; then
    echo "Error: Binary requires macOS '$BINARY_MIN_MACOS' but Info.plist LSMinimumSystemVersion is '$MIN_MACOS'"
    exit 1
fi

# AppKit picks linked-on-or-after behaviour from the binary's SDK stamp, so it
# must be the SDK we built against, not the deployment target (see build-app.sh).
BINARY_SDK="$(xcrun vtool -show-build "$APP_NAME/Contents/MacOS/ScreenshotRenamer" \
    | awk '/ sdk / && !found { print $2; found = 1 }')"
ACTIVE_SDK="$(xcrun --sdk macosx --show-sdk-version)"
if [[ "$BINARY_SDK" != "$ACTIVE_SDK" ]]; then
    echo "Error: Binary records SDK '$BINARY_SDK' but it was built with the macOS $ACTIVE_SDK SDK"
    exit 1
fi
echo "  Binary: minimum macOS $BINARY_MIN_MACOS, SDK $BINARY_SDK"

# The cask's arch constraint mirrors the architectures actually shipped, so
# Homebrew refuses installs the binary can't run (empty = universal, no limit).
BINARY_ARCHS="$(lipo -archs "$APP_NAME/Contents/MacOS/ScreenshotRenamer")"
case "$BINARY_ARCHS" in
    arm64) CASK_ARCH="arm64" ;;
    x86_64) CASK_ARCH="x86_64" ;;
    "x86_64 arm64" | "arm64 x86_64") CASK_ARCH="" ;;
    *)
        echo "Error: Unexpected binary architectures '$BINARY_ARCHS'"
        exit 1
        ;;
esac
echo "  Architectures: $BINARY_ARCHS"

# ── Phase 4: Notarize ──────────────────────────────────────────────

RELEASE_DIR="/tmp/screenshotrenamer-release"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

ZIP_PATH="$RELEASE_DIR/ScreenshotRenamer.zip"
echo "── Creating zip for notarization..."
ditto -c -k --norsrc --keepParent "$APP_NAME" "$ZIP_PATH"

echo "── Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "── Stapling notarization ticket..."
xcrun stapler staple "$APP_NAME"

# Verify staple
if ! xcrun stapler validate "$APP_NAME" &>/dev/null; then
    echo "Error: Stapler validation failed"
    exit 1
fi

# Strip xattrs after stapling, re-zip without resource forks
xattr -rc "$APP_NAME"
rm "$ZIP_PATH"
ditto -c -k --norsrc --keepParent "$APP_NAME" "$ZIP_PATH"
echo "  Notarized and stapled."

# ── Phase 5: Sparkle EdDSA sign ────────────────────────────────────

echo "── Signing with Sparkle EdDSA..."
SIGN_OUTPUT="$("$SIGN_UPDATE" "$ZIP_PATH")"
echo "  $SIGN_OUTPUT"

ED_SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
FILE_LENGTH="$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"

if [[ -z "$ED_SIGNATURE" ]]; then
    echo "Error: Failed to parse EdDSA signature from sign_update output"
    exit 1
fi
if [[ -z "$FILE_LENGTH" ]]; then
    echo "Error: Failed to parse file length from sign_update output"
    exit 1
fi

echo "  Signature: ${ED_SIGNATURE:0:20}..."
echo "  Length: $FILE_LENGTH"

# ── Phase 6: Artifacts ─────────────────────────────────────────────

DMG_PATH="$RELEASE_DIR/ScreenshotRenamer.dmg"
echo "── Creating DMG..."
# diskutil images a folder's contents, so stage the app inside a folder to keep
# ScreenshotRenamer.app at the volume root. (hdiutil create is deprecated.)
DMG_STAGING="$RELEASE_DIR/dmg-staging"
mkdir -p "$DMG_STAGING"
ditto "$APP_NAME" "$DMG_STAGING/$APP_NAME"
diskutil image create from --format UDZO --volumeName "Screenshot Renamer" \
    "$DMG_STAGING" "$DMG_PATH"
rm -rf "$DMG_STAGING"

echo "── Generating checksums..."
(cd "$RELEASE_DIR" && shasum -a 256 ScreenshotRenamer.zip > ScreenshotRenamer.zip.sha256)
(cd "$RELEASE_DIR" && shasum -a 256 ScreenshotRenamer.dmg > ScreenshotRenamer.dmg.sha256)
ZIP_SHA256=$(cd "$RELEASE_DIR" && shasum -a 256 ScreenshotRenamer.zip | awk '{print $1}')
echo "  ZIP SHA256: $ZIP_SHA256"

# ── Phase 7: Tag & GitHub release (idempotent) ─────────────────────

echo "── Tagging..."
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "  Tag v$VERSION exists locally."
elif git ls-remote --tags origin "refs/tags/v$VERSION" | grep -q .; then
    echo "  Tag v$VERSION exists on remote. Fetching."
    git fetch origin "refs/tags/v$VERSION:refs/tags/v$VERSION"
else
    git tag -a "v$VERSION" -m "Release v$VERSION"
    echo "  Created tag v$VERSION."
fi
git push origin "v$VERSION" 2>&1 || true

echo "── GitHub release..."
if gh release view "v$VERSION" &>/dev/null; then
    echo "  Release v$VERSION already exists. Skipping creation."
else
    PREVIOUS_TAG=$(git describe --tags --abbrev=0 "v$VERSION^" 2>/dev/null || echo "")
    if [[ -n "$PREVIOUS_TAG" ]]; then
        COMMITS=$(git log "$PREVIOUS_TAG..v$VERSION" --pretty=format:"- %s (%h)" --no-merges)
    else
        COMMITS=$(git log --pretty=format:"- %s (%h)" --no-merges -10)
    fi

    RELEASE_NOTES="**Requires macOS $MIN_MACOS or later.**

## What's Changed

$COMMITS

**Full Changelog**: https://github.com/$REPO/compare/${PREVIOUS_TAG}...v$VERSION

---
See the [README](https://github.com/$REPO#readme) for installation and usage instructions."

    gh release create "v$VERSION" \
        "$ZIP_PATH" \
        "$ZIP_PATH.sha256" \
        "$DMG_PATH" \
        "$DMG_PATH.sha256" \
        --title "Screenshot Renamer v$VERSION" \
        --notes "$RELEASE_NOTES" \
        --latest
    echo "  GitHub release created."
fi

# Verify release has assets
ASSET_COUNT=$(gh release view "v$VERSION" --json assets --jq '.assets | length')
if [[ "$ASSET_COUNT" -lt 4 ]]; then
    echo "Error: GitHub release has $ASSET_COUNT assets (expected 4)"
    exit 1
fi
echo "  Verified: $ASSET_COUNT assets on GitHub release."

# ── Phase 8: Appcast (idempotent, verified) ────────────────────────

echo "── Updating appcast..."
PUB_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S %z')"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/ScreenshotRenamer.zip"

PAGES_DIR="/tmp/screenshotrenamer-ghpages"
rm -rf "$PAGES_DIR"

if ! git clone --branch gh-pages --single-branch --depth 1 \
    "https://github.com/$REPO.git" "$PAGES_DIR"; then
    echo "Error: Failed to clone gh-pages branch"
    exit 1
fi

cat > "$PAGES_DIR/appcast.xml" <<APPCAST_EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Screenshot Renamer</title>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_MACOS</sparkle:minimumSystemVersion>
      <enclosure url="$DOWNLOAD_URL"
                 sparkle:edSignature="$ED_SIGNATURE"
                 length="$FILE_LENGTH"
                 type="application/octet-stream" />
    </item>
$LEGACY_ITEMS
  </channel>
</rss>
APPCAST_EOF

(cd "$PAGES_DIR" && git add appcast.xml)
if ! (cd "$PAGES_DIR" && git diff --cached --quiet); then
    (cd "$PAGES_DIR" && git commit -m "Update appcast for v$VERSION")
    if ! (cd "$PAGES_DIR" && git push origin gh-pages); then
        echo "Error: Failed to push appcast to gh-pages"
        exit 1
    fi
    echo "  Appcast committed and pushed."
else
    echo "  Appcast already up to date on gh-pages."
fi
rm -rf "$PAGES_DIR"

# Verify appcast is live
echo "── Verifying appcast deployment..."
RETRIES=6
for i in $(seq 1 $RETRIES); do
    LIVE_VERSION=$(curl -sf "$APPCAST_URL" | grep -o '<sparkle:version>[^<]*' | head -1 | sed 's/<sparkle:version>//' || true)
    if [[ "$LIVE_VERSION" == "$VERSION" ]]; then
        echo "  Appcast verified: v$LIVE_VERSION"
        break
    fi
    if [[ $i -eq $RETRIES ]]; then
        echo "  WARNING: Appcast not yet showing v$VERSION (still v$LIVE_VERSION)."
        echo "  GitHub Pages may take up to 60s to propagate. Verify manually:"
        echo "  curl -s $APPCAST_URL | grep sparkle:version"
        break
    fi
    echo "  Waiting for GitHub Pages cache (attempt $i/$RETRIES)..."
    sleep 5
done

# ── Phase 9: Homebrew Cask (idempotent, verified) ──────────────────

echo "── Updating Homebrew Cask..."
TAP_DIR="/tmp/homebrew-tpak"
rm -rf "$TAP_DIR"

if ! gh repo view tpak/homebrew-tpak &>/dev/null; then
    echo "  WARNING: Homebrew tap repo not found. Create it with:"
    echo "    gh repo create tpak/homebrew-tpak --public"
else
    if ! gh repo clone tpak/homebrew-tpak "$TAP_DIR"; then
        echo "Error: Failed to clone Homebrew tap repo"
        exit 1
    fi

    CASK_FILE="$TAP_DIR/Casks/screenshot-renamer.rb"
    if [[ ! -f "$CASK_FILE" ]]; then
        echo "Error: Cask file not found at $CASK_FILE"
        exit 1
    fi

    sed -i '' "s/version \"[^\"]*\"/version \"$VERSION\"/" "$CASK_FILE"
    sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$ZIP_SHA256\"/" "$CASK_FILE"
    sed -i '' "s/depends_on macos: [^[:space:]]*/depends_on macos: :$CASK_MACOS/" "$CASK_FILE"
    if ! grep -q "depends_on macos: :$CASK_MACOS\$" "$CASK_FILE"; then
        echo "Error: Cask is missing 'depends_on macos: :$CASK_MACOS' after update"
        exit 1
    fi
    sed -i '' "/depends_on arch: /d" "$CASK_FILE"
    if [[ -n "$CASK_ARCH" ]]; then
        awk -v line="  depends_on arch: :$CASK_ARCH" \
            '{ print } /^  depends_on macos: / && !done { print line; done = 1 }' \
            "$CASK_FILE" > "$CASK_FILE.tmp"
        mv "$CASK_FILE.tmp" "$CASK_FILE"
        if ! grep -q "^  depends_on arch: :$CASK_ARCH\$" "$CASK_FILE"; then
            echo "Error: Cask is missing 'depends_on arch: :$CASK_ARCH' after update"
            exit 1
        fi
    fi

    (cd "$TAP_DIR" && git add -A)
    if ! (cd "$TAP_DIR" && git diff --cached --quiet); then
        (cd "$TAP_DIR" && git commit -m "Update to v$VERSION")
        if ! (cd "$TAP_DIR" && git push origin main); then
            echo "Error: Failed to push Homebrew cask update"
            exit 1
        fi
        echo "  Homebrew Cask updated to v$VERSION."
    else
        echo "  Homebrew Cask already at v$VERSION."
    fi
    rm -rf "$TAP_DIR"
fi

# ── Phase 10: Final verification ───────────────────────────────────

echo ""
echo "── Final verification ──"

PASS=true

# GitHub release
ASSET_COUNT=$(gh release view "v$VERSION" --json assets --jq '.assets | length' || echo 0)
if [[ "$ASSET_COUNT" -ge 4 ]]; then
    echo "  [PASS] GitHub release: v$VERSION with $ASSET_COUNT assets"
else
    echo "  [FAIL] GitHub release: expected 4 assets, got $ASSET_COUNT"
    PASS=false
fi

# Appcast
LIVE_VERSION=$(curl -sf "$APPCAST_URL" | grep -o '<sparkle:version>[^<]*' | head -1 | sed 's/<sparkle:version>//' || true)
if [[ "$LIVE_VERSION" == "$VERSION" ]]; then
    echo "  [PASS] Sparkle appcast: v$LIVE_VERSION"
    LIVE_MIN_MACOS=$(curl -sf "$APPCAST_URL" | grep -o '<sparkle:minimumSystemVersion>[^<]*' | head -1 \
        | sed 's/<sparkle:minimumSystemVersion>//' || true)
    if [[ "$LIVE_MIN_MACOS" == "$MIN_MACOS" ]]; then
        echo "  [PASS] Sparkle appcast: minimum macOS $LIVE_MIN_MACOS"
    else
        echo "  [FAIL] Sparkle appcast: minimum macOS '$LIVE_MIN_MACOS' (expected $MIN_MACOS)"
        PASS=false
    fi
else
    echo "  [WARN] Sparkle appcast: v$LIVE_VERSION (Pages cache may need up to 60s)"
    echo "         Verify: curl -s $APPCAST_URL | grep sparkle:version"
fi

# Homebrew
if gh repo view tpak/homebrew-tpak &>/dev/null; then
    CASK_VERSION=$(gh api repos/tpak/homebrew-tpak/contents/Casks/screenshot-renamer.rb \
        -H "Accept: application/vnd.github.v3.raw" 2>/dev/null | grep -o 'version "[^"]*"' | head -1 | cut -d'"' -f2 || true)
    if [[ "$CASK_VERSION" == "$VERSION" ]]; then
        echo "  [PASS] Homebrew Cask: v$CASK_VERSION"
    else
        echo "  [FAIL] Homebrew Cask: v$CASK_VERSION (expected v$VERSION)"
        PASS=false
    fi
    CASK_DEPENDS=$(gh api repos/tpak/homebrew-tpak/contents/Casks/screenshot-renamer.rb \
        -H "Accept: application/vnd.github.v3.raw" 2>/dev/null | grep -o 'depends_on macos: [^[:space:]]*' | head -1 || true)
    if [[ "$CASK_DEPENDS" == "depends_on macos: :$CASK_MACOS" ]]; then
        echo "  [PASS] Homebrew Cask: $CASK_DEPENDS"
    else
        echo "  [FAIL] Homebrew Cask: '$CASK_DEPENDS' (expected depends_on macos: :$CASK_MACOS)"
        PASS=false
    fi
    CASK_ARCH_LINE=$(gh api repos/tpak/homebrew-tpak/contents/Casks/screenshot-renamer.rb \
        -H "Accept: application/vnd.github.v3.raw" 2>/dev/null | grep -o 'depends_on arch: [^[:space:]]*' | head -1 || true)
    EXPECTED_ARCH_LINE=""
    if [[ -n "$CASK_ARCH" ]]; then
        EXPECTED_ARCH_LINE="depends_on arch: :$CASK_ARCH"
    fi
    if [[ "$CASK_ARCH_LINE" == "$EXPECTED_ARCH_LINE" ]]; then
        echo "  [PASS] Homebrew Cask: ${CASK_ARCH_LINE:-no arch restriction (universal)}"
    else
        echo "  [FAIL] Homebrew Cask: arch '$CASK_ARCH_LINE' (expected '${EXPECTED_ARCH_LINE:-none}')"
        PASS=false
    fi
fi

echo ""
if [[ "$PASS" == true ]]; then
    echo "=== Release v$VERSION complete! ==="
else
    echo "=== Release v$VERSION finished with warnings — check above ==="
fi
echo ""
echo "  GitHub:   https://github.com/$REPO/releases/tag/v$VERSION"
echo "  Appcast:  $APPCAST_URL"
echo "  Homebrew: brew tap tpak/tpak && brew install --cask screenshot-renamer"
echo ""
echo "  Artifacts: $RELEASE_DIR/"
echo ""
