# Implementation Plan: Task #236

- **Task**: 236 - Define external process wait pattern
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (task 172 / `bounded-build-waiter.md` is a cross-reference, not a dependency)
- **Research Inputs**: specs/236_define_external_process_wait_pattern/reports/01_external-process-wait-pattern.md
- **Artifacts**: plans/01_external-process-wait-pattern.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create one new core context pattern file,
`agent-system/extensions/core/context/patterns/external-process-wait.md`. It states the
external-process-wait defect class once and defines the six required wait rules for a subagent
blocked on a long remote job, with GitHub Actions as the first worked example. Then make it
discoverable with an `index-entries.json` entry and add a one-line pointer in
`anti-stop-patterns.md` that follows the single-statement-plus-pointer convention of
`dispatch-report-not-termination.md`. All edits go to the source store
(`agent-system/extensions/core/`), never `.claude/**`.

### Research Integration

The research report found that no existing core file covers this discipline. Nothing in core
mentions `gh run watch`, `run_in_background` for CI waits, or the relation between the inner
timeout and the Bash tool timeout. The closest neighbors are:
`dispatch-report-not-termination.md`, which explains why a watcher or Monitor left armed is
dangerous and supports rule 3; `context/contracts/wrap-up.md`'s "Teardown Precedes the Terminal
Handoff Write"; and `checkpoint-before-overflow.md`, which is the structural and header template.
`bounded-build-waiter.md` does not exist yet. This file therefore lands first and adds the
forward pointer by filename only. The index entry uses the Tier-4 shape: `on_demand: true` with
an empty `load_when.agents`, matching `early-metadata-pattern.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context provided for this dispatch.

## Goals & Non-Goals

**Goals**:
- A canonical pattern file that states the four-part observed incident once and the six
  mandatory rules, with the 540 < 600 arithmetic explained
- Wording that generalizes beyond GitHub Actions to any remote or external job that has no local
  writer to probe
- A forward cross-reference to `bounded-build-waiter.md` by filename, with a one-sentence scope
  distinction: local writer-liveness via `kill -0` there, no local writer here
- An `index-entries.json` entry that makes the file discoverable to implementation and research
  agents
- A one-line pointer in `anti-stop-patterns.md` that does not restate the rules

**Non-Goals**:
- Agent contract edits, `orchestrate-build-dispatch.sh` edits, and hook changes (separate
  dependent tasks)
- Creating or editing `bounded-build-waiter.md`
- Any write under `.claude/**`
- Task-number references in the deliverables

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The 540 vs. 600 relation is under-explained or stated backwards | M | M | State the arithmetic explicitly: an inner `timeout 540` fires about 60s before the harness's 600000ms Bash-tool ceiling, so control returns in the foreground instead of the call being auto-backgrounded |
| The pointer in `anti-stop-patterns.md` becomes a restatement | M | L | Limit it to one sentence that names the distinct trigger (filler during a legitimate wait vs. a forbidden status value) and links out |
| `line_count` in the index entry drifts and a context-index gate flags it | L | M | Measure the file with `wc -l` after Phase 1 and copy the key order from the `early-metadata-pattern.md` entry |
| Sibling task 235 (no declared `file_scope`) edits `index-entries.json` or `anti-stop-patterns.md` at the same time | M | L | Re-read each file just before editing, stage explicit file paths only, and commit only this task's hunks. If a foreign modification shows up, stop and report it |
| A task number leaks into a deliverable (for example, citing the incident's task or task 172) | M | M | Cite by filename only, then run `check-task-references.sh` on the touched files |
| The on-demand index entry is not "discoverable" enough for implementation and research agents | L | L | Decision: keep `on_demand: true` with empty `agents[]`, so the file is not auto-injected into every dispatch. Discovery comes from keywords (`gh-run-watch`, `ci-wait`, `monitor`, `bounded-wait`, and so on) plus the pointer in `anti-stop-patterns.md`. Wiring it into agent contracts is explicitly out of scope and belongs to the dependent tasks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Author external-process-wait.md [COMPLETED]

**Goal**: Create the canonical pattern file with all required content.

**Tasks**:
- [x] Read `checkpoint-before-overflow.md` for the header block and closing-section conventions,
  and `dispatch-report-not-termination.md` for the "Tear Down Watchers/Monitors Before Reporting"
  section heading to cite *(completed)*
- [x] Write the header: `**Created**: 2026-09-18`, `**Purpose**`, `**Audience**` (any dispatched
  subagent blocked on a long external process, phrased generally), `**Related**` *(completed)*
- [x] "The Defect" section: state the four-part incident once and concretely: *(completed)*
  1. The harness blocks a foreground `sleep`.
  2. An unbounded `gh run watch` exceeds the 600s Bash-tool timeout and is auto-backgrounded.
  3. A Monitor loop that echoes on every 20-90s poll wakes the agent on every unchanged status.
  4. Because a subagent that ends its turn terminates, the agent fills the gaps with about 130
     no-op Bash calls and status-only text turns until it is stopped manually.

  Do not cite any task number.
- [x] "Required Rules" section, one subsection per rule: *(completed)*
  1. Bounded blocking wait. Give the exact command
     `timeout 540 gh run watch ID --interval 60 --exit-status >/dev/null; gh run view ID --json status,conclusion`,
     issued with the Bash tool `timeout` set to 600000, and repeated only while the status is
     `in_progress` or `queued`. Explain why 540 < 600: the inner timeout must fire before the
     harness backgrounds the call, and the roughly 60s margin covers the trailing `gh run view`
     and process overhead.
  2. No no-op filler. Forbid `:`, `true`, `date`, `echo waiting`-style calls and status-only
     turns.
  3. No `run_in_background` and no Monitor for CI waits inside a subagent. Give the reason and
     cite `dispatch-report-not-termination.md`.
  4. A legitimate Monitor (for example, in a top-level session) emits only on a state change,
     never on every poll. Use the incident's Monitor as the negative example.
  5. Do independent local work first.
  6. A total-wait cap of about 45 minutes. At the cap, write a handoff with the run ID, the exact
     resume command, and what remains, then return `status: "partial"`. Point at
     `../formats/handoff-artifact.md` and the orchestrator handoff contract instead of inventing
     a schema, and note that `anti-stop-patterns.md` forbids `completed`.
- [x] "Generalizing Beyond GitHub Actions" paragraph: any remote job that is polled through a
  CLI or API status call and has no local PID to `kill -0` uses the same shape: a bounded inner
  timeout below the tool ceiling, a status re-check, and a total cap. *(completed)*
- [x] "Local vs. Remote Waits" paragraph with a forward pointer to `bounded-build-waiter.md` by
  filename. That file covers the local detached-build case (writer-liveness via `kill -0`, one
  waiter per log); this file covers the case with no local writer. Note that the reciprocal
  pointer lands with that file. *(completed)*
- [x] "Related Documentation" bullets: `dispatch-report-not-termination.md`,
  `../contracts/wrap-up.md` (the teardown-before-handoff rule, cited rather than restated),
  `checkpoint-before-overflow.md`, `anti-stop-patterns.md`, `../formats/handoff-artifact.md`,
  `bounded-build-waiter.md` *(completed)*
- [x] Confirm that the relative link targets exist, except `bounded-build-waiter.md`, which is a
  deliberate forward reference *(completed: verified all five non-forward-reference targets exist
  under context/patterns/, context/contracts/, and context/formats/)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Expected size is about 120-180 lines. Confirm with `wc -l` after writing;
the measured value feeds Phase 2's `line_count`.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/external-process-wait.md` - new file

**Verification**:
- `grep -c "timeout 540 gh run watch" external-process-wait.md` returns at least 1, and the text
  explains 540 < 600 explicitly
- All six rules are present as distinct subsections. The 45-minute cap and `partial` return are
  stated.
- `grep -nE '\btasks? [0-9]+' external-process-wait.md` finds no task references, and
  `bash agent-system/extensions/core/scripts/check-task-references.sh` (or its per-file mode)
  passes for the file
- `bounded-build-waiter.md` is named by filename

---

### Phase 2: Index entry, anti-stop pointer, and validation [COMPLETED]

**Goal**: Make the pattern discoverable and link to it from `anti-stop-patterns.md` without
restating the rules.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/index-entries.json` just before editing (sibling
  territory). Insert a `patterns/external-process-wait.md` entry in path-sorted position among
  the `patterns/*` entries, copying the key order of the `early-metadata-pattern.md` entry:
  - `domain: "core"`, `subdomain: "patterns"`
  - summary: "Bounded-wait discipline for a subagent blocked on a long external process (CI
    runs, remote jobs)"
  - `line_count`: the measured value from Phase 1
  - keywords such as `external-process`, `bounded-wait`, `gh-run-watch`, `ci-wait`, `monitor`,
    `no-op-filler`, `timeout`
  - topics `["workflow", "orchestration"]`
  - empty `load_when` arrays and `"on_demand": true` *(completed)*
- [x] Re-read `agent-system/extensions/core/context/patterns/anti-stop-patterns.md`. Add exactly
  one pointer line under `## Background References` > `### Internal Documentation` (or as a
  one-sentence note just before it). Suggested wording: "A distinct failure mode, filling a
  legitimate external-process wait with no-op Bash calls or status-only turns, is covered in
  `context/patterns/external-process-wait.md`; see that file rather than restating it here."
  Do not restate any rule. *(completed)*
- [x] Validate: `jq empty agent-system/extensions/core/index-entries.json`, and confirm the new
  entry's `line_count` equals `wc -l` of the file *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` over the three
  touched files *(completed)*
- [x] If available against the source store, run `check-extension-docs.sh` and
  `validate-context-index.sh`. They mainly target the deployed index, so only a regression they
  attribute to this entry counts as a failure. Do not deploy or regenerate `.claude/`.
  *(completed: check-extension-docs.sh flagged this edit's own anti-stop-patterns.md line_count
  drift (174 -> 177 after the +3-line pointer), fixed in this entry; the remaining core FAIL
  (batch-orchestration-guardrails.md) is sibling task 228's in-flight territory, not this task's
  regression. validate-context-index.sh passed with 0 errors)*
- [x] Stage the three explicit paths only (no directory or glob add) and commit as
  `task 236 phase 2: ...` (Phase 1 commits separately with its own message) *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - add one entry
- `agent-system/extensions/core/context/patterns/anti-stop-patterns.md` - add one pointer line

**Verification**:
- `jq '.entries[]? // .[]? | select(.path == "patterns/external-process-wait.md")'` (adjusted to
  the file's actual top-level shape) returns exactly one entry with `on_demand == true`
- `git diff agent-system/extensions/core/context/patterns/anti-stop-patterns.md` shows a single
  added pointer line or sentence and no rule text
- The task-reference lint passes. `git status --short` shows no modifications outside this
  task's three files that were staged by this task.

## Testing & Validation

- [ ] The new pattern file exists in the source store and contains the incident statement, the
  six rules, the 540/600 explanation, the generalization paragraph, and the forward pointer to
  `bounded-build-waiter.md`
- [ ] `index-entries.json` is valid JSON with one new on-demand entry whose `line_count` is
  accurate
- [ ] `anti-stop-patterns.md` gains exactly one pointer and no restated rules
- [ ] No task-number references in any touched deliverable
- [ ] No writes under `.claude/**`

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/external-process-wait.md` (new)
- `agent-system/extensions/core/index-entries.json` (one entry added)
- `agent-system/extensions/core/context/patterns/anti-stop-patterns.md` (one pointer line)
- `specs/236_define_external_process_wait_pattern/summaries/01_external-process-wait-pattern-summary.md`

## Rollback/Contingency

All changes are additive. To revert, `git revert` the task's phase commits, or delete the new
file and remove the single index entry and pointer line by hand. Do not use `git-snapshot.sh` in
its reverting default mode: sibling tasks share this working tree.
