#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectRoot)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('cc-editor-sync-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $repo=Join-Path $scratch 'repo'
    $project=Join-Path $scratch 'project'
    $canonical=Join-Path $repo 'src\scripts\local\controllerCustomizer'
    $editor=Join-Path $project 'workspace\scripts\local\controllerCustomizer'
    $cook=Join-Path $scratch 'cook'
    New-Item -ItemType Directory -Path $canonical,$editor,$cook | Out-Null
    $utf8=[Text.UTF8Encoding]::new($false)
    $utf16=[Text.Encoding]::Unicode
    $projectFile=Join-Path $project 'owned.w3edit'
    [IO.File]::WriteAllText($projectFile,'unchanged project metadata',$utf8)
    $projectHash=(Get-FileHash $projectFile).Hash
    $canonicalHashes=@{};$editorHashes=@{}
    foreach ($name in @('bindings.ws','config.ws')) {
        [IO.File]::WriteAllText((Join-Path $canonical $name),'old authored source',$utf8)
        [IO.File]::WriteAllText((Join-Path $editor $name),'old authored source',$utf16)
        $key='local/controllerCustomizer/' + $name
        $canonicalHashes[$key]=(Get-FileHash (Join-Path $canonical $name)).Hash.ToLowerInvariant()
        $editorHashes[$key]=(Get-FileHash (Join-Path $editor $name)).Hash.ToLowerInvariant()
    }
    @{SchemaVersion=2;EvidenceKind='RedkitEditorCook';SourceTextEquivalenceVerified=$true;EditorProject=$project;CanonicalSourceSha256=$canonicalHashes;EditorSourceSha256=$editorHashes} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $cook 'cook.json') -Encoding UTF8
    $config=Join-Path $scratch 'editor.json'
    @{repo=$repo;project_file=$projectFile} | ConvertTo-Json | Set-Content $config -Encoding UTF8
    [IO.File]::WriteAllText((Join-Path $canonical 'bindings.ws'),'new authored source',$utf8)
    $journal=Join-Path $scratch 'sync-backup'
    & (Join-Path $ProjectRoot 'tools\Sync-EditorSources.ps1') -ConfigFile $config -PreviousCookSnapshot $cook -JournalDirectory $journal | Out-Null
    $state=Get-Content (Join-Path $journal 'files.json') -Raw | ConvertFrom-Json
    if ($state.Items.Count -ne 1 -or -not $state.InstallationComplete -or [IO.File]::ReadAllText((Join-Path $editor 'bindings.ws')) -cne 'new authored source') { throw 'Owned source sync failed.' }
    if ((Get-FileHash $projectFile).Hash -cne $projectHash -or (Get-FileHash (Join-Path $editor 'config.ws')).Hash.ToLowerInvariant() -cne $editorHashes['local/controllerCustomizer/config.ws']) { throw 'Unowned/unchanged file modified.' }
    $before=(Get-FileHash (Join-Path $journal 'files.json')).Hash
    & (Join-Path $ProjectRoot 'tools\Sync-EditorSources.ps1') -ConfigFile $config -PreviousCookSnapshot $cook -JournalDirectory $journal | Out-Null
    if ((Get-FileHash (Join-Path $journal 'files.json')).Hash -cne $before) { throw 'No-op sync altered its journal.' }
    [IO.File]::WriteAllText((Join-Path $canonical 'bindings.ws'),'another authored source',$utf8)
    [IO.File]::WriteAllText((Join-Path $editor 'config.ws'),'independent editor edit',$utf16)
    [IO.File]::WriteAllText((Join-Path $canonical 'config.ws'),'changed canonical config',$utf8)
    $installed=(Get-FileHash (Join-Path $editor 'bindings.ws')).Hash
    $refused=$false
    try { & (Join-Path $ProjectRoot 'tools\Sync-EditorSources.ps1') -ConfigFile $config -PreviousCookSnapshot $cook -JournalDirectory (Join-Path $scratch 'refused') | Out-Null } catch { $refused=$true }
    if (-not $refused -or (Get-FileHash (Join-Path $editor 'bindings.ws')).Hash -cne $installed) { throw 'Independent editor edit was overwritten or preflight partially wrote.' }
    Write-Output 'PASS: owned UTF-16 sync, verified backup, unchanged metadata/other source, idempotent no-op and independent-editor-change refusal.'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    $tempPrefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Scratch cleanup escaped temporary directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
