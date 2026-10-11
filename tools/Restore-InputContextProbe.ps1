#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$JournalFile, [switch]$RemoveOwnedContexts)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Close Witcher 3 first.' }
$journalPath = (Resolve-Path -LiteralPath $JournalFile).ProviderPath
$journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($journal.SchemaVersion -ne 1 -or $journal.Purpose -cne 'Phase0PersonalInputContexts' -or $journal.Restored -or -not $journal.InstallationComplete) { throw 'Invalid or inactive input probe journal.' }
$backup = Join-Path (Split-Path $journalPath -Parent) 'input.before.settings'
if ((Get-FileHash -LiteralPath $backup).Hash.ToLowerInvariant() -cne $journal.OriginalSha256) { throw 'Original backup changed; refusing restoration.' }
$currentHash = (Get-FileHash -LiteralPath $journal.InputPath).Hash.ToLowerInvariant()
$before = [IO.File]::ReadAllBytes($backup)
if ($before.Length -ne $journal.OriginalLength) { throw 'Original backup length mismatch.' }
if ($RemoveOwnedContexts) {
    $appendix = Join-Path (Split-Path $journalPath -Parent) 'appendix.ini'
    if ((Get-FileHash -LiteralPath $appendix).Hash.ToLowerInvariant() -cne $journal.AppendixSha256) { throw 'Owned appendix changed; refusing removal.' }
    Import-Module (Join-Path $PSScriptRoot 'PersonalContextProbe.psm1') -Force
    $utf8 = [Text.UTF8Encoding]::new($false,$true)
    $current = [IO.File]::ReadAllBytes($journal.InputPath)
    $after = $utf8.GetBytes((Remove-PersonalContextSections -Text $utf8.GetString($current) -Appendix ([IO.File]::ReadAllText($appendix)) -Contexts $journal.Contexts))
    $removalBackup = Join-Path (Split-Path $journalPath -Parent) 'input.before-owned-removal.settings'
    if (Test-Path -LiteralPath $removalBackup) { throw 'Removal backup already exists; refusing to overwrite it.' }
    [IO.File]::WriteAllBytes($removalBackup,$current)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $restoredHash = ([BitConverter]::ToString($hasher.ComputeHash($after))).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
    $journal | Add-Member -NotePropertyName RemovalEvidence -NotePropertyValue ([ordered]@{ Mode='OwnedContextsOnly'; BeforeSha256=$currentHash; AfterSha256=$restoredHash; Backup=$removalBackup }) -Force
}
else {
    if ($currentHash -cne $journal.InstalledSha256) { throw 'Input changed since installation; refusing to overwrite later changes. Use -RemoveOwnedContexts to preserve unrelated changes.' }
    $after = $before
    $restoredHash = $journal.OriginalSha256
}
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Game started; no input restored.' }
if ((Get-FileHash -LiteralPath $journal.InputPath).Hash.ToLowerInvariant() -cne $currentHash) { throw 'Input changed during preflight; no input restored.' }
[IO.File]::WriteAllBytes($journal.InputPath,$after)
if ((Get-FileHash -LiteralPath $journal.InputPath).Hash.ToLowerInvariant() -cne $restoredHash) { throw 'Restored hash mismatch.' }
$journal.Restored = $true
$journal | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $journalPath -Encoding UTF8
if ($RemoveOwnedContexts) { Write-Output 'Removed only verified owned contexts; unrelated current bytes and removal backup retained.' }
else { Write-Output 'Restored original input bytes; backups retained.' }
