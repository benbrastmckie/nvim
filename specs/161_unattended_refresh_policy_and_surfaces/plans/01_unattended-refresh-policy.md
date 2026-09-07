# Implementation Plan: Task #161

- **Task**: 161 - Settle the unattended-refresh policy and update the systemd, skill, and command surfaces
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: Task 160 (completed)
- **Research Inputs**: `specs/161_unattended_refresh_policy_and_surfaces/reports/01_unattended-refresh-policy.md`
- **Artifacts**: plans/01_unattended-refresh-policy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close out an already-settled policy question and repair two documentation surfaces that grew
incrementally. The unattended hourly `claude-refresh` timer is already non-destructive by
construction; this task records *why* that remains true after three new passes were added, makes
an explicit ruling on the unit's dependency on the gitignored deploy tree, and replaces the
"bolted-on additions" structure of `skill-refresh/SKILL.md` and `commands/refresh.md` with a
single scannable pass inventory naming each pass's gate and destructiveness. Definition of done:
both units still verify, the service comment carries both rulings, both surfaces carry a complete
and consistent inventory, and every acceptance gate is either run green or reported UNRUN.

### Research Integration

The research report establishes four load-bearing facts this plan builds on directly:

- **Both technical gates are already green pre-edit.** `systemd-analyze verify` exits 0 on both
  units (the only output is an unrelated `cups.socket` legacy-path warning from a system unit),
  and `check-extension-docs.sh` reports `core PASS`. Both tools were re-confirmed present during
  planning. The edits in this plan are designed to be inert to both gates.
- **The "no unit change needed" claim is confirmed at code level, not merely asserted.**
  `claude-refresh.sh`'s `main()` calls `run_claude_pass`, `run_lean_pass`, `run_zombie_pass`, and
  `run_mcp_fanout_pass` unconditionally in one fixed sequence, all threading the same
  `$FORCE`/`$DRY_RUN` pair supplied by the single `ExecStart` line. Two of the four never
  terminate anything under any flag; a third terminates only under `--force`, which the unit never
  passes. This is the reasoning to be recorded, not re-derived.
- **The deploy-path question is genuinely unresolved and unrecorded.** Research recommends
  `ConditionPathExists` over the two bare alternatives, on the grounds that it is the only option
  that changes the actual failure mode (hourly failed-unit noise becomes a clean informational
  skip) rather than only describing it.
- **The surfaces gap is a structural one, not missing content.** Every pass is documented
  somewhere; none of it is in one place, and two specific items lack any destructiveness framing
  or cross-surface mirror.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context and no ROADMAP.md consultation was
requested. Not applicable.

## Goals & Non-Goals

**Goals**:
- Record in `claude-refresh.service`'s own comment block the confirmed ruling that passes added
  after the unit was authored require no unit change, with the code-level reason.
- Make an explicit, recorded ruling on the `ExecStart` dependency on the gitignored `.claude/`
  deploy tree, and implement it.
- Give `skill-refresh/SKILL.md` and `commands/refresh.md` a single, complete, scannable pass
  inventory listing every pass with its gate and whether it is destructive.
- Close the two named surface gaps: postflight-marker destructiveness framing, and the missing
  `refresh.md` mirror for stale session registry entries.
- Run every acceptance gate, or report it UNRUN with the reason.

**Non-Goals**:
- Re-litigating the non-destructive unattended cadence policy. It is settled; this task records
  it.
- Restructuring or rewriting the existing Step-by-step procedural content in `SKILL.md`, or the
  `Process Safety`/`Process Protection` narratives. The inventory supplements them as a summary
  and cites them; it does not replace or duplicate them.
- Changing any runtime behavior of `claude-refresh.sh`. The only permitted script edit is
  `print_help()` text.
- Fixing the unrelated `lean` extension `check-extension-docs.sh` FAIL. Out of file scope.
- Adding a `context/patterns/systemd-unit-conventions.md`. Research explicitly deferred this
  until a third systemd unit exists.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The "seven passes" count in the task description is wrong, and an inventory built on it ships incomplete | H | H | Phase 1 exists solely to derive the inventory from the source files rather than from the description. Planning already found at least one pass (`Step 5: Clean Stale Backup Files`) present in `SKILL.md` but absent from the research report's own inventory table. See Phase 1's Scope Hypothesis. |
