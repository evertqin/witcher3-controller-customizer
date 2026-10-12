#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$JournalFile, [Parameter(Mandatory)][string]$CookSnapshot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
if (Test-Path -LiteralPath (Join-Path $projectRoot 'data/schemes/runtime-baseline.json')) { throw 'This historical Phase 1 tool cannot install/package selection schema 2; use the Phase 1.1 candidate workflow.' }
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$journalPath = (Resolve-Path -LiteralPath $JournalFile).ProviderPath
$journalRoot = Split-Path $journalPath -Parent
$journalHash = Get-CCFileHash $journalPath
$state = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($state.SchemaVersion -ne 1 -or $state.Purpose -cne 'ControllerCustomizerPhase1' -or
    $state.Restored -or $state.RolledBack -or -not $state.InstallationComplete -or
    [IO.Path]::GetFullPath($state.FileJournal) -ine $journalPath) { throw 'Invalid or inactive Phase 1 journal.' }
$gameRoot = [IO.Path]::GetFullPath($state.GamePath)
$inputPath = [IO.Path]::GetFullPath((Join-Path $state.DocumentsPath 'input.settings'))
if ([IO.Path]::GetFullPath($state.InputPath) -ine $inputPath) { throw 'Input escaped redirected profile.' }
$targets = @(
    (Join-Path $gameRoot 'mods\modCustomizeControllerScheme\content\precompiled.rsblob'),
    (Join-Path $gameRoot 'mods\modCustomizeControllerScheme\content\info.json'),
    (Join-Path $gameRoot 'mods\modCustomizeControllerScheme\content\metadata.store'),
    (Join-Path $gameRoot 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'))
$legacyTarget = Join-Path $gameRoot 'mods\modDarkSoulsControllerScheme\content\scripts\game\gui\main_menu\ingamemenu\igmUtilities.ws'
$allowed = @($inputPath) + $targets + @($legacyTarget)
if (@($state.Items).Count -notin @(5,6) -or @($state.Items.Target | Sort-Object -Unique).Count -ne @($state.Items).Count) { throw 'Invalid ownership inventory.' }
foreach ($required in (@($inputPath) + $targets)) {
    if (@($state.Items | Where-Object Target -IEQ $required).Count -ne 1) { throw 'Missing owned target.' }
}
for ($index=0; $index -lt $state.Items.Count; $index+=1) {
    $item = $state.Items[$index]
    if ($item.Target -inotIn $allowed -or [IO.Path]::GetFullPath($item.Backup) -ine (Join-Path $journalRoot ('backups\' + $index))) { throw 'Unexpected owned target or backup path.' }
    if ($null -ne $item.OriginalSha256 -and (Get-CCFileHash $item.Backup) -cne $item.OriginalSha256) { throw 'Original backup changed.' }
    if ($item.Target -ine $inputPath -and (Get-CCFileHash $item.Target) -cne $item.InstalledSha256) { throw 'Owned game file changed; update refused.' }
}
$inputHash = Get-CCFileHash $inputPath
Import-Module (Join-Path $PSScriptRoot 'PersonalContextProbe.psm1') -Force
$utf8 = [Text.UTF8Encoding]::new($false,$true)
# Validate the owned multisets, allowing engine record reordering and unrelated edits.
# The returned removal text is deliberately discarded: updates never write input.settings.
Remove-PersonalContextSections -Text ($utf8.GetString([IO.File]::ReadAllBytes($inputPath))) `
    -Appendix ($utf8.GetString([Convert]::FromBase64String($state.AppendixBase64))) -Contexts $state.Contexts | Out-Null
$snapshot = (Resolve-Path -LiteralPath $CookSnapshot).ProviderPath
$compatibility = Get-Content -LiteralPath (Join-Path $projectRoot 'data\compatibility.json') -Raw | ConvertFrom-Json
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
& (Join-Path $PSScriptRoot 'Generate-Assets.ps1') -Check | Out-Null
$exe = Join-Path $gameRoot 'bin\x64_dx12\witcher3.exe'
$version = [string][Diagnostics.FileVersionInfo]::GetVersionInfo($exe).FileVersion
if ($version.Replace(' ','') -cne $compatibility.Dx12FileVersion.Replace(' ','')) { throw 'Game executable version is incompatible.' }
$nativeInput = [IO.File]::ReadAllText((Join-Path $gameRoot 'bin\config\r4game\legacy\base\input_qwerty.ini'))
if ($nativeInput -notmatch '(?m)^Version=60\s*$') { throw 'Input format is incompatible.' }
$cook = Get-Content -LiteralPath (Join-Path $snapshot 'cook.json') -Raw | ConvertFrom-Json
if ($cook.SchemaVersion -ne 2 -or $cook.EvidenceKind -cne 'RedkitEditorCook' -or -not $cook.ScriptCompilationVerified -or
    -not $cook.SourceTextEquivalenceVerified -or $cook.UseLooseScripts -ne $false -or $cook.ScriptCompilationErrors.Count -ne 0 -or
    $cook.CompilerSha256 -cne $toolchain.CompilerSha256 -or $cook.ObservedBlobRelativePath -ine 'mods/modCustomizeControllerScheme/content/precompiled.rsblob') { throw 'Unverified editor cook.' }
if ((Get-CCFileHash (Join-Path $snapshot 'cook.log')) -cne $cook.CookLogSha256) { throw 'Cook log changed.' }
foreach ($hook in $toolchain.BaseScriptSha256.PSObject.Properties) {
    if ((Get-CCFileHash (Join-Path $gameRoot ('content\content0\scripts\' + $hook.Name))) -cne $hook.Value -or
        $cook.BaseHookSha256.($hook.Name) -cne $hook.Value) { throw 'Required native hook is incompatible.' }
}
$sources = [IO.Path]::GetFullPath((Join-Path $projectRoot 'src\scripts')).TrimEnd('\') + '\'
if (@(Get-ChildItem -LiteralPath $sources -Recurse -File -Filter '*.ws').Count -ne @($cook.CanonicalSourceSha256.PSObject.Properties).Count) { throw 'Source inventory changed.' }
foreach ($entry in $cook.CanonicalSourceSha256.PSObject.Properties) {
    $source = [IO.Path]::GetFullPath((Join-Path $sources $entry.Name))
    if (-not $source.StartsWith($sources,[StringComparison]::OrdinalIgnoreCase) -or (Get-CCFileHash $source) -cne $entry.Value) { throw 'Cook does not match current sources.' }
}

$payloads = @(
    (Join-Path $snapshot 'packed\mods\modCustomizeControllerScheme\content\precompiled.rsblob'),
    (Join-Path $snapshot 'packed\mods\modCustomizeControllerScheme\content\info.json'),
    (Join-Path $snapshot 'packed\mods\modCustomizeControllerScheme\content\metadata.store'),
    (Join-Path $projectRoot 'src\menu\modControllerCustomizer.xml'))
$entries = @()
$changes = @()
for ($index=0; $index -lt $targets.Count; $index+=1) {
    $source = $payloads[$index]
    $bytes = [IO.File]::ReadAllBytes($source)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $newHash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
    if ($index -lt 3 -and $newHash -cne $cook.FileSha256.([IO.Path]::GetFileName($source))) { throw 'Cooked artifact changed.' }
    if ($index -eq 0 -and ($cook.BlobLength -le 0 -or $bytes.Length -ne $cook.BlobLength)) { throw 'Invalid compiled blob.' }
    $item = @($state.Items | Where-Object Target -IEQ $targets[$index])[0]
    if ($item.InstalledSha256 -cne $newHash) {
        $entries += [pscustomobject]@{ Target=$item.Target; BeforeSha256=$item.InstalledSha256; Bytes=$bytes }
        $changes += [pscustomobject]@{ Target=$item.Target; OldHash=$item.InstalledSha256; NewHash=$newHash }
        $item.InstalledSha256 = $newHash
    }
}
if (-not $entries.Count) { Write-Output 'Already current; no files or journal changed.'; return }
$run = Join-Path $journalRoot ('updates\artifacts-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$history = [pscustomobject]@{ CookSnapshot=$snapshot; PreviousCookSnapshot=$state.CookSnapshot;
    FileJournal=(Join-Path $run 'files.json'); Changes=$changes; RuntimeVerified=$false }
if ($state.PSObject.Properties.Name -contains 'ArtifactUpdates') { $state.ArtifactUpdates = @($state.ArtifactUpdates) + $history }
else { $state | Add-Member -NotePropertyName ArtifactUpdates -NotePropertyValue @($history) }
$state.CookSnapshot = $snapshot
$state.RuntimeVerified = $false
$state.ReleaseVerified = $false
if ($state.PSObject.Properties.Name -contains 'RuntimeEvidence') {
    $state | Add-Member -NotePropertyName PreviousRuntimeEvidence -NotePropertyValue $state.RuntimeEvidence -Force
    $state.RuntimeEvidence = $null
}
# Keep original install backups for full uninstall; include the ownership journal in
# the same rollback transaction as the payloads, avoiding a stale journal on failure.
$entries += [pscustomobject]@{ Target=$journalPath; BeforeSha256=$journalHash;
    Bytes=$utf8.GetBytes(($state | ConvertTo-Json -Depth 12)) }
$guard = {
    param($Index)
    if ((Get-CCFileHash $inputPath) -cne $inputHash) { throw 'Personal input changed during update.' }
    $legacy = @($state.Items | Where-Object Target -IEQ $legacyTarget)
    if ($legacy.Count -and (Get-CCFileHash $legacyTarget) -cne $legacy[0].InstalledSha256) { throw 'Legacy isolation changed during update.' }
    # Payloads omitted as unchanged remain owned and must remain unchanged too.
    foreach ($item in $state.Items) {
        if ($item.Target -ine $inputPath -and $item.Target -ine $legacyTarget -and
            $item.Target -inotIn @($changes.Target) -and (Get-CCFileHash $item.Target) -cne $item.InstalledSha256) { throw 'Unchanged owned file changed during update.' }
    }
}
$updateJournal = Invoke-CCFileTransaction -Entries $entries -JournalDirectory $run -BeforeApply $guard `
    -Metadata @{ Purpose='ControllerCustomizerPhase1Update'; InstallJournal=$journalPath; CookSnapshot=$snapshot }
Write-Output "Updated owned artifacts/menu; personal input untouched; fresh runtime verification pending. Journal: $updateJournal"
