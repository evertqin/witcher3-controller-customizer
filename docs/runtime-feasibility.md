> Current Phase 1 evidence: [phase1-evidence.md](phase1-evidence.md). Older probe snapshots below are historical; full runtime/manual release gates remain open.

# Runtime feasibility evidence

Status: Phase 0 in progress; runtime backend unproven. Updated 2026-10-10, America/Los_Angeles. Current diagnostic execution and desired menu persistence are user-confirmed. Binding dispatch and gameplay behavior remain unproven; source observations alone are not runtime evidence.

## Baseline and installed differences

At the initial baseline inspection, the source launcher checkout was clean `main` at `5f84ee7d3a5adc93ecd17e6003ba5868044d9fbb`. Both golden input hashes match the historical manifest. There are 48 ordered sections and exactly 12 physical-button changes across BASE_INTERACTIONS_HORSE (1), Horse (7), Horse_Replacer_Ciri (3), ScriptedAction (1). Native `State=Duration,IdleTime=0.3`, keyboard/mouse, axes, menus, photo-mode records and duplicate records are unchanged.

Installed game evidence:

| Item | Observed |
| --- | --- |
| Steam build ID | 25773555 |
| DX12 executable version | 5.0.0.1048522(Build Machine) |
| Native input version | 60 |
| DX11 executable | Absent at bin/x64/witcher3.exe |
| Historical diagram SHA-256 | 1e61ddcf0d7c55828b104294afc15e976dbfabe9b738c6f159a552c47097b059 |
| Installed diagram SHA-256 | 4118acdc778c384f059fd75c9967f8f091c70b80a05af782a9591f132b837b9a |
| Renderer menu file lists | Neither dx11filelist.txt nor dx12filelist.txt present |
| Legacy override | mods/modDarkSoulsControllerScheme present |
| Compiler | REDkit build 25773188 installed; five-file native compilation passed |

Recovered the historical vanilla diagram in memory by reversing the source launcher's fixture label permutation; its hash exactly matches the historical fingerprint. Comparison against the installed source showed seven diff hunks removing sprint-hold text from Geralt/Ciri combat labels, including Switch platform branches. This is a real content difference, not merely encoding. It does not establish why the file changed. Horse row structure remains row index 3 in both inspected creators. Historical compatibility data is preserved; the new observed hash is evidence, not a supported-build addition.

## Traced source contracts

Paths below are under the installed `content/content0/scripts/` and refer to the observed files, not a redistributable snapshot.

| Consumer | Source evidence | Probe/remaining coverage |
| --- | --- | --- |
| Native action queries | game/inputManager.ws:29-33; GetAction, GetActionValue, pattern access; IsActionPressed calls GetAction | ccProbeAction logs native queries and key enums; live input equivalence untested |
| Listener callbacks | game/inputManager.ws:39-40; horse exploration.ws:127-128 subscribes Canter/OnSpeedPress and Gallop/OnSpeedHold; :147-148 unsubscribes | Original subscriptions untouched; actual callback count and release balance untested |
| Riding query consumers | horse exploration.ws:228 queries Gallop; :1009 and :1874 query Canter | A callback-only router would miss these consumers |
| Gesture state logic | horse exploration.ws:2824 defaults DOUBLE_TAP_WINDOW to 0.4; :2839 OnSpeedPress updates triedDoubleTap/timestamps; :2926 OnSpeedHold dispatches gallop | IdleTime=0.3 is not the entire gesture implementation; changed gestures require tracing both bindings and script state |
| Scripted context identity | game/behavior_tree/tasks/player/btPlayer.ws:35-40 and :53 compare literal ScriptedAction | Adapter getter canonicalization is required to avoid repeated state replacement and broken restoration |
| Context lifecycle | game/inputManager.ws:42-51 exposes SetContext, StoreContext, RestoreContext | No binding setter or context registration method in this class; selection is not loading |
| Native event data | game/inputManager.ws SInputAction contains imported const fields | No fabricated writable native event implementation |
| Settings persistence | game/inGameConfigWrapper.ws:21-23, :58-59; ingameMenu.ws SaveChangedSettings and OnClosingMenu | Desired preset read/log wrapper; persistence still requires game test |
| Menu safety | ingameMenu.ws:653 restores EMPTY_CONTEXT inside OnClosingMenu | Probe logs after wrapped native close; no gameplay context override |
| Geralt/Ciri diagram | igmUtilities.ws:131/:916 creators; horse rows :616/:1138; ingameMenu.ws controller data sender | Both horse rows index 3; opt-in marker on one returned field, global creator wrappers compile/link; behavior untested |
| Flash mutation | game/gui/flashScriptImports.ws object string setters and array element get/set | Targeted transformation available in source; runtime marker/refresh untested |
| Context inheritance | bin/config/r4game/legacy/base/input_qwerty.ini Horse derives multiple bases, including BASE_INTERACTIONS_HORSE | Golden user records do not prove how new contexts load or inherit; no invented loader |

`ForceDeactivateAction` is exposed, but calling it alone would not prove held-button suppression, gesture reset or listener correctness. No per-frame polling, file writes or DLL backend was introduced.

## Prototype scope

`menuHooks.ws` reads the desired selector, logs native saves and applies the disabled context experiment after normal close/restoration. XML exposes two desired values using the native options shape. Neither proves menu discovery. `bin/config/r4game/ingameconfig.ini` specifies `MatrixPath="r4game\user_config_matrix\"`; that path is source evidence, not proof of automatic discovery of added files. `contexts.ws` and `bindings.ws` expose raw/logical context, native action/pattern/key queries and ignored-input observations. `diagram.ws` defaults to the native view and enables a single A-field marker only when `ControllerCustomizer/DiagramProbe` equals `true`, following native TOGGLE string semantics. It uses structural index 3, not translated display text. It does not display a guessed active preset. Global creator annotation syntax/linkage passed native compilation; loading, rendered marker and visible refresh remain unresolved.

`contextAdapter.ws` is a compiled, runtime-unverified candidate wrapping native Get/Set/Store/RestoreContext. It normalizes its eight aliases for scripted name comparisons, preserves the actual expected-current context argument on RestoreContext, and routes only the four owned base contexts when ContextProbe=true. The native raw context cache is a plain unsaved scalar. Unknown context names are left alone; invalid preset values preserve the incoming context. Native deactivation before an apply is instrumentation, not proof of suppression or callback correctness. All native/loose-script interactions, restore semantics, early initialization and save behavior still require validation.

`Generate-ContextProbe.ps1` generates only isolated context appendices from the owned golden fixtures. Tests prove the exact flat records, duplicate preservation, eight unique prefixed names, deterministic output and stale-output rejection. They do not prove engine registration, inheritance, live switching or an arbitrary remapping facility. No new live input/settings files were written. Do not confuse additional enumerated preset contexts with an arbitrary runtime editor backend.

