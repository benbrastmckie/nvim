# Implementation Summary: Task #260

- **Task**: 260 - Fix self-clobbering redeploy in cycle-plan
- **Status**: [COMPLETED]
- **Started**: 2026-09-25T00:00:00Z
- **Completed**: 2026-09-25T03:45:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None (the sibling redundant-verify-deploy-passes task depends on THIS one)
- **Artifacts**: plans/01_function-wrap-deploy-callers.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the mid-execution self-overwrite hazard in `agent-system/extensions/core`'s two genuine
`deploy-headless.sh` call sites (`orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint and
`command-gate-out.sh`'s `rc==6` branch) by generalizing the mitigation `deploy-headless.sh` already
applies to itself: wrap everything from the deploy call through true EOF inside one top-level
function, invoked as the file's last physical statement. Added a red-first regression test that
deterministically reproduces the hazard via a synthetic mid-run self-rewriting stub, a mechanical
lint that structurally enforces the wrap for any future caller, and documentation corrections
recording the fix and the decision the sibling redundant-verify-deploy-passes task depends on.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — wrapped everything from the
  Inter-Cycle Redeploy Checkpoint through true EOF inside `orchestrate_cycle_plan_main() { ... }`,
  invoked bare (no argument forwarding) as the file's last physical statement; added a
  `SELF-OVERWRITE HAZARD` header note.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — wrapped everything from just after
  the two top-of-file `source` lines through true EOF inside `command_gate_out_main() { ... }`,
  invoked with `"$@"` (the body reads `$1`/`$2`/`$3`); added a matching header note.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — added
  `write_g11_self_rewriting_deploy_stub` (a deploy-headless.sh stub that truncate-rewrites the
  staged SUT in place, mid-run, with a byte-shifted copy of itself) and `g11_setup_dispatch_candidate`
  (a fixture with a real, non-terminal candidate so a case can assert a genuine `.dispatch` row
  survives), plus two new Group 11 cases: `(t)` (deploy-landed, exit 3) and `(u)` (deploy-failure,
  exit 1) — named `(t)`/`(u)` rather than the plan's originally-proposed `(s)`/`(t)`, since the
  sibling redundant-verify-deploy-passes task's own already-landed work had already claimed letter
  `(s)` in the same Group 11 block.
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` — new suite: a
  mechanical class guard that re-derives, from file contents, every GENUINE `deploy-headless.sh`
  invocation site across `agent-system/extensions/*/scripts/**/*.sh` (never a hardcoded list) and
  structurally verifies the wrap; asserts `deploy-headless.sh` itself independently; self-tests
  against a deliberately-unwrapped scratch copy.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — added a
  "Structural precondition" paragraph to both `Automated Exception` subsections.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — added bullet
  `(iii-a)` distinguishing the two replacement-exposure sub-cases, and a new
  "Self-overwrite mitigation, and the decision the sibling ... task depends on" paragraph in the
  `### The Inter-Cycle Redeploy Checkpoint` subsection.

## Decisions

- **Function-wrap (not re-exec, not a source-store invocation swap, not deferral) was chosen.**
  Candidate (b) (invoke the source-store `deploy-headless.sh`) was rejected on mechanism: it only
  changes which deployer binary runs, not the CALLER, which is still the deployed, still-executing
  script being overwritten. Candidate (c) (defer the deploy) was rejected on contract cost: it
  splits one invocation into two and breaks the in-band `deploy_exit` the three-branch failure
  contract depends on. Candidate (a) (re-exec from a copy) works but costs more here, since both
  call sites derive sibling paths from their own on-disk location.
- **The wrapped bodies were deliberately NOT re-indented**, to keep the diff reviewable as added
  brace/invocation/comment lines and preserve `git blame` continuity across ~1,700 and ~245-line
  regions respectively.
- **The mechanical lint verifies structure via a lone, unindented closing `}`**, not brace-counting
  — brace-counting is corrupted by literal `{`/`}` characters inside this codebase's many
  single-quoted jq program strings. This matches the exact convention this task's own two wraps
  (and `deploy-headless.sh`'s pre-existing `main()`) already use.
- **The checkpoint still invokes the DEPLOYED copy of `deploy-headless.sh`, unchanged.** This is
  the load-bearing decision the sibling redundant-verify-deploy-passes task depends on: today's
  fast (`--skip-slow`, internal to `deploy-headless.sh`) / full (this checkpoint's independent
  pre/post `verify-deploy.sh` snapshot pair) verify-depth split is completely untouched by this fix.

## Plan Deviations

- **Phase 1's cases `(s)`/`(t)`** were implemented as `(t)`/`(u)` instead: the sibling
  redundant-verify-deploy-passes task's own already-landed work had claimed letter `(s)` for an
  unrelated "WIDENED TRIGGER PREDICATE" case in the same Group 11 block before this task's
  implementation dispatch executed. Content and intent otherwise match the plan; the fixture was
  additionally strengthened with a genuinely eligible second candidate so the assertions cover a
  real, non-empty `.dispatch` row, not just a well-formed-but-empty JSON shape.
- **Phase 1's banner-size investigation** went further than the plan anticipated: an initial 64KB
  banner (a size that coincidentally re-aligns with a common internal read-buffer boundary)
  produced a false pre-fix PASS on the deploy-failure case, and a second, independent bug (the
  staged SUT was never reset between cases, so a prior case's rewrite compounded into the next)
  was found and fixed alongside it. See the phase 1 progress file's `approaches_tried` for the
  full investigation.

## Verification

- Build: N/A (bash scripts; `bash -n` clean on every edited file)
- Tests: `test-orchestrate-cycle-plan.sh` 285/285 pass; `test-lint-deploy-caller-wrap.sh` 7/7 pass
  (deterministic across 3 consecutive runs each); `test-force-phases.sh` 33/33;
  `test-orchestrate-cycle-postflight.sh` 127/127; `test-gate-out-repair-reporting.sh` 19/19;
  `test-postflight-deploy-gate.sh` 23/23; `test-deploy-baseline-lib.sh` 7/7;
  `test-deploy-orphans.sh` 5/5; `test-deploy-verify-wiring.sh` 20/20;
  `test-deploy-propagation.sh` 4/4. Full `run-all.sh` sweep: 90 passed, 5 failed, 0 skipped, 95
  total — the 5 failures were verified PRE-EXISTING via a detached git worktree checked out at
  this task's own pre-Phase-1 commit (identical failure signature there: a missing
  `return-meta-status-vocabulary.sh` shared library, an unrelated infra gap), confirming none is a
  regression this task introduced.
- Files verified: Yes

### Pre-fix failure text (Phase 1, verification requirement 1)

Both new regression cases failed, pre-fix, with the SUT exiting 2 and stderr containing:
```
ERROR: orchestrate-cycle-plan.sh: --state-file is required.
```
plus the full usage banner — i.e. execution resumed at a stale byte offset that landed back inside
the script's own argument-parsing logic, which then (correctly, from its own local perspective)
rejected the invocation as malformed. This is a different literal message than the live incident's
`line 998: o: unbound variable`, but the same root-cause class: bash resuming a rewritten file at a
stale offset and executing content that does not correspond to where it was before the rewrite.
Confirmed deterministic across 3 consecutive runs pre-fix (banner size 70KB, `$SUT` reset to
pristine before each case).

### Lint classification result (Phase 4, hazard-class survey)

Exactly 2 genuine `deploy-headless.sh` invocation sites found —
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (line 870) and
`agent-system/extensions/core/scripts/command-gate-out.sh` (line 192) — out of 194 scanned `.sh`
files under `agent-system/extensions/*/scripts/**` (excluding `tests/`); 15 files classified as
mention-only (comments, remedy/`echo`/`advisory`/`fail` strings, doc examples), including every
other file the dispatch's starting `grep -rln` list named
(`scripts/command-gate-out.sh`, `scripts/skill-base.sh`, `scripts/orchestrate-batch-admit.sh`,
`scripts/orchestrate-build-dispatch.sh`, `scripts/task-lock.sh`, `scripts/git-snapshot.sh`,
`scripts/validate-state.sh`, `scripts/verify-deploy.sh`,
`scripts/check-deploy-freshness.sh`, `scripts/check-consumer-freshness.sh`,
`scripts/system-defect-record.sh`, `scripts/measure-eager-context.sh`,
`scripts/check-extension-docs.sh` — all mention-only apart from `command-gate-out.sh` itself,
which IS genuine). `deploy-root-guard.sh` was in the starting list too and is also mention-only.
This matches the research pass's claim of exactly two genuine sites. `deploy-headless.sh` itself
independently satisfies the same structural rule via its own pre-existing `main()`.

### Sibling-task decision (Phase 5/6)

The checkpoint continues to invoke the DEPLOYED copy of `deploy-headless.sh`
(`$SCRIPT_DIR/deploy-headless.sh`), completely unchanged by this fix.
`deploy-headless.sh`'s own internal `--skip-slow` verify depth, and today's fast/full
verify-depth split (its own fast inline check vs. this checkpoint's independent full-depth
pre/post `verify-deploy.sh` comparison), are untouched. Recorded explicitly in
`batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint` subsection so the
redundant-verify-deploy-passes sibling task can build on this baseline directly.

### One-time residual exposure (Phase 6)

The very first deploy that lands this fix is itself triggered from the OLD, unprotected deployed
callers (the currently-deployed `.claude/scripts/orchestrate-cycle-plan.sh` and
`command-gate-out.sh` predate this fix until the next sanctioned automated redeploy propagates it).
If that specific deploy dies mid-run, re-running it is the expected remedy — every deploy after
that first one is protected, since the deployed copies will then carry the wrap. This is inherent
and one-time; no further action is needed.

## Impacts

- Both genuine `deploy-headless.sh` call sites in the source store now survive a redeploy they
  themselves trigger, closing the class of defect that lost an entire live `/orchestrate` batch
  cycle (empty plan JSON, zero dispatch rows, `cycle_count` stuck).
- A future third automated caller that invokes `deploy-headless.sh` without the same structural
  wrap will fail `test-lint-deploy-caller-wrap.sh` loudly, by file and line, rather than silently
  reopening this hazard class.
- The sibling redundant-verify-deploy-passes task has a recorded, load-bearing baseline (deployed
  copy unchanged, verify depth untouched) to build on without re-deriving it.

## Follow-ups

- None. The one-time residual exposure noted above requires no follow-up task — a re-run is the
  expected remedy if the very first post-fix deploy happens to die mid-run.

## References

- `specs/260_fix_self_clobbering_redeploy_in_cycle_plan/reports/01_self-clobbering-redeploy-hazard.md`
- `specs/260_fix_self_clobbering_redeploy_in_cycle_plan/plans/01_function-wrap-deploy-callers.md`
- `specs/260_fix_self_clobbering_redeploy_in_cycle_plan/progress/phase-{1..6}-progress.json`
- `agent-system/extensions/core/scripts/deploy-headless.sh` (the `SELF-OVERWRITE HAZARD` header
  this task's mitigation generalizes)
