# Clarity — Spec Package

This folder contains the full specification for building **Clarity v1**, a macOS desktop app that gives students an honest measurement of their actual focused work time during study sessions.

## Files

- **`CODING_AGENT_PROMPT.md`** — the main prompt to give your coding agent. Contains product principles, architecture, v1 scope, project structure, build order, and definition of done.
- **`docs/EVAL_METHODOLOGY.md`** — how to build a ground-truth dataset and measure detection quality. Critical: the product is only as good as its detection.
- **`docs/ROBUSTNESS_TESTING.md`** — the matrix of conditions (lighting, angles, appearance) the engine must handle, plus known hard cases.
- **`docs/PERFORMANCE_AND_BATTERY.md`** — CPU, memory, battery, and thermal budgets.
- **`docs/PRIVACY_AND_TRUST.md`** — the privacy guarantees and how to implement and communicate them.
- **`docs/DETECTION_TUNING.md`** — per-state thresholds and parameters with reasoning.
- **`docs/ROADMAP_BEYOND_V1.md`** — what's deliberately out of scope and what comes later. Defense against scope creep.

## How to use this with your coding agent

1. Give it `CODING_AGENT_PROMPT.md` as the main task.
2. Tell it to read all files in `docs/` before starting and to copy them into the project's `docs/` folder as the canonical reference.
3. When it asks questions or proposes changes, point it to the relevant doc rather than re-deciding from scratch.

## Architecture summary

- **Swift (SwiftUI) app shell** — UI, session management, storage, macOS integration
- **Python detection engine** (bundled inside .app) — MediaPipe + OpenCV, runs as subprocess
- **IPC** — JSON-line protocol over stdin/stdout
- **Local-only** — no network, no cloud, no accounts in v1

## Core product principles (do not violate)

1. Measurement, not nagging — no real-time alerts in v1
2. Local-only — no data leaves the device
3. No gamification — the honesty is the feature
4. Honest under uncertainty — mark `uncertain` rather than guess wrong
