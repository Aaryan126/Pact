from __future__ import annotations

import argparse
import csv
import operator
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULTS_DIR = ROOT / "eval" / "results"
DEFAULT_SUMMARY = DEFAULT_RESULTS_DIR / "summary.csv"


Compare = Callable[[float, float], bool]


@dataclass(frozen=True)
class SummaryGate:
    clip: str
    metric: str
    op_label: str
    threshold: float
    why: str


@dataclass(frozen=True)
class PredictionCountGate:
    clip: str
    state: str
    op_label: str
    threshold: int
    why: str


OPS: dict[str, Compare] = {
    ">=": operator.ge,
    "<=": operator.le,
}


SUMMARY_GATES: tuple[SummaryGate, ...] = (
    SummaryGate("focused_low_angle_01", "focused_f1", ">=", 0.98, "low-angle focused should stay focused"),
    SummaryGate("focused_low_angle_01", "actual_focused_error_seconds", "<=", 1, "low-angle focused-time count"),
    SummaryGate("focused_screen_01", "focused_f1", ">=", 0.88, "baseline focused screen clip"),
    SummaryGate("focused_screen_01", "actual_focused_error_seconds", "<=", 18, "baseline focused-time count"),
    SummaryGate("away_01", "away_f1", ">=", 0.85, "away state should remain reliable"),
    SummaryGate("away_01", "actual_focused_error_seconds", "<=", 6, "away clip focused-time count"),
    SummaryGate("eyes_closed_01", "eyes_closed_f1", ">=", 0.50, "eyes-closed standalone clip"),
    SummaryGate("eyes_closed_01", "correction_adjusted_focused_error_seconds", "<=", 3, "eyes-closed corrected focus count"),
    SummaryGate("looking_down_phone_01", "looking_down_f1", ">=", 0.65, "phone-like head-down detection"),
    SummaryGate("looking_down_phone_01", "actual_focused_error_seconds", "<=", 8, "phone-like focused-time count"),
    SummaryGate("looking_down_reading_01", "looking_down_f1", ">=", 0.80, "head-down reading visual label"),
    SummaryGate(
        "looking_down_reading_01",
        "correction_adjusted_focused_error_seconds",
        "<=",
        1,
        "reading correction should recover focused time",
    ),
    SummaryGate(
        "looking_down_reading_02",
        "correction_adjusted_focused_error_seconds",
        "<=",
        1,
        "boundary reading clip should remain correctable",
    ),
    SummaryGate("looking_down_reading_02", "visual_focused_error_seconds", "<=", 20, "boundary reading visual drift"),
    SummaryGate("mouth_false_positive_01", "focused_f1", ">=", 0.88, "mouth movement should mostly stay focused"),
    SummaryGate("mouth_false_positive_01", "actual_focused_error_seconds", "<=", 8, "mouth false-positive focused-time count"),
    SummaryGate("mouth_false_positive_02", "focused_f1", ">=", 0.98, "new mouth false-positive clip"),
    SummaryGate("mouth_false_positive_02", "actual_focused_error_seconds", "<=", 1, "new mouth clip focused-time count"),
    SummaryGate("mixed_session_01", "focused_f1", ">=", 0.80, "mixed session focused state"),
    SummaryGate("mixed_session_01", "away_f1", ">=", 0.75, "mixed session away state"),
    SummaryGate("mixed_session_01", "looking_down_f1", ">=", 0.70, "mixed session looking_down state"),
    SummaryGate("mixed_session_01", "talking_f1", ">=", 0.55, "mixed session talking state"),
    SummaryGate("mixed_session_01", "eyes_closed_f1", ">=", 0.65, "mixed session eyes_closed state"),
    SummaryGate("mixed_session_01", "actual_focused_error_seconds", "<=", 18, "mixed session focused-time count"),
    SummaryGate("mixed_session_02", "focused_f1", ">=", 0.82, "new mixed session focused state"),
    SummaryGate("mixed_session_02", "away_f1", ">=", 0.70, "new mixed session away state"),
    SummaryGate("mixed_session_02", "looking_down_f1", ">=", 0.60, "new mixed session looking_down state"),
    SummaryGate("mixed_session_02", "talking_f1", ">=", 0.65, "new mixed session talking state"),
    SummaryGate("mixed_session_02", "eyes_closed_f1", ">=", 0.70, "new mixed session eyes_closed state"),
    SummaryGate("mixed_session_02", "actual_focused_error_seconds", "<=", 6, "new mixed session focused-time count"),
    SummaryGate("talking_away_01", "talking_f1", ">=", 0.72, "talking with social context"),
    SummaryGate("talking_away_01", "actual_focused_error_seconds", "<=", 8, "talking-away focused-time count"),
    SummaryGate("talking_screen_01", "focused_f1", ">=", 0.98, "screen-facing mouth movement limitation"),
    SummaryGate("talking_screen_01", "actual_focused_error_seconds", "<=", 1, "screen-facing mouth movement focused-time count"),
)


