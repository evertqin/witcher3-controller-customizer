> Current Phase 1 evidence: [phase1-evidence.md](phase1-evidence.md). Older probe snapshots below are historical; full runtime/manual release gates remain open.

# Implementation status

Resumed 2026-10-11. Six-script cook installed and loaded; automated Alt1 native callbacks verified. Computer-use tooling added; menus/assertions need further integration. Ciri and arbitrary customization remain untested.

## Phase 0 tracker

- [x] Establish the separate project, source exclusions and byte-preserving fixture attributes.
- [x] Copy owned input fixtures and manifest with provenance.
- [x] Verify exact hashes and four-context/12-record difference in Windows PowerShell 5.1.
- [x] Verify lossless ordered records, duplicates and rejection of unrelated changes.
- [x] Implement read-only prerequisite discovery and strict refusal of unverified readiness.
- [x] Trace native riding queries, callbacks, menu restoration and diagram rows.
- [x] Generate and verify eight experimental fixed contexts from the golden records, without installing them.
- [x] Monitor REDkit installation to successful completion and record the installed compiler hash and matching hook-source hashes.
- [x] Inspect compiler help after user EULA acceptance and establish the matching invocation.
- [x] Record successful native compilation and a hashed script blob through Build-Mod.ps1.
- [x] Verify compiler refusal before execution/output creation under Windows PowerShell 5.1.
- [x] Prepare and hash-verify the five-script editor handoff; document local cooking steps in redkit-probe.md.
- [x] Copy the five verified sources into the supplied REDkit workspace, preserving .w3edit metadata and useLooseScripts=false.
- [x] Observe and snapshot the cooked output layout and successful five-file script phase; preserve full cooking diagnostics.
- [x] Verify rollback ownership checks and refusal to install a failed build in Windows PowerShell 5.1.
- [x] Compile the added visible load-confirmation command through the verified fresh editor cook.
- [x] Verify stale-cook/blob refusal and installation/restoration on a temporary game tree.
- [x] Install the temporary cooked load probe with exact backups and journal.
- [x] Confirm compiled probe execution through user-observed ccProbeLoaded notification.
- [x] Confirm corrected Gameplay selector and desired Alt1 persistence after first menu-title failure.
- [x] Verify personal-context generation, refusal and exact input rollback on temporary files.
- [x] Compile and install new context/diagram diagnostic commands.
- [x] Verify guarded artifact updates and locked-file rollback in Windows PowerShell 5.1.
- [x] Install current personal input aliases with a separate rollback journal.
- [x] Confirm current installed compiled command executes.
- [x] Confirm transient routing opt-in and observer start through immediate status screenshot.
- [x] Observe native speed callbacks with balanced edges and query agreement; last callback uses Alt1 horse alias.
- [x] Confirm observer disable and balanced start/stop (1/1); enabled canter movement works.
- [x] Verify all eight alias names versus an unregistered control; single-key metadata assumption discarded.
- [x] Confirm Geralt horseback marker on/off in Controls.
- [x] Confirm original horse handler dispatch/query agreement and Geralt Alt1 baseline/enable/disable riding sequence.
- [ ] Confirm Ciri horseback marker and native riding/query/callback behavior.
- [x] Confirm selector persistence, normal preset-menu navigation and matching horse context after repeated menu close/reopen.
- [ ] Verify held-button menu-close safety.
- [x] Prove Geralt Horse Current/Alt1 live speed switching and opposite speed-button suppression (Alt1 negative by user report).
- [x] Verify an available Geralt mounted interaction under Current/L3 and Alt1/A.
- [ ] Verify Ciri/ScriptedAction context behavior.
- [ ] Prove an arbitrary mapping and changed gesture through both queries and callbacks.
- [ ] Prove the opt-in targeted diagram marker for Geralt/Ciri.
- [ ] Complete the Phase 0 runtime acceptance gate.

Current cook: `build/redkit-cook/20261010-175109-f131aa9c/cook.json`, 12,298-byte blob; script compilation and updater verification passed. Full log retains 33 outer cooking errors. Original horse callbacks are wrapped after native execution without adding listeners. Current Alt1 riding sequence and original handler dispatch now confirmed; prior competing-observer observations apply to the preceding artifact.

See `runtime-feasibility.md` for observed compatibility changes. Keep the canonical plan and this tracker synchronized when evidence changes.

See runtime-probe.md for the installed probe, required manual observations and exact rollback command.

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

### Diagnostic wrapper compilation failure and correction — 2026-10-10

