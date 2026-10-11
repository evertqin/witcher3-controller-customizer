# Current automation status

Twenty-two runner/adapter checks pass. The final eight-source/six-hook connected cook, reversible update, exact manual-save load, Current native callbacks, Exploration diagram and owned game closure passed.
Source guards require the canonical repo and REDkit workspace to match before cooking; native UI Automation handles editor controls, scan-code input handles the game console, ViGEm handles A/L3 and controller Back, and foreground region screenshots/Windows OCR provide evidence.
Console execution requires the requested command to match OCR of the current prompt; counter reset acknowledgement is required before gestures.
Exact callback totals are 10, Canter 3/3 and Gallop 2/2; balanced duplicate totals are failures.
Menu navigation validates each boundary; input focus loss stops replay and releases the virtual controller.
Owned cleanup can identify a hidden native game window; it sends only graceful WM_CLOSE to the launched PID.

Run from this folder:
```powershell
python development_loop.py editor.json startup-current.json --editor-pid 45780 --journal <development-install.json> --save <pinned-manual-save>
python game_test.py phase1-acceptance.json --journal <development-install.json> --exe <DX12-executable> --save <pinned-manual-save> --ffmpeg <ffmpeg-executable>
```
The editor PID is session-specific. Save calibration is English 2560x1440 and the supplied 07:10:06 manual save SHA-256; no Continue/save/delete action is sent.
Default pause input is controller Back; --pause-input keyboard remains available for diagnosing the unresolved repeated Escape failure.
The acceptance scenario uses the existing native Horse Stop/X action between gestures to reduce movement near enemies.
Results retain logs, source/artifact hashes, command prompt screenshots, native menu pages, OCR assertions and cleanup/save checks.
Native callback verification is not visual gait, interaction, Ciri, device, renderer or full gameplay acceptance.
The previous development journal schema remains required; a fresh Phase 1 installer journal is not yet accepted by the connected updater.
See repository docs/phase1-evidence.md for final artifact and failed replay evidence.

New pinned fixture: mounted-clear-111554.json; pass --fixture mounted-clear-111554.json and the matching --save filename to game_test.py or development_loop.py.
Latest clear-fixture result: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\phase1\clear-fixture-acceptance\20261011T183259Z-db8e6d15\result.json; 8/10 native riding assertions passed; status failed. Full gameplay release acceptance remains pending.

User accepted eight completed switches as sufficient; do not rerun the longer scenario solely to reach ten. Further gameplay release gates remain pending.

## Implemented workflow shortcuts — October 11, 2026

Routine default is `phase1-smoke.json`: establish Current, then one Alt1→Current round trip, two native callback assertions and last-valid fallback.
`game_test.py` and `development_loop.py` use it when their optional scenario argument is omitted. Ten-switch stress scenarios remain explicitly selectable; they are not the default.
`save_fixture.py list --profile <redirected-profile>` lists manual save filenames, local timestamps, hashes, thumbnails and metadata paths.
`save_fixture.py pin --save <explicit-sav> --title <visible-quest-title> --hud-label <gameplay-label> --output <new-fixture.json>` creates a hash/timestamp-pinned fixture without overwriting an existing file.
Pass that JSON using `--fixture`; invalid filenames/hash formats/empty HUD checks refuse before launch. A copied save's modification time may differ from its visible timestamp; the final unique row check still refuses a mismatch.

`tools/Sync-EditorSources.ps1` uses a prior cook's editor hashes to back up and sync only already-owned authored files as UTF-16.
It refuses added/removed source inventory or independent editor edits; matching sources are a no-op. `.w3edit` metadata remains untouched.
Use `development_loop.py editor.json --sync-sources ...` to run source sync before cooking; all other existing source/hook/cook ownership guards remain.
The local current editor sync was verified as a no-op; isolated changed-source tests verified UTF-16 output, backup, no-op idempotence, metadata/unrelated-source preservation and refusal before partial writes.
No source changes were needed in the compiled mod, so its verified artifact and candidate archive remain unchanged.

```powershell
# From tools/automation; replace placeholders using editor.json and save discovery.
python save_fixture.py list --profile <redirected-profile> --limit 5
python save_fixture.py pin --save <explicit-sav> --title "An Invitation from Keira Metz" --hud-label "talk to keira" --output <new-fixture.json>
python game_test.py --journal <development-install.json> --exe <DX12-executable> --save <explicit-sav> --fixture <new-fixture.json> --ffmpeg <ffmpeg-path>
python development_loop.py editor.json --sync-sources --editor-pid <verified-PID> --journal <development-install.json> --save <explicit-sav> --fixture <new-fixture.json>
```

Latest default smoke receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\phase1\routine-smoke\20261011T185455Z-db23df29\result.json
Status: `evidence_collected`; native riding assertions: 2; owned game closed and pinned save unchanged.
Twenty-two Python runner/adapter checks pass, plus isolated source-sync checks; broad gameplay acceptance remains separately pending.
