#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('install','update','restore')][string]$Action,
      [string]$GamePath, [string]$InputPath, [string]$CookSnapshot,
      [string]$JournalFile, [Parameter(Mandatory)][string]$JournalDirectory,
      [string]$PythonPath='python')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$repo=Split-Path $PSScriptRoot -Parent
if ($Action -ne 'restore') {
    if ($Action -eq 'update') {
        $state=Get-Content -LiteralPath $JournalFile -Raw | ConvertFrom-Json
        $GamePath=$state.GamePath
    }
    $compatibility=Get-Content -LiteralPath (Join-Path $repo 'data/compatibility.json') -Raw | ConvertFrom-Json
    $exe=Join-Path $GamePath 'bin/x64_dx12/witcher3.exe'
    $version=[string][Diagnostics.FileVersionInfo]::GetVersionInfo($exe).FileVersion
    if ($version.Replace(' ','') -cne $compatibility.Dx12FileVersion.Replace(' ','')) { throw 'Incompatible DX12 executable.' }
}
# Preparation writes a new sibling stage only; FileTransaction performs live writes.
$directory=[IO.Path]::GetFullPath($JournalDirectory)
$prepared=$directory + '-prepared'
$arguments=@('-X','utf8',(Join-Path $PSScriptRoot 'automation/full_scheme_delivery.py'),$Action,
    '--repo',$repo,'--output',$prepared)
if ($GamePath) { $arguments+=@('--game',$GamePath) }
if ($InputPath) { $arguments+=@('--input',$InputPath) }
if ($CookSnapshot) { $arguments+=@('--cook',$CookSnapshot) }
if ($JournalFile) { $arguments+=@('--journal',$JournalFile) }
& $PythonPath @arguments
if ($LASTEXITCODE -ne 0) { throw 'Standalone preparation refused; live files untouched.' }
$plan=Get-Content -LiteralPath (Join-Path $prepared 'transaction.json') -Raw | ConvertFrom-Json
$entries=@(foreach ($item in $plan.Entries) {
    $bytes=$null
    if ($null -ne $item.Payload) { $bytes=[IO.File]::ReadAllBytes($item.Payload) }
    [pscustomobject]@{Target=$item.Target;BeforeSha256=$item.BeforeSha256;Bytes=$bytes}
})
$metadata=@{}
foreach ($property in $plan.Metadata.PSObject.Properties) { $metadata[$property.Name]=$property.Value }
$path=Invoke-CCFileTransaction -Entries $entries -JournalDirectory $directory -Metadata $metadata
Write-Output "PASS: $Action completed. Journal: $path"
