# Phase 1.1 development evidence

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


## Automated on-foot continuation — October 11, 2026

Geralt was dismounted automatically with native keyboard E held for 1.5 seconds.
One light-attack press/release per scheme reached the original CPlayerInput
OnCbtAttackLight handler: vanilla X, DarkSoul RB, DarkSoul Alt1 RB. All three
observations have exact 1/1 edges, zero query mismatches, zero foreign-context
callbacks and the selected scheme's Combat alias. This proves representative
native dispatch/query behavior; other actions, Ciri and animation acceptance
remain separate. The preferred DarkSoul Alt1 was selected at final cleanup.

The passive wrapper calls the native handler exactly once, adds no listeners,
and uses unsaved input-manager fields. Native/SDK playerInput.ws is additionally
fingerprint-pinned (ecfe93c188dc140c2a650353ddd5fdda7d7d50b59e7957d167dcd1f5fedf2b13).
Current cook: 32,473 bytes, SHA-256 7c9b4a1cc8cf350f4f57583a1001d32581a9985d144bae27cdecf1059d21c823; seven native hooks, eight sources,
zero script-compilation errors and 19 separately retained packaging diagnostics.
Cook receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\onfoot-editor-ready\cooks\20261011-160341-8788373a.

The first replay retained a readable vanilla 1/1 screenshot but failed its broad
notification crop. The corrected replay preserved a passing vanilla assertion,
then stopped immediately on foreground drift to PickerHost.exe. Both original
failed receipts remain failed; no whole-run pass was inferred. After the user's
reported reboot and explicit continuation, only the remaining two schemes were
replayed. DarkSoul passed its live assertion; Alt1's exact 1/1 evidence failed
only its alias-font spelling (Altl). The corrected parser passes those saved
pixels in a separate supplement; the original full replay stays failed. All
three per-scheme assertions now pass across partial receipts; pinned save SHA
and owned closure passed. No additional gameplay cycle was run for this OCR fix.
Windows records an unexpected shutdown and boot at 16:12:24 PDT; no matching
game/editor application-fault event was found in the bounded check. Queued
historical kernel reports do not establish this reboot's cause.

Combined evidence: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\onfoot-verification.json.
Remaining failed replay, with passing DarkSoul assertion: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\onfoot-remaining\20261011T231946Z-df1952d7\result.json.
Alt1 saved-evidence supplement: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\alt1-foot-supplement.json.
Vanilla partial assertion: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\onfoot-ready\20261011T230858Z-52de52ca\probes\20261011T231003Z-bac27e9b\result.json.

The runner adds explicit dismount, X/RB and a 0.15-second tap below the legacy
0.2-second special-attack threshold. A tight status crop avoids busy HUD text;
only edge-count l/I and the known Alt1 suffix glyph normalize to unit digit 1. Exact counts, scheme alias,
zero mismatches and foreign-context counts remain mandatory. Twenty-six Python
checks pass; generated assets and Git whitespace checks pass.

Development artifact updates now atomically update three cooked files and both
ownership journals, retaining original six-target rollback backups. Isolated
update tests refused journal drift before writes and restored original runtime
hashes while preserving later input edits. Evidence:
C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\update-check-b2937b53\result.json.

Native nine-record serialization parity, remaining contextual diagram coverage
and standalone schema-2 delivery remain open. No new manual gate was introduced.


## Complete legacy diagram audit and recovery — October 11, 2026

Compared both exact legacy Git objects at revision 5f84ee7d3a5adc93ecd17e6003ba5868044d9fbb
against the current fingerprint-pinned native creators. After removing label
assignments, their creator control flow is identical. Fifteen of nineteen static
row blocks match the shared six-field permutation exactly. The four remaining
blocks are Geralt/Ciri Combat and Horse. Horse overlays were already implemented;
the audit exposed missing held-sprint labels on Geralt Combat A/B and Ciri Combat
B. The new targeted PC/GDK Combat overlay restores these legacy labels and keeps
quick-sign Aard/Quen lines after the held-sprint line. Vanilla remains native.
Other platform output is preserved; console/Switch support is not claimed.
Summary: docs/phase11-diagram-audit.json. Full local inspection receipt:
C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\diagram-expression-audit.json.

