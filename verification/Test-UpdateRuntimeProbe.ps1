#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CookSnapshot, [string]$SourceGamePath='F:\Steam\steamapps\common\The Witcher 3')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$projectRoot=Split-Path $PSScriptRoot -Parent
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot=Join-Path $tempBase ('cc-update-' + [Guid]::NewGuid().ToString('N'))
function Get-OwnedHashes($GameRoot,$Journal) {
    return @($Journal.Items | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $GameRoot $_.RelativePath)).Hash }) -join '|'
}
try {
    $clone=Join-Path $testRoot 'project'
    $game=Join-Path $testRoot 'game'
    $cookRoot=Join-Path $testRoot 'cook'
    New-Item -ItemType Directory -Path $clone,(Join-Path $game 'bin\config\base'),(Join-Path $game 'bin\config\r4game\user_config_matrix\pc') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'tools'),(Join-Path $projectRoot 'src') -Destination $clone -Recurse
    Copy-Item -LiteralPath $CookSnapshot -Destination $cookRoot -Recurse
    $toolchain=Get-Content -LiteralPath (Join-Path $clone 'tools\compiler-toolchain.json') -Raw | ConvertFrom-Json
    foreach ($entry in $toolchain.BaseScriptSha256.PSObject.Properties) {
        $target=Join-Path (Join-Path $game 'content\content0\scripts') $entry.Name
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path (Join-Path $SourceGamePath 'content\content0\scripts') $entry.Name) -Destination $target
    }
    $general=Join-Path $game 'bin\config\base\general.ini'
    [IO.File]::WriteAllText($general,"[General]`r`nConfigVersion=7`r`n",[Text.UTF8Encoding]::new($false))
    $generalOriginal=(Get-FileHash -LiteralPath $general).Hash
    & (Join-Path $clone 'tools\Install-RuntimeProbe.ps1') -CookedOnly -CookSnapshot $cookRoot -GamePath $game | Out-Null
    $journalFile=@(Get-ChildItem -LiteralPath (Join-Path $clone 'work\runtime-probe') -Filter install.json -Recurse -File)[0].FullName
    $journal=Get-Content -LiteralPath $journalFile -Raw | ConvertFrom-Json
    # Simulate an older installed artifact, keeping the ownership journal accurate.
    foreach ($item in $journal.Items | Where-Object RelativePath -Like 'mods/*') {
        $target=Join-Path $game $item.RelativePath
        [IO.File]::WriteAllText($target,('previous artifact: ' + $item.RelativePath))
        $item.InstalledSha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()
    }
    $journal.RuntimeLoadVerified=$true
    $journal | Add-Member -NotePropertyName RuntimeEvidence -NotePropertyValue ([pscustomobject]@{ CompiledProbeLoadVerified=$true })
    $journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalFile -Encoding UTF8
    $oldJournalBytes=[IO.File]::ReadAllBytes($journalFile)
    $beforeHashes=Get-OwnedHashes $game $journal
    $updater=Join-Path $clone 'tools\Update-RuntimeProbe.ps1'
    $receiptFile=Join-Path $cookRoot 'cook.json'
    $receiptBytes=[IO.File]::ReadAllBytes($receiptFile)
    $receipt=Get-Content -LiteralPath $receiptFile -Raw | ConvertFrom-Json
    $receipt.CanonicalSourceSha256.'local/controllerCustomizer/contexts.ws'='stale'
    $receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptFile -Encoding UTF8
    $rejected=$false
    try { & $updater -JournalFile $journalFile -CookSnapshot $cookRoot | Out-Null } catch { $rejected=$true }
    if (-not $rejected -or (Get-OwnedHashes $game $journal) -cne $beforeHashes) { throw 'Stale cook mutated the installation.' }
    [IO.File]::WriteAllBytes($receiptFile,$receiptBytes)
    $blob=Join-Path $cookRoot 'packed\mods\modCustomizeControllerScheme\content\precompiled.rsblob'
    $blobBytes=[IO.File]::ReadAllBytes($blob)
    [IO.File]::AppendAllText($blob,'corrupt')
    $rejected=$false
    try { & $updater -JournalFile $journalFile -CookSnapshot $cookRoot | Out-Null } catch { $rejected=$true }
    if (-not $rejected -or (Get-OwnedHashes $game $journal) -cne $beforeHashes) { throw 'Corrupt cook mutated the installation.' }
    [IO.File]::WriteAllBytes($blob,$blobBytes)
    $menu=Join-Path $game 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'
    $menuBytes=[IO.File]::ReadAllBytes($menu)
    [IO.File]::AppendAllText($menu,'<!-- later edit -->')
    $changedHashes=Get-OwnedHashes $game $journal
    $rejected=$false
    try { & $updater -JournalFile $journalFile -CookSnapshot $cookRoot | Out-Null } catch { $rejected=$true }
    if (-not $rejected -or (Get-OwnedHashes $game $journal) -cne $changedHashes) { throw 'Later installed edits were overwritten.' }
    [IO.File]::WriteAllBytes($menu,$menuBytes)
    $metadata=Join-Path $game 'mods\modCustomizeControllerScheme\content\metadata.store'
    $lock=[IO.File]::Open($metadata,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {
        $rejected=$false
        try { & $updater -JournalFile $journalFile -CookSnapshot $cookRoot | Out-Null } catch { $rejected=$true }
        if (-not $rejected -or (Get-OwnedHashes $game $journal) -cne $beforeHashes) { throw 'Partial update did not roll back after a locked third file.' }
        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($journalFile)) -cne [Convert]::ToBase64String($oldJournalBytes)) { throw 'Failed update changed its journal.' }
    }
    finally { $lock.Dispose() }
    & $updater -JournalFile $journalFile -CookSnapshot $cookRoot | Out-Null
    $updated=Get-Content -LiteralPath $journalFile -Raw | ConvertFrom-Json
    if ($updated.RuntimeLoadVerified -or $updated.RuntimeEvidence.CompiledProbeLoadVerified -or -not $updated.RuntimeEvidence.PreviousArtifactObservations.CompiledProbeLoadVerified) { throw 'Fresh runtime evidence was falsely claimed or prior evidence lost.' }
    foreach ($item in $updated.Items) {
        if ((Get-FileHash -LiteralPath (Join-Path $game $item.RelativePath)).Hash.ToLowerInvariant() -cne $item.InstalledSha256) { throw 'Updated ownership hash mismatch.' }
    }
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($menu)) -cne [Convert]::ToBase64String($menuBytes)) { throw 'Menu bytes changed.' }
    foreach ($change in $updated.ArtifactUpdates[0].Changes) {
        $backup=Join-Path $updated.ArtifactUpdates[0].BackupDirectory ('backups\' + (Split-Path $change.RelativePath -Leaf))
        if ((Get-FileHash -LiteralPath $backup).Hash.ToLowerInvariant() -cne $change.OldHash) { throw 'Old artifact backup mismatch.' }
    }
    & (Join-Path $clone 'tools\Restore-RuntimeProbe.ps1') -JournalFile $journalFile | Out-Null
    if ((Get-FileHash -LiteralPath $general).Hash -cne $generalOriginal -or (Test-Path -LiteralPath $menu) -or (Test-Path -LiteralPath (Join-Path $game 'mods\modCustomizeControllerScheme'))) { throw 'Updated installation no longer restores correctly.' }
    Write-Output 'PASS: stale/corrupt cook and later edits refused; locked-file partial update rolled back; valid update retains backups; fresh runtime claims reset; uninstall remains byte-exact.'
}
finally {
    $resolved=[IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
