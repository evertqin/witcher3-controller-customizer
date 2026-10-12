// Native settings persistence; apply the effective preset after menu restoration.
// Annotation structure follows the upstream MSF SaveChangedSettings example.
function CCProbeDesiredPreset() : int
{
    return CCRequestedPreset();
}

@wrapMethod(CR4IngameMenu)
function SaveChangedSettings()
{
    wrappedMethod();
    LogChannel('ControllerCustomizer', "settings saved; desired=" + IntToString(CCProbeDesiredPreset()));
}

// Run after native restoration; startup enables routing only for installed aliases.
@wrapMethod(CR4IngameMenu)
function OnClosingMenu()
{
    if (theInput) { theInput.CCSetMenuClosing(true); }
    wrappedMethod();
    if (theInput) { theInput.CCSetMenuClosing(false); }
    CCProbeApplyRestoredContext();
    LogChannel('ControllerCustomizer', "menu closed; restored context=" + NameToString(theInput.GetContext()));
}

// Native group construction/localized hierarchy stays intact; only our title is literal.
@wrapMethod
function IngameMenu_FetchAndGenerateGroupMenuObject(flashStorageUtility : CScriptedFlashValueStorage, displayNamePrefix : string, groupDisplayName : string, rootFlashArray : CScriptedFlashArray, out optionParentArray : CScriptedFlashArray) : CScriptedFlashObject
{
    var group : CScriptedFlashObject;
    group = wrappedMethod(flashStorageUtility, displayNamePrefix, groupDisplayName, rootFlashArray, optionParentArray);
    if (group && groupDisplayName == "controller_customizer")
    {
        group.SetMemberFlashString("label", "Controller Customizer");
        group.SetMemberFlashString("listTitle", "Controller Customizer");
    }
    return group;
}
