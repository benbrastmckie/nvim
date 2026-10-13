# Implementation Summary: Task #368

- **Task**: 368 - Tier-selection discipline: make a non-final-phase `full` verification tier justify itself
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T21:24:20Z
- **Completed**: 2026-10-08T23:55:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: Gate 8 suite-selection mechanism (task 366) — satisfied
- **Artifacts**: plans/01_tier-selection-discipline.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Qualified the verification-tier tie-break at `context/formats/plan-format.md`'s
`## Verification Tiers` section from an unconditional "strictest applicable tier" default to a
cost-aware rule: the final phase and genuine uncertainty still apply the strictest tier, but a
non-final phase states, in a new required `**Tier Justification**:` field, why its tier is the
cheapest one covering the edit's blast radius. Propagated the identical contract to the three
other surfaces a planner actually reads at tier-assignment time (`agents/planner-agent.md`,
`context/workflows/task-breakdown.md`, `context/contracts/phase-closure.md`), fixed one stale
descriptive label, and executed the plan itself as its own acceptance demonstration — five
non-final phases declared tiers below `full` with stated justifications, and the sixth, final
phase ran the complete, unnarrowed gate set.

## What Changed

- `agent-system/extensions/core/context/formats/plan-format.md` — qualified the tie-break; added
  the "final phase" definition (highest-numbered phase, terminal node, transitively depends on
  every other phase); specified the `**Tier Justification**:` field (required on every
  non-final phase, omitted on the final phase) with its two tier-dependent content bars; named
  the two narrowing mechanisms (`run-all.sh --only`, `verify-deploy.sh --only-gate`); wrote in the
  `__FULL_SWEEP__` honesty case for pure-guidance markdown edits that map to no suite at all; and
  cross-referenced the `--skip-slow`/doc-sync-pin caveat. The non-negotiable invariant and the
  `full`-naming requirement are confirmed byte-unchanged.
- `agent-system/extensions/core/agents/planner-agent.md` — rewrote step 8's tier-assignment
  guidance to the qualified rule; added a `**MUST NOT**` against a generic justification; added
  the field to the phase template beside `**Commit Mode**`/`**Scope Hypothesis**`; extended the
  authoring checklist to identify the plan's final phase and check both halves of the rule.
- `agent-system/extensions/core/context/workflows/task-breakdown.md` — added the conditional
  field to both phase templates and a one-line justification to all three worked examples
  (`interface`, `local`, `full`); added one clarifying Notes bullet explaining why the worked
  `full` example's last-listed phase is not that example's Decision-2 final phase.
- `agent-system/extensions/core/context/contracts/phase-closure.md` — added a clause stating a
  justified non-final cheaper tier closes a phase legitimately; added a cross-reference clause
  making explicit that the run-and-observe rule applies to whatever tier is *declared*. The
  no-promotion-without-evidence sentences are confirmed unweakened.
- `agent-system/extensions/core/rules/plan-format-enforcement.md` — one stale-label fix,
  "tie-break-upward rule" -> "tie-break rule" (one line).

## Decisions

- One uniform `**Tier Justification**:` field, required on every non-final phase regardless of
  tier (not only non-final `full`), per the plan's Decision 1 — this forces the blast-radius
  judgment in both directions (a cheap tier with nothing covering it is caught, not only an
  expensive tier with no reason).
- "The final phase" is defined as the plan's highest-numbered phase, required to be both a
  terminal node of the dependency graph and transitively dependent on every other phase — the
  transitivity requirement is what makes that phase's `full` gate meaningful and removes the
  ambiguity of a last wave with two independent terminal phases.
- The `--skip-slow`/doc-sync-pin caveat is cross-referenced to
  `context/standards/shell-script-testing.md:178-183` rather than restated a third time, per
  Decision 3.

## Plan Deviations

- **Phase 1**: Scope Hypothesis under-anticipated one additional hunk — the per-phase field
  catalog under `## Implementation Phases (format)` (where `Scope Hypothesis`/`Commit Mode` are
  already listed) also needed a short bullet for the new field, beyond the `## Verification
  Tiers` section the hypothesis had confined itself to.
