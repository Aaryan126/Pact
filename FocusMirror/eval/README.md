# FocusMirror Eval Harness

Put raw test videos in `recordings/` and matching ground-truth label files in `labels/`. The recordings directory is gitignored because it can contain private video.

Run:

```sh
python3 run_eval.py recordings/session_001.mp4 labels/session_001.json
```

The label format is documented in `../docs/EVAL_METHODOLOGY.md`.
