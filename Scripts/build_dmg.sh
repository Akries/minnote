#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MinNote"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DERIVED_DATA_DIR="$ROOT_DIR/build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Release}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

rm -f "$DMG_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

# Xcode registers its derived app with LaunchServices during every build.
# It is only a packaging input, so unregister it to keep Launchpad clean.
"$LSREGISTER" -u "$APP_PATH" >/dev/null 2>&1 || true

echo "Created $DMG_PATH"
