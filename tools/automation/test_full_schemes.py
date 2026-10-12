from collections import Counter
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from full_schemes import SchemeError, build_appendix, expand_lineage, migrate_selection, parse


class FullSchemeTests(unittest.TestCase):
    def test_repeated_records_and_inherited_branches_survive(self):
        text = "[Root]\r\nIK_Pad_A_CROSS=(Action=Canter)\r\nIK_Pad_A_CROSS=(Action=Gallop,State=Duration,IdleTime=0.300000)\r\n[Left]\r\nDERIVED_FROM=Root\r\n[Right]\nDERIVED_FROM=Root\n[Horse]\nDERIVED_FROM=Left\nDERIVED_FROM=Right\nIK_LShift=(Action=Canter)\n"
        expanded = expand_lineage(parse(text))
        self.assertEqual(len(expanded["Horse"]), 5)
        counts = Counter(row.signature for row in expanded["Horse"])
        self.assertEqual(sorted(counts.values()), [1, 2, 2])
        self.assertEqual(sum(row.controller for row in expanded["Horse"]), 4)
        equivalent = parse("[X]\nIK_Pad_A_CROSS=(IdleTime=0.3,State=Duration,Action=Gallop)\n")["X"][0]
        self.assertEqual(expanded["Root"][1].signature, equivalent.signature)

    def test_bad_graphs_and_duplicate_headers_refuse(self):
        for text in ("[A]\nDERIVED_FROM=B\n[B]\nDERIVED_FROM=A\n", "[A]\nDERIVED_FROM=Missing\n"):
            with self.assertRaises(SchemeError):
                expand_lineage(parse(text))
        with self.assertRaises(SchemeError):
            parse("[Horse]\n[Horse]\n")
        with self.assertRaises(SchemeError):
            parse("[Horse]\nUnknown input\n")

    def test_hint_projection_uses_selected_digital_keys_only(self):
        from scheme_runtime import hint_keys
        profiles = {}
        for scheme, key in [('vanilla', 'IK_Pad_A_CROSS'), ('darksoul', 'IK_Pad_A_CROSS'), ('darksoul-alt1', 'IK_Pad_LeftThumb')]:
            profiles[scheme] = parse(f"[Horse]\n{key}=(Action=Canter)\n{key}=(Action=Canter,State=Duration,IdleTime=0.3)\nIK_LShift=(Action=Canter)\nIK_Pad_LeftAxisX=(Action=Canter)\nIK_Pattern_HorseAcceleration=(Action=Canter)\n")
        self.assertEqual(hint_keys(profiles, 'Horse', 'Canter'), [['IK_Pad_A_CROSS'], ['IK_Pad_A_CROSS'], ['IK_Pad_LeftThumb']])
        self.assertEqual(hint_keys(profiles, 'Horse', 'Gallop'), [[], [], []])

    def test_selection_upgrade_preserves_behavior(self):
        self.assertEqual(migrate_selection(0), "darksoul")
        self.assertEqual(migrate_selection("1"), "darksoul-alt1")
        self.assertEqual(migrate_selection(), "darksoul-alt1")
        self.assertEqual(migrate_selection(1, "vanilla"), "vanilla")
        for value in (True, -1, 2, "", "0.0"):
            with self.assertRaises(SchemeError):
                migrate_selection(value)
        with self.assertRaises(SchemeError):
            migrate_selection(0, "unknown")

    def test_full_appendix_preserves_personal_records_and_refuses_conflicts(self):
        native = "[Base]\nIK_Pad_X_SQUARE=(Action=Attack)\n[Horse]\nDERIVED_FROM=Base\nIK_Pad_A_CROSS=(Action=Canter)\nIK_Pad_LeftThumb=(Action=Use)\nIK_Pad_LeftAxisX=(Action=GI_AxisLeftX)\nIK_Pattern_HorseAcceleration=(Action=Canter)\n"
        dark = "[Base]\nIK_Pad_RightShoulder=(Action=Attack)\n[Horse]\nIK_Pad_RightShoulder=(Action=Attack)\nIK_Pad_A_CROSS=(Action=Canter)\nIK_Pad_LeftThumb=(Action=Use)\nIK_Pad_LeftAxisX=(Action=GI_AxisLeftX)\nIK_Pattern_HorseAcceleration=(Action=Canter)\n"
        alt = dark.replace("IK_Pad_A_CROSS=(Action=Canter)", "IK_Pad_LeftThumb=(Action=Canter)").replace("IK_Pad_LeftThumb=(Action=Use)", "IK_Pad_A_CROSS=(Action=Use)")
        personal = dark + "; personal note\r\nIK_F1=(Action=MyShortcut)\r\nIK_F1=(Action=MyShortcut)\r\n"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "data/schemes").mkdir(parents=True)
            fixtures = root / "fixtures/legacy"
            fixtures.mkdir(parents=True)
            sources = {"vanilla": native, "darksoul": dark, "darksoul-alt1": alt}
            schemes = []
            for ident, text in sources.items():
                file = root / "native.ini" if ident == "vanilla" else fixtures / (ident + ".ini")
                file.write_bytes(text.encode("utf-8"))
                row = {"id": ident, "display_name": ident, "source_sha256": hashlib.sha256(file.read_bytes()).hexdigest()}
                if ident != "vanilla":
                    row["fixture"] = file.relative_to(root).as_posix()
                schemes.append(row)
            (root / "data/schemes/manifest.json").write_text(json.dumps({"schema_version": 1, "selection_schema_version": 2, "schemes": schemes}))
            appendix, aliases = build_appendix(root, root / "native.ini", personal)
            self.assertEqual(len(aliases), 6)
            self.assertEqual(len({a["alias"] for a in aliases}), 5)
            base = [a for a in aliases if a["canonical"] == "Base" and a["scheme"] != "vanilla"]
            self.assertEqual(base[0]["alias"], base[1]["alias"])
            huge = personal + ''.join(f"[Extra{i}]\nIK_F2=(Action=Shortcut)\n" for i in range(128))
            with self.assertRaisesRegex(SchemeError, "native capacity"):
                build_appendix(root, root / "native.ini", huge)
            parsed = parse(appendix)
            for alias in aliases:
                if alias["canonical"] == "Horse":
                    rows = parsed[alias["alias"]]
                    self.assertEqual(sum(r.key == "IK_F1" for r in rows), 2)
                    self.assertIn("; personal note\r\n", appendix)
                    self.assertEqual(sum(r.key == "IK_Pad_LeftAxisX" for r in rows), 1)
                    self.assertEqual(sum(r.key == "IK_Pattern_HorseAcceleration" for r in rows), 1)
            with self.assertRaisesRegex(SchemeError, "Independent controller edits"):
                build_appendix(root, root / "native.ini", personal.replace("IK_Pad_RightShoulder", "IK_Pad_RightTrigger"))
            with self.assertRaisesRegex(SchemeError, "already exist"):
                build_appendix(root, root / "native.ini", personal + appendix)
            (root / "native.ini").write_text(native + "; changed source")
            with self.assertRaisesRegex(SchemeError, "fingerprint changed"):
                build_appendix(root, root / "native.ini", personal)


if __name__ == "__main__":
    unittest.main()
