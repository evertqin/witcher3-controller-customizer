// Effective horseback labels from the preset catalog; native variants stay intact.
// Shared Souls label permutation follows the hash-pinned legacy diagram.
// Global creator wrappers transform the native returned rows once.
// Row 3 is structural in the two inspected creators, not a translated-text lookup.
exec function ccProbeDiagram(enabled : bool)
{
    var config : CInGameConfigWrapper;
    var value : string;
    if (!theGame || !theGame.GetGuiManager()) { return; }
    config = theGame.GetInGameConfigWrapper();
    if (!config) { return; }
    value = "false";
    if (enabled) { value = "true"; }
    config.SetVarValue('ControllerCustomizer', 'DiagramProbe', value);
    theGame.GetGuiManager().ShowNotification("CC diagram probe=" + value + "; reopen Controls", 9000);
}

function CCProbeMarkHorseRow(data : CScriptedFlashArray, ciri : bool) : CScriptedFlashArray
{
    var row : CScriptedFlashObject;
    var config : CInGameConfigWrapper;
    var preset : int;
    var speedMember : string;
    var interactionMember : string;
    var speedText : string;
    var title : string;
    if (!data || !theGame) { return data; }
    config = theGame.GetInGameConfigWrapper();
    if (!config) { return data; }
    if (data.GetLength() < 5) { return data; }
    row = data.GetElementFlashObject(3);
    if (!row) { return data; }
    if (config.GetVarValue('ControllerCustomizer', 'DiagramProbe') == "true")
    {
        row.SetMemberFlashString("txtAButton", "CC diagram probe");
        data.SetElementFlashObject(3, row);
        return data;
    }
    preset = CCDisplayPreset();
    if (preset != 1 && preset != 2) { return data; }
    speedMember = CCGeneratedHorseSpeedMember(preset, ciri);
    if (speedMember == "") { return data; }
    speedText = CCGeneratedHorseSpeedText();
    row.SetMemberFlashString("txtAButton", "");
    row.SetMemberFlashString("txtLeftJoy", GetLocStringByKeyExt("ControlLayout_Movement"));
    if (speedMember == "txtLeftJoy")
    {
        speedText = GetLocStringByKeyExt("ControlLayout_Movement") + "<br/>" + speedText;
    }
    row.SetMemberFlashString(speedMember, speedText);
    if (!ciri)
    {
        interactionMember = CCGeneratedHorseInteractionMember(preset);
        if (interactionMember == "txtLeftJoy")
        {
            row.SetMemberFlashString(interactionMember, GetLocStringByKeyExt("ControlLayout_Movement") + "<br/>" + GetLocStringByKeyExt("ControlLayout_Interact"));
        }
        else { row.SetMemberFlashString(interactionMember, GetLocStringByKeyExt("ControlLayout_Interact")); }
    }
    title = CCGeneratedPresetName(preset);
    row.SetMemberFlashString("layoutName", row.GetMemberFlashString("layoutName") + " (" + title + ")");
    data.SetElementFlashObject(3, row);
    return data;
}

// Snapshot before writing: the six owned fields form a cycle, not independent swaps.
function CCApplySharedDiagram(data : CScriptedFlashArray) : CScriptedFlashArray
{
    var index : int;
    var row : CScriptedFlashObject;
    if (!data || !theGame) { return data; }
    if (CCDisplayPreset() == 0) { return data; }
    for (index = 0; index < data.GetLength(); index += 1)
    {
        row = data.GetElementFlashObject(index);
        if (!row) { continue; }
        CCGeneratedSharedDiagramRow(row);
        data.SetElementFlashObject(index, row);
    }
    return data;
}


// Legacy Combat adds held sprint to Geralt A/B and Ciri B, beyond the six-slot cycle.
// Native quick-sign labels remain ordered after the new sprint line.
function CCApplyCombatDiagram(data : CScriptedFlashArray, ciri : bool) : CScriptedFlashArray
{
    var row : CScriptedFlashObject;
    var config : CInGameConfigWrapper;
    var quickSigns : bool;
    var sprint : string;
    var roll : string;
    var dodge : string;
    if (!data || !theGame) { return data; }
    if (CCDisplayPreset() == 0 || data.GetLength() < 3) { return data; }
    // Only PC/GDK is supported; retain other native platform branch output.
    if (theGame.GetPlatform() != Platform_PC && theGame.GetPlatform() != Platform_PC_GDK) { return data; }
    row = data.GetElementFlashObject(2);
    if (!row) { return data; }
    config = theGame.GetInGameConfigWrapper();
    if (!config) { return data; }
    quickSigns = (bool)config.GetVarValue('Gameplay', 'EnableAlternateSignCasting');
    sprint = "&#10;" + GetLocStringByKeyExt("ControlLayout_hold") + " - " + GetLocStringByKeyExt("ControlLayout_RunSprint");
    dodge = GetLocStringByKeyExt("ControlLayout_Dodge") + sprint;
    if (!ciri)
    {
        roll = GetLocStringByKeyExt("ControlLayout_Roll") + sprint;
        if (quickSigns)
        {
            roll += "&#10;" + GetLocStringByKeyExt("ControlLayout_press") + " " + GetLocStringByKeyExt("Aard");
            dodge += "&#10;" + GetLocStringByKeyExt("ControlLayout_press") + " " + GetLocStringByKeyExt("Quen");
        }
        row.SetMemberFlashString("txtAButton", roll);
    }
    row.SetMemberFlashString("txtBButton", dodge);
    data.SetElementFlashObject(2, row);
    return data;
}

@wrapMethod
function InGameMenu_CreateControllerData(flashStorageUtility : CScriptedFlashValueStorage) : CScriptedFlashArray
{
    var data : CScriptedFlashArray;
    data = wrappedMethod(flashStorageUtility);
    return CCProbeMarkHorseRow(CCApplyCombatDiagram(CCApplySharedDiagram(data), false), false);
}

@wrapMethod
function InGameMenu_CreateControllerDataCiri(flashStorageUtility : CScriptedFlashValueStorage) : CScriptedFlashArray
{
    var data : CScriptedFlashArray;
    data = wrappedMethod(flashStorageUtility);
    return CCProbeMarkHorseRow(CCApplyCombatDiagram(CCApplySharedDiagram(data), true), true);
}
