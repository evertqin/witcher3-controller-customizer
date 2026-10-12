#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CookSnapshot, [string]$OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Split-Path $PSScriptRoot -Parent
if (Test-Path -LiteralPath (Join-Path $repo 'data/schemes/runtime-baseline.json')) { throw 'This historical Phase 1 packager cannot package selection schema 2; use the Phase 1.1 candidate workflow.' }
$snapshot=(Resolve-Path -LiteralPath $CookSnapshot).ProviderPath
$cook=Get-Content -LiteralPath (Join-Path $snapshot 'cook.json') -Raw | ConvertFrom-Json
$toolchain=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
& (Join-Path $PSScriptRoot 'Generate-Assets.ps1') -Check | Out-Null
if ($cook.SchemaVersion -ne 2 -or -not $cook.ScriptCompilationVerified -or -not $cook.SourceTextEquivalenceVerified -or
    $cook.UseLooseScripts -ne $false -or $cook.ScriptCompilationErrors.Count -ne 0 -or $cook.CompilerSha256 -cne $toolchain.CompilerSha256 -or
    $cook.ObservedBlobRelativePath -ine 'mods/modCustomizeControllerScheme/content/precompiled.rsblob') { throw 'Unverified editor cook.' }
if ((Get-FileHash -LiteralPath (Join-Path $snapshot 'cook.log')).Hash.ToLowerInvariant() -cne $cook.CookLogSha256) { throw 'Cook log changed.' }
foreach ($hook in $toolchain.BaseScriptSha256.PSObject.Properties) {
    if ($cook.BaseHookSha256.($hook.Name) -cne $hook.Value) { throw 'Cooked hook fingerprint changed.' }
}
$sourceRoot=[IO.Path]::GetFullPath((Join-Path $repo 'src\scripts')).TrimEnd('\') + '\'
if (@(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Filter '*.ws' -File).Count -ne @($cook.CanonicalSourceSha256.PSObject.Properties).Count) { throw 'Source inventory changed.' }
foreach ($source in $cook.CanonicalSourceSha256.PSObject.Properties) {
    $target=[IO.Path]::GetFullPath((Join-Path $sourceRoot $source.Name))
    if (-not $target.StartsWith($sourceRoot,[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -cne $source.Value) { throw 'Cook does not match current source.' }
}
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $repo 'build\phase1-packages' }
$run=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ((Get-Date -Format yyyyMMdd-HHmmss) + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$stage=Join-Path $run 'package'
[void][IO.Directory]::CreateDirectory($stage)
foreach ($relative in @('data','fixtures\legacy','src\scripts','src\generated','src\menu')) {
    $destination=Join-Path $stage $relative
    [void][IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $destination -Recurse
}
foreach ($name in @('Install-Mod.ps1','Update-Mod.ps1','Restore-Backup.ps1','FileTransaction.psm1','PersonalContextProbe.psm1','InputRecords.psm1','Generate-Assets.ps1','compiler-toolchain.json')) {
    [void][IO.Directory]::CreateDirectory((Join-Path $stage 'tools'))
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $stage ('tools\' + $name))
}
$content=Join-Path $stage 'packed\mods\modCustomizeControllerScheme\content'
[void][IO.Directory]::CreateDirectory($content)
foreach ($name in @('precompiled.rsblob','info.json','metadata.store')) {
    $source=Join-Path $snapshot ('packed\mods\modCustomizeControllerScheme\content\' + $name)
    if ((Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant() -cne $cook.FileSha256.$name) { throw 'Cooked artifact changed.' }
    if ($name -ceq 'precompiled.rsblob' -and ((Get-Item -LiteralPath $source).Length -ne $cook.BlobLength -or $cook.BlobLength -le 0)) { throw 'Invalid blob length.' }
    Copy-Item -LiteralPath $source -Destination (Join-Path $content $name)
}
foreach ($name in @('cook.json','cook.log')) {
    Copy-Item -LiteralPath (Join-Path $snapshot $name) -Destination (Join-Path $stage $name)
}
$readme=@'
# Controller Customizer — Phase 1 development candidate

Current: hold A to canter; double-press and hold A to gallop; L3 interacts.
Alt1: hold L3 to canter; double-press and hold L3 to gallop; A interacts.
Choose Settings > Controller Customizer. Native settings persist the choice.
Existing-save startup activates installed aliases automatically.

Automated tests open Pause with the controller Back button and brake with the
existing native X Stop key between riding gestures. Keyboard Escape replay
currently opens then closes a subsequent menu even with routing disabled;
its root cause and physical-keyboard acceptance remain unresolved.

Phase 1 is accepted for continuation; the user waived additional manual gates.
Ciri, scripted riding, held-switch/focus/disconnect behavior, enlarged diagrams
and other script mods retain untested coverage notes. Only the inspected PC/DX12 environment has runtime
evidence. DX11 and other devices/builds are not declared supported.

Installation requires an existing supported Souls Current/Alt1 input profile.
The installer preserves personal keyboard/axis/unowned pad records and appends
eight contexts; customized shared Souls slots refuse rather than show wrong labels.
This package includes its frozen editor cook receipt and source tree.
Run tools/Install-Mod.ps1 with -CookSnapshot <this package folder>, -GamePath and optional
-DocumentsPath. Keep the reported install journal. An unchanged repeat install
uses -JournalFile. -IsolateLegacy removes only a recognized unchanged legacy
diagram component and retains its bytes for rollback. Unknown legacy files refuse.
Update using tools/Update-Mod.ps1 -JournalFile <journal> -CookSnapshot <new verified cook>.
Updates retain personal bindings and original uninstall backups.
Restore using tools/Restore-Backup.ps1 -JournalFile <journal>. Later unrelated
input changes survive removal of verified owned contexts; changed owned files refuse.
No console setting or DX11/DX12 menu-list files are installed.

Native input fixture provenance/ownership: fixtures/legacy/PROVENANCE.md.
No extracted native game/SDK scripts are included. No new distribution license
has been selected; retain this candidate for local review until release decisions.
'@
[IO.File]::WriteAllText((Join-Path $stage 'README.md'),$readme,[Text.UTF8Encoding]::new($false))
$files=[ordered]@{}
foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName) {
    $relative=$file.FullName.Substring($stage.Length+1).Replace('\','/')
    $files[$relative]=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant()
}
$manifest=[ordered]@{SchemaVersion=1; ReleaseVerified=$false; CompilerSha256=$cook.CompilerSha256;
    BaseHookSha256=$cook.BaseHookSha256; SourceSha256=$cook.CanonicalSourceSha256; Files=$files}
[IO.File]::WriteAllText((Join-Path $stage 'package.json'),($manifest | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath=Join-Path $run 'controller-customizer-phase1-candidate.zip'
$stream=[IO.File]::Open($zipPath,[IO.FileMode]::CreateNew)
$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
try {
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName) {
        $relative=$file.FullName.Substring($stage.Length+1).Replace('\','/')
        $entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime=[DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
        $output=$entry.Open()
        try { $bytes=[IO.File]::ReadAllBytes($file.FullName); $output.Write($bytes,0,$bytes.Length) } finally { $output.Dispose() }
    }
} finally { $zip.Dispose(); $stream.Dispose() }
Write-Output "Candidate package: $zipPath"
Write-Output "SHA256: $((Get-FileHash -LiteralPath $zipPath).Hash.ToLowerInvariant())"
