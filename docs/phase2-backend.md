# Phase 2: custom settings and runtime backend

Phase 1.1 is published as [v0.1.1](https://github.com/evertqin/witcher3-controller-customizer/releases/tag/v0.1.1).
Phase 2 resumes on `phase2-custom-bindings` from released commit `8b476f5`.
The installed Phase 1.1 build and original rollback journals are unchanged.

## Implemented starting point

`tools/automation/custom_bindings.py` creates a versioned, twelve-slot draft from
the fingerprint-checked **vanilla**, **darksoul**, or **darksoul-alt1** source.
The old `--preset data/presets/current.json` interface remains historical DarkSoul;
it does not mean vanilla. Native button and duration values are projected from
the selected immutable scheme, including inherited records.

Apply, Cancel and Restore Preset have separate behavior. The draft validates
inventory, digital buttons, press/duration candidates, timing bounds and declared
shared-button groups. Snapshots are copied. Apply requires an explicit atomic
runtime backend; backend rejection retains the active configuration.
This model is not an in-game editor or a proven live rebinding API.

`custom_binding_audit.py` audits candidate changes against the selected full
controller scheme and the complete personal context lineage. It reports unrelated
actions occupying the proposed button, later personal digital additions and
unresolved pattern dependencies. Duplicate records remain significant.
It never writes installed settings or approves runtime application.

```powershell
# Run from repository root; replace paths. Outputs must be new files.
$nativeInput = 'F:\Steam\steamapps\common\The Witcher 3\bin\config\r4game\legacy\base\input_qwerty.ini'
$profileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'The Witcher 3'
python tools/automation/custom_bindings.py --catalog data/actions.json --scheme darksoul-alt1 --native $nativeInput --output custom-draft.json
python tools/automation/custom_binding_audit.py --scheme darksoul-alt1 --native $nativeInput --personal (Join-Path $profileDir 'input.settings') --config custom-draft.json --output custom-audit.json
python -m unittest discover -s tools/automation -p 'test_custom*.py'
```

An empty conflict list is not runtime acceptance: pattern key dependencies,
native precedence and action lifecycle behavior still need tracing.
The catalog covers twelve historical riding slots; full gameplay editor coverage
is not implemented. Menu/recovery buttons and analog axes remain excluded.

## Initial verification — October 12, 2026

- Nine tests pass: draft isolation, staging/cancel/restore, rejected backend
  preservation, invalid configuration, contextual sharing, inherited conflicts,
  personal additions/duplicates and three-scheme projection.
- All three real pinned sources project twelve bindings and audit unchanged
  without new conflicts. This does not establish fresh-profile gameplay parity.
- Proposed Geralt Follow/Canter/Gallop on R3 with Gallop duration 0.5 seconds
  reports four occupied actions: CameraLock, EnablePhotoMode_Step2,
  HighlightObjective and TrackQuest. No action is silently suppressed.
- The three changed slots also report 24 pattern-dependency entries requiring
  native tracing, including duplicate records. Runtime apply stays disabled.
- Actual personal input contains 116 contexts. Its SHA-256 before/after is
  `53c540b6c85d0cf46c495cf8e90de4ef359a8104ca55aab992ca49244c342355`.
- Generated assets match. The checker now tolerates Git checkout LF/CRLF
  conversion while retaining exact content and source fingerprint checks.

Local receipt: `outputs/phase2/offline-start/result.json` in the automation workspace;
the candidate and detailed conflict report are alongside it. No game launch or
live input/artifact change was performed for this milestone.

## Next: first runtime proof

Trace a startup-loaded bank of native input primitives rather than enumerating
complete custom profiles. Select one primitive through desired custom settings,
route original horse query/listener consumers consistently, and prove a third
button plus changed duration with native callbacks and old-button suppression.
Select an unoccupied button or explicitly design how its existing actions move;
the R3 proposal above cannot be installed as-is.

Relevant inspected native entry points:

- `game/inputManager.ws`: GetAction/GetActionValue, pattern and key lookups,
  RegisterListener/UnregisterListener, ForceDeactivateAction.
- `game/vehicles/horse/states/exploration.ws`: speed listeners around line 125,
  unregister around 145, OnSpeedPress around 2839, OnSpeedHold around 2926.
- Horse double-tap window is 0.4 seconds, separate from native Duration.
- SInputAction fields are imported const; do not fabricate or rename event structs.

Trace physical dependencies of inherited/pattern actions, preserve personal
keyboard/axes/menu controls and fit within the native 128-context capacity.
Install experimental primitives only through a reversible ownership journal,
retaining the released Phase 1.1 artifact and its original rollback baseline.

Atomic apply must cover listener registration, queries, ignored input, releases,
old-button suppression, key lookup, persistence and keyboard coexistence.
No per-frame file polling, native DLL injection or exponential context inventory.
One representative positive mapping/gesture and its old-button negative case
are initial automated acceptance; no ten-switch quota or new manual sign-off.


## Native primitive bank proof — October 12, 2026

- [x] Bounded startup-loaded bank: one additional context (116 → 117), three
  native X actions (press, duration 0.3, duration 0.5), no profile enumeration.
- [x] Fresh REDkit script compilation and source/editor equivalence.
- [x] Real isolated PowerShell install/restore, changed-owned-file refusal,
  original journal restoration and preservation of a later F3 binding.
- [x] Live native primitive callback/value-query/key-lookup checks below/above
  both thresholds, plus an L3 negative case for these primitive actions.
- [ ] Route original Canter/Gallop consumers through a selected primitive and
  prove gameplay old-button suppression with keyboard/pattern coexistence.

| Input | Press callbacks | Duration 0.3 | Duration 0.5 |
| --- | --- | --- | --- |
| X, 0.15 seconds | 1/1 | 0/0 | 0/0 |
| X, 0.4 seconds | 1/1 | 1/1 | 0/0 |
| X, 0.8 seconds | 1/1 | 1/1 | 1/1 |
| L3, 0.15 seconds | 0/0 | 0/0 | 0/0 |

Each pair is press/release. All four assertions reported zero value/pattern-query
mismatches, three exact native X key lookups and the experimental raw context.
The original horse handlers and existing bindings remain unchanged in this
observer experiment: X still casts its existing Sign, and L3 still controls
native riding. The negative case proves primitive isolation, **not** gameplay
old-button suppression. No synthetic/renamed SInputAction event is used.

The experiment is disabled by default and uses unsaved observer fields. Explicit
`ccPrimitiveStart()` validates the extra context, attaches listeners only to
three owned primitive names, and resets counters. `ccPrimitiveStop()` unregisters
those listeners/deactivates their actions and restores normal preset context.
Probe cleanup attempts Stop only against the same foreground-owned process;
full process exit clears unsaved state. Existing controls/duplicate records are
copied without replacement. The experimental bank is installed separately from
normal delivery and removed after verification.

Verified cook: `outputs/phase2/primitive-editor/cooks/20261012-180640-1a22ccde`.
Eight authored sources and eight pinned native hooks; 52,564-byte compiled blob,
SHA-256 `21a93d3cc3ba606f2ee4e15eaf3d22b6816859992295044db20bbcaebc940176`.
Zero script errors; 51 outer resource diagnostics retained. Native startup logged
a CName collision involving two native names before loading completed; no assert
dialog was dismissed, and compilation subsequently passed. Keep that startup
observation separate from the verified script phase.

Automation workspace receipts:

- `outputs/phase2/primitive-integration-v3/result.json`: isolated transactions.
- `outputs/phase2/primitive-live-v2/result.json`: live experiment and restoration.
- `outputs/phase2/primitive-live-v2/game/20261013T011257Z-0027dff6/result.json`:
  owned game closed; pinned save unchanged; exact save selected after four scrolls.
- Nested `probes/20261013T011356Z-dcbb4253/result.json`: four strict assertions.

All eight tracked live files (five existing game files, two ownership journals
and personal input) returned byte-for-byte to their pre-experiment hashes.
The installed game uses the released Phase 1.1 artifact; the editor/canonical
sources retain this Phase 2 prototype for the next cook. Use the new cook above
as the editor-sync ownership baseline, not the earlier Phase 1.1 cook.

Thirty-two focused checks pass (18 automation adapters, nine custom draft/audit,
five primitive/rollback/assertion checks); generated sources match. The first
live replay remains failed: visually correct counts were rejected because OCR
read 1/l and 0/O. Numeric-field-only normalization fixed the parser; exact counts,
source, context, key count and duplicate-field rejection remain mandatory.
Earlier isolated attempts failed on inherited PowerShell module-path/temp
environment details; the successful fixture used the documented process-local
Windows PowerShell module path. Sandbox adapter tests also required a writable
workspace temp directory. Those failures are not runtime gameplay evidence.

Next implementation: capture/rebind original horse listeners, route queries and
key hints consistently, and preserve native keyboard/pattern events/releases.
Every Xbox horse button is already occupied; any third-button proposal must
explicitly relocate its existing action bank instead of silently removing it.
The full in-game editor, persistent custom configuration and atomic gameplay
Apply remain unimplemented.
