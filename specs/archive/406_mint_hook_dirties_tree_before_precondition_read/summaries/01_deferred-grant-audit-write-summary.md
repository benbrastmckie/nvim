# Implementation Summary: Task #406

- **Task**: 406 - Mint hook dirties tree before precondition read
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T16:00:00Z
- **Completed**: 2026-10-15T02:10:00Z
- **Effort**: ~5 hours (across two dispatches; dispatch_seq 14 resumed after a session-limit
  interruption during Phase 5)
- **Dependencies**: None (coordinates with, but does not depend on, the separate
  `sweep_task_support_file_tracked_or_ignored` task)
- **Artifacts**: plans/01_deferred-grant-audit-write.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the class of bug where a `UserPromptSubmit`/`PreToolUse` mint hook (`please-grant.sh` /
`guard-git-push.sh`, via `scripts/lib/push-grant-lib.sh`) dirtied the tracked `specs/events.jsonl`
by appending its audit record synchronously, before the command body it fired for ever ran. This
made `skill-tag`'s own clean-tree precondition unsatisfiable in any repository that tracks that
log, and produced a push-then-commit-then-push loop on every granted push. The adopted fix is
buffer-then-flush: `pg_grant_mint`/`pg_grant_consume` now write to a self-ignored pending-audit
buffer inside the existing grant directory, and a new `pg_audit_flush`, wired into the
already-registered `Stop`/`SubagentStop` hook, drains it into `specs/events.jsonl` after the
whole turn's command body and before the next turn's `UserPromptSubmit`.

## What Changed

- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` — added `pg_audit_buffer_path`,
  `pg_audit_buffer_lock_path`, `pg_audit_buffer`, and `pg_audit_flush`; rewired `pg_grant_mint`
  and `pg_grant_consume` to buffer instead of appending directly; `pg_grant_revoke` deliberately
  left untouched (does not suppress a buffered-but-unconsumed record); header `Audit:` paragraph
  rewritten to document the buffer-then-flush design and its timestamp semantics.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — wired an unconditional
  `pg_audit_flush` call into the `Stop`/`SubagentStop` handling.
- `agent-system/extensions/core/context/formats/events-format.md` — new "Buffer-Then-Flush" section
  naming the pattern as sanctioned for any future pre-command hook needing durable audit writes,
  and stating the `timestamp` (flush time) vs. `detail.recorded_at` (true moment) semantics.
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — comment above the clean-tree check in
  "Validate Git State" recording the invariant it now relies on; no logic change.
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` — three new regression cases:
  the `/tag` clean-tree pin, its buffer-not-log companion, and the revoke-then-flush
  audit-guarantee case.
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` — two new regression cases:
  the consume-side clean-tree mirror and a flush-idempotence case.

## Decisions

- **Adopted direction**: buffer-then-flush (deferred audit write), not the fallback of narrowing
  `skill-tag`'s clean-tree check to ignore one filename. Rationale recorded in the plan: a
  narrower check fixes only the one command that happened to be reported; the shared-library fix
  closes the cause for every future clean-tree-checking command.
- **Audit guarantee preserved by construction**: `pg_grant_revoke` does not touch the buffer or
  the flush; a minted-but-abandoned/revoked/expired grant's `push_grant_issued` record still
  reaches `specs/events.jsonl` on the next unconditional flush, exactly like a consumed one. There
  is no "was this used?" branch that could special-case the forensically interesting case away.
- **Timestamp semantics**: a flushed event's top-level `timestamp` is flush time (never
  backdated); the true mint/consume moment is carried in `detail.recorded_at`.
- **Push/commit loop closed**: `pg_grant_consume`'s buffering (not a direct append) means a
  successful push through `scripts/git-push-granted.sh` leaves the tree clean — no sweep commit
  is required, pinned by a Phase 4 regression case.
- **Blast radius re-attested against the source store** (not inherited from the research report):
  `skill-tag` is the only skill with a refusal-shaped clean-tree check; `/pr` (cslib) commits the
  dirt rather than refusing; `skill-orchestrate` only warns; four infra scripts are not gated
  behind a mint prefix at all. No new occurrence found.
- `scripts/lib/runtime-file-patterns.sh` and `context/standards/orchestrator-runtime-files.md`
  were confirmed untouched throughout — that classification belongs to the separate
  `sweep_task_support_file_tracked_or_ignored` task.

## Plan Deviations

- **Phase 5 final checklist item** ("Run the complete gate set and observe it green"): altered to
  observed-not-green. `verify-deploy.sh` fails 5/37 checks and `run-all.sh` fails 4/144 suites;
  every failure is attributed to a pre-existing or concurrent-sibling-task cause unrelated to
  this task's `file_scope`, with full evidence in the plan's Phase 5 `#### Reasoned Exclusions`
  section. The one failure inside this task's own `file_scope`
  (`test-guard-git-push.sh`'s "invalidation: expired grant" case) was specifically re-verified by
  reproducing the identical failure against the pristine pre-task-406 copy of
  `push-grant-lib.sh` (commit `a7942a4ec`) — confirmed pre-existing, unrelated to the
  buffer-then-flush rewiring, and out of this task's scope to fix.
- **Phase 5's verification line** names `agent-system/extensions/core` as `verify-deploy.sh`'s
  `TARGET`; that errors ("no deploy tree ... nothing to verify"). Ran with `TARGET=$(pwd)` (repo
  root) instead, matching task 389's prior successful invocation of the identical gate set.
  Recorded as a plan-wording deviation, not a gate defect.

## Verification

- Build: N/A (shell/markdown task)
- Tests:
  - `scripts/tests/test-please-grant.sh`: all cases pass, including the three new Phase 4
    regression cases.
  - `scripts/tests/test-guard-git-push.sh`: 49 of 50 assertions pass, including both new Phase 4
    regression cases. The one failure ("invalidation: expired grant expected exit 2, got 0") is
    pre-existing and unrelated — see Plan Deviations above and the Reasoned Exclusions table.
  - `scripts/tests/run-all.sh` (full suite, 144 total): 139 pass, 4 fail
    (`test-detect-noop-bash.sh`, `test-guard-git-push.sh`, `test-verify-deploy-context-budget.sh`,
    `test-four-tier-conflict.sh`), 1 skipped. None of the four failing suites' causes are in this
    task's `file_scope`.
  - `scripts/verify-deploy.sh` (full gate set, 37 checks, `TARGET=$(pwd)`): 32 pass, 5 fail (Gate
    3 doc-lint, Gate 4 task-reference lint, Gate 8 `run-all.sh`, Gate 20 eager-load budget — two
    sub-findings). Full per-item attribution in the plan's Phase 5 `#### Reasoned Exclusions`.
- Files verified: Yes (all `files_touched` paths confirmed clean against HEAD after each commit).
- `/tag`'s own end-to-end path is **not** agent-verified, per the dispatch's user-only constraint
  (`/tag` is user-only — see `.claude/rules/pr-prohibition.md` and the dispatch description). The
  owner must verify a real `/tag` invocation in a repository tracking `specs/events.jsonl`.

## Impacts

- Any repository tracking `specs/events.jsonl` can now run `/tag` without its own mint hook
  defeating `skill-tag`'s clean-tree precondition.
- A granted push through `scripts/git-push-granted.sh` no longer requires a follow-up sweep
  commit to clear log dirt before the next push.
- `context/formats/events-format.md` now documents buffer-then-flush as the sanctioned pattern
  for any future pre-command hook needing a durable audit write, closing the class of bug rather
  than only this one instance.

## Follow-ups

- The owner should verify a real `/tag` invocation end-to-end in a repository that tracks
  `specs/events.jsonl` (agent verification is out of scope per `/tag` being user-only).
- `test-guard-git-push.sh`'s pre-existing "invalidation: expired grant" failure
  (`pg_grant_fresh`/`pg_grant_find_match` handling of an expired-but-HMAC-valid grant) is
  unresolved and recorded in this task's `issues.jsonl`; a follow-up task should fix it.
- The five other pre-existing/sibling-caused gate failures enumerated in the plan's Phase 5
  `#### Reasoned Exclusions` are tracked externally (`iss_1792015798103_u6yBQB`,
  `iss_1792019093789_pEpEft`, `iss_1792019093909_Zk3nZO`) or belong to concurrently-dispatched
  sibling tasks (403's `skill-orchestrate/SKILL.md` growth); none require follow-up from this
  task.

## References

- Plan: `specs/406_mint_hook_dirties_tree_before_precondition_read/plans/01_deferred-grant-audit-write.md`
- Research: `specs/406_mint_hook_dirties_tree_before_precondition_read/reports/01_mint-hook-audit-ordering.md`
- Issues: `specs/406_mint_hook_dirties_tree_before_precondition_read/issues.jsonl`
- Handoffs: `specs/406_mint_hook_dirties_tree_before_precondition_read/handoffs/`
