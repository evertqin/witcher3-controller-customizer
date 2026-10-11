#Requires -Version 5.1
Set-StrictMode -Version Latest

function Read-InputRecords {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $section = ''
    $lineNumber = 0
    foreach ($match in [regex]::Matches($Text, '[^\r\n]*(?:\r\n|\n|\r|$)')) {
        if ($match.Length -eq 0) { continue }
        $lineNumber++
        $raw = $match.Value
        $line = $raw.TrimEnd([char[]]"`r`n")
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $section = $Matches[1] }
        $key = $null
        $value = $null
        $action = $null
        if ($line -match '^\s*([^;#=\s][^=]*)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2]
            if ($value -match '^\(Action=([^,)]+)(?:,|\))') { $action = $Matches[1] }
        }
        [pscustomobject]@{
            Section = $section
            LineNumber = $lineNumber
            Raw = $raw
            Text = $line
            Key = $key
            Value = $value
            Action = $action
        }
    }
}

function Get-PresetDifferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Current,
        [Parameter(Mandatory)][object[]]$Alt1
    )
    if ($Current.Count -ne $Alt1.Count) { throw 'Preset record counts differ.' }
    for ($index = 0; $index -lt $Current.Count; $index++) {
        $before = $Current[$index]
        $after = $Alt1[$index]
        if ($before.Raw -ceq $after.Raw) { continue }
        if ($before.Section -cne $after.Section -or
            $before.Value -cne $after.Value -or
            $null -eq $before.Action -or $null -eq $after.Action -or
            $before.Key -cnotmatch '^IK_Pad_' -or $after.Key -cnotmatch '^IK_Pad_') {
            throw "Unexpected non-button change at line $($before.LineNumber)."
        }
        # A line-ending or whitespace change is not an owned button delta.
        $expected = $before.Raw.Substring(0, $before.Raw.IndexOf($before.Key)) +
            $after.Key + $before.Raw.Substring($before.Raw.IndexOf($before.Key) + $before.Key.Length)
        if ($expected -cne $after.Raw) { throw "Unexpected formatting change at line $($before.LineNumber)." }
        [pscustomobject]@{
            Context = $before.Section
            Action = $before.Action
            Line = $before.LineNumber
            CurrentKey = $before.Key
            Alt1Key = $after.Key
            NativeValue = $before.Value
        }
    }
}

Export-ModuleMember -Function Read-InputRecords, Get-PresetDifferences
