# Phase 1 implementation evidence — October 11, 2026

Phase 1 implementation accepted for continuation; remaining manual gates waived by the user on October 11, 2026.
Observed local baseline: Remaster 5.01 DX12, input format 60, matching compiler and six native hook fingerprints; DX11 executable absent.

Eight authored sources provide startup alias validation, Current/Alt1 configuration, last-valid fallback, context storage/restoration, native menu saving and shared Souls/riding diagrams.
The dedicated Controller Customizer category uses native settings persistence; Current uses A to ride/L3 to interact, Alt1 reverses those buttons.
No extra native listener subscriptions, poller or savegame fields were introduced.
Arbitrary button/gesture editing remains Phase 2 work.

## Verified

- Final six-hook production cook: 18,499-byte blob, SHA-256 `dec1e4a026b696b31672fe4adc664cae05b798ef039fa49043f8e3326c50d468`; zero script-phase errors; outer cooking diagnostics retained, whole cook not error-free.
- Connected cook/install/load test: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\development\20261011T170913Z-7b88a025\result.json; Current startup routing, exactly 10 native callbacks, Canter 3/3, Gallop 2/2, zero query mismatches, native Exploration diagram and menu return; owned game closed and pinned save unchanged.
- Earlier ten alternating switches passed with two temporary passive diagnostic hooks; those hooks were removed before the final cook, so this is not final-artifact ten-switch acceptance.
- Final production artifact subsequently passed seven alternating switches and Alt1 native diagram pages; an eighth switch refused 20 balanced callbacks after a missing reset acknowledgement. Console delivery now requires exact current-prompt OCR and reset acknowledgement before gestures.
- Normal Xbox Alt1 Horse labels inspected; Current Horse was also inspected in the short final replay; Ciri and display variants remain pending.
- Twenty automation checks pass, including duplicate balanced callbacks, command mismatch, stale receipts and ambiguous menu refusal.
- Deterministic candidate archive built twice from the same frozen cook: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase1-packages\20261011-103620-57e2f447\controller-customizer-phase1-candidate.zip; SHA-256 `ba1c22bc35e5958df08880bdeaf7dc2f82904cde16cf851cc34d2a19db833acc`.

## Installation and rollback

Install-Mod validates source/hook/compiler/cook fingerprints and native input format before any mutation.
It copies four personal contexts into eight aliases, changes only twelve preset records, retains original input bytes/duplicates/keyboard/axes and refuses incompatible shared Souls bindings.
Five owned payloads receive hash-verified backups; explicit -IsolateLegacy only accepts the known legacy UI component.
Restore-Backup preflights every owned file and supports safe removal of aliases while preserving later unrelated input edits.
Installer checks cover redirected Documents paths, repeat installation/restoration, changed-file refusal, incompatible hooks/version/input, legacy conflict, partial rollback and unrelated mod preservation.
The actual development installation still uses its previous ownership journals and console-enabled probe setup; it was not silently migrated to the standalone installer.
Development_loop currently accepts the development journal schema, not a fresh Phase 1 installation journal.

## Additional coverage — waived as blocking manual gates

- User accepted eight final-artifact switches; later default two-switch smoke passed. Additional gait/interaction inventory is waived as a blocking manual gate.
- Ciri, ScriptedAction, swimming/boat/dialogue/combat transitions, on-foot and photo mode.
- Held-button switching, focus loss/disconnect gameplay recovery, new game and save-load regressions.
- Quick Sign casting, enlarged UI and other glyph families.
- Representative script/UI mod functionality; modFastTravelAnywhere remained installed but compatibility was not verified.
- Keyboard Escape reopening failed after riding with routing enabled and disabled; native controller Back works for replay. Root cause unresolved.

No renderer/device/universal mod support, storefront publication or release readiness is claimed.
The supplied 07:10:06 manual save is only loaded, never overwritten by the harness.

Latest guarded final-artifact replay: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\phase1\final-acceptance\20261011T175540Z-7e53072a\result.json; status `failed`, owned game closed `True`, pinned save unchanged `True`.
Native status assertions passed: 3; error: `Notification assertion missing/ambiguous: source=horse\s+handlers`.
Final canonical installer checks: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase1\installer-final-check.log; self-contained package checks: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase1\package-installer-final-check.log; both passed. Exact 35-file archive inventory and all hashes verified.

Short Current diagram/fallback replay: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\phase1\current-diagram-fallback\20261011T180505Z-1e243e3b\result.json; status `evidence_collected`, owned closure `True`, save unchanged `True`.
Observed assertions: [{"scope": "native_callback_and_query_only", "callbacks": 10, "canter_edges": [3, 3], "gallop_edges": [2, 2], "query_mismatches": 0, "last_context": "CC_PROBE_Current_Horse", "gameplay_release_verified": false}, {"scope": "preset_fallback_state_machine", "last_valid_retained": true, "original_restored": true}]; error `none`.

## Clear mounted fixture — 11:15:54 AM, October 11, 2026

User supplied a safer mounted save; filesystem timestamp establishes 2026, correcting the typed 2025 year.
Filename `ManualSave_7af48_7ea4a800_2cfd8fb.sav`, SHA-256 `62e38d00c6cae22f034d9fcad47f582b9828e598c13d203a94acad80df241ebb`.
Explicit --fixture pins filename/hash/visible timestamp and HUD labels; the earlier fixture remains supported without that option.
Twenty-one adapter/runner checks pass, including refusal of wrong years/times/autosaves.
Final production cook remains unchanged; no mod source or game installation edits were needed.

Replay: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\phase1\clear-fixture-acceptance\20261011T183259Z-db8e6d15\result.json
Status: `failed`; successful native riding assertions: 8; error: `No useful Canter/Gallop callback evidence`.
Owned game closed: `True`; save unchanged: `True`.

User accepted eight successful switches as sufficient on October 11, 2026; further replay stopped at their request.
The ninth attempt encountered wild dogs and dismounted Geralt, producing zero horse callbacks; the guard stopped correctly.
The eight completed switches each passed exact 10 callbacks, Canter 3/3, Gallop 2/2 and zero query mismatches on the final artifact.
The full ten-switch scenario remains recorded as failed, rather than relabeled successful; the accepted callback evidence consists of those eight switches.
No shorter-duration gesture change was retained or tested live.
Broader interaction/Ciri/held-input/focus/disconnect/new-game/device and cross-mod acceptance remain pending.

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

## Standalone updates and user acceptance decision — October 11, 2026

User explicitly waived remaining manual verification gates and accepted Phase 1
for continuation. Untested Ciri/variants/transition/mod cases remain untested;
they do not block further implementation or justify additional sign-off requests.
Recorded keyboard Escape failure remains visible; controller Back is tested.

Update-Mod.ps1 now supports standalone Phase 1 install journals. Updates verify
cook/source/native fingerprints and alias multisets, preserve personal input
byte-for-byte, retain original uninstall backups, and atomically update changed
compiled/menu files with the ownership journal. New artifacts clear old runtime
and release verification flags. Development-loop journal support remains separate.
Isolated verification/Test-Updater.ps1 checks pass; the live development install
and compiled eight-source artifact were unchanged by this tooling work.

Final self-contained updater candidate: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase1-packages\20261011-123344-47d256d1\controller-customizer-phase1-candidate.zip
SHA-256: d1e569c4a9d80e08074f35a00dcdb3cb2a19a90cfe8e10d869347e2722b7ce16. Packaged updater checks pass; 36 manifest file hashes and exact archive inventory verified. Receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase1\updater-delivery.json
