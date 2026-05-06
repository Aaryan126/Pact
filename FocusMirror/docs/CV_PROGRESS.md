# CV Progress

Last updated: 2026-05-06

## Current Validation Status

Manually tested with the live webcam preview and 13 labeled local clips:

| State | Status | Notes |
|---|---|---|
| `focused` | Working | `focused_low_angle_01` passed with F1 `1.000`; `focused_screen_01` still has some pose-related uncertainty. |
| `away` | Working | Triggers when face is absent for the sustained no-face window; mixed clips are reasonable but still transition-lagged. |
| `eyes_closed` | Improved | Split open/closed EAR thresholds improved `mixed_session_02` eyes-closed F1 to `0.766`. |
| `looking_down` | Working, but semantically ambiguous | Uses head-pose pitch, not eye gaze. Threshold is `pitch <= -15`; sustained window is `3s`. |
| `talking` | Partially working | Detects sustained mouth movement with recent turned-away social context; does not detect mouth-only screen-facing movement. |
| `uncertain` | Observed during warm-up/ambiguous frames | Expected during startup and low-confidence transitions. |

## Current Looking-Down Behavior

`looking_down` is deliberately a head-down label, not a phone-use label.

Current defaults:

- Pitch threshold: `<= -15`
- Sustained duration: `3 seconds`
- Required window agreement: `85%`
- Yaw guardrail: `< 35 degrees`
- Roll guardrail: `< 25 degrees`

The detector estimates head pose from MediaPipe face landmarks using nose tip, chin, eye corners, and mouth corners. It does not infer phone use directly, because reading, writing, and phone use can look the same from the webcam.

`focused` uses a short 2-second recent-orientation check so isolated pose-estimation spikes do not immediately become `uncertain`. Sustained away/down/closed/talking states still take priority.

## Live Preview Command

```sh
cd /Users/aaryan/Desktop/Pact/FocusMirror/python-engine
source .venv39/bin/activate
PYTHONPATH=. python -m focusmirror_engine.main --source webcam --fps 5 --preview --no-json
```

For very fast state changes while testing:

```sh
PYTHONPATH=. python -m focusmirror_engine.main --source webcam --fps 5 --preview --no-json --window-seconds 2 --transition-windows 1
```

## Next Manual Tests

1. Record another reading/writing clip with a clearly lower book/notebook position; `looking_down_reading_02` was visually closer to screen-facing than expected.
2. Add another eyes-closed clip to confirm the split EAR thresholds generalize.
3. Add one more mouth false-positive clip with head turns while chewing/drinking.
4. Keep `talking_screen` as an accepted v1 limitation unless the product definition changes.

## Important Product Note

Keep the UI language factual. Do not rename `looking_down` to `phone_use` in v1. The honest interpretation is “head-down time,” with user correction available for reading or writing.
