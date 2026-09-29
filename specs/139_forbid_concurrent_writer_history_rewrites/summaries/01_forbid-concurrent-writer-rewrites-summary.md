# Implementation Summary: Forbid concurrent-writer history rewrites

- **Task**: 139 - Forbid concurrent-writer history rewrites (rules/contracts) + concurrency-gated hook predicate (absorbed former task 140)
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T02:03:59Z
- **Completed**: 2026-09-29T02:35:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_forbid-concurrent-writer-rewrites.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Bare git history rewrites (`git commit --amend`, a HEAD-moving `git reset`) were forbidden
nowhere in the agent system, and every existing guard layer was scoped by dirtiness of the
working tree — a predicate that structurally cannot fire on the actual hazard, which is
concurrency of writers. This task closed the policy layer (rules, agent contract, hard-mode
recovery contract), then added a second, independent, tree-state-blind predicate to
`guard-destructive-git.sh` that refuses a history rewrite whenever a live dispatched writer
exists, proved it with a 30-case clean-tree fixture suite, documented the new hazard class in the
standards layer, and confirmed the change survives `.claude/` regeneration.

## What Changed

- `agent-system/extensions/core/rules/git-workflow.md` — two new `Never Run` bullets (bare
  `--amend`, HEAD-moving `reset`) with the concurrency qualifier; de-positionalized the
  "Enforced by `guard-destructive-git.sh`" paragraph and named the new predicate; added a new
  `### No History Rewrites While Another Writer Is Live` section immediately after `### No
  Destructive Git on Uncommitted Work`.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — new `MUST NOT` item 10
  prohibiting bare history rewrites and mandating `git-commit-scoped.sh`.
- `agent-system/extensions/core/context/contracts/recovery.md` — corrected the `"Green" Means Fix
  Forward` prohibition to cover two independent hazard classes (discarding uncommitted work vs.
  rewriting committed history under concurrency) instead of only the dirtiness-scoped one; rung
  (c) step 1's restated hook command list now names the new tree-state-blind predicate.
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — relocated the `COMMAND_SCAN`
  construction above the clean-tree exemption; added a concurrency-gated history-rewrite
  predicate (Gate A: `--amend` as a real argv token; Gate B: a HEAD-moving `reset`, with bare
  `HEAD`/`@` and pathspec-only forms exempted); `history_rewrite_live_writer()` reads
  `specs/*/.lock/holder.json` and `specs/.sessions/*.json` directly and cwd-relatively (never via
  `task-lock.sh`); one-or-more-live-records threshold with no self-exclusion; fail-open on any
  read/parse failure; documented `GUARD_ALLOW_HISTORY_REWRITE=1` operator-only override; rewrote
  the header to document both hazard classes.
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — added
  `add_live_lock`/`add_stale_lock`/`add_live_session`/`dead_pid`/`make_concurrency_repo` fixture
  helpers and `assert_blocked_clean`/`assert_allowed_clean_with` assertion helpers, all operating
  on a clean tree; 9 block cases and 21 allow cases; suite grew from 50 to 72 passing cases.
- `agent-system/extensions/core/context/standards/git-safety.md` — new "A Second Hazard Class:
  Rewriting Already-Committed History Under Concurrent Writers" section with the incident, the
  chosen signal, and the design rationale.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — the
  `specs/.sessions/{session_id}.json` row's Consumed-by cell now names the new predicate as its
  first consumer (previously "None in the source store today").
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — new "No History
  Rewrites While Another Writer Is Live — Incident and Full Detail" companion section carrying the
  full incident record, the complete permitted-forms list, and the practical guidance, mirroring
  this file's existing lazy-narrative-companion pattern.

## Decisions

- Item (d) of the original task description named a nonexistent
  `general-implementation-hard-agent.md`; retargeted to `context/contracts/recovery.md`'s actual
  mis-scoped prohibition, per the plan's Research Integration correction.
- `history_rewrite_live_writer()` reads both record families directly and cwd-relatively rather
  than via `task-lock.sh session-list`, because that command sources `deploy-root-guard.sh`
  (exits 1 from the source store) and anchors `PROJECT_ROOT` to its own `SCRIPT_DIR` rather than
  the caller's cwd — both fatal for a hermetically testable, cwd-relative hook.
