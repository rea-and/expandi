#!/bin/bash
set -e

# Expandi Clean Script
# Cleans build artifacts, derived data, and temporary files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo " Cleaning Expandi Build Artifacts         "
echo "=========================================="

rm -rf "$SCRIPT_DIR/.build"
rm -rf "$SCRIPT_DIR/build"
rm -rf "$SCRIPT_DIR/AppIcon.iconset"
find "$SCRIPT_DIR" -name ".DS_Store" -delete 2>/dev/null || true

echo "Clean completed successfully."
echo "=========================================="
