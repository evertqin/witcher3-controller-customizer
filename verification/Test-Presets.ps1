#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'tools\InputRecords.psm1') -Force
$fixtureRoot = Join-Path $projectRoot 'fixtures\legacy'
$manifest = Get-Content -LiteralPath (Join-Path $fixtureRoot 'compatibility.json') -Raw | ConvertFrom-Json
$profiles = @{}
foreach ($profile in @('Current', 'Alt1')) {
    $path = Join-Path $fixtureRoot "$profile\input.settings"
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest.Profiles.$profile.InputSha256) {
        throw "$profile golden fixture fingerprint mismatch."
    }
    $profiles[$profile] = @(Read-InputRecords -Text ([IO.File]::ReadAllText($path)))
    $sectionCount = @($profiles[$profile] | Where-Object Text -Match '^\[').Count
    if ($sectionCount -ne 48) { throw "$profile must retain 48 ordered sections." }
}
$differences = @(Get-PresetDifferences -Current $profiles.Current -Alt1 $profiles.Alt1)
$expectedActions = @{
    BASE_INTERACTIONS_HORSE = @('Follow')
    Horse = @('Follow', 'Canter', 'Gallop', 'Container', 'GatherHerbs', 'FastTravel', 'Use')
    Horse_Replacer_Ciri = @('Follow', 'Canter', 'Gallop')
    ScriptedAction = @('Gallop')
}
if ($differences.Count -ne 12) { throw 'Expected exactly 12 owned record differences.' }
foreach ($context in $expectedActions.Keys) {
    $records = @($differences | Where-Object Context -CEQ $context)
    if ($records.Count -ne $expectedActions[$context].Count) { throw "Unexpected delta count for $context." }
    foreach ($action in $expectedActions[$context]) {
        $record = @($records | Where-Object Action -CEQ $action)
        if ($record.Count -ne 1) { throw "Expected one delta for $context/$action." }
        $speedAction = $action -cin @('Follow', 'Canter', 'Gallop')
        $currentKey = 'IK_Pad_LeftThumb'
        $alt1Key = 'IK_Pad_A_CROSS'
        if ($speedAction) { $currentKey = 'IK_Pad_A_CROSS'; $alt1Key = 'IK_Pad_LeftThumb' }
        if ($record[0].CurrentKey -cne $currentKey -or $record[0].Alt1Key -cne $alt1Key) {
            throw "Incorrect button semantics for $context/$action."
        }
        $nativeValue = "(Action=$action)"
        if ($action -ceq 'Gallop') { $nativeValue = '(Action=Gallop,State=Duration,IdleTime=0.3)' }
        if ($record[0].NativeValue -cne $nativeValue) { throw "Changed native metadata for $context/$action." }
    }
}
# Reconstruction proves all other bytes, including duplicate/axis/menu records, are untouched.
$restored = for ($index = 0; $index -lt $profiles.Alt1.Count; $index++) {
    if ($profiles.Current[$index].Raw -cne $profiles.Alt1[$index].Raw) { $profiles.Current[$index].Raw }
    else { $profiles.Alt1[$index].Raw }
}
if (($restored -join '') -cne ([IO.File]::ReadAllText((Join-Path $fixtureRoot 'Current\input.settings')))) {
    throw 'Lossless reconstruction failed.'
}
Write-Output 'PASS: fixture hashes; 48 sections; exact four-context/12-record delta; native metadata and all unrelated records preserved.'
