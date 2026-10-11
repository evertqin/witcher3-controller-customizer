#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$TargetProcessId,
    [ValidateSet('Inspect','Invoke','Resolve','SetValue')][string]$Action = 'Inspect',
    [string]$Name,
    [string]$AutomationId,
    [string]$Value
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$condition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty, $TargetProcessId)
$root = [Windows.Automation.AutomationElement]::RootElement
$windows = $root.FindAll([Windows.Automation.TreeScope]::Children, $condition)
if ($windows.Count -eq 0) { throw 'Target desktop window unavailable; do not infer application is closed.' }
$matches = @()
$records = @()
foreach ($window in $windows) {
    foreach ($element in $window.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
        $current = $element.Current
        if ($Action -eq 'Inspect') {
            if ($current.Name -or $current.AutomationId) {
                $records += [pscustomobject]@{ Name=$current.Name; AutomationId=$current.AutomationId; Type=$current.ControlType.ProgrammaticName; Enabled=$current.IsEnabled; Offscreen=$current.IsOffscreen; Handle=$current.NativeWindowHandle; X=$current.BoundingRectangle.X; Y=$current.BoundingRectangle.Y; Width=$current.BoundingRectangle.Width; Height=$current.BoundingRectangle.Height }
            }
        } elseif ((-not $Name -or $current.Name -ceq $Name) -and (-not $AutomationId -or $current.AutomationId -ceq $AutomationId) -and $current.IsEnabled -and -not $current.IsOffscreen) {
            $matches += $element
        }
    }
}
if ($Action -eq 'Inspect') { ConvertTo-Json -InputObject @($records) -Depth 3 }
if ($Action -in @('Invoke','Resolve','SetValue')) {
    if (-not $Name -and -not $AutomationId) { throw 'Supply an exact UI control Name or AutomationId.' }
    if ($matches.Count -ne 1) { throw "Expected one enabled control; found $($matches.Count)." }
    $pattern = $null
    if ($Action -eq 'Resolve') {
        $current = $matches[0].Current
        [pscustomobject]@{ Name=$current.Name; Handle=$current.NativeWindowHandle; X=$current.BoundingRectangle.X; Y=$current.BoundingRectangle.Y; Width=$current.BoundingRectangle.Width; Height=$current.BoundingRectangle.Height } | ConvertTo-Json -Compress
    }
    elseif ($Action -eq 'SetValue') {
        if (-not $matches[0].TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) { throw 'Control has no Value pattern.' }
        $pattern.SetValue($Value)
    }
    elseif ($matches[0].TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { $pattern.Invoke() }
    elseif ($matches[0].TryGetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$pattern)) { $pattern.Expand() }
    else { throw 'Control exposes neither Invoke nor Expand; capture screenshot before calibrated input.' }
}