PREDICTION_COUNT_GATES: tuple[PredictionCountGate, ...] = (
    PredictionCountGate("focused_low_angle_01", "looking_down", "<=", 0, "low camera angle should not become looking_down"),
    PredictionCountGate("mouth_false_positive_01", "talking", "<=", 4, "existing mouth false-positive budget"),
    PredictionCountGate("mouth_false_positive_02", "talking", "<=", 0, "new mouth false-positive clip should stay clean"),
    PredictionCountGate("talking_screen_01", "talking", "<=", 0, "screen-facing talking is intentionally not detected in v1"),
)


def main() -> int:
    args = build_parser().parse_args()
    failures = run_gate(args.summary, args.results_dir)
    if failures:
        print("FAIL eval gate")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("PASS eval gate")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Fail if local Clarity eval results regress past accepted thresholds")
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--results-dir", type=Path, default=DEFAULT_RESULTS_DIR)
    return parser


def run_gate(summary_path: Path, results_dir: Path) -> list[str]:
    failures: list[str] = []
    rows = load_summary(summary_path, failures)
    if not rows:
        return failures

    for gate in SUMMARY_GATES:
        row = rows.get(gate.clip)
        if row is None:
            failures.append(f"{gate.clip}: missing from {summary_path}")
            continue

        actual = parse_float(row, gate.metric, failures, gate.clip)
        if actual is None:
            continue

        if not compare(actual, gate.op_label, gate.threshold):
            failures.append(
                f"{gate.clip}.{gate.metric}={actual:.3f}, expected {gate.op_label} {gate.threshold:g} ({gate.why})"
            )

    for gate in PREDICTION_COUNT_GATES:
        actual = count_predicted_seconds(results_dir / f"{gate.clip}_predictions.csv", gate.state, failures)
        if actual is None:
            continue

        if not compare(float(actual), gate.op_label, float(gate.threshold)):
            failures.append(
                f"{gate.clip}.predicted_{gate.state}_seconds={actual}, "
                f"expected {gate.op_label} {gate.threshold} ({gate.why})"
            )

    return failures


def load_summary(path: Path, failures: list[str]) -> dict[str, dict[str, str]]:
    if not path.exists():
        failures.append(f"summary file not found: {path}")
        return {}

    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = {row["clip"]: row for row in reader if row.get("clip")}

    if not rows:
        failures.append(f"summary file has no clip rows: {path}")
    return rows


def parse_float(row: dict[str, str], metric: str, failures: list[str], clip: str) -> float | None:
    value = row.get(metric)
    if value is None or value == "":
        failures.append(f"{clip}.{metric}: missing metric")
        return None

    try:
        return float(value)
    except ValueError:
        failures.append(f"{clip}.{metric}: non-numeric value {value!r}")
        return None


def count_predicted_seconds(path: Path, state: str, failures: list[str]) -> int | None:
    if not path.exists():
        failures.append(f"prediction file not found: {path}")
        return None

    count = 0
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if "predicted" not in (reader.fieldnames or []):
            failures.append(f"{path}: missing predicted column")
            return None

        for row in reader:
            if row.get("predicted") == state:
                count += 1
    return count


def compare(actual: float, op_label: str, threshold: float) -> bool:
    return OPS[op_label](actual, threshold)


if __name__ == "__main__":
    raise SystemExit(main())
