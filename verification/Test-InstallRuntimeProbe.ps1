#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CookSnapshot,
    [string]$SourceGamePath = 'F:\Steam\steamapps\common\The Witcher 3'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('cc-probe-install-' + [Guid]::NewGuid().ToString('N'))
$shell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    $project = Join-Path $testRoot 'project'
    $game = Join-Path $testRoot 'game'
    $snapshot = Join-Path $testRoot 'cook'
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'tools'), (Join-Path $projectRoot 'src') -Destination $project -Recurse
    Copy-Item -LiteralPath $CookSnapshot -Destination $snapshot -Recurse
    $toolchain = Get-Content -LiteralPath (Join-Path $project 'tools\compiler-toolchain.json') -Raw | ConvertFrom-Json
    foreach ($entry in $toolchain.BaseScriptSha256.PSObject.Properties) {
        $destination = Join-Path (Join-Path $game 'content\content0\scripts') $entry.Name
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path (Join-Path $SourceGamePath 'content\content0\scripts') $entry.Name) -Destination $destination
    }
    $general = Join-Path $game 'bin\config\base\general.ini'
    $menu = Join-Path $game 'bin\config\r4game\user_config_matrix\pc\modControllerCustomizer.xml'
    $mod = Join-Path $game 'mods\modCustomizeControllerScheme'
    $legacy = Join-Path $game 'mods\modExisting\preserve.txt'
    New-Item -ItemType Directory -Path (Split-Path $general -Parent), (Split-Path $menu -Parent), (Split-Path $legacy -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($general, "[General]`r`nConfigVersion=7`r`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($legacy, 'existing mod')
    $originalHash = (Get-FileHash -LiteralPath $general).Hash
    $legacyHash = (Get-FileHash -LiteralPath $legacy).Hash
    $reportPath = Join-Path $snapshot 'cook.json'
    $reportBytes = [IO.File]::ReadAllBytes($reportPath)
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $property = @($report.CanonicalSourceSha256.PSObject.Properties)[0]
    $property.Value = '0' * 64
    [IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 8))
    $installer = Join-Path $project 'tools\Install-RuntimeProbe.ps1'
    $preference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $refusal = & $shell -NoProfile -ExecutionPolicy Bypass -File $installer -CookedOnly -CookSnapshot $snapshot -GamePath $game 2>&1
        $refusalExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $preference }
    if ($refusalExit -eq 0 -or ($refusal -join "`n") -notmatch 'Build does not match current probe source') { throw 'Stale cook was not refused.' }
    if ((Test-Path -LiteralPath $mod) -or (Test-Path -LiteralPath $menu) -or (Get-FileHash -LiteralPath $general).Hash -cne $originalHash) { throw 'Stale-cook refusal mutated targets.' }
    [IO.File]::WriteAllBytes($reportPath, $reportBytes)
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $blob = Join-Path (Join-Path $snapshot 'packed') $report.ObservedBlobRelativePath
    $blobBytes = [IO.File]::ReadAllBytes($blob)
    [IO.File]::WriteAllBytes($blob, [byte[]]@(0))
    try {
        $ErrorActionPreference = 'Continue'
        $refusal = & $shell -NoProfile -ExecutionPolicy Bypass -File $installer -CookedOnly -CookSnapshot $snapshot -GamePath $game 2>&1
        $refusalExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $preference }
    if ($refusalExit -eq 0 -or ($refusal -join "`n") -notmatch 'Compiled blob changed') { throw 'Changed blob was not refused.' }
    if ((Test-Path -LiteralPath $mod) -or (Test-Path -LiteralPath $menu) -or (Get-FileHash -LiteralPath $general).Hash -cne $originalHash) { throw 'Changed-blob refusal mutated targets.' }
    [IO.File]::WriteAllBytes($blob, $blobBytes)
    $output = & $shell -NoProfile -ExecutionPolicy Bypass -File $installer -CookedOnly -CookSnapshot $snapshot -GamePath $game
    if ($LASTEXITCODE -ne 0) { throw 'Verified cooked installation failed.' }
    $journalPath = @($output | Where-Object { $_ -like 'Journal: *' })[0].Substring(9)
    $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
    if (-not $journal.InstallationComplete -or $journal.EvidenceKind -cne 'RedkitEditorCook' -or $journal.RuntimeLoadVerified) { throw 'Incorrect installation evidence.' }
    foreach ($item in $journal.Items) {
        if ((Get-FileHash -LiteralPath (Join-Path $game $item.RelativePath)).Hash.ToLowerInvariant() -cne $item.InstalledSha256) { throw 'Installed bytes differ from journal.' }
    }
    if ([IO.File]::ReadAllText($general) -cne "[General]`r`nConfigVersion=7`r`nDBGConsoleOn=true`r`n") { throw 'Console addition changed original configuration.' }
    & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $project 'tools\Restore-RuntimeProbe.ps1') -JournalFile $journalPath
    if ($LASTEXITCODE -ne 0) { throw 'Installed probe restoration failed.' }
    if ((Test-Path -LiteralPath $mod) -or (Test-Path -LiteralPath $menu) -or (Get-FileHash -LiteralPath $general).Hash -cne $originalHash -or (Get-FileHash -LiteralPath $legacy).Hash -cne $legacyHash) { throw 'Round trip did not preserve original targets.' }
    Write-Output 'PASS: stale cook and changed blob refused without mutation; cooked probe install/restore preserves configuration and existing mods (Windows PowerShell 5.1).'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
