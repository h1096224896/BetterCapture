#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="BetterCapture"
CONFIGURATION="${CONFIGURATION:-Debug}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/build"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

mkdir -p "$DIST_DIR"

xcodebuild build \
  -project "$ROOT_DIR/BetterCapture.xcodeproj" \
  -scheme "$APP_NAME" \
  -destination "platform=macOS" \
  -configuration "$CONFIGURATION" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$BUILD_DIR/$APP_NAME.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
