# Phase 1.1: vanilla and full DarkSoul presets

User decision, October 11, 2026: **Current (original) means vanilla Witcher 3
controls**, followed by **DarkSoul** and **DarkSoul Alt1**. DarkSoul Alt1 is the
user's main scheme. Implement Phase 1.1 before continuing the arbitrary editor.

| Display name | Stable identity | Source and behavior |
| --- | --- | --- |
| Current (original) | `vanilla` | Matching installed native controller defaults, across gameplay contexts; native diagrams |
| DarkSoul | `darksoul` | Full pinned legacy `Current` scheme; A riding speed, L3 mounted interactions |
| DarkSoul Alt1 | `darksoul-alt1` | Full pinned legacy `Alt1` scheme; L3 riding speed, A mounted interactions |

Do not relabel the existing Phase 1 `Current` as vanilla: it is already Souls-based.
The accepted two-preset Phase 1 artifact remains the rollback baseline.

## Evidence and implications

- `data/actions.json:2` limits the current catalog to twelve preset deltas.
- `tools/Install-Mod.ps1:58` requires preexisting shared Souls bindings;
  `:98` installs eight aliases for only four contexts. Thus the current installer
  neither ports the full scheme onto vanilla nor implements a vanilla preset.
- `src/scripts/local/controllerCustomizer/diagram.ws:68` applies the shared Souls
  permutation. Vanilla must bypass both shared and horseback transformations.
- The pinned legacy input fixtures each contain 48 sections and 1,295 controller/
  pattern records across 41 contexts, including duplicate records and non-gameplay
  contexts. These are inventory counts, not 1,295 changed actions to remap.
- DarkSoul and DarkSoul Alt1 differ by twelve records across the four recorded
  riding contexts; their other controller behavior remains shared.
- Both legacy diagram sources match the historical manifest and each contains
  311 text-field assignments across native branches. Port their semantic changes
  while retaining current native branches; do not redistribute whole native scripts.
- Matching native `input_qwerty.ini` has 136 inheritance records. Resolve actual
  effective bindings/inheritance before comparing flat legacy records; comparing
  identically named sections alone is insufficient.

Inventory receipt: `docs/phase11-inventory.json`; source revision
`5f84ee7d3a5adc93ecd17e6003ba5868044d9fbb`. Native sources remain local inspection
inputs and are not copied into the repository.

## Implementation changes

1. **Complete controller inventory and three immutable presets.** Extend
   `data/actions.json`, `data/presets/*`, `data/compatibility.json` and
   `tools/Generate-Assets.ps1`. Add a versioned vanilla definition tied to the
   inspected native build and explicitly named DarkSoul profiles referencing the
   unchanged historical fixtures. Inventory all legacy gameplay controller deltas:
   combat, exploration, interactions, Signs/items, D-pad, riding, Ciri, boat,
   swim/dive and relevant scripted states. Account for inherited/pattern records,
   timing, meaningful duplicates and native context exceptions. Reconcile native
   build differences explicitly rather than copying older bindings wholesale.

2. **Whole-scheme context selection.** Extend `contexts.ws`, `contextAdapter.ws`,
   `bootstrap.ws`, generated preset data and personal-context generation. Generate
   three owned variants wherever gameplay bindings differ. Canonical context names
   and normal store/restore behavior must remain correct across transitions. Keep
   native menu/recovery contexts intact unless an actual legacy delta requires a
   specifically traced equivalent. Preserve personal keyboard/mouse/axes and
   unrelated records. Vanilla needs explicit native controller bindings: disabling
   routing would expose the user's existing Souls-modified base contexts.

3. **Three matching diagrams and menu choices.** Extend `diagram.ws`,
   `menuHooks.ws` and `src/menu/modControllerCustomizer.xml`. Show Current
   (original), DarkSoul and DarkSoul Alt1. Vanilla returns native controller rows;
   both DarkSoul options port the full legacy shared and contextual labels,
   including Geralt/Ciri and native quick-sign/display branches. Derive titles,
   effective mappings and labels from one selected preset. Refresh on reopening
   Controls and after selection using the verified native menu lifecycle.

