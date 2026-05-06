from __future__ import annotations

import argparse
import signal
import sys
import time
from pathlib import Path

from .classifier import ClassifierConfig, FrameClassifier
from .detector import DependencyError, MediaPipeDetector, signals_to_raw
from .ipc import emit_error, emit_json_line, make_event
from .preview import close_preview, render_debug_frame
from .state_machine import RollingStateMachine


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="FocusMirror local detection engine")
    parser.add_argument("--source", default="webcam", help="'webcam' or a path to a recorded video")
    parser.add_argument("--camera-index", type=int, default=0)
    parser.add_argument("--fps", type=int, default=5)
    parser.add_argument("--window-seconds", type=float, default=3.0)
    parser.add_argument("--transition-windows", type=int, default=1)
    parser.add_argument("--max-seconds", type=float, default=None, help="Optional debug/eval stop time")
    parser.add_argument("--face-model", default=None, help="Path to MediaPipe Tasks face_landmarker.task model")
    parser.add_argument("--looking-down-pitch", type=float, default=-15.0, help="Pitch threshold for sustained head-down detection")
    parser.add_argument("--looking-down-seconds", type=float, default=3.0, help="Seconds required for head-down detection")
    parser.add_argument("--ear-closed-threshold", type=float, default=0.12, help="EAR threshold below which eyes count as closed")
    parser.add_argument("--preview", action="store_true", help="Show live camera/video overlay for CV debugging")
    parser.add_argument("--no-json", action="store_true", help="Suppress JSON classification output")
    parser.add_argument("--no-mirror-preview", action="store_true", help="Do not mirror the preview window")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    stop = False

    def handle_stop(_signum: int, _frame: object) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)

    try:
        return run(args, should_stop=lambda: stop)
    except DependencyError as exc:
        emit_error(str(exc), code="missing_dependency")
        return 2
    except Exception as exc:  # pragma: no cover - top-level guard
        emit_error(str(exc))
        return 1


def run(args: argparse.Namespace, *, should_stop: callable = lambda: False) -> int:
    import cv2

    source = args.camera_index if args.source == "webcam" else str(Path(args.source).expanduser())
    capture = cv2.VideoCapture(source)
    if not capture.isOpened():
        emit_error(f"Could not open video source: {args.source}", code="source_open_failed")
        return 1

    detector = MediaPipeDetector(max_num_faces=2, face_model_path=args.face_model)
    classifier_config = ClassifierConfig(
        fps=args.fps,
        looking_down_pitch=args.looking_down_pitch,
        looking_down_seconds=args.looking_down_seconds,
        ear_closed_threshold=args.ear_closed_threshold,
    )
    classifier = FrameClassifier(classifier_config)
    state_machine = RollingStateMachine(
        fps=args.fps,
        window_seconds=args.window_seconds,
        transition_windows=args.transition_windows,
        emit_interval_seconds=1.0,
    )

    start_monotonic = time.monotonic()
    next_frame_at = start_monotonic
    is_webcam = args.source == "webcam"
    last_stable = None

    try:
        while not should_stop():
            now = time.monotonic()
            if is_webcam and now < next_frame_at:
                time.sleep(min(0.05, next_frame_at - now))
                continue

            ok, frame = capture.read()
            if not ok:
                break

            if is_webcam:
                elapsed = time.monotonic() - start_monotonic
                next_frame_at = time.monotonic() + (1.0 / args.fps)
            else:
                elapsed = max(0.0, capture.get(cv2.CAP_PROP_POS_MSEC) / 1000.0)
                target_frame = int(elapsed * args.fps)
                next_target_ms = (target_frame + 1) * (1000.0 / args.fps)
                capture.set(cv2.CAP_PROP_POS_MSEC, next_target_ms)

            if args.max_seconds is not None and elapsed > args.max_seconds:
                break

            signals = detector.process(frame, timestamp=elapsed)
            frame_classification = classifier.classify(signals)
            stable = state_machine.add(frame_classification, timestamp=elapsed)
            if stable is not None:
                last_stable = stable

            if args.preview:
                should_quit = render_debug_frame(
                    cv2,
                    frame,
                    signals=signals,
                    frame_classification=frame_classification,
                    stable=last_stable,
                    config=classifier_config,
                    mirror=not args.no_mirror_preview,
                )
                if should_quit:
                    break

            if stable is None or args.no_json:
                continue

            emit_json_line(
                make_event(
                    elapsed_seconds=elapsed,
                    state=stable.state,
                    confidence=stable.confidence,
                    raw={
                        **signals_to_raw(signals),
                        "frame_state": frame_classification.state,
                        "reason": frame_classification.reason,
                        "changed": stable.changed,
                    },
                )
            )
    finally:
        detector.close()
        capture.release()
        if args.preview:
            close_preview(cv2)

    return 0


if __name__ == "__main__":
    sys.exit(main())
