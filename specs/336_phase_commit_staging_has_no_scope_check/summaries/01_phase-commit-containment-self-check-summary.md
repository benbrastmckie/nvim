# Implementation Summary: Task #336

- **Task**: 336 - Rule on the in-dispatch phase-commit staging surface: fifteen implementation
  agents commit with no file_scope check and no contended-path lease
- **Status**: [COMPLETED]
- **Started**: 2026-10-06T23:00:00Z
- **Completed**: 2026-10-07T08:15:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_phase-commit-containment-self-check.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Landed the ruled mechanism — `--task {N}` plus a documented pre-commit Containment self-check —
uniformly across all fifteen implementation-agent definitions that share the in-dispatch
phase-commit recipe. Exercised the observed undeclared-path defect as a live regression case,
confirmed the ruling's central concession (`--task` alone does not catch it), audited uniformity
mechanically, and recorded the durable mechanical chokepoint inside `git-commit-scoped.sh` as a
constrained follow-up specification rather than implementing it here (that script is outside
this task's `file_scope`).

## What Changed

- `agent-system/extensions/core/agents/general-implementation-agent.md` — added `--task "{N}"` to
  both `git-commit-scoped.sh` invocation sites; authored the canonical, named
  `#### Phase-Commit Containment Self-Check` block (predicate, carve-out list, drop-and-warn
  semantics, fail-open posture, and the two recorded reasons: the undeclared-path concession and
  the mid-dispatch siting rationale).
- `agent-system/extensions/founder/agents/founder-implement-agent.md` — `--task "{N}"` at all 5
  invocation sites plus the canonical-block pointer.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — same, 2 sites.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` — same, 1 site.
- `agent-system/extensions/books/agents/books-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` — prose-line recipe
  (no bash block in this file) edited in place to add `--task "{N}"` and the canonical pointer.
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/python/agents/python-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/rust/agents/rust-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/web/agents/web-implementation-agent.md` — same, 1 site.
- `agent-system/extensions/z3/agents/z3-implementation-agent.md` — same, 1 site (preserved its
  existing `--honest-index-rows {N}`).
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/01_pre-fix-regression.md` — new;
  live transcript proving `--task` supplied does NOT catch the observed undeclared-path case
  (exit 0, all ten paths land), with the Containment predicate run (1 kept / 9 dropped).
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/02_uniformity-audit.md` — new;
  mechanical audit confirming uniform coverage across all fifteen `file_scope` entries (21
  genuine invocation sites total).
- `specs/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md` —
  new; the constrained follow-up specification for the durable `git-commit-scoped.sh` chokepoint,
  stated as unfiled, with its coordination constraint (task 304).

## Decisions

- Ruled on both mechanisms at two layers: `--task` (Overlap-family, addresses the contended-path
  case) plus the prose Containment self-check (addresses the undeclared-path case `--task`
  structurally cannot reach). Neither substitutes for the other.
- Sited the self-check in the recipe itself, not at a postflight or cycle-plan layer, because a
  phase commit fires mid-dispatch with no postflight in scope and no cycle-manifest guarantee.
- Drop-and-warn, never refuse-the-whole-commit — reusing the existing "under-stage, never
  over-stage" fail-safe direction.
- Added an explicit fail-open clause to the self-check (missing/malformed `file_scope` proceeds
  as if the check were absent), consistent with every other guard mechanism in this codebase.
- Used class value `"scope excursion"` for the `issue-record.sh` call (no existing seed class
  matched this exact shape).
- Redeployed via the sanctioned `deploy-headless.sh --skip-verify` tool (not a hand-edit) to sync
  the `.claude/` mirror before the final gate run, resolving the content-hash parity check.

## Plan Deviations

- **Phase 4**: `books-implementation-hard-agent.md` has no literal bash invocation of
  `git-commit-scoped.sh`, only a one-line prose cross-reference, consistent with its established
  "same ... as the base agent" deferral style. Edited the prose line in place rather than
  introducing a bash block the file does not otherwise carry.
- **Phase 2**: added a fifth, explicit fail-open clause to the self-check beyond the plan's
  literal (a)-(e) list, consistent with the codebase's existing fail-open posture for guard
  mechanisms.
- **Phase 6**: closed `[COMPLETED WITH EXCLUSIONS]` — one pre-existing, foreign, out-of-scope
  test-suite failure (`run-all.sh`'s `test-orchestrate-cycle-plan.sh`, 14 of 349 cases) is caused
  by an uncommitted modification to `orchestrate-cycle-plan.sh` that predates this dispatch and
  is outside this task's `file_scope`; see the plan's Phase 6 Reasoned Exclusions record.

## Verification

- Build: N/A (markdown agent definitions)
- Tests: `bash .claude/scripts/verify-deploy.sh` — 33 of 34 checks pass (1 reasoned exclusion,
  see Phase 6 of the plan); `bash .claude/scripts/check-task-references.sh` — 0 occurrences
  repository-wide; the mechanical uniformity audit confirms all 21 genuine invocation sites
  across all 15 files carry `--task` and the canonical block or pointer.
- Files verified: Yes — all fifteen `file_scope` entries confirmed modified via their own
  `task 336 phase N:` commit; no file under `.claude/**` or `scripts/git-commit-scoped.sh` was
  touched.

## Impacts

- Every one of the fifteen implementation-agent phase-commit recipes now carries a documented,
  interim defense against the exact undeclared-path excursion that was observed to actually
  happen in production (the "task 187 phase 5" ten-generated-file commit cited in the task
  description), closing the gap between what the V5 `--task` lease can catch and what this
  surface actually needed.
- The durable, mechanical fix is specified and ready to be filed as a follow-up task, coordinated
  with the task that owns `git-commit-scoped.sh`'s exit-code contract (task 304).

## Follow-ups

- File the follow-up specified in `evidence/03_followup-mechanical-check.md`: a Containment check
  inside `git-commit-scoped.sh` itself, coordinated with task 304.
- A pre-existing, uncommitted modification to
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (observed, not caused by this
  task) is currently causing 14 test failures in `test-orchestrate-cycle-plan.sh`; whoever owns
  that change should resolve or commit it.

## References

- Plan: `specs/336_phase_commit_staging_has_no_scope_check/plans/01_phase-commit-containment-self-check.md`
- Research: `specs/336_phase_commit_staging_has_no_scope_check/reports/01_phase-commit-scope-check-ruling.md`
- Evidence: `evidence/01_pre-fix-regression.md`, `evidence/02_uniformity-audit.md`,
  `evidence/03_followup-mechanical-check.md`
