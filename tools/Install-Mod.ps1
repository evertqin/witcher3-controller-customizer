#Requires -Version 5.1
[CmdletBinding()]
param([string]$CookSnapshot, [Parameter(Mandatory)][string]$GamePath,
      [string]$DocumentsPath, [string]$JournalFile, [string]$JournalDirectory,
      [switch]$IsolateLegacy)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
if (Test-Path -LiteralPath (Join-Path $projectRoot 'data/schemes/runtime-baseline.json')) { throw 'This historical Phase 1 tool cannot install/package selection schema 2; use the Phase 1.1 candidate workflow.' }
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$gameRoot = [IO.Path]::GetFullPath($GamePath)
if ($JournalFile) {
    $state = Get-Content -LiteralPath $JournalFile -Raw | ConvertFrom-Json
    if ($state.Purpose -cne 'ControllerCustomizerPhase1' -or $state.Restored -or $state.RolledBack -or -not $state.InstallationComplete -or $state.GamePath -ine $gameRoot) { throw 'Invalid installation journal.' }
    $files = Get-Content -LiteralPath $state.FileJournal -Raw | ConvertFrom-Json
    foreach ($item in $files.Items) {
        if ((Get-CCFileHash $item.Target) -cne $item.InstalledSha256) { throw 'Installed files changed; inspect before reinstalling.' }
    }
    Write-Output "Already installed; owned hashes unchanged. Journal: $JournalFile"
    return
}
if (-not $CookSnapshot) { throw 'Supply a current verified -CookSnapshot.' }
if (-not $DocumentsPath) { $DocumentsPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'The Witcher 3' }
$documents = [IO.Path]::GetFullPath($DocumentsPath)
$inputPath = Join-Path $documents 'input.settings'
$compatibility = Get-Content -LiteralPath (Join-Path $projectRoot 'data\compatibility.json') -Raw | ConvertFrom-Json
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
& (Join-Path $PSScriptRoot 'Generate-Assets.ps1') -Check | Out-Null
$exe = Join-Path $gameRoot 'bin\x64_dx12\witcher3.exe'
$version = [string][Diagnostics.FileVersionInfo]::GetVersionInfo($exe).FileVersion
if ($version.Replace(' ','') -cne $compatibility.Dx12FileVersion.Replace(' ','')) { throw 'Game executable version is incompatible.' }
$nativeInput = [IO.File]::ReadAllText((Join-Path $gameRoot 'bin\config\r4game\legacy\base\input_qwerty.ini'))
if ($nativeInput -notmatch '(?m)^Version=60\s*$') { throw 'Input format is incompatible.' }
$snapshot = (Resolve-Path -LiteralPath $CookSnapshot).ProviderPath
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
Import-Module (Join-Path $PSScriptRoot 'InputRecords.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'PersonalContextProbe.psm1') -Force
$before = [IO.File]::ReadAllBytes($inputPath)
$utf8 = [Text.UTF8Encoding]::new($false,$true)
$personal = @(Read-InputRecords ($utf8.GetString($before)))
$current = @(Read-InputRecords ([IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Current\input.settings'))))
$alt = @(Read-InputRecords ([IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Alt1\input.settings'))))
# Shared diagrams require the existing Souls bindings; keyboard/axes and other pad slots remain personal.
$sharedKeys = @('IK_Pad_X_SQUARE','IK_Pad_Y_TRIANGLE','IK_Pad_RightShoulder','IK_Pad_RightTrigger','IK_Pad_LeftShoulder','IK_Pad_LeftTrigger')
[string[]]$expected = @($current | Where-Object Key -CIn $sharedKeys | ForEach-Object { $_.Section + '|' + $_.Key + '=' + $_.Value.Trim() })
[string[]]$actual = @($personal | Where-Object Key -CIn $sharedKeys | ForEach-Object { $_.Section + '|' + $_.Key + '=' + $_.Value.Trim() })
[Array]::Sort($expected,[StringComparer]::Ordinal)
[Array]::Sort($actual,[StringComparer]::Ordinal)
if ($expected.Count -lt 20) { throw 'Shared binding inventory is incomplete.' }
if (($expected -join "`n") -cne ($actual -join "`n")) { throw 'Shared Souls bindings differ; refusing misleading diagrams. Start from a supported existing Current/Alt1 profile.' }
$differences = @(Get-PresetDifferences -Current $current -Alt1 $alt)
$appendixText = New-PersonalContextAppendix -Text ($utf8.GetString($before)) -Differences $differences
$appendix = $utf8.GetBytes($appendixText)
$inputBytes = [byte[]]($before + $appendix)
$entries = @([pscustomobject]@{ Target=$inputPath; BeforeSha256=(Get-CCFileHash $inputPath); Bytes=$inputBytes })
$modRoot = Join-Path $gameRoot 'mods\modCustomizeControllerScheme'
$menuTarget = Join-Path $gameRoot 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'
if (((Test-Path -LiteralPath $modRoot) -and @(Get-ChildItem -LiteralPath $modRoot -Recurse -File -Force).Count) -or (Test-Path -LiteralPath $menuTarget)) { throw 'Existing mod/menu requires its ownership journal; refusing overwrite.' }
$content = Join-Path $snapshot 'packed\mods\modCustomizeControllerScheme\content'
foreach ($name in @('precompiled.rsblob','info.json','metadata.store')) {
    $payload = Join-Path $content $name
    if ((Get-CCFileHash $payload) -cne $cook.FileSha256.$name) { throw 'Cooked artifact changed.' }
    if ($name -ceq 'precompiled.rsblob' -and ((Get-Item -LiteralPath $payload).Length -ne $cook.BlobLength -or $cook.BlobLength -le 0)) { throw 'Invalid compiled blob.' }
    $entries += [pscustomobject]@{ Target=(Join-Path $modRoot ('content\' + $name)); BeforeSha256=$null; Bytes=[IO.File]::ReadAllBytes($payload) }
}
$entries += [pscustomobject]@{ Target=$menuTarget; BeforeSha256=$null; Bytes=[IO.File]::ReadAllBytes((Join-Path $projectRoot 'src\menu\modControllerCustomizer.xml')) }
$legacyRoot = Join-Path $gameRoot 'mods\modDarkSoulsControllerScheme'
$legacyTarget = Join-Path $legacyRoot 'content\scripts\game\gui\main_menu\ingamemenu\igmUtilities.ws'
if (Test-Path -LiteralPath $legacyRoot) {
    $legacyFiles = @(Get-ChildItem -LiteralPath $legacyRoot -Recurse -File)
    $historical = Get-Content -LiteralPath (Join-Path $projectRoot 'fixtures\legacy\compatibility.json') -Raw | ConvertFrom-Json
    if ($legacyFiles.Count -gt 0) {
        if (-not $IsolateLegacy -or $legacyFiles.Count -ne 1 -or $legacyFiles[0].FullName -ine $legacyTarget -or
            (Get-CCFileHash $legacyTarget) -cnotin @($historical.Profiles.Current.UiSha256,$historical.Profiles.Alt1.UiSha256)) { throw 'Conflicting legacy override; use -IsolateLegacy only for the identified unchanged component.' }
        $entries += [pscustomobject]@{ Target=$legacyTarget; BeforeSha256=(Get-CCFileHash $legacyTarget); Bytes=$null }
    }
}
if (-not $JournalDirectory) { $JournalDirectory = Join-Path $documents ('controller-customizer-backups\install-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)) }
$path = Join-Path ([IO.Path]::GetFullPath($JournalDirectory)) 'install.json'
$state = @{ Purpose='ControllerCustomizerPhase1'; GamePath=$gameRoot; DocumentsPath=$documents;
    FileJournal=$path; InputPath=$inputPath; CookSnapshot=$snapshot;
    RuntimeVerified=$false; ReleaseVerified=$false;
    AppendixBase64=[Convert]::ToBase64String($appendix);
    Contexts=@(foreach ($profile in @('Current','Alt1')) { foreach ($context in @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')) { "CC_PROBE_${profile}_$context" } }) }
$fileJournal = Invoke-CCFileTransaction -Entries $entries -JournalDirectory $JournalDirectory -Metadata $state -JournalName 'install.json'
Write-Output "Installed; release acceptance remains pending. Journal: $path"
