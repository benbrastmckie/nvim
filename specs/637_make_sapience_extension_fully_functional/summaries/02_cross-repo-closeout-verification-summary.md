# Implementation Summary: Task #637

- **Task**: 637 - Make the sapience extension fully functional across loaded repositories
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T17:00:00Z
- **Completed**: 2026-11-17T18:00:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: 628, 635, 636 (all three completed)
- **Artifacts**: plans/02_cross-repo-closeout-verification.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed task 637's four goals as a cross-repo verification pass plus one new mechanism: a
standing `verify-sapience-mcp.sh` check (j) that detects a deployed repository whose core wiring
predates the postflight tagged-write path, two documentation sections recording previously
machine-measured-only facts into the durable design corpus, and a five-repository
redeploy-and-sweep proving each goal's disposition against a pre-change baseline. Goals 1 and 4
are now closed mechanically; goals 2 and 3 are reported as owned, out-of-repository residuals
with their mechanisms documented rather than claimed closed.

## What Changed

- `specs/637_make_sapience_extension_fully_functional/records/01_cross-repo-closeout-evidence.md` — Created. Full pre-change baseline across five repositories, the two acceptance bars re-read on the record, and (appended in Phase 4) the post-change sweep results and four per-goal disposition blocks.
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — New check (j): asserts, against a resolved project's deployed tree, that both postflight write scripts exist and are executable and that both core call sites (`orchestrate-cycle-postflight.sh`, `reconcile-task-status.sh`) carry a `postflight-sapience-notes.sh` invocation. FAILs naming the redeploy remedy; SKIPs when no deployed tree is reachable. Header/`--help` inventory extended to match.
- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` — Permission fix: `chmod +x` (was git mode `100644`, non-executable; its sibling `sapience-remember.sh` was already `100755`). Both call sites invoke it via `bash <path>` so this was not a functional break, but check (j) literally asserts the executable bit.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — New fixture cases 48-53 covering check (j): all-four-conditions-met (pass), each script missing/non-executable (2 fail cases), each core call site present-but-unwired (2 fail cases), and no deployed tree (skip). Header case inventory extended.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — New `### Capture Scheduling and the Manual-Only Trigger` subsection documenting the `sapience` launcher's dispatch to `extract_local.py`, the manual-by-design extraction model, and `~/.dotfiles`'s `services.sapience.backgroundSync` as the sole (default-off) scheduling lever; cross-referenced from the adjacent `### Capture/Activation Reconciliation` subsection.
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md` — Rewrote `## Verifying This Residual Is Still Current` to name the standing disposition of each of the three `verify-sapience-context-scoping.sh` outcomes (`residual holds` = expected green; `residual lifted` = revisit the Ruling; `inconclusive` = re-run) and to state explicitly that no local change can move the verdict.
- `agent-system/extensions/sapience/index-entries.json` — `line_count` reconciled for both edited context files (348→377, 157→178).
- Five repositories redeployed (no `--wipe`): `/home/benjamin/.config/nvim`, `/home/benjamin/.dotfiles`, `/home/benjamin/Projects/BimodalLogic`, `/home/benjamin/Projects/Sapience/sf1-engine`, `/home/benjamin/Projects/Sapience/sapience-app`.

## Decisions

- Applied the `postflight-sapience-notes.sh` permission fix at the source store (plus this
  repository's already-deployed copy) in Phase 2, rather than deferring it to Phase 4's redeploy,
  so Phase 2's own stated verification ("check (j) PASS in this repository today") could be
  checked directly instead of assumed.
- Ran `deploy-headless.sh` against this repository once during Phase 2 (ahead of Phase 4's formal
  five-repository sweep) specifically to land the check (j) edit into this repository's deployed
  tree for Phase 2's own verification; Phase 4's later five-repository run was unaffected
  (idempotent).
- Per this dispatch's Batch Gate Deferral directive, Phase 4's declared `full` verification tier
  was discharged against the scoped `run-all.sh --only test-sapience-mcp-registration.sh` suite
  plus `deploy-headless.sh`'s own unavoidable internal `verify-deploy.sh` call, rather than an
  independently re-invoked unscoped sweep — recorded in the plan's own Phase 4 Verification
  section.
- `sf1-engine`'s `landed_verify_red` redeploy result (an unrelated, pre-existing task-reference
  finding in a git-committed snapshot directory, `integration/claude-system/`, outside the live
  `.claude/` deploy tree) was recorded via `issue-record.sh` and reported rather than fixed — it
  is out of this task's sapience-extension scope, and the actual sapience deploy and all
  sapience-specific checks for that repository were independently confirmed green.

