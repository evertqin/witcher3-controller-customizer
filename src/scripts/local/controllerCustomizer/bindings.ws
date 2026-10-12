// Native observations, not synthetic SInputAction events or action remapping.
function CCProbeReleaseOwnedActions()
{
    if (theInput) { CCGeneratedReleaseContextActions(CCProbeReadRawContext()); }
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
