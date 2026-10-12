#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$JournalFile,
      [string]$PythonPath='python')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$journalPath=(Resolve-Path -LiteralPath $JournalFile).ProviderPath
$root=Split-Path $journalPath -Parent
$journal=Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($journal.Purpose -cne 'ControllerCustomizerPhase11DevelopmentMigration' -or -not $journal.InstallationComplete -or $journal.RolledBack) { throw 'Invalid full-scheme migration journal.' }
if ($journal.Restored) { Write-Output 'Already restored.'; return }
$allowed=@($journal.InputPath,$journal.PreviousRuntimeJournal,
    (Join-Path $journal.GamePath 'mods/modCustomizeControllerScheme/content/precompiled.rsblob'),
    (Join-Path $journal.GamePath 'mods/modCustomizeControllerScheme/content/info.json'),
    (Join-Path $journal.GamePath 'mods/modCustomizeControllerScheme/content/metadata.store'),
    (Join-Path $journal.GamePath 'bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml'))
if (@($journal.Items).Count -ne 6 -or @($journal.Items.Target | Sort-Object -Unique).Count -ne 6) { throw 'Unexpected migration inventory.' }
$entries=@()
for ($index=0;$index -lt $journal.Items.Count;$index++) {
    $item=$journal.Items[$index]
    if ($item.Target -inotIn $allowed -or [IO.Path]::GetFullPath($item.Backup) -ine (Join-Path $root ('backups/' + $index))) { throw 'Unexpected migration target or backup.' }
    if ((Get-CCFileHash $item.Backup) -cne $item.OriginalSha256) { throw 'Migration backup changed.' }
    $before=Get-CCFileHash $item.Target
    $bytes=[IO.File]::ReadAllBytes($item.Backup)
    if ($item.Target -ieq $journal.InputPath) {
        if ($before -cne $item.InstalledSha256) {
            $prepared=Join-Path $root ('restore-input-' + [guid]::NewGuid().ToString('N') + '.settings')
            & $PythonPath (Join-Path $PSScriptRoot 'automation/remove_scheme_aliases.py') --candidate $journal.CandidateDirectory --personal-input $item.Target --output $prepared
            if ($LASTEXITCODE -ne 0) { throw 'Changed owned alias; restoration refused.' }
            $bytes=[IO.File]::ReadAllBytes($prepared)
        }
    }
    elseif ($before -cne $item.InstalledSha256) { throw 'Owned game file or runtime journal changed; restoration refused.' }
    $entries += [pscustomobject]@{Target=$item.Target;BeforeSha256=$before;Bytes=$bytes}
}
$updated=$journal | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$updated.Restored=$true
$entries += [pscustomobject]@{Target=$journalPath;BeforeSha256=(Get-CCFileHash $journalPath);Bytes=([Text.UTF8Encoding]::new($false)).GetBytes(($updated | ConvertTo-Json -Depth 12))}
$restoreDirectory=Join-Path $root ('restore-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
Invoke-CCFileTransaction -Entries $entries -JournalDirectory $restoreDirectory -Metadata @{Purpose='ControllerCustomizerPhase11Restore'} | Out-Null
Write-Output 'PASS: previous runtime restored; later unrelated personal edits and backups retained.'
