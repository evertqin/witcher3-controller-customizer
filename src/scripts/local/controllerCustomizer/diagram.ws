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
    if (!theInput || !theInput.CCProbeRoutingActive()) { return data; }
    preset = CCEffectivePreset();
    if (preset != 0 && preset != 1) { return data; }
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
    if (!data || !theInput || !theInput.CCProbeRoutingActive()) { return data; }
    for (index = 0; index < data.GetLength(); index += 1)
    {
        row = data.GetElementFlashObject(index);
        if (!row) { continue; }
        CCGeneratedSharedDiagramRow(row);
        data.SetElementFlashObject(index, row);
    }
    return data;
}

@wrapMethod
function InGameMenu_CreateControllerData(flashStorageUtility : CScriptedFlashValueStorage) : CScriptedFlashArray
{
    var data : CScriptedFlashArray;
    data = wrappedMethod(flashStorageUtility);
    return CCProbeMarkHorseRow(CCApplySharedDiagram(data), false);
}

@wrapMethod
function InGameMenu_CreateControllerDataCiri(flashStorageUtility : CScriptedFlashValueStorage) : CScriptedFlashArray
{
    var data : CScriptedFlashArray;
    data = wrappedMethod(flashStorageUtility);
    return CCProbeMarkHorseRow(CCApplySharedDiagram(data), true);
}
