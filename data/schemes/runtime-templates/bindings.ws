// Native observations, not synthetic SInputAction events or action remapping.
function CCProbeReleaseOwnedActions()
{
    theInput.ForceDeactivateAction('Follow');
    theInput.ForceDeactivateAction('Canter');
    theInput.ForceDeactivateAction('Gallop');
    theInput.ForceDeactivateAction('Container');
    theInput.ForceDeactivateAction('GatherHerbs');
    theInput.ForceDeactivateAction('FastTravel');
    theInput.ForceDeactivateAction('Use');
}

exec function ccProbeAction(action : name)
{
    var keys : array<EInputKey>;
    var index : int;
    LogChannel('ControllerCustomizer', "action=" + NameToString(action) + "; value=" + FloatToString(theInput.GetActionValue(action)));
    LogChannel('ControllerCustomizer', "pressed=" + IntToString((int)theInput.IsActionPressed(action)));
    LogChannel('ControllerCustomizer', "released=" + IntToString((int)theInput.IsActionReleased(action)));
    LogChannel('ControllerCustomizer', "ignored=" + IntToString((int)theInput.IsInputIgnored(action)));
    LogChannel('ControllerCustomizer', "pattern=" + NameToString(theInput.GetActionPatternName(action)));
    theInput.GetPadKeysForAction(action, keys);
    for (index = 0; index < keys.Size(); index += 1)
    {
        LogChannel('ControllerCustomizer', "pad key enum=" + IntToString((int)keys[index]));
    }
}

// Observation buffer fed by original horse callbacks; no listener registration.
// Plain unsaved fields on the input manager avoid attaching objects to savegames.
class CCProbeRideObserver extends IScriptable
{
    private var active : bool;
    private var starts : int;
    private var stops : int;
    private var callbacks : int;
    private var canterPress : int;
    private var canterRelease : int;
    private var gallopPress : int;
    private var gallopRelease : int;
    private var patternCallbacks : int;
    private var queryMismatches : int;
    private var otherContextCallbacks : int;
    private var lastContext : name;
    private var lastAction : name;
    private var lastPattern : name;

    public function Start()
    {
        if (active) { return; }
        active = true;
        starts += 1;
    }

    public function Stop()
    {
        if (!active) { return; }
        active = false;
        stops += 1;
    }

    public function Reset()
    {
        callbacks = 0;
        canterPress = 0;
        canterRelease = 0;
        gallopPress = 0;
        gallopRelease = 0;
        patternCallbacks = 0;
        queryMismatches = 0;
        otherContextCallbacks = 0;
        lastContext = '';
        lastAction = '';
        lastPattern = '';
    }

    public function Record(actionName : name, action : SInputAction)
    {
        var raw : name;
        var canonical : name;
        var queried : SInputAction;
        if (!active || !theInput) { return; }
        raw = CCProbeReadRawContext();
        canonical = CCProbeCanonicalContext(raw);
        if (canonical != 'Horse' && canonical != 'Horse_Replacer_Ciri' && canonical != 'ScriptedAction' && canonical != 'BASE_INTERACTIONS_HORSE')
        {
            otherContextCallbacks += 1;
            return;
        }
        callbacks += 1;
        lastContext = raw;
        lastAction = action.aName;
        lastPattern = action.patternName;
        if (actionName == 'Canter')
        {
            if (IsPressed(action)) { canterPress += 1; }
            if (IsReleased(action)) { canterRelease += 1; }
        }
        else
        {
            if (IsPressed(action)) { gallopPress += 1; }
            if (IsReleased(action)) { gallopRelease += 1; }
            if (action.isActivatedWithPattern) { patternCallbacks += 1; }
        }
        queried = theInput.GetAction(actionName);
        if (action.aName != actionName || AbsF(queried.value - action.value) > 0.001f ||
            AbsF(queried.lastFrameValue - action.lastFrameValue) > 0.001f ||
            AbsF(theInput.GetActionValue(actionName) - action.value) > 0.001f ||
            theInput.IsActionPressed(actionName) != (action.value > 0.7f) ||
            theInput.IsActionReleased(actionName) != (action.value < 0.7f) ||
            theInput.IsActionActivatedWithPattern(actionName) != action.isActivatedWithPattern ||
            theInput.GetActionPatternName(actionName) != action.patternName)
        {
            queryMismatches += 1;
        }
    }

