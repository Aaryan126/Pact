from __future__ import annotations

import json
import sys
import time
from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass
class ClassificationEvent:
    type: str
    timestamp: float
    elapsed_seconds: float
    state: str
    confidence: float
    raw: dict[str, Any] = field(default_factory=dict)


def make_event(
    *,
    elapsed_seconds: float,
    state: str,
    confidence: float,
    raw: dict[str, Any] | None = None,
) -> ClassificationEvent:
    return ClassificationEvent(
        type="classification",
        timestamp=time.time(),
        elapsed_seconds=elapsed_seconds,
        state=state,
        confidence=round(float(confidence), 4),
        raw=raw or {},
    )


def emit_json_line(event: ClassificationEvent | dict[str, Any]) -> None:
    payload = asdict(event) if isinstance(event, ClassificationEvent) else event
    print(json.dumps(payload, separators=(",", ":"), sort_keys=True), flush=True)


def emit_error(message: str, *, code: str = "engine_error") -> None:
    print(
        json.dumps(
            {
                "type": "error",
                "timestamp": time.time(),
                "code": code,
                "message": message,
            },
            separators=(",", ":"),
            sort_keys=True,
        ),
        file=sys.stderr,
        flush=True,
    )
