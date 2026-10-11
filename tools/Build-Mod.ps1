#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RedkitPath = $env:WITCHER3_REDKIT_HOME,
    [string]$OutputDirectory,
    [string]$CookSnapshot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $RedkitPath) { throw 'Supply -RedkitPath or WITCHER3_REDKIT_HOME for the verified REDkit installation.' }
$redkitRoot = [IO.Path]::GetFullPath($RedkitPath)
$compilerDirectory = Join-Path $redkitRoot 'bin\x64_RedKit'
$compiler = Join-Path $compilerDirectory 'wcc_lite.exe'
$baseScripts = Join-Path $redkitRoot 'r4data\scripts'
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
if ($toolchain.SchemaVersion -ne 1) { throw 'Unsupported compiler evidence schema.' }
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'Installed wcc_lite.exe was not found.' }
$compilerHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash.ToLowerInvariant()
if ($compilerHash -cne $toolchain.CompilerSha256) { throw 'Compiler differs from the inspected toolchain. Inspect its help and verify a new invocation before updating compiler evidence.' }
foreach ($configuration in @('gameconf.cfg', 'redscripts.ini')) {
    if (-not (Test-Path -LiteralPath (Join-Path $redkitRoot ('bin\' + $configuration)) -PathType Leaf)) { throw "Missing REDkit configuration: $configuration" }
}
$baseHashes = [ordered]@{}
foreach ($property in $toolchain.BaseScriptSha256.PSObject.Properties) {
    $path = Join-Path $baseScripts $property.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing base script: $($property.Name)" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne $property.Value) { throw "REDkit hook source changed: $($property.Name). Inspect before compiling." }
    $baseHashes[$property.Name] = $hash
}
$sourceDirectory = Join-Path $projectRoot 'src\scripts'
if (@(Get-ChildItem -LiteralPath $sourceDirectory -Filter '*.ws' -File -Recurse).Count -eq 0) { throw 'No patch scripts found.' }
if (Test-Path -LiteralPath (Join-Path $sourceDirectory 'local\controllerCustomizer\presetData.ws')) {
    & (Join-Path $PSScriptRoot 'Generate-Assets.ps1') -Check | Out-Null
}
if ($CookSnapshot) {
    & (Join-Path $PSScriptRoot 'Package-Mod.ps1') -CookSnapshot $CookSnapshot -OutputDirectory $OutputDirectory
    return
}
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'build' }
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
# Each invocation owns a new directory; failed builds cannot reuse an old blob.
$runDirectory = Join-Path $outputRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
# Keep the source root named scripts; a patch-named root triggered source-link assertions.
$patchDirectory = Join-Path $runDirectory 'scripts'
Copy-Item -LiteralPath $sourceDirectory -Destination $patchDirectory -Recurse
$patchHashes = [ordered]@{}
foreach ($file in Get-ChildItem -LiteralPath $patchDirectory -Filter '*.ws' -File -Recurse | Sort-Object FullName) {
    $relative = $file.FullName.Substring($patchDirectory.Length + 1).Replace('\', '/')
    $patchHashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
$compiledDirectory = Join-Path $runDirectory 'compiled'
$logPath = Join-Path $runDirectory 'compiler.log'
# Plain directory paths avoid PS 5.1 trailing-backslash quoting ambiguity.
$arguments = @('compilescripts', $baseScripts, ('-patch=' + $patchDirectory), ('-out=' + $compiledDirectory))
Push-Location -LiteralPath $compilerDirectory
try {
    # PS 5.1 promotes native stderr to error records; collect it without aborting.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $compiler @arguments *> $logPath
        $compilerExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $savedPreference }
}
finally { Pop-Location }
$log = [IO.File]::ReadAllText($logPath)
$commandletStart = $log.IndexOf("Starting commandlet 'compilescripts'", [StringComparison]::Ordinal)
$compileErrors = @()
if ($commandletStart -ge 0) {
    $compileErrors = @($log.Substring($commandletStart) -split '\r?\n' | Where-Object { $_ -match '\[Error\]' })
}
$blobPath = Join-Path $compiledDirectory 'blob.rsblob'
$succeeded = $compilerExit -eq 0 -and $commandletStart -ge 0 -and $compileErrors.Count -eq 0 -and
    $log.Contains('Success! Patch scripts blob saved to') -and (Test-Path -LiteralPath $blobPath -PathType Leaf)
$blobHash = $null
$blobLength = 0
if (Test-Path -LiteralPath $blobPath -PathType Leaf) {
    $blobLength = (Get-Item -LiteralPath $blobPath).Length
    $blobHash = (Get-FileHash -LiteralPath $blobPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$succeeded = $succeeded -and $blobLength -gt 0
$report = [ordered]@{
    SchemaVersion = 1
    Compiler = $compiler
    CompilerSha256 = $compilerHash
    WorkingDirectory = $compilerDirectory
    Arguments = $arguments
    BaseHookSha256 = $baseHashes
    PatchSha256 = $patchHashes
    ExitCode = $compilerExit
    Succeeded = $succeeded
    LogPath = $logPath
    CoreDiagnostics = @($log -split '\r?\n' | Where-Object { $_ -match '\[Error\]\[(Core|Assert)\]' })
    CompileErrors = $compileErrors
    BlobPath = $blobPath
    BlobLength = $blobLength
    BlobSha256 = $blobHash
    RuntimeLoadVerified = $false
}
$reportPath = Join-Path $runDirectory 'build.json'
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
if (-not $succeeded) { throw "Compilation failed (exit $compilerExit). Review $logPath and $reportPath; no usable build is declared." }
Write-Output "PASS: patch compilation; $blobLength bytes. Runtime loading remains unverified."
Write-Output "Blob: $blobPath"
Write-Output "Evidence: $reportPath"
