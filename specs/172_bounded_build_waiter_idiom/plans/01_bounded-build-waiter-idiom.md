# Implementation Plan: Task #172

- **Task**: 172 - Define a canonical bounded-wait idiom for detached builds
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/172_bounded_build_waiter_idiom/reports/01_bounded-build-waiter-idiom.md
- **Artifacts**: plans/01_bounded-build-waiter-idiom.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Write the missing canonical anchor `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`,
which states the unbounded-waiter defect class once and defines a safe waiter for any detached
local command (not Lean-only), then wire it in with single-statement-plus-pointer citations. The
file already has a dead-ending inbound pointer from `external-process-wait.md`; writing it closes
that hole. Definition of done: the pattern file exists with four mandatory properties and both
symptoms (unbounded poll, turn-ending stop) named; `long-builds.md` carries a one-line pointer
under a new blocking-case section; the file is registered in core `index-entries.json`; the
always-present dispatch-file Wait Discipline block names it so general-implementation-agent
reaches it; all related tests and lints pass.

### Research Integration

- `external-process-wait.md` is the structural template (header block, "The Defect", numbered
  "Required Rules", "Local vs. Remote Waits", "Related Documentation") and already names this
  file in its `Related:` header and "Local vs. Remote Waits" section.
- `lake-build-guard.sh` already documents the `while kill -0 "$holder_pid"` idiom and a `pgrep -f`
  self-match prohibition; cite it as a conforming prior-art example, generalized and wrapped in a
  hard timeout.
