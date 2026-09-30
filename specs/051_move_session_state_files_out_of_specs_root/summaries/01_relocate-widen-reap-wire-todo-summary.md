# Implementation Summary: Task #51

- **Task**: 51 - Move session runtime files out of the specs root and make the reap path run
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T23:54:37Z
- **Completed**: 2026-09-30T04:47:00Z
- **Effort**: ~7 hours across 7 phases
- **Dependencies**: None
- **Artifacts**: plans/01_relocate-widen-reap-wire-todo.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented all three parts of the task: wired `reap-session-runtime-files.sh` and
`task-lock.sh session-reap` into `/todo` (Phase 1, the acceptance-critical deliverable); widened
the reaper's candidate globs to cover all four naming generations, un-suffixed through `.prev-`
(Phase 2); untracked one retired-convention git orphan and documented Check B's coverage limit
(Phase 3); relocated both session-scoped singletons (`.orchestrator-multi-state-{session_id}.json`,
`.return-meta-multi-{session_id}.json`) from the `specs/` root into `specs/.orchestration/`
across every writer, reader, class-lib member, and doc reference, while permanently retaining
legacy-root reap coverage (Phases 4-6); and redeployed, ran the full verification gate set, and
swept this repo's live litter down from 72 stranded files to 0 (Phase 7).

## What Changed

- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — new `<stage id="14.5"
  name="ReapRuntimeFiles">` between Stages 14 and 15; new Stage 16 summary bullet
- `agent-system/extensions/core/commands/todo.md` — new `### 5.8. Reap Stale Session Runtime
  Files` subsection between §5.7 and §6
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` — widened `candidates`
  array to 16 globs (4 shapes × 2 families × 2 locations, permanent legacy-root coverage kept
  alongside the new `specs/.orchestration/` location), extended `extract_session_id`, fixed
  `rel_path` to be two-location-aware, updated header comments
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` — added Cases 7-9
  (superseded-shape stale/fresh, two-location sweep)
- `specs/.meta-return-sess_1790273700_meta01.json` — untracked via `git rm --cached` (working-tree
  copy also deleted, since it was not covered by the existing `.return-meta-*.json` gitignore
  pattern due to its reversed word order)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — new "Retired
  conventions and Check B's coverage limit" subsection; new `specs/.orchestration/` Class Table
  row; updated paths on the two existing singleton rows
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — added `orchestration` as
  the 19th class member across all four index-aligned arrays plus the dir-flag/basename arrays;
  repointed the `orchestrator-multi-state` probe; added shared `runtime_mt_state_path()` and
  `runtime_return_meta_multi_path()` resolvers
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`,
  `skills/skill-orchestrate/SKILL.md` — `mt_state_file`/`return-meta-multi` resolution moved to
  `specs/.orchestration/` via the shared resolver, with `mkdir -p` before first write
- Seven test fixtures repointed to the new location (`test-orchestrate-cycle-plan.sh` — 92 refs,
  `test-orchestrate-cycle-postflight.sh` — 7 refs, `test-orchestrate-context-growth.sh` — 3 refs,
  `test-force-phases.sh` — 2 refs) plus `runtime-file-patterns.sh` added to five fixtures' own
  lib-copy lists (`test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-context-growth.sh`, `test-orchestrate-unwind-dispatch.sh`, and two additional
  fixtures found only by running the full suite: `test-handoff-dispatch-identity.sh`,
  `test-orchestrate-recover-message-findings.sh`)
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — Case 5's hardcoded
  member-count assertion updated `18` → `19`
- Nine prose-only doc files swept for the relocated path (`commands/refresh.md`,
  `commands/orchestrate.md`, `commands/todo.md`, `docs/architecture/orchestrate-state-machine.md`,
  `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/orchestrate-batch-results-template.md`,
  `context/formats/return-metadata-file.md`, `skills/skill-refresh/SKILL.md`,
  `scripts/lib/deploy-ledger-lib.sh`) — `skill-refresh/SKILL.md`'s two bash invocation blocks
  confirmed byte-identical to HEAD (prose paths only changed)
- `specs/.gitignore` — managed block refreshed via `init-specs.sh` to carry the 19th
  `**/.orchestration/` pattern

## Decisions

- Widened the reaper's own glob array (8 shapes total: 4 per family) rather than writing a
  one-shot legacy-name migration script — the gitignore side already tolerated all four naming
  generations, so widening protects every consumer repo permanently rather than sweeping this one
  repo once.
- Kept every legacy `specs/`-root glob in the reaper permanently, alongside the new
  `specs/.orchestration/` globs, rather than retiring them after relocation — this is the load-
  bearing mitigation against the plan's top-scored risk (relocation creating a fourth orphaned
  generation in every other consumer repo that has not yet redeployed this change).
- Added a single shared path resolver (`runtime_mt_state_path`/`runtime_return_meta_multi_path`
  in `runtime-file-patterns.sh`) instead of four independent string literals across the writer
  sites, so a future rename touches one place.
- Phase 7 closed `[COMPLETED WITH EXCLUSIONS]` rather than a plain `[COMPLETED]`: three
  `verify-deploy.sh` gates and several `run-all.sh` residual failures were traced, with concrete
  evidence (`git merge-base --is-ancestor`, `git diff`, `git stash` re-runs), to defects that
  predate this task and lie entirely outside its `file_scope` (a lean-extension/core filename
  collision, a lean skill's missing postflight-boundary section, and accumulated eager-context-
  budget drift from ten unrelated prior tasks). See the plan's Phase 7 `#### Reasoned Exclusions`
  table for the full six-item evidence record.

