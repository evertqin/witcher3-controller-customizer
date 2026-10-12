# Phase 1.1 standalone development candidate

Three choices: Current (original), DarkSoul, DarkSoul Alt1.
84 logical selections share 60 physical banks across 28 gameplay contexts.
Personal plus owned contexts must remain within the observed 128-context limit.
Observed target: PC 5.01 DX12 / Xbox. This is a development candidate, not a
declaration of full native equivalence or support for other builds/devices.
The nine observed vanilla serialization changes remain an effective-gameplay
parity limitation. Ciri and alternate quick-sign display were statically audited
but have no live acceptance evidence. No additional manual gate is required.

Use Windows PowerShell 5.1 and Python 3. Package includes a fingerprint-verified
eight-source REDkit cook and eight native hook fingerprints, not extracted native
scripts or a personal profile/save. Script compilation passed; outer resource
diagnostics remain in cook.log.

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

## Update

Extract the new compiled package and open PowerShell in its root. Close the game.
Use the original install journal and a new directory for this update:

```powershell
$profileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'The Witcher 3'
$backupDir = Join-Path $profileDir 'ControllerCustomizer-backup'
$updateDir = Join-Path $profileDir ('ControllerCustomizer-update-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\FullScheme-Mod.ps1 `
    -Action update -JournalFile (Join-Path $backupDir 'files.json') `
    -CookSnapshot (Get-Location).Path -JournalDirectory $updateDir
```

## Developer packaging

Run from the source repository with a verified REDkit cook matching current sources.
Replace the example paths; the output directory must be new:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Package-FullSchemeMod.ps1 `
    -CookSnapshot 'C:\path\to\verified-cook' -OutputDirectory 'C:\path\to\new-package'
```

## Ownership and compatibility

Keep the install journal, original backups and its sibling `-prepared` directory.
Install refuses an existing customizer or conflicting legacy mod; use the owned
development migration/updater for existing development installations. Updates
preserve original uninstall backups and never rewrite personal input. Restoration
removes only semantically verified owned aliases and preserves later unrelated
input changes. Modified owned records/files refuse before any live write.
The exact previously observed engine serialization variant is accepted for
ownership only; arbitrary flag changes, missing records or extra contexts refuse.

Supported preparation starts from a flat known legacy or native digital binding
bank, including the exact observed vanilla serialization variant. Keyboard/mouse,
axes, patterns and comments remain personal. Missing contexts, inherited personal
contexts, independently customized digital records and unknown serialization
refuse instead of silently rewriting controls. An absent input.settings is not
created; initialize it normally in the game first. Fresh native profile preparation
has fixture coverage, not a live fresh-profile gameplay claim.

No console configuration, save, selected Scheme/old Preset, user.settings,
DX12 settings or menu-list file is changed. The native config wrapper migrates old
Preset 0/1 to DarkSoul/Alt1 and preserves an existing valid Scheme.
Runtime claims start false and remain separate from transaction success.
