#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Eval}"
CONFIGURATION="${CONFIGURATION:-release}"
BUNDLE_ID="${BUNDLE_ID:-com.eval.app}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST_DIR="${DIST_DIR:-"$ROOT_DIR/dist"}"
BUILD_DIR="$ROOT_DIR/.build/$CONFIGURATION"
BINARY_PATH="$BUILD_DIR/$APP_NAME"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
INFO_TEMPLATE="$ROOT_DIR/Sources/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Sources/Eval.entitlements"
INFO_OUT="$CONTENTS_PATH/Info.plist"

mkdir -p "$DIST_DIR"
rm -rf "$APP_PATH"

swift build -c "$CONFIGURATION"

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "Error: build output not found at $BINARY_PATH" >&2
  exit 1
fi

mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"
cp "$BINARY_PATH" "$MACOS_PATH/$APP_NAME"

export APP_NAME BUNDLE_ID VERSION BUILD_NUMBER INFO_TEMPLATE INFO_OUT
/usr/bin/python3 - <<'PY'
import os
import plistlib

template = os.environ["INFO_TEMPLATE"]
out_path = os.environ["INFO_OUT"]

with open(template, "rb") as f:
    plist = plistlib.load(f)

plist["CFBundleExecutable"] = os.environ["APP_NAME"]
plist["CFBundleIdentifier"] = os.environ["BUNDLE_ID"]
plist["CFBundleShortVersionString"] = os.environ["VERSION"]
plist["CFBundleVersion"] = os.environ["BUILD_NUMBER"]

with open(out_path, "wb") as f:
    plistlib.dump(plist, f)
PY

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" \
      --sign "$SIGN_IDENTITY" "$APP_PATH"
  else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
  fi
fi

echo "App bundle created at: $APP_PATH"
