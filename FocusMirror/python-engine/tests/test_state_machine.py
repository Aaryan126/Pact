import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from focusmirror_engine.classifier import FOCUSED, UNCERTAIN, FrameClassification
from focusmirror_engine.state_machine import RollingStateMachine


class RollingStateMachineTests(unittest.TestCase):
    def test_state_machine_debounces_new_state(self) -> None:
        machine = RollingStateMachine(fps=1, window_seconds=3, transition_windows=2, emit_interval_seconds=1)

        self.assertEqual(machine.add(FrameClassification(FOCUSED, 0.9, "test"), timestamp=0).state, UNCERTAIN)
        self.assertEqual(machine.add(FrameClassification(FOCUSED, 0.9, "test"), timestamp=1).state, FOCUSED)
        self.assertEqual(machine.add(FrameClassification(FOCUSED, 0.9, "test"), timestamp=2).state, FOCUSED)


if __name__ == "__main__":
    unittest.main()
