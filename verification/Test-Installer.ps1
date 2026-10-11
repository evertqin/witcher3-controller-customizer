#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CookSnapshot,
      [string]$SourceGamePath='F:\Steam\steamapps\common\The Witcher 3',
      [string]$LegacyFixture, [string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
if ($ProjectRoot) { $repo = (Resolve-Path -LiteralPath $ProjectRoot).ProviderPath }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('cc-phase1-install-' + [guid]::NewGuid().ToString('N'))
Import-Module (Join-Path $repo 'tools\FileTransaction.psm1') -Force
Assert-CCGameClosed
function Assert-Refused([scriptblock]$Action, [string]$Reason) {
    $refused=$false
    try { & $Action | Out-Null } catch {
        if ($Reason -and $_.Exception.Message -notmatch [regex]::Escape($Reason)) { throw }
        $refused=$true
    }
    if (-not $refused) { throw 'Unsafe operation was accepted.' }
}
try {
    $game=Join-Path $scratch 'game'
    $profile=Join-Path $scratch 'OneDrive Documents\The Witcher 3'
    [void][IO.Directory]::CreateDirectory($profile)
    $input=Join-Path $profile 'input.settings'
    Copy-Item -LiteralPath (Join-Path $repo 'fixtures\legacy\Current\input.settings') -Destination $input
    $original=[IO.File]::ReadAllBytes($input)
    $exe='bin\x64_dx12\witcher3.exe'
    [void][IO.Directory]::CreateDirectory((Split-Path (Join-Path $game $exe) -Parent))
    Copy-Item -LiteralPath (Join-Path $SourceGamePath $exe) -Destination (Join-Path $game $exe)
    $nativeInput='bin\config\r4game\legacy\base\input_qwerty.ini'
    [void][IO.Directory]::CreateDirectory((Split-Path (Join-Path $game $nativeInput) -Parent))
    [IO.File]::WriteAllText((Join-Path $game $nativeInput),"[InputSettings]`r`nVersion=60`r`n")
    $toolchain=Get-Content -LiteralPath (Join-Path $repo 'tools\compiler-toolchain.json') -Raw | ConvertFrom-Json
    foreach ($hook in $toolchain.BaseScriptSha256.PSObject.Properties) {
        $relative='content\content0\scripts\' + $hook.Name
        [void][IO.Directory]::CreateDirectory((Split-Path (Join-Path $game $relative) -Parent))
        Copy-Item -LiteralPath (Join-Path $SourceGamePath $relative) -Destination (Join-Path $game $relative)
    }
    $install=Join-Path $repo 'tools\Install-Mod.ps1'
    $restore=Join-Path $repo 'tools\Restore-Backup.ps1'
    $journalRoot=Join-Path $scratch 'journal'
    $arguments=@{GamePath=$game; DocumentsPath=$profile; CookSnapshot=$CookSnapshot; JournalDirectory=$journalRoot}
    $unrelated=Join-Path $game 'mods\modUnrelatedFixture\content\keep.txt'
    [void][IO.Directory]::CreateDirectory((Split-Path $unrelated -Parent))
    [IO.File]::WriteAllText($unrelated,'Unowned mod bytes')
    $unrelatedHash=Get-CCFileHash $unrelated
    $hookTarget=Join-Path $game 'content\content0\scripts\game\inputManager.ws'
    $hookBytes=[IO.File]::ReadAllBytes($hookTarget)
    [IO.File]::AppendAllText($hookTarget,'// incompatible')
    Assert-Refused { & $install @arguments } 'Required native hook is incompatible'
    if ((Get-CCFileHash $input) -cne (Get-CCFileHash (Join-Path $repo 'fixtures\legacy\Current\input.settings')) -or (Test-Path -LiteralPath $journalRoot)) { throw 'Refusal mutated installation.' }
    [IO.File]::WriteAllBytes($hookTarget,$hookBytes)
    $nativeTarget=Join-Path $game $nativeInput
    [IO.File]::WriteAllText($nativeTarget,"[InputSettings]`r`nVersion=59`r`n")
    Assert-Refused { & $install @arguments } 'Input format is incompatible'
    if (Test-Path -LiteralPath $journalRoot) { throw 'Input-version refusal created a journal.' }
    [IO.File]::WriteAllText($nativeTarget,"[InputSettings]`r`nVersion=60`r`n")
    $exeTarget=Join-Path $game $exe
    $exeBackup=Join-Path $scratch 'verified-executable.exe'
    Copy-Item -LiteralPath $exeTarget -Destination $exeBackup
    [IO.File]::WriteAllText($exeTarget,'Unsupported executable without a version resource')
    Assert-Refused { & $install @arguments } 'Game executable version is incompatible'
    if (Test-Path -LiteralPath $journalRoot) { throw 'Executable-version refusal created a journal.' }
    Copy-Item -LiteralPath $exeBackup -Destination $exeTarget -Force
    & $install @arguments | Out-Null
    $journal=Join-Path $journalRoot 'install.json'
    $state=Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
    if ($state.RuntimeVerified -or $state.ReleaseVerified) { throw 'Installation invented runtime/release claims.' }
    $installed=[IO.File]::ReadAllBytes($input)
    for ($index=0; $index -lt $original.Length; $index+=1) { if ($installed[$index] -ne $original[$index]) { throw 'Original personal prefix changed.' } }
    $beforeHash=Get-CCFileHash $journal
    & $install -GamePath $game -JournalFile $journal | Out-Null
    if ((Get-CCFileHash $journal) -cne $beforeHash) { throw 'Idempotent install mutated journal.' }
    $menu=Join-Path $game 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'
    $menuBytes=[IO.File]::ReadAllBytes($menu)
    [IO.File]::AppendAllText($menu,'<!-- later mod edit -->')
    Assert-Refused { & $restore -JournalFile $journal }
    if ((Get-CCFileHash $input) -cne $state.Items[0].InstalledSha256) { throw 'Restore refusal mutated input.' }
    [IO.File]::WriteAllBytes($menu,$menuBytes)
    [IO.File]::AppendAllText($input,"`r`n[LaterPersonalKeys]`r`nIK_F1=(Action=UnownedTest)`r`n")
    & $restore -JournalFile $journal | Out-Null
    if ((Get-CCFileHash $unrelated) -cne $unrelatedHash) { throw 'Unowned mod bytes changed.' }
    if ($LegacyFixture) {
        $legacy=Join-Path $game 'mods\modDarkSoulsControllerScheme\content\scripts\game\gui\main_menu\ingamemenu\igmUtilities.ws'
        [void][IO.Directory]::CreateDirectory((Split-Path $legacy -Parent))
        Copy-Item -LiteralPath $LegacyFixture -Destination $legacy
        $legacyHash=Get-CCFileHash $legacy
        $arguments.JournalDirectory=Join-Path $scratch 'legacy-journal'
        Assert-Refused { & $install @arguments }
        [IO.File]::AppendAllText($legacy,'// unrelated legacy customization')
        Assert-Refused { & $install @arguments -IsolateLegacy }
        Copy-Item -LiteralPath $LegacyFixture -Destination $legacy -Force
        & $install @arguments -IsolateLegacy | Out-Null
        if (Test-Path -LiteralPath $legacy) { throw 'Known legacy component was not isolated.' }
        & $restore -JournalFile (Join-Path $arguments.JournalDirectory 'install.json') | Out-Null
        if ((Get-CCFileHash $legacy) -cne $legacyHash) { throw 'Legacy restoration changed original bytes.' }
    }
    $after=[IO.File]::ReadAllText($input)
    if ($after -match '\[CC_PROBE_' -or $after -notmatch 'IK_F1=\(Action=UnownedTest\)') { throw 'Owned-only removal lost later personal input.' }
    if (Test-Path -LiteralPath $menu) { throw 'Owned menu was not removed.' }
    & $restore -JournalFile $journal | Out-Null
    # Simulate a lock appearing after the first successful write.
    $first=Join-Path $scratch 'first.txt'
    $second=Join-Path $scratch 'second.txt'
    [IO.File]::WriteAllText($first,'first before')
    [IO.File]::WriteAllText($second,'second before')
    $firstHash=Get-CCFileHash $first
    $secondHash=Get-CCFileHash $second
    $entries=@(
        [pscustomobject]@{Target=$first;BeforeSha256=$firstHash;Bytes=[Text.Encoding]::UTF8.GetBytes('first after')},
        [pscustomobject]@{Target=$second;BeforeSha256=$secondHash;Bytes=[Text.Encoding]::UTF8.GetBytes('second after')})
    $script:locked=$null
    try {
        Assert-Refused { Invoke-CCFileTransaction -Entries $entries -JournalDirectory (Join-Path $scratch 'locked-journal') -BeforeApply { param($index) if ($index -eq 1) { $script:locked=[IO.File]::Open($second,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) } } }
    } finally { if ($script:locked) { $script:locked.Dispose() } }
    if ((Get-CCFileHash $first) -cne $firstHash -or (Get-CCFileHash $second) -cne $secondHash) { throw 'Partial failure did not roll back exactly.' }
    Write-Output 'PASS: hook/input/executable compatibility refusal; personal-prefix preservation; idempotence; later-edit refusal; owned-only input removal; locked-file partial rollback.'
    if ($LegacyFixture) { Write-Output 'PASS: conflicting/customized legacy refusal; explicit known-component isolation; byte-exact legacy restoration.' }
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)) { throw 'Scratch escaped temporary directory.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
