# Implementation Plan: Task #272

- **Task**: 272 - Honest session liveness for concurrent batches
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: 351 (per `specs/state.json`). Ordering notes from the task description: 51 (owns `scripts/task-lock.sh` and `context/standards/orchestrator-runtime-files.md` concurrently; keep this task's diffs small and additive), 165 (owns `scripts/orchestrate-batch-admit.sh` -- NOT touched here), 275 (consumes this task's output; former Piece 4 moved there)
- **Research Inputs**: specs/272_honest_session_liveness_concurrent_batches/reports/01_heartbeat-liveness-diagnosis.md
- **Artifacts**: plans/01_heartbeat-liveness-repair.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three in-scope pieces plus two absorbed text/ordering defects, all edited in the source store
(`agent-system/extensions/core/`, never `.claude/**`). Piece 1's scope-determining question is
**answered**: the heartbeat silence is a **design gap** (incomplete propagation of an
already-correct mechanization), not a routing regression -- so the plan extends the existing
mechanism's *reach* rather than building a second one. Piece 2 brings the session registry's
already-tested `session_liveness()` vocabulary down to the per-task lock as an additive third
`check` state, keyed on `session_id` and never on pid. Piece 3 extracts the union-`file_scope`
computation so `session-heartbeat` re-derives it instead of echoing a stale snapshot. Done when
every ACCEPTANCE bullet in the task description holds: the Piece 1 answer is recorded in writing
before any fix lands, fixture tests reproduce both named cases and demonstrably fail against the
pristine scripts, `orchestrate-batch-admit.sh` is untouched, every existing `task-lock.sh` output
consumer still works, and shellcheck is clean.

### Research Integration

The report (`reports/01_heartbeat-liveness-diagnosis.md`) is integrated as follows, with every
load-bearing claim re-derived at plan-authoring time against the source store:

- **Piece 1 verdict (design gap, not routing regression)** -- accepted. Re-derived: the heartbeat
  mechanism lives in `heartbeat_after_phase_transition()` at `scripts/update-phase-status.sh`
  (function ~line 159, invoked at ~line 276 before both the "Phase N not found" and idempotency
  early-exits), traces every branch including every no-op class, and is therefore silent only
  when the script is never invoked at all.
- **The affected-agent set** -- the report's "~11 of 13" figure is superseded by a re-derived,
  authoritative count. `scripts/lint/lint-agent-contracts.sh`'s Check G already carries the
  curated, predicate-swept list of agents whose contracts instruct editing
  `### Phase N: ... [MARKER]` headings: `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS`, **14 files**. A
  `grep -c update-phase-status.sh` over those 14 at plan-authoring time returns 14 for
  `core/agents/general-implementation-agent.md` and **0 for the other 13**. Confirmed hypothesis:
  13 of 14 phase-heading-owning agents never invoke the mechanized heartbeat.
- **Piece 2 gap location** -- refined. `cmd_acquire`'s *own-task* stale branch already has a
  pid-liveness floor (`scripts/task-lock.sh` ~line 828: ABORT when the holder pid is alive). The
  two genuine gaps are (i) `cmd_check` (~lines 1033/1036: `held-fresh`/`held-stale` only, no pid
  dimension) and (ii) `cmd_acquire`'s **cross-task overlap pass** (~line 748-749: "Stale
  overlapping foreign lock: warn and proceed", no pid/liveness dimension at all).
- **Piece 3** -- confirmed verbatim: `cmd_session_register` computes the union via a
  `get_file_scope` loop plus `jq -s -c 'add | unique'`; `cmd_session_heartbeat` reads
  `.file_scope` back verbatim and rewrites it unchanged.
- **Absorbed (a)** -- confirmed and *narrowed*: `scripts/orchestrate-predispatch-review.sh`
  already implements `--session-id` fully (parse at ~line 198, `session_id_explicit` gate at
  ~line 463, Class E branch at ~line 765). The entire defect is the ordering inside
  `commands/orchestrate.md`: the review call is at line 202, `batch_session_id="$(common_session_id)"`
  at line 250. **No change to `orchestrate-predispatch-review.sh` is required.**
- **Absorbed (b)** -- confirmed at `commands/orchestrate.md:236` and
  `docs/architecture/orchestrate-state-machine.md:736`.
- **Dead session-registry entries** -- accepted as **no action**: `/refresh` already calls
  `task-lock.sh session-reap`. Dropped from scope, recorded as verified-already-correct in
  Phase 1.

### Prior Plan Reference

No prior plan. `plans/` was empty at dispatch time.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no roadmap flag was set; no ROADMAP.md
consultation performed.

## Goals & Non-Goals

**Goals**:
- Record Piece 1's routing-regression-versus-design-gap answer in writing, with reproducible
  evidence, **before any fix lands** (an explicit ACCEPTANCE bullet).
- Close Piece 1's functional gap with a mechanism that does **not** depend on each domain agent's
  prose remembering to call a script: fire the existing heartbeat at dispatch boundaries.
- Make the remaining per-agent adoption gap **visible and non-regressing** via an advisory lint
  check that reuses Check G's already-curated agent set.
- Give the per-task lock a third state for stale-heartbeat-but-pid-alive, consuming
  `session_liveness()` rather than transcribing it, keyed on `session_id` only.
