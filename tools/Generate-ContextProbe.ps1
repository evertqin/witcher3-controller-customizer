#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'work\context-probe' }
& (Join-Path $projectRoot 'verification\Test-Presets.ps1') | Out-Null
Import-Module (Join-Path $PSScriptRoot 'InputRecords.psm1') -Force
$contexts = @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')
foreach ($profile in @('Current','Alt1')) {
    $fixturePath = Join-Path $projectRoot "fixtures\legacy\$profile\input.settings"
    $records = @(Read-InputRecords -Text ([IO.File]::ReadAllText($fixturePath)))
    $content = "; Generated from owned golden fixture $profile; experimental context appendix only.`r`n"
    $content += "; Source SHA256: $((Get-FileHash -LiteralPath $fixturePath).Hash.ToLowerInvariant())`r`n"
    $content += "; NOT a full input file or verified loader. Native inheritance/loading is unproven.`r`n"
    foreach ($context in $contexts) {
        $section = @($records | Where-Object Section -CEQ $context)
        if ($section.Count -eq 0) { throw "Missing context $context." }
        $headerCount = 0
        foreach ($record in $section) {
            if ($record.Text -cmatch ('^\[' + [regex]::Escape($context) + '\]$')) {
                $content += $record.Raw.Replace("[$context]", "[CC_PROBE_${profile}_$context]")
                $headerCount++
            }
            else { $content += $record.Raw }
        }
        if ($headerCount -ne 1) { throw "Ambiguous context header $context." }
    }
    $target = Join-Path $OutputDirectory "$profile.input-contexts.ini"
    if ($Check) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or [IO.File]::ReadAllText($target) -cne $content) {
            throw "Missing or stale generated context appendix: $target"
        }
    }
    else {
        if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
        [IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($false))
    }
}
Write-Output 'PASS: deterministic fixed-context appendices generated/checked. Context registration, inheritance and live behavior are NOT verified.'