    public function BankReport() : string
    {
        var keys : array<EInputKey>;
        var correctKeys : int;
        theInput.GetPadKeysForAction('Canter', keys);
        if (keys.Size() == 1 && keys[0] == IK_Pad_X_SQUARE) { correctKeys += 1; }
        keys.Clear();
        theInput.GetPadKeysForAction('Gallop', keys);
        if (keys.Size() == 1 && keys[0] == IK_Pad_X_SQUARE) { correctKeys += 1; }
        keys.Clear();
        theInput.GetPadKeysForAction('VehicleCastSign', keys);
        if (keys.Size() == 1 && keys[0] == IK_Pad_LeftThumb) { correctKeys += 1; }
        return "CC horsebank: Canter=" + IntToString(canterPress) + "/" + IntToString(canterRelease) +
            "; Gallop=" + IntToString(gallopPress) + "/" + IntToString(gallopRelease) +
            "; mismatch=" + IntToString(queryMismatches) + "; foreign=" + IntToString(otherContextCallbacks) +
            "; keys=" + IntToString(correctKeys) +
            "; context=" + IntToString((int)(CCProbeReadRawContext() == 'CC_PRIMITIVE_Horse'));
    }

    public function Report() : string
    {
        return "CC ride: source=horse handlers; active=" + IntToString((int)active) + "; starts/stops=" + IntToString(starts) + "/" + IntToString(stops) +
            "; callbacks=" + IntToString(callbacks) + "; Canter press/release=" + IntToString(canterPress) + "/" + IntToString(canterRelease) +
            "; Gallop press/release=" + IntToString(gallopPress) + "/" + IntToString(gallopRelease) + "; pattern callbacks=" + IntToString(patternCallbacks) +
            "; query mismatches=" + IntToString(queryMismatches) + "; other-context callbacks=" + IntToString(otherContextCallbacks) +
            "; last=" + NameToString(lastContext) + "/" + NameToString(lastAction) + "/" + NameToString(lastPattern);
    }
}

@addField(CInputManager)
private var m_ccProbeRideObserver : CCProbeRideObserver;

@addMethod(CInputManager)
function CCProbeStartRideObservation()
{
    if (!m_ccProbeRideObserver) { m_ccProbeRideObserver = new CCProbeRideObserver; }
    m_ccProbeRideObserver.Reset();
    m_ccProbeRideObserver.Start();
}

@addMethod(CInputManager)
function CCProbeStopRideObservation()
{
    if (m_ccProbeRideObserver) { m_ccProbeRideObserver.Stop(); }
}

@addMethod(CInputManager)
function CCProbeResetRideObservation()
{
    if (m_ccProbeRideObserver) { m_ccProbeRideObserver.Reset(); }
}

@addMethod(CInputManager)
function CCProbeObserveHorseAction(actionName : name, action : SInputAction)
{
    if (m_ccProbeRideObserver) { m_ccProbeRideObserver.Record(actionName, action); }
}

// Remaster state annotation: state Exploration in W3HorseComponent.
// Original handlers execute once before observation, even when the probe is off.
// No new subscriptions can replace the horse's Canter/Gallop listeners.
@wrapMethod(W3HorseComponentStateExploration)
function OnSpeedPress(action : SInputAction)
{
    wrappedMethod(action);
    if (theInput) { theInput.CCProbeObserveHorseAction('Canter', action); }
}

@wrapMethod(W3HorseComponentStateExploration)
function OnSpeedHold(action : SInputAction)
{
    wrappedMethod(action);
    if (theInput) { theInput.CCProbeObserveHorseAction('Gallop', action); }
}

@addMethod(CInputManager)
function CCProbeRideReport() : string
{
    if (!m_ccProbeRideObserver) { return "CC ride observer not started"; }
    return m_ccProbeRideObserver.Report();
}

exec function ccProbeRideReset()
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    theInput.CCProbeResetRideObservation();
    theGame.GetGuiManager().ShowNotification("CC ride counters reset; horse listener registration untouched", 9000);
}

// Start observation without enabling routing: verifies automatic bootstrap.
exec function ccProbeRideStart()
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    theInput.CCProbeStartRideObservation();
    theGame.GetGuiManager().ShowNotification("CC ride observation started; routing=" + IntToString((int)theInput.CCProbeRoutingActive()) + "; raw=" + NameToString(CCProbeReadRawContext()), 9000);
}

