#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CandidateDirectory,
      [Parameter(Mandatory)][string]$CookSnapshot,
      [Parameter(Mandatory)][string]$JournalFile,
      [Parameter(Mandatory)][string]$InputPath,
      [Parameter(Mandatory)][string]$JournalDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$candidate = (Resolve-Path -LiteralPath $CandidateDirectory).ProviderPath
$snapshot = (Resolve-Path -LiteralPath $CookSnapshot).ProviderPath
$journalPath = (Resolve-Path -LiteralPath $JournalFile).ProviderPath
$inputFile = (Resolve-Path -LiteralPath $InputPath).ProviderPath
$candidateReport = Get-Content -LiteralPath (Join-Path $candidate 'candidate.json') -Raw | ConvertFrom-Json
$cook = Get-Content -LiteralPath (Join-Path $snapshot 'cook.json') -Raw | ConvertFrom-Json
$journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
$journalHash = Get-CCFileHash $journalPath
$repo = Split-Path $PSScriptRoot -Parent
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
$gameRoot = [IO.Path]::GetFullPath($journal.GamePath)
if ($journal.SchemaVersion -ne 1 -or $journal.Purpose -cne 'Phase0LoadProbe' -or $journal.Restored -or -not $journal.InstallationComplete) { throw 'Only an active owned development installation can migrate.' }
if ($journal.PSObject.Properties.Name -contains 'Phase11Candidate') { throw 'Development installation already migrated.' }
if ($candidateReport.schema_version -ne 1 -or $candidateReport.selection_schema_version -ne 2 -or
    @($candidateReport.aliases).Count -ne 84 -or $candidateReport.runtime_installed) { throw 'Invalid three-scheme candidate.' }
if ($cook.SchemaVersion -ne 2 -or $cook.EvidenceKind -cne 'RedkitEditorCook' -or
    -not $cook.ScriptCompilationVerified -or -not $cook.SourceTextEquivalenceVerified -or
    $cook.UseLooseScripts -ne $false -or $cook.ScriptCompilationErrors.Count -ne 0 -or
    $cook.CompilerSha256 -cne $toolchain.CompilerSha256 -or
    $cook.ObservedBlobRelativePath -ine 'mods/modCustomizeControllerScheme/content/precompiled.rsblob') { throw 'Candidate has no verified cook.' }
