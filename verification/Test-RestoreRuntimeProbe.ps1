#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-probe-restore-' + [Guid]::NewGuid().ToString('N'))
$shell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    $game = Join-Path $testRoot 'game'
    $receipt = Join-Path $testRoot 'receipt'
    $general = Join-Path $game 'bin\config\base\general.ini'
    $blob = Join-Path $game 'mods\modCustomizeControllerScheme\content\precompiled.rsblob'
    $extra = Join-Path (Split-Path $blob -Parent) 'later-user-file.txt'
    New-Item -ItemType Directory -Path (Split-Path $general -Parent), (Split-Path $blob -Parent), $receipt -Force | Out-Null
    $original = [Text.Encoding]::UTF8.GetBytes("[General]`r`nConfigVersion=7`r`n")
    $backup = Join-Path $receipt 'general.before.ini'
    [IO.File]::WriteAllBytes($backup, $original)
    [IO.File]::WriteAllText($general, "[General]`r`nConfigVersion=7`r`nDBGConsoleOn=true`r`n")
    [IO.File]::WriteAllText($blob, 'owned probe')
    [IO.File]::WriteAllText($extra, 'preserve this')
    $generalHash = (Get-FileHash -LiteralPath $general).Hash.ToLowerInvariant()
    $journal = [ordered]@{
        SchemaVersion = 1; Purpose = 'Phase0LoadProbe'; GamePath = $game; Restored = $false
        Items = @(
            [ordered]@{ RelativePath = 'bin/config/base/general.ini'; ExistedBefore = $true; Backup = 'general.before.ini'; OriginalSha256 = (Get-FileHash -LiteralPath $backup).Hash.ToLowerInvariant(); InstalledSha256 = $generalHash },
            [ordered]@{ RelativePath = 'mods/modCustomizeControllerScheme/content/precompiled.rsblob'; ExistedBefore = $false; Backup = $null; OriginalSha256 = $null; InstalledSha256 = (Get-FileHash -LiteralPath $blob).Hash.ToLowerInvariant() }
        )
    }
    $journalPath = Join-Path $receipt 'install.json'
    [IO.File]::WriteAllText($journalPath, ($journal | ConvertTo-Json -Depth 6))
    [IO.File]::WriteAllText($blob, 'later edit')
    $preference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $refusal = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tools\Restore-RuntimeProbe.ps1') -JournalFile $journalPath 2>&1
        $refusalExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $preference }
    if ($refusalExit -eq 0 -or ($refusal -join "`n") -notmatch 'Owned file changed') { throw 'Later edit was not refused.' }
    if ((Get-FileHash -LiteralPath $general).Hash.ToLowerInvariant() -cne $generalHash) { throw 'Refusal partially restored another file.' }
    if ([IO.File]::ReadAllText($blob) -cne 'later edit') { throw 'Refusal erased later edit.' }
    [IO.File]::WriteAllText($blob, 'owned probe')
    & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tools\Restore-RuntimeProbe.ps1') -JournalFile $journalPath
    if ($LASTEXITCODE -ne 0) { throw 'Valid restoration failed.' }
    if ((Get-FileHash -LiteralPath $general).Hash -cne (Get-FileHash -LiteralPath $backup).Hash) { throw 'Original bytes not restored.' }
    if ((Test-Path -LiteralPath $blob) -or [IO.File]::ReadAllText($extra) -cne 'preserve this') { throw 'Owned-file removal failed to preserve later additions.' }
    Write-Output 'PASS: atomic refusal of later edits, byte-exact restoration, and preservation of unrelated additions (Windows PowerShell 5.1).'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
