#Requires -Version 5.1
[CmdletBinding()]
param([string]$DataDirectory, [string]$OutputDirectory, [switch]$Check)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $DataDirectory) { $DataDirectory = Join-Path $projectRoot 'data' }
$stageSource = -not $OutputDirectory
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'src\generated' }
Import-Module (Join-Path $PSScriptRoot 'InputRecords.psm1') -Force
$catalog = Get-Content -LiteralPath (Join-Path $DataDirectory 'actions.json') -Raw | ConvertFrom-Json
$compatibility = Get-Content -LiteralPath (Join-Path $DataDirectory 'compatibility.json') -Raw | ConvertFrom-Json
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'compiler-toolchain.json') -Raw | ConvertFrom-Json
if ($compatibility.SchemaVersion -ne 1 -or $compatibility.InputVersion -ne 60 -or
    $compatibility.CompilerSha256 -cne $toolchain.CompilerSha256 -or
    $compatibility.CompilerSteamBuildId -cne $toolchain.SteamBuildId -or
    @($compatibility.RequiredHookSha256.PSObject.Properties).Count -ne @($toolchain.BaseScriptSha256.PSObject.Properties).Count) { throw 'Catalog/toolchain compatibility disagrees.' }
foreach ($hook in $toolchain.BaseScriptSha256.PSObject.Properties) {
    if ($compatibility.RequiredHookSha256.($hook.Name) -cne $hook.Value) { throw 'Catalog hook fingerprint disagrees with verified toolchain.' }
}
if ($catalog.SchemaVersion -ne 1 -or $catalog.AliasPrefix -cne 'CC_PROBE_' -or $catalog.HorseHandlerDoubleTapSeconds -ne 0.4) {
    throw 'Unsupported catalog schema, alias namespace or native horse timing.'
}
function Get-UniqueIndex($Items, [string]$Kind) {
    $index = @{}
    foreach ($item in $Items) {
        if ($item.Id -cnotmatch '^[a-z][a-z0-9.-]*$' -or $index.ContainsKey($item.Id)) { throw "Invalid/duplicate $Kind ID." }
        $index[$item.Id] = $item
    }
    return $index
}
function Get-Entry($Index, [string]$Id, [string]$Kind) {
    if (-not $Index.ContainsKey($Id) -or $Index[$Id].Id -cne $Id) { throw "Unknown $Kind ID: $Id" }
    return $Index[$Id]
}
$contexts = Get-UniqueIndex $catalog.Contexts 'context'
$actions = Get-UniqueIndex $catalog.Actions 'action'
$buttons = Get-UniqueIndex $catalog.Buttons 'button'
$gestures = Get-UniqueIndex $catalog.Gestures 'gesture'
$bindings = Get-UniqueIndex $catalog.Bindings 'binding'
if ($contexts.Count -ne 4 -or $bindings.Count -ne 12) { throw 'Preset scope must retain four contexts and twelve deltas.' }
foreach ($id in @('a','l3')) {
    $button = Get-Entry $buttons $id 'button'
    $key = if ($id -ceq 'a') { 'IK_Pad_A_CROSS' } else { 'IK_Pad_LeftThumb' }
    $code = if ($id -ceq 'a') { 136 } else { 146 }
    $member = if ($id -ceq 'a') { 'txtAButton' } else { 'txtLeftJoy' }
    if ($button.NativeKey -cne $key -or $button.NativeCode -ne $code -or $button.DiagramMember -cne $member) { throw 'Unsupported native button/glyph descriptor.' }
}
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'fixtures\legacy\compatibility.json') -Raw | ConvertFrom-Json
$profiles = @()
$allRecords = @{}
foreach ($name in @('Current','Alt1')) {
    $preset = Get-Content -LiteralPath (Join-Path $DataDirectory ('presets\' + $name.ToLowerInvariant() + '.json')) -Raw | ConvertFrom-Json
    $expectedValue = if ($name -ceq 'Current') { 0 } else { 1 }
    if ($preset.SchemaVersion -ne 1 -or $preset.Id -cne $name.ToLowerInvariant() -or
        $preset.DisplayName -cne $name -or $preset.ConfigValue -ne $expectedValue -or
        $preset.FixturePath -cne "fixtures/legacy/$name/input.settings" -or
        $preset.FixtureSha256 -cne $manifest.Profiles.$name.InputSha256) { throw 'Unsupported preset identity/provenance.' }
    $fixturePath = Join-Path $projectRoot $preset.FixturePath
    if ((Get-FileHash -LiteralPath $fixturePath).Hash.ToLowerInvariant() -cne $preset.FixtureSha256) { throw 'Golden fixture changed.' }
    $records = @(Read-InputRecords -Text ([IO.File]::ReadAllText($fixturePath)))
    $allRecords[$name] = $records
    $effective = @()
    $seen = @{}
    foreach ($selection in $preset.Bindings) {
        $binding = Get-Entry $bindings $selection.BindingId 'binding'
        $context = Get-Entry $contexts $binding.ContextId 'context'
        $action = Get-Entry $actions $binding.ActionId 'action'
        $gesture = Get-Entry $gestures $binding.GestureId 'gesture'
        $button = Get-Entry $buttons $selection.ButtonId 'button'
        if ($seen.ContainsKey($binding.Id)) { throw 'Duplicate preset binding.' }
        $seen[$binding.Id] = $true
        $expectedNative = '(Action=' + $action.NativeName + $gesture.NativeSuffix + ')'
        if ($binding.NativeValue -cne $expectedNative) { throw 'Gesture/action metadata disagrees with native record.' }
        if ($binding.FixtureLine -lt 1 -or $binding.FixtureLine -gt $records.Count) { throw 'Invalid fixture line.' }
        $record = $records[$binding.FixtureLine - 1]
        if ($record.Section -cne $context.NativeName -or $record.Key -cne $button.NativeKey -or
            $record.Value -cne $binding.NativeValue) { throw "Catalog differs from fixture: $($binding.Id)." }
        $effective += [pscustomobject][ordered]@{
            BindingId=$binding.Id; ContextId=$context.Id; NativeContext=$context.NativeName;
            Alias=($catalog.AliasPrefix + $name + '_' + $context.NativeName);
            ActionId=$action.Id; NativeAction=$action.NativeName; ButtonId=$button.Id;
            NativeKey=$button.NativeKey; NativeValue=$binding.NativeValue; GestureId=$gesture.Id
        }
    }
    if ($seen.Count -ne $bindings.Count) { throw 'Preset binding coverage incomplete.' }
    $profiles += [pscustomobject][ordered]@{ Id=$preset.Id; DisplayName=$name; ConfigValue=$preset.ConfigValue; FixtureSha256=$preset.FixtureSha256; Bindings=$effective }
}
$differences = @(Get-PresetDifferences -Current $allRecords.Current -Alt1 $allRecords.Alt1)
if ($differences.Count -ne 12) { throw 'Golden profiles no longer contain twelve deltas.' }
foreach ($difference in $differences) {
    $owned = @($catalog.Bindings | Where-Object FixtureLine -EQ $difference.Line)
    if ($owned.Count -ne 1) { throw 'Uncatalogued fixture delta.' }
}
$diagrams = @()
foreach ($profile in $profiles) {
    foreach ($group in $catalog.DiagramGroups) {
        $context = Get-Entry $contexts $group.ContextId 'context'
        $items = @()
        foreach ($id in $group.BindingIds) {
            $binding = Get-Entry $bindings $id 'binding'
            if ($binding.ContextId -cne $context.Id) { throw 'Diagram context differs from binding.' }
            $items += @($profile.Bindings | Where-Object BindingId -CEQ $id)[0]
        }
        if (@($items.ButtonId | Sort-Object -Unique).Count -ne 1) { throw 'Diagram group buttons disagree.' }
        if ($group.Kind -ceq 'speed') {
            if ($items.Count -ne 2 -or $items[0].NativeAction -cne 'Canter' -or $items[1].NativeAction -cne 'Gallop') { throw 'Unsupported horse speed sequence.' }
        }
        elseif ($group.Kind -ceq 'interaction') {
            if ($context.Id -cne 'geralt-horse' -or ($items.NativeAction -join '|') -cne 'Container|GatherHerbs|FastTravel|Use' -or
                $group.LabelKey -cne 'ControlLayout_Interact') { throw 'Unsupported mounted interaction group.' }
        }
        else { throw 'Unknown diagram group kind.' }
        $button = Get-Entry $buttons $items[0].ButtonId 'button'
        $diagrams += [pscustomobject][ordered]@{
            PresetId=$profile.Id; GroupId=$group.Id; ContextId=$context.Id; Kind=$group.Kind;
            GroupLabelKey=$(if ($group.Kind -ceq 'interaction') { $group.LabelKey } else { $null });
            Row=$context.DiagramRow; Member=$button.DiagramMember; Bindings=$items;
            CanterLabelKey=(Get-Entry $actions 'canter' 'action').LabelKey;
            GallopLabelKey=(Get-Entry $actions 'gallop' 'action').LabelKey
        }
    }
}
if (@($diagrams).Count -ne 6 -or @($diagrams | Where-Object { -not $_.CanterLabelKey -or -not $_.GallopLabelKey }).Count) { throw 'Diagram coverage incomplete.' }
if ((Get-Entry $actions 'canter' 'action').LabelKey -cne 'ControlLayout_Canter' -or
    (Get-Entry $actions 'gallop' 'action').LabelKey -cne 'ControlLayout_Gallop') { throw 'Untraced native label key.' }
$expectedShared = @('txtXButton>txtRightBumper','txtYButton>txtRightTrigger','txtRightBumper>txtLeftTrigger','txtRightTrigger>txtXButton','txtLeftBumper>txtYButton','txtLeftTrigger>txtLeftBumper')
if ($catalog.SharedDiagram.LegacySha256 -cne '3fbefaddeb72ec7f4efa9e6c425818139858500f0db929a122ca4de194d78409' -or @($catalog.SharedDiagram.Slots).Count -ne 6) { throw 'Untraced shared diagram provenance.' }
for ($slot = 0; $slot -lt 6; $slot += 1) {
    $entry = $catalog.SharedDiagram.Slots[$slot]
    if (($entry.Source + '>' + $entry.Target) -cne $expectedShared[$slot]) { throw 'Untraced shared diagram slot.' }
}
$provenance = [ordered]@{}
foreach ($path in @('actions.json','presets/current.json','presets/alt1.json','compatibility.json')) {
    $provenance[$path] = (Get-FileHash -LiteralPath (Join-Path $DataDirectory $path)).Hash.ToLowerInvariant()
}
$runtime = [ordered]@{ SchemaVersion=1; GeneratedBy='tools/Generate-Assets.ps1'; SourceSha256=$provenance; Profiles=$profiles }
$diagramData = [ordered]@{ SchemaVersion=1; GeneratedBy='tools/Generate-Assets.ps1'; SourceSha256=$provenance; SharedDiagram=$catalog.SharedDiagram; Rows=$diagrams }
$outputs = [ordered]@{
    'runtime-presets.json'=(($runtime | ConvertTo-Json -Depth 20) + "`n");
    'diagram-presets.json'=(($diagramData | ConvertTo-Json -Depth 20) + "`n")
}
foreach ($profile in $profiles) {
    $content = "; Generated by tools/Generate-Assets.ps1 from $($profile.DisplayName) golden fixture.`r`n"
    $content += "; SHA256: $($profile.FixtureSha256); offline reference, never a personal input overwrite payload.`r`n"
    foreach ($context in $catalog.Contexts) {
        $section = @($allRecords[$profile.DisplayName] | Where-Object Section -CEQ $context.NativeName)
        if (@($section | Where-Object Text -Match '^\[').Count -ne 1) { throw 'Missing/ambiguous native context.' }
        foreach ($record in $section) {
            $raw = $record.Raw
            if ($record.Text -cmatch '^\[') { $raw = $raw.Replace('[' + $context.NativeName + ']', '[' + $catalog.AliasPrefix + $profile.DisplayName + '_' + $context.NativeName + ']') }
            $content += $raw
        }
    }
    $outputs[$profile.Id + '.input-contexts.ini'] = $content
}
# Generated helpers remain outside compiler inputs until explicitly staged.
$ws = "// Generated by tools/Generate-Assets.ps1; exact immutable preset catalog.`n"
foreach ($path in $provenance.Keys) { $ws += "// $path SHA256 $($provenance[$path])`n" }
$ws += "function CCGeneratedCanonicalContext(contextName : name) : name`n{`n    switch (contextName)`n    {`n"
foreach ($context in $catalog.Contexts) {
    foreach ($profile in $profiles) { $ws += "        case '$($catalog.AliasPrefix)$($profile.DisplayName)_$($context.NativeName)':`n" }
    $ws += "            return '$($context.NativeName)';`n"
}
$ws += "    }`n    return contextName;`n}`n`nfunction CCGeneratedResolveContext(baseContext : name, preset : int) : name`n{`n    switch (baseContext)`n    {`n"
foreach ($context in $catalog.Contexts) {
    $ws += "        case '$($context.NativeName)':`n"
    foreach ($profile in $profiles) { $ws += "            if (preset == $($profile.ConfigValue)) { return '$($catalog.AliasPrefix)$($profile.DisplayName)_$($context.NativeName)'; }`n" }
    $ws += "            return baseContext;`n"
}
$ws += "    }`n    return baseContext;`n}`n`nfunction CCGeneratedHorseSpeedMember(preset : int, ciri : bool) : string`n{`n"
foreach ($profile in $profiles) {
    $ws += "    if (preset == $($profile.ConfigValue))`n    {`n"
    foreach ($contextId in @('ciri-horse','geralt-horse')) {
        $row = @($diagrams | Where-Object { $_.PresetId -ceq $profile.Id -and $_.ContextId -ceq $contextId -and $_.Kind -ceq 'speed' })[0]
        $condition = if ($contextId -ceq 'ciri-horse') { 'ciri' } else { '!ciri' }
        $ws += "        if ($condition) { return `"$($row.Member)`"; }`n"
    }
    $ws += "    }`n"
}
$ws += "    return `"`";`n}`n"
$ws += "`nfunction CCGeneratedHorseInteractionMember(preset : int) : string`n{`n"
foreach ($profile in $profiles) {
    $row = @($diagrams | Where-Object { $_.PresetId -ceq $profile.Id -and $_.Kind -ceq 'interaction' })[0]
    $ws += "    if (preset == $($profile.ConfigValue)) { return `"$($row.Member)`"; }`n"
}
$ws += "    return `"`";`n}`n"
$ws += "`nfunction CCGeneratedPresetName(preset : int) : string`n{`n"
foreach ($profile in $profiles) { $ws += "    if (preset == $($profile.ConfigValue)) { return `"$($profile.DisplayName)`"; }`n" }
$ws += "    return `"`";`n}`n"
$canterKey = (Get-Entry $actions 'canter' 'action').LabelKey
$gallopKey = (Get-Entry $actions 'gallop' 'action').LabelKey
$ws += @"

function CCGeneratedHorseSpeedText() : string
{
    return GetLocStringByKeyExt("ControlLayout_hold") + " - " + GetLocStringByKeyExt("$canterKey") + "<br/>" +
        GetLocStringByKeyExt("ControlLayout_doubleTap") + " + " + GetLocStringByKeyExt("ControlLayout_hold") + " - " + GetLocStringByKeyExt("$gallopKey");
}
"@ + "`n"
$ws += "`nfunction CCGeneratedSharedDiagramRow(row : CScriptedFlashObject)`n{`n    var labels : array<string>;`n"
foreach ($entry in $catalog.SharedDiagram.Slots) {
    $ws += "    labels.PushBack(row.GetMemberFlashString(`"$($entry.Source)`"));`n"
}
for ($slot = 0; $slot -lt $catalog.SharedDiagram.Slots.Count; $slot += 1) {
    $ws += "    row.SetMemberFlashString(`"$($catalog.SharedDiagram.Slots[$slot].Target)`", labels[$slot]);`n"
}
$ws += "}`n"
$outputs['presetData.ws'] = $ws
# Validate the entire model before creating output or touching existing files.
foreach ($name in $outputs.Keys) {
    $target = Join-Path $OutputDirectory $name
    if ($Check) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or [IO.File]::ReadAllText($target) -cne $outputs[$name]) { throw "Missing or stale generated asset: $name" }
    }
    else {
        if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
        [IO.File]::WriteAllText($target, $outputs[$name], [Text.UTF8Encoding]::new($false))
    }
}
if ($stageSource) {
    $target = Join-Path $projectRoot 'src\scripts\local\controllerCustomizer\presetData.ws'
    if ($Check) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or [IO.File]::ReadAllText($target) -cne $ws) { throw 'Missing or stale staged catalog source.' }
    }
    else { [IO.File]::WriteAllText($target, $ws, [Text.UTF8Encoding]::new($false)) }
}
Write-Output 'PASS: catalog IDs, immutable fixtures, twelve native deltas, timing, diagram/runtime agreement and generated assets.'
