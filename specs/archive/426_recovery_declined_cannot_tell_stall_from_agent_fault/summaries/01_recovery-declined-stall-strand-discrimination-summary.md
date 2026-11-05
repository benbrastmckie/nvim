# Implementation Summary: Narrow RECOVERY_DECLINED so an abandoned wrap-up is not filed as a blocking agent fault

- **Task**: 426 - RECOVERY_DECLINED cannot tell stall from agent fault
- **Status**: [COMPLETED]
- **Started**: 2026-10-18T02:00:00Z
- **Completed**: 2026-10-18T04:30:00Z
- **Effort**: ~5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_recovery-declined-stall-strand-discrimination.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-cycle-postflight.sh`'s absent-handoff RECOVERY_DECLINED case arm recorded a
blocking, agent-attributed defect without consulting the stall/strand signals the same script
computes much later, and the adjacent `issue-record.sh` call hardcoded `--phase implement` and
passed a structurally-always-empty `--dispatch-seq`. This implementation fixes both recording
bugs, closes a test-sandbox gap that made the `issues.jsonl` side of this path unassertable, and
adds a record-time, arm-local consultation of the stall/strand signals so a reader can tell an
abandoned wrap-up (work intact, remedy is one re-prompt) from an uncorroborated agent-contract
violation — without touching either canonical signal's own trigger expression.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — the RECOVERY_DECLINED
  arm's `issue-record.sh` call now passes `--phase "$phase"` (the real dispatch phase) instead
  of a literal `implement`, and `--dispatch-seq "$expected_dispatch_seq"` (this cycle's own
  minted seq) instead of the always-empty `$handoff_dispatch_seq`. The arm also computes two
  arm-local, record-time-only values (`rd_stall_corroborated`/`rd_stall_commit_count` and
  `rd_strand_corroborated`/`rd_strand_verdict`), appends a three-branch corroboration clause to
  `recovery_declined_detail` (reaching the stderr notice, `system-defect-record.sh --message`,
  the loop-guard row, and `issue-record.sh --what-happened` with no further plumbing), and adds
  a `--tags-json` object (`stall_corroborated`, `stranded_corroborated`, `stall_commit_count`,
  `strand_verdict`) built via `jq -n --argjson`. The canonical `stall_suspected`,
  `stranded_suspected`, and `strand_probe_verdict` blocks are byte-identical — confirmed by
  `git diff` showing every hunk confined to the RECOVERY_DECLINED arm's own span.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` —
  `issue-record.sh` added to both the `require_file` loop and `setup_sandbox`'s `cp` loop
  (previously absent, making every RECOVERY_DECLINED fixture's issue call a silent no-op); new
  fixtures (I2) (regression pin for the cited incident, `--phase plan`), (J1)/(J2) (VERIFY 3:
  stall-corroborated vs. not, `--phase plan`), (J3) (VERIFY 3: strand-corroborated, multi-task
  engine), and a VERIFY (4) non-widening lexical pin scoped to each canonical field's own
  few-line block. Direct run: 296 passed, 0 failed (up from 281 pre-existing).
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — one sentence
  added to the `RECOVERY_DECLINED` registry row noting the record-time corroboration and that it
  is a pre-WORK-(i) snapshot that can legitimately differ from the later-emitted
  `stall_suspected`/`stranded_suspected` fields.

## Decisions

- Computed arm-local, separately-named `rd_stall_*`/`rd_strand_*` values rather than hoisting
  the canonical computations earlier and removing the later ones (the report's primary
  recommendation): WORK (i)'s per-task commit lands between the two points, so a hoist-and-remove
  would silently change the canonical fields' emitted values — against this task's non-widening
  posture even though technically a narrowing. The arm-local values also happen to be *more*
  accurate for attribution, since at record time no postflight-authored commit exists yet.
- Fixture (J3) (the strand variant) was built on the multi-task engine, not the single-task
  engine the sibling fixtures use: a single-task `--loop-guard-file` dispatch structurally
  cannot observe a stranded verdict at the record site, because WORK (b)'s unconditional
  `orchestrate-loop-guard-init.sh --clear-pending` call rewrites any pre-existing
  `.orchestrator-loop-guard` file early in every postflight invocation, defeating
  `dispatch-strand-probe.sh`'s artifact-quiescence leg regardless of backdating. This mirrors
  the canonical `stranded_suspected` T1 fixture's own precondition. Filed as a separate,
  non-blocking follow-up issue (see Follow-ups).
- VERIFY (4)'s non-widening pin greps each canonical trigger expression's own few-line block
  (scoped via `sed`) rather than the whole file, because Phase 3's own arm-local `rd_stall_*`
  computation deliberately reuses the identical conjunction text at the record site (as
  directed), which a bare whole-file "exactly once" grep cannot distinguish from an actual
  widening.
- Confirmed by inspection that `docs/architecture/handoff-schema.md`'s Postflight Boundary
  section, `context/patterns/infra-failure-discrimination.md`, and
  `agents/planner-agent.md`'s terminal-write contract all still need no edit: the script
  continues to only compute and emit signals, never dispatch anything; the agent contract
  already states the terminal write as a MUST; and `infra-failure-discrimination.md` makes no
  mention of either signal.

## Plan Deviations

- **Task 1.verify**: Phase 1's stated verification grep (`grep -n -- '--phase implement' ...`
  returns nothing) does not hold literally — 4 other, out-of-scope call sites also hardcode
  `--phase implement` but are correctly scoped to implement-only code paths (explicitly excluded
  by the plan's Non-Goals). Re-verified instead via `git diff` scope check.
- **Task 4.strand-variant**: built fixture (J3) on the multi-task engine instead of the
  single-task engine the sibling fixtures use (see Decisions above).
- **Task 4.verify4**: VERIFY (4)'s pin scoped per-block via `sed` rather than a bare whole-file
  grep (see Decisions above).

## Verification

- Build: N/A (shell scripts)
- Tests: `run-all.sh --only test-orchestrate-cycle-postflight.sh` — green at every phase; direct
  run 296 passed, 0 failed. All four VERIFY items pinned by fixtures proven to bite via
  deliberate-break-and-restore checks. `git diff` confirms the canonical
  `stall_suspected`/`stranded_suspected`/`strand_probe_verdict` blocks are byte-identical.
- Files verified: Yes — `bash -n` on the edited script at every phase; deploy diff confirms zero
  drift between the source store and the deployed copy for every file this task touched.
- Full gate set (`run-all.sh`, `verify-deploy.sh`): deferred to the batch-level stage per this
  dispatch's Batch Gate Deferral directive (this task is one of several `implement`-phase
  dispatches inside one multi-task `/orchestrate` batch invocation). `deploy-headless.sh` was
  run at Phase 5 and landed the deploy cleanly; its own fast-gate verify pass reported 3 of 37
  checks failed, all three timeout kills under host load on gates unrelated to this task's
  changed files (see Follow-ups) — Phase 5's own verification was discharged against the scoped
  suite instead, per the deferral.

