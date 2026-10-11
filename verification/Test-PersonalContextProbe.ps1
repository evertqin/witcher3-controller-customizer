#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'tools\InputRecords.psm1') -Force
$golden = [IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Current\input.settings'))
$alt = [IO.File]::ReadAllText((Join-Path $projectRoot 'fixtures\legacy\Alt1\input.settings'))
$deltas = @(Get-PresetDifferences -Current @(Read-InputRecords $golden) -Alt1 @(Read-InputRecords $alt))
$personal = $alt.Replace('IK_E=(Action=Use)','IK_K=(Action=Use)').Replace("[Horse]","[Horse]`r`n; personal comment`nIK_Pad_RightThumb=(Action=PersonalProbe)`r`nIK_K=(Action=PersonalKeyboard)`nIK_K=(Action=PersonalKeyboard)")
Import-Module (Join-Path $projectRoot 'tools\PersonalContextProbe.psm1') -Force
$appendix = New-PersonalContextAppendix -Text $personal -Differences $deltas
$expectedRecords = @(Read-InputRecords $personal)
$actualRecords = @(Read-InputRecords $appendix)
foreach ($profile in @('Current','Alt1')) {
    foreach ($context in @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')) {
        $before = @($expectedRecords | Where-Object Section -CEQ $context)
        $after = @($actualRecords | Where-Object Section -CEQ "CC_PROBE_${profile}_$context")
        # Final marker belongs to the final section; exclude it from comparison.
        $after = @($after | Where-Object Text -CNE '; Controller Customizer Phase 0: personal-context probe END')
        if ($before.Count -ne $after.Count) { throw "Lost records: $profile/$context." }
        for ($i=0; $i -lt $before.Count; $i++) {
            $expected = $before[$i].Raw.Replace("[$context]", "[CC_PROBE_${profile}_$context]")
            if ($before[$i].Key -cmatch '^IK_Pad_') {
                $delta = @($deltas | Where-Object { $_.Context -ceq $context -and $_.NativeValue -ceq $before[$i].Value })
                if ($delta.Count -eq 1) {
                    $key = if ($profile -ceq 'Current') { $delta[0].CurrentKey } else { $delta[0].Alt1Key }
                    $expected = $expected.Replace($before[$i].Key,$key)
                }
            }
            if ($expected -cne $after[$i].Raw) { throw "Changed unowned bytes: $profile/$context/$i." }
        }
    }
}
$badIndex = 0
foreach ($bad in @($personal.Replace('IK_Pad_LeftThumb=(Action=Canter)','IK_Pad_X_SQUARE=(Action=Canter)'), ($personal + "`r`n[Horse]`r`n"), ($personal + $appendix))) {
    $rejected = $false
    try { New-PersonalContextAppendix -Text $bad -Differences $deltas | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw "Unsupported/duplicate/existing contexts accepted: case $badIndex." }
    $badIndex++
}
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-personal-contexts-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $inputFile = Join-Path $testRoot 'input.settings'
    $utf8 = [Text.UTF8Encoding]::new($false)
    # A BOM and mixed newlines must survive installation and rollback byte-for-byte.
    $original = [byte[]](@(239,187,191) + @($utf8.GetBytes($personal)))
    [IO.File]::WriteAllBytes($inputFile,$original)
    $originalHash = (Get-FileHash -LiteralPath $inputFile).Hash
    $journalRoot = Join-Path $testRoot 'journal'
    & (Join-Path $projectRoot 'tools\Install-InputContextProbe.ps1') -InputPath $inputFile -JournalDirectory $journalRoot | Out-Null
    $installed = [IO.File]::ReadAllBytes($inputFile)
    for ($i=0; $i -lt $original.Length; $i++) { if ($installed[$i] -ne $original[$i]) { throw 'Original prefix changed.' } }
    $journalFile = Join-Path $journalRoot 'install.json'
    $receipt = Get-Content -LiteralPath $journalFile -Raw | ConvertFrom-Json
    if ($receipt.Contexts.Count -ne 8 -or $receipt.RegistrationVerified -or -not $receipt.InstallationComplete) { throw 'Invalid evidence claims.' }
    [IO.File]::AppendAllText($inputFile,'; later change')
    $laterHash = (Get-FileHash -LiteralPath $inputFile).Hash
    $rejected = $false
    try { & (Join-Path $projectRoot 'tools\Restore-InputContextProbe.ps1') -JournalFile $journalFile | Out-Null } catch { $rejected=$true }
    if (-not $rejected -or (Get-FileHash -LiteralPath $inputFile).Hash -cne $laterHash) { throw 'Rollback overwrote later input changes.' }
    [IO.File]::WriteAllBytes($inputFile,$installed)
    & (Join-Path $projectRoot 'tools\Restore-InputContextProbe.ps1') -JournalFile $journalFile | Out-Null
    if ((Get-FileHash -LiteralPath $inputFile).Hash -cne $originalHash) { throw 'Rollback did not restore exact original bytes.' }
    $badJournal = Join-Path $testRoot 'bad-journal'
    [IO.File]::WriteAllText($inputFile,$personal.Replace('IK_Pad_LeftThumb=(Action=Canter)','IK_Pad_X_SQUARE=(Action=Canter)'),$utf8)
    $badHash = (Get-FileHash -LiteralPath $inputFile).Hash
    $rejected = $false
    try { & (Join-Path $projectRoot 'tools\Install-InputContextProbe.ps1') -InputPath $inputFile -JournalDirectory $badJournal | Out-Null } catch { $rejected=$true }
    if (-not $rejected -or (Test-Path -LiteralPath $badJournal) -or (Get-FileHash -LiteralPath $inputFile).Hash -cne $badHash) { throw 'Unsupported input mutated during refused installation.' }
    Write-Output 'PASS: personal keyboard/axes/comments/duplicates preserved; eight aliases; unsupported inputs refused; byte-exact installation/rollback; later edits protected.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
