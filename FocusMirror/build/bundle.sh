#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_APP="$ROOT/swift-app"
APP="$ROOT/build/FocusMirror.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

export HOME="$ROOT/build/home"
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

swift build -c release --package-path "$SWIFT_APP"
BIN_DIR="$(swift build -c release --package-path "$SWIFT_APP" --show-bin-path)"

cp "$BIN_DIR/FocusMirror" "$MACOS/FocusMirror"
cp "$SWIFT_APP/FocusMirror/Info.plist" "$CONTENTS/Info.plist"
cp "$SWIFT_APP/FocusMirror/FocusMirror.entitlements" "$RESOURCES/FocusMirror.entitlements"
rsync -a --delete \
  --exclude ".venv" \
  --exclude "__pycache__" \
  --exclude ".pytest_cache" \
  "$ROOT/python-engine/" "$RESOURCES/python-engine/"

if [[ "${FOCUSMIRROR_VENDOR_PYTHON:-0}" == "1" ]]; then
  python3 -m venv "$RESOURCES/python-runtime"
  "$RESOURCES/python-runtime/bin/python3" -m pip install --upgrade pip
  "$RESOURCES/python-runtime/bin/python3" -m pip install "$ROOT/python-engine"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - \
    --entitlements "$SWIFT_APP/FocusMirror/FocusMirror.entitlements" \
    "$APP"
fi

echo "Built $APP"
