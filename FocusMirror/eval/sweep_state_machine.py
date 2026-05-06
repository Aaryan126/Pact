from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ROOT = ROOT / "python-engine"
sys.path.insert(0, str(ENGINE_ROOT))
sys.path.insert(0, str(ROOT / "eval"))

from metrics import (
    correction_adjusted_focused_time_error_seconds,
    focused_time_error_from_focus_truth,
    precision_recall_f1,
)
from run_eval import actual_focus_to_seconds, labels_to_seconds, load_labels, predictions_to_seconds, run_detector


DEFAULT_CLIPS = [
    "away_01",
    "eyes_closed_01",
    "focused_screen_01",
    "looking_down_phone_01",
    "looking_down_reading_01",
    "mixed_session_01",
    "mouth_false_positive_01",
    "talking_away_01",
    "talking_screen_01",
]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Sweep state-machine smoothing/debounce settings")
    parser.add_argument("--windows", default="2,3,4,5")
    parser.add_argument("--transitions", default="1,2,3")
    parser.add_argument("--clips", default=",".join(DEFAULT_CLIPS))
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--looking-down-pitch", type=float, default=-15.0)
    parser.add_argument("--looking-down-seconds", type=float, default=3.0)
    parser.add_argument("--ear-closed-threshold", type=float, default=0.12)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    windows = [float(value) for value in args.windows.split(",") if value]
    transitions = [int(value) for value in args.transitions.split(",") if value]
    clips = [value for value in args.clips.split(",") if value]

    print(
        "window,transitions,macro_visual_f1,total_actual_error,total_corrected_error,"
        "mixed_focused_f1,mixed_away_f1,mixed_looking_down_f1,mixed_talking_f1,mixed_eyes_closed_f1,"
        "mixed_actual_error,mixed_corrected_error"
    )
    for window in windows:
        for transition in transitions:
            metrics = evaluate_config(window, transition, clips, args)
            print(
                f"{window:.1f},{transition},"
                f"{metrics['macro_visual_f1']:.3f},"
                f"{metrics['total_actual_error']},"
                f"{metrics['total_corrected_error']},"
                f"{metrics['mixed_focused_f1']:.3f},"
                f"{metrics['mixed_away_f1']:.3f},"
                f"{metrics['mixed_looking_down_f1']:.3f},"
                f"{metrics['mixed_talking_f1']:.3f},"
                f"{metrics['mixed_eyes_closed_f1']:.3f},"
                f"{metrics['mixed_actual_error']},"
                f"{metrics['mixed_corrected_error']}"
            )
    return 0


def evaluate_config(window: float, transition: int, clips: list[str], args: argparse.Namespace) -> dict[str, float | int]:
    total_actual_error = 0
    total_corrected_error = 0
    supported_f1: list[float] = []
    mixed_metrics: dict[str, float | int] = {}

    for clip in clips:
        labels = load_labels(ROOT / "eval" / "labels" / f"{clip}.json")
        duration = int(labels["duration_seconds"])
        y_true = labels_to_seconds(labels, duration)
        actual_focus = actual_focus_to_seconds(labels, duration)
        detector_args = argparse.Namespace(
            fps=args.fps,
            window_seconds=window,
            transition_windows=transition,
            face_model=None,
            looking_down_pitch=args.looking_down_pitch,
            looking_down_seconds=args.looking_down_seconds,
            ear_closed_threshold=args.ear_closed_threshold,
        )
        predictions = run_detector(ROOT / "eval" / "recordings" / f"{clip}.mov", detector_args)
        y_pred = predictions_to_seconds(predictions, duration)
        state_metrics = precision_recall_f1(y_true, y_pred)

        total_actual_error += focused_time_error_from_focus_truth(actual_focus, y_pred)
        total_corrected_error += correction_adjusted_focused_time_error_seconds(actual_focus, y_pred)
        supported_f1.extend(metric.f1 for metric in state_metrics.values() if metric.support > 0)

        if clip == "mixed_session_01":
            mixed_metrics = {
                "mixed_focused_f1": state_metrics["focused"].f1,
                "mixed_away_f1": state_metrics["away"].f1,
                "mixed_looking_down_f1": state_metrics["looking_down"].f1,
                "mixed_talking_f1": state_metrics["talking"].f1,
                "mixed_eyes_closed_f1": state_metrics["eyes_closed"].f1,
                "mixed_actual_error": focused_time_error_from_focus_truth(actual_focus, y_pred),
                "mixed_corrected_error": correction_adjusted_focused_time_error_seconds(actual_focus, y_pred),
            }

    return {
        "macro_visual_f1": sum(supported_f1) / max(1, len(supported_f1)),
        "total_actual_error": total_actual_error,
        "total_corrected_error": total_corrected_error,
        **mixed_metrics,
    }


if __name__ == "__main__":
    raise SystemExit(main())
