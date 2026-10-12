// Phase 0 observations. Context names alone do not prove loaded bindings.
// Visible, read-only confirmation avoids depending on log-channel configuration.
exec function ccProbeLoaded()
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    theGame.GetGuiManager().ShowNotification("CC probe loaded; context=" + NameToString(theInput.GetContext()), 9000);
}

exec function ccProbeContext()
{
    LogChannel('ControllerCustomizer', "native context=" + NameToString(theInput.CCProbeRawContext()));
    LogChannel('ControllerCustomizer', "logical context=" + NameToString(theInput.GetContext()));
    LogChannel('ControllerCustomizer', "desired preset=" + IntToString(CCProbeDesiredPreset()));
}

// Refresh through an explicit object call before reading the wrapper's cache.
// Unqualified calls inside imported classes are not assumed to dispatch wrappers.
function CCProbeReadRawContext() : name
{
    theInput.GetContext();
    return theInput.CCProbeRawContext();
}

function CCProbeInspectionAllowed() : bool
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return false; }
    if (theInput.CCProbeRoutingActive())
    {
        theGame.GetGuiManager().ShowNotification("CC: disable Context probe before testing registration", 9000);
        return false;
    }
    return true;
}

// Each row separates the old cache observation, refreshed raw selection and keys.
function CCProbeContextDetailRow(label : string, target : name) : string
{
    var cached : name;
    var raw : name;
    var keys : array<EInputKey>;
    var index : int;
    var row : string;
    theInput.CCProbeSetInspectionContext(target);
    cached = theInput.CCProbeRawContext();
    raw = CCProbeReadRawContext();
    theInput.GetPadKeysForAction('Canter', keys);
    row = label + ": selected=" + IntToString((int)(raw == target)) + "; cache=" + IntToString((int)(cached == raw)) + "; keys=" + IntToString(keys.Size()) + ":";
    for (index = 0; index < keys.Size(); index += 1)
    {
        row += " " + IntToString((int)keys[index]);
    }
    if (raw != target) { row += "; raw=" + NameToString(raw); }
    LogChannel('ControllerCustomizer', row);
    return row;
}

exec function ccProbeContextDetails()
{
    var original : name;
    var report : string;
    if (!CCProbeInspectionAllowed()) { return; }
    original = CCProbeReadRawContext();
    report = CCProbeContextDetailRow("Horse", 'Horse');
    report += " | " + CCProbeContextDetailRow("Current", 'CC_PROBE_Current_Horse');
    report += " | " + CCProbeContextDetailRow("Alt1", 'CC_PROBE_Alt1_Horse');
    report += " | " + CCProbeContextDetailRow("Missing", 'CC_PROBE_Unregistered_NegativeControl');
    theInput.CCProbeSetInspectionContext(original);
    if (CCProbeReadRawContext() != original)
    {
        theGame.GetGuiManager().ShowNotification("CC context details: restoration failed; quit without saving", 20000);
        return;
    }
    report += " | expected A=" + IntToString((int)IK_Pad_A_CROSS) + "; L3=" + IntToString((int)IK_Pad_LeftThumb) + "; restored";
    theGame.GetGuiManager().ShowNotification(report, 30000);
}

// Explicit scalar calls avoid assuming the array-building loop actually ran.
// Key lookup returned A and L3 together for native Horse and both horse aliases;
// a selected name and global key membership do not establish event dispatch.
function CCProbeInspectOneContext(target : name, action : name, expected : EInputKey, out checked : int, out selected : int, out matchedKeys : int, out failures : string) : int
{
    var keys : array<EInputKey>;
    var raw : name;
    checked += 1;
    theInput.CCProbeSetInspectionContext(target);
    raw = CCProbeReadRawContext();
    theInput.GetPadKeysForAction(action, keys);
    if (raw == target) { selected += 1; }
    else { failures += " | requested=" + NameToString(target) + "; raw=" + NameToString(raw); }
    if (keys.Size() == 1 && keys[0] == expected) { matchedKeys += 1; }
    LogChannel('ControllerCustomizer', "context lookup=" + NameToString(target) + "; raw=" + NameToString(raw) + "; pad keys=" + IntToString(keys.Size()));
    if (raw == target && keys.Size() == 1 && keys[0] == expected) { return 1; }
    return 0;
}

