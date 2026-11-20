# Implementation Summary: Task #662

- **Task**: 662 - Reframe docs for ignored-specs default
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T04:41:28Z
- **Completed**: 2026-11-20T06:30:00Z
- **Effort**: ~1.8 hours
- **Dependencies**: None (consumed the landed outputs of tasks 658-661)
- **Artifacts**: plans/01_reframe-docs-ignored-specs.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Reframed every documentation surface in the `agent-system/extensions/core/**` source store that
asserted, as an invariant, that the `specs/` tree is committed to git, so a gitignored `specs/`
tree now reads as a first-class supported posture rather than a broken state. Each reframed
surface states what the two postures share (the lifecycle event and the commit *attempt*) and
what differs (the outcome — a commit, versus `git-commit-scoped.sh`'s non-failure V13 skip at
exit `8`/`9`), pointing at `context/standards/git-staging-scope.md`'s Per-Operation Contract
section rather than re-deriving the mechanism in each location. Task 661's drafted durability
statement was placed verbatim in `context/standards/orchestrator-runtime-files.md`.

## What Changed

- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — task 661's
  durability statement inserted verbatim at the end of the Fresh-Repo Default section
- `agent-system/extensions/core/rules/git-workflow.md` — a 372-byte posture paragraph under
  Commit Timing, pointing at `git-staging-scope.md` and `orchestrator-runtime-files.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — the exit-path
  table's `failed`/`blocked` rows qualified with the V13-skip channel; `### The mechanical
  signal` gained a paragraph naming `stranded_suspected` as the detector that covers the
  zero-commit case under an ignored posture, with an explicit non-widening disclaimer
- `agent-system/extensions/core/context/processes/research-workflow.md`,
  `planning-workflow.md`, `implementation-workflow.md` — each gained a third, non-failure
  "posture skip" outcome branch in the Create Git Commit step, a posture-neutral checkpoint, and
  (all three, not two — see Plan Deviations) an error-template exclusion note
- `agent-system/extensions/core/docs/templates/README.md` — three unqualified "git commit
  created" occurrences in the 8-Stage Workflow Pattern made posture-neutral
- `agent-system/extensions/core/commands/todo.md` — one sentence on the archival commit's
  non-failure skip under a wholly-ignored tree
- `agent-system/extensions/core/context/workflows/command-lifecycle.md` — output and
  verification criterion qualified
- `agent-system/extensions/core/context/orchestration/postflight-pattern.md` — checkpoint and
  validation-checklist item qualified
- `agent-system/extensions/core/context/workflows/preflight-postflight.md` — validation item
  qualified (sweep-found addition beyond the plan's declared list)
- `agent-system/extensions/core/context/standards/git-integration.md` — overview sentence and
  commit-delegation steps qualified with the posture-skip branch (sweep-found addition)
- `agent-system/extensions/core/index-entries.json` — `line_count` regenerated for every
  touched indexed row across all phases (zero drift remaining)
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`

`agent-system/extensions/core/context/standards/error-handling.md` was inspected (per Phase 5's
conditional instruction) and left unchanged — its commit-failure example describes a genuine
`fatal: not a git repository` failure, not an invariant claim.

## Decisions

- Treated Phase 5's confirmatory sweep grep as authoritative over the plan's own declared file
  list, which surfaced two additional surfaces (`context/workflows/preflight-postflight.md`,
  `context/standards/git-integration.md`) beyond the six the plan named; both were reframed in
  the same pattern.
- Left every success-path-only log line unchanged across all phases (e.g. `git-integration.md`'s
  "Log: Git commit created: {commit_hash}", `postflight-pattern.md`'s `echo "✓ Git commit
  created"`) — only outcome-summarizing checkpoint/criterion lines were softened, consistent
  across phases 2 through 5.
- `git-integration.md`'s overview sentence ("All state-changing operations MUST create git
  commits...") was qualified even though the sweep's specific regex didn't match it, because it
  is the same class of unqualified invariant assertion the whole task targets.

## Plan Deviations

- **Task 4.4 (Scope Hypothesis)** altered: the plan claimed `planning-workflow.md` has no "Git
  Commit Failed" error template (only `research-workflow.md` matched that exact heading). Live
  grep found all three process-workflow files DO carry an error template, just worded "Git
  Commit Failure" (planning, implementation) vs. "Git Commit Failed" (research); the third edit
  was applied to all three files instead of two, for consistency. Logged via `issue-record.sh`.
- **Phase 5 scope** expanded: two surfaces beyond the plan's declared six-file list
  (`preflight-postflight.md`, `git-integration.md`) were reframed, per the phase's own
  instruction to treat the re-run sweep as authoritative.

## Verification

- Build: N/A (documentation-only task; no script logic changed anywhere)
- Tests: `verify-touched.sh` run per-phase and at close; all named suites passed except two
  pre-existing, documented failures unrelated to this task's edits (see Follow-ups)
- Files verified: Yes — all edits confirmed in both source store and deployed tree
- Six protected files (two exemption standards, `state-management.md`, `artifact-formats.md`,
  `git-staging-scope.md`, `absent-specs-git-history.md`): byte-unchanged (`git diff --stat`
  empty over the full task commit range)
- `index-entries.json` `line_count`: zero drift (177/177 exact after final regeneration)
- `measure-eager-context.sh --check`: exits 0, 70,877 B against the unmoved 71,600 B baseline
- Negative controls (deprecated/legacy/superseded framing; task-number references;
  record-versioning language): all clean
- Deploy: landed correctly with all edits propagated; the deploy's own fast-gate verify pass
  reported `landed_verify_red` from one unrelated, pre-existing lint finding (see Follow-ups)

## Impacts

- A repository running with the ignored-specs default (task 660's init behaviour) now has
  documentation that accurately describes its own commit behaviour instead of asserting an
  invariant the posture structurally cannot satisfy.
- The orchestrator's `stall_suspected` detector's documented coverage gap under the ignored
  posture is now explicit, with `stranded_suspected` named as the covering detector — no script
  change, so no runtime behaviour differs.
- The tracked posture remains fully supported and is never described as deprecated, legacy, or
  superseded, per the task's explicit constraint.

## Follow-ups

- `lint-subject-resolution-declaration.sh` reports 1 pre-existing, unrelated violation in
  `agent-system/extensions/core/scripts/tests/run-all.sh` (zero overlap with this task's commit
  range or working tree) — not this task's to fix; logged via `issue-record.sh`
  (`pre-existing-breakage`).
- `test-verify-deploy-context-budget.sh` is a documented `known-failures.txt` entry (class
  `real-defect`, owned elsewhere) whose baseline-fixture-clean assertion depends on a full
  `verify-deploy.sh` run reporting zero findings — currently blocked by the same unrelated
  lint-subject-resolution-declaration.sh finding above.
- Per the dispatch's Batch Gate Deferral directive, the complete `verify-deploy.sh` gate set is
  deferred to this multi-task batch's orchestration close; this task's own scoped discharge
  (`verify-touched.sh`, no args) is documented in Phase 6's verification notes.

## References

- `specs/662_reframe_docs_for_ignored_specs_default/plans/01_reframe-docs-ignored-specs.md`
- `specs/662_reframe_docs_for_ignored_specs_default/reports/01_reframe-docs-ignored-specs.md`
- `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md`
  — source of the verbatim durability statement
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — the authoritative
  Per-Operation Contract every reframed surface points at
