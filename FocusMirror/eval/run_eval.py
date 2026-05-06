from __future__ import annotations

import argparse
import csv
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ROOT = ROOT / "python-engine"
sys.path.insert(0, str(ENGINE_ROOT))

from focusmirror_engine.classifier import ClassifierConfig, FrameClassifier
from focusmirror_engine.detector import DependencyError, MediaPipeDetector, signals_to_raw
from focusmirror_engine.state_machine import RollingStateMachine

from metrics import (
    STATES,
    confusion_matrix,
    correction_adjusted_focused_time_error_seconds,
    focused_binary_metric,
    focused_time_error_from_focus_truth,
    focused_time_error_seconds,
    precision_recall_f1,
)


@dataclass
class PredictionPoint:
    elapsed: float
    stable_state: str
    stable_confidence: float
    frame_state: str
    frame_confidence: float
    reason: str
    raw: dict[str, Any]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run FocusMirror detector eval against labeled video")
    parser.add_argument("video", type=Path)
    parser.add_argument("labels", type=Path)
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--window-seconds", type=float, default=3.0)
    parser.add_argument("--transition-windows", type=int, default=1)
    parser.add_argument("--face-model", default=None, help="Path to MediaPipe Tasks face_landmarker.task model")
    parser.add_argument("--looking-down-pitch", type=float, default=-15.0)
    parser.add_argument("--looking-down-seconds", type=float, default=3.0)
    parser.add_argument("--ear-closed-threshold", type=float, default=0.12)
    parser.add_argument("--csv", type=Path, default=None, help="Write per-second truth/prediction timeline CSV")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    labels = load_labels(args.labels)
    try:
        predictions = run_detector(args.video, args)
    except DependencyError as exc:
        print(f"Missing dependency: {exc}", file=sys.stderr)
        return 2

    duration = int(labels["duration_seconds"])
    y_true = labels_to_seconds(labels, duration)
    actual_focus = actual_focus_to_seconds(labels, duration)
    y_pred = predictions_to_seconds(predictions, duration)
    if args.csv is not None:
        write_prediction_csv(args.csv, y_true, actual_focus, predictions, duration)
    report(y_true, actual_focus, y_pred)
    return 0


