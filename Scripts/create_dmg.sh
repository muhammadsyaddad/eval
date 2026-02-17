#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Eval}"
VERSION="${VERSION:-1.0.0}"
DIST_DIR="${DIST_DIR:-"$ROOT_DIR/dist"}"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_NAME="${DMG_NAME:-$APP_NAME-$VERSION}"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME}"
STAGING_DIR="$DIST_DIR/dmg_staging"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found at $APP_PATH" >&2
  echo "Run Scripts/build_app.sh first." >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "DMG created at: $DMG_PATH"
