# Witcher 3 edit, cook and game-test runbook

## Working configuration

Use `tools/automation/editor.json` for machine paths; avoid rediscovering installed paths or copying them into general helpers.
The canonical repo has eight UTF-8 authored scripts in `src/scripts/local/controllerCustomizer`; REDkit uses UTF-16 copies under its project's `workspace/scripts/local/controllerCustomizer`.
Project settings use compiled scripts, `useLooseScripts=false`; keep the `.w3edit` metadata and native SDK sources intact.
Observed local setup: Remaster 5.01 menu / executable 5.0.0.1048522, input format 60; DX12 is available, DX11 executable absent.
Exact compiler and six native wrapper sources are fingerprint-pinned in `tools/compiler-toolchain.json` and cook receipts; changing a version label is not compatibility evidence.

Historical machine paths:
- Repository: I:\OneDrive\Documents\The Witcher 3\github-project\witcher3-controller-customizer
- REDkit project: F:\projects\TheWitcher3\customizecontrollerscheme
- SDK: H:\SteamLibrary\steamapps\common\The Witcher 3 REDkit
- Game: F:\Steam\steamapps\common\The Witcher 3
- Redirected Documents profile: I:\OneDrive\Documents\The Witcher 3
- Python: F:\Python313\python.exe; FFmpeg: J:\Tools\ffmpeg\bin\ffmpeg.exe
- ViGEmBus is installed/running; the local vendor vgamepad client creates one persistent Xbox controller and verifies presses/releases via independent XInput readback.

## Compile/cook

Run from `tools/automation` (the workspace `outputs/witcher-loop` bundle is an identical development copy):

```powershell
python editor_cook.py editor.json --editor-pid <verified-loaded-project-PID>
```

Find the current editor PID; never reuse a historical PID without checking its executable/project title.
Use the loaded project when available; omit `--editor-pid` only when the editor is closed and the driver should open its own instance.
The driver uses native UI Automation for Browse/Open/Publish/Next/Start and saves a fresh frozen cook snapshot, source hashes, compiler/hooks, full log and compiled artifacts.
The editor stays open; completed cook wizards close so subsequent runs work.
Bare standalone compiler startup stalled locally; do not substitute it for the working editor path.
An existing Build-Mod.ps1 -CookSnapshot path verifies/reuses a frozen editor cook; it does not independently prove new compilation.
The final loaded candidate's script phase had zero errors; outer packaging diagnostics include Wwise/loose-script resource messages and must remain visible rather than claiming whole-cook success.
Its blob is 18,499 bytes, SHA-256 dec1e4a026b696b31672fe4adc664cae05b798ef039fa49043f8e3326c50d468.

## Install/update

Always close the game before writing installed payloads or personal bindings.
Current development setup uses the Phase0LoadProbe runtime journal, a separate eight-alias input journal and reversible known-legacy isolation.
`development_loop.py` verifies owned hashes, cooks, calls Update-RuntimeProbe.ps1, launches a fresh owned game, selects the pinned save, runs probes and gracefully closes only its game.
The standalone Phase 1 installer owns personal alias additions, three compiled artifacts and menu XML; it does not enable the debug console or change native preset/list files.
Use tools/Update-Mod.ps1 -JournalFile <Phase1-install.json> -CookSnapshot <verified-snapshot> for standalone Phase 1 updates. It preserves personal input and original uninstall backups; changed owned records refuse. The development loop still uses its separate Phase0LoadProbe updater; don't silently migrate journals.
Install-Mod.ps1 / Restore-Backup.ps1 have isolated tests for compatibility refusal, redirected paths, duplicates, later unrelated edits, explicit known legacy isolation and partial rollback.
OneDrive writes use in-place byte overwrite with verified backups; don't replace entire personal input files with golden fixtures.

## Locate and pin a save

Saves are under the redirected profile's `gamesaves` folder, not assumed C:\Users\...\Documents.
Sort `ManualSave_*.sav` by modification time; pair the save with its `.png` thumbnail and `.json` build metadata.
Pin the actual `.sav` filename and SHA-256 plus exact visible manual-save timestamp/HUD labels in an explicit fixture JSON.
Filesystem and the actual save-list row showed Sunday October 11, **2026**, 11:15:54 AM; the user's typed 2025 year was a typo.
Use `mounted-clear-111554.json` with ManualSave_7af48_7ea4a800_2cfd8fb.sav, SHA-256 62e38d00c6cae22f034d9fcad47f582b9828e598c13d203a94acad80df241ebb.
The older 07:10:06 fixture remains supported without `--fixture`; never use Continue, which can select a newer autosave.
The save selector requires English 2560x1440, scans the first eleven visible rows, verifies selection borders and the final unique timestamp, then rechecks the save hash after replay.
It uses enlarged save-row OCR; `1 1` can stand for `11` only where the exact timestamp pattern permits whitespace.

