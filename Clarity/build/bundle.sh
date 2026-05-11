#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_APP="$ROOT/swift-app"
APP="$ROOT/build/Clarity.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"
PYTHON_RUNTIME="$RESOURCES/python-runtime"
SWIFTPM_SCRATCH="$ROOT/build/swiftpm"
CODESIGN_IDENTITY="${CLARITY_CODESIGN_IDENTITY:--}"
INSTALLER_IDENTITY="${CLARITY_INSTALLER_IDENTITY:-}"
PROVISIONING_PROFILE="${CLARITY_PROVISIONING_PROFILE:-}"
PKG="$ROOT/build/Clarity.pkg"

export HOME="$ROOT/build/home"
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
rm -rf "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_SCRATCH"
mkdir -p "$HOME" "$CLANG_MODULE_CACHE_PATH"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

swift build -c release --package-path "$SWIFT_APP" --scratch-path "$SWIFTPM_SCRATCH"
BIN_DIR="$(swift build -c release --package-path "$SWIFT_APP" --scratch-path "$SWIFTPM_SCRATCH" --show-bin-path)"

cp "$BIN_DIR/Clarity" "$MACOS/Clarity"
cp "$SWIFT_APP/Clarity/Info.plist" "$CONTENTS/Info.plist"
plutil -replace CFBundleDevelopmentRegion -string en "$CONTENTS/Info.plist"
cp "$SWIFT_APP/Clarity/Clarity.entitlements" "$RESOURCES/Clarity.entitlements"
cp "$SWIFT_APP/Clarity/Resources/Clarity.icns" "$RESOURCES/Clarity.icns"
rsync -a --delete \
  --exclude ".DS_Store" \
  --exclude ".venv*" \
  --exclude "__pycache__/" \
  --exclude ".pytest_cache/" \
  --exclude "tests/" \
  --exclude "*.pyc" \
  "$ROOT/python-engine/" "$RESOURCES/python-engine/"

if [[ "${CLARITY_VENDOR_PYTHON:-0}" == "1" ]]; then
  python3 -m venv --copies "$PYTHON_RUNTIME"
  "$PYTHON_RUNTIME/bin/python3" -m pip install --upgrade pip
  "$PYTHON_RUNTIME/bin/python3" -m pip install "$ROOT/python-engine"
  while IFS= read -r site_packages; do
    find "$site_packages" -maxdepth 1 \( \
      -name "pip" -o \
      -name "pip-*.dist-info" -o \
      -name "setuptools" -o \
      -name "setuptools-*.dist-info" -o \
      -name "wheel" -o \
      -name "wheel-*.dist-info" \
    \) -exec rm -rf {} +
  done < <("$PYTHON_RUNTIME/bin/python3" -c 'import site; print("\n".join(site.getsitepackages()))')
  find "$PYTHON_RUNTIME/bin" -type f -name "pip*" -delete
  find "$PYTHON_RUNTIME" -name "__pycache__" -type d -prune -exec rm -rf {} +
  find "$PYTHON_RUNTIME" -name "tests" -type d -prune -exec rm -rf {} +
  find "$PYTHON_RUNTIME" -name "*.pyc" -type f -delete
  while IFS= read -r -d '' file; do
    if ! file "$file" | grep -q "Mach-O"; then
      chmod a-x "$file"
    fi
  done < <(find "$PYTHON_RUNTIME" -type f -perm -111 -print0)
else
  echo "Warning: Python runtime not vendored. Release builds require CLARITY_VENDOR_PYTHON=1."
fi

if [[ -n "$PROVISIONING_PROFILE" ]]; then
  cp "$PROVISIONING_PROFILE" "$CONTENTS/embedded.provisionprofile"
fi

if command -v codesign >/dev/null 2>&1; then
  sign_macho_files() {
    local root="$1"
    while IFS= read -r -d '' file; do
      if file "$file" | grep -q "Mach-O"; then
        codesign --force --sign "$CODESIGN_IDENTITY" "$file"
      fi
    done < <(find "$root" -type f -print0)
  }

  if [[ -d "$PYTHON_RUNTIME" ]]; then
    sign_macho_files "$PYTHON_RUNTIME"
  fi

  codesign --force --sign "$CODESIGN_IDENTITY" \
    --entitlements "$SWIFT_APP/Clarity/Clarity.entitlements" \
    "$APP"
fi

echo "Built $APP"

if [[ "${CLARITY_CREATE_PKG:-0}" == "1" ]]; then
  if [[ -n "$INSTALLER_IDENTITY" ]]; then
    productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"
  else
    productbuild --component "$APP" /Applications "$PKG"
  fi
  echo "Built $PKG"
fi