- Threshold is one-or-more live records with no attempt to exclude "self": the hook cannot
  correlate its own native session UUID to an agent-system `sess_*` identity, and a dispatched
  agent's own live lock is itself proof it is running under orchestration, where bare rewrites
  are forbidden outright.

## Plan Deviations

- **Task 1.4** altered: the full-detail version of the new `rules/git-workflow.md` section (drafted
  per the plan's items (i)-(vi)) drove the file from 8,828 B to 13,166 B, pushing the eager-load
  context total to 69,375 B against the hard-reviewed 65,950 B `orchestrator-context-budget.json`
  baseline (discovered at Phase 7's redeploy verification, Gate 20). Trimmed the eager section to
  the rule statement, a one-sentence dirtiness-vs-concurrency distinction, a brief permitted-forms
  list, and an enforcement/override paragraph; relocated the full incident record, the complete
  permitted-forms list, and the practical guidance to a new companion section in
  `context/standards/git-workflow-narrative.md` — the established lazy-loaded-companion pattern
  this same file already uses for its "No Destructive Git on Uncommitted Work" sibling rule. Final
  measured eager-load total: 65,949 B, 1 B under baseline. All content required by items (i)-(vi)
  is still present, split across the eager rule and its lazy companion rather than inlined in one
  file; `git-safety.md`'s "A Second Hazard Class" section (Phase 6) independently carries the full
  incident and design rationale as well.
- **Task 4** (`history_rewrite_live_writer()`'s parse-failure path): uses `continue` (skip the
  record) rather than a named `999999` sentinel variable — functionally identical fail-open
  behavior; the verbatim `date -u -d` / `date -u -j -f` BSD-fallback chain from `task-lock.sh`'s
  `age_minutes` idiom is inlined directly rather than wrapped in a same-named helper function.
- **Task 5** (`assert_blocked_clean`/`assert_allowed_clean_with`): both helpers take an explicit
  fixture-fn argument (plus optional fixture-args) rather than the plan's literal 2-arg signature,
  since several distinct fixtures (live lock, live session, stale lock, no record) are each
  exercised through both helpers.

## Verification

- Build: N/A (shell scripts and markdown only)
- Tests: Passed — source-store suite 72/72; deployed suite 72/72; a temporary one-off ordering
  reversion confirmed exactly the 9 new block cases fail when the predicate is placed below the
  clean-tree exemption, then restored
- Files verified: Yes — all 8 changed files diff-identical between source store and deployed
  `.claude/` copy after regeneration

## Impacts

- Every future `general-implementation-agent` dispatch now carries an explicit prohibition on
  bare history rewrites, routing all commits through `git-commit-scoped.sh`.
- `guard-destructive-git.sh` will refuse a bare `git commit --amend` or HEAD-moving `git reset`
  issued by any tool call (from any agent, not only this codebase's own agents) whenever a live
  per-task lock or session-registry entry exists in the repo — including on a clean tree, closing
  the exact blind spot the 2026-09-02 incident exploited.
- `specs/.sessions/{session_id}.json` now has a real reader in the source store, changing its
  documented "Consumed-by" status from none to this predicate.

## Follow-ups

- The mislabeled commit `fd50fabfd` from the original incident remains unrepaired, as an explicit
  non-goal — a separate operator decision for when the branch is quiet.
- A future documentation-economy pass could further trim `commands/orchestrate.md`'s Options
  table (noted in `orchestrator-context-budget.json`'s own derivation comment) to restore more
  eager-load headroom beyond this task's 1 B margin, but that is out of this task's scope.

## References

- Plan: `specs/139_forbid_concurrent_writer_history_rewrites/plans/01_forbid-concurrent-writer-rewrites.md`
- Research report: `specs/139_forbid_concurrent_writer_history_rewrites/reports/01_forbid-concurrent-writer-rewrites.md`
- `agent-system/extensions/core/hooks/guard-destructive-git.sh`
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
