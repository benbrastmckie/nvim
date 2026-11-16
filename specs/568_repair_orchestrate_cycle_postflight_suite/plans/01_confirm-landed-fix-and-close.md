# Implementation Plan: Task #568

- **Task**: 568 - Fix test-orchestrate-cycle-postflight.sh, which fails 25 of 304 assertions
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/568_repair_orchestrate_cycle_postflight_suite/reports/01_fixture-already-fixed-verification.md
- **Artifacts**: plans/01_confirm-landed-fix-and-close.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The defect this task was opened against no longer exists on `master`. The failing suite was
repaired by commit `a4e32ff9e`, which added `lib/project-number-inuse.sh` to
`test-orchestrate-cycle-postflight.sh`'s `setup_sandbox()` library-copy list — the single missing
hard dependency of `state-write.sh` that made every in-fixture status write fail silently. This
plan therefore carries **no production, test, or configuration change**. Its single phase
re-verifies the landed fix against live state (never on the research dispatch's word alone),
discharges the full gate set, and writes the closure summary that carries the disposition
durably.

### Research Integration

The research report establishes four facts this plan is built on, each of which was independently
re-confirmed at plan-authoring time against live state rather than carried forward on trust:

- Direct execution of the suite produces `Results: 312 passed, 0 failed`, exit 0 — re-run at
  plan time with the identical result. The description's "25 of 304" is **refuted**, and so are
  its two derived symptom claims (status-name mismatch, `persisted_status` drift): both were
  downstream of the sourcing failure, not independent defects.
- The addendum's `cleanup: command not found` shell error does not reproduce; it was a
  cascading symptom of the same single failure point.
- The task's own disposition question ("suite expectations wrong, or scripts' behaviour wrong?")
  resolves to **neither**. The defect was a fixture-completeness gap in the suite's own sandbox
  setup. `orchestrate-cycle-postflight.sh` and `update-task-status.sh` were never implicated —
  re-confirmed: neither has been touched since `9be017d79`, which predates nothing relevant here.
- Source-store and deployed copies of the suite are byte-identical (`diff -q`, exit 0,
  re-confirmed), and the suite has no uncommitted modification.

The independent corroboration the report cites (a prior unrelated investigation reproducing the
identical 25-failure count, the identical `state-write.sh: line 214` stderr line, and the
identical symptom shapes, then recommending exactly the change `a4e32ff9e` applied) is what
raises this from "one green run" to a settled disposition.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation
was performed.

## Goals & Non-Goals

**Goals**:
- Re-verify, by direct execution in the implementing dispatch, that the suite is green and that
  the fix commit is present and unmodified on `master`.
- Discharge the full gate set so the task closes on the same evidentiary footing as any other.
- Record the disposition (defect pre-resolved by an unrelated task's commit; no change made and
  none needed) in the task's closure summary, citing durable anchors — the commit sha, the
  suite filename, the library filename — rather than any ephemeral reference.

**Non-Goals**:
- **No change to the suite, to `orchestrate-cycle-postflight.sh`, to `update-task-status.sh`, or
  to any library.** Re-applying the landed fix is a no-op; deriving a *different* fix would
  diverge from the verified-correct one already on `master`.
- **No structural hardening of the fixture library-allowlist mechanism.** The hand-maintained
  allowlist rots whenever a sandbox-copied script gains a new `source` line, and that weakness is
  real — but it is a cross-suite structural concern, not this task's named suite, and it is
  already captured as an open, unowned recommendation in the prior investigation's report. A task
  that wants it should own it explicitly rather than have it smuggled in here.
- No re-litigation of the suite's expectations or the target scripts' behaviour: the disposition
  question is answered, and the answer is "neither was wrong."

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The suite is red again at implement time (a sibling's in-flight edit to a sandbox-copied collaborator reintroduces a library gap) | H | L | Phase 1 re-runs the suite first and treats a non-green result as a STOP: report it rather than silently patching, since per this cycle's territory note an unexpected failure outside this task's own `file_scope` may be a sibling's in-flight edit, not a regression here |
| Assertion count differs from 312 | L | M | The count is a hypothesis, not an acceptance criterion — see the phase's Scope Hypothesis. `0 failed` and exit 0 are the criteria; a changed total from a sibling adding assertions is not a failure |
| Closing with no diff looks like work was skipped | M | M | The summary states the disposition explicitly and cites `a4e32ff9e` plus the re-run evidence, so a future reader can verify the closure rather than infer it |
| The same fixture-allowlist rot recurs in this or another suite | M | M | Out of scope here by deliberate choice (see Non-Goals); the open recommendation naming the durable structural fix remains available to a task that will own it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel. This plan has a single phase, which is
therefore its final phase.

### Phase 1: Re-verify the Landed Fix and Close [COMPLETED]

**Goal**: Confirm against live state that the suite is green and the fix commit is intact, run
the full gate set, and write the closure summary recording that no change was made and none was
needed.

**Tasks**:
- [x] Re-run the suite directly and capture its trailing `Results:` line and exit status:
      `timeout 300 bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`.
      Acceptance is `0 failed` and exit 0. If it is non-green, STOP: check `git log` to confirm
      the change is not this task's own, then report the observation rather than patching —
      a sibling task is dispatched on this same working tree this cycle. *(completed: re-run
      produced `Results: 312 passed, 0 failed`, exit 0)*
- [x] Confirm the fix is present and unmodified: `grep -n "project-number-inuse"
      agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` shows the
      entry inside `setup_sandbox()`'s library-copy loop together with its explanatory comment,
      and `git log --oneline -1 -- <that suite path>` still reports `a4e32ff9e` as the most
      recent commit touching it with no uncommitted modification. *(completed: entry present
      with comment; `git log` confirms `a4e32ff9e` as the most recent commit, no uncommitted mod)*
- [x] Confirm the two scripts the task description named as candidate culprits
      (`orchestrate-cycle-postflight.sh`, `update-task-status.sh`) carry no change attributable
      to this task — their last commits predate this task's dispatch and nothing here touched
      them. *(completed: last commits `9be017d79` and `c5289cb1a` respectively, both predating
      this dispatch)*
- [x] Confirm source-store/deploy parity for the suite with `diff -q` against
      `.claude/scripts/tests/test-orchestrate-cycle-postflight.sh` (expect exit 0, byte-identical).
      *(completed: `diff -q` exit 0, byte-identical)*
- [x] Run the full gate set (see **Verification** below) and record its outcome. *(completed:
      per this dispatch's Batch Gate Deferral directive, discharged via the scoped narrowing
      `bash .claude/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh` — 1
      passed, 0 failed; the complete gate set is deferred to the batch-level stage, see dispatch
      17's Batch Gate Deferral section)*
- [x] Write the closure summary at the path named under **Files to modify**, stating: the
      disposition (fixture-completeness gap, not a suite-expectation or production-code defect);
      that the fix landed via commit `a4e32ff9e` before this task reached implementation; the
      re-run evidence; and that zero source files were changed by this task. Cite the commit sha,
      the suite filename, and `lib/project-number-inuse.sh` as the durable anchors. *(completed)*
- [x] Record an issue-log entry for the premise refutation (`--kind issue --class
      "stale premise"`, severity `minor`) noting that this task's description was overtaken by an
      unrelated task's commit between task creation and dispatch. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the suite reports exactly `312 passed, 0 failed` and
that this task changes **zero** files outside `specs/568_repair_orchestrate_cycle_postflight_suite/`.
Both are hypotheses to confirm at implementation time, not facts to assume. Confirm the first by
reading the suite's own trailing `Results:` line from the live re-run — a *total* other than 312
is acceptable if a sibling legitimately added or removed assertions, since the binding criterion
is `0 failed` and exit 0, not the total. Confirm the second with `git status --short` plus a read
of the staged diff before committing: anything staged outside this task's `specs/` directory
contradicts the hypothesis and must be investigated (possibly a sibling's edit) rather than
committed.

**Files to modify**:
- `specs/568_repair_orchestrate_cycle_postflight_suite/summaries/01_confirm-landed-fix-and-close-summary.md` - created: the closure summary recording the disposition, the re-run evidence, and the zero-change outcome

**Verification**:
- The suite's own run: `0 failed`, exit 0.
- The full gate set for the repository, per the `full` tier:
  `bash .claude/scripts/verify-deploy.sh` — run from the repository root (which is
  simultaneously the deploy consumer and the source store), with no gate narrowing. Neither
  `--only-gate` nor `--only` is used here: this is the final phase, and a narrowed pass is never
  read as equivalent to the full run it replaces.
- `grep` confirms `project-number-inuse.sh` is present in the suite's library-copy loop.
- `diff -q` confirms source-store/deploy byte-identity for the suite.
- `git status --short` shows no modification staged outside this task's `specs/` directory.
- The closure summary file exists, is non-empty, and names commit `a4e32ff9e`.

---

## Testing & Validation

- [ ] `test-orchestrate-cycle-postflight.sh` executes standalone with `0 failed` and exit 0.
- [ ] The suite's two in-built invariants both pass: the real source-store
      `orchestrate-cycle-postflight.sh` is byte-identical before and after the run (the fixture
      never writes the real source store), and no `*.anchor-bak` file survives under the
      source-store scripts directory.
- [ ] No `source: No such file or directory` line — the original failure's stderr signature —
      appears anywhere in the suite's output.
- [ ] `bash .claude/scripts/verify-deploy.sh` completes with its gates green.
- [ ] The working tree carries no change outside this task's own `specs/` directory.

## Artifacts & Outputs

- `specs/568_repair_orchestrate_cycle_postflight_suite/summaries/01_confirm-landed-fix-and-close-summary.md`
  — the closure summary.
- An issue-log entry in this task's `issues.jsonl` recording the premise refutation.
- No source, test, or configuration file is created or modified.

## Rollback/Contingency

Rollback is trivial because the plan writes no source file: the only artifact produced lives
under this task's own `specs/` directory, and discarding it reverts the task completely.

Contingency, if the suite is **not** green at implementation time: do not patch it from within
this task. Per this cycle's territory note, a failure in a file outside this task's own
`file_scope` may be a sibling's in-flight edit rather than a regression here. Check `git log`
first to confirm the change is not this task's own; if a foreign commit, a foreign uncommitted
modification, or a build this dispatch did not start is observed, STOP and report it. If the
suite is genuinely red again from a newly reintroduced fixture gap, that is a materially
different defect from the one this task was opened against, and it warrants its own research
round rather than an improvised fix appended to a closure plan.
