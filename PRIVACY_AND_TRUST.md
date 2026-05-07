# Privacy and Trust

FocusMirror points a camera at students for hours. The privacy story is not a marketing detail, it's the core of the product. If users don't trust that nothing leaves their device, they won't use it, and they'd be right not to.

This document defines the privacy guarantees, how to implement them, and how to communicate them.

## Hard guarantees

These are non-negotiable for v1. If you can't ship them, don't ship.

1. **No video frames ever leave the device.** Frames are processed in memory and discarded. Never written to disk except in explicit debug mode (clearly marked, off by default).
2. **No images, screenshots, or thumbnails are stored.** The session record contains state classifications and timestamps only, no visual data.
3. **No audio is captured in v1.** Microphone permission is not requested.
4. **No network calls during sessions.** The detection engine and Swift app have no network code paths during an active session.
5. **No analytics, no telemetry, no crash reporters that send data.** Not even anonymized "to improve the product." If you want crash reports later, make them opt-in with explicit consent and clear data inspection.
6. **No third-party SDKs that phone home.** Audit dependencies. MediaPipe and OpenCV are local. Don't add SDKs casually.

## What is stored locally

- Session records: start/end timestamps, state segments with timestamps, user corrections.
- App preferences.

That's it. No video, no images, no audio, no biometric templates.

Stored in `~/Library/Application Support/FocusMirror/`. User can inspect, delete, or back up this directory at will.

## Implementation

### Camera permission
Use `NSCameraUsageDescription` in `Info.plist` with this exact string or close to it:

> "FocusMirror uses your camera locally to measure your focus during study sessions. Video is processed on your Mac and never leaves your device, no images or video are saved or sent anywhere."

### Sandbox and entitlements
The app should be sandboxed. The required entitlements:
- `com.apple.security.device.camera` — for webcam access
- `com.apple.security.app-sandbox` — sandbox enabled
- `com.apple.security.files.user-selected.read-write` only for user-initiated CSV export destinations
- App-owned session data stays in the app's Application Support directory

Specifically **not** included:
- `com.apple.security.network.client` — no outbound network during sessions

If you need network for the *outside* of sessions (e.g. checking for updates, eventually), gate it carefully. For v1, simplest is no network entitlement at all.

### Verifying no network calls
- Run the app with Little Snitch or Lulu while doing a full session. Verify zero network requests.
- Add a CI check that greps the codebase for network APIs (`URLSession`, `requests`, `urllib`, etc.) and fails if any appear in the engine or session-handling code paths.

### Python subprocess sandboxing
The bundled Python interpreter inherits the sandbox of the parent .app, so it cannot make network calls either. Verify this explicitly with a test that tries to make a request and confirms it fails.

## What to show users

### Onboarding screen
First-run experience should include a privacy panel that says, in plain language:

- What the camera is used for
- That nothing leaves their device
- That they can verify this themselves (Activity Monitor, Little Snitch)
- That no audio is captured
- Where their data is stored locally
- How to delete it

Don't bury this in a privacy policy PDF. Show it in the onboarding flow.

### In-session indicator
While a session is active, show:
- A small dot in the menu bar showing the camera is active
- Reinforce this with a brief inline note in the active session screen: "Camera on. Processing locally. No recording."

### Privacy section in settings
A dedicated screen that:
- Restates the guarantees
- Shows the local data directory path with a "Reveal in Finder" button
- Has a "Delete all my data" button
- Optional: a "Verify offline" mode where the app refuses to start if any network is detected, for the most paranoid users

## Trust signals beyond what's in the app

These help, especially for early adoption:

- **Open-source the detection engine.** The Python engine has no IP advantage in being closed. Open-sourcing it lets technical users verify the privacy claims directly.
- **Code-sign and notarize the .app properly.** Required for Gatekeeper not to scare users.
- **Be transparent about future changes.** If you ever add cloud features, they must be opt-in and clearly delineated.

## Things to avoid

- Don't say "we encrypt your data" as a privacy claim. The strong claim is "we don't have your data." Encryption is for things that travel; if nothing travels, encryption isn't the relevant guarantee.
- Don't say "anonymous analytics" without explaining exactly what's sent. Most users (correctly) read this as "they're sending stuff."
- Don't add a "create an account" flow in v1. Accounts are an attack surface for trust. If users want backup/sync later, make it explicit, optional, and end-to-end encrypted.

## Future considerations (post-v1)

- If you add a feedback loop where user corrections improve detection, that data should stay local by default. Sharing should be explicit, opt-in, and only the labels (not video).
- If you ever add cloud sync, design it end-to-end encrypted such that you (the developer) cannot read any user data even if compelled.
