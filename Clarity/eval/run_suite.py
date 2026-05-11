from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ROOT = ROOT / "python-engine"
sys.path.insert(0, str(ENGINE_ROOT))
sys.path.insert(0, str(ROOT / "eval"))

from metrics import (
    STATES,
    correction_adjusted_focused_time_error_seconds,
    focused_binary_metric,
    focused_time_error_from_focus_truth,
    focused_time_error_seconds,
    precision_recall_f1,
)
from run_eval import (
    actual_focus_to_seconds,
    labels_to_seconds,
    load_labels,
    predictions_to_seconds,
    run_detector,
    write_prediction_csv,
)
from eval_gate import run_gate


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run Clarity eval over all labeled local clips")
    parser.add_argument("--recordings-dir", type=Path, default=ROOT / "eval" / "recordings")
    parser.add_argument("--labels-dir", type=Path, default=ROOT / "eval" / "labels")
    parser.add_argument("--results-dir", type=Path, default=ROOT / "eval" / "results")
    parser.add_argument("--clips", default="", help="Optional comma-separated clip basenames")
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--window-seconds", type=float, default=3.0)
    parser.add_argument("--transition-windows", type=int, default=1)
    parser.add_argument("--face-model", default=None)
    parser.add_argument("--no-face-seconds", type=float, default=2.0)
    parser.add_argument("--looking-down-pitch", type=float, default=-13.0)
    parser.add_argument("--looking-down-seconds", type=float, default=2.0)
    parser.add_argument("--eyes-closed-seconds", type=float, default=2.0)
    parser.add_argument("--eyes-closed-ratio", type=float, default=0.6)
    parser.add_argument("--ear-closed-threshold", type=float, default=0.14)
    parser.add_argument("--gate", action="store_true", help="Fail if refreshed results regress past accepted thresholds")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    args.results_dir.mkdir(parents=True, exist_ok=True)

    clips = selected_clips(args)
    if not clips:
        raise SystemExit("No clips found")

    summary_rows = []
    for clip in clips:
        row = evaluate_clip(clip, args)
        summary_rows.append(row)
        print(
            f"{clip}: focused_f1={row['focused_f1']:.3f}, "
            f"looking_down_f1={row['looking_down_f1']:.3f}, "
            f"away_f1={row['away_f1']:.3f}, "
            f"eyes_closed_f1={row['eyes_closed_f1']:.3f}, "
            f"talking_f1={row['talking_f1']:.3f}, "
            f"visual_focused_error={row['visual_focused_error_seconds']}s, "
            f"actual_focused_error={row['actual_focused_error_seconds']}s, "
            f"corrected_error={row['correction_adjusted_focused_error_seconds']}s"
        )

    summary_path = args.results_dir / "summary.csv"
    write_summary(summary_path, summary_rows)

    if args.gate:
        failures = run_gate(summary_path, args.results_dir)
        if failures:
            print("FAIL eval gate")
            for failure in failures:
                print(f"- {failure}")
            return 1
        print("PASS eval gate")

    return 0


def selected_clips(args: argparse.Namespace) -> list[str]:
    if args.clips:
        return [clip.strip() for clip in args.clips.split(",") if clip.strip()]

    clips = []
    for label_path in sorted(args.labels_dir.glob("*.json")):
        if label_path.stem == "example_session":
            continue
        video_path = args.recordings_dir / f"{label_path.stem}.mov"
        if video_path.exists():
            clips.append(label_path.stem)
    return clips


def evaluate_clip(clip: str, args: argparse.Namespace) -> dict[str, float | int | str]:
    labels = load_labels(args.labels_dir / f"{clip}.json")
    duration = int(labels["duration_seconds"])
    y_true = labels_to_seconds(labels, duration)
    actual_focus = actual_focus_to_seconds(labels, duration)
    predictions = run_detector(args.recordings_dir / f"{clip}.mov", args)
    y_pred = predictions_to_seconds(predictions, duration)
    write_prediction_csv(args.results_dir / f"{clip}_predictions.csv", y_true, actual_focus, predictions, duration)

    metrics = precision_recall_f1(y_true, y_pred)
    visual_focused_error = focused_time_error_seconds(y_true, y_pred)
    actual_focused_error = focused_time_error_from_focus_truth(actual_focus, y_pred)
    correction_adjusted_error = correction_adjusted_focused_time_error_seconds(actual_focus, y_pred)
    actual_metric = focused_binary_metric(actual_focus, y_pred)
    known_actual_seconds = sum(1 for value in actual_focus if value is not None)
    row: dict[str, float | int | str] = {
        "clip": clip,
        "duration_seconds": duration,
        "visual_focused_error_seconds": visual_focused_error,
        "visual_focused_error_pct": visual_focused_error / max(1, duration),
        "actual_focused_error_seconds": actual_focused_error,
        "actual_focused_error_pct": actual_focused_error / max(1, known_actual_seconds),
        "correction_adjusted_focused_error_seconds": correction_adjusted_error,
        "correction_adjusted_focused_error_pct": correction_adjusted_error / max(1, known_actual_seconds),
        "actual_focused_precision": actual_metric.precision,
        "actual_focused_recall": actual_metric.recall,
        "actual_focused_f1": actual_metric.f1,
        "actual_focused_support_seconds": actual_metric.support,
        "actual_known_seconds": known_actual_seconds,
    }
    for state in STATES:
        row[f"{state}_precision"] = metrics[state].precision
        row[f"{state}_recall"] = metrics[state].recall
        row[f"{state}_f1"] = metrics[state].f1
        row[f"{state}_support_seconds"] = metrics[state].support
    return row


def write_summary(path: Path, rows: list[dict[str, float | int | str]]) -> None:
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    raise SystemExit(main())