Fresh cook: 33554 bytes, SHA-256 a740587c42f4c4aa2431b17eaab47be3816a2edae072471420c63dce26733bb3.
Script compilation and canonical/editor text equivalence passed; 62 outer
packaging/resource diagnostics are retained separately. Cook:
C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\combat-diagram-editor\cooks\20261011-163554-818697dd. Only diagram.ws changed relative to the on-foot observer cook,
so prior per-scheme light-attack evidence is retained for unchanged binding,
bootstrap, routing and input sources rather than repeating those gestures.

One preferred Alt1 native diagram replay collected all four Geralt pages. The
Combat image was visually inspected: A shows Roll and held Sprint; B shows Dodge
and held Sprint. Horse/Exploration/Swimming capture and owned game closure passed;
the exact pinned mounted save SHA is unchanged. The final native choice is Alt1.
Receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\combat-diagram-focus-ready\20261011T234413Z-59777132\result.json. Ciri runtime and alternate quick-sign display
variants remain unexecuted; static source parity is not a claim they were played.

REDkit reload after reboot displayed a source-encoding conversion question.
Declining No preserved the owned UTF-16 files and allowed the cook. The runner
now recognizes only that specific conversion prompt and selects its unique No
button; other errors remain untouched. The new owned editor was gracefully
closed before game replay; the pre-reboot editor PID is invalid.

Two initial game launches timed out before any input because Windows refused
foreground transfer. Recorded diagnostics show one non-minimized 2560x1440 game
window and Cannot focus target. Added native input-queue attachment/detachment
only for the fresh owned startup; no keystrokes go to another application and
mid-replay foreground drift still stops input. The next fresh replay reached the
main menu, exact save and diagrams. Both failed startup receipts remain failed.
Twenty-seven Python checks and generated-asset checks pass. Original six-target
migration rollback remains current after the second atomic development update.

Remaining Phase 1.1 work: nine-record native serialization/effective parity and
standalone schema-2 install/update/package. Remaining actor/display coverage is
recorded separately; no additional manual sign-off or repetition quota applies.


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


### Final capacity-safe candidate verification

Targeted preferred Alt1 replay passed after an explicit native steel-sword draw:
one RB light-attack press/release, 1/1 callbacks, zero query mismatches and zero
foreign-context callbacks in the shared DarkSoul Combat bank. Native Scheme=2
was checked before replay. The pinned save remained unchanged and the owned game
closed. Receipt: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\shared-bank-alt1-combat\20261012T002057Z-0e6b338d\result.json.
The preceding zero-callback attempt is retained as failed: starting with sheathed
weapons does not exercise the combat-only observer. New `draw_sword` preparation
checks preserved native IK_1=SteelSword in Exploration and Combat before input;
the default on-foot scenario now includes it. No repetition quota was added.

Thirty-three targeted Python checks pass. Generated assets match. The standalone
archive's exact inventory and all 47 manifest hashes verified; no native
scripts, personal profiles or saves are included. Package SHA-256: 18a6781239e9abccf1475b3e72c5d84723bf5c5d20a9e63e3fd1c13a28cac105.
Local package: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\outputs\phase11\standalone-package\controller-customizer-phase11-candidate.zip.
Delivery audit: C:\Users\evert\Documents\Codex\2026-10-10\referenced-chatgpt-conversation-this-is-an\work\phase11\delivery-verification.json.
Native effective-default parity remains open; Ciri/display variants remain
unexecuted. The three-choice development candidate is ready for a branch push,
with those limits retained in the original plan and delivery documentation.
