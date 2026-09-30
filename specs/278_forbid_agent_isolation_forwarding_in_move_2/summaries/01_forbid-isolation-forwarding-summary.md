# Implementation Summary: Task #278

- **Task**: 278 - Forbid Agent isolation forwarding in Move 2
- **Status**: [COMPLETED]
- **Started**: 2026-09-30T00:00:00Z
- **Completed**: 2026-09-30T00:35:00Z
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_forbid-isolation-forwarding.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Move 2 of `skill-orchestrate/SKILL.md` did not forbid forwarding a `dispatch[]` row's
`isolation`/`worktree_path` fields to the harness Agent tool's own `isolation` parameter, while
`orchestrate-cycle-plan.sh` emitted both fields on every row with only weak "dispatch-site
wiring" phrasing. This implementation lands a categorical, point-of-use `**MUST NOT**` in Move 2,
strengthens the emitting script's header into an explicit never-forward statement, and cross-links
the existing design record in `batch-orchestration-guardrails.md` so the rule and its rationale
surface each other in both directions. All three edits are documentation/comment-only — no
executable logic changed.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — inserted one new
  `**MUST NOT**:` prose paragraph in the `### Move 2: Dispatch` section (outside any code fence,
  matching the file's existing `aux_dispatch[]` MUST NOT paragraph's convention). States the
  categorical rule (no dispatch-row field is an Agent-tool argument unless Move 2 names it —
  today only `agent`/`model`), notes `Context: {...}` fields are prompt text not tool arguments,
  names `isolation`/`worktree_path` as the motivating collision (a real Agent-tool parameter whose
  enum includes `"worktree"`, so forwarding raises no error), states the one-clause consequence
  (stacked second harness checkout, cross-checkout git refusal, work authored/verified but
  uncommittable), cites the observed cost with no task number or repository name, and points
  forward to `batch-orchestration-guardrails.md`'s "Deliberate Divergences".
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — extended the output-schema
  header's `isolation`/`worktree_path` documentation (comment-only, located by content anchor
  rather than line number) with an explicit statement that both fields RECORD a posture already
  put into effect and are consumed only by this pipeline's own downstream bookkeeping, never an
  Agent-tool argument, plus a forward pointer to Move 2's MUST NOT by section name. No executable
  line changed; `bash -n` confirms syntax validity and the diff is confined to `#`-prefixed lines.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — added one
  line to the "Script-provisioned worktrees, not a harness-level isolation parameter" bullet under
  "Deliberate Divergences", pointing to Move 2's MUST NOT and naming the complementary
  stacked-checkout failure mode, distinct from that bullet's existing `specs/`-staleness argument
  (left fully intact).

## Decisions

- Placed the new Move 2 rule as a standalone prose paragraph immediately after the existing
  `aux_dispatch[]` MUST NOT and before `### Move 3: Postflight`, matching the file's established
  convention for a point-of-use contract statement outside any fence.
- Phrased the rule categorically ("no field ... unless this section names it") per the plan's
  "CONSIDER GENERALIZING" prompt, rather than enumerating only `isolation`/`worktree_path` — this
  was free of cost since only `agent`/`model` are forwarded today.
- Located both the script header anchor and the guardrails bullet by content, not line number,
  per the plan's contingency for the co-owning decomposition task (which had not landed by the
  time this task executed).
- Retained the existing `specs/`-staleness rationale in `batch-orchestration-guardrails.md`
  unchanged, adding the new cross-reference as a pure extension of the same sentence.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation/comment-only change)
- Tests: N/A (no test suite implicated; `bash -n` syntax check passed)
- Files verified: Yes — all three edited files confirmed additive-only (Phases 1 and 3) or
  comment-only (Phase 2) via `git diff`.
- `bash .claude/scripts/check-task-references.sh` — PASS, 0 unexempted occurrences.
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — exits 0.
- Zero writes under `.claude/**` across all three commits.
- All three cross-pointers (Move 2 -> Deliberate Divergences, script header -> Move 2,
  Deliberate Divergences -> Move 2) resolve to real, correctly-named sections.
- `git log`/`git show --name-only` confirm each of the three phase commits touches exactly its
  one intended file, with no foreign hunk swept in despite two concurrent sibling tasks (268, 269)
  editing other files in the same working tree this cycle.

## Impacts

- A dispatching lead reading a `dispatch[]` row with `isolation: "worktree"` now has an explicit,
  self-justifying prohibition at the exact point of use (Move 2), rather than having to discover
  the rationale in a separate guardrails document it has no reason to open mid-dispatch.
- The deploy tree (`.claude/**`) is now stale relative to the source store for these three files;
  this is expected per the plan's non-goals and was not regenerated.

## Follow-ups

- None. The optional third edit (cross-link) from the dispatch's "PROPOSED FIX" was completed as
  Phase 3, not deferred.
- The dispatch's "CONSIDER GENERALIZING" question was resolved: the rule is phrased categorically
  over the dispatch-row data shape, not enumerated per-field.

## References

- `specs/278_forbid_agent_isolation_forwarding_in_move_2/plans/01_forbid-isolation-forwarding.md`
- `specs/278_forbid_agent_isolation_forwarding_in_move_2/reports/01_forbid-isolation-forwarding.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
