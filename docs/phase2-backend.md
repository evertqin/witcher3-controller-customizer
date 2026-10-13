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


## Explicit occupied-button bank experiment — October 12, 2026

`primitive_bank.py --mode horse-swap` stages a single, startup-loaded Xbox horse
context. It exchanges the **entire** occupied X/L3 digital banks: VehicleCastSign
moves to L3; Follow, Canter, Gallop and EnablePhotoMode_Step1 move to X. Only the
Xbox Gallop duration changes from 0.3 to 0.5 seconds. Every original context stays
unchanged; keyboard, axes, patterns and meaningful duplicates in the added bank
remain intact. Unknown/changed X/L3 occupants refuse before installation.
The observer-only mode remains the default. A unique CCP_SWAP_SIGN marker
identifies the relocated bank for native primitive-based key hint lookup.

This is a **fixed startup-loaded proof**, not the arbitrary live Apply backend.
It uses the original logical Canter/Gallop names and unchanged native horse
listeners/handlers, with no fabricated SInputAction or query multiplexing.
Selecting the bank demonstrates dispatch and query agreement; it does not solve
dynamic keyboard/primitive aggregation or justify enumerating custom profiles.
Full custom persistence, menu editor and diagrams remain unimplemented.
Apply while held, focus/disconnect recovery, gait animations, Sign/PhotoMode
gameplay and live pattern combinations were not accepted by this replay.

Explicit Start now refuses unless mounted in Horse with effective Scheme=2.
The transaction reconstructs the declared bank from the verified current input,
so changing hashes/metadata cannot authorize arbitrary input changes. Restoration
uses the existing six-target experiment journal, retaining original rollback
backups and later unrelated personal edits.

`phase2-horse-bank.json` runs direct guarded probes, avoiding an unnecessary
Settings cycle when the persisted preferred scheme already matches.
Keyboard riding checks both preserved native Shift bindings before sending input.
Strict counters require balanced releases, zero query/foreign-context mismatches,
the exact experimental raw context, and exact X/X/L3 native key lookups.

| Input | Native Canter press/release | Native Gallop press/release |
| --- | --- | --- |
| X hold 0.4 seconds | 1/1 | 0/0 |
| X hold 0.8 seconds | 1/1 | 1/1 |
| Old L3 hold 0.8 seconds | 0/0 | 0/0 |
| Native left Shift hold 0.4 seconds | 1/1 | 1/1 |

All four assertions passed with three exact key lookups and zero query/foreign
mismatches. The keyboard retains its original 0.3-second threshold. This proves
the old Xbox speed button is suppressed for the native horse consumers while
keyboard dispatch/releases coexist with the changed Xbox duration.

Verified cook: `outputs/phase2/horse-bank-hints-editor-v2/cooks/20261012-190318-7f789ec6`.
Eight authored scripts and eight pinned native hooks; 53,883-byte
blob SHA-256 `6b5ee300c9917e19c771c2d662b9d5c939cee12d41ea4390b3ee3a00384a26ef`.
Zero script errors; 51 outer resource diagnostics retained.

Workspace evidence:

- `outputs/phase2/horse-bank-hints-integration/result.json`: real isolated install,
  owned drift refusal, original journal restoration and later F3 preservation.
- `outputs/phase2/horse-bank-hints-live/result.json`: full replay plus byte-exact
  restoration of all eight tracked live files.
- `outputs/phase2/horse-bank-hints-live/game/20261013T020359Z-8072e2e3/result.json`:
  owned game closed, exact save selected after 4 scrolls, pinned SHA unchanged.
- `outputs/phase2/horse-bank-hints-live/game/20261013T020359Z-8072e2e3/probes/20261013T020501Z-2b5629e9/result.json`:
  four assertions and screenshots; final controller hint capture is retained.

Earlier receipts remain failed: `horse-bank-live` stopped at controller pause
entry, and `horse-bank-live-direct` reached correct Canter edges but failed all
three native logical key expectations. Primitive-based hint routing corrected
that failure. `horse-bank-hints-editor` failed script compilation because this
native wrapper expansion rejected repeated wrappedMethod calls. The correction
uses one wrappedMethod call and guarded recursion for unique primitive names;
the successful cook above verifies it. The failed editor source was repaired
only after its hash matched the preceding ownership sync journal, with UTF-16
backup retained; the specific owned error dialog was closed through resolved
native control geometry. No unknown dialog was bypassed.

Thirty-six focused Python checks, Generate-Assets -Check and Git whitespace checks
pass. Released Phase 1.1 remains installed. The successful cook above becomes
the next editor-source ownership baseline. No new manual gate or repetition
quota was added.

Next: route selected primitives to original consumers while preserving aggregate
keyboard/pattern queries and releases; prove atomic custom Apply/Cancel/Restore
before exposing an in-game editor. This fixed bank does not complete those gates.


### Controller HUD supplement

The initial final hint screenshot still showed keyboard labels: quarter-stick
camera input did not select controller UI in this fixture. The camera-only hint
step now sends half-stick for 0.4 seconds and verifies independent XInput
readback (16000–16500), then releases it. Geralt movement is unaffected.
One separate short replay of the unchanged cooked artifact was visually checked:
Canter X, Gallop X and Dismount B appear together. The native Gallop instruction
still says Press Twice; this is consistent with the unchanged horse double-tap
logic, not proof of a new standalone hold-to-gallop gameplay gesture.
Do not infer gait animation or general custom gesture acceptance from callbacks.

Receipt: `outputs/phase2/horse-bank-hud-live/result.json`.
Image: `outputs/phase2/horse-bank-hud-live/game/20261013T020908Z-d29c4a1e/probes/20261013T021018Z-7eb3096f/02-hint_capture.png`.
Owned game closed, pinned save unchanged and all eight tracked files restored
byte-for-byte. The four earlier native consumer assertions remain the evidence
for the identical cooked source and bank; they were not repeated for this capture.

Candidate next backend experiment: duplicate each logical action's preserved
keyboard/pattern records into its physical primitive candidate, allowing the
engine to aggregate both devices into one immutable native SInputAction. Then
select that candidate for native listeners and queries together. This avoids
trying to fabricate an aggregate const struct from two independent events.
The approach is uncompiled/unverified; action-name-sensitive consumers and held
Apply still require explicit audit before widening beyond the horse prototype.
