# Performance and Battery

Students study for 1-4 hours at a stretch. If FocusMirror drains the battery, heats the laptop, or makes other apps lag, users will uninstall regardless of how good the detection is.

## Targets

| Metric | Target |
|---|---|
| CPU usage (sustained, on M1/M2 Mac) | < 5% of one core |
| RAM usage (Python engine + Swift app) | < 300 MB total |
| Battery impact for 2-hour session | < 8% extra drain |
| Frame processing rate | 3-5 fps (do NOT process at 30fps) |
| Latency from frame capture to state classification | < 200 ms |

## Why 3-5 fps is enough

The states the engine detects (focused, away, looking_down, talking) all have natural durations of seconds, not milliseconds. There is no value in classifying at 30fps. Sampling at 3-5fps:

- Reduces CPU/GPU load by ~6-10x
- Reduces battery drain proportionally
- Still gives 9-15 samples per 3-second smoothing window, enough for stable classification while keeping transitions responsive
- Reduces thermal load, important for fanless MacBook Airs

If you find yourself thinking "we need faster detection to catch X", reconsider. Most likely X is an event with a duration of multiple seconds and you're already catching it.

## Frame processing approach

Recommended pipeline in the Python engine:

1. Capture from webcam at native rate (often 30fps).
2. Drop frames to hit target fps (e.g. process every 6th frame for 5fps from a 30fps source).
3. Resize captured frame to MediaPipe's expected input size before processing. Don't process full-res frames unnecessarily.
4. Run MediaPipe Face Mesh once per processed frame. This is the dominant cost.
5. Compute derived signals (head pose, EAR, MAR) from landmarks, cheap.
6. Feed result into state machine, emit state every N frames.

## Profiling and budget enforcement

Profile early, profile often. Use:

- macOS Activity Monitor for high-level CPU/memory check
- `py-spy` for sampling profiler on the Python engine
- Instruments (Xcode) for the Swift app

If CPU exceeds budget, the most likely culprits in order:
1. Processing at 30fps instead of throttling
2. Running Face Mesh on too-high-res input frames
3. Running multiple MediaPipe pipelines (e.g. Face Mesh + Pose + Hands) when you only need one

## Battery testing

Run a 2-hour session with the engine active and compare to a baseline 2-hour idle period (screen on, same brightness, no FocusMirror). Battery drain delta is your impact.

Test on at least one Intel Mac and one Apple Silicon Mac, the perf characteristics differ significantly.

## Thermal behavior

On fanless MacBooks (Air models), sustained CPU usage causes throttling and warm chassis. Even if you hit the 5% CPU target, monitor sustained thermal load over a 2-hour session. The laptop should not feel warmer than during normal browsing.

## Resource handling

- Release the camera immediately when a session ends. Do not hold it open in the background.
- Stop the Python subprocess when not in a session. Do not leave it idling.
- Free MediaPipe pipelines on shutdown.

## What to instrument in the app

In a debug build, log periodically:
- Current fps achieved
- Time per frame in MediaPipe
- Time per frame in classification
- Memory usage of the Python process
- Camera capture queue depth (drops indicate you can't keep up)

Strip these logs in release builds, or guard them behind a developer toggle.

## Failure modes to avoid

- **Memory leak in long sessions.** Run a 4-hour session and verify memory is stable. MediaPipe and OpenCV both have potential leak patterns if used naively.
- **Camera never released.** If the engine crashes mid-session, the camera should still get released. Use proper context managers / try-finally in Python.
- **Python subprocess zombie.** If the Swift app crashes, the Python subprocess must not survive. Use process groups or a heartbeat so Python self-terminates if Swift goes away.
