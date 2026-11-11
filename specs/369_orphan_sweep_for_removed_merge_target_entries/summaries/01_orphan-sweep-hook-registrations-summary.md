# Implementation Summary: Task #369

- **Task**: 369 - Orphan sweep for removed merge-target entries (hook registrations)
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T16:15:00Z
- **Completed**: 2026-11-11T20:35:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: None blocking.
- **Artifacts**: plans/01_orphan-sweep-hook-registrations.md, records/01_baseline-measurements.md, records/02_after-measurements.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the gap where a hook registration removed from the source store survived indefinitely in
every already-deployed `.claude/settings.json`: added a single normative identity definition
shared by the merge path and the hook-registration-path lint, an orphan sweep modeled on the
existing context-index sweep, and its call-siting inside `manager.load`'s own atomic-rollback
block. Verified against five real deployed repositories (not synthetic fixtures), four of them
resynced live. Documented the add/change-but-not-delete invariant where a future editor meets it.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/hook_identity.lua` — new; the single normative
  `M.identity(command, hook_type)` definition, reconciling merge.lua's former `.claude/hooks/`-only
  pattern with the lint's broader, directory-qualified identity notion.
- `lua/neotex/plugins/ai/shared/extensions/hook_identity_fixtures.json` — new; the shared
  conformance corpus both consumers are pinned against.
- `lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua` — new; logic-free stdin/stdout
  bridge so the (bash) lint resolves identity through the same Lua module.
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — `hook_identity` now delegates to the
  shared module (exported as `M.hook_identity`); added `M.hook_valid_set_key`,
  `M.remove_orphaned_hook_registrations` (the sweep), and `M.restore_removed_hook_registrations`
  (rollback-threading primitive).
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` — conformance corpus specs, the
  anchor-pair collapse assertion, 8 sweep specs (including both mandatory survival regressions),
  a restore-primitive regression, and a stale pre-existing assertion fixed (a hardcoded hook-count
  literal made stale by unrelated later fragment growth).
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — `build_hook_valid_set` /
  `union_hook_registrations_into_valid_set` valid-set builders (excluding the currently-loading
  extension, mirroring the index sweep's pattern), two fail-safe gates, the sweep call site inside
  `process_merge_targets` (reading the extension's own fragment before invoking the sweep), and
  rollback-path restoration of swept entries on a failed load.
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` — Check C (fragment
  coverage) and Check D (existence) both now resolve identity through the shared module via one
  batched bridge call; the lint's own `normalize_identity()` is deleted.
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` — 3 new cases:
  identity agreement outside `hooks/`, `~/`-ineligibility on both sides, and a loud bridge-failure
  case (via a new `HOOK_IDENTITY_CLI_OVERRIDE` test-only escape hatch).
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` — new
  section stating the add/change-but-not-delete invariant, the per-merge-target sweep inventory
  (including the still-uncovered `merge_targets.mcp` gap), the mandatory carve-out, why no loader
  operation heals a pre-sweep deploy, the by-hand repair and its cost, and the unmanaged-repo field
  case.
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md`,
  `records/02_after-measurements.md`, `records/fixtures/*.json` — before/after measurement
  records and verbatim field fixtures for five real deploys.

## Decisions

- **A third, unstated ineligibility rule was required** beyond the two the plan named: an absolute
  (`/`-leading) path containing no `.claude/` substring is also identity-ineligible. Without it, a
  hand-written `/opt/mytools/...` hook would become sweep-eligible and could be silently deleted —
  the single most dangerous possible regression this task names. Documented at length in
  `hook_identity.lua`'s own doc comment.
- **Check D (script existence) was also unified onto the shared module**, not only Check C
  (fragment coverage), because Phase 3's own verification criterion requires the bash-side
  `normalize_identity()` to be gone entirely (`grep -c` outside the header note must be 0), not
  merely refactored out of Check C alone.
- **The sweep reads the loading extension's own fragment BEFORE invoking the sweep**, reordered
  from the plan's literal task order after re-reading its own safety rationale: an unreadable
  fragment must never leave the target swept with nothing to re-merge.
- **ModelBuilder's live `.claude/` tree was not touched directly.** `git status` there showed 98
  uncommitted, in-progress, unrelated changes under its own (unusually git-tracked) `.claude/`
  tree — a concurrent restructure this dispatch has no visibility into. Demonstrated via a
  scratch-directory replay of its real field fixture instead (12 → 28 registrations,
  fingerprint-identical, both orphans removed, carve-out survivor intact).

## Plan Deviations

- **Phase 2**: added the third ineligibility rule above (not literally stated in the plan's task
  text, but required by its own safety intent).
- **Phase 2**: fixed a pre-existing stale `merge_spec.lua` assertion (hardcoded hook-count literal
  made stale by unrelated fragment growth from other tasks after this spec was authored) — not
  caused by this task, but needed for this phase's own "no pre-existing case newly failing"
  verification to hold.
- **Phase 3**: unified Check D onto the shared module alongside Check C (see Decisions).
- **Phase 5**: reordered "read the fragment" ahead of "invoke the sweep" (see Decisions).
- **Phase 6**: ModelBuilder's live resync was deferred to a scratch-directory replay (see
  Decisions); the host's own live redeploy happened for real during Phase 7's own verification
  pass rather than being held back for Phase 8, since that pass needed a fresh redeploy anyway to
  clear an unrelated doc-lint drift finding.
- **Phase 8**: discharged against a scoped `--only-gate 21,8` invocation rather than the
  unqualified `verify-deploy.sh` aggregator, per the dispatch's own Batch Gate Deferral directive;
  closed `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned Exclusions record for both the
  deferral itself and Gate 8's 5 pre-existing, 0-NEW EXPECTED `run-all.sh` failures.

## Verification

- Build: N/A (Lua/shell source store; no compiled build step).
- Tests: `merge_spec.lua` 22/22, `manifest_spec.lua` 3/3, `test-lint-hook-registration-paths.sh`
  21/21, `test-deploy-orphans.sh`/`test-deploy-propagation.sh`/`test-deploy-verify-overlap.sh`/
  `test-mcp-merge-target.sh` all green. `tests/run-all.sh` (full, unnarrowed): 179 passed, 5 failed
  (all 5 pre-existing EXPECTED, 0 NEW), 2 skipped, 186 total — none of the 5 touch this task's
  files.
- Files verified: Yes — every file in the "What Changed" list, plus a direct headless
  `manager.load` smoke test against a scratch project (first-ever load correctly skips the sweep
  on an empty loaded-extension list; a resync correctly sweeps an injected orphan while preserving
  a hand-written survivor).
- Real-deploy verification: host, Logos/Theory, Logos/Website, and theorem_proving_in_lean4 were
  all resynced live via `deploy-headless.sh`, each showing the predicted orphan(s) removed, 0
  per-event duplicates, and a byte-identical `env`/`permissions` fingerprint before/after; a
  second resync of each was a true no-op. ModelBuilder was replayed against its real field fixture
  in a scratch directory (see Decisions).
- Gate 21 (`lint-hook-registration-paths.sh`): PASS, 0 violations, against the live source store.

## Impacts

- Every repository that next runs an ordinary `[Reload All]`/resync against this source store
  will have any orphaned hook registration (undeclared, cross-matcher-drifted, or
  cross-event-drifted) automatically removed, while every hand-written or `~/`-anchored custom
  hook is structurally guaranteed to survive untouched.
- The hook-registration-path lint and the merge-time sweep can no longer drift onto two different
  identity notions for the same registration — Phase 2/3's reconciliation is permanent, not a
  point-in-time fix.
- `merge_targets.mcp` (project-scoped `.mcp.json` server registrations) remains a known, explicitly
  documented gap with the identical exposure and no sweep — recorded in the boundary narrative as
  future work, not silently left for a reader to rediscover.

## Follow-ups

- `merge_targets.mcp` has no orphan sweep (documented gap, out of this task's scope).
- ModelBuilder's live `.claude/` tree still carries whatever orphans its fixture showed; its
  owner can apply the same `deploy-headless.sh` resync once their own in-progress `.claude/`
  changes (98 uncommitted paths at measurement time) are resolved.
- The wider ~16-repo population sharing the CWD-relative `claude-ready-signal.sh` orphan (beyond
  the five named remediation targets — see `records/01_baseline-measurements.md`'s premise
  re-validation section) will self-heal the next time each repo's own owner runs an ordinary
  resync; this task did not reach into every one of them.
- The full, unqualified `verify-deploy.sh` gate battery is deferred to this `/orchestrate`
  batch's own once-per-invocation run, per the dispatch's Batch Gate Deferral directive.

## References

- `specs/369_orphan_sweep_for_removed_merge_target_entries/plans/01_orphan-sweep-hook-registrations.md`
- `specs/369_orphan_sweep_for_removed_merge_target_entries/reports/01_orphan-sweep-hook-registrations.md`
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md`
- `specs/369_orphan_sweep_for_removed_merge_target_entries/records/02_after-measurements.md`
