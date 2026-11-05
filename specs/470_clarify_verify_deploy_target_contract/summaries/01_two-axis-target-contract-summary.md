# Implementation Summary: Task #470

- **Task**: 470 - Clarify verify-deploy.sh TARGET contract versus its invocation-directory claim
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T07:24:00Z
- **Completed**: 2026-11-05T07:50:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_two-axis-target-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Separated `verify-deploy.sh`'s two distinct contract axes — where the script may be invoked FROM
(either tree, unchanged) versus what its `TARGET` argument must BE (a repository root holding a
deployed `.claude/` tree, and additionally `agent-system/extensions` for any source-store-only
gate to run rather than SKIP) — across the script's own header, its gate0 error text, and the
one live document that actually prescribed the broken invocation
(`context/formats/plan-format.md`'s `__FULL_SWEEP__` sub-case (b)). All edits landed in the
source store and were redeployed to the live tree.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` — added a `TARGET_REPO CONTRACT`
  header paragraph (separate axis from the existing, byte-identical `INVOCATION CONTRACT`
  paragraph) and a `TARGET_REPO placeholder` usage subsection; added one `echo ... >&2` line in
  gate0's `.claude/`-missing branch naming the TARGET convention.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — widened the
  existing `verify-deploy.sh` pointer sentence in the Root-Resolution Guard section by one clause
  pointing at the header's `TARGET_REPO CONTRACT` as the authority.
- `agent-system/extensions/core/context/formats/plan-format.md` — corrected the
  `__FULL_SWEEP__` sub-case (b) copy-pasteable invocation from the broken
  `--only-gate 3,4 <source_dir>` shape to `--only-gate 3,4 <repo_root>`; corrected the
  accompanying no-argument-form SKIP claim to state the consumer-repo-vs-source-store-repo
  distinction; added a cross-reference to the script header's `TARGET_REPO CONTRACT`.
- `.claude/**` (deployed tree) — regenerated via `deploy-headless.sh` to carry all of the above.

## Decisions

- The new header paragraph refers to "the paragraph above" rather than repeating the literal
  string "INVOCATION CONTRACT", preserving the plan's `grep -c 'INVOCATION CONTRACT' == 1`
  verification criterion while still satisfying the task's "separate axis" framing requirement.
- The corrected `plan-format.md` sub-case (b) invocation keeps `.claude/scripts/verify-deploy.sh`
  (the deployed entry point) rather than a source-store path, matching the style of the adjacent
  generic gate-subset bullet and consistent with the script's own INVOCATION CONTRACT (either
  entry point is valid once TARGET is correct).
- `regeneration-is-manual-only.md` stays a pointer: no new section was added, consistent with
  outcome 4's "header-alone authority plus pointers, never two partial copies" decision already
  made during planning.

## Plan Deviations

- **Phase 1 baseline-capture tasks** (altered): the plan's captured baseline assumptions (a
  non-empty `--findings` differential, ~76 lines of foreign uncommitted `verify-deploy.sh` work)
  no longer held at implement time — both conditions had been resolved by other work before this
  dispatch began. Recorded as `kind: win` via `issue-record.sh` rather than treated as a
  deviation requiring remediation.
- **Phase 2/3 differential-findings checks** (altered): editing the source store ahead of Phase
  4's redeploy produced one expected, self-resolving transient finding each time
  (`deployed script content drift` for the file just edited) that cleared once Phase 4 redeployed.
- **Phase 3 `index-entries.json` regeneration** (expected fallback, not a deviation): 6 of its 8
  regenerated `line_count` entries were pre-existing foreign uncommitted diffs unrelated to this
  task; the file was left entirely unstaged for Phase 3's commit per the plan's own anticipated
  branch, and Phase 4's redeploy re-ran the generator rather than losing the sync.
- **Phase 4's full-battery verification criterion** (altered): the dispatch file (generated after
  this plan) carried a `## Batch Gate Deferral` section directing this phase to discharge against
  a scoped tier and defer the unscoped full-battery exit-0 bar to the once-per-invocation
  batch-level stage. An independent unscoped run was attempted first and FAILed at gate 8, traced
  to a pre-existing, already-tracked test-corpus defect
  (`specs/476_isolate_seven_red_gate8_shell_suites`, itself citing completed task 275's proof
  that these suites fail identically on unmodified master) plus plausible interference from
  concurrently-active sibling-task dispatches in this same batch touching shared
  verify-deploy.sh/gate-selection test fixtures — not a regression introduced by this task. The
  dispatch-mandated scoped substitute (`verify-deploy.sh --skip-slow --only-gate 3,4,6,7,12,22`
  at the repo root) exits 0 clean, 7/7 PASS, none SKIP, both demonstrating the contract this task
  documents and confirming no regression within this task's own scoped tier.

## Verification

- Build: N/A (shell script + markdown edits)
- Tests: Passed — `bash -n` clean after every `verify-deploy.sh` edit; gate 22 (shellcheck)
  PASS throughout; the four `run-all.sh --only` suites mapped to the two edited markdown files
  pass 4/4 pre- and post-redeploy; the dispatch-mandated scoped gate set
  (`--only-gate 3,4,6,7,12,22`) exits 0, 7/7 PASS, none SKIP, post-redeploy.
- Files verified: Yes — deployed `.claude/scripts/verify-deploy.sh`,
  `.claude/context/formats/plan-format.md`, and
  `.claude/context/patterns/regeneration-is-manual-only.md` all confirmed to carry this task's
  changes verbatim after `deploy-headless.sh` reached `RESULT=landed_verify_clean`.
- Original cited defect: Resolved — `verify-deploy.sh --skip-slow --only-gate 3,4
  agent-system/extensions/core` (the invocation named in this task's CITATION) still exits 2 as
  expected (a source-store directory genuinely cannot be a TARGET), but its stderr now names the
  convention explicitly, and the one live document that prescribed that broken invocation
  (`plan-format.md:364`) no longer does.
- Unscoped full battery: not run to completion as this task's own gating criterion (deferred to
  the batch-level stage per the dispatch's Batch Gate Deferral section — see Plan Deviations).

## Impacts

- A future planner consulting `plan-format.md`'s `__FULL_SWEEP__` sub-case (b) now gets a
  copy-pasteable invocation that actually runs, instead of one that fails at gate0 before gate
  selection is even consulted.
- A reader of `verify-deploy.sh`'s header, or of a gate0 "no deploy tree" error against a
  source-store directory, now learns the TARGET-argument contract explicitly rather than having
  to infer it from the separate, true-but-adjacent invocation-CWD claim.
- No gate's pass/fail semantics changed (outcome 5 / this task's Non-Goal): every edit is a
  comment, a markdown sentence, or a pure `echo ... >&2` addition.

## Follow-ups

- The gate-8 shell-test-corpus defect this task's Phase 4 encountered (and deliberately did not
  widen scope to fix) is already tracked by the open task at
  `specs/476_isolate_seven_red_gate8_shell_suites/`; no new follow-up task is needed for it.
- `agent-system/extensions/core/index-entries.json` still carries 6 pre-existing foreign
  uncommitted `line_count` diffs unrelated to this task (observed throughout Phases 1, 3, and 4);
  this task did not commit that file and leaves those diffs for their owning task to resolve.

## References

- Plan: `specs/470_clarify_verify_deploy_target_contract/plans/01_two-axis-target-contract.md`
- Research: `specs/470_clarify_verify_deploy_target_contract/reports/01_target-contract-clarification.md`
- Progress files: `specs/470_clarify_verify_deploy_target_contract/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/470_clarify_verify_deploy_target_contract/handoffs/phase-{1,2,3}-handoff-*.md`
- Pre-existing test-corpus defect (encountered, not fixed here): `specs/476_isolate_seven_red_gate8_shell_suites/`
