#!/usr/bin/env bash
set -euo pipefail

if [[ "${CLARITY_SKIP_PYTHON_BUNDLE:-0}" == "1" ]]; then
  echo "Skipping Python bundle preparation because CLARITY_SKIP_PYTHON_BUNDLE=1."
  exit 0
fi

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" || -z "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
  echo "error: Xcode build environment is missing bundle output paths."
  exit 1
fi

if [[ -n "${CLARITY_HOST_PYTHON:-}" ]]; then
  HOST_PYTHON="$CLARITY_HOST_PYTHON"
elif [[ -x "/Library/Frameworks/Python.framework/Versions/Current/bin/python3" ]]; then
  HOST_PYTHON="/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
elif [[ -x "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3" ]]; then
  HOST_PYTHON="/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
else
  HOST_PYTHON="python3"
fi

if ! command -v "$HOST_PYTHON" >/dev/null 2>&1; then
  echo "error: Could not find host Python executable '$HOST_PYTHON'."
  exit 1
fi

echo "Using host Python: $HOST_PYTHON"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SWIFT_APP_ROOT/.." && pwd)"
ENGINE_SRC="$PROJECT_ROOT/python-engine"

RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
FRAMEWORKS_DIR="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
ENGINE_DST="$RESOURCES_DIR/python-engine"
PACKAGES_DST="$RESOURCES_DIR/python-packages"
PYTHON_FRAMEWORK_DST="$FRAMEWORKS_DIR/Python.framework"

SANDBOX_ENTITLEMENTS_FILE=""
if [[ -n "${CODE_SIGN_ENTITLEMENTS:-}" ]]; then
  if [[ -f "$CODE_SIGN_ENTITLEMENTS" ]]; then
    SANDBOX_ENTITLEMENTS_FILE="$CODE_SIGN_ENTITLEMENTS"
  elif [[ -f "$SWIFT_APP_ROOT/$CODE_SIGN_ENTITLEMENTS" ]]; then
    SANDBOX_ENTITLEMENTS_FILE="$SWIFT_APP_ROOT/$CODE_SIGN_ENTITLEMENTS"
  fi
fi

NESTED_EXECUTABLE_ENTITLEMENTS_FILE=""
if [[ -n "$SANDBOX_ENTITLEMENTS_FILE" ]]; then
  if [[ -n "${TARGET_TEMP_DIR:-}" ]]; then
    NESTED_EXECUTABLE_ENTITLEMENTS_FILE="$TARGET_TEMP_DIR/ClarityNestedExecutable.entitlements"
  else
    NESTED_EXECUTABLE_ENTITLEMENTS_FILE="$RESOURCES_DIR/.ClarityNestedExecutable.entitlements"
  fi

  mkdir -p "$(dirname "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE")"
  /usr/libexec/PlistBuddy -c "Clear dict" "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.app-sandbox bool true" "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE"
fi

prune_non_runtime_artifacts() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return
  fi

  find "$root" \( -name "*.a" -o -name "*.o" -o -name "*.bc" \) \( -type f -o -type l \) -delete
}

remove_broken_symlinks() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return
  fi

  while IFS= read -r -d '' symlink; do
    if [[ ! -e "$symlink" ]]; then
      rm -f "$symlink"
    fi
  done < <(find "$root" -type l -print0)
}

validate_symlinks() {
  local root="$1"
  local has_invalid=0
  if [[ ! -d "$root" ]]; then
    return
  fi

  while IFS= read -r -d '' symlink; do
    if [[ ! -e "$symlink" ]]; then
      echo "error: Broken symbolic link remains in bundle: $symlink -> $(readlink "$symlink")"
      has_invalid=1
    fi
  done < <(find "$root" -type l -print0)

  if [[ "$has_invalid" != "0" ]]; then
    exit 1
  fi
}

