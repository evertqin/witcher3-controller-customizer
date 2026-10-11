# Local editor probe handoff

The current five-file probe, including ccProbeLoaded, compiled through the local REDkit editor and its cooked output is installed for a temporary runtime test. Standalone startup retries remain unresolved. There is no desktop-control tool in this session, so editor setup/cooking requires user interaction. This handoff does not mark runtime acceptance complete.

## Prepared input

`work/redkit-handoff/20261010-102226-0b3ab860/workspace/scripts/local/controllerCustomizer/` contains only the five authored scripts, copied from the successful build snapshot and verified against its PatchSha256 entries. `handoff.json` records their hashes and the original build report. No bundled base scripts, personal settings, input appendices or existing mod files are included.

The menu XML stays at `src/menu/modControllerCustomizer.xml`; its discovery mechanism remains unverified. ContextProbe and DiagramProbe default false. Start by establishing blob packaging/loading before enabling either experiment.

## Editor steps

1. Open REDkit through Steam and complete the editor's first-time game/depot setup if prompted. Use the installed game at `F:\Steam\steamapps\common\The Witcher 3`. The official setup guide describes depot generation and local project creation; a compiler EULA acceptance alone does not prove editor setup is complete.
2. Create a separate local project named `ControllerCustomizerProbe`, and provide its folder path. The prepared five-file subtree will be copied into its `workspace/scripts/local/controllerCustomizer/`, with refusal if that destination already exists. The rest of its workspace stays intact.
3. Use REDkit's local cooking workflow, described under Publish > Save and publish mod project > Time to cook. Keep this a local test: use the local ZIP export to inspect the cooked package. Publishing to a storefront is outside this task.
4. Retain the cooking log and generated `packed/` or exported package. Inspect where REDkit put `precompiled.rsblob`, confirm it contains this probe, and record the layout rather than inferring it from the standalone output name. A script-only payload should not contain copied vanilla scripts.
5. Prepare a reversible installation using that observed layout and the acceptance procedure in `manual-acceptance.md`. Record treatment of the existing legacy diagram override before installation. Real game startup, menu, controller and diagram observations remain required.

The official [editor setup guide](https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/6324341/Starting+the+Editor) identifies the workspace and publish directories. The [local cooking/export guide](https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/6328254/Publishing+mods) describes the packed output and local ZIP export. The [first script mod guide](https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/36241465/WS+Create+your+first+script+mod) documents the mod/content/scripts/local source layout. These guides do not prove this probe's cooked loader path or runtime behavior.

## Supplied project — 2026-10-10

User supplied `F:\projects\TheWitcher3\customizecontrollerscheme`. Inspected `customizecontrollerscheme.w3edit`: name CustomizeControllerScheme, useLooseScripts=false, succesfullyCooked=false, and empty publishing metadata. Copied only the five authored scripts into `workspace/scripts/local/controllerCustomizer/`; all hashes match the standalone build snapshot. The project file was unchanged. Receipt: `work/redkit-handoff/20261010-102226-0b3ab860/editor-project.json`, with project-file hash 879a1e7391fb301624ec5e724e214295adb2d82717e58d5ea8f5dad01d10ec53.

Open the existing project and continue at local cooking/export (steps 3–4 above). If the editor requires basic metadata, describe this as a Phase 0 controller probe with runtime behavior unverified. Capture any setup/cooking error before changing sources. The cooking result was subsequently inspected as recorded below; game installation and runtime acceptance remain pending.

## Cooking inspected

The editor emitted packed/mods/modCustomizeControllerScheme/content/{precompiled.rsblob,info.json,metadata.store}. Frozen snapshot: build/redkit-cook/20261010-124540-c21c80e8. The script phase succeeded, while 33 diagnostics occurred elsewhere in the log; see build.md. No ZIP was found or needed for inspection. The workspace now also includes a read-only ccProbeLoaded notification awaiting compilation after editor closure. Runtime installation has not run.


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