4. **Explicit configuration migration.** Extend `config.ws`, install/update
   transactions and metadata with a versioned three-scheme identity. Detect the
   previous installed schema from its journal/config before replacing the menu.
   Old `Preset=0` maps to DarkSoul; old `Preset=1` maps to DarkSoul Alt1. Never
   silently reinterpret old zero as vanilla. Use a distinct versioned selection
   field or proven schema migration; distinguish missing configuration from an
   existing legacy selection. Preserve the selected behavior on upgrades.
   Recommend DarkSoul Alt1 for a fresh installation, reflecting the user's stated
   preference; explicit user choices always prevail. Invalid selection retains
   the last valid complete scheme. Keep caches out of save serialization.

5. **Installation from vanilla or legacy profiles.** Extend `Install-Mod.ps1`,
   `Update-Mod.ps1`, `Restore-Backup.ps1`, context modules and journal inventory.
   Remove the assumption that shared Souls slots are already installed. Apply only
   identified owned controller records/aliases; never overwrite the whole personal
   input file with a fixture. Native-default and known legacy inputs are supported
   entry points. Preserve independent edits where compatible; refuse ambiguous
   conflicting owned records before mutation. Migrate the separate development
   journals explicitly with verified backups; do not feed their schema into the
   standalone updater. Preserve known legacy isolation, original uninstall bytes,
   unrelated mods and later unrelated personal edits.

6. **Verification and handoff.** Extend existing preset/generator/context/installer
   checks for all three schemes, complete controller semantics, migration and
   rollback. Adapt automation fixtures/menu assertions and default smoke scenario
   to the three-choice names. Update README, compatibility and runbook evidence.
   Preserve Phase 2 draft code; extend its catalog assumptions after Phase 1.1's
   inventory stabilizes. Full fixed presets still do not prove arbitrary rebinding.

## Proportionate automated acceptance

- Offline: exact legacy fingerprints, complete effective controller multiset and
  timing equivalence, unchanged personal keyboard/axes/menu records, deterministic
  generation, incompatible-input refusal, migration and owned-only rollback.
- Cook: fresh matching authored/editor sources and required native hooks; zero
  script-phase errors, with outer diagnostics retained.
- Game: one three-choice cycle Current → DarkSoul → DarkSoul Alt1 → Current;
  one representative shared gameplay binding per scheme and the riding difference,
  matching native Controls screenshots, then return to DarkSoul Alt1. Add only a
  targeted negative old-button/transition case when needed to establish isolation.
- Evidence: selected stable identity, raw/canonical context, native queries and
  original callbacks where observable, screenshots, artifact/source hashes,
  pinned-save integrity and owned-process cleanup.

Use available native scripting/UI automation and ViGEm. No ten-switch quota or
new manual sign-off. The previous manual waivers remain effective; new complete
scheme behavior still needs proportionate engineering evidence before it is
reported as implemented. Do not label unexecuted coverage passed.

## Phase ordering

Accepted Phase 1 → **Phase 1.1 full three-preset port** → Phase 2 arbitrary
button/gesture backend and in-game editor. Phase 2's draft model remains preserved;
its runtime backend work resumes after Phase 1.1's complete catalog and selection
contract are established. That scope revision itself changed no runtime files; subsequent runtime progress is recorded below.

## Implementation progress — October 11, 2026

Implemented `data/schemes/manifest.json` and
`tools/automation/full_schemes.py`: three source-pinned stable identities,
selection migration preserving old 0→DarkSoul and 1→DarkSoul Alt1, inheritance
lineage validation with cycle/missing-parent refusal, duplicate-sensitive semantic
comparison, and complete personal alias appendix generation.

The actual pinned native/legacy sources contain 48 contexts; their inherited
controller/pattern inventories have 1,297 vanilla and 1,295 records in each legacy
scheme. Preparing all three schemes requires 28 changed contexts
and 84 aliases, rather than the old four contexts/eight aliases.
Each alias gets the complete selected digital-pad binding multiset while retaining
the personal context's keyboard/mouse, axes, patterns, other device records and
comments. Base personal bytes and existing probe aliases remain untouched.
Independent controller edits and non-digital source deltas refuse for reconciliation.

Four targeted tests pass: duplicate/inheritance semantics, invalid-graph refusal,
versioned selection migration, and full-appendix preservation/refusal. Inventory
freshness and an actual personal-profile preparation passed. Receipt:
`C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase1\full-scheme-preparation.json`.
Appendix prepared at `C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase1\full-scheme-appendix-preserved.ini`; **not installed**. Native inheritance precedence
is explicitly not inferred merely from the source-lineage comparison. Next integrate
versioned configuration/menu, generated context routing/bootstrap and guarded
ownership migration, then cook and run one three-choice game cycle.

