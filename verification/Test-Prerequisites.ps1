#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-prerequisites-' + [Guid]::NewGuid().ToString('N'))
$windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    $game = Join-Path $testRoot 'steamapps\common\The Witcher 3'
    $input = Join-Path $game 'bin\config\r4game\legacy\base\input_qwerty.ini'
    $ui = Join-Path $game 'content\content0\scripts\game\gui\main_menu\ingamemenu\igmUtilities.ws'
    New-Item -ItemType Directory -Path (Split-Path $input -Parent), (Split-Path $ui -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($input, "[InputSettings]`r`nVersion=60`r`n")
    [IO.File]::WriteAllText($ui, 'deliberately incompatible source')
    $before = (Get-FileHash -LiteralPath $input).Hash + (Get-FileHash -LiteralPath $ui).Hash
    $scriptPath = Join-Path $projectRoot 'tools\Test-Prerequisites.ps1'
    $output = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -GamePath $game -SteamLibraryPaths $testRoot
    if ($LASTEXITCODE -ne 0) { throw 'Read-only discovery failed.' }
    $report = ($output -join "`n") | ConvertFrom-Json
    if ($report.Ready -or $report.CompilerInvocationVerified -or $report.InputVersion -ne 60) { throw 'Discovery made an incorrect readiness claim.' }
    if ($report.ActualUiSha256 -eq $report.ExpectedUiSha256) { throw 'Incompatible UI was accepted.' }
    $fakeToolkit = Join-Path $testRoot 'fake-REDkit'
    $fakeBinary = Join-Path $fakeToolkit 'bin\x64_RedKit\wcc_lite.exe'
    New-Item -ItemType Directory -Path (Split-Path $fakeBinary -Parent) -Force | Out-Null
    [IO.File]::WriteAllBytes($fakeBinary, [byte[]]@())
    $output = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -GamePath $game -SteamLibraryPaths $testRoot -RedkitPath $fakeToolkit
    if ($LASTEXITCODE -ne 0) { throw 'Explicit compiler candidate discovery failed.' }
    $report = ($output -join "`n") | ConvertFrom-Json
    if (@($report.CompilerCandidates | Where-Object Path -EQ $fakeBinary).Count -ne 1) { throw 'Explicit candidate was not discovered.' }
    if ($report.Ready -or $report.CompilerInvocationVerified) { throw 'A candidate filename incorrectly established readiness.' }
    # Windows PowerShell 5.1 promotes redirected native stderr to an error record.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -GamePath $game -SteamLibraryPaths $testRoot -RequireReady *> $null
        $gateExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $savedPreference }
    if ($gateExitCode -eq 0) { throw 'Strict prerequisite gate accepted unverified state.' }
    $after = (Get-FileHash -LiteralPath $input).Hash + (Get-FileHash -LiteralPath $ui).Hash
    if ($before -cne $after) { throw 'Prerequisite discovery mutated input files.' }
    Write-Output 'PASS: read-only prerequisite discovery, incompatible source reporting, candidate discovery without execution, and refusal of unverified readiness.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
