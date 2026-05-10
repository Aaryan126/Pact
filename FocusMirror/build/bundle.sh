#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_APP="$ROOT/swift-app"
APP="$ROOT/build/FocusMirror.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"
PYTHON_RUNTIME="$RESOURCES/python-runtime"

export HOME="$ROOT/build/home"
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

swift build -c release --package-path "$SWIFT_APP"
BIN_DIR="$(swift build -c release --package-path "$SWIFT_APP" --show-bin-path)"

cp "$BIN_DIR/FocusMirror" "$MACOS/FocusMirror"
cp "$SWIFT_APP/FocusMirror/Info.plist" "$CONTENTS/Info.plist"
plutil -replace CFBundleDevelopmentRegion -string en "$CONTENTS/Info.plist"
cp "$SWIFT_APP/FocusMirror/FocusMirror.entitlements" "$RESOURCES/FocusMirror.entitlements"
rsync -a --delete \
  --exclude ".DS_Store" \
  --exclude ".venv*" \
  --exclude "__pycache__/" \
  --exclude ".pytest_cache/" \
  --exclude "tests/" \
  --exclude "*.pyc" \
  "$ROOT/python-engine/" "$RESOURCES/python-engine/"

if [[ "${FOCUSMIRROR_VENDOR_PYTHON:-0}" == "1" ]]; then
  python3 -m venv --copies "$PYTHON_RUNTIME"
  "$PYTHON_RUNTIME/bin/python3" -m pip install --upgrade pip
  "$PYTHON_RUNTIME/bin/python3" -m pip install "$ROOT/python-engine"
  find "$PYTHON_RUNTIME" -name "__pycache__" -type d -prune -exec rm -rf {} +
  find "$PYTHON_RUNTIME" -name "tests" -type d -prune -exec rm -rf {} +
  find "$PYTHON_RUNTIME" -name "*.pyc" -type f -delete
  while IFS= read -r -d '' file; do
    if ! file "$file" | grep -q "Mach-O"; then
      chmod a-x "$file"
    fi
  done < <(find "$PYTHON_RUNTIME" -type f -perm -111 -print0)
else
  echo "Warning: Python runtime not vendored. Release builds require FOCUSMIRROR_VENDOR_PYTHON=1."
fi

if command -v codesign >/dev/null 2>&1; then
  sign_macho_files() {
    local root="$1"
    while IFS= read -r -d '' file; do
      if file "$file" | grep -q "Mach-O"; then
        codesign --force --sign - "$file"
      fi
    done < <(find "$root" -type f -print0)
  }

  if [[ -d "$PYTHON_RUNTIME" ]]; then
    sign_macho_files "$PYTHON_RUNTIME"
  fi

  codesign --force --sign - \
    --entitlements "$SWIFT_APP/FocusMirror/FocusMirror.entitlements" \
    "$APP"
fi

echo "Built $APP"
