# Detection Tuning

Per-state thresholds, parameters, and the reasoning behind defaults. Treat these as starting points, refine via the eval harness, never via vibes.

## General parameters

| Parameter | Default | Why |
|---|---|---|
| Processing fps | 5 | Plenty for second-scale states; saves battery vs. 30fps |
| Smoothing window | 5 seconds (25 frames at 5fps) | Long enough to filter noise, short enough to feel responsive |
| Transition debounce | 3 consecutive windows | Prevents flickering between states for marginal cases |
| Face detection min confidence | 0.5 | MediaPipe default, works well |
| Face mesh refinement landmarks | enabled | Required for accurate eye/iris position |

## State: `away`

Definition: no face detected in frame for sustained period.

| Parameter | Default | Notes |
|---|---|---|
| No-face threshold | 5 seconds | Brief glances away (looking at notebook) shouldn't count |
| Re-acquire threshold | 1 second | Once face returns, transition out of `away` quickly |

Edge case: face detection occasionally fails for 1-2 frames even when user is present (motion blur, partial occlusion). The 5-second threshold absorbs this.

## State: `focused`

Definition: face present, oriented toward screen, eyes open, not talking.

This is the default state when nothing else fires. Conditions:
- Face detected with confidence ≥ 0.5
- Head pose: |yaw| < 25°, |pitch| < 20° (looking roughly at screen)
- Eyes: EAR > 0.20 (open)
- Mouth movement: MAR variance over last 3 seconds < talking threshold

If all these hold, classify as `focused`.

## State: `looking_down`

Definition: head pose tilted significantly down, sustained. Likely phone use or sleeping head down.

| Parameter | Default | Notes |
|---|---|---|
| Pitch threshold | < -20° (looking down) | Moderate sustained head-down tilt |
| Sustained duration | 5 seconds | Brief glances down at notebook OK |
| Window ratio | 85% of recent valid frames | Requires consistent head-down posture |
| Yaw / roll guardrails | yaw < 35°, roll < 25° | Avoids misclassifying side turns or tilted posture as phone use |

Hard case: reading a physical book on the desk produces the same signal. There is no reliable way to distinguish this from CV alone. Mitigation: user correction on summary screen.

## State: `talking`

Definition: sustained mouth movement combined with either head turned away from screen, or a second face in frame.

This is the hardest signal. Composition:

**Mouth movement detection:**
- Compute Mouth Aspect Ratio (MAR) per frame from face mesh landmarks
- Compute variance of MAR over last 3 seconds
- Mouth-moving threshold: variance > 0.005 (tune via eval)

**Talking signal fires when:**
- Mouth-moving for ≥ 3 of last 5 seconds, AND
- Either |yaw| > 30° (turned away from screen) OR a second face is detected in frame

Why both conditions: mouth movement alone fires too often (chewing gum, reading aloud, mouthing words while thinking). Adding the head-turn or second-face requirement filters most false positives.

| Parameter | Default | Notes |
|---|---|---|
| MAR variance threshold | 0.005 | Calibrate per-eval |
| Mouth-moving window | 3 of last 5 seconds | Filters one-off mouth movements |
| Head-turn angle | yaw > 30° | A clear turn, not just a glance |

Known limitation: video calls (talking while looking at screen) won't be flagged as talking because head pose is forward-facing. This is acceptable for v1 — students on video study calls are arguably "in a session" and the time isn't pure individual focus, but it isn't pure distraction either. Document the limitation.

## State: `eyes_closed`

Definition: face present, oriented toward screen, but eyes closed for sustained period.

| Parameter | Default | Notes |
|---|---|---|
| EAR threshold | 0.20 | Below this counts as closed |
| Sustained duration | 3 seconds | Allow normal blinks (~0.3s) and prolonged blinks |

Note: this overlaps with `looking_down` if the user's head is down and eyes are closed (sleeping). State machine priority: `looking_down` wins if pitch is < -25°, otherwise `eyes_closed`.

## State: `uncertain`

Fallback when detection confidence is too low to commit. Conditions:
- Face detected but landmarks have low confidence
- Severe motion blur
- Face partially occluded (hand covering, etc.)

Better to mark `uncertain` than to confidently classify wrong. The summary screen can show uncertain time as a separate category, and users can tag it as focused or distracted post-hoc.

## State machine priority

When multiple conditions could fire, apply this priority order:

1. `away` (no face) — overrides everything
2. `looking_down` (pitch < -25° sustained)
3. `talking` (mouth + head-turn or second face)
4. `eyes_closed` (eyes shut sustained)
5. `focused` (default if face is present and oriented)
6. `uncertain` (fallback)

## Tuning workflow

1. Pick one parameter to tune.
2. Run eval on current settings, record baseline metrics.
3. Sweep the parameter across a small range (e.g. EAR threshold from 0.15 to 0.25 in 0.01 steps).
4. Rerun eval at each step.
5. Pick the value that maximizes F1 on the affected state without significantly hurting other states.
6. Commit the change with the eval results in the commit message.

Do not tune multiple parameters at once. You won't know what helped or hurt.

## Per-user calibration (post-v1)

EAR baselines vary by individual (eye shape, glasses, etc.). Eventually a 30-second calibration step at first launch could improve per-user accuracy. Out of scope for v1.
