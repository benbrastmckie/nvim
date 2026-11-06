# Implementation Summary: Task #409

- **Task**: 409 - Advise on dirty file scope at admission
- **Status**: [COMPLETED]
- **Started**: 2026-11-06T00:00:00Z
- **Completed**: 2026-11-06T13:30:00Z
- **Effort**: low
- **Dependencies**: 407, 378, 387, 401, 403
- **Artifacts**: plans/01_dirty-scope-advisory-admission.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a fourth additive, non-blocking advisory field — `dirty_scope_advisory` — to the admission
verdict `orchestrate-batch-admit.sh` produces, firing whenever a dispatch candidate's own
declared `file_scope` intersects the current dirty working tree. The advisory is carried through
`orchestrate-cycle-plan.sh`'s per-cycle ledger and rendered as Class J in
`orchestrate-predispatch-review.sh`, matching the converged shape of the three existing sibling
advisories. All six implementation phases landed and were committed individually; the sixth and
final phase (redeploy and full gate set) is closed with reasoned exclusions rather than plain
completion, because the full gate run showed six failing checks, every one of which traces to a
cause outside this task's own files.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — computes and merges
  `dirty_scope_advisory` into the admission verdict via `scopes_overlap_first()` against
  `git diff --name-only HEAD`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — ledgers the advisory in a new
  `dirty_scope_ledger`, regardless of decision.
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — renders the advisory
  as Class J, with an accurate zero-count line on the tested-negative case.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` and
  `test-four-tier-conflict.sh` — presence/absence regression cases, backed by a new git-repository
  `TMPROOT` fixture capability neither suite had before.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — a Class J
  rendering scenario.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` and
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — documentation
  convergence for the new field, matching the two docs that track every existing sibling advisory.
- Deployed tree (`.claude/`) regenerated via `deploy-headless.sh`; all eight touched source-store
  files confirmed byte-identical to their deployed counterparts.

## Decisions

- Followed `whole_tree_claim`'s universal merge placement (applies regardless of whether the
  candidate's own changes are self-modifying), not `cross_session_hazard`'s narrower scoping.
- No `$schema` version bump — the field is additive and backward-compatible, matching both later
  sibling advisories' precedent.
- `git-snapshot.sh` required no code change; its existing `git diff --name-only HEAD` dirty-path
  computation already covers staged and unstaged changes, so no second `--cached` pass was added.
- Documentation convergence targets two docs, not three: `orchestrate-batch-results-template.md`
  was excluded because neither `absent_scope_advisory` nor `cross_session_hazard` — the two most
  recent sibling advisories — appears there either, establishing that a new advisory does not get
  a results-template section.
- Phase 6 (redeploy and full gate set) is closed `[COMPLETED WITH EXCLUSIONS]` rather than
  `[PARTIAL]`: this task's own deliverable is independently confirmed complete and correctly
  deployed (all 8 touched files byte-identical in the deployed tree, and `deploy-headless.sh`
  reported a landed deploy), and every one of the 6 full-gate-run failures traces to a cause
  outside this task's file_scope — see Plan Deviations below and the plan's own
  `#### Reasoned Exclusions` record for the full per-item evidence.

## Plan Deviations

- **Phase 6, redeploy step**: `deploy-headless.sh` reported `RESULT=landed_verify_red`, not the
  plan's target `RESULT=landed_verify_clean`. The deploy itself landed (files synced correctly);
  only the verify step was red, and the two prior-dispatch logs show this was the fast-gate
  subset invoked by `deploy-headless.sh` internally, not a separate run.
- **Phase 6, full gate set step**: `bash .claude/scripts/verify-deploy.sh` with no `--skip-slow`
  and no `--only-gate` narrowing reported 6 of 40 checks failing rather than a clean pass. Triage
  (full detail and evidence in the plan's `#### Reasoned Exclusions` record):
  - gate3 (doc-lint) and gate4 (task-reference lint): each killed by its own internal timeout
    (60s) under concurrent-session load on this shared tree — not a finding against this task's
    files.
  - gate10 (`validate-state.sh --deep`): killed by its own internal 30s timeout, same cause.
  - Manifest-driven parity check (check 5): reported two findings naming
    `scripts/lib/gate-store-fixture-lib.sh` and `scripts/lib/gate-registry-lib.sh` — files this
    task never touched. Git-blamed to concurrent sibling task 489 (commit `c4dbdc050`), confirmed
    live-editing the same shared source tree during this dispatch window.
  - gate8 (`tests/run-all.sh`): blocked on `specs/.gate-lock`, held by a concurrent
    `verify-deploy-gate8-*` session from another agent's run (pid 4043396), not by this task's
    files.
  - Dead-command-recommendation lint (check 24): a pre-existing finding naming the `/ide` built-in
    with no definition file, independently corroborated as a known foreign finding in an earlier,
    unrelated task's issue log (`specs/401_.../issues.jsonl`, entry `iss_1793953974938_7nb3up`).

  No deviation required re-running any gate: the two existing logs from a prior dispatch
  (`deploy-409.log`, `verify-deploy-409-bg.log`) were read and triaged directly, per this
  dispatch's explicit scope.

## Verification

- Build: N/A (shell/jq scripts and markdown docs, no build step)
- Tests: Phases 1-5 each individually verified and committed; Phase 6's full gate run showed
  6/40 failing checks, all traced to foreign causes (see Plan Deviations above)
- Files verified: Yes — all 8 source-store files this task touched confirmed byte-identical
  against their deployed `.claude/` counterparts via direct diff
- Working tree: confirmed clean of any uncommitted change belonging to this task's own scope
  (`git status --porcelain` empty over both the task directory and all 8 touched source files)

## Impacts

- Operators running `/orchestrate` on a repository with a dirty tracked tree now see a Class J
  advisory naming any intersection between a dispatch candidate's declared `file_scope` and the
  dirty paths, before that candidate's implement dispatch sweeps a foreign hunk into its own
  commit.
- The advisory is strictly informational: it never defers, excludes, or changes the exit code of
  an admission run.

## Follow-ups

- None owned by this task. The 6 foreign gate failures recorded in Plan Deviations are each
  either transient (gate-internal timeouts, lock contention from a concurrent session) or owned
  by another task (task 489's in-flight `gate-registry-lib.sh`/`gate-store-fixture-lib.sh` work;
  the pre-existing `/ide` dead-command-recommendation finding tracked since task 401).

## References

- specs/409_advise_on_dirty_file_scope_at_admission/plans/01_dirty-scope-advisory-admission.md
- specs/409_advise_on_dirty_file_scope_at_admission/reports/01_dirty-scope-advisory-research.md
- specs/409_advise_on_dirty_file_scope_at_admission/handoffs/ (per-phase progressive handoffs,
  phases 1-5)
- /tmp/claude-1000/-home-benjamin--config-nvim/29691ec0-67cb-4265-ba13-cf498093c31c/scratchpad/deploy-409.log
- /tmp/claude-1000/-home-benjamin--config-nvim/29691ec0-67cb-4265-ba13-cf498093c31c/scratchpad/verify-deploy-409-bg.log
