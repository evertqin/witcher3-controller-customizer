"""Freeze a verified REDkit editor cook using the existing updater receipt schema."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import uuid


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text(path):
    raw = path.read_bytes()
    encoding = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
    return raw.decode(encoding).replace("\r\n", "\n").replace("\r", "\n")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "editor", "sdk", "game", "log", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--completion-screenshot", type=Path, required=True)
    args = parser.parse_args()
    repo, editor, sdk, log = args.repo, args.editor, args.sdk, args.log
    require(args.completion_screenshot.is_file(), "Cook completion evidence required")
    body = text(log)
    files = sorted((repo / "src/scripts").rglob("*.ws"))
    editor_files = sorted((editor / "workspace/scripts").rglob("*.ws"))
    require(len(files) > 0 and len(files) == len(editor_files), "Source inventory mismatch")
    patch_marker = f"Parsing {len(files)} script files..."
    base_count = len(list((sdk / "r4data/scripts").rglob("*.ws")))
    base_start = body.index(f"Parsing {base_count} script files...")
    patch_start = body.index(patch_marker, base_start)
    end = body.index("Scriptables reloaded.", patch_start) + len("Scriptables reloaded.")
    require("[Error]" not in body[base_start:end], "Script-phase errors")
    require("Script functions: successfully loaded." in body[patch_start:end], "Patch not loaded")
    require("Step CompileScripts has finished!" in body[end:], "Script stage incomplete")
    require("Step CreateMetadataStores has finished!" in body[end:], "Packaging stage incomplete")
    stamp = re.search(r"\[(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\].*" + re.escape(patch_marker), body).group(1)
    patch_time = datetime.strptime(stamp, "%Y.%m.%d %H:%M:%S").timestamp()
    project_file = editor / "customizecontrollerscheme.w3edit"
    project = json.loads(text(project_file))
    require(project["useLooseScripts"] is False and project["succesfullyCooked"] is True, "Project not successfully cooked")
    source_hashes, editor_hashes = {}, {}
    for source in files:
        relative = source.relative_to(repo / "src/scripts").as_posix()
        target = editor / "workspace/scripts" / relative
        require(text(source) == text(target), f"Source text differs: {relative}")
        require(target.stat().st_mtime <= patch_time + 1, "Source modified after compilation")
        source_hashes[relative], editor_hashes[relative] = sha(source), sha(target)
    toolchain = json.loads(text(repo / "tools/compiler-toolchain.json"))
    require(sha(sdk / "bin/x64_RedKit/wcc_lite.exe") == toolchain["CompilerSha256"], "Compiler fingerprint mismatch")
    for relative, expected in toolchain["BaseScriptSha256"].items():
        require(sha(sdk / "r4data/scripts" / relative) == expected, f"SDK hook changed: {relative}")
        require(sha(args.game / "content/content0/scripts" / relative) == expected, f"Game hook changed: {relative}")
    blob_relative = "mods/modcustomizecontrollerscheme/content/precompiled.rsblob"
    blob = editor / "packed" / blob_relative
    require(blob.stat().st_size > 0, "Empty blob")
    require(patch_time <= blob.stat().st_mtime <= log.stat().st_mtime + 1, "Blob not from this cook")
    artifacts = {name: sha(blob.parent / name) for name in ("precompiled.rsblob", "info.json", "metadata.store")}
    run = args.output.resolve() / (datetime.fromtimestamp(log.stat().st_mtime).strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8])
    run.mkdir(parents=True)
    content = run / "packed" / Path(blob_relative).parent
    content.mkdir(parents=True)
    for name, expected in artifacts.items():
        shutil.copy2(blob.parent / name, content / name)
        require(sha(content / name) == expected, "Artifact changed during snapshot")
    info = json.loads(text(content / "info.json"))
    require(info["useLooseScripts"] is False, "Unexpected loose script metadata")
    shutil.copy2(log, run / "cook.log")
    shutil.copy2(project_file, run / "project.w3edit")
    shutil.copy2(args.completion_screenshot, run / "cook-completion.png")
    for source in files:
        relative = source.relative_to(repo / "src/scripts")
        for category, root in (("canonical", repo / "src/scripts"), ("editor", editor / "workspace/scripts")):
            target = run / "sources" / category / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
            expected = source_hashes if category == "canonical" else editor_hashes
            require(sha(target) == expected[relative.as_posix()], "Source changed during snapshot")
    diagnostics = [line for line in body.splitlines() if "[Error]" in line]
    report = {
        "SchemaVersion": 2, "EvidenceKind": "RedkitEditorCook", "EditorProject": str(editor),
        "UserReportedCookSuccess": False, "AgentObservedCookCompletion": True,
        "ProjectSuccessfullyCooked": project["succesfullyCooked"],
        "InfoSuccessfullyCooked": info["succesfullyCooked"], "UseLooseScripts": False,
        "CompilerSha256": toolchain["CompilerSha256"], "BaseHookSha256": toolchain["BaseScriptSha256"],
        "CanonicalSourceSha256": source_hashes, "EditorSourceSha256": editor_hashes,
        "SourceTextEquivalenceVerified": True, "SourceInventoryCount": len(files),
        "CookLogSha256": sha(run / "cook.log"), "ScriptCompilationVerified": True,
        "ScriptCompilationErrors": [], "CookDiagnostics": diagnostics,
        "WholeCookErrorFree": not diagnostics, "ObservedBlobRelativePath": blob_relative,
        "FileSha256": artifacts, "BlobLength": blob.stat().st_size,
        "RuntimeLoadVerified": False, "StandaloneExitCode": None,
    }
    (run / "cook.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"Snapshot": str(run), "BlobLength": report["BlobLength"],
                      "BlobSha256": artifacts["precompiled.rsblob"], "PackagingErrorCount": len(diagnostics)}, indent=2))


if __name__ == "__main__":
    main()
