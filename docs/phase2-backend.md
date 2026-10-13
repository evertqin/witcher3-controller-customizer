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