## Plan Deviations

- **Phase 2**: added a `chmod +x` fix to `postflight-sapience-notes.sh` (source store and this
  repository's deployed copy) and a one-repository `deploy-headless.sh` run, neither listed in
  the plan's Phase 2 task list but both necessary for Phase 2's own stated verification to hold.
  See `progress/phase-2-progress.json`'s `deviations` array.
- **Phase 4**: `sf1-engine`'s redeploy surfaced an unrelated, pre-existing `landed_verify_red`
  finding (see Decisions above); recorded and reported, not fixed, per the plan's own
  Rollback/Contingency guidance. See `progress/phase-4-progress.json`'s `deviations` array.
- No other deviations. All four phases otherwise followed the plan's task lists as written.

## Verification

- Build: N/A (no code build in this repository's sense)
- Tests: `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — 53/53 cases pass, including new cases 48-53; confirmed from the source store and via `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`.
- `bash -n` and `shellcheck` (via `.claude/scripts/lint/lint-shellcheck.sh --verbose`) report no new finding on either edited script.
- `bash .claude/scripts/generate-context-line-counts.sh --write` reconciled both edited context files; a second pass reports zero corrections.
- `bash .claude/scripts/check-task-references.sh` reports no new finding for either edited context file.
- `verify-sapience-mcp.sh` check (j) PASS and check (e) at 7 grants/5 hooks in all five swept repositories; the dry-run tagged-write reachability probe produced the correct `[repo:<slug>]` provenance in all five, with no non-dry-run write issued anywhere.
- Files verified: Yes (all new/edited files confirmed present, non-empty, and content-checked).

## Impacts

- A repository whose core deploy predates the postflight wiring will now FAIL check (j) by name
  with a redeploy remedy, rather than silently producing zero tagged notes for weeks before
  anyone notices.
- The two acceptance bars this task's description framed as open defects (goal 2's
  `RESIDUAL_HOLDS` probe outcome, goal 3's "capture sync is restored") are now documented as
  owned, out-of-repository residuals rather than left to be re-measured from live machine state
  each time the question comes up.

## Follow-ups

- Two user-owned levers remain open, both outside this repository's write surface, raised as a
  non-blocking `user_decision`: (1) whether to enable `services.sapience.backgroundSync` in
  `~/.dotfiles` for scheduled extraction (spends real money/CPU per run), and (2) whether to
  enable transcript capture for `BimodalLogic` and `sf1-engine`. Recommendation: leave both as
  they stand; neither is required to close any goal this plan addresses.
- `sf1-engine`'s `integration/claude-system/` snapshot directory carries a pre-existing
  task-reference finding, out of this task's scope; recorded via `issue-record.sh` for visibility,
  not actioned here.

## References

- Plan: `specs/637_make_sapience_extension_fully_functional/plans/02_cross-repo-closeout-verification.md`
- Records: `specs/637_make_sapience_extension_fully_functional/records/01_cross-repo-closeout-evidence.md`
- Research: `specs/637_make_sapience_extension_fully_functional/reports/02_scoping-and-remaining-gaps.md`, `specs/637_make_sapience_extension_fully_functional/reports/01_seed-audit-findings.md`
- Progress: `specs/637_make_sapience_extension_fully_functional/progress/phase-{1,2,3,4}-progress.json`
