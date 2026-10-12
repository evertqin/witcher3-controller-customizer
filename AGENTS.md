# Controller Customizer workflow

- Before REDkit/game/save automation, read `docs/automation-runbook.md` and current `docs/phase11-evidence.md` (Phase 1 history: `docs/phase1-evidence.md`).
- Phase 1.1 generated runtime/menu must pass `tools/Generate-Assets.ps1 -Check`; generation lives in `tools/automation/scheme_runtime.py` and pinned project-owned templates.
- Keep canonical UTF-8 scripts in `src/scripts`; use ownership-guarded `tools/Sync-EditorSources.ps1` for the UTF-16 REDkit mirror.
- Prefer native editor controls, scripted file/log handling and ViGEm over blind GUI coordinates.
- Routine defaults follow installed journal schema: `phase11-smoke.json` for three schemes, `phase1-smoke.json` for historical two-preset installs; use longer stress testing only for a specific unresolved concern.
- User accepted eight successful switches as sufficient; do not repeat solely to reach ten.
- Keep meaningful failure checks and distinguish callback evidence from full gameplay acceptance.
- Discover/pin explicit manual saves with `tools/automation/save_fixture.py`; retain save hashes and owned-process cleanup evidence.
