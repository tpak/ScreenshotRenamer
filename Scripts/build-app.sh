#!/bin/bash
set -e

# Parse arguments
BUMP_VERSION=false
SIGN_RELEASE=false
for arg in "$@"; do
    case $arg in
        --bump)
            BUMP_VERSION=true
            shift
            ;;
        --sign)
            SIGN_RELEASE=true
            shift
            ;;
    esac
done

echo "🔨 Building Screenshot Renamer..."

# Auto-increment patch version if --bump flag is passed
if [ "$BUMP_VERSION" = true ]; then
    ./Scripts/bump-version.sh patch
fi

# Read version from VERSION file
if [ ! -f "VERSION" ]; then
    echo "❌ ERROR: VERSION file not found"
    exit 1
fi
VERSION=$(cat VERSION | tr -d '[:space:]')
echo "📌 Version: $VERSION"

# Backup original Info.plist outside the source tree, so SPM doesn't scan the
# backup as an unhandled resource during the build. Restore on exit (via trap)
# so a failed build never leaves an injected Info.plist in the working tree.
PLIST_PATH="Sources/ScreenshotRenamer/Resources/Info.plist"
PLIST_BACKUP="$(mktemp -t screenshotrenamer-infoplist)"
cp "$PLIST_PATH" "$PLIST_BACKUP"
trap 'mv -f "$PLIST_BACKUP" "$PLIST_PATH"' EXIT

# Inject version into Info.plist
./Scripts/inject-version.sh

# Build release binary
swift build -c release

# Create .app bundle structure
APP_NAME="ScreenshotRenamer.app"
APP_DIR="$APP_NAME/Contents"
rm -rf "$APP_NAME"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy binary and fix rpath for embedded frameworks
cp .build/release/ScreenshotRenamer "$APP_DIR/MacOS/"
chmod +x "$APP_DIR/MacOS/ScreenshotRenamer"
install_name_tool -add_rpath @loader_path/../Frameworks "$APP_DIR/MacOS/ScreenshotRenamer"

# Copy Info.plist (with version injected) to app bundle
cp Sources/ScreenshotRenamer/Resources/Info.plist "$APP_DIR/"

# Restore original Info.plist in source tree (also handled by the EXIT trap)
mv -f "$PLIST_BACKUP" "$PLIST_PATH"
trap - EXIT

# Copy app icon
cp Sources/ScreenshotRenamer/Resources/AppIcon.icns "$APP_DIR/Resources/"

# Embed Sparkle framework
mkdir -p "$APP_DIR/Frameworks"
SPARKLE_FRAMEWORK=$(find .build/artifacts -name "Sparkle.framework" -type d | head -1)
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Frameworks/"
    echo "✅ Embedded Sparkle.framework"
else
    echo "❌ ERROR: Sparkle.framework not found in build artifacts"
    exit 1
fi

# Code signing
if [ "$SIGN_RELEASE" = true ]; then
    SIGN_IDENTITY="Developer ID Application"
    ENTITLEMENTS="Sources/ScreenshotRenamer/Resources/ScreenshotRenamer.entitlements"

    # Verify certificate is available
    if ! security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
        echo "❌ ERROR: No '$SIGN_IDENTITY' certificate found in keychain"
        exit 1
    fi

    # Strip extended attributes that create ._* files
    xattr -rc "$APP_NAME"

    # Sign inside-out: Sparkle XPC services → helper apps → Autoupdate → framework → main app
    echo "🔐 Signing with Developer ID (inside-out)..."
    SPARKLE_FW="$APP_DIR/Frameworks/Sparkle.framework"
    if [ -d "$SPARKLE_FW" ]; then
        for xpc in "$SPARKLE_FW"/Versions/B/XPCServices/*.xpc; do
            [ -d "$xpc" ] && codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$xpc"
        done
        for helper in "$SPARKLE_FW"/Versions/B/*.app; do
            [ -d "$helper" ] && codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$helper"
        done
        if [ -f "$SPARKLE_FW/Versions/B/Autoupdate" ]; then
            codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_FW/Versions/B/Autoupdate"
        fi
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_FW"
    fi

    # Sign main app with entitlements
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_NAME"

    # Verify signature
    if codesign --verify --deep --strict "$APP_NAME" 2>&1; then
        echo "✅ Code signature verified"
    else
        echo "❌ ERROR: Code signature verification failed"
        exit 1
    fi
else
    # Ad-hoc sign for local development
    codesign --force --deep --sign - "$APP_NAME"
fi

echo ""
echo "✅ Build complete!"
echo "📦 App bundle: $(pwd)/$APP_NAME"
echo "📏 Size: $(du -sh "$APP_NAME" | cut -f1)"
echo "🏷️  Version: $VERSION"
if [ "$SIGN_RELEASE" = true ]; then
    echo "🔐 Signed with Developer ID"
fi
echo ""
echo "To install: cp -r $APP_NAME /Applications/"
echo "To run now: open $APP_NAME"
