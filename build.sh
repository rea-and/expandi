#!/bin/bash
set -e

# Expandi Build Script
# Builds release binary, packages macOS App Bundle, and signs bundle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Expandi"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=========================================="
echo " Building $APP_NAME for macOS (Release)   "
echo "=========================================="

# 1. Compile Swift Package in Release configuration
echo "[1/4] Compiling Swift Release binary..."
swift build -c release

RELEASE_BIN="$SCRIPT_DIR/.build/release/$APP_NAME"
if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Release binary not found at $RELEASE_BIN"
    exit 1
fi

# 2. Setup App Bundle structure
echo "[2/4] Assembling macOS application bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$RELEASE_BIN" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy Icon
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 3. Ad-hoc code signing
echo "[3/4] Code signing application bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 4. Verify bundle
echo "[4/4] Verifying application bundle..."
codesign --verify --deep --strict --verbose=1 "$APP_BUNDLE"

echo ""
echo "=========================================="
echo " Build Succeeded!                         "
echo " Bundle: $APP_BUNDLE"
echo " Size:   $(du -sh "$APP_BUNDLE" | cut -f1)"
echo "=========================================="