```powershell
# From repository root; output files must be new.
python tools/automation/full_schemes.py --native-input <native-input_qwerty.ini> --output <new-inventory.json>
python tools/automation/full_schemes.py --native-input <native-input_qwerty.ini> --personal-input <personal-input.settings> --output <new-appendix.ini>
python -m unittest discover -s tools/automation -p test_full_schemes.py
```

## Runtime integration — October 11, 2026

Phase 1.1 is now compiled and installed in the owned development setup. Canonical
eight-source output matches the frozen cook; the accepted Phase 1 artifact remains
available through rollback backups. Generated routing covers 28 gameplay contexts,
84 aliases and three selection slots: 0 vanilla, 1 DarkSoul, 2 DarkSoul Alt1.
Canonical getters still return native names; bootstrap checks every alias before
enabling routing. Changed digital actions are released per current context;
this does not claim held-button gameplay suppression.

The distinct native `Scheme` setting avoids reinterpreting legacy `Preset`.
Actual DX12 startup migrated stored `Preset=0` to `Scheme=1` (DarkSoul), before
the replay selected anything. Missing configuration defaults to preferred Alt1;
unknown values retain the last valid runtime selection. The hidden old Preset
field remains registered for migration. Vanilla bypasses both diagram transforms.

`scheme_runtime.py` generates canonical scripts/menu from fingerprint-pinned
project-owned templates; these contain no redistributed native scripts. Run
`Generate-Assets.ps1 -Check -NativeInputPath <native-input_qwerty.ini> -PythonPath
<python>` under Windows PowerShell 5.1. Existing twelve-delta fixtures/assets remain
historical inputs; their correctness is checked alongside the full runtime.

Fresh REDkit cook: 31,077 bytes, SHA-256
`7807aed6ef54582160d72a6e27d4bfacfa181c5e3f1cd10beaf6338da40b6cca`.
Script phase passed; 19 outer packaging diagnostics remain. Snapshot:
`C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an/outputs/phase11/editor/cooks/20261011-152223-f577b26a`.

`Install-FullSchemeCandidate.ps1` explicitly migrates the active development
journal in one six-target transaction: three compiled files, menu, personal alias
appendix and the existing runtime journal. It preserves original input bytes
before launch, all old probe aliases, console configuration and legacy isolation.
Changed-input refusal, complete ownership hashes, repeated-migration refusal and
rollback passed in isolated fixtures. `Restore-FullSchemeCandidate.ps1` also
supports semantic alias removal after engine serialization, preserving later
personal edits. Live migration backups:
`C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an/work/phase11/live-migration/files.json`.

The standalone Phase 1 installer/updater/packager explicitly refuse schema 2;
they must not install eight aliases underneath an 84-alias runtime. Extending
standalone delivery remains unfinished. The historical Phase 1 package is unchanged.

The runner now recognizes all three captions, verifies each single menu step,
waits for full menu visibility before navigation, supports native controller pause
for stationary menu-only scenarios, and picks the default smoke by installed
journal schema. Twenty-five Python adapter/backend/ownership checks pass.

Native riding evidence exists for all three schemes: exactly 10 callbacks,
Canter 3/3, Gallop 2/2, zero native query mismatches. Vanilla and DarkSoul assertions
passed in the first replay. Alt1 counters were captured in a later failed replay;
a separate supplement verified the saved frame after fixing context OCR spacing.
Original failed receipts remain failed. Supplemental receipt:
`C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an/work/phase11/alt1-callback-supplement.json`.
All completed replay processes closed; the pinned 11:15:54 save stayed unchanged.

**Open native serialization issue:** the engine added `Reprocess` to eight vanilla
Focus records and removed the two vanilla HorseKick pad records lacking explicit
State. Native HorseKick handlers exist; do not infer that kicks are unsupported.
These nine alias changes were captured separately and checked against the exact
investigated delta; subsequent ownership checks use the frozen registered alias
multisets. This establishes ownership, **not native default parity**. Raw source
and registration receipts remain distinct in the candidate. Resolve effective
native serialization/gesture semantics before declaring full vanilla equivalence.

