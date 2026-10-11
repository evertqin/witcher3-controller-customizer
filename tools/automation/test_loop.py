import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from loop import LogReader, LoopError, Runner, validate


class LoopTests(unittest.TestCase):
    def setUp(self):
        base = Path(os.environ.get("W3_TEST_TMP", tempfile.gettempdir())).resolve()
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=base)
        self.root = Path(self.temp.name)
        self.base = base

    def tearDown(self):
        self.assertEqual(self.root.resolve().parent, self.base)
        self.temp.cleanup()

    def execute(self, stages, **extra):
        config = dict(configured=True, scope="build", stages=stages, **extra)
        validate(config)
        runner = Runner(config, self.root / "config.json", self.root / "runs")
        success = runner.run()
        result = json.loads((runner.directory / "result.json").read_text())
        return success, result, runner

    @staticmethod
    def command(code, **extra):
        return dict(name="command", kind="command", argv=[sys.executable, "-c", code], **extra)

    def test_success_requires_actual_output_and_nonempty_artifact(self):
        code = "from pathlib import Path; Path(r'{run_dir}/blob').write_bytes(b'fresh'); print('COMPILED')"
        success, report, runner = self.execute([self.command(code, pass_regex="COMPILED", artifacts=["{run_dir}/blob"])])
        self.assertTrue(success)
        self.assertEqual(report["status"], "build_passed")
        self.assertTrue((runner.directory / "summary.md").exists())

    def test_error_text_blocks_zero_exit_and_following_stage(self):
        success, report, _ = self.execute([
            self.command("print('PASS ERROR')", pass_regex="PASS", fail_regex="ERROR"),
            self.command("raise RuntimeError('must never run')")])
        self.assertFalse(success)
        self.assertEqual(len(report["steps"]), 1)

    def test_missing_artifact_cannot_reuse_old_blob(self):
        (self.root / "blob").write_bytes(b"old")
        success, report, _ = self.execute([self.command("print('OK')", artifacts=["{run_dir}/blob"])])
        self.assertFalse(success)
        self.assertIn("artifact missing", report["error"])

    def test_timeout_stops_child_and_records_failure(self):
        success, report, runner = self.execute([self.command("import time; time.sleep(30)", timeout=0.1)])
        self.assertFalse(success)
        self.assertIn("timed out", report["error"])
        self.assertIsNotNone(runner.children[0].poll())

    def test_stale_runtime_pass_is_ignored(self):
        log = self.root / "runtime.log"
        log.write_text("OLD_PASS\n")
        success, report, _ = self.execute([dict(name="runtime", kind="wait_log", path=str(log), pass_regex="OLD_PASS", timeout=0.1)])
        self.assertFalse(success)
        self.assertIn("fresh log", report["error"])

    def test_split_marker_and_rotation(self):
        log = self.root / "runtime.log"
        log.write_text("stale\n")
        reader = LogReader(log)
        with log.open("a") as stream:
            stream.write("PA")
        self.assertEqual(reader.read(), "")
        with log.open("a") as stream:
            stream.write("SS\n")
        self.assertEqual(reader.read(), "PASS\n")
        log.rename(self.root / "old.log")
        log.write_text("NEW\n")
        self.assertEqual(reader.read(), "NEW\n")

    def test_source_drift_invalidates_result(self):
        source = self.root / "probe.ws"
        source.write_text("before")
        code = f"from pathlib import Path; Path({str(source)!r}).write_text('after')"
        success, report, _ = self.execute([self.command(code)], source_roots=[str(source)])
        self.assertFalse(success)
        self.assertIn("Sources changed", report["error"])

    def test_gameplay_cannot_pass_without_correlated_assertion(self):
        with self.assertRaises(LoopError):
            validate(dict(configured=True, scope="gameplay", stages=[self.command("print('PASS')", assertion=True, pass_regex="PASS")]))

    def test_draft_is_blocked(self):
        with self.assertRaises(LoopError):
            validate(dict(configured=False, stages=[]))


if __name__ == "__main__":
    unittest.main()
