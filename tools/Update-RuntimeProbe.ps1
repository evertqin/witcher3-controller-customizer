#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$JournalFile, [Parameter(Mandatory)][string]$CookSnapshot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Close Witcher 3 first.' }
$journalPath = (Resolve-Path -LiteralPath $JournalFile).ProviderPath
$journalRoot = Split-Path $journalPath -Parent
$journalBytes = [IO.File]::ReadAllBytes($journalPath)
$journalHash = (Get-FileHash -LiteralPath $journalPath).Hash
$journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($journal.SchemaVersion -ne 1 -or $journal.Purpose -cne 'Phase0LoadProbe' -or $journal.Restored -or -not $journal.InstallationComplete) { throw 'Invalid or inactive probe journal.' }
$gameRoot = [IO.Path]::GetFullPath($journal.GamePath)
$snapshot = (Resolve-Path -LiteralPath $CookSnapshot).ProviderPath
$cook = Get-Content -LiteralPath (Join-Path $snapshot 'cook.json') -Raw | ConvertFrom-Json
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
if ($cook.SchemaVersion -ne 2 -or $cook.EvidenceKind -cne 'RedkitEditorCook' -or
    -not $cook.ScriptCompilationVerified -or -not $cook.SourceTextEquivalenceVerified -or
    $cook.UseLooseScripts -ne $false -or $cook.ScriptCompilationErrors.Count -ne 0 -or
    $cook.CompilerSha256 -cne $toolchain.CompilerSha256 -or
    $cook.ObservedBlobRelativePath -ine 'mods/modCustomizeControllerScheme/content/precompiled.rsblob') { throw 'Unverified editor cook.' }