thin_macho_to_arm64() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    return
  fi

  while IFS= read -r -d '' file; do
    if ! file "$file" | grep -q "Mach-O"; then
      continue
    fi

    local archs
    archs="$(lipo -archs "$file" 2>/dev/null || true)"
    if [[ " $archs " == *" arm64 "* && " $archs " == *" x86_64 "* ]]; then
      lipo "$file" -remove x86_64 -output "$file"
    elif [[ -n "$archs" && " $archs " != *" arm64 "* ]]; then
      rm -f "$file"
    fi
  done < <(find "$root" -type f -print0)
}

if [[ ! -f "$ENGINE_SRC/clarity_engine/main.py" ]]; then
  echo "error: Could not find Clarity Python engine at $ENGINE_SRC."
  exit 1
fi

PYTHON_VERSION="$("$HOST_PYTHON" - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"

PYTHON_FRAMEWORK_VERSION_SRC="$("$HOST_PYTHON" - <<'PY'
from pathlib import Path
import sys

exe = Path(sys.executable).resolve()
parts = exe.parts
try:
    index = parts.index("Python.framework")
except ValueError:
    raise SystemExit("error: Host Python must be a Python.org framework build at /Library/Frameworks/Python.framework.")

version_root = Path(*parts[: index + 3])
if not (version_root / "Python").exists():
    raise SystemExit(f"error: Could not find Python framework binary under {version_root}.")

print(version_root)
PY
)"

mkdir -p "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

echo "Copying Clarity Python engine..."
rsync -a --delete \
  --exclude ".DS_Store" \
  --exclude ".venv*" \
  --exclude "__pycache__/" \
  --exclude ".pytest_cache/" \
  --exclude "tests/" \
  --exclude "*.pyc" \
  "$ENGINE_SRC/" "$ENGINE_DST/"

PYTHON_STAMP="$RESOURCES_DIR/.clarity-python-$PYTHON_VERSION.stamp"
if [[ ! -f "$PYTHON_STAMP" ]]; then
  echo "Embedding Python.framework $PYTHON_VERSION..."
  rm -rf "$PYTHON_FRAMEWORK_DST"
  mkdir -p "$PYTHON_FRAMEWORK_DST/Versions"

  rsync -a --delete \
    --exclude "__pycache__/" \
    --exclude "*.pyc" \
    --exclude "Frameworks/" \
    --exclude "lib/python$PYTHON_VERSION/idlelib/" \
    --exclude "lib/python$PYTHON_VERSION/site-packages/" \
    --exclude "lib/python$PYTHON_VERSION/test/" \
    --exclude "lib/python$PYTHON_VERSION/tkinter/" \
    --exclude "lib/python$PYTHON_VERSION/turtledemo/" \
    "$PYTHON_FRAMEWORK_VERSION_SRC/" \
    "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/"

  ln -sfn "$PYTHON_VERSION" "$PYTHON_FRAMEWORK_DST/Versions/Current"
  ln -sfn "Versions/Current/Headers" "$PYTHON_FRAMEWORK_DST/Headers"
  ln -sfn "Versions/Current/Python" "$PYTHON_FRAMEWORK_DST/Python"
  ln -sfn "Versions/Current/Resources" "$PYTHON_FRAMEWORK_DST/Resources"

  install_name_tool -id "@rpath/Python.framework/Versions/$PYTHON_VERSION/Python" \
    "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/Python"

  while IFS= read -r -d '' executable; do
    if file "$executable" | grep -q "Mach-O"; then
      install_name_tool -change "$PYTHON_FRAMEWORK_VERSION_SRC/Python" \
        "@executable_path/../Python" \
        "$executable" || true
    fi
  done < <(find "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/bin" -type f -print0)

  touch "$PYTHON_STAMP"
fi

find "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/bin" -mindepth 1 -maxdepth 1 \
  ! \( -name "python3" -o -name "python$PYTHON_VERSION" \) \
  -exec rm -rf {} +
