> Current Phase 1 evidence: [phase1-evidence.md](phase1-evidence.md). Older probe snapshots below are historical; full runtime/manual release gates remain open.

# Build and prerequisites

Target plan baseline: Remaster 5.00c, input format 60. Scripts are authored in UTF-8. Golden fixtures retain original bytes.

## Discovery

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Prerequisites.ps1 -GamePath 'F:\Steam\steamapps\common\The Witcher 3' -RedkitPath 'H:\SteamLibrary\steamapps\common\The Witcher 3 REDkit'
```

`-RedkitPath` is optional; configured Steam libraries are discovered from the Steam registry and `libraryfolders.vdf`. `WITCHER3_REDKIT_HOME` supplies an explicit toolkit path. `-SteamLibraryPaths` accepts additional library roots. The script reads only; it never launches an executable, modifies the game, changes Steam, installs prerequisites or alters compatibility fingerprints.

`-RequireReady` fails until the full runtime gate is satisfied. This discovery-only command does not consume build reports; its CompilerInvocationVerified=false is not an audit of the separately verified build. Reported candidates are locations to inspect, not assertions of a working compiler. A binary version does not prove compatibility with this game's scripts.

## Verified compiler invocation — 2026-10-10

Steam completed REDkit build 25773188 at 09:48:03 America/Los_Angeles. Installed root: `H:\SteamLibrary\steamapps\common\The Witcher 3 REDkit`. Compiler `bin/x64_RedKit/wcc_lite.exe`: 150,762,960 bytes, SHA-256 `9f448e0c8b9ea1ea803d0ae543f2fcd6e905088b8b71f54da2bff22c6cf318fc`. Its Windows version fields are empty. `tools/compiler-toolchain.json` pins the inspected compiler and three hook-source fingerprints; it does not replace the historical runtime compatibility manifest.

The user reviewed the first-run EULA and reported acceptance. The initial scratch-directory help attempt then exited 3 because the compiler could not find its configuration. Running from REDkit's `bin/x64_RedKit` fixes configuration discovery. No-argument help and `help compilescripts` both exited 0. Actual help:

```text
compilescripts <source_dir> <options>
-out=<outputpath>          - Output path
-patch=<patch_source_dir>  - Blob source scripts (output will be a .rsblob)
```

`-out` takes a directory and creates `blob.rsblob` inside it. Reproduce the verified build from this repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Mod.ps1 -RedkitPath 'H:\SteamLibrary\steamapps\common\The Witcher 3 REDkit'
```

The wrapper runs this argument array from REDkit's `bin/x64_RedKit` (the concrete paths are retained in each report):

```text
compilescripts
H:\SteamLibrary\steamapps\common\The Witcher 3 REDkit\r4data\scripts
-patch=<new-build-directory>\scripts
-out=<new-build-directory>\compiled
```

It refuses an uninspected compiler or changed hook source before execution/output creation, snapshots the authored sources in a fresh directory, and records source/output hashes, arguments, exit code and logs in `build.json`. A successful result requires an actual commandlet start, exit 0, the save-success marker, no errors after commandlet start, and a newly created nonempty blob. Startup diagnostics are preserved separately from compilation errors. Runtime loading is always recorded as unverified.

Latest verified build: `build/20261010-102226-0b3ab860/build.json`; exit 0, 1,525 base scripts and five patch files parsed, **4,184-byte** `compiled/blob.rsblob`. SHA-256: `269be1e137968c37095ab1d8368577689cf466c91bfe730183e12700290f415e`. There were no errors after compilation began. Missing legacy overrides/mods.settings, depot-path and sound-bank diagnostics appeared during engine initialization; this is not a clean-runtime claim.

The initial protected sender wrapper failed parsing. The corrected bare global `@wrapMethod` creator wrappers for Geralt/Ciri, and the native context method wrappers, compiled successfully. A copied source root named `patch` produced source-link assertions despite native exit 0. Preserve the snapshot root name `scripts`, as tested. Run `20261010-101243-b89bd25f` was initially reported successful by an earlier, insufficient guard; it is **disqualified** due to those assertions. Run `20261010-101629-59893562` correctly failed that guard. Use the latest verified report above; do not select an old blob merely by existence or native exit code.

