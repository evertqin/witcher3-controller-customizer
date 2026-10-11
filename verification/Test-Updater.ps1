#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CookSnapshot,
      [string]$SourceGamePath='F:\Steam\steamapps\common\The Witcher 3', [string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
if ($ProjectRoot) { $repo=(Resolve-Path -LiteralPath $ProjectRoot).ProviderPath }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('cc-phase1-update-' + [guid]::NewGuid().ToString('N'))
Import-Module (Join-Path $repo 'tools\FileTransaction.psm1') -Force
Assert-CCGameClosed
function Assert-Refused([scriptblock]$Action, [string]$Reason) {
    $refused=$false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notmatch [regex]::Escape($Reason)) { throw }
        $refused=$true
    }
    if (-not $refused) { throw 'Unsafe update was accepted.' }
}
try {
    $game=Join-Path $scratch 'game'
    $profile=Join-Path $scratch 'redirected Documents\The Witcher 3'
    [void][IO.Directory]::CreateDirectory($profile)
    $input=Join-Path $profile 'input.settings'
    Copy-Item -LiteralPath (Join-Path $repo 'fixtures\legacy\Current\input.settings') -Destination $input
    $exe='bin\x64_dx12\witcher3.exe'
    [void][IO.Directory]::CreateDirectory((Split-Path (Join-Path $game $exe) -Parent))
    Copy-Item -LiteralPath (Join-Path $SourceGamePath $exe) -Destination (Join-Path $game $exe)
    $nativeInput=Join-Path $game 'bin\config\r4game\legacy\base\input_qwerty.ini'
    [void][IO.Directory]::CreateDirectory((Split-Path $nativeInput -Parent))
    [IO.File]::WriteAllText($nativeInput,"[InputSettings]`r`nVersion=60`r`n")
    $toolchain=Get-Content -LiteralPath (Join-Path $repo 'tools\compiler-toolchain.json') -Raw | ConvertFrom-Json
    foreach ($hook in $toolchain.BaseScriptSha256.PSObject.Properties) {
        $relative='content\content0\scripts\' + $hook.Name
        [void][IO.Directory]::CreateDirectory((Split-Path (Join-Path $game $relative) -Parent))
        Copy-Item -LiteralPath (Join-Path $SourceGamePath $relative) -Destination (Join-Path $game $relative)
    }
    $journal=Join-Path $scratch 'journal\install.json'
    & (Join-Path $repo 'tools\Install-Mod.ps1') -GamePath $game -DocumentsPath $profile -CookSnapshot $CookSnapshot -JournalDirectory (Split-Path $journal -Parent) | Out-Null
    $update=Join-Path $repo 'tools\Update-Mod.ps1'
    $restore=Join-Path $repo 'tools\Restore-Backup.ps1'
    $initialHash=Get-CCFileHash $journal
    & $update -JournalFile $journal -CookSnapshot $CookSnapshot | Out-Null
    if ((Get-CCFileHash $journal) -cne $initialHash -or (Test-Path -LiteralPath (Join-Path $scratch 'journal\updates'))) { throw 'No-op created changes.' }
    # Model an older owned artifact without inventing a compiler receipt.
    $state=Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
    foreach ($item in $state.Items | Where-Object Target -Like '*\modCustomizeControllerScheme\content\*') {
        [IO.File]::WriteAllText($item.Target,'Previously installed owned artifact ' + [IO.Path]::GetFileName($item.Target))
        $item.InstalledSha256=Get-CCFileHash $item.Target
    }
    $menuItem=@($state.Items | Where-Object Target -Like '*\modControllerCustomizer.xml')[0]
    [IO.File]::AppendAllText($menuItem.Target,'<!-- prior owned menu version -->')
    $menuItem.InstalledSha256=Get-CCFileHash $menuItem.Target
    $state.RuntimeVerified=$true
    $state.ReleaseVerified=$true
    Write-CCJournal $state $journal
    # Engine-like ordering plus unrelated edits must survive an update byte-for-byte.
    $text=[IO.File]::ReadAllText($input)
    $text=[regex]::Replace($text,'(?m)^IK_Pad_A_CROSS=(.*)\r?\nIK_Pad_A_CROSS=(.*)\r?$',"IK_Pad_A_CROSS=`$2`r`nIK_Pad_A_CROSS=`$1")
    [IO.File]::WriteAllText($input,$text + "`r`n[LaterPersonalKeys]`r`nIK_F1=(Action=UnownedTest)`r`n",[Text.UTF8Encoding]::new($false))
    $inputHash=Get-CCFileHash $input
    $menu=Join-Path $game 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'
    $menuBytes=[IO.File]::ReadAllBytes($menu)
    [IO.File]::AppendAllText($menu,'<!-- independent edit -->')
    $journalHash=Get-CCFileHash $journal
    Assert-Refused { & $update -JournalFile $journal -CookSnapshot $CookSnapshot } 'Owned game file changed'
    if ((Get-CCFileHash $journal) -cne $journalHash -or (Get-CCFileHash $input) -cne $inputHash) { throw 'Refusal mutated files.' }
    [IO.File]::WriteAllBytes($menu,$menuBytes)
    $validInput=[IO.File]::ReadAllBytes($input)
    [IO.File]::AppendAllText($input,"`r`n[CC_PROBE_Alt1_Horse]`r`nIK_F2=(Action=Foreign)`r`n")
    Assert-Refused { & $update -JournalFile $journal -CookSnapshot $CookSnapshot } 'Missing or duplicate owned context'
    [IO.File]::WriteAllBytes($input,$validInput)
    & $update -JournalFile $journal -CookSnapshot $CookSnapshot | Out-Null
    $newState=Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
    if ($newState.RuntimeVerified -or $newState.ReleaseVerified -or $newState.ArtifactUpdates.Count -ne 1) { throw 'Update retained stale verification.' }
    if ((Get-CCFileHash $input) -cne $inputHash) { throw 'Update wrote personal input.' }
    foreach ($item in $newState.Items | Where-Object Target -Like '*\modCustomizeControllerScheme\content\*') {
        if ((Get-CCFileHash $item.Target) -cne $item.InstalledSha256) { throw 'Updated payload mismatch.' }
    }
    $txn=Get-Content -LiteralPath $newState.ArtifactUpdates[0].FileJournal -Raw | ConvertFrom-Json
    if (-not $txn.InstallationComplete -or $txn.Items[-1].Target -ine $journal -or $txn.Items.Count -ne 5) { throw 'Ownership journal missing from atomic update.' }
    & $restore -JournalFile $journal | Out-Null
    if ([IO.File]::ReadAllText($input) -match '\[CC_PROBE_' -or [IO.File]::ReadAllText($input) -notmatch 'IK_F1=\(Action=UnownedTest\)' -or (Test-Path -LiteralPath $menu)) { throw 'Updated install could not restore owned files.' }
    Write-Output 'PASS: current no-op; owned-artifact update; personal reordering/edits preserved; foreign game/alias edits refused; stale verification cleared; journal included in rollback; original uninstall backups retained.'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)) { throw 'Scratch escaped temporary directory.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
