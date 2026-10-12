#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CookSnapshot,
      [Parameter(Mandatory)][string]$OutputDirectory, [string]$PythonPath='python')
$ErrorActionPreference='Stop'
& $PythonPath -X utf8 (Join-Path $PSScriptRoot 'automation/package_full_scheme.py') --repo (Split-Path $PSScriptRoot -Parent) --cook $CookSnapshot --output $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw 'Schema-2 packaging failed.' }