| `check-extension-docs.sh` exits non-zero from the pre-existing unrelated `lean` FAIL and is misread as this task's gate failing | M | H | The acceptance-relevant signal is the `core` row staying `PASS`, not the script's overall exit code. Confirmed at planning time: overall `rc=1`, `core PASS`, sole FAIL is `lean`. Phase 5 checks the `core` row explicitly and records the overall code as pre-existing context. |
| An implementer edits the deployed `.claude/**` tree instead of the source store, and the change is silently wiped | H | M | Binding constraint restated in every phase that edits a file; all four target paths are given in full under `agent-system/extensions/core/`. Phase 5 greps the working tree to confirm no `.claude/**` file was modified. |
| `systemd-analyze verify` or `check-extension-docs.sh` unavailable in the implementing environment, and an unrun gate is reported as green | H | L | Both confirmed present at planning time, but availability is an environment property that can differ. Phase 5 requires each gate to be recorded as PASS, FAIL, or UNRUN-with-reason; a truthful UNRUN is the correct outcome and must never be upgraded to assumed-green. |
| The added inventory table drifts from runtime behavior when a future pass is added | M | M | Keep each row a thin pointer citing the owning Step number / section name rather than restating its content, so the step remains the single place needing update. |
| `ConditionPathExists` is read as scope expansion beyond "decide and record" | L | L | The task description itself names it as one of three considered options, so implementing it is within the task's own named scope. The rationale is recorded in the unit comment alongside the directive. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Derive the Authoritative Pass Inventory [NOT STARTED]

**Goal**: Produce the single canonical list of passes -- each with its owning source location,
its gate, and whether it is destructive -- that Phases 2, 3, and 4 all consume. Nothing downstream
should re-derive this.

**Tasks**:
- [ ] Enumerate every `### Step N` heading in `skill-refresh/SKILL.md` and every `echo "=== ... ==="`
      banner it emits. Do not assume the count from the task description.
- [ ] Enumerate every pass function called from `claude-refresh.sh`'s `main()`, confirming each is
      called unconditionally and which `$FORCE`/`$DRY_RUN` gating it applies.
- [ ] Enumerate every `###` subsection under `commands/refresh.md`'s `## What It Cleans` and
      `## Safety`.
- [ ] For each pass, classify its gate as exactly one of: interactive-confirm, `--dry-run`
      preview, age-threshold-only (no confirmation), or report-only-always.
- [ ] For each pass, classify destructiveness as: destructive / non-destructive / destructive but
      recoverable (note the recovery mechanism).
- [ ] For each pass, record whether the hourly systemd cadence reaches it (only
      `claude-refresh.sh`'s internal passes are reached; the file/spec cleanup passes are
      `/refresh`-only).
- [ ] Record the resulting inventory in the progress file as the canonical input to Phases 2-4,
      and note explicitly any pass the task description's list of seven omitted.

**Timing**: 40 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The task description asserts seven passes (orphaned Claude processes,
`~/.claude/` cleanup, orphaned postflight markers, stale task `.lock` dirs, Lean LSP reclamation,
MCP fan-out reporting, zombie reporting); the research report's own table lists nine rows on a
different decomposition. Both are hypotheses, and they disagree. Planning already found a
concrete omission from both: `SKILL.md`'s `### Step 5: Clean Stale Backup Files`. Confirm the real
count and membership by enumerating the `### Step` headings in `SKILL.md`, the pass functions in
`claude-refresh.sh`'s `main()`, and the `###` subsections of `refresh.md` -- and treat that
enumeration, not either prior list, as authoritative. If the confirmed count differs from seven,
that is the expected outcome, not an error; carry the real number forward.

**Files to modify**:
- None. This phase reads and records only.

**Verification**:
- The recorded inventory names, for every pass, all four attributes: source location, gate,
  destructiveness, and whether the hourly cadence reaches it.
- Any divergence from the description's list of seven is stated explicitly with the source
  location that justifies it.

---

### Phase 2: Record Both Rulings in the Service Unit [NOT STARTED]

**Goal**: Make `claude-refresh.service` self-documenting on the two questions this task exists to
settle, so a future reader does not reopen either, and implement the deploy-path ruling.

**Tasks**:
- [ ] Extend the existing `# Policy:` comment block in `agent-system/extensions/core/systemd/claude-refresh.service`
      with a short addendum recording the confirmed ruling on passes added after the unit was
      authored: every pass runs unconditionally from one `main()` sequence threading the single
      `ExecStart` line's `--dry-run`, so no new pass has required or requires its own flag or
      `ExecStart` line; the report-only passes never terminate under any flag, and the Lean pass
      terminates only under `--force`, which this unit never passes.
- [ ] State in the same comment that the file/spec cleanup passes are `/refresh`-only and are
      never reached by this unit, so the ruling is scoped to the script's internal passes.
- [ ] Add `ConditionPathExists=%h/.config/nvim/.claude/scripts/claude-refresh.sh` to the `[Unit]`
      section.
- [ ] Add a comment above that directive recording the deploy-path ruling: `ExecStart` targets the
      gitignored, regenerated deploy tree; when that tree is absent the condition makes systemd
      skip the run as informational rather than failing the unit hourly into `systemctl --failed`;
      this was chosen over leaving it as-is or documenting alone because it is the only option
      that changes the failure mode.