def load_labels(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if "segments" not in data or "duration_seconds" not in data:
        raise ValueError("Label file must contain duration_seconds and segments")
    return data


def labels_to_seconds(labels: dict, duration: int) -> list[str]:
    timeline = ["uncertain"] * duration
    for segment in labels["segments"]:
        start = max(0, int(segment["start"]))
        end = min(duration, int(segment["end"]))
        label = segment.get("visual_state", segment.get("label", "uncertain"))
        for second in range(start, end):
            timeline[second] = label
    return timeline


def actual_focus_to_seconds(labels: dict, duration: int) -> list[bool | None]:
    timeline: list[bool | None] = [None] * duration
    for segment in labels["segments"]:
        start = max(0, int(segment["start"]))
        end = min(duration, int(segment["end"]))
        label = segment.get("visual_state", segment.get("label", "uncertain"))
        actual_focus = _parse_actual_focus(segment.get("actual_focus"), label)
        for second in range(start, end):
            timeline[second] = actual_focus
    return timeline


def _parse_actual_focus(value: object, visual_state: str) -> bool | None:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.lower()
        if normalized == "true":
            return True
        if normalized == "false":
            return False
        if normalized == "unknown":
            return None
    if value is None:
        if visual_state == "focused":
            return True
        if visual_state == "uncertain":
            return None
        return False
    raise ValueError(f"Unsupported actual_focus value: {value!r}")


def predictions_to_seconds(predictions: list[PredictionPoint], duration: int) -> list[str]:
    timeline = ["uncertain"] * duration
    if not predictions:
        return timeline
    predictions = sorted(predictions, key=lambda item: item.elapsed)
    cursor = 0
    current = predictions[0].stable_state
    for point in predictions:
        end = min(duration, max(cursor, int(round(point.elapsed))))
        for second in range(cursor, end):
            timeline[second] = current
        cursor = end
        current = point.stable_state
    for second in range(cursor, duration):
        timeline[second] = current
    return timeline


def run_detector(video: Path, args: argparse.Namespace) -> list[PredictionPoint]:
    import cv2

    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        raise RuntimeError(f"Could not open video: {video}")
    source_fps = capture.get(cv2.CAP_PROP_FPS) or 30.0

    detector = MediaPipeDetector(max_num_faces=2, face_model_path=args.face_model)
    classifier = FrameClassifier(
        ClassifierConfig(
            fps=args.fps,
            looking_down_pitch=args.looking_down_pitch,
            looking_down_seconds=args.looking_down_seconds,
            ear_closed_threshold=args.ear_closed_threshold,
        )
    )
    state_machine = RollingStateMachine(
        fps=args.fps,
        window_seconds=args.window_seconds,
        transition_windows=args.transition_windows,
        emit_interval_seconds=1.0,
    )
    predictions: list[PredictionPoint] = []
    next_process_at = 0.0
    frame_index = 0

    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            elapsed = frame_index / source_fps
            frame_index += 1
            if elapsed + 1e-6 < next_process_at:
                continue
            next_process_at += 1.0 / args.fps

            signals = detector.process(frame, timestamp=elapsed)
            frame_classification = classifier.classify(signals)
            stable = state_machine.add(frame_classification, timestamp=elapsed)
            if stable is not None:
                predictions.append(
                    PredictionPoint(
                        elapsed=elapsed,
                        stable_state=stable.state,
                        stable_confidence=stable.confidence,
                        frame_state=frame_classification.state,
                        frame_confidence=frame_classification.confidence,
                        reason=frame_classification.reason,
                        raw=signals_to_raw(signals),
                    )
                )
    finally:
        detector.close()
        capture.release()

    return predictions


def write_prediction_csv(
    path: Path,
    y_true: list[str],
    actual_focus: list[bool | None],
    predictions: list[PredictionPoint],
    duration: int,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    points = sorted(predictions, key=lambda item: item.elapsed)
    rows = prediction_rows(points, duration)

    fieldnames = [
        "second",
        "visual_truth",
        "truth",
        "actual_focus",
        "predicted",
        "stable_confidence",
        "frame_state",
        "frame_confidence",
        "reason",
        "face_count",
        "pitch",
        "yaw",
        "roll",
        "ear",
        "mar",
        "pose_ok",
        "landmarks_ok",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for second in range(duration):
            point = rows[second]
            raw = point.raw if point is not None else {}
            writer.writerow(
                {
                    "second": second,
                    "visual_truth": y_true[second] if second < len(y_true) else "uncertain",
                    "truth": y_true[second] if second < len(y_true) else "uncertain",
                    "actual_focus": _csv_actual_focus(
                        actual_focus[second] if second < len(actual_focus) else None
                    ),
                    "predicted": point.stable_state if point is not None else "uncertain",
                    "stable_confidence": _csv_float(point.stable_confidence if point is not None else None),
                    "frame_state": point.frame_state if point is not None else "",
                    "frame_confidence": _csv_float(point.frame_confidence if point is not None else None),
                    "reason": point.reason if point is not None else "no_prediction",
                    "face_count": raw.get("face_count", ""),
                    "pitch": _csv_float(raw.get("pitch")),
                    "yaw": _csv_float(raw.get("yaw")),
                    "roll": _csv_float(raw.get("roll")),
                    "ear": _csv_float(raw.get("ear")),
                    "mar": _csv_float(raw.get("mar")),
                    "pose_ok": raw.get("pose_ok", ""),
                    "landmarks_ok": raw.get("landmarks_ok", ""),
                }
            )


def prediction_rows(predictions: list[PredictionPoint], duration: int) -> list[PredictionPoint | None]:
    rows: list[PredictionPoint | None] = [None] * duration
    if not predictions:
        return rows
    cursor = 0
    current = predictions[0]
    for point in predictions:
        end = min(duration, max(cursor, int(round(point.elapsed))))
        for second in range(cursor, end):
            rows[second] = current
        cursor = end
        current = point
    for second in range(cursor, duration):
        rows[second] = current
    return rows


def _csv_float(value: Any) -> str:
    if value is None or value == "":
        return ""
    return f"{float(value):.4f}"


def _csv_actual_focus(value: bool | None) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    return "unknown"


def report(y_true: list[str], actual_focus: list[bool | None], y_pred: list[str]) -> None:
    metrics = precision_recall_f1(y_true, y_pred)
    print("Visual-state metrics")
    print("state,precision,recall,f1,support_seconds")
    for state in STATES:
        metric = metrics[state]
        print(f"{state},{metric.precision:.3f},{metric.recall:.3f},{metric.f1:.3f},{metric.support}")

    print("\nConfusion matrix")
    matrix = confusion_matrix(y_true, y_pred)
    print("," + ",".join(STATES))
    for truth in STATES:
        values = ",".join(str(matrix[truth][pred]) for pred in STATES)
        print(f"{truth},{values}")

    error = focused_time_error_seconds(y_true, y_pred)
    duration = max(1, len(y_true))
    print(f"\nVisual focused-state time error: {error}s ({error / duration:.2%} of session)")

    known_focus_seconds = sum(1 for value in actual_focus if value is not None)
    actual_error = focused_time_error_from_focus_truth(actual_focus, y_pred)
    corrected_error = correction_adjusted_focused_time_error_seconds(actual_focus, y_pred)
    binary = focused_binary_metric(actual_focus, y_pred)
    denominator = max(1, known_focus_seconds)
    print("\nActual focused-time metrics")
    print("precision,recall,f1,support_seconds,focused_time_error_seconds,correction_adjusted_error_seconds,known_seconds")
    print(
        f"{binary.precision:.3f},{binary.recall:.3f},{binary.f1:.3f},"
        f"{binary.support},{actual_error},{corrected_error},{known_focus_seconds}"
    )
    print(f"Actual focused-time error: {actual_error}s ({actual_error / denominator:.2%} of known labeled time)")
    print(
        "Correction-adjusted focused-time error: "
        f"{corrected_error}s ({corrected_error / denominator:.2%} of known labeled time)"
    )


if __name__ == "__main__":
    raise SystemExit(main())
