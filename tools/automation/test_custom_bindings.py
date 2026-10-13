from copy import deepcopy
import json
from pathlib import Path
import unittest

from custom_bindings import BindingError, CustomDraft, from_preset, validate


ROOT = Path(__file__).resolve().parents[2]


class Backend:
    def __init__(self, fail=False):
        self.calls = []
        self.fail = fail

    def apply(self, candidate):
        self.calls.append(deepcopy(candidate))
        candidate["bindings"].clear()  # A backend cannot mutate the settings snapshot.
        if self.fail:
            raise RuntimeError("Runtime apply refused")


class CustomBindingTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((ROOT / "data/actions.json").read_text(encoding="utf-8-sig"))
        self.current = json.loads((ROOT / "data/presets/current.json").read_text(encoding="utf-8-sig"))
        self.alt = json.loads((ROOT / "data/presets/alt1.json").read_text(encoding="utf-8-sig"))
        self.initial = from_preset(self.catalog, self.current)

    def custom(self):
        candidate = deepcopy(self.initial)
        for binding in candidate["bindings"]:
            if binding["id"] in {"geralt-horse.follow", "geralt-horse.canter", "geralt-horse.gallop"}:
                binding["button"] = "r3"
            if binding["id"] == "geralt-horse.gallop":
                binding["seconds"] = 0.5
        return candidate

    def test_presets_roundtrip_and_staging_cancel(self):
        original = deepcopy(self.current)
        editor = CustomDraft(self.catalog, self.initial)
        editor.stage(json.loads(json.dumps(self.custom())))
        self.assertEqual(editor.active, self.initial)
        self.assertNotEqual(editor.pending, editor.active)
        editor.cancel()
        self.assertEqual(editor.pending, self.initial)
        editor.restore_preset(self.alt)
        self.assertEqual(editor.pending, from_preset(self.catalog, self.alt))
        self.assertEqual(self.current, original)

    def test_atomic_apply_contract_and_defensive_copies(self):
        editor = CustomDraft(self.catalog, self.initial)
        candidate = self.custom()
        editor.stage(candidate)
        candidate["bindings"].clear()
        with self.assertRaises(BindingError):
            editor.apply(None)
        with self.assertRaises(RuntimeError):
            editor.apply(Backend(fail=True))
        self.assertEqual(editor.active, self.initial)
        applied = editor.apply(Backend())
        self.assertEqual(applied, self.custom())
        applied["bindings"].clear()
        self.assertEqual(editor.active, self.custom())

    def test_reject_bad_settings_without_changing_pending(self):
        editor = CustomDraft(self.catalog, self.initial)
        mutations = [
            lambda c: c.update(schema_version=True),
            lambda c: c["bindings"].pop(),
            lambda c: c["bindings"].append(deepcopy(c["bindings"][0])),
            lambda c: c["bindings"][0].update(id="unknown.action"),
            lambda c: c["bindings"][0].update(button="start"),
            lambda c: c["bindings"][0].update(button="left-axis-x"),
            lambda c: c["bindings"][0].update(gesture="double-tap"),
            lambda c: c["bindings"][0].update(seconds=0.3),
            lambda c: c["bindings"][0].update(gesture="duration", seconds=True),
            lambda c: c["bindings"][0].update(gesture="duration", seconds=float("nan")),
            lambda c: c["bindings"][0].update(gesture="duration", seconds=2),
            lambda c: c["bindings"][0].update(extra="ignored"),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                candidate = deepcopy(self.initial)
                mutate(candidate)
                with self.assertRaises(BindingError):
                    editor.stage(candidate)
                self.assertEqual(editor.pending, self.initial)

    def test_contextual_conflicts_allow_only_declared_native_groups(self):
        candidate = deepcopy(self.initial)
        for binding in candidate["bindings"]:
            if binding["id"] == "geralt-horse.use":
                binding["button"] = "a"
        with self.assertRaisesRegex(BindingError, "Conflicting"):
            validate(candidate, self.catalog)
        # Context separation and intentional Follow/Canter/Gallop sharing stay valid.
        self.assertEqual(validate(self.custom(), self.catalog), self.custom())


if __name__ == "__main__":
    unittest.main()