- [ ] Leave `claude-refresh.timer` unedited unless Phase 1's inventory surfaces a concrete reason;
      record "no change needed" if none.
- [ ] Run `systemd-analyze verify` on both unit files and confirm exit 0.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `claude-refresh.sh`'s `main()` calls exactly four pass
functions (`run_claude_pass`, `run_lean_pass`, `run_zombie_pass`, `run_mcp_fanout_pass`), all
unconditional. The comment text must state the count that Phase 1 actually confirmed from
`main()`, not this number taken on faith. If Phase 1 found a different set, write the comment
against the confirmed set and note the discrepancy.

**Files to modify**:
- `agent-system/extensions/core/systemd/claude-refresh.service` - comment addendum recording both
  rulings; one `ConditionPathExists=` directive in `[Unit]`.
- `agent-system/extensions/core/systemd/claude-refresh.timer` - expected no change; confirm and
  record.

**Verification**:
- `systemd-analyze verify agent-system/extensions/core/systemd/claude-refresh.service` exits 0.
- `systemd-analyze verify agent-system/extensions/core/systemd/claude-refresh.timer` exits 0.
- The unrelated `cups.socket` warning is the only output; it references neither target file.
- The comment block states both rulings, and the `ConditionPathExists` path string matches the
  `ExecStart` path character-for-character.

---

### Phase 3: Add the Pass Inventory to SKILL.md [NOT STARTED]

**Goal**: Give `skill-refresh/SKILL.md` one place a reader can scan for every pass, its gate, and
its destructiveness, and close the postflight-marker framing gap.

**Tasks**:
- [ ] Insert a single inventory table into
      `agent-system/extensions/core/skills/skill-refresh/SKILL.md`, placed before the step-by-step
      `## Execution` procedure so it reads as an orientation summary.
- [ ] Populate it from Phase 1's confirmed inventory, one row per pass, with columns: pass name,
      owning Step / section, gate, destructive (yes / no / yes-but-recoverable), and whether the
      hourly systemd cadence reaches it.
- [ ] Keep every row a thin pointer that cites its owning Step number or section name rather than
      restating that step's content.
- [ ] Add an explicit destructiveness statement to `### Step 3: Clean Orphaned Postflight Markers`:
      it deletes unconditionally past a 60-minute age threshold with no interactive confirmation
      when not `--dry-run`, which is a different gate class from the confirmation-gated process
      passes.
- [ ] Update the skill's opening "Performs two operations" framing if Phase 1's inventory shows it
      understates the current pass set.
- [ ] Confirm no edit lands inside an executable bash fence.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The row count of the inserted table is whatever Phase 1 confirmed, not
seven. Confirm by comparing the table's rows one-to-one against Phase 1's recorded inventory
before closing this phase; a row with no corresponding inventory entry, or an inventory entry with
no row, blocks closure.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - new inventory table; Step 3
  destructiveness statement; opening framing sentence if understated.

**Verification**:
- Every pass in Phase 1's inventory appears exactly once as a table row.
- Step 3 carries an explicit destructiveness and gate statement.
- `bash .claude/scripts/check-extension-docs.sh` still reports `core PASS`.
- `git diff` on this file shows no hunk inside a ```bash fence.

---

### Phase 4: Add the Matching Inventory to refresh.md [NOT STARTED]

**Goal**: Make the user-facing command doc carry the same inventory as the skill, and close its
two mirror gaps.

**Tasks**:
- [ ] Insert the same inventory table into `agent-system/extensions/core/commands/refresh.md`,
      near the top of `## What It Cleans`, populated from Phase 1's confirmed inventory.
- [ ] Add the missing `### Orphaned Postflight Markers` subsection under `## What It Cleans`,
      including its age threshold, its gate, and the fact that it is `/refresh`-only and never
      reached by the hourly cadence.
- [ ] Add the missing `### Stale Session Registry Entries` subsection, mirroring `SKILL.md`'s
      Step 4.6, so every Step 3-4.6 item has a `refresh.md` counterpart.
- [ ] Verify the table's rows, gates, and destructiveness classifications are identical to the
      `SKILL.md` table from Phase 3 -- same inventory, adapted wording only.
- [ ] Confirm the `## Options` flag descriptions remain accurate against the inventory.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two missing subsections (orphaned postflight
markers, stale session registry entries). Confirm against Phase 1's inventory by checking each
inventory entry for a corresponding `refresh.md` subsection before closing; if Phase 1 surfaced
additional passes absent from `refresh.md` -- `Clean Stale Backup Files` is a live candidate --
add those subsections too and record the corrected count.

