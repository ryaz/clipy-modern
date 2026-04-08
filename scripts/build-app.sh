#!/bin/bash
set -euo pipefail

APP_NAME="Clipy"
VERSION="${VERSION:-0.1.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# --- Step 1: Build release binary ---
echo "==> Building release binary..."
swift build -c release --arch arm64

BUILD_DIR=".build/arm64-apple-macosx/release"
BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -f "$BINARY" ]; then
  echo "ERROR: Binary not found at $BINARY"; exit 1
fi

# --- Step 2: Create .app bundle ---
echo "==> Creating app bundle..."
APP_BUNDLE="build/${APP_NAME}.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
sed "s/\${VERSION}/$VERSION/g" support/Info.plist > "$APP_BUNDLE/Contents/Info.plist"

if [ -f support/AppIcon.icns ]; then
  cp support/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
fi

# --- Step 3: Ad-hoc code sign ---
echo "==> Code signing (ad-hoc)..."
codesign --force --sign - \
  --entitlements support/Clipy.entitlements \
  "$APP_BUNDLE"

codesign --verify --verbose "$APP_BUNDLE"

# --- Step 4: Create DMG ---
echo "==> Creating DMG..."
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_STAGING="build/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "build/$DMG_NAME"

rm -rf "$DMG_STAGING"

echo ""
echo "==> Done!"
echo "    App: $APP_BUNDLE"
echo "    DMG: build/$DMG_NAME"
echo ""
echo "To install: open build/$DMG_NAME and drag Clipy to Applications"
