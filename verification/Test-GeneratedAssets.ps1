#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$generator = Join-Path $projectRoot 'tools\Generate-Assets.ps1'
Import-Module (Join-Path $projectRoot 'tools\InputRecords.psm1') -Force
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('cc-generated-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
try {
    $output = Join-Path $scratch 'output'
    & $generator -OutputDirectory $output | Out-Null
    $hashes = @{}
    foreach ($file in Get-ChildItem -LiteralPath $output -File) { $hashes[$file.Name] = (Get-FileHash -LiteralPath $file.FullName).Hash }
    & $generator -OutputDirectory $output | Out-Null
    & $generator -OutputDirectory $output -Check | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $output -File) {
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -cne $hashes[$file.Name]) { throw 'Generation not deterministic.' }
    }
    $runtime = Get-Content -LiteralPath (Join-Path $output 'runtime-presets.json') -Raw | ConvertFrom-Json
    $diagrams = Get-Content -LiteralPath (Join-Path $output 'diagram-presets.json') -Raw | ConvertFrom-Json
    foreach ($profile in $runtime.Profiles) {
        $golden = @(Read-InputRecords -Text ([IO.File]::ReadAllText((Join-Path $projectRoot ('fixtures\legacy\' + $profile.DisplayName + '\input.settings')))))
        $appendix = @(Read-InputRecords -Text ([IO.File]::ReadAllText((Join-Path $output ($profile.Id + '.input-contexts.ini')))))
        foreach ($context in @('BASE_INTERACTIONS_HORSE','Horse','Horse_Replacer_Ciri','ScriptedAction')) {
            $alias = 'CC_PROBE_' + $profile.DisplayName + '_' + $context
            $expected = @($golden | Where-Object Section -CEQ $context | ForEach-Object Raw) -join ''
            $actual = @($appendix | Where-Object Section -CEQ $alias | ForEach-Object { $_.Raw.Replace('[' + $alias + ']', '[' + $context + ']') }) -join ''
            if ($expected -cne $actual) { throw 'Generated section changes keyboard/axis/unowned/duplicate records.' }
        }
        foreach ($binding in $profile.Bindings) {
            $matches = @($golden | Where-Object { $_.Section -ceq $binding.NativeContext -and $_.Key -ceq $binding.NativeKey -and $_.Value -ceq $binding.NativeValue })
            if ($matches.Count -ne 1) { throw 'Runtime binding differs from pinned golden input.' }
        }
        foreach ($row in @($diagrams.Rows | Where-Object PresetId -CEQ $profile.Id)) {
            if ($row.Row -ne 3) { throw 'Wrong native horse diagram row.' }
            foreach ($binding in $row.Bindings) {
                $runtimeBinding = @($profile.Bindings | Where-Object BindingId -CEQ $binding.BindingId)
                if ($runtimeBinding.Count -ne 1 -or ($binding | ConvertTo-Json -Compress) -cne ($runtimeBinding[0] | ConvertTo-Json -Compress)) { throw 'Diagram/runtime bindings disagree.' }
                $member = if ($binding.NativeKey -ceq 'IK_Pad_A_CROSS') { 'txtAButton' } else { 'txtLeftJoy' }
                if ($row.Member -cne $member) { throw 'Wrong physical diagram slot.' }
            }
            if ($row.ContextId -ceq 'ciri-horse' -and $row.Kind -ceq 'interaction') { throw 'Geralt-only interaction leaked into Ciri.' }
        }
    }
    function Assert-Rejected([scriptblock]$Mutation) {
        $data = Join-Path $scratch ('data-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath (Join-Path $projectRoot 'data') -Destination $data -Recurse
        & $Mutation $data
        $rejected = $false
        try { & $generator -DataDirectory $data -OutputDirectory $output | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw 'Invalid model accepted.' }
        foreach ($file in Get-ChildItem -LiteralPath $output -File) {
            if ((Get-FileHash -LiteralPath $file.FullName).Hash -cne $hashes[$file.Name]) { throw 'Validation failure mutated outputs.' }
        }
    }
    foreach ($property in @('ActionId','ContextId','GestureId')) {
        Assert-Rejected {
            param($data)
            $path = Join-Path $data 'actions.json'
            $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $value.Bindings[0].$property = 'unknown'
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 20))
        }
    }
    Assert-Rejected {
        param($data)
        $path = Join-Path $data 'presets\current.json'
        $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $value.Bindings[0].ButtonId = 'unknown'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 20))
    }
    Assert-Rejected {
        param($data)
        $path = Join-Path $data 'actions.json'
        $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $value.Gestures[1].NativeSuffix = ',State=Duration,IdleTime=0.9'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 20))
    }
    Assert-Rejected {
        param($data)
        $path = Join-Path $data 'presets\current.json'
        $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $value.Bindings[0].ButtonId = 'l3'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 20))
    }
    Assert-Rejected {
        param($data)
        $path = Join-Path $data 'actions.json'
        $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $value.SharedDiagram.Slots[0].Target = 'txtXButton'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 20))
    }
    [IO.File]::AppendAllText((Join-Path $output 'presetData.ws'), '// stale')
    $staleRefused = $false
    try { & $generator -OutputDirectory $output -Check | Out-Null } catch { $staleRefused = $true }
    if (-not $staleRefused) { throw 'Stale generated source accepted.' }
    Write-Output 'PASS: determinism, exact golden sections/gestures, runtime/diagram agreement, invalid model refusal without mutation and stale-output detection.'
}
finally {
    # Only remove this explicitly created temporary directory.
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { throw 'Scratch path escaped temporary directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
