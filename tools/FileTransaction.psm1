#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-CCFileHash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-CCGameClosed {
    if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) { throw 'Close The Witcher 3 first.' }
}

function Write-CCJournal($Journal, [string]$Path) {
    [IO.File]::WriteAllText($Path, ($Journal | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
}

function Invoke-CCFileTransaction {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Entries,
          [Parameter(Mandatory)][string]$JournalDirectory,
          [scriptblock]$BeforeApply, [hashtable]$Metadata, [string]$JournalName='files.json')
    Assert-CCGameClosed
    $root = [IO.Path]::GetFullPath($JournalDirectory)
    if (Test-Path -LiteralPath $root) { throw 'Journal directory must be new.' }
    $seen = @{}
    foreach ($entry in $Entries) {
        $target = [IO.Path]::GetFullPath($entry.Target)
        if ($seen.ContainsKey($target)) { throw 'Duplicate transaction target.' }
        $seen[$target] = $true
        if ((Get-CCFileHash $target) -cne $entry.BeforeSha256) { throw "Target changed: $target" }
        if (Test-Path -LiteralPath $target -PathType Container) { throw 'Target is a directory.' }
    }
    [void](New-Item -ItemType Directory -Path (Join-Path $root 'backups'), (Join-Path $root 'payload'))
    $items = @()
    for ($index = 0; $index -lt $Entries.Count; $index += 1) {
        $entry = $Entries[$index]
        $target = [IO.Path]::GetFullPath($entry.Target)
        $backup = Join-Path $root ('backups\' + $index)
        $payload = Join-Path $root ('payload\' + $index)
        if ($null -ne $entry.BeforeSha256) {
            Copy-Item -LiteralPath $target -Destination $backup
            if ((Get-CCFileHash $backup) -cne $entry.BeforeSha256) { throw 'Backup verification failed.' }
        }
        $installed = $null
        if ($null -ne $entry.Bytes) {
            [IO.File]::WriteAllBytes($payload, [byte[]]$entry.Bytes)
            $installed = Get-CCFileHash $payload
        }
        $items += [pscustomobject]@{ Target=$target; Backup=$backup; Payload=$payload;
            OriginalSha256=$entry.BeforeSha256; InstalledSha256=$installed }
    }
    $journal = [ordered]@{ SchemaVersion=1; Purpose='ControllerCustomizerFiles';
        InstallationComplete=$false; RolledBack=$false; Restored=$false; Items=$items }
    if ($Metadata) {
        foreach ($key in $Metadata.Keys) {
            if ($key -cin @('SchemaVersion','InstallationComplete','RolledBack','Restored','Items')) { throw 'Reserved journal metadata.' }
            $journal[$key] = $Metadata[$key]
        }
    }
    if ($JournalName -cnotin @('files.json','install.json')) { throw 'Unsupported journal filename.' }
    $journalPath = Join-Path $root $JournalName
    Write-CCJournal $journal $journalPath
    $applied = @()
    try {
        for ($index = 0; $index -lt $items.Count; $index += 1) {
            $item = $items[$index]
            if ($BeforeApply) { & $BeforeApply $index }
            Assert-CCGameClosed
            if ((Get-CCFileHash $item.Target) -cne $item.OriginalSha256) { throw 'Target changed during staging.' }
            # Mark before mutation so a failed/partial in-place write also rolls back.
            $applied += $item
            if ($null -eq $item.InstalledSha256) { Remove-Item -LiteralPath $item.Target }
            else {
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Target))
                # Redirected OneDrive destinations retain their existing file identity.
                [IO.File]::WriteAllBytes($item.Target, [IO.File]::ReadAllBytes($item.Payload))
            }
            if ((Get-CCFileHash $item.Target) -cne $item.InstalledSha256) { throw 'Installed hash verification failed.' }
        }
        $journal.InstallationComplete = $true
        Write-CCJournal $journal $journalPath
    }
    catch {
        $failure = $_
        $rollbackErrors = @()
        [Array]::Reverse($applied)
        foreach ($item in $applied) {
            try {
                if ($null -eq $item.OriginalSha256) {
                    if (Test-Path -LiteralPath $item.Target -PathType Leaf) { Remove-Item -LiteralPath $item.Target }
                }
                else { [IO.File]::WriteAllBytes($item.Target, [IO.File]::ReadAllBytes($item.Backup)) }
                if ((Get-CCFileHash $item.Target) -cne $item.OriginalSha256) { throw 'Rollback hash mismatch.' }
            }
            catch { $rollbackErrors += $_.Exception.Message }
        }
        $journal.RolledBack = $rollbackErrors.Count -eq 0
        $journal.InstallationComplete = $false
        $journal['RollbackErrors'] = $rollbackErrors
        Write-CCJournal $journal $journalPath
        if ($rollbackErrors.Count) { throw "Rollback requires inspection: $journalPath; $($rollbackErrors -join '; ')" }
        throw $failure
    }
    return $journalPath
}

Export-ModuleMember -Function Get-CCFileHash, Assert-CCGameClosed, Write-CCJournal, Invoke-CCFileTransaction
