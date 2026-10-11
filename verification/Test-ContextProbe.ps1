#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'tools\InputRecords.psm1') -Force
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-contexts-' + [Guid]::NewGuid().ToString('N'))
try {
    $generator = Join-Path $projectRoot 'tools\Generate-ContextProbe.ps1'
    & $generator -OutputDirectory $testRoot | Out-Null
    & $generator -OutputDirectory $testRoot -Check | Out-Null
    $beforeHashes = @()
    foreach ($profile in @('Current','Alt1')) {
        $target = Join-Path $testRoot "$profile.input-contexts.ini"
        $beforeHashes += (Get-FileHash -LiteralPath $target).Hash
        $generated = @(Read-InputRecords -Text ([IO.File]::ReadAllText($target)))
        $golden = @(Read-InputRecords -Text ([IO.File]::ReadAllText((Join-Path $projectRoot "fixtures\legacy\$profile\input.settings"))))
        if (@($generated | Where-Object Text -Match '^\[').Count -ne 4) { throw 'Expected four uniquely owned context headers per profile.' }
        foreach ($context in @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')) {
            $actual = @($generated | Where-Object Section -CEQ "CC_PROBE_${profile}_$context")
            $expected = @($golden | Where-Object Section -CEQ $context)
            if ($actual.Count -ne $expected.Count) { throw "Lost records in $profile/$context." }
            for ($i=0; $i -lt $expected.Count; $i++) {
                $normalized = $actual[$i].Raw.Replace("[CC_PROBE_${profile}_$context]", "[$context]")
                if ($normalized -cne $expected[$i].Raw) { throw "Changed native record in $profile/$context at index $i." }
            }
        }
    }
    & $generator -OutputDirectory $testRoot | Out-Null
    $afterHashes = @(foreach ($profile in @('Current','Alt1')) { (Get-FileHash -LiteralPath (Join-Path $testRoot "$profile.input-contexts.ini")).Hash })
    if (($beforeHashes -join ':') -cne ($afterHashes -join ':')) { throw 'Generation is not deterministic.' }
    [IO.File]::AppendAllText((Join-Path $testRoot 'Current.input-contexts.ini'), '; stale')
    $rejected = $false
    try { & $generator -OutputDirectory $testRoot -Check | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw '-Check accepted changed generated data.' }
    # Verify real Windows PowerShell CLI defaults in an isolated clone. PSScriptRoot
    # is not reliably initialized inside parameter-default expressions in 5.1.
    $cliRoot = Join-Path $testRoot 'cli-project'
    New-Item -ItemType Directory -Path (Join-Path $cliRoot 'tools'), (Join-Path $cliRoot 'verification'), (Join-Path $cliRoot 'fixtures') -Force | Out-Null
    Copy-Item -LiteralPath $generator, (Join-Path $projectRoot 'tools\InputRecords.psm1') -Destination (Join-Path $cliRoot 'tools')
    Copy-Item -LiteralPath (Join-Path $projectRoot 'verification\Test-Presets.ps1') -Destination (Join-Path $cliRoot 'verification')
    Copy-Item -LiteralPath (Join-Path $projectRoot 'fixtures\legacy') -Destination (Join-Path $cliRoot 'fixtures') -Recurse
    $ps51 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $ps51 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $cliRoot 'tools\Generate-ContextProbe.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'CLI default output generation failed.' }
    foreach ($profile in @('Current','Alt1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $cliRoot "work\context-probe\$profile.input-contexts.ini"))) { throw 'CLI default output is outside the project work directory.' }
    }
    & $ps51 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $cliRoot 'tools\Generate-ContextProbe.ps1') -Check | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'CLI default output check failed.' }
    Write-Output 'PASS: eight unique fixed contexts; exact native records/duplicates retained; deterministic generation; stale output rejected. No runtime proof claimed.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
