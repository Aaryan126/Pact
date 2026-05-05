# FocusMirror Swift App

SwiftUI shell for FocusMirror v1. It handles onboarding, session control, local JSON persistence, and IPC with the bundled Python engine.

## Build During Development

```sh
swift build --package-path FocusMirror/swift-app
```

The release `.app` bundle is produced by `../build/bundle.sh`.
