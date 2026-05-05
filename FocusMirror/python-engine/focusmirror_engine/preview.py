from __future__ import annotations

from typing import Any

from .classifier import ClassifierConfig, FrameClassification
from .detector import FrameSignals
from .state_machine import StableClassification

STATE_COLORS = {
    "focused": (68, 170, 94),
    "away": (54, 54, 215),
    "looking_down": (40, 152, 230),
    "talking": (214, 112, 85),
    "eyes_closed": (164, 92, 170),
    "uncertain": (148, 148, 148),
}

FEATURE_CONNECTIONS = (
    (33, 133),   # left eye
    (362, 263),  # right eye
    (61, 291),   # mouth width
    (13, 14),    # mouth opening
    (1, 152),    # nose to chin
    (33, 263),   # eye line
    (10, 152),   # upper face to chin
)


def render_debug_frame(
    cv2: Any,
    frame_bgr: Any,
    *,
    signals: FrameSignals,
    frame_classification: FrameClassification,
    stable: StableClassification | None,
    config: ClassifierConfig,
    mirror: bool = True,
) -> bool:
    display = frame_bgr.copy()
    if mirror:
        display = cv2.flip(display, 1)

    height, width = display.shape[:2]
    color = STATE_COLORS.get(stable.state if stable else frame_classification.state, STATE_COLORS["uncertain"])

    _draw_landmarks(cv2, display, signals, mirror=mirror, width=width)
    _draw_top_state_label(cv2, display, frame_classification, stable, color)
    _draw_label_panel(cv2, display, signals, frame_classification, stable, color, config)

    cv2.imshow("FocusMirror CV Preview", display)
    key = cv2.waitKey(1) & 0xFF
    if key in (ord("q"), 27):
        return True
    try:
        return cv2.getWindowProperty("FocusMirror CV Preview", cv2.WND_PROP_VISIBLE) < 1
    except cv2.error:
        return False


def close_preview(cv2: Any) -> None:
    try:
        cv2.destroyWindow("FocusMirror CV Preview")
    except cv2.error:
        pass


def _draw_landmarks(cv2: Any, frame: Any, signals: FrameSignals, *, mirror: bool, width: int) -> None:
    if signals.landmarks is None:
        return

    points = signals.landmarks
    for point in points[::3]:
        x, y = _xy(point, mirror=mirror, width=width)
        cv2.circle(frame, (x, y), 1, (75, 190, 120), -1)

    for start, end in FEATURE_CONNECTIONS:
        if start >= len(points) or end >= len(points):
            continue
        x1, y1 = _xy(points[start], mirror=mirror, width=width)
        x2, y2 = _xy(points[end], mirror=mirror, width=width)
        cv2.line(frame, (x1, y1), (x2, y2), (0, 230, 255), 2)


def _draw_label_panel(
    cv2: Any,
    frame: Any,
    signals: FrameSignals,
    frame_classification: FrameClassification,
    stable: StableClassification | None,
    color: tuple[int, int, int],
    config: ClassifierConfig,
) -> None:
    stable_state = stable.state if stable else "warming_up"
    stable_confidence = stable.confidence if stable else 0.0
    lines = [
        f"stable: {stable_state} ({stable_confidence:.2f})",
        f"frame:  {frame_classification.state} ({frame_classification.confidence:.2f})",
        f"reason: {frame_classification.reason}",
        (
            "head pose: "
            f"pitch={_fmt(signals.pitch)} "
            f"(down <= {config.looking_down_pitch:.0f}) "
            f"yaw={_fmt(signals.yaw)} roll={_fmt(signals.roll)}"
        ),
        (
            "looking_down gate: "
            f"{config.looking_down_seconds:.0f}s, "
            f"{int(config.looking_down_ratio * 100)}% window, "
            f"yaw<{config.looking_down_max_yaw_degrees:.0f}, roll<{config.looking_down_max_roll_degrees:.0f}"
        ),
        "looking_down uses head pitch, not eye gaze",
        f"eyes/mouth: EAR={_fmt(signals.ear, 3)} MAR={_fmt(signals.mar, 3)} faces={signals.face_count}",
        "q or Esc: quit",
    ]

    panel_width = 520
    panel_height = 26 + len(lines) * 24
    cv2.rectangle(frame, (16, 16), (16 + panel_width, 16 + panel_height), (24, 26, 28), -1)
    cv2.rectangle(frame, (16, 16), (16 + panel_width, 16 + panel_height), color, 2)

    for index, line in enumerate(lines):
        y = 48 + index * 24
        text_color = color if index == 0 else (235, 235, 235)
        cv2.putText(frame, line, (30, y), cv2.FONT_HERSHEY_SIMPLEX, 0.58, text_color, 1, cv2.LINE_AA)


def _draw_top_state_label(
    cv2: Any,
    frame: Any,
    frame_classification: FrameClassification,
    stable: StableClassification | None,
    color: tuple[int, int, int],
) -> None:
    height, width = frame.shape[:2]
    stable_state = stable.state if stable else "warming_up"
    stable_confidence = stable.confidence if stable else 0.0
    title = stable_state.replace("_", " ").upper()
    subtitle = f"frame: {frame_classification.state.replace('_', ' ')}  |  stable confidence: {stable_confidence:.2f}"

    title_scale = max(1.4, min(2.6, width / 520.0))
    title_thickness = max(3, int(width / 260))
    subtitle_scale = max(0.58, min(0.95, width / 980.0))
    subtitle_thickness = 2

    title_size, _ = cv2.getTextSize(title, cv2.FONT_HERSHEY_SIMPLEX, title_scale, title_thickness)
    subtitle_size, _ = cv2.getTextSize(subtitle, cv2.FONT_HERSHEY_SIMPLEX, subtitle_scale, subtitle_thickness)

    panel_width = min(width - 32, max(title_size[0], subtitle_size[0]) + 64)
    panel_height = title_size[1] + subtitle_size[1] + 50
    left = int((width - panel_width) / 2)
    top = 16
    right = left + panel_width
    bottom = top + panel_height

    overlay = frame.copy()
    cv2.rectangle(overlay, (left, top), (right, bottom), (18, 20, 22), -1)
    cv2.addWeighted(overlay, 0.82, frame, 0.18, 0, frame)
    cv2.rectangle(frame, (left, top), (right, bottom), color, 4)

    title_x = int((width - title_size[0]) / 2)
    title_y = top + 18 + title_size[1]
    subtitle_x = int((width - subtitle_size[0]) / 2)
    subtitle_y = title_y + subtitle_size[1] + 20

    cv2.putText(frame, title, (title_x, title_y), cv2.FONT_HERSHEY_SIMPLEX, title_scale, color, title_thickness, cv2.LINE_AA)
    cv2.putText(frame, subtitle, (subtitle_x, subtitle_y), cv2.FONT_HERSHEY_SIMPLEX, subtitle_scale, (240, 240, 240), subtitle_thickness, cv2.LINE_AA)


def _xy(point: Any, *, mirror: bool, width: int) -> tuple[int, int]:
    x = int(point[0])
    y = int(point[1])
    if mirror:
        x = width - x
    return x, y


def _fmt(value: float | None, digits: int = 1) -> str:
    if value is None:
        return "n/a"
    return f"{value:.{digits}f}"
