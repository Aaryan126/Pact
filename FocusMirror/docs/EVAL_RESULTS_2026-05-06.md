# Eval Results - 2026-05-06

Dataset: 13 local `.mov` clips in `eval/recordings/`.

Labels: first-pass JSON labels in `eval/labels/`, revised with user-provided timings. Labels now separate `visual_state` from `actual_focus`, so reading/writing can be visually `looking_down` while still counting as actually focused.

Engine settings:

- fps: `5`
- `looking_down_pitch`: `-15`
- `looking_down_seconds`: `3`
- `ear_closed_threshold`: `0.12`
- `ear_open_threshold`: `0.08`
- state smoothing: `3s` window, `1` transition window

## Clip Results

| Clip | Key Visual Result | Raw Actual Focus Error | Correction-Adjusted Error |
|---|---:|---:|---:|
| `focused_screen_01` | `focused` F1 `0.907` | `14s` / `17.07%` | `0s` |
| `focused_low_angle_01` | `focused` F1 `1.000`; no false looking-down from low camera angle | `0s` / `0.00%` | `0s` |
| `away_01` | `away` F1 `0.875`, `focused` F1 `0.894` | `5s` / `7.58%` | `5s` |
| `eyes_closed_01` | `eyes_closed` F1 `0.556`, `focused` F1 `0.818` | `4s` / `9.09%` | `2s` |
| `looking_down_phone_01` | `looking_down` F1 `0.718`, `focused` F1 `0.833` | `4s` / `8.89%` | `6s` |
| `looking_down_reading_01` | `looking_down` F1 `0.909`; visual focused error `0s` | `36s` / `97.30%` | `0s` |
| `looking_down_reading_02` | `looking_down` F1 `0.519`; clip was visually less head-down than intended | `24s` / `40.00%` | `0s` |
| `talking_away_01` | `talking` F1 `0.793`, `focused` F1 `0.645` | `5s` / `10.87%` | `3s` |
| `talking_screen_01` | mouth-only screen-facing movement labeled visual `focused`; `focused` F1 `1.000` | `0s` / `0.00%` known time | `0s` |
| `mouth_false_positive_01` | `focused` F1 `0.904`, no talking false positives | `7s` / `17.50%` | `0s` |
| `mouth_false_positive_02` | `focused` F1 `1.000`, no talking false positives | `0s` / `0.00%` | `0s` |
| `mixed_session_01` | `focused` F1 `0.855`, `away` F1 `0.857`, `looking_down` F1 `0.808`, `eyes_closed` F1 `0.745`, `talking` F1 `0.634` | `13s` / `7.18%` | `17s` |
| `mixed_session_02` | `focused` F1 `0.862`, `away` F1 `0.783`, `looking_down` F1 `0.711`, `eyes_closed` F1 `0.766`, `talking` F1 `0.776` | `2s` / `1.10%` | `10s` |

## Readout

Strongest signals:

- `away` is working reasonably well in both the dedicated clip and mixed session.
- `talking` works when the user talks while turned away from the screen; the two mixed clips now score `0.634` and `0.776` for talking F1.
- `looking_down_reading_01` is now correctly represented: the visual detector sees head-down well (`looking_down` F1 `0.909`), while actual focus requires user correction.
- The false-positive mouth movement clips did not trigger `talking`, which is good.
- `talking_screen_01` is now treated as mouth-only screen-facing movement, not v1 `talking`; the detector correctly leaves it mostly `focused`.
- Splitting EAR thresholds keeps `focused` permissive at `0.08` while using `0.12` for sustained eyes-closed detection.
- A 2-second recent-orientation check reduced single-frame pose spikes in `focused_screen_01`; after later tuning, the current focused F1 is `0.907`.

Weakest signals:

- `focused_screen_01` still has some `uncertain` time from pose-estimation instability.
- `eyes_closed_01` remains weaker than the mixed eyes-closed clips, likely due the exact eye/face posture in that recording.
- `looking_down_reading_02` did not look visually head-down enough for the detector much of the time; this is useful because it shows a boundary case between screen-facing and desk-facing work.

## Looking-Down Sweep

Sweep command:

```sh
python-engine/.venv39/bin/python eval/sweep_looking_down.py
```

Key rows after splitting visual labels from actual focus:

| Pitch | Seconds | `looking_down_phone_01` F1 | `mixed_session_01` looking_down F1 | Mixed Focused Error |
|---:|---:|---:|---:|---:|
| `-10` | `3` | `0.750` | `0.808` | `19s` |
| `-15` | `3` | `0.718` | `0.808` | `19s` |
| `-20` | `3` | `0.467` | `0.558` | `26s` |
| `-25` | `3` | `0.000` | `0.421` | `27s` |

Decision: set pitch to `-15`. `-10` scored slightly higher on phone/reading, but `-15` is a safer default for laptop-camera posture while still fixing the main missed-looking-down cases.

## State-Machine Sweep

Key rows:

| Window | Transitions | Macro Visual F1 | Mixed Focused F1 | Mixed Talking F1 | Mixed Corrected Error |
|---:|---:|---:|---:|---:|---:|
| `2s` | `1` | `0.761` | `0.810` | `0.486` | `28s` |
| `3s` | `1` | `0.774` | `0.785` | `0.444` | `30s` |
| `5s` | `3` | `0.650` | `0.692` | `0.250` | `36s` |

Decision: set state smoothing to `3s` with `1` transition window. This gave the best macro visual F1 while reducing stale `focused` time compared with the original `5s` / `3` setting.

Important: `looking_down_reading_01` should not be tuned away. The visual signal is genuinely head-down, and the product should handle it through post-session correction.

## Immediate Next Steps

1. Add at least one more mixed clip to validate that `-15` pitch and `3s` / `1` smoothing generalize.
2. Add one more reading/writing clip where the notebook/book is clearly lower than the screen.
3. Investigate EAR handling in the dedicated eyes-closed clip.
4. Keep `talking_screen` as an explicit v1 limitation unless the product definition changes.

## Eval Harness Note

`eval/run_eval.py` was updated to read videos sequentially and sample frames at the target fps instead of seeking by timestamp. This avoids hangs on longer QuickTime `.mov` recordings.

`eval/run_eval.py` now supports `--csv eval/results/<clip>_predictions.csv`, which writes a per-second timeline with truth, predicted state, confidence, raw head pose, EAR, MAR, and classifier reason.

`eval/run_suite.py` runs all labeled local clips, refreshes per-clip prediction CSVs, and writes `eval/results/summary.csv`. The summary now includes visual-state metrics, raw actual focused-time metrics, and a correction-adjusted focused-time error that simulates users tagging false non-focused segments as actually focused.
