from __future__ import annotations

import math
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

cv2: Any | None = None
mp: Any | None = None
_BaseOptions: Any | None = None
_vision: Any | None = None


@dataclass
class FrameSignals:
    timestamp: float
    face_count: int
    confidence: float
    pitch: float | None = None
    yaw: float | None = None
    roll: float | None = None
    ear: float | None = None
    mar: float | None = None
    pose_ok: bool = False
    landmarks_ok: bool = False
    landmarks: np.ndarray | None = None


class DependencyError(RuntimeError):
    pass


class MediaPipeDetector:
    """MediaPipe Face Mesh wrapper that extracts FocusMirror's v1 signals."""

    def __init__(
        self,
        *,
        max_num_faces: int = 2,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
        face_model_path: str | None = None,
    ) -> None:
        _load_dependencies()

        self._mode = "legacy" if hasattr(mp, "solutions") else "tasks"
        self._face_mesh = None
        self._face_landmarker = None

        if self._mode == "legacy":
            self._face_mesh = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=max_num_faces,
                refine_landmarks=True,
                min_detection_confidence=min_detection_confidence,
                min_tracking_confidence=min_tracking_confidence,
            )
            return

        model_path = _resolve_face_model_path(face_model_path)
        if model_path is None:
            raise DependencyError(
                "This MediaPipe install exposes the newer Tasks API, not "
                "mediapipe.solutions.face_mesh. Download face_landmarker.task "
                "to python-engine/models/face_landmarker.task or pass "
                "--face-model /path/to/face_landmarker.task."
            )
        options = _vision.FaceLandmarkerOptions(
            base_options=_BaseOptions(
                model_asset_path=str(model_path),
                delegate=_BaseOptions.Delegate.CPU,
            ),
            running_mode=_vision.RunningMode.VIDEO,
            num_faces=max_num_faces,
            min_face_detection_confidence=min_detection_confidence,
            min_face_presence_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )
        self._face_landmarker = _vision.FaceLandmarker.create_from_options(options)

    def close(self) -> None:
        if self._face_mesh is not None:
            self._face_mesh.close()
        if self._face_landmarker is not None:
            self._face_landmarker.close()

    def process(self, frame_bgr: np.ndarray, *, timestamp: float) -> FrameSignals:
        height, width = frame_bgr.shape[:2]
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        if self._mode == "tasks":
            return self._process_tasks(frame_rgb, width=width, height=height, timestamp=timestamp)
        return self._process_legacy(frame_rgb, width=width, height=height, timestamp=timestamp)

    def _process_legacy(self, frame_rgb: np.ndarray, *, width: int, height: int, timestamp: float) -> FrameSignals:
        frame_rgb.flags.writeable = False
        result = self._face_mesh.process(frame_rgb)
        faces = result.multi_face_landmarks or []
        face_count = len(faces)

        if face_count == 0:
            return FrameSignals(
                timestamp=timestamp,
                face_count=0,
                confidence=1.0,
                landmarks_ok=False,
            )

        landmarks = faces[0].landmark
        points = np.array([(lm.x * width, lm.y * height, lm.z) for lm in landmarks])
        ear = _average_ear(points)
        mar = _mouth_aspect_ratio(points)
        pose = _estimate_head_pose(points, width=width, height=height)

        return FrameSignals(
            timestamp=timestamp,
            face_count=face_count,
            confidence=0.95 if pose is not None and ear is not None and mar is not None else 0.55,
            pitch=pose["pitch"] if pose else None,
            yaw=pose["yaw"] if pose else None,
            roll=pose["roll"] if pose else None,
            ear=ear,
            mar=mar,
            pose_ok=pose is not None,
            landmarks_ok=True,
            landmarks=points,
        )

    def _process_tasks(self, frame_rgb: np.ndarray, *, width: int, height: int, timestamp: float) -> FrameSignals:
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
        result = self._face_landmarker.detect_for_video(image, int(timestamp * 1000))
        faces = result.face_landmarks or []
        face_count = len(faces)

        if face_count == 0:
            return FrameSignals(
                timestamp=timestamp,
                face_count=0,
                confidence=1.0,
                landmarks_ok=False,
            )

        landmarks = faces[0]
        points = np.array([(lm.x * width, lm.y * height, lm.z) for lm in landmarks])
        ear = _average_ear(points)
        mar = _mouth_aspect_ratio(points)
        pose = _estimate_head_pose(points, width=width, height=height)

        return FrameSignals(
            timestamp=timestamp,
            face_count=face_count,
            confidence=0.95 if pose is not None and ear is not None and mar is not None else 0.55,
            pitch=pose["pitch"] if pose else None,
            yaw=pose["yaw"] if pose else None,
            roll=pose["roll"] if pose else None,
            ear=ear,
            mar=mar,
            pose_ok=pose is not None,
            landmarks_ok=True,
            landmarks=points,
        )


def _distance(points: np.ndarray, a: int, b: int) -> float:
    pa = points[a][:2]
    pb = points[b][:2]
    return float(np.linalg.norm(pa - pb))


def _eye_aspect_ratio(points: np.ndarray, indices: tuple[int, int, int, int, int, int]) -> float | None:
    p1, p2, p3, p4, p5, p6 = indices
    horizontal = _distance(points, p1, p4)
    if horizontal <= 1e-6:
        return None
    vertical = _distance(points, p2, p6) + _distance(points, p3, p5)
    return vertical / (2.0 * horizontal)


