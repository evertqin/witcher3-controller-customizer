#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [string]$JournalDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $projectRoot 'verification\Test-Presets.ps1') | Out-Null
Import-Module (Join-Path $PSScriptRoot 'InputRecords.psm1') -Force
$current = @(Read-InputRecords -Text ([IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Current\input.settings'))))
$alt = @(Read-InputRecords -Text ([IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Alt1\input.settings'))))
$differences = @(Get-PresetDifferences -Current $current -Alt1 $alt)
Import-Module (Join-Path $PSScriptRoot 'PersonalContextProbe.psm1') -Force
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Close Witcher 3 first.' }
$inputFile = (Resolve-Path -LiteralPath $InputPath).ProviderPath
$originalHash = (Get-FileHash -LiteralPath $inputFile).Hash.ToLowerInvariant()
$before = [IO.File]::ReadAllBytes($inputFile)
# Strict UTF-8 decoding preserves the original prefix bytes, including any BOM.
$utf8 = [Text.UTF8Encoding]::new($false,$true)
$appendix = $utf8.GetBytes((New-PersonalContextAppendix -Text ($utf8.GetString($before)) -Differences $differences))
$after = [byte[]]::new($before.Length + $appendix.Length)
[Array]::Copy($before,0,$after,0,$before.Length)
[Array]::Copy($appendix,0,$after,$before.Length,$appendix.Length)
if (-not $JournalDirectory) { $JournalDirectory = Join-Path $projectRoot ('work\runtime-probe\input-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)) }
if (Test-Path -LiteralPath $JournalDirectory) { throw 'Journal directory must be new.' }
$journalRoot = [IO.Path]::GetFullPath($JournalDirectory)
New-Item -ItemType Directory -Path $journalRoot | Out-Null
[IO.File]::WriteAllBytes((Join-Path $journalRoot 'input.before.settings'),$before)
[IO.File]::WriteAllBytes((Join-Path $journalRoot 'appendix.ini'),$appendix)
[IO.File]::WriteAllBytes((Join-Path $journalRoot 'input.installed.settings'),$after)
$journal = [ordered]@{
    SchemaVersion = 1; Purpose = 'Phase0PersonalInputContexts'; InputPath = $inputFile
    OriginalSha256 = $originalHash
    InstalledSha256 = (Get-FileHash -LiteralPath (Join-Path $journalRoot 'input.installed.settings')).Hash.ToLowerInvariant()
    AppendixSha256 = (Get-FileHash -LiteralPath (Join-Path $journalRoot 'appendix.ini')).Hash.ToLowerInvariant()
    OriginalLength = $before.Length; AddedLength = $appendix.Length
    Contexts = @(foreach ($profile in @('Current','Alt1')) { foreach ($context in @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')) { "CC_PROBE_${profile}_$context" } })
    InstallationComplete = $false; Restored = $false; RegistrationVerified = $false
}
$journalPath = Join-Path $journalRoot 'install.json'
$journal | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $journalPath -Encoding UTF8
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Game started; no input written.' }
if ((Get-FileHash -LiteralPath $inputFile).Hash.ToLowerInvariant() -cne $originalHash) { throw 'Input changed; no input written.' }
[IO.File]::WriteAllBytes($inputFile,$after)
if ((Get-FileHash -LiteralPath $inputFile).Hash.ToLowerInvariant() -cne $journal.InstalledSha256) { throw 'Installed input hash mismatch; retain backup.' }
$journal.InstallationComplete = $true
$journal | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $journalPath -Encoding UTF8
Write-Output "Installed eight experimental contexts; original bytes preserved as prefix. Registration remains unverified. Journal: $journalPath"
