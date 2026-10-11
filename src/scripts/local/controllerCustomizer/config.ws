// Native settings persist the desired value; runtime fallback stays out of saves.
function CCRequestedPreset() : int
{
    var config : CInGameConfigWrapper;
    var value : string;
    if (!theGame) { return -1; }
    config = theGame.GetInGameConfigWrapper();
    if (!config) { return -1; }
    value = config.GetVarValue('ControllerCustomizer', 'Preset');
    if (value == "") { return 0; }
    if (value == "0") { return 0; }
    if (value == "1") { return 1; }
    return -1;
}

@addField(CInputManager)
private var m_ccLastValidPreset : int;

@addField(CInputManager)
private var m_ccInvalidPresetReported : bool;

@addMethod(CInputManager)
function CCRefreshPreset() : int
{
    return CCAcceptPreset(CCRequestedPreset());
}

@addMethod(CInputManager)
function CCAcceptPreset(requested : int) : int
{
    if (requested == 0 || requested == 1)
    {
        m_ccLastValidPreset = requested;
        m_ccInvalidPresetReported = false;
    }
    else if (!m_ccInvalidPresetReported && theGame && theGame.GetGuiManager())
    {
        theGame.GetGuiManager().ShowNotification("Controller Customizer: invalid preset; keeping " + CCGeneratedPresetName(m_ccLastValidPreset), 9000);
        m_ccInvalidPresetReported = true;
    }
    return m_ccLastValidPreset;
}

function CCEffectivePreset() : int
{
    if (!theInput) { return 0; }
    return theInput.CCRefreshPreset();
}

// Exercise the actual fallback state machine without editing native config or routing.
exec function ccProbeFallback()
{
    var original : int;
    var alt : int;
    var altInvalid : int;
    var current : int;
    var currentInvalid : int;
    var restored : int;
    var restoreText : string;
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    original = CCEffectivePreset();
    alt = theInput.CCAcceptPreset(1);
    altInvalid = theInput.CCAcceptPreset(-1);
    current = theInput.CCAcceptPreset(0);
    currentInvalid = theInput.CCAcceptPreset(-1);
    restored = theInput.CCAcceptPreset(original);
    restoreText = "no";
    if (restored == original) { restoreText = "yes"; }
    theGame.GetGuiManager().ShowNotification("CC fallback: valid=" + IntToString(alt) + "/" + IntToString(current) + "; invalid=" + IntToString(altInvalid) + "/" + IntToString(currentInvalid) + "; restored=" + restoreText, 15000);
}

// Read-only lifecycle diagnostic; never opens, closes, or repairs a menu.
exec function ccProbeMenuState()
{
    var root : CR4MenuBase;
    var child : CR4MenuBase;
    var rootName : name;
    var childName : name;
    if (!theGame || !theInput || !theGame.GetGuiManager()) { return; }
    root = (CR4MenuBase)theGame.GetGuiManager().GetRootMenu();
    if (root)
    {
        rootName = root.GetMenuName();
        child = (CR4MenuBase)root.GetSubMenu();
        if (child) { childName = child.GetMenuName(); }
    }
    theGame.GetGuiManager().ShowNotification("CC menu: any=" + IntToString((int)theGame.GetGuiManager().IsAnyMenu()) + "; root=" + NameToString(rootName) + "; child=" + NameToString(childName) + "; raw=" + NameToString(theInput.CCProbeRawContext()) + "; pending=" + NameToString(theGame.GetMenuToOpen()), 30000);
}