exec function ccProbeRideStatus()
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    theGame.GetGuiManager().ShowNotification("routing=" + IntToString((int)theInput.CCProbeRoutingActive()) + "; desired=" + IntToString(CCProbeDesiredPreset()) + "; " + theInput.CCProbeRideReport(), 30000);
}

// Passive observation after the original light-attack handler, never a listener.
@addField(CInputManager)
private var m_ccFootActive : bool;
@addField(CInputManager)
private var m_ccFootPress : int;
@addField(CInputManager)
private var m_ccFootRelease : int;
@addField(CInputManager)
private var m_ccFootMismatch : int;
@addField(CInputManager)
private var m_ccFootForeign : int;
@addField(CInputManager)
private var m_ccFootLast : name;

@addMethod(CInputManager)
function CCObserveFootAttack(action : SInputAction)
{
    var canonical : name;
    var queried : SInputAction;
    if (!m_ccFootActive) { return; }
    m_ccFootLast = CCProbeReadRawContext();
    canonical = CCProbeCanonicalContext(m_ccFootLast);
    if (canonical != 'Exploration' && canonical != 'Combat')
    {
        m_ccFootForeign += 1;
        return;
    }
    if (IsPressed(action)) { m_ccFootPress += 1; }
    if (IsReleased(action)) { m_ccFootRelease += 1; }
    queried = theInput.GetAction('AttackLight');
    if (action.aName != 'AttackLight' || AbsF(queried.value - action.value) > 0.001f ||
        AbsF(queried.lastFrameValue - action.lastFrameValue) > 0.001f ||
        AbsF(theInput.GetActionValue('AttackLight') - action.value) > 0.001f)
    {
        m_ccFootMismatch += 1;
    }
}

@wrapMethod(CPlayerInput)
function OnCbtAttackLight(action : SInputAction)
{
    wrappedMethod(action);
    if (theInput) { theInput.CCObserveFootAttack(action); }
}

@addMethod(CInputManager)
function CCStartFootObservation()
{
    m_ccFootPress = 0;
    m_ccFootRelease = 0;
    m_ccFootMismatch = 0;
    m_ccFootForeign = 0;
    m_ccFootLast = '';
    m_ccFootActive = true;
}

@addMethod(CInputManager)
function CCFootReport() : string
{
    return "CC foot: press/release=" + IntToString(m_ccFootPress) + "/" + IntToString(m_ccFootRelease) +
        "; mismatch=" + IntToString(m_ccFootMismatch) + "; foreign=" + IntToString(m_ccFootForeign) +
        "; last=" + NameToString(m_ccFootLast);
}

exec function ccProbeFootStart()
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    theInput.CCStartFootObservation();
    theGame.GetGuiManager().ShowNotification("CC foot counters reset; raw=" + NameToString(CCProbeReadRawContext()), 9000);
}

exec function ccProbeFootStatus()
{
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    theGame.GetGuiManager().ShowNotification(theInput.CCFootReport(), 30000);
}

// Native key lookup is global; resolve changed digital hints against the selected
// gameplay bank. Native keyboard, axes, menus and unsupported actions stay native.
@addField(CInputManager)
private var m_ccHintContext : name;

@addMethod(CInputManager)
function CCHintContext() : name
{
    return m_ccHintContext;
}

@addMethod(CInputManager)
function CCSetHintContext(contextName : name)
{
    m_ccHintContext = contextName;
}

