# Implementation Plan: Task #237

- **Task**: 237 - Wire the external-process wait pattern into the general implementation and research agent contracts
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: 236 (created `context/patterns/external-process-wait.md`)
- **Research Inputs**: specs/237_wire_wait_pattern_into_agent_contracts/reports/01_wire_wait_pattern_pointer.md
- **Artifacts**: plans/01_wire-wait-pattern-pointer.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a short pointer block to two core agent contracts that sends a dispatched subagent to
`context/patterns/external-process-wait.md` whenever it must wait on a long-running
external/remote process such as a CI run. The block goes right after each file's Context
Exhaustion Monitoring stage. It has concise MUST / MUST NOT bullets that cite the pattern file's
numbered rules instead of restating them, and it adds one load-on-demand line to each file's
`## Context References` list. All edits target the source store
(`agent-system/extensions/core/agents/`), never `.claude/**`. The task is done when both files
carry the block and the context reference, the lints pass, and no task numbers appear in either
deliverable.

### Research Integration

The research report (`reports/01_wire_wait_pattern_pointer.md`) supplies ready-to-apply text for
both files. It fitted that text into each file, checked it, then reverted it. Its main findings:
- The pattern file exists and defines six numbered rules under `## Required Rules`: (1) bounded
  blocking wait, (2) no no-op filler, (3) no `run_in_background`/Monitor for CI waits in a
  subagent, (4) a Monitor emits only on state change, (5) independent local work first, (6) a
  ~45 min cap followed by handoff and partial return. This plan confirmed the headings at plan
  time.
- Anchors: in `general-research-agent.md`, the anchor is the end of `### Stage 3.5: Context
  Exhaustion Monitoring`, before `### Stage 3.6`. In `general-implementation-agent.md`, it is the
  end of the `#### Context Exhaustion Monitoring (Stage 4.5)` bullet list, before the
  "**Derive `project_name` and `task_number` before first use**" paragraph.
- Rule 6's handoff step reuses each file's existing handoff mechanism (research Stage 3.6;
  implementation Stage 4C, `#### E.`) by reference. It does not restate that mechanism.
- Extension agents are left out on purpose (see Non-Goals).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided for this dispatch.

## Goals & Non-Goals

**Goals**:
- Add a `## Context References` line to both core agent files. It loads
  `external-process-wait.md` on demand only.
- Insert an "External Process Wait Discipline" pointer block with MUST bullets (Rules 1, 5, 6)
  and MUST NOT bullets (Rules 2, 3) in both files, at the researched anchors.
- Keep the blocks short. They point to the pattern file and do not restate its mechanics.

**Non-Goals**:
- Editing extension agents, including the four `-hard` variants. The research recommends a
  follow-up task scoped to those files.
- Creating `bounded-build-waiter.md`, which the pattern file references as a dangling link.
- Editing `.claude/**` (the deploy tree) or the pattern file itself.
- Touching sibling-task territory: `scripts/orchestrate-build-dispatch.sh`, `scripts/tests/`,
  `hooks/detect-noop-bash.sh`, `merge-sources/settings-hooks.json`, `manifest.json`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A concurrent sibling edits the same file mid-phase | M | L | Sibling scopes do not overlap these two files. Re-read each file just before editing, stage only the explicit file path, and stop and report if a foreign change appears. |
| The anchor text has drifted since research | L | L | Before inserting, re-grep the anchor headings/paragraph. Adapt the placement to the equivalent spot and do not force stale text. |
| An agent-contract lint rejects a new heading or bullet shape | M | L | Phase 3 runs `lint-agent-contracts.sh`. If a heading form is flagged, use the bold-label form (as in the implementation agent) instead. |
| Wait bullets get duplicated into the handoff stages later | L | L | The block text says it points to the pattern file rather than restating it, and it names the handoff stage instead of repeating its steps. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire pointer into general-research-agent.md [COMPLETED]

**Goal**: Add the context reference line and the External Process Wait Discipline subsection to
the research agent contract.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/agents/general-research-agent.md` right before
      editing, and confirm the `### Stage 3.5` / `### Stage 3.6` headings and the
      `checkpoint-before-overflow.md` Context References line are present. *(completed)*
- [x] Insert the research report's Context References line immediately after the
      `checkpoint-before-overflow.md` line: `@.claude/context/patterns/external-process-wait.md`,
      loaded on demand only when a long-running external/remote wait occurs. *(completed)*
- [x] Insert the report's `### External Process Wait Discipline` subsection after the Stage 3.5
      closing line ("If pressure is detected, ... proceed to Stage 3.6.") and before `### Stage
      3.6`. Use the report's exact MUST (Rules 1, 5, 6; Rule 6 names "Stage 3.6 above") and
      MUST NOT (Rules 2, 3) bullets. *(completed)*
- [x] Confirm that no task numbers appear in the added text and that lines stay at about 100
      characters or less. *(completed)*
