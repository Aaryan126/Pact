from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path
from statistics import median


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Summarize FocusMirror per-second prediction CSV files")
    parser.add_argument("csv_files", nargs="+", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    for path in args.csv_files:
        summarize(path)
    return 0


def summarize(path: Path) -> None:
    rows = list(csv.DictReader(path.open("r", encoding="utf-8")))
    print(f"\n=== {path.name} ===")
    truth_key = "visual_truth" if rows and "visual_truth" in rows[0] else "truth"
    print("visual_truth:", _counts(rows, truth_key))
    if rows and "actual_focus" in rows[0]:
        print("actual_focus:", _counts(rows, "actual_focus"))
    print("predicted:", _counts(rows, "predicted"))
    print("frame_state:", _counts(rows, "frame_state"))
    print("reasons:", Counter(row["reason"] for row in rows).most_common(6))

    for state in sorted(set(row["predicted"] for row in rows)):
        subset = [row for row in rows if row["predicted"] == state]
        print(
            f"  {state}: n={len(subset)} "
            f"ear={_median_field(subset, 'ear')} "
            f"pitch={_median_field(subset, 'pitch')} "
            f"yaw={_median_field(subset, 'yaw')} "
            f"roll={_median_field(subset, 'roll')} "
            f"mar={_median_field(subset, 'mar')}"
        )


def _counts(rows: list[dict[str, str]], key: str) -> dict[str, int]:
    return dict(Counter(row[key] for row in rows))


def _median_field(rows: list[dict[str, str]], key: str) -> str:
    values = [float(row[key]) for row in rows if row.get(key)]
    if not values:
        return "n/a"
    return f"{median(values):.3f}"


if __name__ == "__main__":
    raise SystemExit(main())
