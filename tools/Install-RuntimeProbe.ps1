#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Standalone')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Standalone')][string]$BuildReport,
    [Parameter(Mandatory = $true, ParameterSetName = 'Cooked')][switch]$CookedOnly,
    [Parameter(Mandatory = $true)][string]$CookSnapshot,
    [string]$GamePath = 'F:\Steam\steamapps\common\The Witcher 3'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = [IO.Path]::GetFullPath($GamePath)
if (Get-Process -Name 'witcher3' -ErrorAction SilentlyContinue) { throw 'Close The Witcher 3 before installing the probe.' }
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
if (-not $CookedOnly) {
    $build = Get-Content -LiteralPath $BuildReport -Raw | ConvertFrom-Json
    if (-not $build.Succeeded -or $build.ExitCode -ne 0 -or $build.CompileErrors.Count -ne 0 -or $build.CompilerSha256 -cne $toolchain.CompilerSha256) { throw 'Build is not verified.' }
}
$cook = Get-Content -LiteralPath (Join-Path $CookSnapshot 'cook.json') -Raw | ConvertFrom-Json
if (-not $cook.ScriptCompilationVerified -or $cook.UseLooseScripts -ne $false -or $cook.ObservedBlobRelativePath -ine 'mods/modCustomizeControllerScheme/content/precompiled.rsblob') { throw 'Cooked layout was not inspected.' }
if ($CookedOnly) {
    if ($cook.SchemaVersion -ne 2 -or $cook.EvidenceKind -cne 'RedkitEditorCook' -or
        $cook.CompilerSha256 -cne $toolchain.CompilerSha256 -or -not $cook.SourceTextEquivalenceVerified -or
        $cook.ScriptCompilationErrors.Count -ne 0) { throw 'Current-source editor cook is not verified.' }
    if ((Get-FileHash -LiteralPath (Join-Path $CookSnapshot 'cook.log')).Hash.ToLowerInvariant() -cne $cook.CookLogSha256) { throw 'Cook log changed.' }
    $sourceHashes = $cook.CanonicalSourceSha256
    $blobSource = Join-Path (Join-Path $CookSnapshot 'packed') $cook.ObservedBlobRelativePath
    $blobHash = $cook.FileSha256.'precompiled.rsblob'
    $blobLength = $cook.BlobLength
    $buildReportPath = $null
    $evidenceKind = 'RedkitEditorCook'
}
else {
    $sourceHashes = $build.PatchSha256
    $blobSource = $build.BlobPath
    $blobHash = $build.BlobSha256
    $blobLength = $build.BlobLength
    $buildReportPath = [IO.Path]::GetFullPath($BuildReport)
    $evidenceKind = 'StandaloneCommandlet'
}
foreach ($entry in $toolchain.BaseScriptSha256.PSObject.Properties) {
    $nativeSource = Join-Path (Join-Path $gameRoot 'content\content0\scripts') $entry.Name
    if ((Get-FileHash -LiteralPath $nativeSource).Hash.ToLowerInvariant() -cne $entry.Value) { throw "Installed hook source changed: $($entry.Name)" }
    if ($CookedOnly -and $cook.BaseHookSha256.($entry.Name) -cne $entry.Value) { throw 'Cooked hook fingerprint differs.' }
}
$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src\scripts') -Filter '*.ws' -File -Recurse)
if ($sourceFiles.Count -ne @($sourceHashes.PSObject.Properties).Count) { throw 'Build source inventory changed.' }
foreach ($entry in $sourceHashes.PSObject.Properties) {
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'src\scripts')).TrimEnd('\') + '\'
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $sourceRoot $entry.Name))
    if (-not $sourcePath.StartsWith($sourceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source escapes probe directory.' }
    if ((Get-FileHash -LiteralPath (Join-Path (Join-Path $projectRoot 'src\scripts') $entry.Name)).Hash.ToLowerInvariant() -cne $entry.Value) { throw 'Build does not match current probe source.' }
}
if ((Get-FileHash -LiteralPath $blobSource).Hash.ToLowerInvariant() -cne $blobHash -or $blobLength -le 0 -or (Get-Item -LiteralPath $blobSource).Length -ne $blobLength) { throw 'Compiled blob changed.' }
$modRoot = Join-Path $gameRoot 'mods\modCustomizeControllerScheme'
$menuPath = Join-Path $gameRoot 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'
if ((Test-Path -LiteralPath $modRoot) -or (Test-Path -LiteralPath $menuPath)) { throw 'Probe target already exists; refusing overwrite.' }
$menuSource = Join-Path $projectRoot 'src\menu\modControllerCustomizer.xml'
$menu = [xml](Get-Content -LiteralPath $menuSource -Raw)
foreach ($flag in @('ContextProbe', 'DiagramProbe')) {
    $variable = @($menu.UserConfig.Group.VisibleVars.Var | Where-Object id -EQ $flag)
    if ($variable.Count -ne 1 -or $variable[0].value -cne 'false') { throw 'Runtime experiments must default off.' }
}
$general = Join-Path $gameRoot 'bin\config\base\general.ini'
$generalBytes = [IO.File]::ReadAllBytes($general)
$generalText = [IO.File]::ReadAllText($general)
$headers = [regex]::Matches($generalText, '(?m)^\[([^\]]+)\]\s*$')
if ($headers.Count -ne 1 -or $headers[0].Groups[1].Value -cne 'General' -or $generalText -match '(?im)^\s*DBGConsoleOn\s*=') { throw 'Console configuration needs separate inspection; refusing to replace existing settings.' }
$newline = "`n"
if ($generalText.Contains("`r`n")) { $newline = "`r`n" }
$suffix = 'DBGConsoleOn=true' + $newline
if (-not $generalText.EndsWith("`n")) { $suffix = $newline + $suffix }
$consoleBytes = [byte[]]($generalBytes + [Text.Encoding]::UTF8.GetBytes($suffix))
$run = Join-Path $projectRoot ('work\runtime-probe\install-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $run 'payload\mods\modCustomizeControllerScheme\content'), (Join-Path $run 'backups') -Force | Out-Null
$payloadContent = Join-Path $run 'payload\mods\modCustomizeControllerScheme\content'
Copy-Item -LiteralPath $blobSource -Destination (Join-Path $payloadContent 'precompiled.rsblob')
foreach ($name in @('info.json', 'metadata.store')) {
    $source = Join-Path (Join-Path $CookSnapshot 'packed\mods\modCustomizeControllerScheme\content') $name
    if ((Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant() -cne $cook.FileSha256.$name) { throw 'Cooked metadata changed.' }
    Copy-Item -LiteralPath $source -Destination (Join-Path $payloadContent $name)
}
[IO.File]::WriteAllBytes((Join-Path $run 'backups\general.ini'), $generalBytes)
[IO.File]::WriteAllBytes((Join-Path $run 'console.ini'), $consoleBytes)
Copy-Item -LiteralPath $menuSource -Destination (Join-Path $run 'menu.xml')
$items = @()
foreach ($name in @('precompiled.rsblob', 'info.json', 'metadata.store')) {
    $items += [ordered]@{ RelativePath = 'mods/modCustomizeControllerScheme/content/' + $name; ExistedBefore = $false; Backup = $null; OriginalSha256 = $null; InstalledSha256 = (Get-FileHash -LiteralPath (Join-Path $payloadContent $name)).Hash.ToLowerInvariant() }
}
$items += [ordered]@{ RelativePath = 'bin/config/r4game/user_config_matrix/pc/modControllerCustomizer.xml'; ExistedBefore = $false; Backup = $null; OriginalSha256 = $null; InstalledSha256 = (Get-FileHash -LiteralPath (Join-Path $run 'menu.xml')).Hash.ToLowerInvariant() }
$items += [ordered]@{ RelativePath = 'bin/config/base/general.ini'; ExistedBefore = $true; Backup = 'backups/general.ini'; OriginalSha256 = (Get-FileHash -LiteralPath (Join-Path $run 'backups\general.ini')).Hash.ToLowerInvariant(); InstalledSha256 = (Get-FileHash -LiteralPath (Join-Path $run 'console.ini')).Hash.ToLowerInvariant() }
$journal = [ordered]@{ SchemaVersion = 1; Purpose = 'Phase0LoadProbe'; GamePath = $gameRoot; BuildReport = $buildReportPath; EvidenceKind = $evidenceKind; CookSnapshot = [IO.Path]::GetFullPath($CookSnapshot); Restored = $false; InstallationComplete = $false; RuntimeLoadVerified = $false; Items = $items }
$journalPath = Join-Path $run 'install.json'
[IO.File]::WriteAllText($journalPath, ($journal | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
# Repeat ownership/config checks immediately before live mutation.
if ((Get-Process -Name 'witcher3' -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath $modRoot) -or (Test-Path -LiteralPath $menuPath) -or (Get-FileHash -LiteralPath $general).Hash.ToLowerInvariant() -cne $items[-1].OriginalSha256) { throw 'Installation preconditions changed.' }
Copy-Item -LiteralPath (Join-Path $run 'payload\mods\modCustomizeControllerScheme') -Destination $modRoot -Recurse
Copy-Item -LiteralPath (Join-Path $run 'menu.xml') -Destination $menuPath
[IO.File]::WriteAllBytes($general, $consoleBytes)
foreach ($item in $items) {
    if ((Get-FileHash -LiteralPath (Join-Path $gameRoot $item.RelativePath)).Hash.ToLowerInvariant() -cne $item.InstalledSha256) { throw "Installed probe verification failed; retain journal/backups: $journalPath" }
}
$journal.InstallationComplete = $true
[IO.File]::WriteAllText($journalPath, ($journal | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Output 'PASS: temporary load probe installed; runtime behavior remains unverified.'
Write-Output "Journal: $journalPath"
Write-Output 'Existing mods and personal input/user.settings were not edited. ContextProbe and DiagramProbe default off.'