def _average_ear(points: np.ndarray) -> float | None:
    left = _eye_aspect_ratio(points, (33, 160, 158, 133, 153, 144))
    right = _eye_aspect_ratio(points, (362, 385, 387, 263, 373, 380))
    values = [value for value in (left, right) if value is not None and math.isfinite(value)]
    if not values:
        return None
    return float(sum(values) / len(values))


def _mouth_aspect_ratio(points: np.ndarray) -> float | None:
    horizontal = _distance(points, 61, 291)
    if horizontal <= 1e-6:
        return None
    vertical = _distance(points, 13, 14)
    return float(vertical / horizontal)


def _estimate_head_pose(points: np.ndarray, *, width: int, height: int) -> dict[str, float] | None:
    image_points = np.array(
        [
            points[1][:2],    # nose tip
            points[152][:2],  # chin
            points[33][:2],   # left eye outer
            points[263][:2],  # right eye outer
            points[61][:2],   # mouth left
            points[291][:2],  # mouth right
        ],
        dtype=np.float64,
    )
    model_points = np.array(
        [
            (0.0, 0.0, 0.0),
            (0.0, -63.6, -12.5),
            (-43.3, 32.7, -26.0),
            (43.3, 32.7, -26.0),
            (-28.9, -28.9, -24.1),
            (28.9, -28.9, -24.1),
        ],
        dtype=np.float64,
    )
    focal_length = float(width)
    camera_matrix = np.array(
        [[focal_length, 0.0, width / 2.0], [0.0, focal_length, height / 2.0], [0.0, 0.0, 1.0]],
        dtype=np.float64,
    )
    dist_coeffs = np.zeros((4, 1), dtype=np.float64)
    ok, rotation_vector, translation_vector = cv2.solvePnP(
        model_points,
        image_points,
        camera_matrix,
        dist_coeffs,
        flags=cv2.SOLVEPNP_ITERATIVE,
    )
    if not ok:
        return None

    rotation_matrix, _ = cv2.Rodrigues(rotation_vector)
    projection = np.hstack((rotation_matrix, translation_vector))
    _, _, _, _, _, _, euler = cv2.decomposeProjectionMatrix(projection)
    pitch = _normalize_pose_angle(float(euler[0][0]))
    yaw = _normalize_pose_angle(float(euler[1][0]))
    roll = _normalize_pose_angle(float(euler[2][0]))

    return {
        # FocusMirror convention: negative pitch means head tilted down.
        "pitch": pitch,
        "yaw": yaw,
        "roll": roll,
    }


def _normalize_pose_angle(angle: float) -> float:
    while angle > 180.0:
        angle -= 360.0
    while angle < -180.0:
        angle += 360.0
    if angle > 90.0:
        return 180.0 - angle
    if angle < -90.0:
        return -180.0 - angle
    return angle


def signals_to_raw(signals: FrameSignals) -> dict[str, Any]:
    return {
        "face_count": signals.face_count,
        "confidence": round(signals.confidence, 4),
        "pitch": _round_optional(signals.pitch),
        "yaw": _round_optional(signals.yaw),
        "roll": _round_optional(signals.roll),
        "ear": _round_optional(signals.ear),
        "mar": _round_optional(signals.mar),
        "pose_ok": signals.pose_ok,
        "landmarks_ok": signals.landmarks_ok,
    }


def _round_optional(value: float | None) -> float | None:
    return None if value is None else round(float(value), 4)


def _load_dependencies() -> None:
    global cv2, mp, _BaseOptions, _vision
    if cv2 is not None and mp is not None:
        return
    matplotlib_config_dir = Path(tempfile.gettempdir()) / "focusmirror-matplotlib"
    matplotlib_config_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("MPLCONFIGDIR", str(matplotlib_config_dir))
    try:
        import cv2 as imported_cv2
    except ImportError as exc:  # pragma: no cover - exercised in dependency setup
        raise DependencyError(f"opencv-python is required: {exc}") from exc
    try:
        import mediapipe as imported_mp
    except ImportError as exc:  # pragma: no cover - exercised in dependency setup
        raise DependencyError(f"mediapipe is required: {exc}") from exc
    cv2 = imported_cv2
    mp = imported_mp
    if not hasattr(mp, "solutions"):
        try:
            from mediapipe.tasks import python as imported_tasks_python
            from mediapipe.tasks.python import vision as imported_vision
        except ImportError as exc:  # pragma: no cover - exercised in dependency setup
            raise DependencyError(
                "mediapipe has neither the legacy solutions API nor the Tasks vision API."
            ) from exc
        _BaseOptions = imported_tasks_python.BaseOptions
        _vision = imported_vision


def _resolve_face_model_path(face_model_path: str | None) -> Path | None:
    candidates: list[Path] = []
    if face_model_path:
        candidates.append(Path(face_model_path).expanduser())
    if env_path := os.environ.get("FOCUSMIRROR_FACE_MODEL"):
        candidates.append(Path(env_path).expanduser())
    engine_root = Path(__file__).resolve().parents[1]
    candidates.extend(
        [
            engine_root / "models" / "face_landmarker.task",
            Path.cwd() / "models" / "face_landmarker.task",
        ]
    )
    return next((path for path in candidates if path.is_file()), None)
