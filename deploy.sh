#!/bin/bash
set -e

# Expandi Deployment Script
# Builds and installs Expandi into /Applications or ~/Applications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Expandi"

echo "=========================================="
echo " Deploying $APP_NAME                      "
echo "=========================================="

# 1. Run build script
./build.sh

SOURCE_BUNDLE="$SCRIPT_DIR/build/$APP_NAME.app"
if [ ! -d "$SOURCE_BUNDLE" ]; then
    echo "Error: Application bundle not found at $SOURCE_BUNDLE"
    exit 1
fi

# 2. Determine target directory
TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

DEST_PATH="$TARGET_DIR/$APP_NAME.app"

echo "Installing to: $DEST_PATH"

# Close running instance if open
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "Stopping currently running instance of $APP_NAME..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# Copy bundle
rm -rf "$DEST_PATH"
cp -R "$SOURCE_BUNDLE" "$DEST_PATH"

# Remove quarantine attribute if present
xattr -dr com.apple.quarantine "$DEST_PATH" 2>/dev/null || true

# Re-sign installed bundle
codesign --force --deep --sign - "$DEST_PATH"

echo ""
echo "=========================================="
echo " Deployment Complete!                     "
echo " Installed at: $DEST_PATH"
echo " "
echo " Next Steps:"
echo " 1. Launch Expandi:"
echo "    open \"$DEST_PATH\""
echo " "
echo " 2. Enable Accessibility Permission:"
echo "    System Settings -> Privacy & Security -> Accessibility"
echo "    Toggle on '$APP_NAME'"
echo "=========================================="
