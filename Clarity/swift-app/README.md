# Clarity Swift App

SwiftUI shell for Clarity v1. It handles onboarding, session control, local JSON persistence, and IPC with the bundled Python engine.

## Build During Development

```sh
swift build --package-path Clarity/swift-app
```

The release `.app` bundle is produced by `../build/bundle.sh`.