Remaining engineering work: native serialization parity, representative shared
on-foot binding evidence, full contextual diagram parity, standalone schema-2
installation/update/package support and fresh-profile migration/fallback coverage.
No new manual gate or ten-switch quota; Phase 2 draft code remains preserved.

### Completed stationary menu/diagram cycle

One stationary Current (original) → DarkSoul → DarkSoul Alt1 → Current (original)
cycle passed; the final selection was restored to DarkSoul Alt1 (`Scheme=2`).
Exploration, Swimming, Combat and Horse pages were captured for each scheme
(12 pages). The three Horse screenshots were inspected: vanilla native layout,
DarkSoul A speed/L3 interaction, Alt1 L3 speed/A interaction, with the expected
shared Souls label permutation. This is normal Geralt/Xbox coverage; it does not
prove Ciri/display variants or on-foot action dispatch.

Receipt: `C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\menus-ready\20261011T224448Z-75a9560e\result.json`. Game closed; pinned save unchanged. Final audit preserved every
original binding multiset in all 56 existing contexts (48 personal + eight old
probe aliases), and verified ownership of all 84 new registered aliases. Semantic
rollback with later personal edits passed in fixture `migration-check-79b18cce`.
Audit: `C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\runtime-verification.json`. Twenty-five targeted Python checks and generated-source freshness
pass; Git whitespace checks pass. No commit or push was made for Phase 1.1.

The earlier menu-only first-pause attempt failed; using the established startup
stop/probe sequence completed this targeted replay. Retain its failed receipt;
first-pause readiness without that initialization is not claimed fixed.
Native serialization parity, on-foot dispatch and standalone delivery remain open.


## Standalone delivery and context capacity — October 11, 2026

Added `FullScheme-Mod.ps1` standalone install/update/restore preparation and
`Package-FullSchemeMod.ps1`. Original backups are retained across updates;
artifact updates never rewrite personal input. Owned drift refuses before live
writes; restoration semantically removes only owned aliases and retains unrelated
later edits. Existing development installations retain their separate journals.
Exact nine-record observed serialization is accepted for ownership only.
Missing/inherited/customized profiles still refuse instead of guessing.

Real PowerShell transactions passed on two isolated native-profile fixtures:
flattened source lineage and the exact recorded native serialization variant.
Both verified installation, update, original backup retention, changed-owned-file
refusal, alias removal and preservation of a later F3 edit. This proves delivery
transactions and preparation; it does not prove a live fresh-profile control bank.
Receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\standalone-integration\result.json.

The old cook included eleven native context-map capacity assertions among its
outer diagnostics. Sharing the 24 identical non-riding DarkSoul/Alt1 banks reduces
84 logical selections to 60 physical aliases. The existing 56 contexts now total
116, below 128. All three schemes keep their complete digital source multisets;
Alt1 retains its four distinct riding contexts. Generation rejects profiles whose
combined bank exceeds 128. Historical 84-bank ownership receipts remain restorable.
The original six migration backups remain untouched after the guarded bank update.

Fresh cook: 31713 bytes, SHA-256 d80eb19799e5f0c4185ba0fd16b7af555cb5346df1f29019184f60cc8b9087fc.
Script compilation/source equivalence passed. The context-capacity assertions
are absent; 51 other outer resource diagnostics remain.
Snapshot: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\shared-bank-editor\cooks\20261011-170620-a0f0348b.
The cold-open source-encoding handler executed successfully on this cook.

One three-choice replay stopped at an unrecognized menu boundary after native
dismount; an earlier attempt stopped at foreground transfer. Failed receipts
remain failed. Fresh-owned focus recovery now attaches both target and foreground
input queues and restores only the owned window, detaching before any input.
The targeted preferred Alt1 attack replay is recorded separately below.

An attempted engine-created default baseline exported no input.settings file.
Its native game window had hidden IME helpers; cleanup selected the exact owned
game title, waited for process exit and restored the complete original input
byte-for-byte in a guarded transaction. No native parity claim follows from this
attempt. Recovery receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\native-default-baseline\recovery-completed.json.

Native effective-default parity and live Ciri/alternate quick-sign variants remain
unexecuted acceptance coverage. Additional manual sign-off remains waived.
Phase 2 drafts are preserved separately from the Phase 1.1 commit.
