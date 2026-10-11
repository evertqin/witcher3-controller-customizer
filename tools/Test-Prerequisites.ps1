#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GamePath,
    [string[]]$SteamLibraryPaths = @(),
    [string]$RedkitPath = $env:WITCHER3_REDKIT_HOME,
    [switch]$RequireReady
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'fixtures\legacy\compatibility.json') -Raw | ConvertFrom-Json
$gameRoot = [IO.Path]::GetFullPath($GamePath)
$issues = New-Object 'Collections.Generic.List[string]'
$inputPath = Join-Path $gameRoot 'bin\config\r4game\legacy\base\input_qwerty.ini'
$uiPath = Join-Path $gameRoot 'content\content0\scripts\game\gui\main_menu\ingamemenu\igmUtilities.ws'
$inputVersion = $null
if (Test-Path -LiteralPath $inputPath -PathType Leaf) {
    $inputText = [IO.File]::ReadAllText($inputPath)
    if ($inputText -match '(?m)^Version=(\d+)\s*$') { $inputVersion = [int]$Matches[1] }
}
if ($inputVersion -ne $manifest.InputVersion) { $issues.Add('Missing or incompatible native input format.') }
$uiHash = $null
if (Test-Path -LiteralPath $uiPath -PathType Leaf) { $uiHash = (Get-FileHash -LiteralPath $uiPath -Algorithm SHA256).Hash.ToLowerInvariant() }
if ($uiHash -ne $manifest.VanillaUiSha256) {
    $issues.Add('Installed controller diagram source differs from the historical baseline; inspect it before designing hooks. Do not replace the manifest fingerprint to bypass this gate.')
}
$renderers = @(foreach ($renderer in @('x64', 'x64_dx12')) {
    $exePath = Join-Path $gameRoot "bin\$renderer\witcher3.exe"
    if (Test-Path -LiteralPath $exePath -PathType Leaf) {
        $item = Get-Item -LiteralPath $exePath
        [pscustomobject]@{ Directory = $renderer; Path = $exePath; FileVersion = $item.VersionInfo.FileVersion }
    }
})
if ($renderers.Count -eq 0) { $issues.Add('No game executable found.') }
$menuPath = Join-Path $gameRoot 'bin\config\r4game\user_config_matrix\pc'
$menuFileLists = @(foreach ($fileName in @('dx11filelist.txt', 'dx12filelist.txt')) {
    if (Test-Path -LiteralPath (Join-Path $menuPath $fileName) -PathType Leaf) { $fileName }
})
$legacyPath = Join-Path $gameRoot 'mods\modDarkSoulsControllerScheme'
$legacyPresent = Test-Path -LiteralPath $legacyPath
if ($legacyPresent) { $issues.Add('Legacy diagram override is present; any installation needs an explicit reversible migration.') }

# Search only configured libraries and explicit toolkit roots, never entire drives.
$libraries = New-Object 'Collections.Generic.List[string]'
foreach ($library in $SteamLibraryPaths) { $libraries.Add([IO.Path]::GetFullPath($library)) }
$steamRoot = $null
if (Test-Path 'HKCU:\Software\Valve\Steam') {
    $steamRegistry = Get-ItemProperty 'HKCU:\Software\Valve\Steam'
    if ($steamRegistry.PSObject.Properties['SteamPath']) { $steamRoot = $steamRegistry.SteamPath }
}
if (-not $steamRoot) {
    $steamRoot = Split-Path (Split-Path (Split-Path $gameRoot -Parent) -Parent) -Parent
}
$libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
if (Test-Path -LiteralPath $libraryFile -PathType Leaf) {
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($libraryFile), '"path"\s+"([^"]+)"')) {
        $libraries.Add($match.Groups[1].Value.Replace('\\', '\'))
    }
}
$libraries = @($libraries | Sort-Object -Unique)
$toolkitRoots = New-Object 'Collections.Generic.List[string]'
if ($RedkitPath) {
    if (-not (Test-Path -LiteralPath $RedkitPath -PathType Container)) { $issues.Add('Explicit REDkit directory does not exist.') }
    else { $toolkitRoots.Add([IO.Path]::GetFullPath($RedkitPath)) }
}
$unreadableLibraries = @()
foreach ($library in $libraries) {
    $commonPath = Join-Path $library 'steamapps\common'
    if (-not (Test-Path -LiteralPath $commonPath -PathType Container)) { $unreadableLibraries += $library; continue }
    foreach ($directory in Get-ChildItem -LiteralPath $commonPath -Directory) {
        if ($directory.Name -match '(?i)redkit|witcher.*modkit') { $toolkitRoots.Add($directory.FullName) }
    }
}
$candidates = @(foreach ($toolkitRoot in @($toolkitRoots | Sort-Object -Unique)) {
    foreach ($exe in Get-ChildItem -LiteralPath $toolkitRoot -Filter '*.exe' -File -Recurse) {
        if ($exe.Name -match '(?i)^editor\.exe$|scriptstudio|witcher3editor|redkit|wcc|script.*compil') {
            [pscustomobject]@{ Path = $exe.FullName; FileVersion = $exe.VersionInfo.FileVersion }
        }
    }
})
if ($candidates.Count -eq 0) { $issues.Add('No REDkit/editor/compiler candidate found in inspected locations.') }
# Discovery alone never establishes a valid compiler invocation or native hook support.
$issues.Add('Discovery does not verify compilation; see Build-Mod build.json evidence. Prototype loading and runtime acceptance remain unverified.')
[pscustomobject]@{
    TargetBaseline = $manifest.GameVersion
    GamePath = $gameRoot
    Renderers = $renderers
    InputVersion = $inputVersion
    ExpectedUiSha256 = $manifest.VanillaUiSha256
    ActualUiSha256 = $uiHash
    MenuFileLists = $menuFileLists
    MenuRegistrationVerified = $false
    LegacyOverridePresent = $legacyPresent
    SearchedSteamLibraries = $libraries
    UnavailableLibraries = $unreadableLibraries
    CompilerCandidates = $candidates
    CompilerInvocationVerified = $false
    Ready = $false
    Issues = @($issues.ToArray())
} | ConvertTo-Json -Depth 6
if ($RequireReady) { throw 'Phase 0 prerequisite gate is not satisfied. See the evidence report above and docs/build.md.' }
