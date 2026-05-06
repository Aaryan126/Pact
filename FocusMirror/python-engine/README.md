# FocusMirror Python Engine

Local-only computer vision engine for FocusMirror. It reads webcam frames or a video file, processes at 3-5 fps, and emits one JSON classification event per second on stdout.

## Run Standalone

```sh
/usr/bin/python3 -m venv .venv39
source .venv39/bin/activate
pip install "mediapipe==0.10.14"
PYTHONPATH=. python -m focusmirror_engine.main --source webcam --fps 5
```

For live visual debugging with the camera feed, landmarks, pose values, and current labels:

```sh
PYTHONPATH=. python -m focusmirror_engine.main --source webcam --fps 5 --preview --no-json
```

Press `q` or `Esc` in the preview window to stop.

`looking_down` is based on sustained head pose pitch from face landmarks, not eye gaze. The engine estimates the 3D orientation of the face using nose, chin, eye-corner, and mouth-corner landmarks. By default it requires a moderate downward head tilt for 3 seconds, then the state machine smooths the final output.

To tune eye-closed sensitivity:

```sh
PYTHONPATH=. python -m focusmirror_engine.main --source webcam --fps 5 --preview --no-json --ear-closed-threshold 0.10
```

On this Mac, the default `python3` is Python 3.13 with a tasks-only MediaPipe package. For iterative CV work, prefer the Python 3.9 venv above because `mediapipe==0.10.14` still exposes the legacy `mp.solutions.face_mesh` API.

If you intentionally use the newer MediaPipe Tasks API, download the Face Landmarker model bundle into `models/face_landmarker.task` first, or pass it explicitly:

```sh
mkdir -p models
curl -L -o models/face_landmarker.task \
  https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task

PYTHONPATH=. python3 -m focusmirror_engine.main --source webcam --fps 5 \
  --face-model models/face_landmarker.task
```

For eval or debugging with a file:

```sh
PYTHONPATH=. python -m focusmirror_engine.main --source path/to/recording.mp4 --fps 5
```

The engine does not use audio, does not write frames to disk, and does not make network calls.
