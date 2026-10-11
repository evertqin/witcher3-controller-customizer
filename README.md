# Witcher 3 Controller Customizer

PC mod for native in-game Current/Alt1 selection and matching controller diagrams.
Observed environment: Remaster 5.01, DX12, Xbox controller, input format 60.

| Preset | Canter | Gallop | Mounted interaction |
| --- | --- | --- | --- |
| Current | Hold A | Double-press A and hold | L3 |
| Alt1 | Hold L3 | Double-press L3 and hold | A |

Select **Settings > Controller Customizer** and resume gameplay without restarting.
The original Souls-controls launcher remains a separate project.

Phase 1 is accepted for continuation: eight successful switches and a later
two-switch automated smoke are recorded. Additional manual gates were waived;
untested coverage remains untested. Arbitrary buttons/gestures are Phase 2 work.
See [evidence](docs/phase1-evidence.md) and [compatibility](docs/compatibility.md).

## Build, install, update, restore

Use Windows PowerShell 5.1. A matching REDkit editor cook is required;
standalone compiler startup remains unreliable locally.
See [automation runbook](docs/automation-runbook.md) for the working editor workflow.

```powershell
.\tools\Package-Mod.ps1 -CookSnapshot <verified-editor-cook>
.\tools\Install-Mod.ps1 -CookSnapshot <verified-editor-cook> -GamePath <game> -DocumentsPath <profile>
.\tools\Update-Mod.ps1 -JournalFile <install.json> -CookSnapshot <verified-editor-cook>
.\tools\Restore-Backup.ps1 -JournalFile <install.json>
```

The installer requires a supported existing Souls Current/Alt1 input profile.
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

Default verification uses one Current/Alt1 round trip. Evidence distinguishes
native callback/query agreement from visual gait and broader gameplay coverage.
Controller Back is the tested pause entry; repeated keyboard Escape reopening
remains unresolved. No universal Ciri/device/renderer/script-mod support is claimed.

## Offline verification

```powershell
.\tools\Generate-Assets.ps1 -Check
.\verification\Test-Presets.ps1
.\verification\Test-GeneratedAssets.ps1
.\verification\Test-Installer.ps1 -CookSnapshot <verified-editor-cook>
.\verification\Test-Updater.ps1 -CookSnapshot <verified-editor-cook>
```

Golden input profiles are owned verification fixtures, never whole-file install
payloads. Their provenance is in [fixtures/legacy/PROVENANCE.md](fixtures/legacy/PROVENANCE.md).
Personal settings, saves, native game/SDK sources and local builds are excluded.
No new distribution license has been selected for the authored mod.