All five WitcherScript files compiled against the installed bundled source. The failed protected sender wrapper was replaced with bare global creator wrappers that call wrappedMethod once and mark only horse row 3 txtAButton. Native compilation does not prove runtime load or rendering. [Settings Framework's hook example](https://github.com/SpontanCombust/tw3-settings-framework/blob/master/hooks/v4.04a_REDkit%2B/modSettingsFrameworkHooks/content/scripts/local/settings_framework_hooks.ws) was inspected for method annotation structure only; no framework code is copied. Its [README](https://github.com/SpontanCombust/tw3-settings-framework) documents settings generation and configuration access, not a general live input rebinding facility.

## Backend decision and gates

No backend selected. First establish supported custom-context loading with native patterns and inheritance, then prove Current/Alt1, stored-menu restoration and repeated live switches. Arbitrary mappings and changed gestures still require a real engine rebinding facility or a demonstrably complete router covering queries, listeners, old-binding suppression and key lookup. Native DLL injection and broad state rewrites are outside this implementation authorization.

Additional source inspection on 2026-10-10: the horse's `OnSpeedPress` and `OnSpeedHold` callbacks read native value/pattern fields without using `action.aName`; no `action.aName` reference occurs in that horse state file. A configurable router could therefore be investigated by selecting startup-loaded button/gesture primitive actions for both queries and listener registration. This is different from enumerating whole custom profiles. It remains a candidate only: primitive loading, matching query metadata, listener re-registration after edits, old-button suppression, native key lookup and the horse's separate double-tap state all need proof. Other consumers may depend on the action name, so this observation does not establish general editor coverage. `ReloadGameplayConfig` exists in `engine/game.ws:236`, but no script call or demonstrated input-reload contract was found; it is not treated as a rebinding API.

A second test candidate is the native input configuration builder. Installed `bin/config/r4game/user_config_matrix/pc/input.xml:3-9` declares `builder="Input"`, `displayType="INPUTPC"` and an `actions` list; its GallopCanter variable targets both native action names. `ingameMenu.ws:4675-4742` handles keyboard changes and calls `SetVarValue('PCInput', keybindTag, newKeybindValue + ";IK_None")` at line 4731. The exported script does not establish the native builder's controller filtering, replacement rules, context scope or gesture editing. Test a dedicated probe action/variable in an isolated configuration before considering existing actions: accepting a pad enum would be insufficient if the old pad record still fires or keyboard records are replaced. Do not experiment by writing the player's real GallopCanter variable. No such setter experiment has run.

Native context/global creator hooks compiled; their loading and compiled versus loose-script interactions remain untested. Menu registration, successful packaging paths and cross-mod behavior remain untested. Consult the [remaster modding guide](https://mod.io/g/the-witcher-3/r/what-does-the-remaster-mean-for-modding) when the matching toolchain is ready; its browser response was not readable during this run, so no new details are inferred from it.

## Installed toolchain evidence — 2026-10-10

Steam completed REDkit build 25773188 with No Error at 09:48:03 America/Los_Angeles. The completed `wcc_lite.exe` SHA-256 is `9f448e0c8b9ea1ea803d0ae543f2fcd6e905088b8b71f54da2bff22c6cf318fc`; its Windows version fields are empty. Editor version is 5.0.0.1048625(Build Machine); the bundled release executable reports 5.0.0.1040524(Build Machine).

Compared bundled `r4data/scripts/` against installed game `content/content0/scripts/` for the three hook-source files:

| File | SHA-256 in both installations |
| --- | --- |
| game/inputManager.ws | 9aa531cf1642408bfeabeb799fe5170e71e0d5a659983d934c28d52558a113a5 |
| game/gui/main_menu/ingameMenu.ws | fe051467b393dc3b0ac15dfdcf1d6064210853600cc254ba3fd20b32b1a6518e |
| game/gui/main_menu/ingamemenu/igmUtilities.ws | 4118acdc778c384f059fd75c9967f8f091c70b80a05af782a9591f132b837b9a |

This establishes equality for these installed sources, including the diagram source that differs from the historical fixture. It does not replace the historical compatibility manifest or prove runtime/native-hook compatibility.

The user handled the first-run EULA and reported acceptance. Help and five-file patch compilation then succeeded from bin/x64_RedKit. Latest build: build/20261010-102226-0b3ab860/build.json, exit 0, 4184-byte blob, no errors after compilation began. Build-Mod.ps1 pins the inspected toolchain, snapshots sources, and rejects compilation errors even with native exit 0. A patch-named source root produced assertions; the tested scripts-named root succeeds. See build.md for exact arguments, output hash, disqualified older output and startup diagnostics. No scripts were loaded in-game. REDkit created editoruser.settings; input.settings changed during the session with writer unresolved and remained stable through later builds. No project script wrote personal input or installed/migrated a mod.

## Verification record

| Check | Result |
| --- | --- |
| Test-Presets.ps1, Windows PowerShell 5.1 | Passed |
| Test-InputRecords.ps1, Windows PowerShell 5.1 | Passed |
| Test-Prerequisites.ps1, Windows PowerShell 5.1 | Passed after fixing expected-error handling for native stderr |
| Test-ContextProbe.ps1, Windows PowerShell 5.1 | Passed; generation only, no runtime proof |
| Read-only installed prerequisite discovery | Completed; Ready=false, source mismatch and legacy override reported |
| Native compilation/linkage | Passed: latest build above, five patch files, global/native hooks |
| Test-BuildMod.ps1, Windows PowerShell 5.1 | Passed: unverified compiler refused before execution or output creation |
| In-game load/context/persistence/diagram | Not run |
| Phase 1/2 release criteria | Not run; dependent on Phase 0 |

## Cooked output inspection — 2026-10-10

The user reported cooking successfully. Inspected the packed output: `mods/modCustomizeControllerScheme/content/precompiled.rsblob` (4184 bytes, SHA-256 `1dcb63c9ce0c2ce8424eeb2b9c66720acb10e807c119c91f327e7e055e097b32`), `info.json` (336 bytes) and `metadata.store` (114 bytes). The publish directory contained no ZIP. A ZIP is not required to inspect this local packed layout. Frozen artifacts and full log: `build/redkit-cook/20261010-124540-c21c80e8/`; evidence report: `cook.json` there. This proves output placement, not game loading.

The script phase parsed the five probe files, generated 815 code nodes, compiled and reloaded successfully, with no errors in that phase. All five editor source texts matched the original build after decoding and newline normalization; raw hashes differed following editor encoding/newline normalization. The project reports succesfullyCooked=true; generated info.json reports false. Preserve this discrepancy without changing the emitted flag or claiming runtime compatibility.

The complete cooking log contains **33 error diagnostics**, including attempts to treat the five .ws files as generic resources, a missing initial cook.db, missing Wwise 2023.1 and failure to remove packed/dlc. The script-only output contains no audio or cooked resource bundles. Script compilation passed; the whole cooking run is not classified error-free, and its runtime validity remains unproven. No Wwise installation or global SDK configuration change was undertaken.

### Visible load probe and retry gate

Added a read-only `ccProbeLoaded()` exec command to contexts.ws. After a loaded save it should display `CC probe loaded; context=...` through the existing GUI notification API (r4guimanager.ws:1389). This addition is **not yet compiled**. The matching standalone attempt `build/20261010-125619-17666890` stalled during startup before the compilescripts commandlet, with both REDkit editors open. Stopped only the identified compiler process; its report records exit -1, Succeeded=false and no blob. Editor contention is a hypothesis to test, not an established cause. Requested editor closure before retry; editor processes and unsaved work were preserved.

Prepared `Install-RuntimeProbe.ps1` and `Restore-RuntimeProbe.ps1` for a temporary load test. Installation refuses failed/stale builds, changed native hook sources and existing targets; it will add the three-file probe mod and prototype menu XML, then enable the debug console with a byte-preserving general.ini backup. Both experimental flags stay false. Existing legacy mods and personal gameplay settings remain outside its write set. Installation has **not** run. See `runtime-probe.md`.

Windows PowerShell 5.1 verification passed: failed-build installation refusal left the live console/menu/mod targets unchanged; rollback preflight refused later edits without partial restoration, restored original bytes and preserved unrelated additions. Personal input.settings remains `9ccfb04155744fd624d850ed858fa987d33c3a4ab00d9a8473525cfbf3b0886c`; user.settings remains `605e1bd8e3ce235d7a7c1d11d6de3ffae186551b91362997a9781539d4660d6b`. No live mod/menu/console installation or runtime acceptance occurred.


### Standalone retry after editor closure — 2026-10-10

The user closed both REDkit editors. The matching standalone retry
`build/20261010-131424-4edac9ce/build.json` still stalled before the
compilescripts commandlet; it was stopped with process identity checks and
records exit -1, Succeeded=false and no blob. Editor contention is not an
established cause. Help experiments using a noninteractive assertion option,
explicit depot/workspace overrides, an isolated working-directory configuration,
and hidden native process launch did not reach help completion. No compiler
success is inferred from these experiments; shared SDK configuration was not
edited. Only task-owned compiler processes were stopped.

The five current editor source texts were verified against the canonical sources,
including the new read-only `ccProbeLoaded()` notification. Receipt:
`build/20261010-131424-4edac9ce/retry.json`. The earlier cooked blob predates this
addition and must not be presented as a build of the current sources. The next
step uses the previously working REDkit editor cooking path: reopen
`F:\projects\TheWitcher3\customizecontrollerscheme\customizecontrollerscheme.w3edit`
and choose Publish → Save and publish mod project locally. Inspect the fresh
script phase, source snapshot and packed blob before installation. Do not publish
to a storefront. This manual editor operation is necessary because standalone
startup remains unresolved and this session has no editor-control tool.

Personal input.settings and user.settings retained their recorded hashes. No
probe mod, menu, console configuration, fixed context or save was installed or
modified. Phase 0 compilation of the notification, loading and all runtime gates
remain pending; dependent Phase 1/2 work remains pending.

### Updated editor cook and temporary installation — 2026-10-10

The user cooked the updated sources through REDkit. The publish log for
14:28:44 parsed 1,525 base scripts and the five current probe files, generated
875 patch code nodes, compiled/loaded them, reloaded scriptables and finished
CompileScripts. No error occurred in the script compilation phase. Current
canonical/editor sources match after decoding and newline normalization, and
their hashes and copies are frozen with matching SDK/game hook fingerprints in
`build/redkit-cook/20261010-142844-fe31b66a/cook.json`. The 4,419-byte blob has SHA-256
`f3e49c42663e362973635001d8cadb617165b13ae996ab8032df0be48cd9e09b` and includes ccProbeLoaded.
This is editor-cook evidence; no standalone exit 0 is fabricated.

The full cook still has 33 resource/audio/cleanup error diagnostics, retained in
the snapshot. Unlike the first cook, both project metadata and fresh info.json
report succesfullyCooked=true. The observed packed directory uses lower-case
modcustomizecontrollerscheme; the installed mod directory uses the equivalent
Windows path modCustomizeControllerScheme. Whole-cook cleanliness and runtime
validity are not inferred from a successful script phase.

Added an explicit Install-RuntimeProbe.ps1 -CookedOnly path. It requires the
current-source cook receipt, intact log/blob/metadata, complete current source
inventory and matching installed hook fingerprints. The standalone path retains
its exit/error gates. Test-InstallRuntimeProbe.ps1 passed in Windows PowerShell
5.1 against a temporary game tree: stale source receipt and corrupted blob
refuse without mutation; valid cooked installation and restoration preserve
original console configuration and an existing mod.

The verified cooked probe is now installed reversibly at
`F:\Steam\steamapps\common\The Witcher 3`. Owned writes are the three-file
probe mod, modControllerCustomizer.xml and the backed-up DBGConsoleOn addition
to general.ini. Journal: `work/runtime-probe/install-20261010-143310-73d51cc8/install.json`. All five installed hashes match
the journal; all previously present mod files and personal input.settings and
user.settings retained their pre-installation hashes. No input contexts or save
files were written. Both experimental flags default false, and no pre-existing
ControllerCustomizer settings group was present before installation.

Real game startup, ccProbeLoaded notification, menu discovery/persistence,
native/loose-script interaction, context registration/switching, arbitrary
mapping/gesture behavior and diagram rendering remain untested. The user was
asked to launch/load, execute ccProbeLoaded(), and report the menu observations.
Phase 0's runtime gate and dependent Phase 1/2 work remain pending.

### Missing baseline files observed and project fixtures recovered — 2026-10-10

Read-only Git status now shows five tracked deletions in the original launcher checkout: both control-schemes input.settings files, both full igmUtilities.ws overrides, and verification/fixtures/igmUtilities-1.0.0.ws. This task did not write or restore that checkout; those unrelated changes remain intact. The writer is unknown.

Both independent golden input fixtures in the new project were also missing, causing a fresh Test-Presets.ps1 run to fail before validation. Recovered only those two implementation-owned fixture copies from byte-exact Git blobs at the recorded revision 5f84ee7d3a5adc93ecd17e6003ba5868044d9fbb after validating both manifest hashes; existing targets were refused. Test-Presets.ps1 then passed again in Windows PowerShell 5.1. Recovery receipt: build/redkit-cook/20261010-142844-fe31b66a/fixture-recovery.json. No live input, game file or original checkout was changed by this recovery.

### First runtime observation and menu correction — 2026-10-10

The user did not see Controller Customizer prototype in Settings. After console
instructions, the user reported ccProbeLoaded() displayed loaded with context=empty
and closed the game. This confirms the installed compiled probe executed; it does
not prove the correct gameplay context, custom-context registration or rebinding.
Journal/runtime-observation.json records this distinction. No riding/menu/gesture
acceptance is inferred from the notification.

Native igmOptions.ws:310–318 selects the group label prefix from customDisplayName,
then :383 and :396 resolve group labels through GetLocStringByKeyExt. Group
nonLocalizedName does not provide literal group labels. The prototype used an
unregistered literal string as a group localization key. This is a known menu
label defect; absence of the expected title alone does not establish whether the
XML was loaded. Native variable code uses nonLocalizedName for the row label and
nonLocalized for option values (:1158). The prototype lacked the latter flag.

Corrected only the owned menu XML: ControllerCustomizer now uses the existing
gameplay displayName and the literal row label Controller Customizer: desired
riding preset. Current/Alt1 option values use nonLocalized; IDs, values and hidden,
false ContextProbe/DiagramProbe flags are preserved. This diagnostic uses Options
→ Gameplay to distinguish XML discovery from custom group localization; a dedicated
localized Controller Customizer category remains later work. No scripts changed
and no re-cook was required.

After the user closed the game, applied the correction, backed up the prior menu
and updated its rollback hash/history in
work/runtime-probe/install-20261010-143310-73d51cc8/install.json. All five owned
hashes match the updated journal. Corrected menu SHA-256:
c90db5d14ae6783eae7b4974bbb5bb03d3b00d3d50e3506795489cff0a7c1122.
The guarded updater is retained in the task workspace at
work/apply-probe-menu-fix.ps1. Compiled blob, metadata and console bytes were not
changed by this update.

Requested a fresh game launch, Gameplay selector/labels check, desired Alt1
close/reopen and restart persistence, and normal menu navigation. These checks
remain pending. Live preset switching, arbitrary mapping/gesture behavior and
diagram tests remain unproven; overall Phase 0 and dependent Phase 1/2 gates
remain pending.


### Selector confirmed; personal-context probe prepared — 2026-10-10

User reports "yes, it is there and alt1 persists" after the requested Gameplay
selector, close/reopen and restart checks. The active DX12 profile is
dx12user.settings, not user.settings: its ControllerCustomizer section contains
Preset=1. This confirms native XML discovery and desired-choice persistence.
Normal navigation, held-input safety and effective live remapping remain unverified.

Added a separate personal-context generator and input install/restore journal.
It copies the player's four current sections into eight aliases, changes only
the verified twelve pad records, and appends them while preserving every original
byte. Alias sections retain personalized keyboard, axes, comments, duplicates and
unowned pad bindings. Unsupported owned mappings, ambiguous sections and existing
probe aliases refuse before input mutation. Restoration verifies the original
backup and installed hash; later input changes are refused rather than overwritten.
No native input_qwerty.ini changes are planned for this first loader experiment.

Windows PowerShell 5.1 Test-PersonalContextProbe.ps1 passed preservation,
unsupported-input refusal, byte-exact install/rollback and later-edit protection
on temporary input files. Actual startup registration is still unproven.

Three authored scripts were updated in the REDkit workspace, with all five source
hashes recorded in work/runtime-probe/context-handoff.json. ccProbeContexts()
checks raw alias selection and expected native pad-key lookup for all eight
contexts, then restores the original context. A synchronous inspection bypass
prevents disabled normal routing from canonicalizing the test aliases.
ccProbeContextMode(true) refuses activation unless all eight lookups pass;
false disables it. ccProbeDiagram(true/false) enables/disables the targeted marker.
These new commands are NOT compiled or installed yet; the current installed blob
remains the previously confirmed load/menu probe. Fresh editor cooking is required.
Key lookup alone cannot prove action dispatch, queries, callbacks or riding safety.
Arbitrary customization and changed gestures remain unimplemented.

### Legacy diagram mod isolated — 2026-10-10

At the user's suggestion, temporarily disabled modDarkSoulsControllerScheme for
baseline probe testing. Its only payload is the full igmUtilities.ws override,
which defines both InGameMenu_CreateControllerData and its Ciri counterpart.
Those are also the functions wrapped by the new diagram probe. An isolated test
is needed before restoring the legacy mod for the separate compatibility check;
no runtime conflict or compatibility result is inferred from source overlap.

With Witcher 3 closed, moved the exact verified folder outside mods to
F:\Steam\steamapps\common\The Witcher 3\controllerCustomizerTestBackups\legacy-isolation-20261010-145752-34fd8cd5\modDarkSoulsControllerScheme.
The original path is absent and its one script retains the original SHA-256.
Personal input.settings and dx12user.settings hashes were unchanged by the move.
Removing this diagram mod does not revert the existing controller bindings.
Other mods and the compiled probe remain installed.

Isolation/restore scripts parsed successfully. Journal:
work/runtime-probe/legacy-isolation-20261010-145752-34fd8cd5/isolation.json.
To restore with the game closed, run Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Restore-LegacyProbeIsolation.ps1 -JournalFile '.\work\runtime-probe\legacy-isolation-20261010-145752-34fd8cd5\isolation.json'
```

Restoration refuses an occupied original path, changed backup inventory/hashes or
reparse points. This separate journal must be restored in addition to the probe's
own uninstall journal. Actual restoration has not run. Latest diagnostic sources
still need the requested fresh REDkit editor cook; no new runtime gate is passed.

### Corrected context/diagram commands cooked and installed — 2026-10-10

User reported cooked. The fresh 15:34:44 publish log compiled 1,525 base scripts
and all five current probe scripts, successfully loaded/reloaded them and finished
CompileScripts without script-phase errors. Canonical/editor text equivalence,
pre-compilation source times, installed SDK/game hook fingerprints and packed
payload hashes were verified. Both project metadata and emitted info.json report
succesfullyCooked=true; useLooseScripts=false remains unchanged.
Frozen evidence: build/redkit-cook/20261010-153521-8f10c8cf/cook.json.
Blob: 6,870 bytes, SHA-256
647884997d6cedf6ae93a22ec2f20257ae9fb4aeef24ca9780e0df0c6b937b32.
All 33 outer resource/audio/cleanup errors remain in the frozen cook log; the
whole cook is not classified error-free. The previous wrappedMethod error is
resolved in this actual native compilation.

Added Update-RuntimeProbe.ps1 and verified it in Windows PowerShell 5.1 using
Test-UpdateRuntimeProbe.ps1. Tests passed stale-source/corrupt-payload refusal,
later installed-edit preservation, rollback when the third target is locked,
valid update with exact old-artifact backups, reset of fresh runtime claims and
byte-exact full-probe uninstall. This verifies update/rollback behavior, not gameplay.

With Witcher 3 closed, updated only the three compiled mod files. Menu/console
bytes retained their journal hashes. The original probe journal now records the
new hashes, frozen cook and artifact history; prior user runtime observations are
retained under PreviousArtifactObservations, not attributed to the new blob.
Backup/update evidence:
work/runtime-probe/install-20261010-143310-73d51cc8/updates/artifacts-20261010-154048-a286868b/.
All five owned installed hashes match the updated journal.

The new commands are installed but their game execution is not yet verified.
No personal input aliases have been installed yet: REDkit was still open after
cooking, and the user was asked to close it before updating the shared input
profile. Generate aliases afresh from current bytes rather than applying the
stale candidate. ContextProbe/DiagramProbe defaults remain false; active
dx12user.settings contains Preset=1 with no experimental flag enabled.
The legacy full diagram override remains isolated. Overall Phase 0 and riding,
arbitrary customization/gesture, query/callback and diagram gates remain pending.


### Personal input contexts installed; startup lookup check pending — 2026-10-10

The user closed REDkit. Verified neither REDkit nor Witcher 3 was running before
installation. In Windows PowerShell 5.1, Install-InputContextProbe.ps1 generated
eight aliases afresh from current input.settings and the verified twelve-record
pad delta. It appended only those aliases, preserving the exact original prefix.
The stale earlier candidate was not applied. Original input SHA-256:
e0e026b64d3253f1d785ece9637cb05f98137bc4419eda706bbb4742bf038d4e.
Installed input SHA-256: 48d20010ed134207ac5dff2c0d56375fd4bbacb2165c0566ffa23382bb9c1704.
Original bytes: 111078; appended bytes: 23276.
Exact backups, appendix and ownership receipt:
work/runtime-probe/input-20261010-154354-6e795fb2/install.json.
preservation.json confirms installed bytes equal original bytes plus the appendix,
eight unique alias headers, unchanged probe artifact hashes and legacy isolation.
No native input_qwerty.ini, user settings or save file was changed by this operation.

The current compiled commands are installed; ContextProbe and DiagramProbe remain
disabled. Input startup loading, action dispatch and live riding behavior remain
unverified. Next launch/load a save, open the console with backtick/tilde, and run
ccProbeContexts(). Report the complete notification count or any startup/console
error. Expected success: CC context lookups: 8/8; original context restored.
Do not enable ccProbeContextMode yet. A successful lookup only proves this
registration/metadata check, not press/hold/release, listener dispatch or held-input
safety. Collect those observations in the following controlled riding test.

Rollback now has three separate journals. With Witcher 3 and REDkit closed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Restore-InputContextProbe.ps1 -JournalFile '.\work\runtime-probe\input-20261010-154354-6e795fb2\install.json'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Restore-RuntimeProbe.ps1 -JournalFile '.\work\runtime-probe\install-20261010-143310-73d51cc8\install.json'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Restore-LegacyProbeIsolation.ps1 -JournalFile '.\work\runtime-probe\legacy-isolation-20261010-145752-34fd8cd5\isolation.json'
```

Input restoration refuses later input edits instead of overwriting them; retain
backups and reconcile owned aliases if the game rewrites the file. Runtime and
legacy restorers also preflight hashes/ownership. Actual uninstall has not run.
Overall Phase 0 and dependent gameplay/customization/diagram gates remain pending.


### Startup lookup failure; finer diagnostic prepared — 2026-10-10

User reports ccProbeContexts(): 0/8; original context restored. This confirms
execution of the installed 6,870-byte blob, not custom-context registration.
The old score combined raw context identity and a single expected pad key;
it does not identify which condition failed. Restoration is user-reported, not
independently verified. Runtime evidence: work/runtime-probe/lookup-failure-20261010-155914/runtime-observation.json.

The input file changed during the runtime session, including section/record order.
All eight alias binding multisets, including duplicate counts, still match the
installed appendix. Observed SHA-256: 55f3bb05a271c3e13f438d9643cd5789044dfd2ffd7153468d0af4bdcadfbba1.
The writer is not independently identified. No live input was modified here.

Prepared ccProbeContextDetails(): native Horse control plus Current/Alt1 aliases,
separate raw-selection/cache results, pad-key counts and enum values. Inspection
explicitly refreshes the wrapped getter before capturing/restoring native context.
ccProbeContexts() now reports selected, keys and combined counts separately.
ContextProbe stays disabled; the live routing backend is unchanged. Current
canonical/editor sources match; fresh REDkit cooking is required before installation.

Restore-InputContextProbe.ps1 now accepts -RemoveOwnedContexts after normal game
serialization. It verifies each alias's complete binding multiset, refuses changed,
missing or duplicate owned records/headers, preserves all other current bytes,
BOM, comments and duplicates, and retains an exact pre-removal backup. Default
whole-file restoration still refuses later edits. Test-OwnedContextRemoval.ps1
and Test-PersonalContextProbe.ps1 passed in Windows PowerShell 5.1; a read-only
preview passed against the actual rewritten profile. Actual removal has not run.
Overall Phase 0, live switching, arbitrary gesture/query/callback and diagram
acceptance gates remain pending.


### Detailed context diagnostic cooked and installed — 2026-10-10

User reported cooked. Fresh editor log publish 2026-10-10 16-07-58.log compiled
1,525 base scripts and five current probe scripts, loaded/reloaded scriptables
and completed CompileScripts without script-phase errors. Current canonical/editor
text and toolchain/hook hashes match. Frozen evidence:
build/redkit-cook/20261010-160807-eaa1d561/cook.json.
Blob: 8,239 bytes; SHA-256 784fee9f28ff42dfb0e15db3ef2b3f5650ba81077467e8b0cd60cb2262b7a068.
The full log retains 33 outer cooking errors; whole-cook error-free is false.

With Witcher 3 closed, the tested Update-RuntimeProbe.ps1 installed only the three
cooked files with exact backups and journal updates. All five installed ownership
hashes match; personal input SHA-256 is unchanged from the failed lookup session;
the legacy diagram override remains isolated with verified backup hashes.
Update backup: I:\OneDrive\Documents\The Witcher 3\github-project\witcher3-controller-customizer\work\runtime-probe\install-20261010-143310-73d51cc8\updates\artifacts-20261010-160917-231e08fe.
The prior 0/8 execution observation is retained under PreviousArtifactObservations;
it does not apply to this new blob. Fresh runtime execution/registration are unverified.

Next: close REDkit if open, launch Witcher 3 and load a save, stopping for startup
script errors. Run ccProbeContextDetails() in the backtick/tilde console and report
Horse/Current/Alt1 selected/cache/key values and the expected A/L3 enum values.
Then run ccProbeContexts() and report selected/keys/both totals and restoration.
Keep ContextProbe disabled. These diagnostics establish only selection/key lookup;
live switching, arbitrary mapping/gesture, callbacks, held-input safety and targeted
Geralt/Ciri diagram acceptance remain pending. Overall Phase 0 is incomplete.


### Screenshot observations invalidate the single-key test — 2026-10-10

The user supplied screenshots from the installed 8,239-byte blob. Horse, Current
horse alias and Alt1 horse alias each report selected=1 and cache=1; all three
return Canter keys [146,136], with A=136 and L3=146. Both diagnostics report
restoration. This confirms fresh command execution and these name-selection
observations, not loaded alias bindings or native event dispatch. The same key
list across selections disproves the diagnostic's single-expected-key assumption;
aggregation across contexts is a plausible inference, not a verified API contract.

The separate eight-context command reports selected=0/8, keys=0/8, both=0/8.
It did not report array size or executed iterations. That disagreement therefore
does not prove all eight SetContext calls failed. Raw cache refresh failure was
not observed in the three scalar controls. Original screenshots, source snapshot
and structured observation: work/runtime-probe/context-screenshots-20261010-161726/.

Prepared explicit scalar checks for all eight aliases with checked/selected/
single-key/both counters and requested/raw details for name-selection failures.
Added an unregistered negative control, absent from current input and native/SDK
config searches, to test whether arbitrary names are accepted too. Names and key
membership alone cannot prove registration/dispatch. ccProbeContextMode(true)
now refuses enablement independently of the diagnostic score; false remains
available for restoration. No native routing wrappers or personal bindings changed.
Current canonical/editor source text matches; another fresh native cook is required.

Input changed again during the runtime session; SHA-256 0c1406973c3f4164a0f6613c53c1c0e2330e3587c1ee1477b49ec0b5f99578f8.
All eight owned alias binding multisets still match the installed appendix, and
the read-only owned-removal preview succeeds. Experimental config flags remain
disabled. No live artifacts or profile bytes changed in this update. Phase 0,
live presets, arbitrary mapping/gesture, query/callback and diagram gates remain
pending; do not move into backend-dependent phases on name-selection evidence.


### Explicit context checks cooked and installed — 2026-10-10

Fresh publish 2026-10-10 16-22-11.log compiled 1,525 base scripts and all five
current probe scripts, loaded/reloaded scriptables and completed CompileScripts
without script-phase errors. Canonical/editor text and pinned toolchain/native
hook hashes match. Frozen evidence: build/redkit-cook/20261010-162220-fb949d76/cook.json.
Blob: 8,612 bytes; SHA-256 3911ccd3ef733498fc556ea258b7135de54c13bf748e4acc95b1451eb561bff8.
All 33 outer cooking errors remain in the frozen log; whole-cook error-free is false.

With Witcher 3 closed, the tested updater replaced only the three cooked files,
retaining exact backups and updating the ownership journal. All five installed
hashes match; personal input SHA-256 remains
0c1406973c3f4164a0f6613c53c1c0e2330e3587c1ee1477b49ec0b5f99578f8.
The legacy diagram override remains isolated with verified backup hashes;
experimental flags remain disabled. Backup: I:\OneDrive\Documents\The Witcher 3\github-project\witcher3-controller-customizer\work\runtime-probe\install-20261010-143310-73d51cc8\updates\artifacts-20261010-162249-c0895008.
The previous screenshots are retained as observations of the preceding blob;
fresh execution of this new diagnostic remains unverified. Enablement is blocked
independently of the score. No new automated code tests were needed: the guarded
updater was already verified, and this actual cook validates the changed script.

Next: close REDkit if open, launch Witcher 3 and load a save; stop for startup
script errors. Open backtick/tilde console and run ccProbeContexts(). Report the
full checked/selected/single-key/both/missing-selected notification, any requested/
raw failure details and restoration. Expected executed checks: 8/8. Counts and
the unknown-context control are diagnostic observations, not a registration or
event-dispatch acceptance gate. Leave live routing disabled. Phase 0 and riding,
arbitrary mapping/gesture, query/callback and Geralt/Ciri diagram gates remain pending.


### Alias-name gate and Geralt diagram passed; riding observer staged — 2026-10-10

User screenshot reports checked=8/8, selected=8/8, single-key=0/8, both=0/8,
missing-selected=0, restored. All eight startup alias names are selectable while
the unregistered name is not. This resolves the old array-loop disagreement and
passes name availability; it does not prove binding event dispatch, native
inheritance or held-input safety. Single-key metadata remains an unsuitable
gate; previous Horse/Current/Alt1 queries returned A/L3 together. Screenshot and
structured evidence: work/runtime-probe/name-gate-ride-handoff-20261010-163248/.

User also reports Geralt, confirmed, closed after the requested marker-on/off
Controls test. Geralt horseback A-field marker display/removal is confirmed;
Ciri and exhaustive unchanged-field checks remain pending. DiagramProbe=false
is present in the profile. All eight owned input binding multisets remain exact,
and the installed five ownership hashes match. No live game artifacts changed.

Staged riding opt-in uses an unsaved CInputManager boolean, not the persisted
ContextProbe variable, so a full restart disables routing. It first requires
all eight selected names and the missing control to fail, then attaches one
read-only observer for Canter/Gallop; normal console/menu restoration applies
the chosen alias. Disable normalizes context, deactivates owned actions and
unregisters this observer. Existing horse listeners/handlers are unchanged;
native horse source SHA-256: 824e0c91d05cd3d5027c663d7bf4d47f9124793b265374475d208f5fa17adcd3.

The observer records press/release edges, pattern-bearing callbacks, original
callback names/contexts, registration start/stop counts and comparisons against
GetAction/GetActionValue/pressed/released/pattern queries during native callbacks.
Other-context callbacks are counted separately. ccProbeRideReset() clears only
observations; ccProbeRideStatus() shows routing, desired preset and results.
Zero callbacks cannot establish agreement; this observer's balanced lifecycle
does not prove the native horse listeners' balance. Pattern-callback counts are
not gesture counts. HUD pad-key lookup remains unresolved. Arbitrary mappings,
gesture edits, Ciri/ScriptedAction gameplay and held-button suppression remain
unproven. No synthetic events, file reloads, per-frame polling or native horse
handler replacements were added. Current canonical/editor sources match; actual
native compilation and installation are still required before riding tests.
Overall Phase 0 and backend-dependent phases remain pending.


### Transient riding observer cooked and installed — 2026-10-10

Fresh publish 2026-10-10 16-38-18.log compiled 1,525 base scripts and the five
current probe scripts, loaded/reloaded scriptables and completed CompileScripts
without script-phase errors. New observer class/events, added transient fields
and name-only opt-in gate compiled with the matching toolchain. Source text and
toolchain/native hook fingerprints match. Frozen evidence:
build/redkit-cook/20261010-163827-3bfbead6/cook.json.
Blob: 12,202 bytes; SHA-256 b898dbc0388cd9b095ce181a02d35d7d03b1d043ebe6e925ca9e8e3a9476ff64.
Full log retains 33 outer errors; whole-cook error-free remains false.

With Witcher 3 closed, the tested updater installed the three cooked files with
exact backups/journal updates. All five installed hashes match. Input retains
SHA-256 55f3bb05a271c3e13f438d9643cd5789044dfd2ffd7153468d0af4bdcadfbba1;
desired Preset=1 and DiagramProbe=false are retained. Native horse source is
unchanged; legacy diagram isolation/backup hashes are intact. Update backup:
I:\OneDrive\Documents\The Witcher 3\github-project\witcher3-controller-customizer\work\runtime-probe\install-20261010-143310-73d51cc8\updates\artifacts-20261010-163906-50e7e5c6.
Previous name-selection/Geralt marker results are preserved as observations of
the preceding blob. New runtime execution, listener dispatch, query agreement
and routing reset on restart have not yet been observed. Session routing starts
disabled and is not saved in configuration.

First runtime step: close REDkit if open, load Geralt and mount in a clear area.
Keep desired Alt1; stop and release A/L3. Run ccProbeContextMode(true) in console;
after its enabled notification, release A/L3 and close console. Open/close Options
once with buttons released so the known menu-restoration hook applies the alias.
Hold L3 to canter, double-press-and-hold L3 to gallop, then release; report movement
and the complete ccProbeRideStatus() notification. Finish with
ccProbeContextMode(false). Stop/report startup errors or an enablement failure.
Expected useful evidence: nonzero native speed callbacks, press/release records,
query mismatches=0 and last context CC_PROBE_Alt1_Horse. Zero callbacks prove
nothing. Current/Alt1 live switching, opposite-key suppression, interactions,
Ciri/scripted riding, held-menu behavior and arbitrary mappings/gestures remain
pending. Overall Phase 0 is incomplete.


### Riding report with routing disabled — 2026-10-10

User first reported canter working, continued gait after L3 release and failed
double-L3 gallop. Follow-up ccProbeRideStatus() reported routing=0, desired=1,
CC ride observer not started; the user then reported both canter and double-L3
gallop working. The newly added status command confirms current compiled probe
execution. Its absent observer and disabled routing provide no alias callback,
query-agreement or live-switching evidence. The enable-command notification and
session continuity are not reported; neither failed enablement nor restart reset
is established. The initial gallop failure cannot be attributed to live routing.

Native horse OnSpeedPress release clears the OnGallop lock rather than setting
speed to zero; continued gait alone does not prove a stuck Canter action. Native
horse source remains unchanged. Next collect ccProbeContextMode(true)'s full
notification followed immediately by ccProbeRideStatus() without closing console
or restarting. Stop before riding if routing remains zero. No recook, input edit
or native gesture change is justified by this observation. Phase 0 remains open.

Evidence: `work/runtime-probe/ride-disabled-20261010-165051-8d1b65d2/runtime-observation.json`.


### Session opt-in and observer start confirmed — 2026-10-10

User's immediate status screenshot reports routing=1, desired=1, active=1,
starts/stops=1/0. All callback, press/release, pattern, mismatch and other-context
counters are zero; last context/action/pattern are None/None/None. This confirms
session opt-in and observer start, resolving the prior disabled status without
source changes or another cook. The separate enable-command notification was
not supplied. No callback activity has been collected, so zero mismatches do not
prove query agreement; selected riding alias and dispatch remain unverified.

Next, in the same game session, release A/L3, close console and open/close Options
once. Test L3 hold for canter, then quick click-release-click-and-hold for gallop.
Release L3 and report the full ccProbeRideStatus notification and horse behavior;
finish with ccProbeContextMode(false). Look for nonzero callbacks, release edges
and the Alt1 horse alias; assess query agreement only with actual callbacks.
Phase 0, live preset switching, held-input safety and arbitrary gestures remain
pending. No live game, profile or source files changed to record this evidence.

Evidence: `work/runtime-probe/ride-enabled-20261010-165208-2721a2ea/runtime-observation.json`.


### Alt1 riding callbacks and native query agreement observed — 2026-10-10

User screenshot reports routing=1, desired=1, active=1, starts/stops=1/0,
callbacks=36, Canter press/release=12/12, Gallop press/release=6/6,
pattern callbacks=0, query mismatches=0, other-context callbacks=0 and
last=CC_PROBE_Alt1_Horse/Gallop/None. This establishes real native speed
callback delivery and the observer's query agreement during these 36 accepted
riding callbacks. The last callback used the Alt1 horse alias; earlier individual
callback contexts were not retained. Balanced edge totals are observed, but
horse movement, physical-key exclusivity and broader held-input safety are not
established by counters. No original horse handlers or subscriptions changed.

Zero pattern callbacks do not establish failed double-tap behavior. The unchanged
native horse script computes its own 0.4-second double-tap window, while the owned
Gallop bindings retain State=Duration,IdleTime=0.3. A changed gesture, arbitrary
button mapping and native pattern semantics remain unverified. Next confirm the
actual canter/gallop behavior, disable with ccProbeContextMode(false), then capture
routing, active and starts/stops from ccProbeRideStatus. Both-direction mounted
preset switching and opposite-key suppression follow after this check. Broad
registration/gameplay acceptance and Phase 0 remain pending. Source, live mod,
input and native horse files were not changed to record this observation.

Evidence: `work/runtime-probe/ride-callbacks-20261010-165350-22724f82/runtime-observation.json`.


### Enabled gallop failure; observer shutdown passed — 2026-10-10

User reports "canter worked, double L3 didn't work" for the enabled test.
Shutdown screenshot reports routing=0, desired=1, active=0, starts/stops=1/1,
with all previous counts retained: callbacks=36, Canter=12/12, Gallop=6/6,
pattern callbacks=0, query mismatches=0, other-context callbacks=0 and
last=CC_PROBE_Alt1_Horse/Gallop/None. Canter movement and observer shutdown are
confirmed; the double-L3 gallop gameplay check failed despite received Gallop
edges. These events alone do not establish the native horse's double-tap decision
or speed restrictions. Full native subscription balance remains unverified.

Read-only comparison: all eight owned alias binding multisets still match the
verified installed appendix. Native Horse and Alt1 horse alias binding multisets
are equal: True. Native and SDK horse exploration source hashes match
824e0c91d05cd3d5027c663d7bf4d47f9124793b265374475d208f5fa17adcd3.
No binding or horse-source mismatch was found; runtime inheritance and timing
remain unverified. First repeat quick double-L3-and-hold with routing disabled
in the same area, without dismounting. This separates a context-related failure
from current horse restrictions or input timing before another diagnostic cook.
Phase 0 and both-direction switching remain pending; no source/live input/mod
files changed. Observed profile snapshot and both runtime receipts are retained.

Evidence: `work/runtime-probe/ride-gallop-failure-20261010-165635-bcc4a233/runtime-observation.json`.


### Remount recovery; replace competing observer listeners — 2026-10-10

Repeat screenshots show routing=1, desired=1, active=1, starts/stops=1/0;
callbacks grow from 0 to 18, with Canter=7/7, Gallop=2/2, no pattern callbacks,
query mismatches or other-context callbacks. Last event is
CC_PROBE_Alt1_Horse/Canter/None. User reports disable required dismounting before
both canter and gallop worked. Baseline and enabled movement results for this
repeat were not separately stated. Seamless disable recovery is not verified.

The diagnostic registered its own Canter/Gallop listeners after the horse's
OnSpeedPress/OnSpeedHold listeners. Native horse state entry registers those
listeners again, and double-tap state is updated inside OnSpeedPress; Canter is
also queried outside callbacks. Listener interference is therefore a strong
inference from this sequence, not an established native multi-listener contract.
Earlier probe callback/query agreement does not establish original horse callback
delivery or an uninvasive diagnostic. Prior observations remain retained.

Changed only bindings.ws: the observer now opens/closes an observation window
without any RegisterListener/UnregisterListener calls. Two Remaster state-method
wrappers for W3HorseComponentStateExploration.OnSpeedPress/OnSpeedHold invoke the
original handler exactly once, then record its actual callback. Original horse
registrations, speed/gesture logic and event data are preserved. Status identifies
source=horse handlers; starts/stops now count observation windows. State-wrapper
naming follows the Remaster guide:
https://mod.io/g/the-witcher-3/r/what-does-the-remaster-mean-for-modding

Added the inspected native/SDK horse-state fingerprint to compiler-toolchain.json.
Canonical/editor source text matches; prior source/editor/manifest bytes and
screenshots are backed up. Current installed blob is unchanged and still uses
the old diagnostic. New wrappers have NOT been compiled or installed. A fresh
native cook must validate the generated state class/events before installation;
the artifact-update test requires that new matching CookSnapshot. An attempted
test invocation without that mandatory parameter did not execute its checks.
No live mod, input profile, native horse source or project metadata was changed.
After cooking/installing, restart fully and verify baseline/enable/disable on the
same mounted horse, real horse-handler callbacks and recovery without remount.
Keep Phase 0, live presets and arbitrary customization acceptance pending.

Evidence/staged-source receipt: `work/runtime-probe/horse-handler-observer-20261010-174116-827ee823/`.


### Horse wrapper declaration syntax corrected — 2026-10-10

User compiler screenshot reports bindings.ws line 161: unexpected TOKEN_EVENT,
expecting TOKEN_FUNCTION, near event. The annotation parser requires a function
declaration even when the original state method is declared as an event. Changed
only the two wrapper declaration keywords, OnSpeedPress and OnSpeedHold, from
event to function. Bodies still invoke their original handler once and then
observe it; no listener registration or horse logic was added. Exact failed
source/editor bytes and screenshot are preserved; canonical/editor source
hashes match after correction. Live mod/input remain unchanged. Native class
resolution/linking and successful compilation are still unverified. REDkit was
open during staging; close/reopen the project before cooking to load corrected
source. Keep Witcher 3 closed; report the fresh cook or next compiler error.
Phase 0 remains incomplete.

Evidence: `work/runtime-probe/horse-wrapper-syntax-20261010-174655-c08ac4e6/`.


### Original horse-handler observer cooked and installed — 2026-10-10

Fresh publish 2026-10-10 17-51-01.log compiled 1,525 base scripts and all five
current probe scripts, loaded/reloaded scriptables and completed CompileScripts
without script-phase errors. This validates the generated horse state class,
function wrapper declarations and their calls. Source text and compiler/four
native hook fingerprints match. Frozen cook: build/redkit-cook/20261010-175109-f131aa9c.
Blob: 12,298 bytes; SHA-256 85e1ae02bdc5f0fd33611e1aa087d41775a17e78faa42bd6ff5618fdd23e6a64.
Full log retains 33 outer errors; whole-cook error-free remains false.

Test-UpdateRuntimeProbe.ps1 with this matching CookSnapshot passed in Windows
PowerShell 5.1: stale/corrupt/later-edit refusal, locked-file rollback, backups,
fresh runtime reset and byte-exact uninstall. With Witcher 3 closed, the guarded
updater installed only the three cooked files. All five ownership hashes match;
menu/console and profile were not changed. Exact update backup:
I:\OneDrive\Documents\The Witcher 3\github-project\witcher3-controller-customizer\work\runtime-probe\install-20261010-143310-73d51cc8\updates\artifacts-20261010-175317-f9683707.
All eight personal alias binding multisets still match the installed appendix;
input SHA-256 0c1406973c3f4164a0f6613c53c1c0e2330e3587c1ee1477b49ec0b5f99578f8, desired Preset=1, DiagramProbe=false.

The installed observer now records after original OnSpeedPress/OnSpeedHold
execute once; it never registers/unregisters Canter/Gallop listeners. Status
identifies source=horse handlers. Starts/stops count observation windows only.
Prior competing-observer callback/failure/remount evidence remains nested under
PreviousArtifactObservations and is not attributed to this new blob. Fresh load,
original handler execution, movement, hot switching and disable recovery remain
unverified; broad Phase 0 acceptance stays pending.

Next close REDkit and launch/load Geralt. Mount in a clear area, keep Alt1 and
first verify baseline L3 canter/quick double-press-and-hold gallop; stop/report if
baseline fails. Release A/L3 and enable ccProbeContextMode(true); status should
show source=horse handlers, routing=1, active=1. Close console and open/close
Options with both buttons released. Repeat gestures, release and capture the
full ccProbeRideStatus notification. Disable with ccProbeContextMode(false),
then repeat both gestures on the same mounted horse without dismount/reload.
Report baseline/enabled/disabled behavior and status, including shutdown window
counts. Stop/report startup script errors. No further native cook is needed for
this test; Current/Alt1 switching follows only if the baseline recovery passes.


### Original horse callbacks and Alt1 riding sequence passed — 2026-10-10

User reports "seems everything works fine this time" in response to the requested
baseline/enable/disable canter and quick double-L3-and-hold gallop sequence while
staying mounted. Record this as user-confirmed movement and disable recovery
without remount; no disabled-status screenshot or new stop-count evidence was
supplied. Enabled screenshots identify source=horse handlers, routing=1,
desired=1, active=1, starts/stops=1/0. Callback count grows 0 to 62: Canter edges
22/22, Gallop edges 9/9, pattern callbacks=0, query mismatches=0, other-context
callbacks=0, last=CC_PROBE_Alt1_Horse/Canter/None.

This confirms the current compiled wrappers execute original horse handlers,
then record their native callback/query agreement; last event uses the Alt1
horse alias. Prior events' individual contexts were not retained. Unlike the
earlier competing observer, this implementation makes no native listener calls.
Successful gallop and seamless recovery support the listener-interference
diagnosis; native multi-listener API semantics are not independently established.
Pattern-bearing native events are not required by this tested native gesture.

Next prove both-direction Current/Alt1 switching while mounted, including that
the opposite button no longer emits Canter/Gallop callbacks. Enable the probe,
select Current and close Options with A/L3 released; reset counters and test
A canter/double-press-and-hold, capture status. Reset and test L3 the same way,
capture status. Switch to Alt1 without dismount/reload, reset/test L3 positive,
then reset/test A negative, capturing each status. Expected positive callbacks
under the matching alias with no query mismatches; expected negative speed
callback count zero. Report movement and four screenshots; disable afterward.
Interactions, native subscription lifecycle, Ciri/scripted contexts, held-menu
safety, arbitrary buttons/gestures and diagram acceptance remain separate gates.
Overall Phase 0 remains incomplete. No source, live game or input edits needed.

Evidence: `work/runtime-probe/horse-handler-success-20261010-181704-d8d969f5/runtime-observation.json`.


### Mounted Current/Alt1 speed switching passed — 2026-10-10

User confirms "everything worked" for the requested same-mounted Current/Alt1
positive and opposite-button negative sequence. Three screenshots: Current
positive desired=0, callbacks=20, Canter=6/6, Gallop=4/4, last Current_Horse/Gallop;
Current negative desired=0, all speed callbacks/edges zero and last None;
Alt1 positive desired=1, callbacks=10, Canter=3/3, Gallop=2/2, last Alt1_Horse/Gallop.
All identify source=horse handlers, routing=1, active=1, starts/stops=1/0, zero
query mismatches, pattern and other-context callbacks. This establishes native
callback/query evidence under both aliases and Current's inactive L3 suppression.
Alt1 inactive A test is user-confirmed by the sequence reply; the fourth screenshot
was not provided, so its numerical callback count is unobserved rather than zero.

Geralt mounted speed switching without restart/dismount and canter/gallop on the
chosen A/L3 buttons pass by user report. Mounted interactions are still untested;
the full combined Phase 0 riding criterion stays pending. Next enable the probe,
use an interaction available while mounted under Current with L3, switch to Alt1
and use A, report successful interaction/menu navigation, then disable. Held-menu
input, Ciri/scripted contexts, arbitrary mapping/gesture and diagram gates remain
separate. No source, live mod or input changes are required for this check.

Evidence: `work/runtime-probe/mounted-preset-switch-20261010-182232-a97cfa56/runtime-observation.json`.


### Geralt mounted interaction and normal menu gates passed — 2026-10-10

User replies "both worked without issue" to the mounted Current/L3 and Alt1/A
interaction sequence, which also requested menu-navigation problems. One mounted
interaction under each preset and normal preset-menu navigation are therefore
user-confirmed. Interaction kind and all four individual mounted actions were
not reported/tested separately. Combined with prior speed-switch screenshots and
sequence confirmation, the Phase 0 Geralt mounted canter/gallop/available
interaction gate passes. Repeated settings close/reopen restores the matching
horse aliases observed in native callbacks; normal navigation is user-confirmed.

Held-input menu safety remains separate and pending. Next, mounted and stopped
in clear terrain, enable routing and start Alt1. Reset counters, open Options,
hold A, select Current and close with keyboard/mouse while A stays held for one
second. Release, capture status and report automatic acceleration/interaction.
Reverse from Current with L3 held while choosing Alt1. After each observation,
confirm a fresh speed-button press works; disable afterward. This tests a held
interaction button becoming the new speed button on each menu-close transition.
Ciri/scripted contexts, targeted Ciri marker, arbitrary mapping/changed gesture,
native subscription lifecycle and broader release regressions remain pending.
Overall Phase 0 remains incomplete. No source/game/profile changes are needed.

Evidence: `work/runtime-probe/mounted-interactions-20261010-182614-eaa8d58f/runtime-observation.json`.


### Held-menu observation; preset-only continuation — 2026-10-10

User reports "didnt notice issue" for the requested held A/L3 menu-switch
sequence. Two supplied status screenshots both show routing=1, desired=1,
source=horse handlers, active=1, observation windows=3/2, and zero callbacks,
Canter/Gallop edges, pattern callbacks, query mismatches and other-context
callbacks; last=None/None/None. They support zero observed speed events but do
not independently identify both transition legs: neither shows desired=0.
Fresh-press success and final routing disable were not explicitly reported.
Observation windows are not native listener counts. Record no visible issue
by user report; full held-input/focus/disconnect acceptance remains pending.

User has no Ciri save available. Ciri diagram marker and riding verification
remain untested; no save is created or changed to bypass that gate. Proceed with
the plan's preset-only Release 1 allowance using the proven Geralt backend,
while Ciri regressions and arbitrary button/gesture customization stay open.
The installed scripts, game files and personal input/profile were unchanged.

Evidence: `work/runtime-probe/held-menu-20261011-013258Z-b46bbffc/runtime-observation.json`.
