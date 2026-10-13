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

## Phase 1.1 continuation

Read `docs/phase11-evidence.md` first; it supersedes the historical two-preset
baseline above. The eight canonical sources now match the full-scheme cook.
Generate-Assets checks both historical fixture assets and the full runtime.
Use explicit native input/Python paths or the existing machine configuration.
The development journal now identifies `Phase11Candidate`; default replay chooses
the three-choice smoke and verifies all registered alias multisets before launch.
The separate old eight-alias journal remains historical; it does not own the new
bank. The Phase 1.1 six-target migration journal owns that migration and rollback.
Use `Restore-FullSchemeCandidate.ps1 -JournalFile <migration/files.json>` for this
candidate, never the standalone Phase 1 restorer. Preserve the candidate directory
and its registered-alias receipt for ownership checks. Current native serialization
differences are explicitly pending parity, not silently counted as source matches.
No standalone schema-2 package has been created; old packaging tools refuse it.


## On-foot replay and crash continuation

Use `tools/automation/phase11-onfoot.json` explicitly; its mounted fixture loads
unchanged, stops the horse, initializes the console, holds native E to dismount,
then verifies one light-attack tap per scheme (vanilla X, both Souls RB).
The console whitelist includes ccProbeFootStart() and ccProbeFootStatus(). Reset
acknowledgement, native callback counts, query equality and selected raw Combat
or Exploration alias are required. The 0.15-second tap stays below the legacy
special-attack hold threshold. Keep the final preferred Alt1 selection.

After a reboot, rediscover processes; old editor/game PIDs are invalid. Verify
installed ownership and the pinned save before replay. Preserve partial passing
assertions and failed parent receipts separately; replay only missing cases when
artifact/scenario conditions agree. Do not infer crash causation from old queued
Windows Error Reporting dumps. Normal foreground drift stops all input.

For schema-2 development cooks use Update-RuntimeProbe.ps1: it keeps both the
active runtime and original migration rollback journals current in one file
transaction. Continue to use Restore-FullSchemeCandidate.ps1 for this migration.
The registered alias bank and original backups remain required ownership evidence.


REDkit cold reopen can ask to convert existing script/XML files to UTF-8. Select
No for the specifically observed encoding question; it preserves owned UTF-16
sources. The startup runner recognizes that prompt and leaves unrelated errors
untouched. Attached-editor cooks did not encounter it. After reboot rediscover
the editor PID; the old session's PID cannot be reused.

If game startup has no captured frames, consult startup-window-events.json.
Repeated Cannot focus target with a non-minimized owned window is a Windows
foreground-transfer failure, not gameplay evidence. Fresh owned startup permits
a brief native input-queue attachment to transfer focus, always detaching before
input. The ordinary replay guard still refuses all input on foreground drift.


## Current schema-2 standalone delivery and shared banks

The newer workflow supersedes the earlier standalone-unfinished notes above.
See docs/phase11-delivery.md. Use FullScheme-Mod.ps1 and Package-FullSchemeMod.ps1;
old Phase 1 tools still refuse schema 2. Keep installation original backups and
the sibling prepared/candidate directory. Standalone journals and development
journals are separate contracts; the game replay runner currently uses the owned
development journal, not a standalone journal.

84 logical selection entries now share 60 physical aliases; Alt1 uses DarkSoul's
identical non-riding contexts. Foot assertions allow that shared bank only for
Alt1; selected native Scheme is verified separately. Budget includes all personal
and existing probe contexts, and generation refuses more than 128 total contexts.
Do not mistake identical context sharing for losing a scheme's records.

For owned cleanup, select exact title/executable/PID and include hidden windows;
filter out hidden zero-size IME helpers. Wait for process exit, not only window
disappearance, before invoking a file transaction. Startup alone did not serialize
missing input.settings; retain that failed baseline evidence rather than guessing.


On-foot combat probes require a drawn weapon. Use the guarded `draw_sword` step
after dismount, before resetting counters. A sheathed first tap can merely draw
a weapon and return zero combat callbacks; do not reinterpret it as a pass.
The preferred Alt1 fixture passed one native RB press/release in shared Combat.

### Diagram and HUD regression procedure

Use `display-refresh.json` with `game_test.py --title-only` for title Settings,
then without that flag for the pinned mounted save. `scheme_switch` accepts
`inspect_diagram: true` to inspect the diagram before closing that same Settings
instance. Selection OCR after each arrow also proves the customizer remains open.
Native title Settings ends with INSTALLED; gameplay Settings ends with BACK.
Use one ViGEm device for D-pad, A and B throughout each menu flow; mixed keyboard
and pad navigation can miss transitions. XInput button/axis readback and finally
reset remain mandatory. `hint_capture` uses only a brief right-stick camera input
to select controller glyphs, then captures after HUD refresh; it never moves Geralt.

Save loading scans the first eleven visible rows, then uses bounded Down scrolling
with a confirmed last-row selection and changed row pixels. It loads only after
the exact manual timestamp is OCR-confirmed again, retaining the original file's
pinned SHA-256. Do not assume an older fixture remains on the first page.
Fresh-owned startup waits for exact The Witcher 3 title and may restore focus only
before the main menu is recognized. Later focus drift stops input. Cleanup uses
that exact title/executable/PID, including hidden windows, and waits for exit.

Diagram selection uses config directly, independently of gameplay routing/cache.
Native ControllerHelp regenerates mappings on explicit entry. Do not call
SendControllerData from customizer option changes: it opens the diagram popup.
The HUD wraps native feedback key queries with a scoped canonical context and
forces refresh after a changed gameplay context is restored.


## Phase 2 prototype continuation

See `docs/phase2-backend.md` for the read-only primitive and explicit X/L3 bank
experiments. Released Phase 1.1 is restored after their temporary transactions;
prototype sources remain only in the editor/repository. The latest verified
editor ownership baseline is
`outputs/phase2/horse-bank-hints-editor-v2/cooks/20261012-190318-7f789ec6`
in the automation workspace. Source sync uses that cook, not the release cook.
The `phase2-horse-bank.json` replay requires mounted Alt1 and Start enforces it;
no redundant Settings cycle is required when Scheme=2 is already persisted.
The bounded fixed bank does not establish arbitrary live Apply.

For camera-only controller hint captures, quarter-stick was below the effective
device-switch threshold in the mounted fixture. Half-stick for 0.4 seconds with
XInput readback 16000–16500 selects the controller HUD; release the stick before
capturing. This changes the camera only. A captured keyboard HUD is not evidence
for controller glyphs.

Native GetPadKeysForAction fallback did not produce the relocated logical key
expectations; derive prototype hints from uniquely owned physical primitive keys.
The native wrapper expansion rejected repeated wrappedMethod calls in one method.
Use one native wrapped call, then scoped queries of owned primitive names with
an explicit recursion termination guard. Retain failed compilation receipts.
If a failed cook lacks a new ownership baseline, verify the last source-sync
journal's installed hash before repairing that editor source as UTF-16 in a new
backed transaction; never disable the independent-edit guard.