- **Phase 3**: Added one clarifying Notes bullet to `task-breakdown.md`'s worked example
  (beyond the plan's literal task list) explaining that the example's Phase 3 depends only on
  Phase 1 (not transitively on Phase 2), so it is not that example's Decision-2 final phase
  despite being last-listed — forestalling an apparent contradiction with the new final-phase
  definition.
- **Phase 5**: The plan's literal `grep -rn 'tie-break-upward' agent-system/extensions/` check
  was run scoped to the five in-scope files instead of the whole corpus. The one corpus-wide
  survivor, `context/contracts/reference-grounding.md:85`, independently describes that file's
  own, separate numeric Tier 1/2/3 tie-break — a different system `plan-format.md` already
  disclaims collision with — not a copy of the rule this task qualifies. Recorded as a
  non-blocking issue.
- **Phase 6 (final)**: 2 of 35 unnarrowed final-gate checks were closed as reasoned exclusions
  rather than plain green. See Follow-ups and Verification below for the full account.

## Verification

- Build: N/A (documentation/guidance-only task)
- Tests: 33 of 35 `verify-deploy.sh` checks green with no narrowing flags; the remaining 2
  (gate 13's 2 orphan findings, gate 8's 1 failing suite) are closed as reasoned exclusions —
  see Phase 6's `#### Reasoned Exclusions` table in the plan for the full per-item record. Both
  root-cause to the same pre-existing, unrelated condition: `hooks/detect-noop-bash.sh:251`
  writes a per-session `tmp/noop-bash-shapes-<uuid>` runtime file on every Bash-tool call —
  the identical mechanism `context/patterns/deploy-orphan-detection.md`'s "Runtime artifact"
  exclusion class already documents for the sibling `tmp/noop-bash-count-*` pattern, just not yet
  added under the newer `-shapes-` suffix. The one failing shell suite's fixture symlinks the
  live `.claude/` tree and inherits the identical orphan files in its own baseline check.
  Confirmed, by reproduction and by reading `detect-noop-bash.sh`'s and the fixture's source,
  unrelated to any of this task's five edited files. All other gates — including 3 (doc-lint),
  4 (task-reference lint), and 5 (manifest parity/content-hash) — are fully green, confirming the
  redeploy correctly cleared all drift expected during Phases 1-5.
- Files verified: all five edited files diff-confirmed byte-identical between
  `agent-system/extensions/core/**` and their deployed `.claude/**` counterparts. Zero
  task-number references in any of the five (`check-task-references.sh --quiet` green).
- Acceptance items 1-6 (from the task description) all demonstrated by execution, not asserted:
  - Item 1: this plan's own Phases 1-5 declared tiers below `full` with stated justifications and
    its final gate ran.
  - Item 2: the archived task-361 mid-task phase's live replay confirmed `suite_selection_select`
    maps `scripts/lib/push-grant-lib.sh` to `test-guard-destructive-git.sh`, `test-guard-git-push.sh`,
    `test-please-grant.sh`, and `hooks/guard-destructive-git.sh` to an 8-suite set including
    `test-guard-destructive-git.sh` — the intersection covering both files that phase edited.
  - Item 3: the worked `full` example at `task-breakdown.md`'s Phase 3 carries a satisfiable
    one-line justification.
  - Item 4: `plan-format.md:338-345`'s invariant and full-naming passages are byte-unchanged.
  - Item 5: `grep -rn 'strictest applicable tier'` across the five in-scope files returns only
    the qualified form; zero unconditional occurrences.
  - Item 6: `planner-agent.md`'s authoring checklist now identifies the final phase and checks
    the `**Tier Justification**:` field on every other phase.

## Impacts

- Future plans across every task type now have a cost-aware, checkable mechanism for choosing a
  cheaper verification tier at non-final phases, directly reducing redundant full-gate-set runs
  (measured at 14m1.5s sequential / 6m47.4s under `--jobs auto` on a loaded host) for phases whose
  edits don't need that coverage.
- The final phase of every plan is unaffected: it still names the complete gate set, per the
  non-negotiable invariant, which is byte-unchanged.

## Follow-ups

- `context/patterns/deploy-orphan-detection.md`'s "Runtime artifact" exclusion-class table should
  gain a `tmp/noop-bash-shapes-*` row alongside its existing `tmp/noop-bash-count-*` row, closing
  the gap in `verify.lua`'s orphan predicate that this task's Phase 6 worked around via a
  reasoned exclusion. Out of this task's `file_scope`; recommended as a separate, small
  follow-up task.
- `agent-system/extensions/core/rules/plan-format-enforcement.md`'s "Required per-phase fields"
  summary list does not mention `**Tier Justification**` (the plan deliberately scoped Phase 5's
  edit there to the one stale-label fix only). The four main surfaces fully document the field;
  this is a minor completeness gap in a lower-tier summary file, not a correctness issue.

## References

- Plan: `specs/368_tier_selection_discipline_non_final_full/plans/01_tier-selection-discipline.md`
- Research report: `specs/368_tier_selection_discipline_non_final_full/reports/01_tier-selection-discipline.md`
- Progress files: `specs/368_tier_selection_discipline_non_final_full/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/368_tier_selection_discipline_non_final_full/handoffs/phase-{1..6}-handoff-*.md`
