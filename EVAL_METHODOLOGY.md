# Evaluation Methodology

The detection engine is the product. If detection is sloppy, the entire honesty premise of the app collapses, you'd be lying to users about their work, which is worse than what Forest does.

This document describes how to build a ground-truth dataset, label it, and measure detection quality before shipping any change.

## Why this matters

Without an eval set, every "improvement" to the detection engine is a vibe. You change a threshold, it feels better in your test, you ship it. Two weeks later you realize you regressed something else. Eval discipline prevents this.

The eval set is the single most important piece of infrastructure in v1. Build it before you optimize anything.

## Building the ground-truth dataset

### What to record

Record at least **3 sessions of 30+ minutes each**, deliberately containing a mix of behaviors. Aim for representation of every state the classifier produces:

- Focused work (typing, reading on screen, thinking while looking at screen)
- Phone use (looking down at phone in lap, on desk)
- Talking to someone in the room (out of frame and in frame)
- Talking to someone on a video call (face oriented at screen, mouth moving)
- Stepping away (toilet break, getting water, leaving for >30 seconds)
- Brief glances away (looking at notebook on desk, looking out window for 2-3 seconds)
- Reading a physical book/notes on the desk (head down but actually working — important edge case)
- Resting head on hand while thinking (easy to misclassify as sleeping)
- Brief micro-naps or sustained eyes-closed thinking
- Stretching, drinking water, adjusting posture

### Recording conditions

Vary the conditions across recordings:
- Different lighting: daytime with window light, evening with desk lamp only, mixed
- Different camera angles: laptop on desk at eye level, laptop slightly below, laptop on lap
- Different backgrounds: blank wall, busy bookshelf, window behind you (backlit)
- With and without glasses (if applicable)
- Different clothing/appearance (hood up, hat, etc., if realistic for your users)

If possible, get recordings from multiple people. A model that works only on the developer's face is not a product.

### Recording setup

- Record at the same resolution and frame rate the production engine will use (e.g. 720p, 30fps source even if engine processes at 5fps).
- Save the raw video file.
- Also save a synchronized timestamp log if anything ambiguous happens, so you can label accurately.

## Labeling

For each recording, produce a JSON label file with this structure:

```json
{
  "video": "session_001.mp4",
  "duration_seconds": 1832,
  "segments": [
    {"start": 0,    "end": 245,  "label": "focused"},
    {"start": 245,  "end": 312,  "label": "looking_down", "note": "phone use"},
    {"start": 312,  "end": 318,  "label": "focused", "note": "glanced back at screen"},
    {"start": 318,  "end": 401,  "label": "looking_down", "note": "phone use"},
    {"start": 401,  "end": 456,  "label": "talking", "note": "to roommate, out of frame"},
    ...
  ]
}
```

Labels should match the engine's output states exactly. Use a tool like CVAT, Label Studio, or even a simple custom UI to scrub through the video and mark segment boundaries. For v1 you can also do this in a spreadsheet and convert to JSON, the goal is to get to 100% labeled coverage.

**Edge case handling in labels:**
- Reading a physical book on desk → label as `focused`. The engine may misclassify as `looking_down`; this is a known hard case and the eval will quantify how often.
- Brief glances away (<2 seconds) → label as the surrounding state (don't fragment the label timeline for tiny events the engine wouldn't catch anyway).
- Genuine ambiguous moments → label your best guess and add a `note`.

## Running the eval

`eval/run_eval.py` should:

1. Load a labeled recording.
2. Run the detection engine on the video file (not the live webcam) at the production frame rate.
3. Produce a per-second prediction timeline.
4. Compare predictions against ground truth on a per-second basis.
5. Output:
   - **Per-state precision, recall, F1**
   - **Confusion matrix** (which states get confused for which)
   - **Total focused time error**: |predicted_focused_seconds - actual_focused_seconds|. This is the user-facing metric; even if per-frame F1 is mediocre, if total focused-time is accurate to within ±5%, the summary screen is still honest.

## Acceptance thresholds for v1

These are minimums for shipping v1. Tighten over time.

| Metric | Target |
|---|---|
| F1 on `focused` state | ≥ 0.85 |
| F1 on `away` state | ≥ 0.95 (this is easy, no excuse) |
| F1 on `looking_down` state | ≥ 0.75 |
| F1 on `talking` state | ≥ 0.70 (genuinely hard, OK to be lower) |
| Total focused-time error | ≤ 5% of session duration |

If you can't hit these, the product isn't ready. Either improve detection or narrow the scope of states claimed.

## When to re-run the eval

- Before merging any change to the detection engine, classifier, or state machine.
- Whenever you add a new test recording (the new data may surface regressions).
- Whenever you tune a threshold in `DETECTION_TUNING.md`.

Make running the eval a one-command operation. Friction here is fatal, if eval takes 20 minutes of manual setup, you'll skip it and ship regressions.

## Beyond v1

- Larger labeled dataset (20+ hours, multiple subjects, diverse demographics).
- Continuous evaluation: every detection engine commit triggers eval automatically.
- User-corrected segments from real users (anonymized, opt-in) become additional eval data over time.
