#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$JournalFile)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$state = Get-Content -LiteralPath $JournalFile -Raw | ConvertFrom-Json
if ($state.Purpose -cne 'ControllerCustomizerPhase1' -or -not $state.InstallationComplete) { throw 'Invalid installation journal.' }
if ($state.Restored) { Write-Output 'Already restored.'; return }
$journal = Get-Content -LiteralPath $state.FileJournal -Raw | ConvertFrom-Json
if (-not $journal.InstallationComplete -or $journal.RolledBack) { throw 'Incomplete file transaction.' }
$entries = @()
$allowed = @($state.InputPath,
    (Join-Path $state.GamePath 'mods\modCustomizeControllerScheme\content\precompiled.rsblob'),
    (Join-Path $state.GamePath 'mods\modCustomizeControllerScheme\content\info.json'),
    (Join-Path $state.GamePath 'mods\modCustomizeControllerScheme\content\metadata.store'),
    (Join-Path $state.GamePath 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'),
    (Join-Path $state.GamePath 'mods\modDarkSoulsControllerScheme\content\scripts\game\gui\main_menu\ingamemenu\igmUtilities.ws'))
if (@($journal.Items).Count -notin @(5,6) -or @($journal.Items.Target | Sort-Object -Unique).Count -ne @($journal.Items).Count) { throw 'Invalid ownership inventory.' }
if ([IO.Path]::GetFullPath($state.InputPath) -ine [IO.Path]::GetFullPath((Join-Path $state.DocumentsPath 'input.settings'))) { throw 'Input escaped redirected profile.' }
$journalRoot = Split-Path ([IO.Path]::GetFullPath($JournalFile)) -Parent
for ($index=0; $index -lt $journal.Items.Count; $index+=1) {
    $item = $journal.Items[$index]
    if ($item.Target -inotIn $allowed -or [IO.Path]::GetFullPath($item.Backup) -ine (Join-Path $journalRoot ('backups\' + $index))) { throw 'Unexpected owned target or backup path.' }
    $before = Get-CCFileHash $item.Target
    if ($null -ne $item.OriginalSha256 -and (Get-CCFileHash $item.Backup) -cne $item.OriginalSha256) { throw 'Original backup changed.' }
    $bytes = $null
    if ($null -ne $item.OriginalSha256) { $bytes = [IO.File]::ReadAllBytes($item.Backup) }
    if ($before -cne $item.InstalledSha256) {
        if ($item.Target -ine $state.InputPath) { throw 'Owned game file changed; refusing restoration.' }
        Import-Module (Join-Path $PSScriptRoot 'PersonalContextProbe.psm1') -Force
        $utf8 = [Text.UTF8Encoding]::new($false,$true)
        $appendix = $utf8.GetString([Convert]::FromBase64String($state.AppendixBase64))
        $bytes = $utf8.GetBytes((Remove-PersonalContextSections -Text ($utf8.GetString([IO.File]::ReadAllBytes($item.Target))) -Appendix $appendix -Contexts $state.Contexts))
    }
    # Bound journal targets to the installed game or the single redirected input file.
    $gamePrefix = [IO.Path]::GetFullPath($state.GamePath).TrimEnd('\') + '\'
    $target = [IO.Path]::GetFullPath($item.Target)
    if ($target -ine [IO.Path]::GetFullPath($state.InputPath) -and -not $target.StartsWith($gamePrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Journal target escaped installation.' }
    $entries += [pscustomobject]@{ Target=$target; BeforeSha256=$before; Bytes=$bytes }
}
$restoreDirectory = Join-Path (Split-Path $state.FileJournal -Parent) ('restore-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$restoreJournal = Invoke-CCFileTransaction -Entries $entries -JournalDirectory $restoreDirectory
$state.Restored = $true
$state | Add-Member -NotePropertyName RestoreJournal -NotePropertyValue $restoreJournal -Force
Write-CCJournal $state $JournalFile
Write-Output 'Owned files restored; later unrelated input changes and all backups retained.'
