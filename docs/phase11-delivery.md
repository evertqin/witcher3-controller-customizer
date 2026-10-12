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
eight-source REDkit cook and seven native hook fingerprints, not extracted native
scripts or a personal profile/save. Script compilation passed; outer resource
diagnostics remain in cook.log.

```powershell
# Repository: create a new output directory using a cook matching current sources.
.\tools\Package-FullSchemeMod.ps1 -CookSnapshot <cook> -OutputDirectory <new-output> -PythonPath <python>

# Repository or extracted package root (package root itself is its cook snapshot):
.\tools\FullScheme-Mod.ps1 -Action install -GamePath <game> -InputPath <profile/input.settings> -CookSnapshot <cook-or-package> -JournalDirectory <new-backup-directory> -PythonPath <python>
.\tools\FullScheme-Mod.ps1 -Action update -JournalFile <install-directory/files.json> -CookSnapshot <new-cook-or-package> -JournalDirectory <new-update-directory> -PythonPath <python>
.\tools\FullScheme-Mod.ps1 -Action restore -JournalFile <install-directory/files.json> -JournalDirectory <new-restore-directory> -PythonPath <python>
```

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
