# FocusMirror

FocusMirror is a local-only macOS app that measures what actually happened during a study session. It is not a gamified timer and it does not nag during the session. The v1 app silently observes, classifies second-scale focus states locally, and shows an honest summary after the user ends the session.

## Project Layout

- `swift-app/` - SwiftUI macOS shell, session storage, camera permission, and Python IPC.
- `python-engine/` - MediaPipe/OpenCV detector that emits JSON-line classifications.
- `eval/` - video-label evaluation harness with per-state metrics.
- `docs/` - product, privacy, tuning, eval, robustness, and performance references.
- `build/bundle.sh` - rough local `.app` bundler.

## Run the Python Engine

```sh
cd python-engine
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
focusmirror-engine --source webcam --fps 5
```

## Build the Swift App

```sh
swift build --package-path swift-app
```

## Produce a Local App Bundle

```sh
./build/bundle.sh
```

Set `FOCUSMIRROR_VENDOR_PYTHON=1` to create a bundled Python runtime under `Contents/Frameworks/python-runtime` and install the Python engine into it. Release builds do not fall back to system Python at runtime.

## Privacy Defaults

The v1 entitlements include sandboxing, camera access, and user-selected file access for explicit CSV export only. There is no network client entitlement, no audio permission, no analytics, and no frame storage.