User reported warnings and a wrappedMethod compilation error while reopening the
updated project. REDkit bin/editor.log confirms two failed editor initialization
attempts at 15:09:49 and 15:13:13: local/controllerCustomizer/contextAdapter.ws[79],
Could not find function 'wrappedMethod'. No new publish log was generated.
The SetContext wrapper introduced two wrappedMethod call sites in separate branches;
the compiler rejected the second call site. Changed only that wrapper to choose
resolvedContext first and invoke wrappedMethod(resolvedContext) once. Normal routing
and the synchronous registration-inspection bypass retain their intended paths.

The failed editor log contains 362 unique script warnings, the same set after
normalizing virtual source-path case as the successful 14:28:44 cook. This identifies the newly
blocking script error without classifying every other editor diagnostic as benign.
Failed sources, prior handoff and full log are preserved in
work/runtime-probe/wrapper-failure-20261010-151654.

Corrected canonical/editor sources are text-equivalent; the SetContext body has
one wrappedMethod call site. Updated source hashes and failure evidence are in
work/runtime-probe/context-handoff.json. These are static/source checks; fresh
native compilation is still required. The installed compiled blob was not changed,
no input contexts were installed, and the legacy diagram mod remains isolated.
Overall Phase 0 and all gameplay/diagram acceptance gates remain pending.


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


### Preset catalog and horseback diagram sources staged — 2026-10-10

Under the plan's preset-only allowance, added a versioned four-context/seven-action,
twelve-delta catalog, immutable Current/Alt1 definitions referencing the exact full
golden profiles, and a compatibility record linked to the verified compiler/four
native hook hashes. No historical compatibility fingerprint was changed. This is
the preset-delta inventory, not a completed arbitrary gameplay action inventory.

Generate-Assets.ps1 validates IDs, fixture provenance, exact native record/timing
semantics and diagram/runtime agreement before writing deterministic runtime and
diagram JSON, lossless golden context references and presetData.ws. Compiler
preflight checks generated freshness. Generated contexts remain offline references;
personal input installation still uses the tested personal-context preservation
path. Context adapter now delegates its existing alias tables to generated helpers;
transient opt-in, release, original horse handlers and restore lifecycle stay the
same. No extra listener or automatic routing activation was introduced.

Targeted diagram wrappers retain the marker and, while routing is opted in, preview
the selected horseback A/L3 canter/gallop and Geralt interaction labels with a preset
name. They preserve native creator calls and unrelated rows/fields; Ciri gets no
Geralt-only interactions. Labels use traced native localization keys. Common Souls
diagram fields, automatic bootstrap, dedicated menu, installer integration and
broader Release 1 regressions remain pending. Ciri is untested: no save available.

Passed in Windows PowerShell 5.1: Generate-Assets.ps1 and -Check,
Test-GeneratedAssets.ps1, Test-Presets.ps1, Test-BuildMod.ps1. Evidence covers
determinism, unchanged ordered golden sections/duplicates/axes/keyboard, twelve
deltas and timing, diagram/runtime agreement, unknown action/context/gesture/button
refusal without output mutation, altered timing/wrong preset refusal, stale output
refusal and compiler refusal before execution. Native syntax/linkage and in-game
labels are NOT verified for these staged sources.

Six canonical/editor source texts match. The installed five-script artifact is
unchanged; prior runtime evidence applies only to its recorded 85e1ae02... blob.
Fresh REDkit GUI cooking is required before artifact update and diagram testing.
The cook snapshot helper now requires an explicit log and derives the expected
patch count from the exact current source inventory, rather than assuming five.
No game, personal settings, save or legacy-isolation file was changed.

Staging receipt: `work/runtime-probe/catalog-diagrams-20261011-014029Z-01aa89ca/stage.json`.

Handoff: `I:\OneDrive\projects\AIAssets\thoughts\shared\handoffs\evertqin--witcher3-controller-customizer\2026-10-10-18-46-03-controller-customizer-preset-cook-pause.md`. No fresh six-script cook or installation performed.


### Computer-use automation continuation — 2026-10-11

Resumed at user request. Added tools/automation: native REDkit control driver,
validated cook snapshots, guarded console replay, persistent ViGEm controller,
game-only DX12 screenshots, fresh-log command runner and 13 passing refusal/
freshness checks. The complete loaded-project REDkit driver passed and produced
a six-script 14,206-byte cook, SHA e4ea77b511bf4c8f486e675c2adf5880edea45409eded6780c422c574af53aba,
with zero script-phase errors and 15 outer diagnostics. Cold opening exercised
Browse/Open but initial short readiness timeout failed; longer waits remain
unverified on a complete cold run. Standalone startup remains unresolved.

