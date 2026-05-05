from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from statistics import variance

from .detector import FrameSignals

FOCUSED = "focused"
AWAY = "away"
LOOKING_DOWN = "looking_down"
TALKING = "talking"
EYES_CLOSED = "eyes_closed"
UNCERTAIN = "uncertain"

STATES = (FOCUSED, AWAY, LOOKING_DOWN, TALKING, EYES_CLOSED, UNCERTAIN)


@dataclass
class ClassifierConfig:
    fps: int = 5
    no_face_seconds: float = 5.0
    looking_down_pitch: float = -20.0
    looking_down_seconds: float = 5.0
    looking_down_ratio: float = 0.85
    looking_down_max_yaw_degrees: float = 35.0
    looking_down_max_roll_degrees: float = 25.0
    screen_yaw_degrees: float = 25.0
    screen_pitch_degrees: float = 20.0
    talking_yaw_degrees: float = 30.0
    mouth_variance_window_seconds: float = 3.0
    mouth_variance_threshold: float = 0.005
    eyes_closed_seconds: float = 3.0
    ear_closed_threshold: float = 0.20
    minimum_confidence: float = 0.5


@dataclass
class FrameClassification:
    state: str
    confidence: float
    reason: str


class FrameClassifier:
    """Classifies one processed frame using rolling signal history."""

    def __init__(self, config: ClassifierConfig | None = None) -> None:
        self.config = config or ClassifierConfig()
        max_seconds = max(
            self.config.no_face_seconds,
            self.config.looking_down_seconds,
            self.config.mouth_variance_window_seconds,
            self.config.eyes_closed_seconds,
        ) + 2.0
        self._history: deque[FrameSignals] = deque(maxlen=max(1, int(max_seconds * self.config.fps)))
        self._no_face_since: float | None = None

    def classify(self, signals: FrameSignals) -> FrameClassification:
        self._history.append(signals)
        config = self.config

        if signals.face_count == 0:
            if self._no_face_since is None:
                self._no_face_since = signals.timestamp
            elapsed = signals.timestamp - self._no_face_since
            if elapsed >= config.no_face_seconds:
                return FrameClassification(AWAY, 0.95, "no_face_sustained")
            return FrameClassification(UNCERTAIN, 0.55, "face_temporarily_missing")

        self._no_face_since = None

        if signals.confidence < config.minimum_confidence or not signals.landmarks_ok:
            return FrameClassification(UNCERTAIN, 0.5, "low_landmark_confidence")

        if self._is_sustained_looking_down(signals.timestamp):
            return FrameClassification(LOOKING_DOWN, 0.86, "pitch_down_sustained")

        if self._is_talking(signals):
            return FrameClassification(TALKING, 0.75, "mouth_motion_with_social_context")

        if self._is_sustained_eyes_closed(signals.timestamp):
            return FrameClassification(EYES_CLOSED, 0.82, "ear_closed_sustained")

        if _is_oriented_to_screen(signals, config) and signals.ear is not None and signals.ear > config.ear_closed_threshold:
            return FrameClassification(FOCUSED, 0.8, "screen_oriented_eyes_open")

        return FrameClassification(UNCERTAIN, 0.55, "ambiguous_pose_or_eye_state")

    def _recent(self, now: float, seconds: float) -> list[FrameSignals]:
        earliest = now - seconds
        return [signals for signals in self._history if signals.timestamp >= earliest]

    def _is_sustained_looking_down(self, now: float) -> bool:
        config = self.config
        recent = [
            s
            for s in self._recent(now, config.looking_down_seconds)
            if s.face_count > 0 and s.pitch is not None and s.yaw is not None and s.roll is not None
        ]
        expected = max(1, int(config.looking_down_seconds * config.fps * 0.75))
        if len(recent) < expected:
            return False
        down = [
            s
            for s in recent
            if s.pitch is not None
            and s.yaw is not None
            and s.roll is not None
            and s.pitch < config.looking_down_pitch
            and abs(s.yaw) < config.looking_down_max_yaw_degrees
            and abs(s.roll) < config.looking_down_max_roll_degrees
        ]
        return len(down) / len(recent) >= config.looking_down_ratio

    def _is_sustained_eyes_closed(self, now: float) -> bool:
        config = self.config
        recent = [s for s in self._recent(now, config.eyes_closed_seconds) if s.face_count > 0 and s.ear is not None]
        expected = max(1, int(config.eyes_closed_seconds * config.fps * 0.6))
        if len(recent) < expected:
            return False
        closed = [
            s
            for s in recent
            if s.ear is not None
            and s.ear < config.ear_closed_threshold
            and _is_oriented_to_screen(s, config)
        ]
        return len(closed) / len(recent) >= 0.7

    def _is_talking(self, signals: FrameSignals) -> bool:
        config = self.config
        if signals.mar is None:
            return False
        recent = [s for s in self._recent(signals.timestamp, config.mouth_variance_window_seconds) if s.mar is not None]
        expected = max(3, int(config.mouth_variance_window_seconds * config.fps * 0.6))
        if len(recent) < expected:
            return False
        mar_values = [float(s.mar) for s in recent if s.mar is not None]
        if len(mar_values) < 3:
            return False
        mouth_moving = variance(mar_values) > config.mouth_variance_threshold
        social_context = signals.face_count > 1 or (
            signals.yaw is not None and abs(signals.yaw) > config.talking_yaw_degrees
        )
        return mouth_moving and social_context


def _is_oriented_to_screen(signals: FrameSignals, config: ClassifierConfig) -> bool:
    if signals.pitch is None or signals.yaw is None:
        return False
    return abs(signals.yaw) < config.screen_yaw_degrees and abs(signals.pitch) < config.screen_pitch_degrees
