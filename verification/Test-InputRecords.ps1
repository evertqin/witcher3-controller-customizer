#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\InputRecords.psm1') -Force

function Assert-Rejected([scriptblock]$Operation, [string]$Message) {
    $rejected = $false
    try { & $Operation | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw $Message }
}

$sample = "; comment`r`n[Horse]`nIK_Pad_A_CROSS=(Action=Canter)`r`nIK_Pad_A_CROSS=(Action=Gallop,State=Duration,IdleTime=0.3)`r`nIK_Pad_A_CROSS=(Action=Canter)`n`nIK_W=(Action=GI_AxisLeftY,State=Axis,Value=1)"
$records = @(Read-InputRecords -Text $sample)
if (($records.Raw -join '') -cne $sample) { throw 'Mixed line endings, comments or final line were lost.' }
if (@($records | Where-Object Action -CEQ 'Canter').Count -ne 2) { throw 'Meaningful duplicates collapsed.' }
if (@(Read-InputRecords -Text '').Count -ne 0) { throw 'Empty input produced phantom records.' }
$alt = @(Read-InputRecords -Text $sample.Replace('IK_Pad_A_CROSS', 'IK_Pad_LeftThumb'))
if (@(Get-PresetDifferences -Current $records -Alt1 $alt).Count -ne 3) { throw 'Duplicate ordered deltas were lost.' }
$changedTiming = @(Read-InputRecords -Text $sample.Replace('IdleTime=0.3', 'IdleTime=0.4'))
Assert-Rejected { Get-PresetDifferences -Current $records -Alt1 $changedTiming } 'Timing change was accepted.'
$changedAxis = @(Read-InputRecords -Text $sample.Replace('IK_W=', 'IK_S='))
Assert-Rejected { Get-PresetDifferences -Current $records -Alt1 $changedAxis } 'Keyboard/axis change was accepted.'
$changedContext = @(Read-InputRecords -Text $sample.Replace('[Horse]', '[Combat]'))
Assert-Rejected { Get-PresetDifferences -Current $records -Alt1 $changedContext } 'Context change was accepted.'
$changedFormatting = @(Read-InputRecords -Text $sample.Replace("`r`n", "`n"))
Assert-Rejected { Get-PresetDifferences -Current $records -Alt1 $changedFormatting } 'Line ending change was accepted.'
Assert-Rejected { Get-PresetDifferences -Current $records -Alt1 @($records | Select-Object -Skip 1) } 'Removed duplicate/record was accepted.'
Write-Output 'PASS: lossless ordered records and duplicates; timing, keyboard/axis, context, formatting and deletion changes rejected.'
