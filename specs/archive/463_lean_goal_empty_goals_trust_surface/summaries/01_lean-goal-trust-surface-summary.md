# Implementation Summary: Task #463

- **Task**: 463 - State that `lean_goal`'s empty `goals_after` is not evidence a declaration elaborates
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T00:00:00Z
- **Completed**: 2026-11-22T01:10:00Z
- **Effort**: ~1.25 hours
- **Dependencies**: `lean_tier_vocabulary_to_build_scope_mapping` (confirmed landed)
- **Artifacts**: plans/01_lean-goal-trust-surface.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  no-record-versioning-in-deliverables.md

## Overview

The lean extension's `mcp-tools-guide.md` asserted `"no goals" = proof complete` for `lean_goal`,
while the implementation flow document relies on exactly that tool for per-step verification.
This is false: an elaboration error inside a tactic term (e.g. an unknown constant in a closing
`exact`) is recovered by Lean's elaborator with a synthetic `sorryAx` placeholder, closing the
goal while the declaration does not elaborate. This task states the corrected trust surface once,
points the flow document at it, and removes the one in-scope restatement of the false claim.

## What Changed

- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` — replaced the
  `- "no goals" = proof complete` bullet under `#### lean_goal` with the canonical statement: an
  empty `goals_after` means no goals remain open at that position and is not evidence the
  declaration elaborates; the `sorryAx` mechanism measured on this host's resolved toolchain
  (Lean 4.27.0-rc1, differing from the plan's 4.33.0-rc1 pin — re-measured and confirmed
  identical); and the named cheaper-than-full-build check, `lean_verify` on the fully qualified
  name.
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` —
  appended a one-line rationale pointer to Stage 4B item 5's step-verification line, directing to
  `mcp-tools-guide.md`'s `lean_goal` section, without restating the mechanism. The two-tool
  instruction and the `do NOT run lake build per-step` imperative are unchanged.
- `agent-system/extensions/lean/README.md` — dropped the `("no goals" = done)` parenthetical from
  the `lean_goal` row of the Capabilities table, leaving an accurate, caveat-free gloss.
- `agent-system/extensions/lean/index-entries.json` — `line_count` regenerated for the two edited
  context files, as a mechanical consequence of Phase 4's `deploy-headless.sh` run (not a
  hand-edit).
- Deployed copies under `.claude/context/project/lean4/**` regenerated via `deploy-headless.sh`
  (`RESULT=landed_verify_clean`), not hand-authored.

## Decisions

- Sited the canonical statement in `mcp-tools-guide.md` (siting candidate (a)), not
  `metadata-trust-surfaces.md` (a different genre of trust document), per planning's research
  integration.
- Named `lean_verify` (not `lean_diagnostic_messages`, which is globally blocked in this same
  extension) as the cheaper-than-full-build check that covers the unknown-constant case.
- Left `agent-system/extensions/lean/agents/lean-implementation-agent.md`'s step-9 restatement
  untouched: that file sits in a concurrent sibling task's declared `file_scope` this cycle.

## Plan Deviations

- **Phase 1** toolchain pin altered from Lean 4.33.0-rc1 (the plan's pin) to 4.27.0-rc1 (this
  host's resolved elan toolchain), per the plan's own explicit divergence instruction. The
  4-line `sorryAx` probe was re-run on this host and reproduced the identical result.

## Verification

- Build: N/A (no `.lean` source changed)
- Tests: `verify-deploy.sh --skip-slow --only-gate 3,4` — PASS (0 failures) after Phase 4's
  redeploy. `verify-touched.sh` on each phase's touched set — green per phase (Phase 1/2 recorded
  a transient `index-entries.json` line_count-mismatch finding outside their own `Files to
  modify` union, resolved automatically by Phase 4's redeploy; Phase 3's 18-suite battery passed
  16/18, with the 2 failures naming files outside this plan's scope — one harness-marked
  EXPECTED, one naming only pre-existing, unrelated lint-fixture self-tests). Phase 4's
  `verify-touched.sh` run on all three touched paths: narrowed 21-suite run 20/21 (1 EXPECTED
  failure), OWED-fallback full sweep (verify-touched.sh's own mechanism, not a hand-assembled
  one) 98/98 passed.
- Files verified: Yes — `grep -rn '"no goals" = proof complete' agent-system/ .claude/` and
  `grep -rn '("no goals" = done)' agent-system/ .claude/` both return nothing.

## Impacts

- The lean implementation agent now has a documented reason to pair `lean_goal` with
  `lean_verify` at every per-step verification point, rather than treating an empty `goals_after`
  as sufficient on its own.
- No change to the landed phase-commit-gates-on-the-full-build ruling; this caveat operates
  strictly between commit boundaries.

## Follow-ups

- `agent-system/extensions/lean/agents/lean-implementation-agent.md` line 753 ("Always verify
  proofs are actually complete (\"no goals\")") still restates the false completeness claim.
  Excluded this cycle due to a concurrent sibling's territory claim on that file; recorded via
  `issue-record.sh` so a future task can point it at the now-canonical statement without
  re-filing it as a fresh defect.

## References

- Plan: `specs/463_lean_goal_empty_goals_trust_surface/plans/01_lean-goal-trust-surface.md`
- Research: `specs/463_lean_goal_empty_goals_trust_surface/reports/01_lean-goal-trust-surface.md`
- Handoffs: `specs/463_lean_goal_empty_goals_trust_surface/handoffs/`
