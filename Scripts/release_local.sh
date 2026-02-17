#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Eval}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="${BUNDLE_ID:-com.eval.app}"

export APP_NAME VERSION BUILD_NUMBER BUNDLE_ID

"$ROOT_DIR/Scripts/build_app.sh"
"$ROOT_DIR/Scripts/create_dmg.sh"

echo "Local release artifacts in $ROOT_DIR/dist"