## Impacts

- A future RECOVERY_DECLINED `issues.jsonl` entry and defect record now carry the dispatch's
  real phase and a non-null `dispatch_seq`, so phase-based triage over `issues.jsonl` and
  dispatch-seq-keyed consumers no longer see corrupted values for this defect class.
- A reader of a RECOVERY_DECLINED record (human or downstream tooling reading `--tags-json`) can
  now distinguish an abandoned-wrap-up or heartbeat-strand occurrence (work intact, one-re-prompt
  remedy) from an uncorroborated agent-contract violation, without the classification itself
  changing — every RECOVERY_DECLINED occurrence remains `blocking` severity.

## Follow-ups

- Filed in this task's `issues.jsonl` (severity minor): a single-task dispatch using
  `--loop-guard-file` can never legitimately observe `stranded_suspected=true` (nor this task's
  new `rd_strand_corroborated`) at any point after WORK (b)'s unconditional
  `orchestrate-loop-guard-init.sh --clear-pending "$TASK_DIR"` call, since it rewrites a
  pre-existing `.orchestrator-loop-guard` file early in every postflight invocation and defeats
  `dispatch-strand-probe.sh`'s artifact-quiescence leg — a structural, engine-dependent property
  of the production script, not something this task's own changes introduced or can fix within
  its stated scope.
- Filed in this task's `issues.jsonl` (severity minor, resolution deferred): `deploy-headless.sh`'s
  own fast-gate verify pass hit 3 timeout kills (gate4/check-task-references.sh,
  gate6/an agent-contracts-adjacent check, gate10/validate-state.sh --deep) under host load at
  Phase 5 — none touching this task's files. The full gate set still runs once at the batch
  level; a retry may be needed if host load persists.
- The plan's Non-Goals explicitly excludes fixing the sibling `handoff_dispatch_seq` call sites
  at the successful-recovery path (lines ~1301/1335/1421/1442/1503 pre-edit), which share
  DEFECT C's structural pattern but sit outside this task's stated scope — already recorded as a
  follow-up in this task's `issues.jsonl` by the planner.

## References

- Plan: `specs/426_recovery_declined_cannot_tell_stall_from_agent_fault/plans/01_recovery-declined-stall-strand-discrimination.md`
- Report: `specs/426_recovery_declined_cannot_tell_stall_from_agent_fault/reports/01_recovery-declined-stall-strand-discrimination.md`
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the
  `RECOVERY_DECLINED` registry row this task annotates
