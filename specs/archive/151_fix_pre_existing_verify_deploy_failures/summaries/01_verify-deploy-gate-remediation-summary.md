# Implementation Summary: Fix the two pre-existing verify-deploy gate failures

- **Task**: 151 - Fix the two pre-existing verify-deploy gate failures (state-writer boundary, whole-tree orphan)
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T21:24:00Z
- **Completed**: 2026-09-07T22:25:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_verify-deploy-gate-remediation.md
- **Standards**: summary-format.md, status-markers.md, artifact-formats.md, source-store-deploy-boundary.md

## Overview

Both pre-existing gate failures named in the dispatch were confirmed and closed. FAILURE 1 (gate
12, state-writer boundary lint) was already remedied on disk by an earlier commit
(`89f575aed`); this task independently re-confirmed it green from live re-runs and recorded the
remedy decision. FAILURE 2 (gate 13, whole-tree orphan detection) currently reports 0 findings
and the original finding is not reproducible; this task fixed the concrete defect that made that
identity unrecoverable in the first place — gates 13 and 5 told the operator to "re-run without
`--quiet` for detail" while their per-finding lines were appended only under `--findings`, so a
plain non-quiet re-run printed nothing extra. That defect is now fixed for both gates. A full
`bash .claude/scripts/verify-deploy.sh` run reports `PASS -- 29 check(s), 0 failure(s)`, and
`deploy-headless.sh` exits 0.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` — gate 5 and gate 13 failure branches
  now print each extracted finding line (`VERIFY_FINDING` / `ORPHAN_FINDING`) to the
  operator-visible stderr stream unconditionally on failure, not only when `--findings` is
  passed. Both gates' `fail()` hint strings were corrected from the false, self-referential
  "re-run without `--quiet` for detail: bash verify-deploy.sh" to accurate text. The existing
  `--findings` `FINDINGS_LIST` population is unchanged in shape — same `FINDING gateN <detail>`
  entries, same exit code, same `CHECKS`/`FAILURES` accounting. Purely additive.
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` — new "Fail-time
  detail output" subsection recording the fix, so the existing measurement recipe is understood
  as a follow-up classification tool rather than the only way to learn a finding occurred.
- `agent-system/extensions/lean/index-entries.json` — corrected `comparator-integration.md`'s
  stale `line_count` declaration (219 → 247), synchronizing it to the file's actual length.