@wrapMethod(CInputManager)
function GetPadKeysForAction(actionName : name, out outKeys : array<EInputKey>)
{
    var contextName : name;
    var resolved : array<EInputKey>;
    var relocatedSign : array<EInputKey>;
    wrappedMethod(actionName, outKeys);
    if (!CCProbeRoutingActive()) { return; }
    // Native logical key lookup does not reflect this loaded alias. Derive the
    // relocated hints from unique physical primitives, guarded by its marker.
    if (CCProbeReadRawContext() == 'CC_PRIMITIVE_Horse')
    {
        if (actionName != 'VehicleCastSign' && actionName != 'Canter' && actionName != 'Gallop' &&
            actionName != 'Follow' && actionName != 'EnablePhotoMode_Step1') { return; }
        GetPadKeysForAction('CCP_SWAP_SIGN', relocatedSign);
        if (relocatedSign.Size() == 1 && relocatedSign[0] == IK_Pad_LeftThumb)
        {
            if (actionName == 'VehicleCastSign') { outKeys = relocatedSign; }
            else if (actionName == 'Canter' || actionName == 'Follow' || actionName == 'EnablePhotoMode_Step1')
            {
                outKeys.Clear();
                GetPadKeysForAction('CCP_X_PRESS', outKeys);
            }
            else if (actionName == 'Gallop')
            {
                outKeys.Clear();
                GetPadKeysForAction('CCP_X_D5', outKeys);
            }
        }
        return;
    }
    contextName = m_ccHintContext;
    if (contextName == '') { contextName = CCProbeCanonicalContext(CCProbeReadRawContext()); }
    if (CCGeneratedPadHintKeys(contextName, CCEffectivePreset(), actionName, resolved))
    {
        outKeys = resolved;
    }
}

// HUD keeps its canonical context even when the input manager is restoring a
// menu. Scope its native key queries to that context, retaining nested callers.
@wrapMethod(CR4HudModuleControlsFeedback)
function SendInputContextActions(inputContextName : name, optional isForced : bool)
{
    var previous : name;
    var contextName : name;
    if (theInput)
    {
    previous = theInput.CCHintContext();
    contextName = inputContextName;
    if (thePlayer && thePlayer.IsCiri())
    {
        if (contextName == 'Horse') { contextName = 'Horse_Replacer_Ciri'; }
    }
    theInput.CCSetHintContext(contextName);
    }
    wrappedMethod(inputContextName, isForced);
    if (theInput) { theInput.CCSetHintContext(previous); }
}

function CCRefreshControlHints()
{
    var hud : CR4ScriptedHud;
    var controls : CR4HudModuleControlsFeedback;
    if (!theGame || !thePlayer) { return; }
    hud = (CR4ScriptedHud)theGame.GetHud();
    if (!hud) { return; }
    controls = (CR4HudModuleControlsFeedback)hud.GetHudModule("ControlsFeedbackModule");
    if (controls) { controls.ForceModuleUpdate(); }
}

// Disabled by default: observe native primitives without remapping horse actions.
class CCPrimitiveObserver extends IScriptable
{
    private var running : bool;
    private var pDown : int;
    private var pUp : int;
    private var d3Down : int;
    private var d3Up : int;
    private var d5Down : int;
    private var d5Up : int;
    private var mismatches : int;

    public function Active() : bool { return running; }

    public function Reset()
    {
        pDown = 0; pUp = 0; d3Down = 0; d3Up = 0;
        d5Down = 0; d5Up = 0; mismatches = 0;
    }

    public function Start()
    {
        if (!running)
        {
            theInput.RegisterListener(this, 'OnPress', 'CCP_X_PRESS');
            theInput.RegisterListener(this, 'OnDuration3', 'CCP_X_D3');
            theInput.RegisterListener(this, 'OnDuration5', 'CCP_X_D5');
            running = true;
        }
        Reset();
    }

    public function Stop()
    {
        if (!running) { return; }
        theInput.UnregisterListener(this, 'CCP_X_PRESS');
        theInput.UnregisterListener(this, 'CCP_X_D3');
        theInput.UnregisterListener(this, 'CCP_X_D5');
        theInput.ForceDeactivateAction('CCP_X_PRESS');
        theInput.ForceDeactivateAction('CCP_X_D3');
        theInput.ForceDeactivateAction('CCP_X_D5');
        running = false;
    }

    private function Record(action : SInputAction, index : int)
    {
        var queried : SInputAction;
        var expected : name;
        if (!running) { return; }
        if (index == 0) { expected = 'CCP_X_PRESS'; }
        else if (index == 3) { expected = 'CCP_X_D3'; }
        else { expected = 'CCP_X_D5'; }
        queried = theInput.GetAction(expected);
        if (action.aName != expected || AbsF(action.value - queried.value) > 0.001f ||
            action.isActivatedWithPattern != queried.isActivatedWithPattern ||
            action.patternName != queried.patternName ||
            CCProbeReadRawContext() != 'CC_PRIMITIVE_Horse') { mismatches += 1; }
        if (index == 0)
        {
            if (IsPressed(action)) { pDown += 1; }
            if (IsReleased(action)) { pUp += 1; }
        }
        else if (index == 3)
        {
            if (IsPressed(action)) { d3Down += 1; }
            if (IsReleased(action)) { d3Up += 1; }
        }
        else
        {
            if (IsPressed(action)) { d5Down += 1; }
            if (IsReleased(action)) { d5Up += 1; }
        }
    }

