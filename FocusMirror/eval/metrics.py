from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass
from typing import Iterable

STATES = ("focused", "away", "looking_down", "talking", "eyes_closed", "uncertain")


@dataclass
class StateMetric:
    precision: float
    recall: float
    f1: float
    support: int


def precision_recall_f1(y_true: list[str], y_pred: list[str], states: Iterable[str] = STATES) -> dict[str, StateMetric]:
    result: dict[str, StateMetric] = {}
    for state in states:
        tp = sum(1 for truth, pred in zip(y_true, y_pred) if truth == state and pred == state)
        fp = sum(1 for truth, pred in zip(y_true, y_pred) if truth != state and pred == state)
        fn = sum(1 for truth, pred in zip(y_true, y_pred) if truth == state and pred != state)
        precision = tp / (tp + fp) if tp + fp else 0.0
        recall = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        support = sum(1 for truth in y_true if truth == state)
        result[state] = StateMetric(precision, recall, f1, support)
    return result


def confusion_matrix(y_true: list[str], y_pred: list[str], states: Iterable[str] = STATES) -> dict[str, dict[str, int]]:
    state_list = list(states)
    matrix: dict[str, dict[str, int]] = {truth: {pred: 0 for pred in state_list} for truth in state_list}
    extras: defaultdict[str, Counter[str]] = defaultdict(Counter)
    for truth, pred in zip(y_true, y_pred):
        if truth in matrix and pred in matrix[truth]:
            matrix[truth][pred] += 1
        else:
            extras[truth][pred] += 1
    return matrix


def focused_time_error_seconds(y_true: list[str], y_pred: list[str]) -> int:
    actual = sum(1 for value in y_true if value == "focused")
    predicted = sum(1 for value in y_pred if value == "focused")
    return abs(predicted - actual)


def focused_time_error_from_focus_truth(actual_focus: list[bool | None], y_pred: list[str]) -> int:
    actual = sum(1 for value in actual_focus if value is True)
    predicted = sum(
        1 for truth, pred in zip(actual_focus, y_pred) if truth is not None and pred == "focused"
    )
    return abs(predicted - actual)


def correction_adjusted_focused_time_error_seconds(actual_focus: list[bool | None], y_pred: list[str]) -> int:
    actual = sum(1 for value in actual_focus if value is True)
    corrected_prediction = sum(
        1
        for truth, pred in zip(actual_focus, y_pred)
        if truth is not None and (pred == "focused" or truth is True)
    )
    return abs(corrected_prediction - actual)


def focused_binary_metric(actual_focus: list[bool | None], y_pred: list[str]) -> StateMetric:
    pairs = [(truth, pred == "focused") for truth, pred in zip(actual_focus, y_pred) if truth is not None]
    tp = sum(1 for truth, pred in pairs if truth is True and pred is True)
    fp = sum(1 for truth, pred in pairs if truth is False and pred is True)
    fn = sum(1 for truth, pred in pairs if truth is True and pred is False)
    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / (tp + fn) if tp + fn else 0.0
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
    support = sum(1 for truth, _pred in pairs if truth is True)
    return StateMetric(precision, recall, f1, support)
