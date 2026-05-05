from __future__ import annotations

from collections import Counter, deque
from dataclasses import dataclass

from .classifier import FOCUSED, UNCERTAIN, FrameClassification


@dataclass
class StableClassification:
    state: str
    confidence: float
    changed: bool


class RollingStateMachine:
    """Majority vote plus transition debounce over classifier output."""

    def __init__(
        self,
        *,
        fps: int = 5,
        window_seconds: float = 5.0,
        transition_windows: int = 3,
        emit_interval_seconds: float = 1.0,
    ) -> None:
        self.fps = fps
        self.window_seconds = window_seconds
        self.transition_windows = transition_windows
        self.emit_interval_seconds = emit_interval_seconds
        self._window: deque[tuple[float, FrameClassification]] = deque(maxlen=max(1, int(fps * window_seconds)))
        self._committed_state = UNCERTAIN
        self._candidate_state: str | None = None
        self._candidate_count = 0
        self._last_emit_at: float | None = None

    def add(self, classification: FrameClassification, *, timestamp: float) -> StableClassification | None:
        self._window.append((timestamp, classification))
        if self._last_emit_at is not None and timestamp - self._last_emit_at < self.emit_interval_seconds:
            return None
        self._last_emit_at = timestamp

        window_values = [item for _, item in self._window]
        if not window_values:
            return StableClassification(self._committed_state, 0.0, False)

        candidate = self._majority_state(window_values)
        candidate_confidence = self._average_confidence(window_values, candidate)
        changed = False

        if candidate == self._committed_state:
            self._candidate_state = None
            self._candidate_count = 0
        else:
            if candidate == self._candidate_state:
                self._candidate_count += 1
            else:
                self._candidate_state = candidate
                self._candidate_count = 1
            if self._candidate_count >= self.transition_windows:
                self._committed_state = candidate
                self._candidate_state = None
                self._candidate_count = 0
                changed = True

        return StableClassification(self._committed_state, candidate_confidence, changed)

    @staticmethod
    def _majority_state(values: list[FrameClassification]) -> str:
        counts = Counter(value.state for value in values)
        if not counts:
            return UNCERTAIN
        state, count = counts.most_common(1)[0]
        if count / len(values) < 0.4:
            return UNCERTAIN
        return state or FOCUSED

    @staticmethod
    def _average_confidence(values: list[FrameClassification], state: str) -> float:
        confidences = [value.confidence for value in values if value.state == state]
        if not confidences:
            confidences = [value.confidence for value in values]
        return max(0.0, min(1.0, sum(confidences) / len(confidences)))