- [x] Commit only this file with `git add -- agent-system/extensions/core/agents/general-research-agent.md`. *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md` - one Context References line
  and one new subsection between Stage 3.5 and Stage 3.6

**Verification**:
- `grep -c "external-process-wait" agent-system/extensions/core/agents/general-research-agent.md`
  returns at least 2 (the reference line and the block).
- The subsection sits between `### Stage 3.5` and `### Stage 3.6` (check with `grep -n`).
- `git diff` shows only additions in this file.

---

### Phase 2: Wire pointer into general-implementation-agent.md [COMPLETED]

**Goal**: Add the context reference line and the External Process Wait Discipline block inside
Stage 4.5 of the implementation agent contract.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md` right before
      editing, and confirm the `#### Context Exhaustion Monitoring (Stage 4.5)` bullet list and
      the following "**Derive `project_name` and `task_number` before first use**" paragraph. *(completed)*
- [x] Insert the report's Context References line immediately after the
      `checkpoint-before-overflow.md` line (the one mentioning Stage 4C). It points to "External
      Process Wait Discipline under Stage 4.5". *(completed)*
- [x] Insert the report's bold-label block (`**External Process Wait Discipline**:` followed by
      `**MUST**:` / `**MUST NOT**:` bullet lists) after the Stage 4.5 bullet list and before the
      "Derive `project_name`" paragraph. Rule 6's bullet names "Stage 4C below". *(completed)*
- [x] Confirm that no task numbers appear in the added text and that lines stay at about 100
      characters or less. *(completed)*
- [x] Commit only this file with `git add -- agent-system/extensions/core/agents/general-implementation-agent.md`. *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - one Context
  References line and one bold-label block inside Stage 4.5

**Verification**:
- `grep -c "external-process-wait" agent-system/extensions/core/agents/general-implementation-agent.md`
  returns at least 2.
- The block appears after the "proactively write a handoff" bullet and before the "Derive
  `project_name`" paragraph.
- `git diff` shows only additions in this file.

---

### Phase 3: Validate contracts and deliverable rules [COMPLETED]

**Goal**: Run the repo's contract and task-reference checks over both edited files and fix any
findings.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/check-task-references.sh`, or its
      per-file mode if it has one, and confirm neither edited file introduces a finding.
      *(completed: ran scoped to agent-system/extensions/core/agents, 0 occurrences)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`. Also run
      `lint-contract-compliance.sh` if it applies to agent files. Confirm there are no new
      failures attributable to these edits. Compare against a pre-edit baseline if the lint was
      already red. *(completed: lint-agent-contracts.sh passed 104/104 checks, 0 failures;
      lint-contract-compliance.sh is scoped to hard-mode contract wiring and does not apply to
      these two non-hard agent files)*
- [x] Confirm that the referenced path `context/patterns/external-process-wait.md` exists in the
      source store and that both blocks cite Rules 1, 2, 3, 5, 6 with numbers matching the
      pattern file's `### N.` headings. *(completed: confirmed via grep, headings 1-6 match)*
- [x] Confirm that `git status` shows no stray edits to `.claude/**`, extension agents, or
      sibling-territory files from this task. *(completed: only this task's own plan file was
      uncommitted; the two agent files were already committed by phase)*
- [x] If a fix is needed, edit only the two target files and commit them by explicit path.
      *(completed: no fix was needed)*

**Timing**: 20 minutes

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: The edits touch exactly two files (the two core agent contracts). Confirm
with `git log --stat` over this task's commits. Any third file means scope drift.

**Files to modify**:
- None expected. Fixes, if any, go only to the two Phase 1/2 files.

**Verification**:
- The task-reference check and the agent-contract lint report no new findings for either file.
- The rule numbers cited in both blocks match `external-process-wait.md`'s `## Required Rules`.

## Testing & Validation

- [ ] Both agent files contain an on-demand `external-process-wait.md` Context References entry.
- [ ] Both agent files contain MUST (Rules 1, 5, 6) and MUST NOT (Rules 2, 3) bullets that point
      to the pattern file and do not restate its mechanics.
- [ ] Rule 6's handoff step names the existing handoff stage (research Stage 3.6; implementation
      Stage 4C).
- [ ] `check-task-references.sh` and `lint-agent-contracts.sh` report no new findings.
- [ ] No files under `.claude/**` or extension agent directories are modified.

## Artifacts & Outputs

- `agent-system/extensions/core/agents/general-research-agent.md` (modified)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified)
- `specs/237_wire_wait_pattern_into_agent_contracts/summaries/01_wire-wait-pattern-pointer-summary.md`

## Rollback/Contingency

Every change is additive and committed per file. To roll back, `git revert` the phase commit(s)
for the affected file. No uncommitted-work rollback, and therefore no snapshot, is expected. If
one is ever needed, follow `context/contracts/recovery.md`'s rollback rung for the invocation
shape.
