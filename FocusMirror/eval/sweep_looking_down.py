from __future__ import annotations

import argparse
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
    "looking_down_phone_01",
    "looking_down_reading_01",
    "mixed_session_01",
]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Sweep looking_down pitch/duration over selected eval clips")
    parser.add_argument("--pitches", default="-10,-15,-20,-25")
    parser.add_argument("--seconds", default="3,4,5")
    parser.add_argument("--clips", default=",".join(DEFAULT_CLIPS))
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--ear-closed-threshold", type=float, default=0.08)
    parser.add_argument("--window-seconds", type=float, default=3.0)
    parser.add_argument("--transition-windows", type=int, default=1)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    pitches = [float(value) for value in args.pitches.split(",") if value]
    seconds_values = [float(value) for value in args.seconds.split(",") if value]
    clips = [value for value in args.clips.split(",") if value]

    print("pitch,seconds,clip,focused_f1,looking_down_f1,focused_error_seconds,focused_error_pct")
    for pitch in pitches:
        for seconds in seconds_values:
            for clip in clips:
                metrics = evaluate_clip(clip, pitch, seconds, args)
                print(
                    f"{pitch:.1f},{seconds:.1f},{clip},"
                    f"{metrics['focused_f1']:.3f},"
                    f"{metrics['looking_down_f1']:.3f},"
                    f"{metrics['focused_error_seconds']},"
                    f"{metrics['focused_error_pct']:.3f}"
                )
    return 0


def evaluate_clip(clip: str, pitch: float, seconds: float, args: argparse.Namespace) -> dict[str, float]:
    labels = load_labels(ROOT / "eval" / "labels" / f"{clip}.json")
    duration = int(labels["duration_seconds"])
    y_true = labels_to_seconds(labels, duration)

    detector_args = argparse.Namespace(
        fps=args.fps,
        window_seconds=args.window_seconds,
        transition_windows=args.transition_windows,
        face_model=None,
        looking_down_pitch=pitch,
        looking_down_seconds=seconds,
        ear_closed_threshold=args.ear_closed_threshold,
    )
    predictions = run_detector(ROOT / "eval" / "recordings" / f"{clip}.mov", detector_args)
    y_pred = predictions_to_seconds(predictions, duration)
    state_metrics = precision_recall_f1(y_true, y_pred)
    focused_error = focused_time_error_seconds(y_true, y_pred)
    return {
        "focused_f1": state_metrics["focused"].f1,
        "looking_down_f1": state_metrics["looking_down"].f1,
        "focused_error_seconds": focused_error,
        "focused_error_pct": focused_error / max(1, duration),
    }


if __name__ == "__main__":
    raise SystemExit(main())