After detecting a missing probe/restored legacy mod, the user manually restored
the test setup. All five ownership hashes then matched and the game closed.
The existing guarded updater installed the preceding verified six-script cook
b8f05ac422e139644b8dcc88b7f48b0b85d26c6a074f9693e39e9354eb30d576 with exact backups;
menu/console retained their hashes. The latest e4ea77b5 cook is not installed.

Launched DX12 and continued into the user's latest mounted Keira Metz quest
save. Agent-observed notifications establish fresh probe execution, Horse
context, 8/8 recognized alias names and rejected missing-name control. Synthetic
keyboard input required scan codes, longer presses and modifier settling;
HWND game capture returned black, while foreground desktop-region capture works.

Virtual L3 hold/double-hold produced 10 original horse-handler callbacks,
Canter edges 3/3, Gallop edges 2/2, zero query mismatches. Before a Settings
cycle, last context was native Horse; after the normal cycle it was
CC_PROBE_Alt1_Horse. Thus the first run is baseline evidence only. Screenshots
and machine-readable observations retain installed artifact hashes and distinct
scope. Routing disable command was delivered and virtual controller detached;
no save command was issued. Menus still need visual supervision, exact save-list
selection and automatic gameplay assertions remain incomplete. Ciri, Current/A
automation, diagrams, full gait classification and broader regressions remain
open. Phase 1/2 release gates are not completed.

Evidence: tools/automation/README.md; external bundle runtime-observation-oct11.json;
editor driver result 20261011T142315Z-2399c3c0;
alias result 20261011T142337Z-90b77845;
routed ride result 20261011T142717Z-61136bd5.


Automatic callback checks added: Windows OCR reads captured notifications;
strict assertions require nonzero horse-handler callbacks, positive/balanced
Canter/Gallop edges, matching totals, zero query mismatches and the expected
alias. The real routed screenshot passes; baseline/unreadable evidence refuses.
Fourteen automated checks pass. The live replay was run before OCR integration;
OCR was then verified against its actual captured evidence. Full unattended
replay after OCR integration, Current/A execution and gait classification remain
pending. Added an unexecuted Current/A scenario alongside tested Alt1/L3.


Final cleanup observation: routing=0, active=0, observation windows 2/2;
callback counters retained. The supplied save retains SHA-256
1b32a68488aa519fc7a9924d957029cf17de5ed32a49a1edd03f16c758d0c77d.
Escape did not reliably display the pause menu after shutdown; input calibration
versus runtime restoration remains unresolved. No menu safety acceptance is
inferred. Correct the earlier planned paused-final-state note: the task-launched
game was gracefully closed via its native window, no save command issued;
REDkit remains open for inspection. The user-visible bundle includes all run
receipts and screenshots. No commits, publication or unrelated changes occurred.


Automation continuation, October 11: complete connected cook/install/game replay
verified: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\witcher-loop\evidence\development\20261011T151442Z-a8acb5e9\result.json
Cold REDkit startup/open/cook also passed independently in 37 seconds at
evidence/editor/20261011T145146Z-d21d16be/result.json. Completed cook wizards now
close after evidence freezes; editor remains open. The updater uses a local
Windows PowerShell module path to avoid inherited PowerShell 7 modules.
The connected run installed blob 79f326d76dc8f4d3ef4c5627b77c9b0237dd8da0eaa44a7c38f11c01475ab974 through the
existing ownership-checked updater with backups; script compilation has zero
errors, while outer cook diagnostics remain in the receipt.
Fresh game startup skips only recognized intro prompts, scans highlighted save
rows, recognizes the exact October 11 07:10:06 manual fixture and its selection
border, waits for the quest HUD, replays Current/A plus a checked Settings cycle,
and closes only its owned game process. Save hash remains unchanged. Current/A
produced 10 callbacks, balanced Canter 3/3 and Gallop 2/2, zero query mismatches,
last CC_PROBE_Current_Horse. Sixteen automated checks pass. OCR captures use
explicit UTF-8; menu-only crops avoid background/notification recognition errors.
Earlier Continue-based runs loaded a newer autosave; do not equate them with the
exact supplied manual fixture. The later direct and connected Current tests do
use the exact fixture. Selection calibration is limited to 2560x1440 English,
first eleven visible save rows; ambiguous/missing evidence stops before loading.
Pause navigation still fails after routing shutdown/controller detachment;
each automated test therefore uses a fresh game process. This runtime issue,
Alt1 end-to-end replay with the new driver, gait/diagram/Ciri acceptance and
broader regressions remain open. No release-wide gameplay claim or release gate
completion is inferred. Current remains selected in the user's settings.
