// Initialize after native game/save startup; no timers, file polling or listeners.
function CCRegisteredContext(target : name) : bool
{
    theInput.CCProbeSetInspectionContext(target);
    return CCProbeReadRawContext() == target;
}

function CCInitializePresets()
{
    var original : name;
    var available : bool;
    if (!theGame || !theInput) { return; }
    original = CCProbeReadRawContext();
    theInput.CCProbeSetRoutingActive(false);
    available = CCRegisteredContext('CC_PROBE_Current_BASE_INTERACTIONS_HORSE');
    available = CCRegisteredContext('CC_PROBE_Current_Horse') && available;
    available = CCRegisteredContext('CC_PROBE_Current_Horse_Replacer_Ciri') && available;
    available = CCRegisteredContext('CC_PROBE_Current_ScriptedAction') && available;
    available = CCRegisteredContext('CC_PROBE_Alt1_BASE_INTERACTIONS_HORSE') && available;
    available = CCRegisteredContext('CC_PROBE_Alt1_Horse') && available;
    available = CCRegisteredContext('CC_PROBE_Alt1_Horse_Replacer_Ciri') && available;
    available = CCRegisteredContext('CC_PROBE_Alt1_ScriptedAction') && available;
    theInput.CCProbeSetInspectionContext(original);
    if (CCProbeReadRawContext() != original || !available)
    {
        if (theGame.GetGuiManager())
        {
            theGame.GetGuiManager().ShowNotification("Controller Customizer: input contexts unavailable; reinstall mod", 15000);
        }
        return;
    }
    theInput.CCRefreshPreset();
    theInput.CCProbeSetRoutingActive(true);
    CCProbeApplyRestoredContext();
}

@wrapMethod(CR4Game)
function OnGameStarted(restored : bool)
{
    wrappedMethod(restored);
    CCInitializePresets();
}
