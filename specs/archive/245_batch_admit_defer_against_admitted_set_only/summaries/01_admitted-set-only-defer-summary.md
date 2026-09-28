# Implementation Summary: Task #245

- **Task**: 245 - Batch admit: defer against admitted set only
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T00:00:00Z
- **Completed**: 2026-09-22T12:15:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_admitted-set-only-defer.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-batch-admit.sh`'s `in_batch` deferral rule tested a candidate against any
lower-numbered task appearing in the invocation's argument list, regardless of whether that peer
was itself admitted this cycle. This meant a candidate could pay a needless one-cycle wait when
its only overlap was with a peer that was *also deferring* — no dispatch of the deferred peer
happens, so there was no concurrent-write hazard to guard against. The jq program's top-level
`$cands[] as $c | ...` generator was replaced with a `reduce` over candidates sorted ascending by
`project_number`, threading a running admitted-set lookup so the `in_batch` collision test now
compares only against peers already decided `admit`. NDJSON output still emits in original
caller-argument order; `cross_batch`, `session_active`, and self-modification semantics are
unchanged.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — converted the jq program's
  top-level generator to a `reduce` over ascending-`project_number`-sorted candidates; narrowed
  the `in_batch` collision predicate so a lower-numbered peer only blocks a candidate when that
  peer's own accumulated verdict is `admit`; re-emit verdicts in original caller-argument order by
  binding the fold's `.results` map and iterating the original `$candidates` array; updated the
  `# Determinism:` header comment and the "Deferral-direction rule for file_scope_collision"
  comment block to describe the narrowed rule.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` — new regression
  suite (isolated `mktemp -d` temp root, byte-for-byte script copies satisfying
  `deploy-root-guard.sh`) with three cases: Case 1 reproduces the observed A-admitted /
  C-defers-on-A / D-admitted (overlapping only C) chain; Case 2 asserts NDJSON emission order
  matches caller-argument order even when arguments are passed out of ascending order (`D C A B`);
  Case 3 confirms the narrowing holds uniformly across defer reasons (self-modification-caused
  defers also keep a lower-numbered in-batch peer out of the admitted set).
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — narrowed the
  `in_batch` bullet under Deferral-Direction Rule and Caller Guidance to state a lower-numbered
  peer blocks a candidate only when that peer is itself admitted this cycle; added a "Two
  independent orderings" paragraph to the Invocation Contract / Determinism section distinguishing
  decision order (ascending `project_number`) from emission order (caller-argument order); added
  a Version History entry ("admitted-set-only in-batch narrowing — still v5, no version bump")
  modeled on the existing self-modification-tie-breaker entry; corrected two downstream stale
  claims surfaced during the grep pass (the `idle_overlap_advisory` field row's reasoning and the
  v4-to-v5 Version History entry's now-inaccurate "in_batch collision behavior is completely
  unaffected" claim, via a forward-pointing footnote).

## Decisions

- Chose the verbatim-move reduce restructuring (Phase 2's primary approach) over the plan's
  documented fallback (a separate precomputed admitted-set reduce feeding an unchanged generator);
  the verbatim move succeeded on the first attempt and needed no fallback.
- Kept a defensive degrade-to-admit fallback at the admitted-set lookup site for the
  (unreachable-by-construction) case of a lookup miss, matching the script's existing
  admit-when-in-doubt posture, with a comment explaining why the miss cannot occur.
- Documented the pre-existing duplicate-positional-argument edge case (a duplicate task number
  looks up its own first-occurrence verdict) inline rather than adding new handling for it, since
  it was explicitly out of scope for this fix.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell/jq scripts, no build step)
- Tests: Passed — `test-orchestrate-batch-admit.sh` (3/3 cases green), `test-conflict-predicate.sh`
  (v4/v5 session/corroboration suite, green), `bash -n` clean on the modified script,
  `run-all.sh` discovers and passes the new suite (91 passed, 1 failed, 0 skipped, 92 total). The
  one failure, `test-verify-deploy-context-budget.sh`, is a pre-existing and unrelated Gate 20
  eager-context-budget deploy check (commands/orchestrate.md, skills/skill-orchestrate/SKILL.md)
  last touched by prior, unrelated tasks; it is consistent with this dispatch's own
  `<deploy-freshness-context>` flag that the deployed `core` extension is stale relative to the
  source store, and does not touch `orchestrate-batch-admit.sh` or either of this task's other two
  files.
- Files verified: Yes

## Impacts

- `orchestrate-cycle-plan.sh` and `orchestrate-predispatch-review.sh` (the two live verdict
  consumers; `orchestrate-dry-run-report.sh` was retired in a prior, unrelated task and its
  dry-run functionality folded into `orchestrate-cycle-plan.sh --dry-run`) branch only on
  `decision`/`defer_reason`/`collision_scope`/`colliding_task_number` and require no code change —
  confirmed by grep.
- **`.claude/scripts/orchestrate-batch-admit.sh` is a regenerated deploy artifact.** This fix
  takes effect for live `/orchestrate` runs only after the next deploy/reload
  (`bash .claude/scripts/deploy-headless.sh`); the source-store edit alone does not change
  in-flight or future `/orchestrate` batch-admit behavior until that redeploy happens. This
  dispatch's own `<deploy-freshness-context>` block confirms the deployed `core` extension is
  already stale relative to the source store for unrelated reasons.
- Batches with a chain of in-batch, same-cycle deferrals (candidate admitted, dependent candidate
  defers on it, a third candidate overlapping only the deferring one) will now admit that third
  candidate in the same cycle instead of waiting an extra cycle — the wasted-cycle pattern
  observed live in the evidence source (an 8-task batch that took 6 implement cycles, ~2 of which
  were avoidable).

## Follow-ups

- None.

## References

- `specs/245_batch_admit_defer_against_admitted_set_only/reports/01_admitted_set_only_defer.md`
- `specs/245_batch_admit_defer_against_admitted_set_only/plans/01_admitted-set-only-defer.md`
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
