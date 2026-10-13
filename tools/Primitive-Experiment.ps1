#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('install','restore')][string]$Action,
      [Parameter(Mandatory)][string]$JournalFile, [string]$CookSnapshot,
      [string]$BankDirectory, [Parameter(Mandatory)][string]$JournalDirectory,
      [string]$PythonPath='python')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'FileTransaction.psm1') -Force
Assert-CCGameClosed
$directory=[IO.Path]::GetFullPath($JournalDirectory)
$prepared=$directory+'-prepared'
$arguments=@('-X','utf8',(Join-Path $PSScriptRoot 'automation/temporary_primitive.py'),$Action,
    '--journal',$JournalFile,'--output',$prepared)
if ($CookSnapshot) { $arguments+=@('--cook',$CookSnapshot) }
if ($BankDirectory) { $arguments+=@('--bank',$BankDirectory) }
& $PythonPath @arguments
if ($LASTEXITCODE -ne 0) { throw 'Primitive transaction preparation refused; live files untouched.' }
$plan=Get-Content -LiteralPath (Join-Path $prepared 'transaction.json') -Raw | ConvertFrom-Json
$entries=@(foreach ($item in $plan.Entries) {
    [pscustomobject]@{Target=$item.Target;BeforeSha256=$item.BeforeSha256;Bytes=[IO.File]::ReadAllBytes($item.Payload)}
})
$metadata=@{}
foreach ($property in $plan.Metadata.PSObject.Properties) { $metadata[$property.Name]=$property.Value }
$path=Invoke-CCFileTransaction -Entries $entries -JournalDirectory $directory -Metadata $metadata
Write-Output "PASS: primitive $Action completed. Journal: $path"