```powershell
python game_test.py <scenario.json> --journal <development-install.json> --exe <DX12-executable> --save <explicit-sav-path> --fixture mounted-clear-111554.json --ffmpeg <ffmpeg-path>
python development_loop.py editor.json <scenario.json> --editor-pid <PID> --journal <development-install.json> --save <explicit-sav-path> --fixture mounted-clear-111554.json
```

## Reliable input and evidence

Game input uses scan codes with sufficient press/modifier settling; very short taps can disappear at low frame rates.
Console commands are whitelisted, typed, captured and checked against OCR of the **current prompt** before Enter; don't search console history for a matching command.
The prompt crop stays at original resolution; enlarging it can turn the cursor into i/j. Fresh frames may resolve blink ambiguity without additional inputs.
Counter reset must acknowledge `CC ride counters reset` before any gestures; otherwise refuse rather than accumulating stale totals.
Use controller **Back** for repeatable pause entry and keyboard menu navigation; repeated keyboard Escape reopening failed with alias routing enabled and disabled. Root cause unresolved.
Native Horse X/Stop between gestures reduces movement; it does not guarantee stationary/safe terrain throughout a long replay.
Hold and double-press-and-hold tests currently use calibrated 1s holds; expected native totals are exactly 10, Canter 3/3, Gallop 2/2, zero query mismatches and the selected alias.
Primary `callbacks` must start its own semicolon field; never accidentally read `pattern callbacks` as the total.
OCR can confuse equals/hyphen separators; exact numeric counts/context still matter. Balanced duplicate totals fail.
Read the lower-left notification crop, rather than asking full-screen OCR to find it against busy foliage.
Menu ordering is anchored beneath the unique SETTINGS header through BACK; background HUD above the heading is outside the menu rows.
DX12 HWND capture returned black; capture only the foreground game's physical desktop region. Stop input on foreground/process drift and release the virtual controller.
Fullscreen focus loss can hide the owned window; graceful WM_CLOSE may identify it by exact executable/PID/title even when hidden. Never force-kill or close another game instance as cleanup.
PS 5.1 is needed for Windows OCR/UIA. If inherited PS 7 modules hide Get-FileHash, set process-local PSModulePath to the WindowsPowerShell v1.0 Modules directory.
Sandbox process/window enumeration can hide live applications; use an approved interactive execution context for real desktop work.

## Verification policy — user decision

Routine checks should use one Current → Alt1 → Current round trip (two switches), with a diagram/fallback check only when the changed feature warrants it.
Use one representative positive case and relevant refusal case for similar reversible changes; don't repeat full suites without a new failure or material concern.
Long ten-switch stress tests are optional and require a specific regression/release purpose; don't rerun just to reach an arbitrary number.
The user accepted eight successful final-artifact switches as sufficient. Wild dogs interrupted the ninth; preserve the failed full receipt and the eight passing assertions separately.
Reducing repetitions does not permit wrong contexts, duplicate callbacks, query mismatches, unbalanced releases, changed owned files, ambiguous save selection or overwriting saves.
Callbacks are evidence of native dispatch, not proof of gait, all interactions, Ciri, quick-sign/glyph variants, held/focus/disconnect/new-game or universal mod compatibility.
Save results with logs/screenshots/OCR, source/artifact hashes, exact scenario and ownership/save cleanup checks; link `docs/phase1-evidence.md`.

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

User waived remaining Phase 1 manual gates on October 11, 2026; continue implementation using existing evidence and proportionate automated checks. Untested coverage is recorded as waived, never passed.

Final self-contained updater candidate: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase1-packages\20261011-123344-47d256d1\controller-customizer-phase1-candidate.zip
SHA-256: d1e569c4a9d80e08074f35a00dcdb3cb2a19a90cfe8e10d869347e2722b7ce16. Packaged updater checks pass; 36 manifest file hashes and exact archive inventory verified. Receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase1\updater-delivery.json