if ((Get-FileHash -LiteralPath (Join-Path $snapshot 'cook.log')).Hash.ToLowerInvariant() -cne $cook.CookLogSha256) { throw 'Cook log changed.' }
foreach ($entry in $toolchain.BaseScriptSha256.PSObject.Properties) {
    $native = Join-Path (Join-Path $gameRoot 'content\content0\scripts') $entry.Name
    if ((Get-FileHash -LiteralPath $native).Hash.ToLowerInvariant() -cne $entry.Value -or $cook.BaseHookSha256.($entry.Name) -cne $entry.Value) { throw 'Native hook fingerprint changed.' }
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'src\scripts')).TrimEnd('\') + '\'
if (@(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.ws').Count -ne @($cook.CanonicalSourceSha256.PSObject.Properties).Count) { throw 'Source inventory changed.' }
foreach ($entry in $cook.CanonicalSourceSha256.PSObject.Properties) {
    $source = [IO.Path]::GetFullPath((Join-Path $sourceRoot $entry.Name))
    if (-not $source.StartsWith($sourceRoot,[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant() -cne $entry.Value) { throw 'Cook does not match current sources.' }
}
$allowed = @('mods/modCustomizeControllerScheme/content/precompiled.rsblob','mods/modCustomizeControllerScheme/content/info.json','mods/modCustomizeControllerScheme/content/metadata.store','bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml','bin/config/base/general.ini')
if (@($journal.Items).Count -ne $allowed.Count) { throw 'Unexpected ownership inventory.' }
$seen = @{}
foreach ($item in $journal.Items) {
    if ($item.RelativePath -cnotin $allowed -or $seen.ContainsKey($item.RelativePath)) { throw 'Unexpected or duplicate owned path.' }
    $seen[$item.RelativePath] = $true
    if ((Get-FileHash -LiteralPath (Join-Path $gameRoot $item.RelativePath)).Hash.ToLowerInvariant() -cne $item.InstalledSha256) { throw 'Installed probe changed; update refused.' }
}
$payloadRoot = [IO.Path]::GetFullPath((Join-Path $snapshot 'packed')).TrimEnd('\') + '\'
$content = Split-Path (Join-Path $payloadRoot $cook.ObservedBlobRelativePath) -Parent
$changes = @()
foreach ($name in @('precompiled.rsblob','info.json','metadata.store')) {
    $source = Join-Path $content $name
    $newHash = (Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
    if ($newHash -cne $cook.FileSha256.$name) { throw 'Cooked payload changed.' }
    if ($name -ceq 'precompiled.rsblob' -and ($cook.BlobLength -le 0 -or (Get-Item -LiteralPath $source).Length -ne $cook.BlobLength)) { throw 'Invalid compiled blob length.' }
    $relative = 'mods/modCustomizeControllerScheme/content/' + $name
    $item = @($journal.Items | Where-Object RelativePath -CEQ $relative)[0]
    $changes += [pscustomobject]@{ Name=$name; RelativePath=$relative; Source=$source; Target=(Join-Path $gameRoot $relative); OldHash=$item.InstalledSha256; NewHash=$newHash }
}
# Schema-2 development updates keep the original six-target rollback current.
if ($journal.PSObject.Properties.Name -contains 'Phase11Candidate') {
    Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
    $migrationPath=Join-Path $journal.Phase11Candidate.TransactionDirectory 'files.json'
    $migrationHash=Get-CCFileHash $migrationPath
    $migration=Get-Content -LiteralPath $migrationPath -Raw | ConvertFrom-Json
    if ($migration.Purpose -cne 'ControllerCustomizerPhase11DevelopmentMigration' -or
        -not $migration.InstallationComplete -or $migration.Restored -or $migration.RolledBack -or
        $migration.PreviousRuntimeJournal -ine $journalPath -or $migration.GamePath -ine $gameRoot -or
        $migration.CandidateDirectory -ine $journal.Phase11Candidate.CandidateDirectory -or
        @($migration.Items).Count -ne 6) { throw 'Invalid schema-2 migration ownership.' }
    $journalItem=@($migration.Items | Where-Object Target -IEQ $journalPath)
    if ($journalItem.Count -ne 1 -or $journalItem[0].InstalledSha256 -cne $journalHash.ToLowerInvariant()) { throw 'Migration runtime journal changed.' }
    $entries=@()
    foreach ($change in $changes) {
        $owned=@($migration.Items | Where-Object Target -IEQ $change.Target)
        if ($owned.Count -ne 1 -or $owned[0].InstalledSha256 -cne $change.OldHash) { throw 'Migration payload ownership disagrees.' }
        $owned[0].InstalledSha256=$change.NewHash
        @($journal.Items | Where-Object RelativePath -CEQ $change.RelativePath)[0].InstalledSha256=$change.NewHash
        $entries += [pscustomobject]@{Target=$change.Target;BeforeSha256=$change.OldHash;Bytes=[IO.File]::ReadAllBytes($change.Source)}
    }
    $run=Join-Path $journalRoot ('updates/artifacts-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    $history=[pscustomobject]@{CookSnapshot=$snapshot;BackupDirectory=$run;PreviousCookSnapshot=$journal.CookSnapshot;Changes=@($changes | Select-Object RelativePath,OldHash,NewHash);RuntimeVerified=$false}
    if ($journal.PSObject.Properties.Name -contains 'ArtifactUpdates') { $journal.ArtifactUpdates=@($journal.ArtifactUpdates) + $history }
    else { $journal | Add-Member -NotePropertyName ArtifactUpdates -NotePropertyValue @($history) }
    $journal.CookSnapshot=$snapshot
    $journal.RuntimeLoadVerified=$false
    $journal.Phase11Candidate.RuntimeLoadVerified=$false
    $journal.Phase11Candidate.GameplayVerified=$false
    $journal | Add-Member -NotePropertyName RuntimeEvidence -NotePropertyValue ([pscustomobject]@{CompiledProbeLoadVerified=$false;GameplayContextCorrectnessVerified=$false}) -Force
    $utf8=[Text.UTF8Encoding]::new($false)
    $newJournal=$utf8.GetBytes(($journal | ConvertTo-Json -Depth 20))
    $journalItem[0].InstalledSha256=([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($newJournal))).Replace('-','').ToLowerInvariant()
    $migration.CookSnapshot=$snapshot
    $migration.RuntimeLoadVerified=$false
    $migration.GameplayVerified=$false
    $entries += [pscustomobject]@{Target=$journalPath;BeforeSha256=$journalHash.ToLowerInvariant();Bytes=$newJournal}
    $entries += [pscustomobject]@{Target=$migrationPath;BeforeSha256=$migrationHash;Bytes=$utf8.GetBytes(($migration | ConvertTo-Json -Depth 20))}
    Invoke-CCFileTransaction -Entries $entries -JournalDirectory $run -Metadata @{Purpose='ControllerCustomizerPhase11DevelopmentUpdate'} | Out-Null
    Write-Output "PASS: compiled files and both ownership journals updated atomically; original migration rollback preserved. Backup: $run"
    return
}
$run = Join-Path $journalRoot ('updates\artifacts-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path (Join-Path $run 'backups'),(Join-Path $run 'payload') -Force | Out-Null
[IO.File]::WriteAllBytes((Join-Path $run 'journal.before.json'),$journalBytes)
foreach ($change in $changes) {
    Copy-Item -LiteralPath $change.Target -Destination (Join-Path $run ('backups\' + $change.Name))
    Copy-Item -LiteralPath $change.Source -Destination (Join-Path $run ('payload\' + $change.Name))
    if ((Get-FileHash -LiteralPath (Join-Path $run ('backups\' + $change.Name))).Hash.ToLowerInvariant() -cne $change.OldHash -or
        (Get-FileHash -LiteralPath (Join-Path $run ('payload\' + $change.Name))).Hash.ToLowerInvariant() -cne $change.NewHash) { throw 'Update backup/payload mismatch.' }
}
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Game started; no update performed.' }
if ((Get-FileHash -LiteralPath $journalPath).Hash -cne $journalHash) { throw 'Journal changed; no update performed.' }
foreach ($item in $journal.Items) {
    if ((Get-FileHash -LiteralPath (Join-Path $gameRoot $item.RelativePath)).Hash.ToLowerInvariant() -cne $item.InstalledSha256) { throw 'Installed file changed during preflight.' }
}
$written = @()
try {
    foreach ($change in $changes) {
        Copy-Item -LiteralPath (Join-Path $run ('payload\' + $change.Name)) -Destination $change.Target
        $written += $change
        if ((Get-FileHash -LiteralPath $change.Target).Hash.ToLowerInvariant() -cne $change.NewHash) { throw 'Updated payload hash mismatch.' }
        @($journal.Items | Where-Object RelativePath -CEQ $change.RelativePath)[0].InstalledSha256 = $change.NewHash
    }
    $history = [pscustomobject]@{ CookSnapshot=$snapshot; BackupDirectory=$run; PreviousCookSnapshot=$journal.CookSnapshot; Changes=@($changes | Select-Object RelativePath,OldHash,NewHash); RuntimeVerified=$false }
    if ($journal.PSObject.Properties.Name -contains 'ArtifactUpdates') { $journal.ArtifactUpdates = @($journal.ArtifactUpdates) + $history }
    else { $journal | Add-Member -NotePropertyName ArtifactUpdates -NotePropertyValue @($history) }
    $previousEvidence = if ($journal.PSObject.Properties.Name -contains 'RuntimeEvidence') { $journal.RuntimeEvidence } else { $null }
    $journal | Add-Member -NotePropertyName RuntimeEvidence -NotePropertyValue ([pscustomobject]@{ CompiledProbeLoadVerified=$false; GameplayContextCorrectnessVerified=$false; PreviousArtifactObservations=$previousEvidence }) -Force
    $journal.CookSnapshot = $snapshot
    $journal.EvidenceKind = 'RedkitEditorCook'
    $journal.BuildReport = $null
    $journal.RuntimeLoadVerified = $false
    [IO.File]::WriteAllText($journalPath,($journal | ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
    $history | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'update.json') -Encoding UTF8
}
catch {
    $failure = $_
    foreach ($change in $written) {
        if ((Get-FileHash -LiteralPath $change.Target).Hash.ToLowerInvariant() -cne $change.NewHash) { throw "Update failed and a target changed; retain backups at $run. Original failure: $failure" }
        Copy-Item -LiteralPath (Join-Path $run ('backups\' + $change.Name)) -Destination $change.Target
    }
    [IO.File]::WriteAllBytes($journalPath,$journalBytes)
    throw $failure
}
Write-Output "PASS: three cooked files updated; menu/console untouched; fresh runtime load unverified. Backup: $run"
