# Clarity Eval Harness

Put raw test videos in `recordings/` and matching ground-truth label files in `labels/`. The recordings directory is gitignored because it can contain private video.

Run:

```sh
PYTHONPATH=../python-engine ../python-engine/.venv39/bin/python run_eval.py recordings/session_001.mov labels/session_001.json
```

Run the full local suite and refresh CSV output:

```sh
PYTHONPATH=../python-engine ../python-engine/.venv39/bin/python run_suite.py
```

Run the full suite with the regression gate:

```sh
PYTHONPATH=../python-engine ../python-engine/.venv39/bin/python run_suite.py --gate
```

To check existing CSV results without re-running MediaPipe:

```sh
../python-engine/.venv39/bin/python eval_gate.py
```

The label format is documented in `../docs/EVAL_METHODOLOGY.md`.

`run_suite.py` writes:

- `results/<clip>_predictions.csv`: per-second visual truth, actual focus truth, prediction, confidence, and raw CV signals.
- `results/summary.csv`: per-clip visual-state metrics plus actual focused-time metrics.

`eval_gate.py` intentionally encodes the behaviors already validated on the local clip set. It is a regression guard, not a shipping-quality guarantee.