**Files to modify**:
- `agent-system/extensions/core/commands/refresh.md` - inventory table; new postflight-markers
  subsection; new session-registry subsection; any further subsections Phase 1 shows missing.

**Verification**:
- Every pass in Phase 1's inventory has both a table row and a prose subsection or an explicit
  pointer to one.
- The `refresh.md` and `SKILL.md` tables agree row-for-row on gate and destructiveness.
- `bash .claude/scripts/check-extension-docs.sh` still reports `core PASS`.

---

### Phase 5: Help Text and Full Acceptance Gate Run [NOT STARTED]

**Goal**: Bring `--help` into line with the documented inventory and run every acceptance gate,
recording each as PASS, FAIL, or UNRUN with a reason.

**Tasks**:
- [ ] Add a short line to `claude-refresh.sh`'s `print_help()` naming the passes the script runs
      each invocation, using Phase 1's confirmed set. Text-only; change no control flow, no flag
      parsing, and no pass behavior.
- [ ] Run `systemd-analyze verify` on both unit files; record exit codes.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh`; record the `core` row and the overall
      exit code, noting that the overall non-zero code comes from the pre-existing, out-of-scope
      `lean` FAIL confirmed at planning time.
- [ ] Run `bash agent-system/extensions/core/scripts/claude-refresh.sh --help` and confirm its
      output is consistent with the documented inventory in both surfaces.
- [ ] Confirm no file under `.claude/**` was modified: `git status --porcelain` shows changes only
      under `agent-system/extensions/core/` and `specs/`.
- [ ] Confirm no task-number reference was introduced outside `specs/**`.
- [ ] For any gate whose tool is unavailable, record UNRUN with the reason. Never record an
      unavailable check as passing.

**Timing**: 30 minutes

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that five acceptance gates exist (both units verify;
service comment states both rulings; SKILL.md documents every pass with gate and destructiveness;
help text matches the documented inventory; doc-lint `core` row passes). Confirm by re-reading the
dispatch description's ACCEPTANCE paragraph and checking each clause has a recorded result.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `print_help()` text only.

**Verification**:
- Both `systemd-analyze verify` invocations exit 0.
- `check-extension-docs.sh` reports `core PASS`.
- `--help` output names the same pass set the surfaces document.
- `git status --porcelain` contains no `.claude/` path.
- Every acceptance clause has a recorded PASS / FAIL / UNRUN result.

---

## Testing & Validation

- [ ] `systemd-analyze verify agent-system/extensions/core/systemd/claude-refresh.service` exits 0
- [ ] `systemd-analyze verify agent-system/extensions/core/systemd/claude-refresh.timer` exits 0
- [ ] `bash .claude/scripts/check-extension-docs.sh` reports `core PASS` (overall non-zero exit
      from the pre-existing unrelated `lean` FAIL is expected and out of scope)
- [ ] `bash agent-system/extensions/core/scripts/claude-refresh.sh --help` runs and its pass list
      matches the documented inventory
- [ ] `claude-refresh.service` comment block states the new-passes ruling and the deploy-path
      ruling
- [ ] `ConditionPathExists=` path matches the `ExecStart=` path character-for-character
- [ ] `SKILL.md` and `refresh.md` inventory tables agree row-for-row
- [ ] Every pass in the confirmed inventory has a gate and a destructiveness classification in
      both surfaces
- [ ] `git status --porcelain` shows no modified path under `.claude/`
- [ ] No task-number reference introduced outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/core/systemd/claude-refresh.service` - both rulings recorded in the
  comment block; one `ConditionPathExists=` directive added
- `agent-system/extensions/core/systemd/claude-refresh.timer` - expected unchanged; "no change
  needed" recorded
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - pass inventory table; Step 3
  destructiveness statement
- `agent-system/extensions/core/commands/refresh.md` - matching inventory table; postflight-markers
  and session-registry subsections
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `print_help()` text line
- `specs/161_unattended_refresh_policy_and_surfaces/summaries/01_unattended-refresh-policy-summary.md`

## Rollback/Contingency

All five target files are tracked in git under `agent-system/extensions/core/`, and every phase is
committed separately per the commit-per-green-substep mandate, so any phase reverts independently
with `git revert` of its own commit. No deployed state, database, or external system is touched.

The one edit with runtime effect is the `ConditionPathExists=` directive; if it proves wrong on a
target machine (for instance the deploy tree lives at a different path), removing that single line
restores the current behavior exactly, with the comment block retained as the documented record of
the decision and its reversal.

If Phase 1 shows the pass inventory to be substantially larger or differently structured than
either the task description or the research report assumed, do not silently expand Phases 3-4 to
absorb it. Record the confirmed inventory, complete the phases against it, and flag the divergence
in the implementation summary so the scope change is visible rather than absorbed.
