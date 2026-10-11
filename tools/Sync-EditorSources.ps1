#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigFile,
      [Parameter(Mandatory)][string]$PreviousCookSnapshot,
      [string]$JournalDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$config=Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
$project=(Resolve-Path -LiteralPath $config.project_file).ProviderPath
$projectRoot=Split-Path $project -Parent
$previous=Get-Content -LiteralPath (Join-Path $PreviousCookSnapshot 'cook.json') -Raw | ConvertFrom-Json
if ($previous.SchemaVersion -ne 2 -or $previous.EvidenceKind -cne 'RedkitEditorCook' -or
    -not $previous.SourceTextEquivalenceVerified -or
    [IO.Path]::GetFullPath($previous.EditorProject) -ine $projectRoot) { throw 'Previous cook does not identify this owned project.' }
$canonical=Join-Path $config.repo 'src\scripts\local\controllerCustomizer'
$editor=Join-Path $projectRoot 'workspace\scripts\local\controllerCustomizer'
$files=@(Get-ChildItem -LiteralPath $canonical -File -Filter '*.ws')
$expected=@($previous.CanonicalSourceSha256.PSObject.Properties.Name | ForEach-Object {
    if ($_ -notmatch '^local/controllerCustomizer/[^/\\]+\.ws$') { throw 'Previous owned source inventory is unexpected.' }
    [IO.Path]::GetFileName($_)
})
if ($files.Count -eq 0 -or (Compare-Object @($files.Name | Sort-Object) @($expected | Sort-Object))) { throw 'Owned source inventory changed; review added/removed sources before syncing.' }
$projectHash=Get-CCFileHash $project
$utf8=[Text.UTF8Encoding]::new($false,$true)
$utf16=[Text.UnicodeEncoding]::new($false,$true,$true)
$entries=@()
foreach ($file in $files) {
    $target=Join-Path $editor $file.Name
    $hash=Get-CCFileHash $target
    if ($null -eq $hash) { throw 'Owned editor source is missing.' }
    $sourceText=[IO.File]::ReadAllText($file.FullName,$utf8)
    $editorText=[IO.File]::ReadAllText($target,$utf16)
    if ($sourceText.Replace("`r`n","`n") -ceq $editorText.Replace("`r`n","`n")) { continue }
    $key='local/controllerCustomizer/' + $file.Name
    if ($hash -cne $previous.EditorSourceSha256.$key) { throw 'Editor source has independent changes; refusing overwrite.' }
    $entries += [pscustomobject]@{Target=$target;BeforeSha256=$hash;Bytes=[byte[]]($utf16.GetPreamble()+$utf16.GetBytes($sourceText))}
}
if (-not $entries.Count) { Write-Output 'PASS: owned editor sources already match; no files written.'; return }
if (-not $JournalDirectory) { $JournalDirectory=Join-Path $config.repo ('work\editor-sync\' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)) }
Invoke-CCFileTransaction -Entries $entries -JournalDirectory $JournalDirectory -Metadata @{Purpose='ControllerCustomizerEditorSync';EditorProject=$projectRoot;PreviousCookSnapshot=$PreviousCookSnapshot;ProjectMetadataSha256=$projectHash} | Out-Null
if ((Get-CCFileHash $project) -cne $projectHash) { throw 'Project metadata changed during source sync.' }
Write-Output "PASS: $($entries.Count) owned scripts synced as UTF-16; originals backed up at $JournalDirectory."
