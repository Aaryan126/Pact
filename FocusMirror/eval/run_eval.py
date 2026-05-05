from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ROOT = ROOT / "python-engine"
sys.path.insert(0, str(ENGINE_ROOT))

from focusmirror_engine.classifier import ClassifierConfig, FrameClassifier
from focusmirror_engine.detector import DependencyError, MediaPipeDetector
from focusmirror_engine.state_machine import RollingStateMachine

from metrics import STATES, confusion_matrix, focused_time_error_seconds, precision_recall_f1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run FocusMirror detector eval against labeled video")
    parser.add_argument("video", type=Path)
    parser.add_argument("labels", type=Path)
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--window-seconds", type=float, default=5.0)
    parser.add_argument("--transition-windows", type=int, default=3)
    parser.add_argument("--face-model", default=None, help="Path to MediaPipe Tasks face_landmarker.task model")
    parser.add_argument("--looking-down-pitch", type=float, default=-20.0)
    parser.add_argument("--looking-down-seconds", type=float, default=5.0)
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
    y_pred = predictions_to_seconds(predictions, duration)
    report(y_true, y_pred)
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
        for second in range(start, end):
            timeline[second] = segment["label"]
    return timeline


def predictions_to_seconds(predictions: list[tuple[float, str]], duration: int) -> list[str]:
    timeline = ["uncertain"] * duration
    if not predictions:
        return timeline
    predictions = sorted(predictions, key=lambda item: item[0])
    cursor = 0
    current = predictions[0][1]
    for elapsed, state in predictions:
        end = min(duration, max(cursor, int(round(elapsed))))
        for second in range(cursor, end):
            timeline[second] = current
        cursor = end
        current = state
    for second in range(cursor, duration):
        timeline[second] = current
    return timeline


def run_detector(video: Path, args: argparse.Namespace) -> list[tuple[float, str]]:
    import cv2

    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        raise RuntimeError(f"Could not open video: {video}")

    detector = MediaPipeDetector(max_num_faces=2, face_model_path=args.face_model)
    classifier = FrameClassifier(
        ClassifierConfig(
            fps=args.fps,
            looking_down_pitch=args.looking_down_pitch,
            looking_down_seconds=args.looking_down_seconds,
        )
    )
    state_machine = RollingStateMachine(
        fps=args.fps,
        window_seconds=args.window_seconds,
        transition_windows=args.transition_windows,
        emit_interval_seconds=1.0,
    )
    predictions: list[tuple[float, str]] = []

    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            elapsed = max(0.0, capture.get(cv2.CAP_PROP_POS_MSEC) / 1000.0)
            signals = detector.process(frame, timestamp=elapsed)
            frame_classification = classifier.classify(signals)
            stable = state_machine.add(frame_classification, timestamp=elapsed)
            if stable is not None:
                predictions.append((elapsed, stable.state))

            target_frame = int(elapsed * args.fps)
            capture.set(cv2.CAP_PROP_POS_MSEC, (target_frame + 1) * (1000.0 / args.fps))
    finally:
        detector.close()
        capture.release()

    return predictions


def report(y_true: list[str], y_pred: list[str]) -> None:
    metrics = precision_recall_f1(y_true, y_pred)
    print("Per-state metrics")
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
    print(f"\nFocused time error: {error}s ({error / duration:.2%} of session)")


if __name__ == "__main__":
    raise SystemExit(main())