// Restore the original raw context before returning, including after the missing
// context control. The negative control must not appear in any installed INI.
function CCProbeInspectContexts() : int
{
    var original : name;
    var missingSelected : bool;
    var checked : int;
    var selected : int;
    var matchedKeys : int;
    var passed : int;
    var failures : string;
    if (!CCProbeInspectionAllowed()) { return -1; }
    original = CCProbeReadRawContext();
    checked = 0;
    selected = 0;
    matchedKeys = 0;
    passed = 0;
    failures = "";
    passed += CCProbeInspectOneContext('CC_PROBE_Current_BASE_INTERACTIONS_HORSE', 'Follow', IK_Pad_A_CROSS, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Current_Horse', 'Canter', IK_Pad_A_CROSS, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Current_Horse_Replacer_Ciri', 'Canter', IK_Pad_A_CROSS, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Current_ScriptedAction', 'Gallop', IK_Pad_A_CROSS, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Alt1_BASE_INTERACTIONS_HORSE', 'Follow', IK_Pad_LeftThumb, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Alt1_Horse', 'Canter', IK_Pad_LeftThumb, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Alt1_Horse_Replacer_Ciri', 'Canter', IK_Pad_LeftThumb, checked, selected, matchedKeys, failures);
    passed += CCProbeInspectOneContext('CC_PROBE_Alt1_ScriptedAction', 'Gallop', IK_Pad_LeftThumb, checked, selected, matchedKeys, failures);
    theInput.CCProbeSetInspectionContext('CC_PROBE_Unregistered_NegativeControl');
    missingSelected = CCProbeReadRawContext() == 'CC_PROBE_Unregistered_NegativeControl';
    theInput.CCProbeSetInspectionContext(original);
    if (CCProbeReadRawContext() != original)
    {
        theGame.GetGuiManager().ShowNotification("CC context test: restoration failed; quit without saving", 15000);
        return -1;
    }
    theGame.GetGuiManager().ShowNotification("CC contexts: checked=" + IntToString(checked) + "/8; selected=" + IntToString(selected) + "/8; single-key=" + IntToString(matchedKeys) + "/8; both=" + IntToString(passed) + "/8; missing-selected=" + IntToString((int)missingSelected) + "; restored" + failures, 30000);
    // Gate only recognized names versus the missing control. Global key lookup
    // is not scoped to the selected context; callbacks remain a separate test.
    if (checked != 8 || missingSelected) { return -1; }
    return selected;
}

exec function ccProbeContexts()
{
    var count : int;
    count = CCProbeInspectContexts();
    if (count < 0) { return; }
    // The helper reports independent selection/key counts and restoration.
}

// Controlled riding experiment: recognize every alias, then attach a read-only
// observer. Normal console/menu restoration applies routing after this command.
// Full restart clears the unsaved input-manager flag and listener instance.
exec function ccProbeContextMode(enabled : bool)
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    if (!enabled)
    {
        theInput.CCProbeSetRoutingActive(false);
        CCProbeReleaseOwnedActions();
        CCProbeApplyRestoredContext();
        theInput.CCProbeStopRideObservation();
        theGame.GetGuiManager().ShowNotification("CC context probe disabled", 9000);
        return;
    }
    if (theInput.CCProbeRoutingActive())
    {
        theInput.CCProbeStartRideObservation();
        theGame.GetGuiManager().ShowNotification("CC context probe already enabled", 9000);
        return;
    }
    if (CCProbeDesiredPreset() < 0 || CCProbeInspectContexts() != 8)
    {
        theGame.GetGuiManager().ShowNotification("CC: desired preset/name check failed; routing remains disabled", 15000);
        return;
    }
    theInput.CCProbeStartRideObservation();
    theInput.CCProbeSetRoutingActive(true);
    theGame.GetGuiManager().ShowNotification("CC riding experiment enabled for this session; release A/L3, then close console", 15000);
}

