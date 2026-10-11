#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'tools\InputRecords.psm1') -Force
Import-Module (Join-Path $projectRoot 'tools\PersonalContextProbe.psm1') -Force
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-owned-removal-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $inputFile = Join-Path $testRoot 'input.settings'
    $utf8 = [Text.UTF8Encoding]::new($false)
    $original = [IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Current\input.settings'))
    [IO.File]::WriteAllText($inputFile,$original,$utf8)
    $journalRoot = Join-Path $testRoot 'journal'
    & (Join-Path $projectRoot 'tools\Install-InputContextProbe.ps1') -InputPath $inputFile -JournalDirectory $journalRoot | Out-Null
    $journalFile = Join-Path $journalRoot 'install.json'
    $journal = Get-Content -LiteralPath $journalFile -Raw | ConvertFrom-Json
    $appendix = [IO.File]::ReadAllText((Join-Path $journalRoot 'appendix.ini'))
    $records = @(Read-InputRecords $appendix)
    # Simulate engine serialization: reordered sections/bindings, removed original
    # comments, LF newlines; retain duplicates and add unrelated user edits/BOM.
    $unrelated = $original.Replace('IK_E=(Action=Use)','IK_K=(Action=Use)') + "`n[PersonalNewContext]`nIK_K=(Action=Personal)`nIK_K=(Action=Personal)`n; later user note`n"
    $serialized = [string][char]0xfeff + $unrelated
    foreach ($context in @($journal.Contexts | Sort-Object -Descending)) {
        $serialized += "[$context]`n"
        foreach ($binding in @($records | Where-Object { $_.Section -ceq $context -and $null -ne $_.Key } | Sort-Object Text -Descending)) {
            $serialized += $binding.Text + "`n"
        }
    }
    $serialized += '; later note inside owned section'
    $expected = [string][char]0xfeff + $unrelated + '; later note inside owned section'
    $removed = Remove-PersonalContextSections -Text $serialized -Appendix $appendix -Contexts $journal.Contexts
    if ($removed -cne $expected) { throw 'Removal changed unrelated bytes, BOM, comments or duplicates.' }
    $context = $journal.Contexts[0]
    $binding = @($records | Where-Object { $_.Section -ceq $context -and $null -ne $_.Key })[0].Text
    foreach ($bad in @(
        $serialized.Replace($binding,$binding + 'changed'),
        $serialized.Replace("[$context]", "[$context]`n$binding"),
        $serialized.Replace("[$context]", "[$context]`n[$context]"),
        $serialized.Replace("[$context]", '[MissingOwnedContext]'),
        $serialized.Replace("[$context]", "[$context]`nunknown record")
    )) {
        [IO.File]::WriteAllText($inputFile,$bad,$utf8)
        $badHash = (Get-FileHash -LiteralPath $inputFile).Hash
        $rejected = $false
        try { & (Join-Path $projectRoot 'tools\Restore-InputContextProbe.ps1') -JournalFile $journalFile -RemoveOwnedContexts | Out-Null } catch { $rejected=$true }
        if (-not $rejected -or (Get-FileHash -LiteralPath $inputFile).Hash -cne $badHash -or (Test-Path -LiteralPath (Join-Path $journalRoot 'input.before-owned-removal.settings'))) { throw 'Unsafe removal accepted or mutated input.' }
    }
    [IO.File]::WriteAllText($inputFile,$serialized,$utf8)
    $beforeHash = (Get-FileHash -LiteralPath $inputFile).Hash
    & (Join-Path $projectRoot 'tools\Restore-InputContextProbe.ps1') -JournalFile $journalFile -RemoveOwnedContexts | Out-Null
    if ([IO.File]::ReadAllText($inputFile) -cne $expected.TrimStart([char]0xfeff)) { throw 'CLI removal content mismatch.' }
    if ($utf8.GetString([IO.File]::ReadAllBytes($inputFile)) -cne $expected) { throw 'CLI removal lost exact bytes/BOM.' }
    if ((Get-FileHash -LiteralPath (Join-Path $journalRoot 'input.before-owned-removal.settings')).Hash -cne $beforeHash) { throw 'Removal backup changed.' }
    $restored = Get-Content -LiteralPath $journalFile -Raw | ConvertFrom-Json
    if (-not $restored.Restored -or $restored.RemovalEvidence.Mode -cne 'OwnedContextsOnly') { throw 'Missing removal evidence.' }
    Write-Output 'PASS: reordered serialization accepted; unrelated edits/BOM/comments/duplicates preserved; altered/missing/duplicate owned records refused; exact removal backup retained.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
