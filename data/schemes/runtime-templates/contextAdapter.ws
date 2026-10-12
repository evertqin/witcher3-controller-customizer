// Preset routing requires matching native compilation and installed aliases.
// Bootstrap verifies registration on game/save startup. No file writes.
function CCProbeCanonicalContext(contextName : name) : name
{
    return CCGeneratedCanonicalContext(contextName);
}

function CCProbeResolveContext(contextName : name) : name
{
    var baseContext : name;
    var preset : int;
    baseContext = CCProbeCanonicalContext(contextName);
    if (!theGame) { return contextName; }
    if (!theInput || !theInput.CCProbeRoutingActive())
    {
        return baseContext;
    }
    preset = CCEffectivePreset();
    if (preset != 0 && preset != 1) { return contextName; }
    return CCGeneratedResolveContext(baseContext, preset);
}

// Plain unsaved scalar cache, refreshed by the native getter on every access.
@addField(CInputManager)
private var m_ccProbeRawContext : name;

@addField(CInputManager)
private var m_ccProbeInspectingContext : bool;

@addField(CInputManager)
private var m_ccProbeRoutingActive : bool;

@addField(CInputManager)
private var m_ccMenuClosing : bool;

@addMethod(CInputManager)
function CCSetMenuClosing(closing : bool)
{
    m_ccMenuClosing = closing;
}

@addMethod(CInputManager)
function CCProbeRoutingActive() : bool
{
    return m_ccProbeRoutingActive;
}

@addMethod(CInputManager)
function CCProbeSetRoutingActive(enabled : bool)
{
    m_ccProbeRoutingActive = enabled;
}

@wrapMethod(CInputManager)
function GetContext() : name
{
    m_ccProbeRawContext = wrappedMethod();
    // Scripted-action consumers compare the literal 'ScriptedAction'.
    return CCProbeCanonicalContext(m_ccProbeRawContext);
}

@addMethod(CInputManager)
function CCProbeRawContext() : name
{
    GetContext();
    return m_ccProbeRawContext;
}

@wrapMethod(CInputManager)
function SetContext(contextName : name)
{
    var resolvedContext : name;
    resolvedContext = contextName;
    if (!m_ccProbeInspectingContext) { resolvedContext = CCProbeResolveContext(contextName); }
    wrappedMethod(resolvedContext);
}

// Synchronous bypass for registration inspection and startup validation.
@addMethod(CInputManager)
function CCProbeSetInspectionContext(contextName : name)
{
    m_ccProbeInspectingContext = true;
    SetContext(contextName);
    m_ccProbeInspectingContext = false;
}

@wrapMethod(CInputManager)
function StoreContext(newContext : name)
{
    wrappedMethod(CCProbeResolveContext(newContext));
}

@wrapMethod(CInputManager)
function RestoreContext(storedContext : name, contextCouldChange : bool)
{
    var actualContext : name;
    actualContext = CCProbeRawContext();
    // Use the actual expected-current-context name, not the newly desired preset.
    if (CCProbeCanonicalContext(actualContext) == storedContext) { storedContext = actualContext; }
    wrappedMethod(storedContext, contextCouldChange);
    // IngameMenu applies after its complete native close, not midway through restoration.
    if (!m_ccMenuClosing) { CCProbeApplyRestoredContext(); }
}

function CCProbeApplyRestoredContext()
{
    var currentContext : name;
    var nextContext : name;
    if (!theGame || !theInput) { return; }
    currentContext = CCProbeReadRawContext();
    nextContext = CCProbeResolveContext(currentContext);
    if (nextContext == currentContext) { return; }
    // Deactivation alone is NOT proof of held-button suppression.
    CCProbeReleaseOwnedActions();
    theInput.SetContext(nextContext);
    CCRefreshControlHints();
    LogChannel('ControllerCustomizer', "experimental context=" + NameToString(theInput.CCProbeRawContext()));
}
