#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-build-refusal-' + [Guid]::NewGuid().ToString('N'))
$windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    $fakeToolkit = Join-Path $testRoot 'unverified REDkit'
    $output = Join-Path $testRoot 'build output'
    $fakeBinary = Join-Path $fakeToolkit 'bin\x64_RedKit\wcc_lite.exe'
    New-Item -ItemType Directory -Path (Split-Path $fakeBinary -Parent) -Force | Out-Null
    [IO.File]::WriteAllBytes($fakeBinary, [byte[]]@())
    $before = (Get-FileHash -LiteralPath $fakeBinary).Hash
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $failure = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'tools\Build-Mod.ps1') -RedkitPath $fakeToolkit -OutputDirectory $output 2>&1
        $failureExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $savedPreference }
    if ($failureExit -eq 0 -or ($failure -join "`n") -notmatch 'Compiler differs from the inspected toolchain') { throw 'An unverified executable did not fail at the compiler identity gate.' }
    if (Test-Path -LiteralPath $output) { throw 'An incompatible compiler created build output.' }
    if ((Get-FileHash -LiteralPath $fakeBinary).Hash -cne $before) { throw 'Compiler refusal modified the candidate.' }
    Write-Output 'PASS: unverified compiler rejected before execution or output creation (Windows PowerShell 5.1).'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
