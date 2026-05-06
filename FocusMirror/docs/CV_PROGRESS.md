# CV Progress

Last updated: 2026-05-06

## Current Validation Status

Manually tested with the live webcam preview:

| State | Status | Notes |
|---|---|---|
| `focused` | Working in initial manual testing | Face present, screen-facing, eyes open. |
| `away` | Working in initial manual testing | Triggers when face is absent for the sustained no-face window. |
| `eyes_closed` | Working in initial manual testing | Detects sustained closed eyes using EAR. |
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

1. Review the generated prediction CSVs and tighten label boundaries.
2. Add more focused-screen clips under varied lighting and camera positions.
3. Decide whether `talking_screen` remains an accepted v1 limitation.
4. Add correction-aware product-summary eval after the raw visual detector eval.

## Important Product Note

Keep the UI language factual. Do not rename `looking_down` to `phone_use` in v1. The honest interpretation is “head-down time,” with user correction available for reading or writing.
