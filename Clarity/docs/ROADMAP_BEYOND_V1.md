# Roadmap Beyond v1

What's deliberately out of v1 scope, and what's worth considering later. This doc is a defense against scope creep — items here are *not* in v1, full stop.

## Explicitly NOT in v1

### Behavior change features
- Real-time alerts when distracted
- Sounds, notifications, or any interruption during sessions
- Stakes (money pledged, contacts notified, etc.)
- Streaks, scores, achievements, leaderboards
- Daily/weekly goals

Reason: v1 is a self-knowledge tool. Adding behavior change before nailing measurement recreates the Forest problem.

### Detection expansion
- Audio / talking detection via microphone
- Phone object detection via the camera
- Fine-grained activity classification (typing vs. reading vs. note-taking)
- Detecting which app the user is in (would require accessibility permissions)
- Detecting browser tab activity
- Multiple monitor support beyond the primary camera view

Reason: v1 already has enough surface area. Expand detection only after the core states are reliable per the eval thresholds.

### Platform expansion
- Windows, Linux versions
- iOS/iPadOS app
- Companion mobile app for phone-pickup detection
- Web version

Reason: macOS-first focuses the trust story (native app, locally verifiable) and the build complexity. Other platforms come after macOS works.

### Account / cloud features
- User accounts
- Cloud sync of session history
- Cross-device session continuation
- Sharing summaries with friends or study groups
- Web dashboard for reviewing data

Reason: each of these adds a privacy attack surface. v1 is local-only, no accounts, period. Add later only if there's clear demand and a privacy-respecting design.

### Analytics and feedback
- Product analytics (Mixpanel, Amplitude, etc.)
- Crash reporting that sends data
- A/B testing infrastructure
- Anonymous usage stats

Reason: for a privacy-first measurement product, telemetry is a contradiction. If you need feedback, ask users directly via opt-in surveys.

## Strong candidates for v2

In rough priority order. Don't start any of these until v1 is shipped, used, and the detection eval thresholds are met.

### 1. Per-user calibration
A 30-60 second calibration on first launch where the user looks at their screen normally, looks down at their phone, looks away. Tune EAR / pose thresholds per user. Likely meaningful accuracy win for users with glasses, narrow eyes, or unusual posture.

### 2. Better summary insights
Once you have weeks of session data, show patterns:
- Time of day correlations ("your afternoon focus ratio is 30% lower than morning")
- Session length effects ("focus drops sharply after 50 minutes for you")
- Weekly trends

Still purely descriptive, no judgment.

### 3. Focus ratio over time chart
Simple: a line chart of focus ratio per session over the last N sessions. Lets users see if they're improving without gamification.

### 4. Custom session types
User can label a session as "writing essay" or "problem sets" or "exam review". Aggregate stats per type. Useful for self-knowledge ("I focus better on problem sets than reading").

### 5. Optional companion mobile app for phone detection
Without ever processing video on the phone, just signal phone unlock/usage events to the desktop app. Significantly improves accuracy on a major distraction category. Strictly opt-in.

### 6. Open-source the detection engine
Once the engine is stable, publish the Python code. Builds trust, attracts contributors who can improve detection, allows verification of privacy claims.

### 7. Audio-based talking detection (opt-in)
Local-only voice activity detection (Silero VAD) for better talking detection. Strictly local, never recorded, mic permission only requested if user opts in.

## Possible v3+ ideas (parking lot)

Not commitments, just things worth considering eventually:

- **Group accountability mode.** Two users who agree to share their focus ratios with each other (only the aggregate numbers, never raw data) for social accountability. Opt-in on both ends.
- **Integration with calendar.** Auto-start a session when a "study" calendar block begins.
- **Pomodoro integration.** Built-in pomodoro timer that integrates with the focus measurement.
- **Reading-mode detection.** Distinguish reading-on-screen (focused) from looking-down-at-book (focused) from looking-down-at-phone (distracted) — this is the holy grail and probably requires either object detection or paired-device signals.
- **Behavior change mode (opt-in).** Once measurement is rock solid, optionally enable real-time alerts. Strictly opt-in, never default.

## What this roadmap is NOT

It's not a commitment. The most important thing v1 gives you is data on whether anyone actually wants this. Most v2 ideas should be reprioritized or killed based on what real users do and say. Don't build any of this speculatively.

## When to start v2

- v1 is shipped to real users
- Eval F1 thresholds are met across the robustness matrix, not just the dev's own face
- You have at least 50 users with > 5 sessions each
- You've personally watched at least 5 users use the app and noticed where it disappoints them

If those conditions aren't met, fix v1, don't expand it.