- Make `cmd_acquire`'s cross-task overlap pass stop degrading a demonstrably-live session's lock
  to advisory.
- Re-derive the session registry's union `file_scope` on `session-heartbeat`.
- Wake up the dead Class E contention review and fix the self-contradicting batch-size message.

**Non-Goals**:
- Any edit to `scripts/orchestrate-batch-admit.sh` (task 165's surface; explicitly forbidden).
- Per-orchestration identity / per-orchestration metadata (moved to task 275 in full).
- Editing the 13 un-migrated `*-implementation-agent.md` files, which live in **other extensions**
  and outside this task's declared `file_scope` -- see Risks, and the non-blocking
  `user_decision` this plan raises.
- Reap-policy changes for dead session-registry entries (verified already correct).
- Rebuilding or replacing the heartbeat mechanism; it is extended in reach, never duplicated.
- Any hand-authored edit under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new `check` **exit code** breaks existing consumers | H | H | Do NOT add an exit code. All three consumers (`reconcile-task-status.sh` demote gate, `orchestrate-unwind-dispatch.sh` Gate #6, `orchestrate-cycle-plan.sh` lock probe) gate on 0/1/2 with a catch-all that treats anything else as error-or-optimistic. Emit a **new line prefix carrying exit code 1** (the existing "a live session may be working" code), which is exactly the right behavior at all three sites. Pinned by the Phase 4 test. |
| New prefix is a superstring of an existing one (`held-stale-pid-alive` contains `held-stale`) | M | M | Name the third state `held-live` -- a prefix that is a substring of neither existing state, so any future prefix/substring consumer cannot mis-match. Record it in `context/patterns/task-lock.md`'s stable-contract section alongside the other two. |
| Escalating `cmd_acquire`'s overlap pass from WARN-and-proceed to ABORT changes refusal semantics for existing callers | M | M | Escalate **only** when `session_liveness()` returns `pid-alive` for the foreign holder's registered session; every other verdict, and a missing/corrupt registry entry, keeps today's WARN-and-proceed byte-for-byte. Covered by a fixture case in both directions. |
| Extracting the heartbeat into a shared library changes the existing trace-line shape, breaking `scripts/tests/test-phase-heartbeat.sh` | M | M | Parameterize the phase label and pass the real phase number from `update-phase-status.sh`, so phase-transition trace lines stay byte-identical. Phase 2 verification runs the existing suite unmodified before any new call site is added. |
| Piece 1's full per-agent remediation needs 13 files across 12 other extensions, outside declared `file_scope` | M | H | Do not widen silently. Core-side dispatch-boundary pulse closes the functional gap system-wide; the advisory lint keeps the residual gap visible; a non-blocking `user_decision` puts the widen-or-follow-up call to the user. |
| A FAILing new lint check turns `verify-deploy.sh` Gate 6 red on landing (13 known offenders) | H | H | Introduce Check I as **advisory/WARN-only** with the 13 recorded as a dated migration inventory; the check FAILs only on a *new* phase-heading-owning agent added without the call. |
| Task 51 concurrently owns `scripts/task-lock.sh` and `context/standards/orchestrator-runtime-files.md` | M | M | Keep every `task-lock.sh` diff small, additive, and append-only within its existing functions; no structural rewrite. Re-read each file immediately before editing (sibling-concurrency discipline from the dispatch's Territory block). |
| Concurrent sibling dispatches (366, 367, 271, 306) on this shared tree | M | H | Per-task hunk staging only; never a directory or glob `git add`; never `git-snapshot.sh` in reverting mode; re-read before edit; STOP and report a foreign commit or build rather than absorbing it. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 7 | 1 |
| 3 | 6 | 4 |
| 4 | 5 | 6 |
| 5 | 8 | 2, 3, 5, 6, 7 |

Phases within the same wave can execute in parallel. Phases 4, 6 and 5 are serialized across
waves 2-4 **because they all edit `scripts/task-lock.sh`** -- their logical dependency is file
ownership, not data flow.

---

### Phase 1: Record the Piece 1 Diagnosis in Writing [COMPLETED]

**Goal**: Satisfy the ACCEPTANCE bullet "Piece 1's routing-regression-versus-design-gap question
answered in writing before any fix lands, with the answer visible in the trace log or an
equivalent probe" -- and record the two scope reductions this task is taking (dead-registry
entries: no action; `orchestrate-predispatch-review.sh`: no change needed).

**Tasks**:
- [x] Re-read `context/patterns/task-lock.md` immediately before editing (sibling concurrency). *(completed)*
- [x] Add a new section to `context/patterns/task-lock.md`, "Heartbeat Coverage Is Per-Caller, *(completed)*
      Not Repo-Wide", stating: the verdict (**design gap**, incomplete propagation of an
      already-correct mechanization -- not a routing regression); where the one mechanism lives
      (`scripts/update-phase-status.sh`'s `heartbeat_after_phase_transition()`); why a naive grep
      misses it (the path is held in `$tl_path`); and the explicit instruction **not to build a
      second mechanism**.
- [x] In that section, record the equivalent probe verbatim so a future reader can re-derive the *(completed)*
      answer: every branch of the function traces, therefore zero trace lines for a task with
      committed phase-completion commits proves the script was never invoked -- not that a
      no-op absorbed the call. Name the corroborating observation that
      `noop:session-mismatch` appears zero times in either repo's log.
- [x] Record the re-derived adoption inventory: Check G's `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` *(completed)*
      (14 files) is the authoritative in-scope set; 13 of the 14 contain zero
      `update-phase-status.sh` references. Include the one-line reproduce command.
- [x] Record the secondary, independently-real finding: the heartbeat is reachable only via a *(completed)*
      phase-status transition, so a task in one long phase emits nothing between transitions --
      and name Phase 2 as the dispatch-boundary remedy.
- [x] Record that `_hb_trace` verdict lines are written and consumed by nothing today, as a known *(completed)*
      gap with no action in this task.
- [x] Record the two scope reductions: (i) dead session-registry entries need **no change** -- *(completed)*
      `skills/skill-refresh/SKILL.md` and `commands/refresh.md` already call
      `task-lock.sh session-reap` on explicit `/refresh`, so the observed stale entries mean
      `/refresh` has not been run, not that the path is unwired; the PID-recycling hazard is an
      inherent `kill -0` limitation, recorded as a known limitation, not an action item.
      (ii) `scripts/orchestrate-predispatch-review.sh` already implements `--session-id` fully --
      absorbed (a) is an ordering fix in `commands/orchestrate.md` alone.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The "14 in-scope agents, 13 without the call" figure is a plan-authoring-time
re-derivation of the report's carried "~11 of 13", taken from
`scripts/lint/lint-agent-contracts.sh`'s `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` plus a
`grep -c update-phase-status.sh` sweep over those paths. Confirm at implementation time by
re-running: `cd agent-system/extensions && for rel in $(sed -n '/^OWNERSHIP_IN_SCOPE_RELATIVE_PATHS=(/,/^)/p' core/scripts/lint/lint-agent-contracts.sh | grep -oE '"[^"]+"' | tr -d '"'); do printf '%s %s\n' "$(grep -c update-phase-status.sh "$rel" || true)" "$rel"; done` and write the
observed numbers, not these, into the new section.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - new "Heartbeat Coverage Is
  Per-Caller, Not Repo-Wide" section carrying the Piece 1 verdict, the probe, the adoption
  inventory, and the two recorded scope reductions

**Verification**:
- Diff read-through confirms every changed hunk is prose inside the markdown document; no fenced
  block is introduced that a consumer parses.
- `grep -n "design gap" agent-system/extensions/core/context/patterns/task-lock.md` returns the
  new verdict line.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo-wide
  equivalent) reports no task-number reference introduced outside `specs/**`.

---

### Phase 2: Dispatch-Boundary Heartbeat (Piece 1 Functional Fix) [COMPLETED]

**Goal**: Make the existing heartbeat fire at dispatch boundaries, independent of any agent's
prose, so all 13 un-migrated phase-heading-owning agents (and every task type with no
phase-headed plan at all) are covered without editing a single file outside
`agent-system/extensions/core/`.

**Tasks**:
- [x] Extract `heartbeat_after_phase_transition()` from `scripts/update-phase-status.sh` into a *(completed)*
      new `scripts/lib/phase-heartbeat-lib.sh` as an explicit-parameter function (e.g.
      `phase_heartbeat_pulse <repo_root> <task_dir> <task_number> <phase_label> <caller_session_id>`),
      replacing its current reliance on the caller's `$repo_root` / `$plan_dir` /
      `$task_number` / `$phase_number` / `$caller_session_id` closure variables.
- [x] Preserve, byte-for-byte: the trace-log path (`${repo_root}/.agent-logs/heartbeat-trace.log`), *(completed)*
      the line shape `[<ISO8601>] task <N> phase <P> <subcommand>: <verdict> session=<sid> sid_source=<src> msg=<...>`,
      every no-op/error classifier (`no-holder`, `unparseable-holder`, `session-mismatch`,
      `no-lock`, `no-entry`, `unknown`, `task-lock-unresolved`), the `$tl_path` two-candidate
      resolution, the `PHASE_HEARTBEAT_DISABLE` opt-out, and the never-affect-stdout-or-exit-code
      property.
- [x] Have `scripts/update-phase-status.sh` source the new lib and call it with the real phase *(completed)*
      number, so its emitted lines are unchanged.
- [x] Add a dispatch-**start** pulse in `scripts/orchestrate-build-dispatch.sh`, using its already *(completed)*
      resolved task number, session id and repo root, with a phase label distinct from any real
      phase number (e.g. `dispatch-start`) so the two sources stay separable in the log.
- [x] Add a dispatch-**end** pulse in `scripts/orchestrate-cycle-postflight.sh`, using its *(completed)*
      `<task_number>`, `--session`, and `--task-dir` arguments, labelled `dispatch-end`.
- [x] Keep both new call sites strictly non-blocking and silent on stdout (`>/dev/null || true`), *(completed)*
      matching the existing invocation's own contract.
- [x] Extend `scripts/tests/test-phase-heartbeat.sh` with a case asserting a `dispatch-start` *(completed)*
      pulse writes a trace line for a task whose plan has no phase transition at all.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the two dispatch-boundary scripts
(`orchestrate-build-dispatch.sh`, `orchestrate-cycle-postflight.sh`) are the complete set of
per-dispatch entry points that always run regardless of task type or routed agent, based on their
own usage headers (`<task_number> <phase> --session SID --seq N` and
`<task_number> --session SID ... --task-dir DIR`). Confirm at implementation time by grepping
`skills/skill-orchestrate/SKILL.md` for every script it invokes once per dispatched task, and
add any further always-run boundary found, or record why the two suffice.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/phase-heartbeat-lib.sh` - NEW; the single extracted
  heartbeat implementation with an explicit-parameter signature
- `agent-system/extensions/core/scripts/update-phase-status.sh` - source the lib; delete the
  inlined function; call with the real phase number (output unchanged)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - dispatch-start pulse
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - dispatch-end pulse
- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` - new dispatch-boundary case
- `agent-system/extensions/core/context/patterns/task-lock.md` - document the two new pulse sites
  in the Phase 1 section

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` passes, including
  every pre-existing case **unmodified** (proving the phase-transition line shape did not drift).
- Build of the changed modules plus their enumerated direct dependents:
  `shellcheck` clean on `lib/phase-heartbeat-lib.sh`, `update-phase-status.sh`,
  `orchestrate-build-dispatch.sh`, `orchestrate-cycle-postflight.sh` per
  `context/standards/shell-strict-mode.md`.
- `bash agent-system/extensions/core/scripts/tests/test-dispatch-metrics.sh` and any other suite
  exercising the two touched orchestrate scripts pass.
- A manual probe confirms a `dispatch-start` line appears in `.agent-logs/heartbeat-trace.log`
  for a dispatch whose agent never calls `update-phase-status.sh`.

---

### Phase 3: Advisory Lint for Heartbeat Adoption (Piece 1 Regression Guard) [COMPLETED]

**Goal**: Keep the residual per-agent adoption gap visible and non-regressing without turning
`verify-deploy.sh` Gate 6 red, by adding an advisory check that reuses Check G's already-curated
phase-heading-owning agent set.

**Tasks**:
- [x] Re-read `scripts/lint/lint-agent-contracts.sh` immediately before editing. *(completed)*
- [x] Add `check_i_heartbeat_mechanization_adoption()` (next free letter after the existing *(completed)*
      A, B, C, E, F, G, H), reusing `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` rather than re-deriving
      the agent set, exactly as the file's own Check G/H headers instruct.
- [x] For each in-scope agent: PASS when the file references `update-phase-status.sh`; emit a *(completed)*
      named **WARNING** (not a FAIL) when it does not **and** the file is on a recorded,
      dated migration-inventory list carried in the check's own header comment.
- [x] Emit a **FAIL** for any in-scope agent that neither references the script nor appears on *(completed)*
      the recorded inventory -- that is a newly added phase-heading-owning agent reintroducing
      the gap, which is exactly the regression this check exists to catch.
- [x] Register the new check in the file's run-all block alongside `check_h_...`. *(completed)*
- [x] Add `scripts/tests/test-lint-agent-contracts-heartbeat.sh` (or extend the existing *(completed)*
      lint-agent-contracts test suite if one exists) with: an inventory-listed offender produces
      a WARNING and exit 0; a synthetic non-inventory offender produces a FAIL.
- [x] Record the inventory and the lint's advisory posture in the Phase 1 `task-lock.md` section, *(completed)*
      including the condition under which it should be promoted to FAIL (once the migration lands).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the migration inventory is exactly the 13 files computed
in Phase 1 and that `check_i` is the next free check letter. Confirm at implementation time by
re-running Phase 1's sweep command and by
`grep -nE '^check_[a-z]_' agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - new Check I plus its
  recorded migration inventory and run-all registration
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-heartbeat.sh` - NEW;
  WARNING-on-inventoried and FAIL-on-new cases
- `agent-system/extensions/core/context/patterns/task-lock.md` - note the advisory posture and
  the promotion condition

**Verification**:
- `REPO_ROOT=<repo> bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  exits 0 and prints exactly the inventoried agents as named warnings.
- The new test suite passes both directions (inventoried offender -> WARN/exit 0; synthetic new
  offender -> FAIL).
- `shellcheck` clean on both touched/new scripts.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` Gate 6 ("Agent contracts lint")
  stays green.

---

### Phase 4: Third Lock State `held-live` in `cmd_check` (Piece 2a) [COMPLETED]

**Goal**: Give the per-task lock a state distinct from both `held-fresh` and `held-stale` for a
holder whose heartbeat is stale but whose **registered session** is demonstrably alive --
consuming `session_liveness()`, keyed on `session_id`, never on pid.

**Tasks**:
- [x] Re-read `scripts/task-lock.sh` immediately before editing (task 51 and siblings). *(completed)*
- [x] In `cmd_check`, on the existing `age > TASK_LOCK_STALE_MIN` branch only, resolve *(completed)*
      `specs/.sessions/${holder_session}.json` via the existing `session_registry_dir "false"`
      helper and, when that file exists, feed it to `session_liveness()` to obtain
      `<age_minutes> <liveness_reason>`.
- [x] When `liveness_reason` is `pid-alive`, emit the new third line: *(completed)*
      `held-live session=<sid> heartbeat_age_min=<age> threshold_min=<thr> never_heartbeated=<bool> liveness_reason=pid-alive`
      -- field order and names identical to the existing two lines plus one appended field, per
      the appended-field convention `task-lock.sh`'s own header already documents for
      `never_heartbeated`.
- [x] Return **exit code 1** for `held-live`, NOT a new code. Rationale to record in the function *(completed)*
      comment: all three consumers gate on 0/1/2 with a catch-all -- `reconcile-task-status.sh`
      refuses demotion on 1 (correct: a live session may be working),
      `orchestrate-unwind-dispatch.sh` Gate #6 compares `session=` and refuses only a *foreign*
      live holder (correct), `orchestrate-cycle-plan.sh`'s probe defers a foreign live holder to
      a later cycle (correct). A new code would make unwind error out and cycle-plan proceed
      optimistically over a live lock.
- [x] Fall back to today's exact `held-stale` line and exit 2 when the registry entry is missing, *(completed)*
      corrupt, or returns any reason other than `pid-alive` -- the no-op-not-abort convention used
      throughout this file.
- [x] Do **not** compare the holder's pid to the caller's pid anywhere. Record the reason in a *(completed)*
      comment: two genuinely different `/orchestrate` sessions can share a pid with
      `pid_source: ancestor-claude`, so pid-equality self-exclusion would read a foreign session
      as self.
- [x] Update `scripts/task-lock.sh`'s own header contract block (the `held-fresh`/`held-stale` *(completed)*
      appended-field note) and `context/patterns/task-lock.md`'s stable-prefix/exit-code contract
      section to name the third prefix and its exit code.
- [x] Add `scripts/tests/test-task-lock-liveness.sh` (NEW), modelled on `scripts/test-task-lock-reap.sh`'s *(completed)*
      and `scripts/test-session-registry.sh`'s isolated-temp-root pattern (copy the real scripts
      byte-for-byte into `$TMPROOT/.claude/scripts/`, controlled timestamps, no sleeping): the
      **stale-but-pid-alive** case -- a holder.json with `heartbeat_at` older than
      `TASK_LOCK_STALE_MIN` plus a registry entry for its session whose pid is the live test
      process -- asserting the `held-live` prefix, the `liveness_reason=pid-alive` field, and
      **exit code 1**; plus the three fallback cases (no registry entry, corrupt entry,
      `dead-pid` entry) asserting the unchanged `held-stale` line and exit 2.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the complete consumer set of `task-lock.sh check` is
three scripts (`reconcile-task-status.sh`, `orchestrate-unwind-dispatch.sh`,
`orchestrate-cycle-plan.sh`) plus `scripts/tests/test-phase-heartbeat.sh`, and that none
prefix-matches the output text (all gate on exit code, extracting only `session=`). Confirm at
implementation time by re-running
`grep -rn 'task-lock.sh" check\|task-lock.sh check' --include=*.sh --include=*.md agent-system/extensions/`
and `grep -rn 'held-fresh\|held-stale' --include=*.sh agent-system/extensions/`, and widen this
phase's verification to any further consumer found.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - `cmd_check`: additive `held-live` branch
  consuming `session_liveness()`; header contract block updated
- `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh` - NEW; stale-but-pid-alive
  case plus the three fallbacks
- `agent-system/extensions/core/context/patterns/task-lock.md` - third prefix and exit code in the
  stable-contract section

**Verification**:
- The new suite **fails against the pristine script** and passes against the modified one:
  copy `git show HEAD:agent-system/extensions/core/scripts/task-lock.sh` into a scratch fixture
  and run the suite against it, capturing the failure output as the ACCEPTANCE evidence; then run
  against the working copy and capture the pass.
- Build of the changed module plus its enumerated direct dependents: `shellcheck` clean on
  `task-lock.sh`; `bash scripts/test-task-lock-reap.sh`, `bash scripts/test-session-registry.sh`,
  `bash scripts/test-conflict-predicate.sh`, `bash scripts/test-four-tier-conflict.sh`, and
  `bash scripts/tests/test-phase-heartbeat.sh` all pass unchanged.
- `grep -c 'held-fresh\|held-stale' ` output lines in the existing suites are unchanged, proving
  the two pre-existing states were not rewritten.

---

### Phase 5: `cmd_acquire` Overlap Pass Consults the Same Verdict (Piece 2b) [NOT STARTED]

**Goal**: Stop `cmd_acquire`'s cross-task overlap pass from degrading a demonstrably-live foreign
session's lock to advisory purely because its heartbeat drifted -- the exact live incident the
task description reports.

**Tasks**:
- [ ] Re-read `scripts/task-lock.sh` immediately before editing.
- [ ] At the "Stale overlapping foreign lock: warn and proceed" branch (~line 748), before
      emitting the WARN, resolve the foreign holder's `other_session` in the session registry and
      run it through `session_liveness()` -- the same verdict Phase 4 consumes, not a second
      transcription.
- [ ] When the verdict is `pid-alive`, ABORT (return 1) with a message naming the overlapping
      path, the foreign task, the foreign session, the heartbeat age, the threshold, and
      `liveness_reason=pid-alive`, mirroring the shape of the adjacent fresh-overlap ABORT and of
      the own-task pid-alive ABORT already present at ~line 828.
- [ ] For every other verdict -- and for a missing or corrupt registry entry -- keep today's
      WARN-and-proceed text byte-for-byte unchanged.
- [ ] Never mutate the foreign lock or the session registry on this path (both are read-only here
      today; preserve that).
- [ ] Extend `scripts/tests/test-task-lock-liveness.sh` with the **two-live-sessions overlap**
      case: two tasks with overlapping `file_scope` in the fixture `state.json`, task A's lock
      held by session A with a stale heartbeat and a registry entry whose pid is live; session B
      acquiring task B must ABORT (exit 1) instead of warning-and-proceeding. Add the mirror
      case: the same setup with a `dead-pid` registry entry must still WARN and proceed (exit 0).
- [ ] Record the escalation and its exact trigger condition in `context/patterns/task-lock.md`.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that only one `cmd_acquire` branch lacks a pid/liveness
dimension (the cross-task overlap pass's stale WARN at ~line 748), the own-task stale branch
having already acquired one at ~line 828. Confirm at implementation time by re-reading
`cmd_acquire` end to end and enumerating every branch that reasons on `age_minutes` without a
liveness consult.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - `cmd_acquire` cross-task overlap pass:
  liveness consult before the stale WARN, ABORT on `pid-alive`
- `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh` - two-live-sessions
  overlap case plus the dead-pid mirror case
- `agent-system/extensions/core/context/patterns/task-lock.md` - document the escalation trigger

**Verification**:
- The two new cases **fail against the pristine script** (captured as ACCEPTANCE evidence) and
  pass against the modified one, using the same `git show HEAD:` fixture technique as Phase 4.
- `shellcheck` clean on `task-lock.sh`.
- Build of the changed module plus enumerated direct dependents: `test-task-lock-reap.sh`,
  `test-session-registry.sh`, `test-conflict-predicate.sh`, `test-four-tier-conflict.sh`,
  `test-session-runtime-files.sh` all pass unchanged -- the dead-pid mirror case specifically
  proves the WARN-and-proceed path for a non-live holder is untouched.

---

### Phase 6: Re-derive the Registry's Union `file_scope` on Heartbeat (Piece 3) [COMPLETED]

**Goal**: Stop `session-heartbeat` from echoing a registration-time `file_scope` snapshot, so a
task whose `file_scope` widens after registration is reflected in the registry.

**Tasks**:
- [x] Re-read `scripts/task-lock.sh` immediately before editing. *(completed)*
- [x] Extract `cmd_session_register`'s union computation (the `get_file_scope` loop over *(completed)*
      `task_numbers_json` into a temp file, then `jq -s -c 'add | unique'`, then the
      empty/`null` -> `[]` normalization, then the `rm -f`) into one shared helper, e.g.
      `derive_union_file_scope <task_numbers_json>`, printing the JSON array on stdout.
- [x] Call it from `cmd_session_register` in place of the inlined block -- **same inputs, same *(completed)*
      output, no behavior change there**.
- [x] Call it from `cmd_session_heartbeat` using the `task_numbers_json` it already reads back, *(completed)*
      replacing the verbatim `file_scope_json` read. Keep `task_numbers_json`, `pid`,
      `pid_source`, `command` and `started_at` read back verbatim as today (a session's task set
      does not change mid-flight; only the per-task `file_scope` in `specs/state.json` widens).
- [x] Preserve `cmd_session_heartbeat`'s contract exactly: a missing or unparseable entry remains *(completed)*
      a stderr WARN and exit 0, never a block on the caller; no registry schema change; no change
      to `write_session_entry`'s argument order.
- [x] Extend `scripts/test-session-registry.sh` with a case: register a session, widen the *(completed)*
      covered task's `file_scope` in the fixture `state.json`, run `session-heartbeat`, assert the
      entry's `.file_scope` now contains the newly added path -- and a companion case asserting
      `session-register`'s own output is unchanged by the extraction.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts `cmd_session_heartbeat` reads back exactly six fields
(`pid`, `pid_source`, `command`, `task_numbers`, `file_scope`, `started_at`) and that
`file_scope` is the only one that must be recomputed. Confirm at implementation time by
re-reading `cmd_session_heartbeat` and `write_session_entry` and enumerating their fields.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - new `derive_union_file_scope()` helper;
  `cmd_session_register` calls it; `cmd_session_heartbeat` calls it instead of reading
  `.file_scope` back verbatim
- `agent-system/extensions/core/scripts/test-session-registry.sh` - widen-then-heartbeat case plus
  a register-output-unchanged case
- `agent-system/extensions/core/context/patterns/task-lock.md` - update the Session-Registry CLI
  section to state that `session-heartbeat` re-derives `file_scope`

**Verification**:
- Build/lint of the single changed module: `shellcheck` clean on `task-lock.sh`.
- `bash agent-system/extensions/core/scripts/test-session-registry.sh` passes, including every
  pre-existing case unmodified.
- The new widen-then-heartbeat case fails against the pristine script (`git show HEAD:` fixture)
  and passes against the modified one.

---

### Phase 7: Wake Class E and Fix the Batch-Size Message (Absorbed a + b) [NOT STARTED]

**Goal**: Make the pre-dispatch session-registry contention review actually run, and stop the
MAX_TASKS guard from telling the operator that batching is unsupported. Both absorbed defects are
handled in one phase because they share `commands/orchestrate.md`.

**Tasks**:
- [ ] Re-read `commands/orchestrate.md` and `docs/architecture/orchestrate-state-machine.md`
      immediately before editing -- both overlap open sibling tasks, so a foreign modification is
      a STOP-and-report condition, not noise.
- [ ] (a) Move the `source .claude/scripts/lib/common.sh` / `batch_session_id="$(common_session_id)"`
      pair (currently ~line 250) to **before** the `orchestrate-predispatch-review.sh` call
      (~line 202), and pass `--session-id "$batch_session_id"` into that call.
- [ ] (a) Verify no statement between the two current positions feeds `common_session_id()`
      (the dependency-graph construction and the MAX_TASKS guard both sit between them and
      neither is an input), and record that finding in a comment beside the moved mint.
- [ ] (a) Record the ordering subtlety in the same comment: the review runs **before**
      `session-register`, so `session_contention()`'s self-session-id exclusion is a no-op against
      the caller's own not-yet-registered id -- harmless, and other live sessions are still
      surfaced correctly. Note explicitly that **no change to
      `scripts/orchestrate-predispatch-review.sh` is required**: it already parses `--session-id`,
      gates on `session_id_explicit`, and threads the flag into the batch-admit subprocess.
- [ ] (a) Note that the MAX_TASKS truncation stays **after** the review call, so the review
      continues to see the untruncated candidate list -- existing behavior, deliberately unchanged.
- [ ] (b) Replace the message at `commands/orchestrate.md:236` with text that keeps the
      operationally useful "first N only" fact and drops the false "not yet supported" framing,
      e.g. `"Batch size $task_count exceeds MAX_TASKS=$MAX_TASKS. Running with the first $MAX_TASKS tasks only."`
- [ ] (b) Apply the identical replacement at `docs/architecture/orchestrate-state-machine.md:736`
      so the two sites stay verbatim-identical.
- [ ] Confirm `context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default"
      framing needs no edit (it is already correct; it was the two sites above that contradicted it).

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly two sites carry the stale message
(`commands/orchestrate.md:236`, `docs/architecture/orchestrate-state-machine.md:736`) and exactly
one site mints `batch_session_id`. Confirm at implementation time by re-running
`grep -rn "Batching is not yet supported" agent-system/extensions/` and
`grep -rn "batch_session_id=" agent-system/extensions/` and handling every hit found.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - mint `batch_session_id` before the
  predispatch-review call; pass `--session-id`; corrected MAX_TASKS message
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - the same
  corrected MAX_TASKS message, kept verbatim-identical to the command's

**Verification**:
- `grep -n "orchestrate-predispatch-review.sh" agent-system/extensions/core/commands/orchestrate.md`
  shows `--session-id "$batch_session_id"` on the call, and the mint appears on an earlier line
  number than the call.
- `grep -rn "Batching is not yet supported" agent-system/extensions/` returns nothing.
- A direct probe reproduces the fix: run
  `bash .claude/scripts/orchestrate-predispatch-review.sh --session-id "$(bash -c 'source .claude/scripts/lib/common.sh; common_session_id')" <two task numbers>`
  and confirm the Class E section no longer prints
  `SKIPPED (no --session-id supplied to this script; ...)`.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` and any
  suite asserting on `orchestrate.md`'s recipe text pass.

---

### Phase 8: Full Gate and ACCEPTANCE Checklist [NOT STARTED]

**Goal**: Prove every ACCEPTANCE bullet from the task description holds, under the repository's
complete gate set, before the task closes.

**Tasks**:
- [ ] Confirm `git diff --stat` shows **zero** changes to
      `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`.
- [ ] Confirm every changed path is under `agent-system/extensions/core/` and **no** path under
      `.claude/**` was hand-authored.
- [ ] Run `shellcheck` on every touched shell script per
      `context/standards/shell-strict-mode.md`: `task-lock.sh`, `update-phase-status.sh`,
      `lib/phase-heartbeat-lib.sh`, `orchestrate-build-dispatch.sh`,
      `orchestrate-cycle-postflight.sh`, `lint/lint-agent-contracts.sh`, and every new or extended
      test suite.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` (both documented test
      locations are auto-discovered, so the new `scripts/tests/test-task-lock-liveness.sh` and
      `scripts/tests/test-lint-agent-contracts-heartbeat.sh` are picked up without registration).
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`), confirming Gate 6 (agent-contracts
      lint) and Gate 8 (suite discovery) are green.
- [ ] Re-run `bash .claude/scripts/check-task-references.sh` to confirm no task-number reference
      was introduced outside `specs/**`.
- [ ] Assemble the ACCEPTANCE evidence in the task summary: (i) the Phase 1 written answer and its
      location; (ii) the captured pristine-script failure output and modified-script pass output
      for the two-live-sessions and stale-but-pid-alive cases; (iii) the untouched
      `orchestrate-batch-admit.sh`; (iv) the unchanged pre-existing `held-fresh`/`held-stale`
      lines plus the passing existing consumer suites; (v) clean shellcheck.

**Timing**: 1 hour

**Depends on**: 2, 3, 5, 6, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the shellcheck target list and the gate set are complete
as enumerated. Confirm at implementation time by deriving the shellcheck list mechanically from
`git diff --name-only` filtered to `*.sh`, rather than from this enumeration, and by taking the
gate set from `verify-deploy.sh`'s own gate roster rather than a hand-picked subset.

**Files to modify**:
- none planned (gate-only phase; any file touched here is a defect fix surfaced by a gate, and is
  committed under the phase whose work it belongs to)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate it aggregates reported green.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 with zero NEW failures.
- All five ACCEPTANCE evidence items above are recorded in the task summary.

---

## Testing & Validation

- [ ] `scripts/tests/test-task-lock-liveness.sh` (NEW) covers the **stale-but-pid-alive** case and
      the **two-live-sessions overlap** case, and both **demonstrably fail against the pristine
      `task-lock.sh`** (`git show HEAD:` fixture) before the fixes land -- the task's explicit
      ACCEPTANCE requirement.
- [ ] Negative/fallback coverage proves nothing regressed: missing registry entry, corrupt entry,
      and `dead-pid` entry all keep today's `held-stale` line, exit 2, and WARN-and-proceed
      acquire behavior byte-for-byte.
- [ ] Every pre-existing consumer suite passes unmodified: `test-task-lock-reap.sh`,
      `test-session-registry.sh`, `test-conflict-predicate.sh`, `test-four-tier-conflict.sh`,
      `test-session-runtime-files.sh`, `tests/test-phase-heartbeat.sh`.
- [ ] `tests/test-phase-heartbeat.sh` gains a dispatch-boundary case and keeps every existing case
      unmodified, proving the phase-transition trace line shape did not drift under the library
      extraction.
- [ ] `tests/test-lint-agent-contracts-heartbeat.sh` (NEW) proves Check I warns on an inventoried
      offender (exit 0) and fails on a synthetic new offender.
- [ ] `test-session-registry.sh` gains a widen-then-heartbeat case proving Piece 3.
- [ ] Direct probe: Class E no longer prints its `SKIPPED (no --session-id supplied...)` line.
- [ ] `shellcheck` clean on every touched script per `context/standards/shell-strict-mode.md`.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` and
      `bash .claude/scripts/verify-deploy.sh` both green.
- [ ] `git diff --stat` confirms `scripts/orchestrate-batch-admit.sh` is untouched.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/task-lock.md` - the Piece 1 written verdict and
  probe, the adoption inventory, the two recorded scope reductions, the third `check` state's
  contract, the acquire escalation trigger, and the `session-heartbeat` re-derivation note
- `agent-system/extensions/core/scripts/lib/phase-heartbeat-lib.sh` - NEW; the single extracted
  heartbeat implementation
- `agent-system/extensions/core/scripts/update-phase-status.sh` - sources the lib; output unchanged
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - dispatch-start pulse
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - dispatch-end pulse
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - advisory Check I plus the
  recorded migration inventory
- `agent-system/extensions/core/scripts/task-lock.sh` - `held-live` third state in `cmd_check`;
  liveness consult in `cmd_acquire`'s overlap pass; `derive_union_file_scope()` shared by
  `session-register` and `session-heartbeat`
- `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh` - NEW
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-heartbeat.sh` - NEW
- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` - dispatch-boundary case
- `agent-system/extensions/core/scripts/test-session-registry.sh` - widen-then-heartbeat case
- `agent-system/extensions/core/commands/orchestrate.md` - earlier session mint, `--session-id`
  threaded, corrected MAX_TASKS message
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - corrected
  MAX_TASKS message
- `specs/272_honest_session_liveness_concurrent_batches/summaries/01_*-summary.md` - execution
  summary carrying the five ACCEPTANCE evidence items

## Rollback/Contingency

Every phase is a small, additive diff committed on its own, so the ordinary contingency is to
revert the single offending phase commit (`git revert <sha>`) and re-plan that phase alone. Three
targeted escape hatches exist if a landed change misbehaves in the field:

- **Piece 1 (dispatch-boundary pulses)**: `PHASE_HEARTBEAT_DISABLE=<any value>` already disables
  the heartbeat entirely, restoring exact pre-mechanization behavior. Phase 2 must keep that
  opt-out honoured by the extracted library, so this remains available at every new call site.
- **Piece 2 (`held-live` / acquire escalation)**: the fallback paths keep today's behavior
  byte-for-byte for every non-`pid-alive` verdict, so reverting is a one-branch deletion; a field
  override is additionally available by raising `TASK_LOCK_STALE_MIN` so the stale branch is not
  reached.
- **Piece 3**: `derive_union_file_scope()` is behavior-identical at `session-register`, so a
  revert is confined to `cmd_session_heartbeat`'s single changed assignment.

If a rollback must discard uncommitted working-tree changes rather than revert a commit, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape (including its out-of-scope override flag) -- never a bare precautionary
`git-snapshot.sh 272`. For an ordinary defensive checkpoint before risky work, use
`git-snapshot.sh --no-revert`, which is durable without reverting the working tree.
