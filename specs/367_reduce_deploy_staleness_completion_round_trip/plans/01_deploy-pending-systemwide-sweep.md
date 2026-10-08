# Implementation Plan: Task #367

- **Task**: 367 - Reduce the deploy-staleness completion round trip without weakening the completion-deploy gate
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/367_reduce_deploy_staleness_completion_round_trip/reports/01_deploy_pending_task_numbers_scope_gap.md
- **Artifacts**: plans/01_deploy-pending-systemwide-sweep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, git-staging-scope.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The automatic promotion of a deploy-pending task already exists and is already correct in every
mechanic (ledger force-run, unconditional `cycle_modified_files` accumulation, pre-eligibility
ordering, identical-dispatch streak-freeze, marker clearing on success). The single gap is its
**candidate set**: `run_post_deploy_reconcile_pass()` in
`agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` iterates only
`post_deploy_reconcile_json`, which `orchestrate-cycle-plan.sh:874` builds exclusively from the
current invocation's own `.task_numbers`. A task refused by the completion-deploy gate (exit 6)
is therefore structurally invisible to the automatic mechanism in every later invocation that does
not happen to name that exact task number again — which is what forced the hand-run
`reconcile-task-status.sh` remedy recorded in this repository's history.

The fix widens the **reach of that one already-sanctioned trigger's** promotion pass, entirely
inside the shared library: in addition to the existing invocation-scoped loop, sweep
`specs/state.json` for any non-terminal task whose own `.return-meta.json` carries
`deploy_pending: true`, and replay `reconcile-task-status.sh` for it. No new
`deploy-headless.sh` call site is added (the sweep never calls it), neither excluded file is
touched, and the gate in `update-task-status.sh` is not edited: safety is structural, because every
promotion path still runs through that unconditional, check-only gate, which simply re-refuses
(exit 6, no write) whenever the tree is genuinely stale.

### Research Integration

Key findings carried from `reports/01_deploy_pending_task_numbers_scope_gap.md` and re-verified
against the source store at plan-authoring time:

- Cause is a sharper variant of the dispatch's hypothesis **(b)**: the pass ran and would run
  again, but its candidate set never contained the stranded tasks. Re-verified:
  `scripts/orchestrate-cycle-plan.sh:874` reads `mt_get_json '.task_numbers'`.
- `run_post_deploy_reconcile_pass` is called **unconditionally every cycle**, outside every `if`
  the checkpoint's trigger logic opens (`scripts/orchestrate-cycle-plan.sh:1169`). The widened
  sweep therefore needs no new call site and takes effect on the very next `/orchestrate`
  invocation on any task.
- The documented-vs-mechanical divergence is resolved in the lint's favour:
  `context/patterns/regeneration-is-manual-only.md:138-143` still names
  `commands/implement.md` Step 4, a file that no longer exists in the source store. The
  mechanically enforced pair is `{orchestrate-cycle-plan.sh, command-gate-out.sh}`.
- `scripts/reconcile-task-status.sh`'s `implementing` branch (re-read at `:595-628`) promotes via
  `update-task-status.sh postflight ... implement --phase-check=refuse` once a `summaries/*.md`
  artifact exists and the handoff permits it — the exact shape a deploy-pending-refused task has.
  No edit to that script is currently expected (see Phase 2's Scope Hypothesis).
- `scripts/tests/test-postflight-deploy-gate.sh` is the structural model for the new fixture: it
  already builds an isolated repo with a fabricated `.claude-extensions.json`/source-repo pair
  whose HEAD can be advanced to make the tree provably STALE or left alone to make it FRESH.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no ROADMAP.md was loaded or consulted. The
dispatch's own binding constraint from ROADMAP Settled decision 10 (the sanctioned automated
deploy-trigger count stays at exactly two) is carried as a Goal and a Non-Goal below.

## Goals & Non-Goals

**Goals**:

- Remove the wasted dispatch cycle: a task whose completion write was refused with exit 6 records
  its completion automatically, with no hand-run `reconcile-task-status.sh`, on the next
  `/orchestrate` cycle regardless of which tasks that invocation names.
