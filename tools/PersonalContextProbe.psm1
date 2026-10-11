#Requires -Version 5.1
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'InputRecords.psm1')

function New-PersonalContextAppendix {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][object[]]$Differences)
    $records = @(Read-InputRecords -Text $Text)
    if (@($records | Where-Object Section -Like 'CC_PROBE_*').Count) { throw 'Probe contexts already exist.' }
    $contexts = @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')
    if ($Differences.Count -ne 12 -or (@($Differences.Context | Sort-Object -Unique) -join '|') -cne (@($contexts | Sort-Object) -join '|')) {
        throw 'Expected the verified four-context/12-record delta.'
    }
    $output = "`r`n; Controller Customizer Phase 0: personal-context probe BEGIN`r`n"
    foreach ($profile in @('Current','Alt1')) {
        foreach ($context in $contexts) {
            $section = @($records | Where-Object Section -CEQ $context)
            if (@($section | Where-Object Text -Match '^\s*\[').Count -ne 1) { throw "Missing or duplicate context $context." }
            $owned = @($Differences | Where-Object Context -CEQ $context)
            # Reject ambiguous or independently customized owned records before producing output.
            foreach ($delta in $owned) {
                $matches = @($section | Where-Object { $_.Key -cmatch '^IK_Pad_' -and $_.Value -ceq $delta.NativeValue })
                if ($matches.Count -ne 1 -or $matches[0].Key -cnotin @($delta.CurrentKey,$delta.Alt1Key)) {
                    throw "Unsupported owned binding: $context/$($delta.Action)."
                }
            }
            foreach ($record in $section) {
                $raw = $record.Raw
                if ($record.Text -match '^\s*\[') {
                    $raw = $raw.Replace("[$context]", "[CC_PROBE_${profile}_$context]")
                }
                elseif ($record.Key -cmatch '^IK_Pad_') {
                    $delta = @($owned | Where-Object NativeValue -CEQ $record.Value)
                    if ($delta.Count -eq 1) {
                        $key = if ($profile -ceq 'Current') { $delta[0].CurrentKey } else { $delta[0].Alt1Key }
                        $offset = $raw.IndexOf($record.Key, [StringComparison]::Ordinal)
                        $raw = $raw.Substring(0,$offset) + $key + $raw.Substring($offset + $record.Key.Length)
                    }
                }
                $output += $raw
            }
            if (-not $output.EndsWith("`n") -and -not $output.EndsWith("`r")) { $output += "`r`n" }
        }
    }
    $output += "; Controller Customizer Phase 0: personal-context probe END`r`n"
    return $output
}

function Remove-PersonalContextSections {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Appendix,
        [Parameter(Mandatory)][string[]]$Contexts
    )
    $records = @(Read-InputRecords -Text $Text)
    $expected = @(Read-InputRecords -Text $Appendix)
    if ($Contexts.Count -ne 8 -or @($Contexts | Sort-Object -Unique).Count -ne 8 -or
        @($Contexts | Where-Object { $_ -cnotmatch '^CC_PROBE_(Current|Alt1)_(BASE_INTERACTIONS_HORSE|Horse|Horse_Replacer_Ciri|ScriptedAction)$' }).Count) {
        throw 'Invalid owned context inventory.'
    }
    foreach ($context in $Contexts) {
        $before = @($expected | Where-Object Section -CEQ $context)
        $current = @($records | Where-Object Section -CEQ $context)
        foreach ($section in @(@{ Rows=$before }, @{ Rows=$current })) {
            if (@($section.Rows | Where-Object Text -Match '^\s*\[').Count -ne 1) { throw "Missing or duplicate owned context: $context." }
            foreach ($record in $section.Rows) {
                if ($record.Text.Trim() -and $record.Text -notmatch '^\s*[;#\[]' -and $null -eq $record.Key) {
                    throw "Unrecognized owned record: $context."
                }
            }
        }
        # The engine reorders records. Compare ordinal multisets, preserving duplicate counts.
        [string[]]$beforeBindings = @($before | Where-Object { $null -ne $_.Key } | ForEach-Object { $_.Key + '=' + $_.Value.Trim() })
        [string[]]$currentBindings = @($current | Where-Object { $null -ne $_.Key } | ForEach-Object { $_.Key + '=' + $_.Value.Trim() })
        [Array]::Sort($beforeBindings,[StringComparer]::Ordinal)
        [Array]::Sort($currentBindings,[StringComparer]::Ordinal)
        if ($beforeBindings.Count -ne $currentBindings.Count) { throw "Changed owned records: $context." }
        for ($index=0; $index -lt $beforeBindings.Count; $index++) {
            if ($beforeBindings[$index] -cne $currentBindings[$index]) { throw "Changed owned records: $context." }
        }
    }
    $output = [Text.StringBuilder]::new()
    foreach ($record in $records) {
        if ($record.Text -cin @('; Controller Customizer Phase 0: personal-context probe BEGIN','; Controller Customizer Phase 0: personal-context probe END')) { continue }
        if ($record.Section -cin $Contexts -and ($record.Text -match '^\s*\[' -or $null -ne $record.Key)) { continue }
        # Preserve all unrelated raw bytes and all comments, including later user notes.
        [void]$output.Append($record.Raw)
    }
    return $output.ToString()
}

Export-ModuleMember -Function New-PersonalContextAppendix, Remove-PersonalContextSections
