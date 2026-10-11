#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$JournalFile)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$journalPath = [IO.Path]::GetFullPath($JournalFile)
$journalDirectory = Split-Path $journalPath -Parent
$journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($journal.SchemaVersion -ne 1 -or $journal.Purpose -cne 'Phase0LoadProbe') { throw 'Unsupported probe journal.' }
if ($journal.Restored) { throw 'Probe was already restored.' }
if (Get-Process -Name 'witcher3' -ErrorAction SilentlyContinue) { throw 'Close The Witcher 3 before restoring the probe.' }
$gameRoot = [IO.Path]::GetFullPath($journal.GamePath)
$allowed = @(
    'bin/config/base/general.ini',
    'bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml',
    'mods/modCustomizeControllerScheme/content/precompiled.rsblob',
    'mods/modCustomizeControllerScheme/content/info.json',
    'mods/modCustomizeControllerScheme/content/metadata.store'
)
$seen = @{}
# Preflight every item before restoring anything; retain later user edits.
foreach ($item in $journal.Items) {
    if ($item.RelativePath -cnotin $allowed -or $seen.ContainsKey($item.RelativePath)) { throw 'Unexpected or duplicate owned path.' }
    $seen[$item.RelativePath] = $true
    $target = Join-Path $gameRoot $item.RelativePath
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Owned file missing: $target" }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.InstalledSha256) {
        throw "Owned file changed after installation; refusing all restoration: $target"
    }
    if ($item.ExistedBefore) {
        $backup = [IO.Path]::GetFullPath((Join-Path $journalDirectory $item.Backup))
        if (-not $backup.StartsWith($journalDirectory.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Backup escapes journal directory.' }
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.OriginalSha256) { throw 'Original backup changed.' }
    }
}
foreach ($item in $journal.Items) {
    $target = Join-Path $gameRoot $item.RelativePath
    if ($item.ExistedBefore) {
        [IO.File]::WriteAllBytes($target, [IO.File]::ReadAllBytes((Join-Path $journalDirectory $item.Backup)))
    }
    else { Remove-Item -LiteralPath $target }
}
# Remove only empty, probe-owned directories; leave any later additions intact.
foreach ($relative in @('mods/modCustomizeControllerScheme/content', 'mods/modCustomizeControllerScheme')) {
    $directory = Join-Path $gameRoot $relative
    if ((Test-Path -LiteralPath $directory -PathType Container) -and @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $directory
    }
}
$journal.Restored = $true
[IO.File]::WriteAllText($journalPath, ($journal | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Output 'PASS: owned probe files restored; backups and personal gameplay settings retained.'
