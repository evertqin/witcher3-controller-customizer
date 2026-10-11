"""Configurable Witcher 3 build/test runner; Python 3.11+, no dependencies."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid


class LoopError(Exception):
    pass


def substitute(value, variables):
    if isinstance(value, str):
        for key, replacement in variables.items():
            value = value.replace("{" + key + "}", str(replacement))
        return value
    if isinstance(value, list):
        return [substitute(item, variables) for item in value]
    if isinstance(value, dict):
        return {key: substitute(item, variables) for key, item in value.items()}
    return value


def fingerprint(roots):
    result = {}
    for root in map(Path, roots):
        paths = sorted(root.rglob("*")) if root.is_dir() else [root]
        for path in paths:
            if path.is_file():
                result[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


class LogReader:
    """Ignore pre-run bytes; consume fresh records without accepting stale passes."""
    def __init__(self, path):
        self.path = Path(path)
        self.position = self.path.stat().st_size if self.path.exists() else 0
        self.identity = self.path.stat().st_ino if self.path.exists() else None
        self.pending = b""

    def read(self):
        if not self.path.exists():
            return ""
        stat = self.path.stat()
        if stat.st_size < self.position or stat.st_ino != self.identity:
            self.position, self.pending = 0, b""
        self.identity = stat.st_ino
        with self.path.open("rb") as stream:
            stream.seek(self.position)
            data = self.pending + stream.read()
            self.position = stream.tell()
        # Keep incomplete lines until they are flushed, avoiding split markers.
        end = data.rfind(b"\n") + 1
        self.pending = data[end:]
        return data[:end].decode("utf-8", errors="replace").replace("\r\n", "\n")


def stop_owned(process):
    if process.poll() is not None:
        return
    if os.name == "nt":
        # PID belongs to a child created by this run, never kill by image name.
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=10, check=False)
    else:
        process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


class Runner:
    def __init__(self, config, config_path, evidence):
        self.config = config
        self.run_id = uuid.uuid4().hex
        self.directory = evidence / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + self.run_id[:8])
        self.variables = {"run_id": self.run_id, "run_dir": self.directory,
                          "bundle": config_path.parent, "python": sys.executable}
        self.children = []
        self.readers = {}
        self.report = {"run_id": self.run_id, "status": "running", "steps": [],
                       "warnings": [], "config": str(config_path)}

    def command(self, stage, log_path, launch=False):
        argv = stage["argv"]
        environment = os.environ.copy()
        environment.update({str(k): str(v) for k, v in stage.get("env", {}).items()})
        environment.update(W3_RUN_ID=self.run_id, W3_RUN_DIR=str(self.directory))
        with log_path.open("wb") as stream:
            process = subprocess.Popen(argv, cwd=stage.get("cwd"), env=environment,
                                       stdout=stream, stderr=subprocess.STDOUT,
                                       shell=False,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" and not launch else 0)
            self.children.append(process)
            if launch:
                self.variables[stage.get("pid_variable", "game_pid")] = process.pid
                return {"pid": process.pid}
            try:
                code = process.wait(timeout=stage.get("timeout", 120))
            except subprocess.TimeoutExpired:
                stop_owned(process)
                raise LoopError("Command timed out")
        output = log_path.read_text(encoding="utf-8", errors="replace")
        if code != 0:
            raise LoopError(f"Command exited {code}; see {log_path.name}")
        if stage.get("fail_regex") and re.search(stage["fail_regex"], output):
            raise LoopError("Command reported failure despite exit 0")
        if stage.get("pass_regex") and not re.search(stage["pass_regex"], output):
            raise LoopError("Expected success marker missing")
        for artifact in stage.get("artifacts", []):
            path = Path(artifact)
            if not path.is_file() or not path.stat().st_size:
                raise LoopError(f"Expected nonempty artifact missing: {path}")
        return {"exit_code": code}

    def wait_log(self, stage, log_path):
        reader = self.readers[stage["path"]]
        deadline = time.monotonic() + stage.get("timeout", 60)
        while time.monotonic() < deadline:
            text = reader.read()
            if text:
                with log_path.open("a", encoding="utf-8") as stream:
                    stream.write(text)
                if stage.get("fail_regex") and re.search(stage["fail_regex"], text):
                    raise LoopError("Runtime failure marker")
                if re.search(stage["pass_regex"], text):
                    return {"marker": stage["pass_regex"]}
            if stage.get("require_live_game") and "game_pid" in self.variables:
                owned = next(p for p in self.children if p.pid == self.variables["game_pid"])
                if owned.poll() is not None:
                    raise LoopError("Game exited before expected marker")
            time.sleep(0.2)
        raise LoopError("Timed out waiting for fresh log marker")

    def run(self):
        self.directory.mkdir(parents=True)
        (self.directory / "config.json").write_text(json.dumps(self.config, indent=2), encoding="utf-8")
        self.report["started_utc"] = datetime.now(timezone.utc).isoformat()
        stages = substitute(self.config["stages"], self.variables)
        for stage in stages:
            if stage["kind"] == "wait_log":
                self.readers.setdefault(stage["path"], LogReader(stage["path"]))
        try:
            self.report["sources"] = fingerprint(self.config.get("source_roots", []))
            for index, raw_stage in enumerate(self.config["stages"]):
                stage = substitute(raw_stage, self.variables)
                entry = {"name": stage["name"], "kind": stage["kind"], "status": "running"}
                self.report["steps"].append(entry)
                log = self.directory / f"{index:02d}.log"
                start = time.monotonic()
                try:
                    if stage["kind"] in ("command", "launch"):
                        entry.update(self.command(stage, log, stage["kind"] == "launch"))
                    elif stage["kind"] == "wait_log":
                        entry.update(self.wait_log(stage, log))
                    else:
                        raise LoopError(f"Unknown stage kind: {stage['kind']}")
                    entry["status"] = "passed"
                except Exception as error:
                    entry.update(status="failed", error=str(error))
                    raise
                finally:
                    entry["seconds"] = round(time.monotonic() - start, 3)
                    entry["log"] = log.name if log.exists() else None
            if fingerprint(self.config.get("source_roots", [])) != self.report["sources"]:
                raise LoopError("Sources changed during run; result invalid")
            self.report["status"] = {"gameplay": "passed", "build": "build_passed", "evidence": "evidence_collected"}[self.config.get("scope", "build")]
        except KeyboardInterrupt:
            self.report.update(status="interrupted", error="User interrupted run")
        except Exception as error:
            self.report.update(status="failed", error=str(error))
        finally:
            if not self.config.get("leave_launched_processes", False):
                for child in reversed(self.children):
                    try:
                        stop_owned(child)
                    except Exception as error:
                        self.report["warnings"].append(f"Process cleanup: {error}")
            for index, raw in enumerate(self.config.get("evidence_files", [])):
                path = Path(substitute(raw, self.variables))
                try:
                    (self.directory / f"external-{index}-{path.name}").write_bytes(path.read_bytes())
                except OSError as error:
                    self.report["warnings"].append(f"Evidence unavailable: {path}: {error}")
            self.report["finished_utc"] = datetime.now(timezone.utc).isoformat()
            (self.directory / "result.json").write_text(json.dumps(self.report, indent=2), encoding="utf-8")
            lines = [f"Run: {self.run_id}", f"Scope: {self.config.get('scope', 'build')}",
                     f"Result: {self.report['status']}"]
            lines += [f"- {s['name']}: {s['status']} ({s.get('seconds', 0)}s)" for s in self.report["steps"]]
            if self.report.get("error"):
                lines.append(f"Error: {self.report['error']}")
            (self.directory / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        return self.report["status"] in ("passed", "build_passed", "evidence_collected")


def validate(config):
    if not config.get("configured", False):
        raise LoopError("Draft scenario: configure paths, markers and UI targets first")
    stages = config.get("stages", [])
    if not stages:
        raise LoopError("No stages configured")
    if config.get("scope", "build") not in ("gameplay", "build", "evidence"):
        raise LoopError("Scope must be build, gameplay or evidence")
    if config.get("scope") == "gameplay" and not any(
        s.get("assertion") and s.get("pass_regex") for s in stages
    ):
        raise LoopError("Gameplay scope requires an explicit assertion marker")
    if config.get("scope") == "gameplay" and any(
        s.get("assertion") and "{run_id}" not in s.get("pass_regex", "") for s in stages
    ):
        raise LoopError("Gameplay assertion markers must include {run_id}")
    for stage in stages:
        if stage.get("kind") not in ("command", "launch", "wait_log"):
            raise LoopError("Unsupported stage")
        if stage["kind"] in ("command", "launch"):
            if not isinstance(stage.get("argv"), list) or not stage["argv"] or not all(isinstance(s, str) for s in stage["argv"]):
                raise LoopError("Commands must be nonempty argv arrays")
        if stage["kind"] == "wait_log" and not stage.get("pass_regex"):
            raise LoopError("wait_log requires pass_regex")
        for key in ("pass_regex", "fail_regex"):
            if stage.get(key):
                re.compile(stage[key])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    config_path = args.config.resolve()
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
        validate(config)
        evidence = (args.evidence or config_path.parent / "runs").resolve()
        runner = Runner(config, config_path, evidence)
        if args.dry_run:
            print(json.dumps(substitute(config, runner.variables), indent=2, default=str))
            return 0
        evidence.mkdir(parents=True, exist_ok=True)
        # Serialize runs against shared compiler/editor logs; stale locks need inspection.
        lock = evidence / ".loop.lock"
        with lock.open("x", encoding="utf-8") as stream:
            stream.write(str(os.getpid()))
        try:
            success = runner.run()
            print(str(runner.directory / "result.json"))
            return 0 if success else 1
        finally:
            lock.unlink()
    except (OSError, ValueError, LoopError) as error:
        print(f"Blocked: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
