from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ROOT = ROOT / "python-engine"
sys.path.insert(0, str(ENGINE_ROOT))
sys.path.insert(0, str(ROOT / "eval"))

from metrics import focused_time_error_seconds, precision_recall_f1
from run_eval import labels_to_seconds, load_labels, predictions_to_seconds, run_detector


DEFAULT_CLIPS = [
    "focused_screen_01",
    "eyes_closed_01",
    "mouth_false_positive_01",
    "mixed_session_01",
]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Sweep EAR closed threshold over selected eval clips")
    parser.add_argument("--thresholds", default="0.10,0.12,0.14,0.16")
    parser.add_argument("--clips", default=",".join(DEFAULT_CLIPS))
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--window-seconds", type=float, default=3.0)
    parser.add_argument("--transition-windows", type=int, default=1)
    parser.add_argument("--no-face-seconds", type=float, default=2.0)
    parser.add_argument("--looking-down-pitch", type=float, default=-13.0)
    parser.add_argument("--looking-down-seconds", type=float, default=2.0)
    parser.add_argument("--eyes-closed-seconds", type=float, default=2.0)
    parser.add_argument("--eyes-closed-ratio", type=float, default=0.6)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    thresholds = [float(value) for value in args.thresholds.split(",") if value]
    clips = [value for value in args.clips.split(",") if value]

    print("threshold,clip,focused_f1,eyes_closed_f1,focused_error_seconds,focused_error_pct")
    for threshold in thresholds:
        for clip in clips:
            metrics = evaluate_clip(clip, threshold, args)
            print(
                f"{threshold:.3f},{clip},"
                f"{metrics['focused_f1']:.3f},"
                f"{metrics['eyes_closed_f1']:.3f},"
                f"{metrics['focused_error_seconds']},"
                f"{metrics['focused_error_pct']:.3f}"
            )
    return 0


def evaluate_clip(clip: str, threshold: float, args: argparse.Namespace) -> dict[str, float]:
    labels = load_labels(ROOT / "eval" / "labels" / f"{clip}.json")
    duration = int(labels["duration_seconds"])
    y_true = labels_to_seconds(labels, duration)

    detector_args = argparse.Namespace(
        fps=args.fps,
        window_seconds=args.window_seconds,
        transition_windows=args.transition_windows,
        face_model=None,
        no_face_seconds=args.no_face_seconds,
        looking_down_pitch=args.looking_down_pitch,
        looking_down_seconds=args.looking_down_seconds,
        eyes_closed_seconds=args.eyes_closed_seconds,
        eyes_closed_ratio=args.eyes_closed_ratio,
        ear_closed_threshold=threshold,
    )
    predictions = run_detector(ROOT / "eval" / "recordings" / f"{clip}.mov", detector_args)
    y_pred = predictions_to_seconds(predictions, duration)
    state_metrics = precision_recall_f1(y_true, y_pred)
    focused_error = focused_time_error_seconds(y_true, y_pred)
    return {
        "focused_f1": state_metrics["focused"].f1,
        "eyes_closed_f1": state_metrics["eyes_closed"].f1,
        "focused_error_seconds": focused_error,
        "focused_error_pct": focused_error / max(1, duration),
    }


if __name__ == "__main__":
    raise SystemExit(main())