`verification/Test-BuildMod.ps1` passed under Windows PowerShell 5.1: an unverified binary is rejected without execution, output creation or candidate mutation.

### Native initialization side effects

REDkit initializes the real redirected Witcher Documents directory even for compiler help/build commands. It created `editoruser.settings`; a trial `-userDirectory=<scratch-profile>` did not isolate that initialization. Do not describe the compiler as sandboxed from personal configuration.

The live `input.settings` hash changed during this session from `e0e026b64d3253f1d785ece9637cb05f98137bc4419eda706bbb4742bf038d4e` to `9ccfb04155744fd624d850ed858fa987d33c3a4ab00d9a8473525cfbf3b0886c`, with observed last-write 10:10:36 America/Los_Angeles and unchanged size 111,078 bytes. The writer and semantic delta are not established. No project script wrote this file, and it was not overwritten or restored from a golden fixture. The later builds left that observed hash stable. `user.settings` remains `605e1bd8e3ce235d7a7c1d11d6de3ffae186551b91362997a9781539d4660d6b`. No mod install, input-context addition, legacy migration or save write was performed.

## Package and load status

Compilation establishes syntax/linkage, not the engine's loader placement. A local three-file editor output and temporary runtime-probe installation tools now exist; see the inspection/retry record below. The release installer remains unimplemented. The loose-source layout proposed in the plan is `mods/modControllerCustomizer/content/scripts/local/controllerCustomizer/`. The editor's cooked output placement is now observed at mods/modCustomizeControllerScheme/content/precompiled.rsblob. Actual game loading remains unverified; the output layout is recorded below.

The [Remaster modding guide](https://mod.io/g/the-witcher-3/r/what-does-the-remaster-mean-for-modding), now readable through search, confirms that native wrapping requires REDkit precompilation and that REDkit cooking creates `precompiled.rsblob`. It also describes precedence over loose scripts affecting the same function. It does not establish the output layout of this commandlet. Next establish the REDkit cooking/package layout with this five-file probe, then inspect the generated payload and capture a real game load log. The verified five-script handoff and required editor steps are in [redkit-probe.md](redkit-probe.md); the supplied project is F:\projects\TheWitcher3\customizecontrollerscheme, its five-file workspace is hash-verified, and local cooking/export is pending because this session has no desktop-control tool. Keep ContextProbe false until startup registration is proven. Record exact loader paths in this document only after observing them.

Menu XML discovery, neither-present renderer file-list handling, native/loose-script interaction, context registration and diagram refresh all remain runtime checks. Live installation must include a reviewed payload and reversible handling of the legacy override and modified personal input. See `manual-acceptance.md`; no runtime case is marked passed.

## Fixed-context experiment

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Generate-ContextProbe.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Generate-ContextProbe.ps1 -Check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verification\Test-ContextProbe.ps1
```

Generation writes only `work/context-probe/{Current,Alt1}.input-contexts.ini`, with source hashes and experimental warnings. Each appendix renames the four golden context headers and retains every other record and duplicate. These are data to investigate startup registration, not whole-file install payloads or a tested inheritance implementation. Do not automatically append them to native or personal input files. The golden keyboard/axis records describe the recorded baseline, not arbitrary later user edits.

`ContextProbe=false` disables routing. Enabling it in a development configuration is valid only after context loading is proven: otherwise native selection may request a nonexistent context. The adapter wraps native Get/Set/Store/RestoreContext, so matching native compilation and compiled/loose-script interaction tests are mandatory. It canonicalizes getter names because `CBTTaskPlayerActionDecorator` compares the literal ScriptedAction context each frame. The raw-name cache is a plain unsaved scalar; actual save/restart behavior remains untested. ForceDeactivateAction and IsInputIgnored instrumentation require runtime evidence of held-button suppression and callback balance.

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