- Name the cause with evidence in the implementation summary (acceptance #1) — variant (b),
  candidate set bounded by `.task_numbers`.
- Produce a reproduction fixture that fails against the unmodified library and passes against the
  changed one (acceptance #2), plus a sibling case proving the gate still refuses against a
  genuinely stale tree with `state.json` unchanged (acceptance #4).
- Report a counted before/after of automated cycles from work-done to status-recorded
  (acceptance #3).
- Correct `context/patterns/regeneration-is-manual-only.md` so its documented pair matches what
  `scripts/tests/test-lint-deploy-caller-wrap.sh` mechanically enforces (acceptance #6).

**Non-Goals**:

- Weakening, softening, or editing the completion-deploy gate
  (`scripts/update-task-status.sh` PHASE 0.5). Excluded by the dispatch and by construction: any
  design whose effect is that a completion can be recorded against a stale deployed tree is
  rejected, not traded off.
- Adding a third automated `deploy-headless.sh` call site, or moving the existing inline call out
  of `orchestrate-cycle-plan.sh` (that move already correctly failed the lint and must not be
  re-attempted).
- Editing, patching, or special-casing `scripts/tests/test-lint-deploy-caller-wrap.sh`.
- Editing `scripts/orchestrate-cycle-postflight.sh`, `scripts/orchestrate-cycle-plan.sh`, or
  `scripts/update-task-status.sh` (all excluded, all contended).
- Editing `context/patterns/batch-orchestration-guardrails.md`. The research report recommends a
  follow-on invariant update there; the file is claimed by two other open tasks, so this plan
  records the needed wording in the library's own header comment instead and leaves the shared
  pattern document to its owners. (Recorded here so the omission is a decision, not a gap.)
- Editing `scripts/tests/run-all.sh` or `context/standards/shell-script-testing.md` — both are a
  concurrent sibling's declared territory; the new suite is picked up by `run-all.sh`'s existing
  `scripts/tests/test-*.sh` glob with no registration edit.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A system-wide sweep promotes a task that should not be promoted (wrong status, no real completion) | H | L | Candidate predicate is narrow and conjunctive: non-terminal status in `{implementing, partial}` AND `deploy_pending == true` in that task's own `.return-meta.json`. `reconcile-task-status.sh`'s own promotion table plus the `--phase-check=refuse` backstop remain the only promotion authority; the sweep adds no promotion logic of its own. |
| The sweep triggers `reconcile-task-status.sh`'s **demotion** path on an unrelated task | H | L | That path fires only for `researching`/`planning` with no artifact. The candidate predicate excludes both statuses, so no swept candidate can ever reach it. Verified by an explicit fixture case in Phase 3. |
| The sweep races a concurrent `/orchestrate` session that owns the stranded task | M | M | Before attempting a swept (out-of-batch) candidate, consult `task-lock.sh check`: proceed only on `free` (rc 0) or `held-stale` (rc 2); skip on `held-fresh` (rc 1) or resolution error (rc 3), failing CLOSED — the same exit-code gate `reconcile-task-status.sh:247-312` already uses for its own lock-aware decision. In-batch candidates keep today's behavior, protected by the checkpoint window's existing "no dispatch in flight" invariant. |
| A swept foreign task pollutes the batch's own reporting (`.completed_tasks` drives Move 4's Succeeded table and the `.dispatch/` cleanup set) | M | H if unguarded | `.completed_tasks +=` fires only when the promoted task is a member of `mt_get_json '.task_numbers'`; swept non-members are recorded only in `.post_deploy_reconcile_notices` with `scope: "swept"` and a distinct stderr line. Asserted by a fixture case. |
| Per-cycle cost of the sweep (one `state.json` scan plus one `.return-meta.json` read per non-terminal task, every cycle) | L | H | Same big-O as the loop it extends; the expensive part (`reconcile-task-status.sh` spawn) still fires only for genuinely deploy-pending candidates, normally zero. No pre-filter that duplicates gate logic is added. |
| New code runs under the caller's `set -euo pipefail` and aborts the cycle on a benign nonzero (missing file, `jq` miss) | M | M | Library is Class C (no `set` line, sourced). Every new command is explicitly guarded (`if`, `|| true`, `|| continue`), matching the existing loop's own `|| true` / `|| _pdr_rc=$?` idiom. shellcheck clean per `context/standards/shell-strict-mode.md`. |
| This task's **own** completion write will itself be refused with exit 6 (it modifies `agent-system/extensions/**`) | L | H | Expected and correct — it is the very defect being fixed. Do NOT hand-run a deploy or a reconcile to dodge it; let the sanctioned path (gate-out's `rc == 6` retry, or the next cycle's checkpoint) resolve it, and report the observed cycle count as acceptance #3's "before" datum. |
| Concurrent siblings are editing the same working tree this cycle | M | H | Per the dispatch's Territory block: re-read each file immediately before editing, stage only this task's own hunks with an explicit file list (never a directory or glob pathspec), never run `git-snapshot.sh` in reverting mode, and stop and report any foreign commit or foreign uncommitted modification. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Reproduction Harness and Pre-Fix Characterization [COMPLETED]

**Goal**: Stand up `scripts/tests/test-redeploy-checkpoint-promotion.sh` as an isolated,
fixture-driven suite that can drive `run_post_deploy_reconcile_pass()` directly, and record —
as measured evidence, not assertion — that the unmodified library promotes an in-batch
deploy-pending task but strands an out-of-batch one.

**Tasks**:

- [x] Re-read `scripts/tests/test-postflight-deploy-gate.sh:1-300` and copy its structural model:
      `mktemp -d` WORKDIR with an EXIT-trap cleanup, `pass()/fail()/info()` counters,
      `set -uo pipefail` (Class B per `context/standards/shell-strict-mode.md`), exit 0 all-pass /
      1 any-fail / 2 environment error. *(completed)*
- [x] Resolve the file under test **source-store-first** with a `REDEPLOY_CHECKPOINT_LIB`
      environment override (default: `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh`,
      fallback `.claude/scripts/lib/redeploy-checkpoint-lib.sh`). The override is what makes the
      fail-before/pass-after demonstration repeatable without ever committing a red suite — see
      Phase 3. *(completed)*
- [x] Build the fixture repo: source-store copies of `reconcile-task-status.sh`,
      `update-task-status.sh` and `lib/deploy-freshness-lib.sh`; deploy-tree copies of the
      unchanged dependency chain (`state-write.sh`, `task-lock.sh`, `generate-todo.sh`,
      `generate-task-order.sh`, `update-plan-status.sh`, `update-phase-status.sh`,
      `deploy-root-guard.sh`, `lib/common.sh`, `lib/phase-heading-patterns.sh`,
      `lib/status-vocabulary.sh`, `lib/file-scope-overlap.sh`, `lib/task-lookup-lib.sh`); a
      **stub** `git-commit-scoped.sh` that logs its argv and exits 0 (the suite must never commit). *(completed)*
- [x] Reuse the gate suite's `build_source_and_extensions` idiom for freshness control: a throwaway
      git source-repo plus a fabricated `.claude-extensions.json` whose recorded
      `source_git_head` is either current (FRESH) or deliberately behind (STALE). *(completed)*
- [x] Fixture two tasks, each with `status: "implementing"`, a `plans/01_*.md` with its single
      phase marked `[COMPLETED]`, a `summaries/01_*-summary.md`, an
      `.orchestrator-handoff.json` with `status: "implemented"`, and a `.return-meta.json`
      carrying `deploy_pending: true` plus `modified_files` overlapping
      `agent-system/extensions/**`. *(completed)*
- [x] Write the driver shim that sources the library under test and calls
      `run_post_deploy_reconcile_pass`, supplying exactly the globals it closes over:
      `dry_run=false`, `cycle_count`, `session_id`, `SCRIPT_DIR`, `STATE_FILE`, `PROJECT_ROOT`,
      `post_deploy_reconcile_json`, plus `mt_json`/`mt_set`/`mt_save`/`mt_get_json` stubs copied
      in shape from `scripts/orchestrate-cycle-plan.sh:632-654`, and `task_lookup_dir` sourced
      from the fixture's `lib/task-lookup-lib.sh`. *(completed)*
- [x] Case A (characterization, must stay green after the change): in-batch candidate
      (`post_deploy_reconcile_json='[1]'`), FRESH tree -> task 1 promoted to `completed`,
      notice recorded, `.completed_tasks` contains 1. *(completed)*
- [x] Pre-fix probe, reported via `info()` rather than asserted: out-of-batch candidate
      (`post_deploy_reconcile_json='[]'`, task 2 deploy-pending, FRESH tree) -> task 2's status
      and `deploy_pending` marker both unchanged. Capture the probe output verbatim into the
      dispatch log as acceptance #2's "fails before" evidence. *(completed: probe showed
      project 2 status='implementing', deploy_pending='true', unchanged -- confirms cause
      variant (b))*
- [x] `shellcheck` the new suite; run it (all cases green) and commit. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the closed-over global set
(`dry_run`, `cycle_count`, `session_id`, `SCRIPT_DIR`, `STATE_FILE`, `post_deploy_reconcile_json`,
plus `mt_*` and `task_lookup_dir`) is sufficient to drive the pass in isolation, and that
`PROJECT_ROOT` is the only additional global the widened sweep will need. Confirm at
implementation time by `grep -n '\$[A-Za-z_]' ` over the library body and by the suite actually
running green — a missing global surfaces immediately as an unbound-variable or empty-path
failure, not silently.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` - new file:
  isolated fixture harness, Case A characterization, pre-fix probe

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` exits 0
  with Case A passing.
- `shellcheck agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh`
  reports nothing.
- The probe's recorded output shows the out-of-batch task unpromoted and still
  `deploy_pending: true` against the unmodified library.
- The real `specs/` tree, real `state.json`, and real `.claude-extensions.json` are untouched by
  the run (`git status --short` shows only the new test file).

---

### Phase 2: Widen the Promotion Pass to a System-Wide Deploy-Pending Sweep [COMPLETED]

**Goal**: Inside `run_post_deploy_reconcile_pass()` only, extend the candidate set from the
invocation-scoped `post_deploy_reconcile_json` to that set **unioned with** a `specs/state.json`
sweep for any non-terminal, deploy-pending task — with no new deploy-trigger call site, no edit
to any excluded file, and no change to the gate.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` in full
      immediately before editing (concurrent siblings share this tree). *(completed)*
- [x] Add a candidate-derivation step before the existing loop that builds
      `_pdr_candidates_json` as: every entry of `post_deploy_reconcile_json` (unchanged, first,
      order preserved), then every additional task number `T` from `STATE_FILE`'s
      `active_projects[]` satisfying all of: `status` in `{implementing, partial}`;
      `${PROJECT_ROOT:-$(cd "$(dirname "$STATE_FILE")/.." && pwd)}/$(task_lookup_dir ...)/.return-meta.json`
      exists and reports `.deploy_pending == true`; `T` not already present in
      `post_deploy_reconcile_json`. *(completed: altered — an additional conjunct was required,
      `T` not already a member of `mt_get_json '.task_numbers'`. The sibling regression suite
      test-orchestrate-cycle-plan.sh's Arm E (deploy failed to land) and Arm G (self-attribution
      hard-mode withholding) both FAILED without this exclusion: both fixtures keep a
      `.task_numbers` member's `deploy_pending:true` + `status:implementing` on disk precisely
      because its absence from `post_deploy_reconcile_json` is a deliberate same-cycle decision,
      not an earlier-cycle stranding — the literal plan predicate re-added it and silently
      defeated that decision. See the library's own updated header comment for the full
      reasoning.)*
- [x] Gate each **swept** (non-`post_deploy_reconcile_json`) candidate on
      `bash "$SCRIPT_DIR/task-lock.sh" check "$T"`: proceed on rc 0 (`free`) or rc 2
      (`held-stale`); skip with a named stderr line on rc 1 (`held-fresh`) or rc 3
      (resolution error), failing CLOSED. Mirror the exit-code gate and the
      "ALL of them routine, expected outcomes" posture already recorded at
      `scripts/reconcile-task-status.sh:247-312`; do not re-derive a second staleness heuristic. *(completed)*
- [x] Change the loop's outer guard from `[ "$post_deploy_reconcile_json" != "[]" ]` to the union
      being non-empty, keeping `[ "$dry_run" != "true" ]` unchanged on the same condition, and
      keeping the trailing `.cycle_modified_files = []` reset and `mt_save` outside it exactly as
      today. *(completed)*
- [x] Iterate `_pdr_candidates_json` with the existing loop body verbatim (same
      `reconcile-task-status.sh` invocation, same `promoted`/`refused`/`no-op` classification,
      same non-fatal posture), adding a `scope` field (`"batch"` when the task is a member of
      `mt_get_json '.task_numbers'`, else `"swept"`) to the
      `.post_deploy_reconcile_notices` entry, and a distinct stderr line for swept candidates so
      an operator can tell a self-heal of a stranded task from this batch's own convergence. *(completed)*
- [x] Gate the `.completed_tasks +=` write and the `git-commit-scoped.sh` promotion commit on
      `scope == "batch"` for `completed_tasks` (a non-member must not enter the batch's Succeeded
      table or its `.dispatch/` cleanup set) while keeping the scoped commit for **both** scopes
      (a swept promotion's `state.json`/`TODO.md` transition needs committing exactly as an
      in-batch one does, with the same explicit two-entry pathspec and the same non-blocking
      warning on failure). *(completed)*
- [x] Update the function's header comment to record: the widened candidate set and why it is a
      reach widening of an existing sanctioned trigger rather than a third site; the lock gate and
      its fail-closed direction; the `scope` distinction and the `.completed_tasks` reasoning; and
      the structural safety argument (every promotion still passes through the unconditional,
      check-only PHASE 0.5 gate, so a genuinely stale tree simply re-refuses and the marker
      survives for the next sweep). Cite file-and-line anchors only — no task numbers. *(completed)*
- [x] Confirm the closing conclusion on `scripts/reconcile-task-status.sh`: re-read its
      `implementing` branch (`:595-628`) and `partial` branch (`:629+`) and record whether a
      swept candidate needs any accommodation there. Edit it only if a concrete, demonstrated need
      appears; otherwise state in the summary that it needed none. *(completed: re-read both
      branches; neither needs accommodation -- each reads only the task_number argument it is
      given and its own task directory, with no assumption about who or what is calling it.
      reconcile-task-status.sh left unmodified.)*
- [x] `shellcheck` the library; run Phase 1's suite with the default (changed) library and confirm
      Case A still green; commit. *(completed: shellcheck reports only the same SC2154/SC2016
      closed-over-global categories already present in the pre-existing file and in sibling
      Class C libraries territory-contention-lib.sh / task-classification-lib.sh -- no new
      category introduced. Discovered and fixed a related gap during verification:
      check-extension-docs.sh Rule Q flagged the new test file as undeclared in
      agent-system/extensions/core/manifest.json's provides.scripts array; repaired via
      `bash .claude/scripts/sync-manifest-scripts.sh --write` -- a one-line, mechanical,
      required companion entry for the one new script this task adds, included in this phase's
      commit even though manifest.json is not in this task's declared file_scope.)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase hypothesizes that **one** file changes
(`scripts/lib/redeploy-checkpoint-lib.sh`) and that `scripts/reconcile-task-status.sh` needs no
edit — carried from `reports/01_deploy_pending_task_numbers_scope_gap.md`'s Recommendation 2,
re-derived at plan-authoring time by reading the `implementing` branch directly. Confirm at
implementation time by the final-task re-read above and by Phase 3's fixture cases passing with
`reconcile-task-status.sh` unmodified; if a real need appears, that file is already in
`file_scope` and may be edited, with the need named in the summary.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` - widen the candidate set
  to the invocation-scoped list unioned with a system-wide deploy-pending sweep; add the
  `task-lock.sh check` gate for swept candidates; add `scope` to the notice entry; scope the
  `.completed_tasks` write to batch members; update the header contract
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - only if the re-read above
  demonstrates a concrete need; no change expected

**Verification**:

- `shellcheck agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` reports nothing.
- `bash agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` exits 0
  (Case A unchanged).
- `bash agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` exits 0 with
  the suite itself unmodified (`git diff --stat` shows no change to it), and
  `grep -c deploy-headless agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh`
  is 0.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`,
  `test-force-phases.sh`, and `test-orchestrate-unwind-dispatch.sh` (the three existing suites
  that touch this library) all exit 0.
- Full gate set for this tier: `bash .claude/scripts/verify-deploy.sh` (source-store path
  `agent-system/extensions/core/scripts/verify-deploy.sh`) passes, and
  `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green.
- `git diff --stat` touches no excluded file (`update-task-status.sh`,
  `orchestrate-cycle-postflight.sh`, `orchestrate-cycle-plan.sh`) and no sibling's declared
  territory.

---

### Phase 3: Prove It — Fail-Before/Pass-After, Stale Refusal, Lock Guard, Reporting Scope [COMPLETED]

**Goal**: Turn Phase 1's probe into assertions that are green only with Phase 2's change, and add
the three sibling cases that make the acceptance criteria demonstrated rather than asserted.

**Tasks**:

- [x] Case B (acceptance #2): out-of-batch candidate (`post_deploy_reconcile_json='[]'`,
      `.task_numbers=[1]`, task 2 deploy-pending, FRESH tree) -> task 2 promoted to `completed`
      in the fixture's `state.json`, its `deploy_pending` marker cleared, and a notice recorded
      with `scope: "swept"`. *(completed)*
- [x] Case C (acceptance #4, the no-weakening proof): same shape as Case B but with the fixture's
      recorded `source_git_head` left behind so the tree is provably STALE -> the sweep attempts
      the candidate, `update-task-status.sh` refuses with exit 6, the fixture's `state.json`
      status is byte-identical to before the run, `deploy_pending` is still `true`, and the notice
      outcome is `refused`. This exercises the no-weakening requirement against the **widened**
      code path, not just the pre-existing gate suite. *(completed: altered — "byte-identical"
      narrowed from the whole state.json file to its `.status` field. reconcile-task-status.sh
      unconditionally link_artifact()s the summary into `.artifacts` BEFORE attempting the
      postflight promotion the stale tree then refuses — pre-existing, unmodified behavior — so
      the whole file is not byte-identical, but the STATUS TRANSITION the gate exists to refuse
      is unchanged, mirroring test-postflight-deploy-gate.sh's own Case 1, which likewise checks
      only `before_status == after_status`.)*
- [x] Case D (lock guard): a swept candidate whose task directory carries a fresh
      `.lock/holder.json` from a foreign session -> skipped, no reconcile attempted (assert the
      stub-visible absence of a promotion and the named skip line on stderr), status unchanged. *(completed)*
- [x] Case E (reporting scope): assert `.completed_tasks` contains the in-batch promotion and does
      NOT contain the swept one, and that both appear in `.post_deploy_reconcile_notices` with the
      correct `scope` values. *(completed)*
- [x] Case F (negative control, the demotion risk): a `researching` task with no artifact present
      in the fixture `state.json` is never a candidate — assert its status is unchanged after a
      sweep run, proving the predicate cannot reach `reconcile-task-status.sh`'s demotion path. *(completed)*
- [x] Record the fail-before/pass-after demonstration as a two-run command pair in the summary:
      `git show HEAD~N:agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` into a
      temp file, run the suite with `REDEPLOY_CHECKPOINT_LIB=<that temp file>` (expect non-zero,
      Cases B/C/D/E failing), then run it unset (expect 0). Capture both exit codes verbatim. *(completed:
      BEFORE (pristine, HEAD of the commit preceding Phase 2's own) exit code 1, 11 passed / 6
      failed — Cases B, C, D, E all failed exactly as predicted. AFTER (default resolution, the
      widened library) exit code 0, 17 passed / 0 failed.)*
- [x] Derive acceptance #3's counted before/after from the fixture, not from prose: **before** —
      with the pristine library, N successive calls to the pass (N >= 2, simulating later cycles of
      an invocation that does not name the task) promote the stranded task 0 times, so the
      automated cycle count from work-done to status-recorded is unbounded and the recorded cost is
      a hand-run `reconcile-task-status.sh`; **after** — the first call promotes it, so the count is
      1 cycle of the next `/orchestrate` invocation on any task. Report the measured pair, not a
      fabricated single number. *(completed: measured directly — pristine library, 3 successive
      cycles against a stranded deploy-pending task, status stayed 'implementing' all 3 times
      (0 promotions); widened library, cycle 1 promoted it to 'completed'.)*
- [x] `shellcheck` the suite; run it; commit. *(completed: shellcheck clean; suite exits 0,
      17 passed / 0 failed.)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts six fixture cases (A-F) suffice to cover acceptance #2,
#3 and #4 against the widened path. Confirm at implementation time by mapping each acceptance
criterion to the case name in the summary; if a criterion has no case, add one rather than
declaring the mapping satisfied.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` - add Cases
  B-F and the two-run fail-before/pass-after demonstration

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` exits 0
  with all six cases passing.
- The same suite run with `REDEPLOY_CHECKPOINT_LIB` pointed at the pristine pre-change library
  exits non-zero, with Cases B/C/D/E reported as failures — the recorded fail-before evidence.
- `shellcheck` on the suite reports nothing.
- Case C's assertions confirm exit 6 and an unchanged fixture `state.json`.

---

### Phase 4: Correct the Sanctioned-Site Prose to Match the Lint [NOT STARTED]

**Goal**: Make `context/patterns/regeneration-is-manual-only.md`'s documented pair match what
`scripts/tests/test-lint-deploy-caller-wrap.sh` mechanically enforces, removing the dangling
reference to a file that no longer exists, while leaving the sanctioned count at exactly two.

**Tasks**:

- [ ] Re-read `context/patterns/regeneration-is-manual-only.md:120-185` immediately before
      editing, and re-confirm the dangling reference with
      `find agent-system -ipath '*commands*' -iname 'implement.md'` (expected: no output).
- [ ] In the "Automated Exception: The Postflight Completion-Deploy Gate" section, replace the
      `commands/implement.md` Step 4 half of the sanctioned-sites pair with
      `scripts/orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint — the site the
      document's own later "Update" paragraph already confirms carries the `deploy_pending`
      override — and state explicitly that the mechanically authoritative pair is the one the
      lint re-derives on every run, never a hardcoded list.
- [ ] Apply the same correction to the "deliberately UNCHANGED by this closure" paragraph, which
      repeats the stale pair, and to the "Structural precondition" paragraph's
      markdown-command-prompt carve-out, which exists only to excuse the now-nonexistent file.
      Keep the count at exactly two and keep the "no other automated caller is sanctioned"
      sentence intact.
- [ ] Follow the document's own correction-as-addition convention: add a short labeled
      **CORRECTION.** block recording that the earlier pair named a file that no longer exists in
      the source store, that the lint is the mechanical source of truth, and that the
      post-deploy reconcile pass's candidate set has been widened system-wide inside
      `scripts/lib/redeploy-checkpoint-lib.sh` with no new call site — reach, not count.
- [ ] Cite durable anchors only (file plus line), never a task number, per the dispatch's
      deliverable rule and `rules/no-task-references-in-deliverables.md`.
- [ ] Commit the documentation change on its own.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three occurrence sites of the stale pair inside
the one document (the sanctioned-sites sentence, the unchanged-count paragraph, and the
structural-precondition carve-out). Confirm at implementation time with
`grep -n 'commands/implement' agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
returning zero matches after the edit, and with a repository-wide
`grep -rn "commands/implement.md" agent-system/` check for further stragglers outside this file
(report, do not silently widen scope, if any appear).

**Files to modify**:

- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - correct the
  sanctioned-sites pair to `{command-gate-out.sh rc == 6, orchestrate-cycle-plan.sh Inter-Cycle
  Redeploy Checkpoint}`, remove the dangling `commands/implement.md` references, add the labeled
  correction block

**Verification**:

- Diff read-through confirms every changed hunk is prose inside this one document.
- `grep -n 'commands/implement' <file>` returns nothing.
- The pair named in the document matches the pair
  `scripts/tests/test-lint-deploy-caller-wrap.sh` reports, and
  `bash agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` is green with
  the suite unmodified.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) shows no new
  task-number reference outside `specs/**`.

---

### Phase 5: Final Gate Set and Acceptance Walkthrough [NOT STARTED]

**Goal**: Run the complete gate set, confirm every one of the dispatch's eight acceptance criteria
against recorded evidence, and write the implementation summary with the named cause and the
counted before/after.

**Tasks**:

- [ ] `shellcheck` every changed shell file; confirm the strict-mode class of each
      (library: Class C, no `set` line; suite: Class B, `set -uo pipefail`) per
      `context/standards/shell-strict-mode.md`.
- [ ] Run the full suite set: `bash agent-system/extensions/core/scripts/tests/run-all.sh` green,
      with `test-lint-deploy-caller-wrap.sh`, `test-postflight-deploy-gate.sh`,
      `test-reconcile-handoff-status.sh`, `test-orchestrate-cycle-plan.sh`,
      `test-force-phases.sh`, `test-orchestrate-unwind-dispatch.sh` and the whole
      `test-lint-*.sh` family individually confirmed. No suite weakened, skipped, or deleted.
- [ ] `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`) passes.
- [ ] Confirm `git diff --stat` against the task's start point touches only this task's four
      `file_scope` paths (minus any not needed) and no sibling's declared territory; confirm no
      `deploy-headless.sh` call was added anywhere
      (`git diff | grep -c 'deploy-headless'` is 0 for added lines).
- [ ] Write the acceptance walkthrough into the summary, one row per criterion #1-#8, each citing
      the concrete evidence: #1 the named cause (candidate set bounded by `.task_numbers` at
      `scripts/orchestrate-cycle-plan.sh:874`) with the git-history trace; #2 Case B plus the
      two-run exit codes; #3 the measured before/after automated-cycle count; #4 Case C; #5 the
      lint green and unmodified; #6 the corrected prose matching it; #7 `run-all.sh` green; #8
      shellcheck clean.
- [ ] Do NOT invoke `deploy-headless.sh` or hand-run `reconcile-task-status.sh` to make this
      task's own completion land. If this task's postflight is refused with exit 6, record that
      refusal as acceptance #3's observed "before" datum and let the sanctioned path resolve it.
- [ ] Write the implementation summary artifact and commit.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `specs/367_reduce_deploy_staleness_completion_round_trip/summaries/01_*-summary.md` - new
  implementation summary with the acceptance walkthrough and the counted before/after

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh` exits 0.
- `shellcheck` reports nothing on every changed shell file.
- Every acceptance criterion #1-#8 has a named evidence citation in the summary; none is marked
  satisfied by assertion alone.

---

## Testing & Validation

- [ ] `test-redeploy-checkpoint-promotion.sh` green with all six cases (A-F).
- [ ] Fail-before/pass-after demonstrated as a two-run pair with recorded exit codes, using the
      `REDEPLOY_CHECKPOINT_LIB` override against the pristine library.
- [ ] Acceptance #4 proven against the widened path: stale tree -> exit 6, `state.json`
      unchanged, `deploy_pending` still `true`.
- [ ] `test-lint-deploy-caller-wrap.sh` green and the suite file itself unmodified.
- [ ] The whole `test-lint-*.sh` family green (notably `test-lint-scoped-commit-boundary.sh`,
      `test-lint-state-writer-boundary.sh`, `test-lint-postflight-boundary.sh`, which cover the
      call classes this library uses).
- [ ] `test-postflight-deploy-gate.sh` green and unmodified — the gate's own behavior is unchanged.
- [ ] `run-all.sh` green; no suite weakened, skipped, or deleted.
- [ ] `shellcheck` clean per `context/standards/shell-strict-mode.md`.
- [ ] `verify-deploy.sh` green.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` — widened candidate set
  (invocation-scoped list unioned with a system-wide deploy-pending sweep), lock-gated for swept
  candidates, `scope`-tagged notices, batch-scoped `.completed_tasks` write, updated header
  contract.
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` — new
  fixture-driven suite (Cases A-F) plus the fail-before/pass-after demonstration.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — corrected
  sanctioned-sites pair, dangling reference removed, labeled correction block added.
- `specs/367_reduce_deploy_staleness_completion_round_trip/summaries/01_*-summary.md` —
  implementation summary with the named cause, the acceptance walkthrough, and the counted
  before/after.
- Possibly unchanged: `agent-system/extensions/core/scripts/reconcile-task-status.sh` (in
  `file_scope`, no edit expected — see Phase 2's Scope Hypothesis).

## Rollback/Contingency

Every phase commits independently, so rollback is per-commit: `git revert` the library commit
alone restores the pre-change invocation-scoped behavior without touching the new suite or the
documentation correction (the suite's Cases B-F then fail, which is the honest signal that the fix
is absent, not a broken test). Before any intentional rollback that would discard uncommitted
work, run `bash .claude/scripts/git-snapshot.sh 367` first, per
`rules/git-workflow.md`'s "No Destructive Git on Uncommitted Work"; for an ordinary defensive
checkpoint mid-phase use `--no-revert`, never the reverting default.

Contingency if the sweep proves unsafe to run unconditionally every cycle (for example, a
measured per-cycle cost that matters, or an unforeseen interaction with a concurrent session that
the `task-lock.sh check` gate does not cover): narrow the sweep's own precondition inside the same
library — for instance to cycles in which the checkpoint actually deployed — rather than moving
the fix to a new call site or softening the gate. Both of those are excluded by construction, not
available as fallbacks.