prune_non_runtime_artifacts "$PYTHON_FRAMEWORK_DST"
thin_macho_to_arm64 "$PYTHON_FRAMEWORK_DST"
rm -f "$PYTHON_FRAMEWORK_DST"/.clarity-python-*.stamp
rm -rf \
  "$PYTHON_FRAMEWORK_DST/Headers" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/Frameworks" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/Headers" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/include" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/pkgconfig" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/python$PYTHON_VERSION/config-$PYTHON_VERSION-darwin" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/python$PYTHON_VERSION/idlelib" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/python$PYTHON_VERSION/tkinter" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/python$PYTHON_VERSION/turtledemo" \
  "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/share"
find "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/python$PYTHON_VERSION/lib-dynload" \
  -name "_tkinter.*" -type f -delete
remove_broken_symlinks "$PYTHON_FRAMEWORK_DST"

PACKAGES_STAMP_INPUT="$("$HOST_PYTHON" - <<PY
from pathlib import Path
import hashlib

paths = [
    Path("$ENGINE_SRC/pyproject.toml"),
]
digest = hashlib.sha256()
digest.update("$PYTHON_VERSION".encode())
for path in paths:
    digest.update(path.read_bytes())
print(digest.hexdigest())
PY
)"
PACKAGES_STAMP="$PACKAGES_DST/.clarity-packages-$PACKAGES_STAMP_INPUT.stamp"

if [[ ! -f "$PACKAGES_STAMP" ]]; then
  echo "Installing Clarity Python dependencies..."
  rm -rf "$PACKAGES_DST"
  mkdir -p "$PACKAGES_DST"
  "$HOST_PYTHON" -m pip install \
    --disable-pip-version-check \
    --no-compile \
    --upgrade \
    --target "$PACKAGES_DST" \
    "$ENGINE_SRC"

  find "$PACKAGES_DST" -name "__pycache__" -type d -prune -exec rm -rf {} +
  find "$PACKAGES_DST" -name "tests" -type d -prune -exec rm -rf {} +
  find "$PACKAGES_DST" -name "*.pyc" -type f -delete
  touch "$PACKAGES_STAMP"
fi
prune_non_runtime_artifacts "$PACKAGES_DST"
thin_macho_to_arm64 "$PACKAGES_DST"
remove_broken_symlinks "$PACKAGES_DST"

rewrite_dependency() {
  local file="$1"
  if ! file "$file" | grep -q "Mach-O"; then
    return
  fi

  install_name_tool -change "$PYTHON_FRAMEWORK_VERSION_SRC/Python" \
    "@rpath/Python.framework/Versions/$PYTHON_VERSION/Python" \
    "$file" 2>/dev/null || true
}

while IFS= read -r -d '' file; do
  rewrite_dependency "$file"
done < <(find "$PACKAGES_DST" "$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/lib/python$PYTHON_VERSION/lib-dynload" -type f -print0)

SIGNING_IDENTITY=""
if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${EXPANDED_CODE_SIGN_IDENTITY:-}" != "-" ]]; then
  SIGNING_IDENTITY="$EXPANDED_CODE_SIGN_IDENTITY"
elif [[ "${CLARITY_AD_HOC_SIGN_PYTHON:-1}" == "1" ]]; then
  SIGNING_IDENTITY="-"
fi

sign_macho_file() {
  local file="$1"
  local file_info
  file_info="$(file "$file")"

  if [[ "$file_info" != *"Mach-O"* ]]; then
    return
  fi

  if [[ "$file_info" == *"executable"* && -n "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE" ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none \
      --entitlements "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE" \
      "$file"
  else
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$file"
  fi
}

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing bundled Python runtime..."
  while IFS= read -r -d '' file; do
    sign_macho_file "$file"
  done < <(find "$PYTHON_FRAMEWORK_DST" "$PACKAGES_DST" -type f -print0)

  PYTHON_APP="$PYTHON_FRAMEWORK_DST/Versions/$PYTHON_VERSION/Resources/Python.app"
  if [[ -d "$PYTHON_APP" && -n "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE" ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none \
      --entitlements "$NESTED_EXECUTABLE_ENTITLEMENTS_FILE" \
      "$PYTHON_APP"
  fi

  codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$PYTHON_FRAMEWORK_DST"
fi

validate_symlinks "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"

echo "Prepared bundled Python engine and runtime."