    event OnPress(action : SInputAction) { Record(action, 0); }
    event OnDuration3(action : SInputAction) { Record(action, 3); }
    event OnDuration5(action : SInputAction) { Record(action, 5); }

    private function HasXKey(actionName : name) : bool
    {
        var keys : array<EInputKey>;
        theInput.GetPadKeysForAction(actionName, keys);
        return keys.Size() == 1 && keys[0] == IK_Pad_X_SQUARE;
    }

    public function Report() : string
    {
        var keys : int;
        keys = (int)HasXKey('CCP_X_PRESS') + (int)HasXKey('CCP_X_D3') + (int)HasXKey('CCP_X_D5');
        return "CC primitives: P=" + IntToString(pDown) + "/" + IntToString(pUp) +
            "; D3=" + IntToString(d3Down) + "/" + IntToString(d3Up) +
            "; D5=" + IntToString(d5Down) + "/" + IntToString(d5Up) +
            "; mismatch=" + IntToString(mismatches) + "; keys=" + IntToString(keys) +
            "; context=" + IntToString((int)(CCProbeReadRawContext() == 'CC_PRIMITIVE_Horse'));
    }
}

@addField(CInputManager)
private var m_ccPrimitiveObserver : CCPrimitiveObserver;

@addMethod(CInputManager)
function CCPrimitiveActive() : bool
{
    return m_ccPrimitiveObserver && m_ccPrimitiveObserver.Active();
}

@addMethod(CInputManager)
function CCPrimitiveStart() : bool
{
    var original : name;
    var available : bool;
    original = CCProbeReadRawContext();
    if (CCProbeCanonicalContext(original) != 'Horse' || CCEffectivePreset() != 2) { return false; }
    available = CCRegisteredContext('CC_PRIMITIVE_Horse');
    CCProbeSetInspectionContext(original);
    if (!available || CCProbeReadRawContext() != original) { return false; }
    if (!m_ccPrimitiveObserver) { m_ccPrimitiveObserver = new CCPrimitiveObserver; }
    m_ccPrimitiveObserver.Start();
    CCProbeApplyRestoredContext();
    return true;
}

@addMethod(CInputManager)
function CCPrimitiveStop()
{
    if (m_ccPrimitiveObserver) { m_ccPrimitiveObserver.Stop(); }
    CCProbeApplyRestoredContext();
}

@addMethod(CInputManager)
function CCPrimitiveReport() : string
{
    if (!m_ccPrimitiveObserver) { return "CC primitives not started"; }
    return m_ccPrimitiveObserver.Report();
}

exec function ccPrimitiveStart()
{
    if (!theInput || !theGame || !theGame.GetGuiManager()) { return; }
    if (!theInput.CCPrimitiveStart())
    {
        theGame.GetGuiManager().ShowNotification("CC primitive bank unavailable", 12000);
        return;
    }
    theGame.GetGuiManager().ShowNotification("CC primitive counters reset", 12000);
}

exec function ccPrimitiveStatus()
{
    if (theInput && theGame && theGame.GetGuiManager())
    { theGame.GetGuiManager().ShowNotification(theInput.CCPrimitiveReport(), 15000); }
}

exec function ccPrimitiveStop()
{
    if (!theInput || !theGame || !theGame.GetGuiManager()) { return; }
    theInput.CCPrimitiveStop();
    theGame.GetGuiManager().ShowNotification("CC primitive probe stopped", 12000);
}

@addMethod(CInputManager)
function CCHorseBankReport() : string
{
    if (!m_ccProbeRideObserver) { return "CC horsebank not started"; }
    return m_ccProbeRideObserver.BankReport();
}

exec function ccHorseBankStatus()
{
    if (theInput && theGame && theGame.GetGuiManager())
    { theGame.GetGuiManager().ShowNotification(theInput.CCHorseBankReport(), 15000); }
}
