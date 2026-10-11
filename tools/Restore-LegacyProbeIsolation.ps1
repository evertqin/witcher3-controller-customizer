#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$JournalFile)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Close Witcher 3 first.' }
$journalPath = (Resolve-Path -LiteralPath $JournalFile).ProviderPath
$journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($journal.SchemaVersion -ne 1 -or $journal.Purpose -cne 'Phase0LegacyModIsolation' -or -not $journal.Disabled -or $journal.Restored) { throw 'Invalid or inactive isolation journal.' }
$gameRoot = [IO.Path]::GetFullPath($journal.GamePath).TrimEnd('\')
$original = [IO.Path]::GetFullPath($journal.OriginalPath)
$backup = [IO.Path]::GetFullPath($journal.BackupPath)
if ($original -ine (Join-Path $gameRoot 'mods\modDarkSoulsControllerScheme') -or
    -not $backup.StartsWith((Join-Path $gameRoot 'controllerCustomizerTestBackups') + '\',[StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path $backup -Leaf) -ine 'modDarkSoulsControllerScheme') { throw 'Unexpected restoration paths.' }
if (Test-Path -LiteralPath $original) { throw 'Original mod path already exists; refusing overwrite.' }
$root = Get-Item -LiteralPath $backup
$entries = @(Get-ChildItem -LiteralPath $backup -Recurse -Force)
if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -or @($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Reparse points are not supported.' }
$files = @($entries | Where-Object { -not $_.PSIsContainer })
if ($files.Count -ne @($journal.Files).Count) { throw 'Backup inventory changed; refusing restoration.' }
foreach ($file in $files) {
    $relative = $file.FullName.Substring($backup.Length + 1)
    $record = @($journal.Files | Where-Object RelativePath -CEQ $relative)
    if ($record.Count -ne 1 -or (Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant() -cne $record[0].Sha256) { throw "Backup file changed: $relative" }
}
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Game started; no restoration performed.' }
if (Test-Path -LiteralPath $original) { throw 'Original path appeared; no restoration performed.' }
Move-Item -LiteralPath $backup -Destination $original
foreach ($record in $journal.Files) {
    if ((Get-FileHash -LiteralPath (Join-Path $original $record.RelativePath)).Hash.ToLowerInvariant() -cne $record.Sha256) { throw 'Restored mod hash mismatch; retain journal.' }
}
$journal.Restored = $true
$journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
Write-Output 'Legacy diagram mod restored; personal input settings unchanged by this tool.'