- Four properties (sharpened from the description's three): hard timeout; writer liveness by
  captured PID, never process-name matching; one-waiter-per-log with an attach-or-fail-loudly
  disposition for a second would-be waiter; a dead writer ends the wait immediately.
- The index entry for `external-process-wait.md` is a ready-to-copy template (domain `core`,
  subdomain `patterns`, empty `load_when`, `on_demand: true`).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consultation requested for this dispatch.

### Decisions

- **Include the `orchestrate-build-dispatch.sh` Wait Discipline edit (Phase 3).** Research left it
  open. It is in scope: the third evidence round explicitly requires the pointer to reach
  general-implementation-agent, the dispatch-file block is unconditional in every phase and mode,
  and the script is neither an agent file nor one of the three files the description forbids.
  This widens the recorded `file_scope` (currently the pattern file and `long-builds.md` only) by
  `orchestrate-build-dispatch.sh`, its test, and core `index-entries.json`. The implementer should
  note the widening in the summary. If a reviewer rejects it, Phase 3 can be dropped
  independently: `external-process-wait.md` already links to the new file, so general agents
  still reach it through one extra hop.
- **Attach-or-fail-loudly stays at the policy level.** The pattern file states what must not
  happen (silently ending the turn, or spawning a second independent loop) and the two acceptable
  responses. It does not prescribe a lock-file mechanism; the guard-side dependent task owns that.
- **Contract half deferred.** The turn-ending symptom is named and explained in the pattern file,
  but the MUST NOT against ending a turn on a background wait is not written into any agent
  contract here.

## Goals & Non-Goals

**Goals**:
- One canonical, generic (not Lean-only) anchor for waiting on a detached local command, with the
  defect class stated once
- A concrete, greppable waiter shape (a recognizable process signature) that the reaper-side task
  can later match
- Pointers from `long-builds.md`, core `index-entries.json`, and the dispatch-file Wait Discipline
  block

**Non-Goals**:
- Modifying `lake-build-guard.sh`, `claude-refresh.sh`, or any agent file
- Mechanical enforcement of one-waiter-per-log (lock files, guard changes)
- Restating the waiter model inside `long-builds.md`
- Editing anything under `.claude/` (a disposable deploy artifact)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pattern reads as Lean-specific | M | M | Main example is a generic `cmd >log 2>&1 & pid=$!`; Lean guard and the gate-script case appear only as examples |
| Attach-or-fail policy conflicts with a later guard mechanism | M | L | State the policy only; leave the mechanism to the dependent task |
| Task-number references leak into deliverables | M | M | Name incidents by repository and symptom, never by task; run the task-reference lint in Phase 4 |
| Dispatch-script edit breaks the byte-level test expectations | L | L | Add one line to the existing block; add a Group 14 assertion; run the full test file |
| Timeout guidance mixes up wait-duration with the guard's `--timeout` lock-wait | M | M | Explicitly separate the waiter's wait-duration bound from the guard's lock-wait `--timeout` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author bounded-build-waiter.md [COMPLETED]

**Goal**: Write the canonical pattern file, mirroring `external-process-wait.md`'s structure.

**Tasks**:
- [x] Read `agent-system/extensions/core/context/patterns/external-process-wait.md` in full, plus
      `lake-build-guard.sh`'s header and `print_help()` kill -0 / pgrep passages, as templates
- [x] Header block: Created (ISO date), Purpose, Audience ("any dispatched agent that detaches a
      local command and must block on it within the same dispatch", explicitly not Lean-only),
      Related (`external-process-wait.md`, `dispatch-report-not-termination.md`,
      `anti-stop-patterns.md`, `../contracts/wrap-up.md`, the Lean `long-builds.md`)
- [x] "## The Defect": the defect class stated once ("a poll loop whose exit condition is a
      sentinel written by a process that may die first has no bounded termination"; "a liveness
      test keyed on a process name is self-referential whenever the polling shell's argv
      contains the pattern"), then three incidents named by repository and symptom only:
      the sentinel poll (22 + 2 loops on `EXIT=` sentinels that became unwritable when the
      guarded build was superseded); the turn-ending stop ("waiting for lake build", "Monitor is
      already watching"); the `ps aux | grep "[b]ash ..."` self-match (five hangs; the bracket
      trick protects grep from itself, not from the launching shell's own argv)
- [x] "## Two Symptoms, One Missing Affordance": detach-without-a-blocking-idiom forces a choice
      between polling forever and ending the turn; this file is the missing affordance; the MUST
      NOT against ending a turn on a background wait is deferred to the agent-contract layer (no
      task numbers)
- [x] "## Required Rules", numbered:
      1. Hard timeout (`timeout N`) so the waiter cannot outlive its writer; N is a wait-duration
         bound sized to the command's expected run time, distinct from `lake-build-guard.sh
         --timeout` (a lock-wait bound); keep it within whatever the calling tool allows
      2. Writer liveness by captured PID only (`pid=$!`, `kill -0 "$pid"`); prohibit `ps | grep`,
         `pgrep -f`, and any name-matching test; never poll a sentinel alone
      3. A dead writer ends the wait immediately; afterwards read the log or exit status, and
         treat a missing sentinel as "writer died", not "keep waiting"
      4. One waiter per log: before starting a waiter, check for an existing one for the same
         log/PID; a second would-be waiter either attaches (waits on the same recorded PID with
         no second independent loop) or fails loudly naming the existing waiter; never silently
         stop and hand back the turn; a superseded build's waiter is reaped before a replacement
         is spawned
- [x] "## The Canonical Idiom": the sanctioned shape, e.g.
      `cmd >log 2>&1 & pid=$!` then
      `timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"`,
      with the simpler foreground-under-`timeout` form preferred when the command fits the Bash
      tool's limit; note how to read the exit status afterwards (`wait "$pid"` in the same shell,
      or an exit line the writer appends, read after liveness ends, never polled for); state the
      shape as the recognizable process signature a reaper can match
- [x] "## Conforming Examples": `lake-build-guard.sh`'s own `kill -0 "$holder_pid"` idiom
      (prior art, lacking only the timeout wrapper); a generic gate-script example
- [x] "## Local vs. Remote Waits": reciprocal of `external-process-wait.md`'s section
- [x] "## Related Documentation": one line per cross-reference
- [x] Keep lines at roughly 100 characters; no emoji; no task-number references *(completed: all
      Phase 1 tasks done; file written at 120 lines, no lines over 100 chars, task-ref lint clean)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - new file

**Verification**:
- All sections present; four rules numbered; both symptoms named
- `grep -nE '\btasks? [0-9]+' <file>` returns nothing
- Every relative cross-reference resolves to an existing file under `agent-system/extensions/`
- `external-process-wait.md`'s description of the sibling ("a detached build with a local log
  file, where writer-liveness is checked via `kill -0` and a one-waiter-per-log convention
  applies") is still accurate; if the wording has drifted, make a one-line factual fix there

---

### Phase 2: Wire long-builds.md pointer and index registration [NOT STARTED]

**Goal**: Add the Lean-side pointer and register the new file in the context index.

**Tasks**:
- [ ] In `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md`, add a new
      section `## Blocking on a detached build` between "Passive progress checks" and "Completion
      discipline": one or two sentences saying that when a dispatch must block on a detached build
      within the same turn, the sanctioned idiom (hard timeout, PID-captured writer liveness,
      one waiter per log) is in `core` `context/patterns/bounded-build-waiter.md`. Do not restate
      the model. Match the citation style used for `dispatch-report-not-termination.md` elsewhere
- [ ] Optionally add one clause to "The liveness caveat" pointing at the new section, so that
      liveness checks and blocking waits are told apart (one sentence at most)
- [ ] Add a `patterns/bounded-build-waiter.md` entry to
      `agent-system/extensions/core/index-entries.json`, copied from the
      `patterns/external-process-wait.md` entry shape: summary, accurate `line_count`
      (`wc -l`), keywords (`bounded-wait`, `kill-0`, `writer-liveness`, `detached-build`,
      `one-waiter-per-log`, `timeout`, `poll-loop`), topics `workflow`/`orchestration`, empty
      `load_when` arrays, `on_demand: true`

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` - new pointer section
- `agent-system/extensions/core/index-entries.json` - new entry

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` succeeds
- `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes
- `bash agent-system/extensions/core/scripts/validate-context-index.sh` (or its documented
  source-store mode) reports no new errors for the entry
- The new `long-builds.md` section is at most three lines of prose and contains no idiom code

---

### Phase 3: Dispatch-file Wait Discipline carrier [NOT STARTED]

**Goal**: Make the always-present dispatch-file wait pointer reach the local-case anchor, so
general-implementation-agent (and every other dispatched agent) sees it.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`'s unconditional
      `## Wait Discipline` echo block, add a line or two: for a detached local command (a build,
      gate, or test run you backgrounded), read `context/patterns/bounded-build-waiter.md`
      instead: timeout-bounded, `kill -0 "$pid"` on the captured PID, never `ps | grep` or
      `pgrep -f`, one waiter per log
- [ ] Update the script's header comment describing the Wait Discipline block so it names both
      anchors
- [ ] Add matching `assert_contains ... "context/patterns/bounded-build-waiter.md"` assertions to
      Group 14 in `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`
      (base and hard, every phase already covered)

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Only the one echo block, its header comment, and Group 14 of the test need
to change. Confirm by grepping the script for other copies of the Wait Discipline text and the
test suite for byte-exact snapshots of the block (`grep -rn "Wait Discipline" agent-system/extensions/core`);
if a golden file or another emitter exists, update it in this phase too.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - Wait Discipline block and header comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - Group 14 assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` passes
- `bash -n agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` succeeds

---

### Phase 4: Final gate [NOT STARTED]

**Goal**: Run the full relevant gate set over every touched file.

**Tasks**:
- [ ] Run the repo task-reference lint (`check-task-references.sh` in core scripts) over all
      touched deliverables; fix any hit
- [ ] Re-run Phases 2 and 3 test commands together
- [ ] `grep -rn "bounded-build-waiter.md" agent-system/extensions` and confirm every inbound
      pointer (`external-process-wait.md` x2, `long-builds.md`, `index-entries.json`, the
      dispatch script) resolves to the now-existing file
- [ ] Confirm `git status` shows no edits under `.claude/` and no edits to `lake-build-guard.sh`,
      `claude-refresh.sh`, or `agents/*.md`
- [ ] Optionally run `check-extension-docs.sh` if it covers context files, and fix new findings
      in touched files only

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None expected (fixes only, confined to files from Phases 1-3)

**Verification**:
- All listed commands pass; no forbidden file touched

## Testing & Validation

- [ ] `test-orchestrate-build-dispatch.sh` passes, including new Group 14 assertions
- [ ] `test-index-entries-schema.sh` passes; `index-entries.json` is valid JSON
- [ ] Task-reference lint is clean for all touched deliverables
- [ ] Every `bounded-build-waiter.md` pointer resolves; `external-process-wait.md`'s sibling
      description matches the written file
- [ ] No writes under `.claude/`, none to the three forbidden files, none to any agent file

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (new)
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` (pointer section)
- `agent-system/extensions/core/index-entries.json` (new entry)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (Wait Discipline line)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (assertions)
- `specs/172_bounded_build_waiter_idiom/summaries/01_bounded-build-waiter-idiom-summary.md`

## Rollback/Contingency

All changes are additive and per-file. To back out, revert the relevant phase commit with
`git revert <sha>` (commits are per phase). Phase 3 can be reverted on its own without affecting
Phases 1-2. If an uncommitted working-tree rollback is ever needed, follow the snapshot-then-
rollback recipe in `context/contracts/recovery.md`'s rollback rung rather than a bare snapshot.