- `agent-system/extensions/core/index-entries.json` — corrected `deploy-orphan-detection.md`'s
  `line_count` declaration (115 → 130), reflecting the new subsection added by this task.
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` — no edit; the regression
  comment naming the boundary contract was already present from commit `89f575aed` and needed
  no change (Phase 1 confirmed rather than modified).

## Decisions

**FAILURE 1 remedy (gate 12, state-writer boundary lint)**: the correct remedy, already applied
by commit `89f575aed` prior to this task, is option **(a)** — route all four hand-rolled writes
in `test-force-phases.sh` through the sanctioned `state-write.sh` writer — applied uniformly
across all four sites (including the two shapes the dispatch flagged as possibly deserving
different answers: the real `specs/state.json` path at line 261 and the `$WORKDIR/specs/state.json`
scratch paths at lines 312/323/334). Reasoning: the test fixture already copies `state-write.sh`
and its full dependency chain into `$WORKDIR/.claude/scripts/`, and `state-write.sh` resolves its
own `PROJECT_ROOT` from its invoked path — so the sanctioned writer self-targets whichever root
invokes it (real repo root for line 261's setup call, scratch `$WORKDIR` for the other three)
with zero additional plumbing. Options **(b)** (scoped allowlist entry) and **(c)** (narrow the
lint's own detection for non-`specs/` scratch paths) were live, mechanically supported choices —
the lint already has a file-level allowlist mechanism used elsewhere — and were rejected on the
merits: both would have left the suite exercising a *different* code path than the production
callers it is meant to regression-test, silently weakening the fixture's fidelity to real
`update-task-status.sh` behavior. Routing through the real writer costs nothing here and keeps
the test suite honest about what it verifies.

Verbatim evidence collected in Phase 1: `lint-state-writer-boundary.sh --verbose` — Files
checked: 1075, Candidate lines exempted: 22, Total violations: 0.
`test-force-phases.sh`: 19 passed, 0 failed. `test-lint-state-writer-boundary.sh`: 8 passed, 0
failed. All four call sites (lines 265, 312, 323, 334) confirmed to invoke
`"$WORKDIR/.claude/scripts/state-write.sh"`, with no residual `jq ... > tmp && mv` pattern
anywhere in the file.

**FAILURE 2 outcome (gate 13, whole-tree orphan detection)**: a direct re-run of the gate's
`find_orphans` detection reports `ORPHAN_DONE checked=5353` with 0 `ORPHAN_FINDING` lines,
matching the research report's prior observation exactly. **The original single finding's
identity was never captured at the time of the multi-task `/orchestrate` batch failure and is
not reproducible on demand** — this is stated plainly rather than obscured. Research's
falsifiable hypothesis (a transient declared/deployed mismatch from a concurrent multi-task
batch, fitting the "uncommitted source-store working-tree artifact" exclusion class in
`deploy-orphan-detection.md`) remains untested by this task; 0 findings now neither confirms nor
refutes it. A future occurrence would confirm the hypothesis if the finding path corresponds to a
file with no commit yet at the moment of failure (`git status` shows it new/modified); it would
refute the hypothesis if the finding is a genuinely undeclared file with no owning extension at
all.

One correction to the dispatch's own framing is recorded here: the dispatch asked this task to
note the untracked `agent-system/extensions/literature/scripts/literature-pyenv/` path as "a
concrete live example of the 'uncommitted source-store working-tree artifact' class". On
inspection, `deploy-orphan-detection.md`'s own exclusion-class table already names this exact
path pattern (`scripts/literature-pyenv/venv/**`) under a *different*, pre-existing class —
**Runtime artifact** (provisioned at first use by `literature-pyenv-provision.sh`, `.gitignore`d
at the project root, never part of any `provides.*` list) — not the uncommitted-source-store
class the dispatch's task text hypothesized. This is recorded as a correction rather than forced
to fit the original guess.

**The substantive FAILURE 2 remedy** is the diagnosability fix in
`agent-system/extensions/core/scripts/verify-deploy.sh`: gates 13 and 5 previously told the
operator "re-run without `--quiet` for detail", but the per-finding `ORPHAN_FINDING` /
`VERIFY_FINDING` lines were appended only to the `--findings`-gated `FINDINGS_LIST` array and
printed nowhere else — the hint was false, and this is precisely why the original finding's
identity was unrecoverable after the fact. Both gates now print every finding line to the
operator-visible stderr stream unconditionally on failure, and both hint strings were corrected
to describe the actual behavior. The change is additive only: no exit code, no
`CHECKS`/`FAILURES` accounting, and no `--findings` output shape changed — confirmed by diff
review and by re-running `test-deploy-verify-wiring.sh` (9/9), `test-postflight-deploy-gate.sh`
(19/19), and `test-deploy-orphans.sh` (5/5), the three direct-dependent test suites identified by
grepping the source store for `verify-deploy.sh` consumers.

An end-to-end check confirmed the fix directly: with a deliberately planted undeclared file
(`.claude/context/__orphan-probe-151.md`) and trap-guarded cleanup, the gate-13 logic (exercised
via the real script's own `say`/`pass`/`fail` functions against a live `find_orphans` run) printed
`- orphan file: context/__orphan-probe-151.md` in its failure output with `FINDINGS_LIST` left
empty (since `--findings` was not passed) — exactly the target behavior. After cleanup, detection
returned to 0 findings (`checked=5353`) with `git status --short` showing no leftover probe.

**Phase 4 residual failure**: after redeploying with the Phase 3 fix in place, the full gate
suite reported exactly one residual failure — gate 3 doc-lint — with **two** stale
`line_count` declarations, not the single one the plan hypothesized:
`agent-system/extensions/lean/index-entries.json`'s `comparator-integration.md` entry (declared
219, actual 247 — the plan's hypothesized drift, pre-existing) and
`agent-system/extensions/core/index-entries.json`'s `deploy-orphan-detection.md` entry (declared
115, actual 130 — caused by this task's own Phase 3 documentation edit, discovered only once the
full doc-lint ran). Both were confirmed not concurrently owned by another in-flight task (clean
`git status --short`, no conflicting recent `git log` entries — the core mismatch traces directly
to this task's own commit), so decision-rule branch **(a)** applied to both: corrected via the
sanctioned `generate-context-line-counts.sh --write` tool, which recomputes `line_count` from
`wc -l` for every entry across all 20 extensions and reported exactly these 2 changes out of 502
total entries. This synchronizes declarations to reality and weakens no check.

## Plan Deviations

- **Phase 2, task 5** (note the untracked `literature-pyenv` path as an "uncommitted
  source-store working-tree artifact" example): altered. The path is already an explicitly named
  example of the pre-existing **Runtime artifact** exclusion class in
  `deploy-orphan-detection.md`'s own table, not the class the plan hypothesized. Recorded
  honestly as a correction rather than forced to match the guess.
- **Phase 4, task 3** (decision-rule branch (a), scope hypothesis of exactly one residual
  mismatch): altered. Two stale `line_count` declarations were found and corrected, not one —
  the second (`core/deploy-orphan-detection.md`) was introduced by this task's own Phase 3 edit
  and only surfaced once the full gate suite ran post-redeploy. Both fit decision-rule branch (a)
  identically (neither file was concurrently owned by another in-flight task), so both were
  corrected with the same sanctioned tool in the same pass.
- No other deviations. All other plan tasks completed as written.

## Verification

- Build: N/A (no build step for this task type)
- Tests: `test-force-phases.sh` 19/19, `test-lint-state-writer-boundary.sh` 8/8,
  `test-deploy-verify-wiring.sh` 9/9, `test-postflight-deploy-gate.sh` 19/19,
  `test-deploy-orphans.sh` 5/5 — all passed
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` — clean
- `bash .claude/scripts/verify-deploy.sh` (full, non-quiet) — `PASS -- 29 check(s), 0
  failure(s)`, with gate 12 and gate 13 both confirmed `[PASS]` explicitly
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` — exits 0
- Files verified: Yes

## Regression Notes

1. **FAILURE 1 (state-writer boundary) cannot silently re-break**: `lint-state-writer-boundary.sh`
   runs over the *entire* source store on every `verify-deploy.sh` invocation (gate 12), so any
   future hand-rolled `jq ... > tmp && mv` write against `state.json` anywhere in
   `agent-system/extensions/**` is caught immediately, not just in the four sites fixed here.
   `test-lint-state-writer-boundary.sh` additionally pins the lint's own detection behavior (its
   positive/negative/exempt cases), so a future change to the lint itself that weakened detection
   would fail that suite before ever reaching a real repo.
2. **FAILURE 2's diagnosability cannot silently re-break**: gate 13 (and gate 5) run on every
   redeploy checkpoint, and their failure branches now print every finding unconditionally —
   there is no `--quiet`/`--findings` toggle left to silently suppress the detail again, since
   the print statement is unconditional in the failure branch itself, not gated behind a flag
   check. `test-deploy-orphans.sh`'s scratch-tree regression (Assertions A-E) continues to prove
   the underlying detector still fires on planted orphans and stays silent on each exclusion
   class; this task changed only how the shell wrapper surfaces an existing finding, not the
   detector's classification logic.
3. **The two `line_count` corrections cannot re-drift silently for the same reason twice**:
   `check-extension-docs.sh` (invoked by gate 3 on every `verify-deploy.sh` run) already re-checks
   every entry's `line_count` against `wc -l` on the actual file; this task did not add new
   detection, it corrected the two stale declarations that detection was already, correctly,
   flagging. The underlying class of problem — that any future doc edit re-drifts its own
   `line_count` declaration and blocks an unrelated task's gate — is explicitly out of this
   task's scope; the sibling task on line_count/gate-coupling brittleness addresses that class.

## Impacts

- No detection logic, exclusion class, or allowlist was loosened anywhere in this task — gates 5
  and 13's fix is strictly additive output; the `line_count` corrections synchronize declarations
  to reality rather than changing what is checked.
- Future `verify-deploy.sh` gate-5 or gate-13 failures are now diagnosable from the first
  observation, closing the exact gap that made this task's own FAILURE 2 investigation
  inconclusive.
- The redeploy performed in Phase 4 flagged several downstream consumer repos (BimodalLogic,
  ModelChecker, Logos/Theory, PossibleWorlds, and others) as `STALE` relative to the updated
  source store — this is `deploy-headless.sh`'s existing, expected staleness report for any
  source-store change and requires no action from this task; each consumer repo redeploys
  independently when its own maintainer chooses to.

## Follow-ups

- None required to close this task. The sibling task addressing the `line_count`/gate-coupling
  problem as a *class* (why an unrelated pre-existing lint failure can gate every task's
  completion) remains a separate, non-blocking piece of work per the dispatch's own framing.

## References

- `specs/151_fix_pre_existing_verify_deploy_failures/plans/01_verify-deploy-gate-remediation.md`
- `specs/151_fix_pre_existing_verify_deploy_failures/reports/01_verify-deploy-gate-failures.md`
- `specs/151_fix_pre_existing_verify_deploy_failures/progress/phase-1-progress.json` through
  `phase-4-progress.json`
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`