## Plan Deviations

- **Phase 3**: the Scope Hypothesis's confirming grep found a second `.meta-return` match
  (`specs/vault/01-vault/archive/223_.../.meta-return.json`) beyond the one phase 3 targeted.
  Evaluated and left untouched — it is a per-task artifact inside an already-vaulted historical
  archive directory, not root-level session-scoped litter, matching the plan's own Non-Goals
  exclusion for per-task files.
- **Phase 5**: `test-runtime-file-tracking.sh`'s Case 5 was predicted a "likely no-op" but
  actually needed a real hardcoded-count fix (`18` → `19`). A full `run-all.sh` pass also
  surfaced two more fixtures needing the same `runtime-file-patterns.sh` lib-copy fix as the four
  already in scope (`test-handoff-dispatch-identity.sh`,
  `test-orchestrate-recover-message-findings.sh`) — folded into Phase 5 as the same defect class.
- **Phase 7**: closed `[COMPLETED WITH EXCLUSIONS]` — see Decisions above and the plan's own
  Reasoned Exclusions table for the six pre-existing, out-of-scope items traced and left unfixed.

## Verification

- Build: N/A (shell scripts and markdown only)
- Tests: `scripts/test-session-runtime-files.sh` (9/9), `scripts/tests/test-runtime-file-
  tracking.sh` (9/9, both source-store and deployed mode), `scripts/tests/test-orchestrate-
  cycle-plan.sh` (331/331), `scripts/tests/test-orchestrate-cycle-postflight.sh` (147/147),
  `scripts/tests/test-orchestrate-unwind-dispatch.sh` (21/21), `scripts/tests/test-force-
  phases.sh` (33/33) — all PASS. `check-runtime-file-tracking.sh` — Checks A/B/C all PASS
  (source-store and deployed mode). A full source-store `run-all.sh` pass completed once (97
  passed / 8 failed before the last two fixture fixes landed); every failure was either fixed
  in-scope or traced to a confirmed pre-existing, out-of-scope defect (see Phase 7's Reasoned
  Exclusions table).
- Files verified: Yes — every phase's own per-substep verification criteria checked before
  committing (syntax checks, targeted test runs, `git diff`/`git status` reviews).

## Litter Counts

Before the live sweep: 72 stranded files at the `specs/` root (40 `.orchestrator-multi-state-*`,
32 `.return-meta-multi-*`), matching the plan's own measured estimate exactly. After the live
sweep (`reap-session-runtime-files.sh`, no `--dry-run`): **0** — confirmed by a post-sweep
recount. `task-lock.sh session-reap --dry-run` (the `/refresh` path) continues to report
correctly (5 of 6 stale session-registry entries), confirming `/refresh`'s own invocation is
untouched by this task.

## Impacts

- `/todo` now reaps stale session-scoped orchestration runtime files and stale session-registry
  entries on every live invocation (not just on explicit `/refresh`), closing the root cause of
  unbounded litter growth this task's own evidence-refresh sections identified as the
  acceptance-critical half of the work.
- Every consumer repo of the core extension (BimodalLogic, cslib, ModelChecker, PersonalWebsite,
  and any future deploy target) gains the same fix on its next redeploy: the widened reaper glob
  covers all four naming generations, the relocated `specs/.orchestration/` singleton location
  keeps the `specs/` root clean going forward, and permanent legacy-root coverage means no
  already-stranded file in any of those repos becomes newly unreapable.

## Follow-ups

- The three pre-existing `verify-deploy.sh`/`run-all.sh` defect classes documented in this
  summary's Decisions section and the plan's Phase 7 Reasoned Exclusions table are candidates for
  a future task: (1) the lean-extension/core `context/contracts/*.md` filename collision in the
  deploy-merge order; (2) `skills/skill-lean-research/SKILL.md`'s missing postflight-boundary
  section; (3) the eager-context-budget baseline drift (67,980 B measured vs. 65,950 B recorded,
  accumulated across ten unrelated prior tasks); (4) `return-meta-status-vocabulary.sh` missing
  from three test fixtures' hand-maintained lib-copy lists since task 257 landed
  (`test-orchestrate-context-growth.sh`, `test-handoff-dispatch-identity.sh`,
  `test-orchestrate-recover-message-findings.sh`).
- The Non-Goals section's explicitly out-of-scope items remain open by design: sweeping the other
  four affected repos (BimodalLogic, cslib, ModelChecker, PersonalWebsite) arrives via their own
  next redeploy of the core extension, not via this task.

## References

- `specs/051_move_session_state_files_out_of_specs_root/plans/01_relocate-widen-reap-wire-todo.md`
- `specs/051_move_session_state_files_out_of_specs_root/reports/01_relocate-widen-reap-wire-todo.md`
- `specs/051_move_session_state_files_out_of_specs_root/progress/phase-{1..7}-progress.json`
