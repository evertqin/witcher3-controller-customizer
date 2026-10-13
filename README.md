# Witcher 3 Controller Customizer

PC mod development for Current (original), DarkSoul and DarkSoul Alt1 selection
and matching native controller diagrams. Phase 1.1 is the accepted release scope.
Observed environment: Remaster 5.01, DX12, Xbox controller, input format 60.

| Preset | Canter | Gallop | Mounted interaction |
| --- | --- | --- | --- |
| Current (original) | Hold A | Double-press A and hold | Native defaults |
| DarkSoul | Hold A | Double-press A and hold | L3 |
| DarkSoul Alt1 | Hold L3 | Double-press L3 and hold | A |

Select **Settings > Controller Customizer** and resume gameplay without restarting.
The original Souls-controls launcher remains a separate project.

Historical Phase 1 was accepted for continuation: eight successful switches and a later
two-switch automated smoke are recorded. Additional manual gates were waived;
untested coverage remains untested. Phase 2 custom buttons/gestures are deferred;
committed experiments remain on the [phase2-custom-bindings feature branch](https://github.com/evertqin/witcher3-controller-customizer/tree/phase2-custom-bindings).
See [evidence](docs/phase1-evidence.md) and [compatibility](docs/compatibility.md).

## Development build and migration

Phase 1.1 uses `Generate-Assets.ps1 -Check`, the REDkit editor cook, and the
explicit `Install-FullSchemeCandidate.ps1` development migration. Preserve its
`files.json` transaction and candidate directory; rollback uses
`Restore-FullSchemeCandidate.ps1 -JournalFile <migration/files.json>`. Full native
parity remains pending; standalone schema-2 transactions now have isolated verification. See
[Phase 1.1 evidence](docs/phase11-evidence.md).

## Install

Extract the compiled `controller-customizer-phase11-candidate.zip`, then open
PowerShell in the extracted folder containing `tools` and `cook.json`.
GitHub's source ZIP is not a compiled package; developers must cook and package it first.
Requires Windows PowerShell 5.1 and Python 3 available as `python`.
REDkit, FFmpeg and ViGEm are only needed for development/testing.

Close the game. Set your game path below; Documents is resolved automatically,
including OneDrive redirection. If your profile lives elsewhere, set `$profileDir`.
The backup directory must not already exist.

```powershell
$gameDir = 'F:\Steam\steamapps\common\The Witcher 3' # Change for your installation.
$profileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'The Witcher 3'
$backupDir = Join-Path $profileDir 'ControllerCustomizer-backup'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\FullScheme-Mod.ps1 `
    -Action install -GamePath $gameDir -InputPath (Join-Path $profileDir 'input.settings') `
    -CookSnapshot (Get-Location).Path -JournalDirectory $backupDir
```

Wait for `PASS: install completed`, then launch the game and open
**Settings > Controller Customizer**. Keep the extracted package, backup directory
and its sibling `ControllerCustomizer-backup-prepared` for updates/uninstall.
If Python is not on PATH, add `-PythonPath 'C:\path\to\python.exe'` to each command.

Install refuses an existing customizer or conflicting `modDarkSoulsControllerScheme`.
Existing installations must use their own update/restore journal; the development
migration uses `Restore-FullSchemeCandidate.ps1`, not this standalone uninstall.
If `input.settings` is missing, launch the game and initialize controls first.

## Uninstall

Close the game and open PowerShell in the retained extracted package folder.
Use the **original install** backup directory, including after updates:

```powershell
$profileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'The Witcher 3'
$backupDir = Join-Path $profileDir 'ControllerCustomizer-backup'
$restoreDir = Join-Path $profileDir ('ControllerCustomizer-uninstall-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\FullScheme-Mod.ps1 `
    -Action restore -JournalFile (Join-Path $backupDir 'files.json') -JournalDirectory $restoreDir
```

`PASS: restore completed` confirms uninstall. It removes owned mod files/control
aliases and preserves unrelated personal bindings, including later edits.
Keep backups until restoration succeeds; deleting only the mod folder leaves input aliases.

See [delivery details](docs/phase11-delivery.md) for updates and developer packaging.
The standalone installer checks the observed Remaster 5.01 DX12 target and preserves
personal bindings/backups. This remains a development candidate; full native
effective parity is not claimed.

## Historical Phase 1 delivery

Use Windows PowerShell 5.1. A matching REDkit editor cook is required;
standalone compiler startup remains unreliable locally.
See [automation runbook](docs/automation-runbook.md) for the working editor workflow.

```powershell
.\tools\Package-Mod.ps1 -CookSnapshot <verified-editor-cook>
.\tools\Install-Mod.ps1 -CookSnapshot <verified-editor-cook> -GamePath <game> -DocumentsPath <profile>
.\tools\Update-Mod.ps1 -JournalFile <install.json> -CookSnapshot <verified-editor-cook>
.\tools\Restore-Backup.ps1 -JournalFile <install.json>
```

Those historical installer/updater/packager commands refuse this schema-2 branch.
The released Phase 1 installer requires a supported existing Souls Current/Alt1 input profile.
It preserves personal keyboard/axis/unowned bindings and meaningful duplicates.
Keep its verified backups and ownership journal. Updates preserve personal input;
uninstall removes verified owned contexts while retaining later unrelated edits.
Explicit `-IsolateLegacy` only accepts the identified unchanged legacy diagram file.
Existing development probe journals use a separate updater; do not mix schemas.

## Automated development loop

`tools/automation` combines native REDkit UI controls, guarded artifact updates,
ViGEm controller input, exact manual-save selection, screenshots and OCR assertions.
Edit `editor.json` for your installation; supplied scenarios/fixtures reflect the
recorded local English 2560x1440 environment and require your own pinned save.
Python 3, FFmpeg and the ViGEmBus driver are required; the vendored client includes
its license and provenance. Run from `tools/automation`:

```powershell
python save_fixture.py list --profile <profile>
python development_loop.py editor.json --sync-sources --editor-pid <verified-PID> --journal <development-install.json> --save <manual-sav> --fixture <fixture.json>
```

Default verification follows the installed journal: one three-choice cycle for
Phase 1.1, or one Current/Alt1 round trip for historical Phase 1. Evidence distinguishes
native callback/query agreement from visual gait and broader gameplay coverage.
Controller Back is the tested pause entry; repeated keyboard Escape reopening
remains unresolved. No universal Ciri/device/renderer/script-mod support is claimed.

## Offline verification

```powershell
.\tools\Generate-Assets.ps1 -Check
.\verification\Test-Presets.ps1
.\verification\Test-GeneratedAssets.ps1
python -m unittest discover -s tools/automation -p test_adapters.py
python -m unittest discover -s tools/automation -p test_full_schemes.py
python -m unittest discover -s tools/automation -p test_scheme_alias_removal.py
```

Golden input profiles are owned verification fixtures, never whole-file install
payloads. Their provenance is in [fixtures/legacy/PROVENANCE.md](fixtures/legacy/PROVENANCE.md).
Personal settings, saves, native game/SDK sources and local builds are excluded.
No new distribution license has been selected for the authored mod.

## Phase 2 development

The local `phase2-custom-bindings` branch adds the custom draft/validation model.
See [backend work](docs/phase2-backend.md). Live arbitrary routing and the in-game
editor remain unimplemented; Phase 1.1 is now the installed development candidate.

## Phase 1.1 scope

Active: **Current (original vanilla), DarkSoul, DarkSoul Alt1**, porting the full
legacy controller schemes before the Phase 2 editor. DarkSoul Alt1 is preferred.
See [Phase 1.1 scope](docs/phase11-scope.md); native serialization parity remains engineering work; standalone delivery is implemented.

### Active Phase 1.1 development candidate

The development installation now offers **Current (original)**, **DarkSoul** and
**DarkSoul Alt1**, with full gameplay context routing. Old `Preset=0` migrates to
DarkSoul, preserving behavior. Source generation and the fresh REDkit script phase
pass; three riding callback traces are recorded. This is an in-progress candidate:
native serialization parity remains open; on-foot and display evidence and standalone delivery are recorded.
Historical Phase 1 install/update/package tools refuse the new schema. See
[Phase 1.1 evidence](docs/phase11-evidence.md) and [scope](docs/phase11-scope.md).