if ((Get-CCFileHash (Join-Path $snapshot 'cook.log')) -cne $cook.CookLogSha256) { throw 'Cook log changed.' }
foreach ($entry in $candidateReport.files.PSObject.Properties) {
    $root = $candidate.TrimEnd('\') + '\'
    $path = [IO.Path]::GetFullPath((Join-Path $candidate $entry.Name))
    if (-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase) -or (Get-CCFileHash $path) -cne $entry.Value) { throw 'Candidate file changed or escaped stage.' }
}
if (@($cook.CanonicalSourceSha256.PSObject.Properties).Count -ne 8) { throw 'Unexpected compiled source inventory.' }
foreach ($entry in $cook.CanonicalSourceSha256.PSObject.Properties) {
    if ($entry.Name -cnotmatch '^local/controllerCustomizer/[^/\\]+\.ws$' -or
        (Get-CCFileHash (Join-Path $candidate ('src/scripts/' + $entry.Name))) -cne $entry.Value) { throw 'Cook source differs from candidate.' }
}
foreach ($entry in $toolchain.BaseScriptSha256.PSObject.Properties) {
    if ((Get-CCFileHash (Join-Path $gameRoot ('content/content0/scripts/' + $entry.Name))) -cne $entry.Value -or
        $cook.BaseHookSha256.($entry.Name) -cne $entry.Value) { throw 'Native hook changed.' }
}
if (Test-Path -LiteralPath (Join-Path $gameRoot 'mods/modDarkSoulsControllerScheme/content/scripts/game/gui/main_menu/ingamemenu/igmUtilities.ws')) { throw 'Known conflicting legacy diagram must remain isolated.' }
$allowed = @('mods/modCustomizeControllerScheme/content/precompiled.rsblob','mods/modCustomizeControllerScheme/content/info.json','mods/modCustomizeControllerScheme/content/metadata.store','bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml','bin/config/base/general.ini')
if (@($journal.Items).Count -ne 5) { throw 'Unexpected development ownership inventory.' }
$seen = @{}
foreach ($item in $journal.Items) {
    if ($item.RelativePath -cnotin $allowed -or $seen.ContainsKey($item.RelativePath)) { throw 'Unknown or duplicate owned target.' }
    $seen[$item.RelativePath] = $true
    if ((Get-CCFileHash (Join-Path $gameRoot $item.RelativePath)) -cne $item.InstalledSha256) { throw 'Owned development file changed.' }
}
$inputHash = Get-CCFileHash $inputFile
if ($inputHash -cne $candidateReport.personal_input_sha256) { throw 'Personal input changed since candidate preparation.' }
$inputBytes = [IO.File]::ReadAllBytes($inputFile)
$inputText = [Text.Encoding]::UTF8.GetString($inputBytes)
if ($inputText -match '\[CC_SCHEME_') { throw 'Full-scheme aliases already installed.' }
$appendix = [IO.File]::ReadAllBytes((Join-Path $candidate 'full-scheme-appendix.ini'))
$entries = @()
foreach ($name in @('precompiled.rsblob','info.json','metadata.store')) {
    $relative = 'mods/modCustomizeControllerScheme/content/' + $name
    $source = Join-Path $snapshot ('packed/mods/modCustomizeControllerScheme/content/' + $name)
    if ((Get-CCFileHash $source) -cne $cook.FileSha256.$name) { throw 'Cooked payload changed.' }
    $item = @($journal.Items | Where-Object RelativePath -CEQ $relative)[0]
    $entries += [pscustomobject]@{Target=(Join-Path $gameRoot $relative);BeforeSha256=$item.InstalledSha256;Bytes=[IO.File]::ReadAllBytes($source)}
    $item.InstalledSha256 = $cook.FileSha256.$name
}
$menuRelative = 'bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml'
$menuItem = @($journal.Items | Where-Object RelativePath -CEQ $menuRelative)[0]
$menuSource = Join-Path $candidate 'src/menu/modControllerCustomizer.xml'
$entries += [pscustomobject]@{Target=(Join-Path $gameRoot $menuRelative);BeforeSha256=$menuItem.InstalledSha256;Bytes=[IO.File]::ReadAllBytes($menuSource)}
$menuItem.InstalledSha256 = Get-CCFileHash $menuSource
$entries += [pscustomobject]@{Target=$inputFile;BeforeSha256=$inputHash;Bytes=[byte[]]($inputBytes+$appendix)}
$journal.CookSnapshot = $snapshot
$journal.RuntimeLoadVerified = $false
$journal | Add-Member -NotePropertyName Phase11Candidate -NotePropertyValue ([pscustomobject]@{
    CandidateDirectory=$candidate;TransactionDirectory=[IO.Path]::GetFullPath($JournalDirectory);
    SelectionSchemaVersion=2;InputPath=$inputFile;PreviousInputSha256=$inputHash;
    RuntimeLoadVerified=$false;GameplayVerified=$false})
$journal | Add-Member -NotePropertyName RuntimeEvidence -Force -NotePropertyValue ([pscustomobject]@{CompiledProbeLoadVerified=$false;GameplayContextCorrectnessVerified=$false})
$utf8 = [Text.UTF8Encoding]::new($false)
$entries += [pscustomobject]@{Target=$journalPath;BeforeSha256=$journalHash;Bytes=$utf8.GetBytes(($journal | ConvertTo-Json -Depth 16))}
Invoke-CCFileTransaction -Entries $entries -JournalDirectory $JournalDirectory -Metadata @{
    Purpose='ControllerCustomizerPhase11DevelopmentMigration';GamePath=$gameRoot;InputPath=$inputFile;
    CandidateDirectory=$candidate;CookSnapshot=$snapshot;PreviousRuntimeJournal=$journalPath;
    RuntimeLoadVerified=$false;GameplayVerified=$false} | Out-Null
Write-Output 'PASS: candidate installed with verified rollback backups; runtime load remains unverified.'
