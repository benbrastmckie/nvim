# Implementation Plan: Task #292

- **Task**: 292 - Add task-count reasoning step to task creation
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/292_task_count_reasoning_in_task_creation/reports/01_task-count-reasoning.md
- **Artifacts**: plans/01_task-count-reasoning-test.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task creation currently has no step that asks how MANY tasks a set of findings should become. The
fix is a single named, bidirectional consolidation-versus-division test authored once in
`agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` (the
reference every multi-task creator already cites by path), then wired in by reference from the
four creation paths that lack it: `commands/task.md`'s Create Task Mode and Expand Mode,
`commands/errors.md` (no grouping logic at all today), and the two existing fuzzy clustering
implementations in `agents/meta-builder-agent.md` Stage 3.5 and `skills/skill-fix-it/SKILL.md`
Step 7.5, which match on key-term/component overlap and therefore cannot see the sharper
shared-edit-target / shared-acceptance-gate signal the motivating incident turned on. All edits
land in the source store under `agent-system/extensions/core/`; the deployed `.claude/` tree is
regenerated in the final phase.

### Research Integration

The research report settled four things this plan depends on:

- **Canonical location**: `multi-task-creation-standard.md` is already cited verbatim by
  `commands/meta.md:12`, `commands/errors.md:205`, `commands/fix-it.md:282`, and
  `commands/task.md:888`. Authoring the test there and referencing it by path from every consumer
  avoids five drifting copies of the same criteria.
- **The precise gap in existing clustering**: Component 3's keys are `file_section` +
  `issue_type`, or 2+ shared `key_terms` + same `priority`. Component 4a's file-overlap check
  runs *after* division is already decided and only adds a serializing dependency edge — it
  reacts to overlap rather than questioning the split. Neither mechanism treats "shares an edit
  target" or "resolves the same acceptance gate" as a standalone consolidation signal.
- **Create Task Mode has no pointer to the standard at all** (Steps 0-9 confirmed by direct read),
  and that is the path ad hoc multi-finding drafting actually walks.
- **Expand Mode Step 2 is genuinely ungoverned**: "Analyze description for natural breakpoints"
  names no criteria, and the `task-divider` component referenced by
  `context/standards/task-management.md` does not exist in the source store (confirmed absent) —
  so it must not be cited as prior art.

The research also recommended (Rec 6) that
`context/patterns/batch-orchestration-guardrails.md` NOT be merged or restated, only
cross-referenced. This plan follows that: Phase 5 adds an inbound pointer only.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- A single named test ("Component 0: Task-Count Reasoning") in
  `multi-task-creation-standard.md`, stating the default (consolidate unless a named divide reason
  applies), the exhaustive divide-reason list, the do-not-divide reasons, and its bidirectional
  application to the division direction.
- Create Task Mode and Expand Mode in `commands/task.md` both reference that test by path at the
  point where task count is actually decided.
- The two existing clustering implementations (`meta-builder-agent.md` Stage 3.5,
  `skill-fix-it/SKILL.md` Step 7.5) gain shared-narrow-edit-target / shared-acceptance-gate as a
  **primary** match criterion, with an explicit exclusion for broad shared-infrastructure files.
- `commands/errors.md` gains a lightweight, non-interactive pre-merge of findings sharing a file
  or gate, before task entries are drafted.
- A bidirectional cross-reference between the new component and
  `batch-orchestration-guardrails.md`'s "Batching Is the Default" section, distinguishing
  how-many-to-create from how-to-run-them.
- The deployed `.claude/` tree is regenerated and verified.

**Non-Goals**:
- No `--interactive` flag for `/errors` (separately tracked in the standard's own "Gaps and Future
  Enhancements" section; this plan adds the consolidation test to `/errors`, not interactive
  selection).
- No change to Component 4a's overlap-to-dependency behavior — it keeps serializing overlapping
  *separate* tasks; the new component operates upstream of it.
- No merge or relocation of `batch-orchestration-guardrails.md` content.
- No remediation of the motivating incident itself (the consolidation was correctly applied there
  by ad hoc judgment; only the systemic gap is in scope).
- No new script, hook, or mechanical enforcement gate. This is a documentation/instruction change;
  a validator that mechanically checks the test was applied is out of scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wording drift across the five files that mention the test | M | H | Full test (default + both reason lists) lives ONLY in `multi-task-creation-standard.md`; every other file references it by path with at most a one-line gloss. Phase 5 greps for restated reason-list text outside the standard. |
| Over-consolidation when findings share a broad, widely-edited file (e.g. `specs/state.json`) | M | M | The new primary criterion is "shares a *narrow* `file_scope` entry or one named acceptance gate", never "shares any file". Phase 1 states the exclusion; Phases 3 and 4 carry it into both clustering copies, consistent with `validate-state.sh` Check 8's WARN-only treatment of directory-root scopes. |
| Slowing `/errors`' intentionally fast non-interactive triage | L | M | `/errors` gets a mechanical pre-merge only (group findings sharing a file or gate), no picker, no user gate. |
| Task-number citations leaking into source-store files | M | M | `.claude/rules/no-task-references-in-deliverables.md` applies to everything outside `specs/**`. The motivating incident MUST be described by its durable anchors (the config file path, the verify-deploy gate, the `file_scope_collision` check), never by task number. Phase 5 runs `check-task-references.sh`. |
| Sibling task concurrently editing the same source store | M | M | A sibling task is scheduled in the same `/orchestrate` cycle with a 20-file `agent-system/extensions/core/` scope that does NOT intersect this plan's six files. Still: re-read each file immediately before editing, stage only this task's own hunks (explicit per-file `git add`, never a directory pathspec), never run `git-snapshot.sh` in reverting default mode, and if a foreign commit or foreign uncommitted modification appears, STOP and report after checking `git log`. |
| Deploy in Phase 5 picks up a sibling's in-flight source-store edits | M | M | `deploy-headless.sh` is whole-tree by construction. Before running it, check `git status --short agent-system/` for foreign modifications; if any exist, report rather than deploying, and leave Phase 5 `[BLOCKED]` on that observation instead of deploying someone else's partial work. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2, 3 and 4 touch disjoint files and
all depend only on Phase 1's authored text existing to point at.

---

### Phase 1: Author "Component 0: Task-Count Reasoning" in the standard [COMPLETED]

**Goal**: The full bidirectional test exists in exactly one place, with the standard's own
checklist, compliance table and gaps section updated to match.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` *(completed)*
      in full immediately before editing (sibling-concurrency precaution).
- [x] Insert a new `### 0. Task-Count Reasoning (Required)` subsection under `## Core Components`, *(completed)*
      immediately before `### 1. Item Discovery (Required)` (currently line 31), so it reads as the
      step that runs before any item is turned into a task entry.
- [x] State the default explicitly and unmistakably: **consolidate unless a named divide reason *(completed)*
      applies**.
- [x] Enumerate the legitimate reasons to divide, as a closed list: *(completed)*
      (a) genuinely disjoint `file_scope` with no overlap under the
      `context/patterns/file-footprint-overlap.md` rule (reference it by path, do not restate it);
      (b) a different `task_type` or owning domain/extension;
      (c) a real dependency ordering between the parts, where one part cannot be verified until the
      other lands;
      (d) a size that will not fit one agent dispatch — cross-reference the phase-sizing bound in
      `merge-sources/claudemd.md`'s Hard Mode section (H8) rather than restating a line count.
- [x] Enumerate the reasons NOT to divide, chiefly: findings that share an edit target (the same *(completed)*
      file or files) or share a single acceptance gate belong in ONE task. Explain why the split is
      actively self-defeating and not merely cosmetic: separate tasks would declare overlapping
      `file_scope`, and Component 4a's own in-batch overlap check would then serialize one behind
      the other, so the two "tasks" were never independently dispatchable.
- [x] State the narrowness qualifier: the shared-edit-target signal means a shared *narrow* *(completed)*
      `file_scope` entry or one named acceptance gate — not a broad, widely-edited infrastructure
      file or a directory root. Cross-reference `validate-state.sh` Check 8 (WARN-only) as the
      existing detector of coarse directory-root scopes.
- [x] State bidirectionality in its own short paragraph: the same closed divide-reason list governs *(completed)*
      the division direction, so an over-large task is still split when (b), (c) or (d) genuinely
      applies — the test is not a one-way bias toward fewer tasks.
- [x] Add the outbound cross-reference to `context/patterns/batch-orchestration-guardrails.md`'s *(completed)*
      "Batching Is the Default" section, explicitly naming the boundary: that section governs which
      already-created tasks are RUN together in one `/orchestrate` invocation; this component
      governs how many tasks are CREATED in the first place. State that neither subsumes the other.
- [x] Relate the new component to the existing `## Task Minimization Principle` section (lines *(completed)*
      9-25) with a forward pointer from that section, so the principle and its now-named test are
      not read as two unrelated things. Do NOT duplicate the reason lists there.
- [x] Note in the component that Component 3 (Topic Grouping) and Component 4a (File Footprint *(completed)*
      Overlap) remain unchanged in behavior, and that this component runs upstream of both.
- [x] Update `## Implementation Checklist` -> `### Required Components` with a *(completed)*
      `- [ ] **Task-Count Reasoning (0)**: ...` line.
- [x] Update `## Current Compliance Status` to add a "Task-Count Reasoning (0)" column, with *(completed)*
      per-command values reflecting the post-implementation state of Phases 2-4 (`/task` create and
      expand: Yes; `/errors`: Yes (non-interactive); `/meta`, `/fix-it`: Yes (primary-match
      criterion)). Leave `/review` and `/task --review` honestly marked as not yet wired, since
      they are out of this plan's scope.
- [x] Update `## Gaps and Future Enhancements` -> `### /errors` so its rationale line no longer *(completed)*
      implies the consolidation gap is intentional; keep the `--interactive` enhancement listed as
      the separate, still-open item.
- [x] Add `.claude/context/patterns/batch-orchestration-guardrails.md` to `## Related *(completed)*
      Documentation`.
- [x] Describe the motivating incident using durable anchors only — the config file path *(completed)*
      `agent-system/extensions/core/context/config/orchestrator-context-budget.json`, the
      verify-deploy gate, the `file_scope_collision` check. NO task-number citation anywhere in this
      file (see `.claude/rules/no-task-references-in-deliverables.md`).

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that the correct insertion point is immediately before
`### 1. Item Discovery (Required)` at line 31, and that the three secondary sections needing
updates are `## Implementation Checklist` (line 409), `## Current Compliance Status` (line 453)
and `## Gaps and Future Enhancements` (line 472). Confirm at implementation time by re-reading the
file's heading map (`grep -n '^#\{1,3\} '`) before editing — the line numbers are from a read taken
at planning time and a sibling task's edits or an unrelated commit may have shifted them.

**Files to modify**:
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` - new
  Component 0 subsection plus checklist, compliance-table, gaps and related-docs updates.

**Verification**:
- The file contains exactly one statement of the default and exactly one copy of each reason list.
- `grep -n 'batch-orchestration-guardrails' ` on the file returns the new cross-reference(s).
- `bash .claude/scripts/check-task-references.sh` reports no new violation for this file.
- Markdown headings render in order: `### 0.` precedes `### 1.` under `## Core Components`.

---

### Phase 2: Wire `commands/task.md` Create Task Mode and Expand Mode [COMPLETED]

**Goal**: Both single-task-creation paths point at the new component at the moment task count is
actually decided, by reference rather than by restatement.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/commands/task.md` around both insertion points *(completed)*
      immediately before editing.
- [x] Insert a new step in Create Task Mode between current Step 2 ("Parse description") and *(completed)*
      Step 3 ("Improve description"), numbered `2.5`, titled "Task-count check (when drafting more
      than one task in the same session)". Its body: when this invocation is one of several
      task-creation calls drafting a related set of findings or observations in the same session,
      run the Task-Count Reasoning test in
      `.claude/docs/reference/standards/multi-task-creation-standard.md` across the whole set
      BEFORE assigning each finding its own description; consolidate findings sharing an edit
      target or a single acceptance gate into one description. Keep it to a few lines plus the path
      pointer — no restatement of the reason lists.
- [x] Add the standard's path to Create Task Mode as an explicit reference (this mode currently has *(completed)*
      no pointer to the standard at all, unlike `--review` mode at line 888). A one-line
      "Standards Reference" note adjacent to the new Step 2.5 is sufficient.
- [x] Replace Expand Mode Step 2's bare "Analyze description for natural breakpoints (use *(completed)*
      DESCRIPTION exported by gate-in)" with a version that applies the divide-reason list by
      reference: a breakpoint is legitimate only where a named divide reason holds (disjoint
      `file_scope`, different `task_type`/domain, real dependency ordering, or size exceeding one
      agent dispatch), citing
      `.claude/docs/reference/standards/multi-task-creation-standard.md`'s Component 0.
- [x] Reframe Step 3's "Create 2-5 subtasks" so the count is a consequence of the test rather than *(completed)*
      an unexplained bound: the number of subtasks is however many the applicable divide reasons
      justify, with 2-5 retained as the expected practical range and a note that a task admitting
      no divide reason should not be expanded at all.
- [x] Do NOT cite `context/standards/task-management.md`'s `task-divider` delegation as prior art — *(completed)*
      research confirmed no such agent or skill exists in the source store.
- [x] No task-number citations in this file. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts two insertion points in one file — the Step 2/Step 3
boundary in Create Task Mode (around line 61) and Expand Mode Step 2 (around line 385, with Step 3
at 419). Confirm by re-reading `grep -n '^## \|^[0-9]\+\. \*\*' commands/task.md` before editing;
if the Create Task Mode step numbering has changed, place the new step at whatever boundary
immediately follows description parsing and precedes description improvement rather than forcing
the literal number 2.5.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - new Create Task Mode Step 2.5 plus a standards
  pointer; Expand Mode Steps 2 and 3 rewritten to apply the divide-reason list by reference.

**Verification**:
- Both insertion points cite `multi-task-creation-standard.md` by path.
- Neither insertion point restates the divide-reason list in full (at most a parenthetical gloss).
- Create Task Mode's step sequence remains monotonic and readable after insertion.
- `bash .claude/scripts/check-task-references.sh` clean for this file.

---

### Phase 3: Add shared-target/shared-gate as a primary match in both clustering copies [COMPLETED]

**Goal**: `/meta` Stage 3.5 and `/fix-it` Step 7.5 mechanically catch the shared-edit-target /
shared-gate case instead of relying on fuzzy key-term overlap, and the two mirrored algorithms stay
in sync.

**Tasks**:
- [x] Re-read both files' clustering sections immediately before editing. *(completed)*
- [x] In `agents/meta-builder-agent.md` Stage 3.5: add a shared-target indicator to the 3.5.1 *(completed)*
      extraction list (the anticipated narrow `file_scope` paths and any named acceptance
      gate/check the item resolves), and add a new **first** primary-match branch to the 3.5.2
      clustering pseudocode — before the existing `component_type` + `affected_area` branch —
      matching when two items share a narrow `file_scope` entry or the same named acceptance gate.
- [x] In `skills/skill-fix-it/SKILL.md` Step 7.5: make the identical change to the "Topic Indicator *(completed)*
      Extraction" list and to the numbered clustering algorithm, keeping the two copies'
      criteria-ordering and wording aligned so a future reader cannot read them as two different
      rules.
- [x] In both files, state the narrowness exclusion inline (one line each): a directory root or *(completed)*
      broad, widely-edited infrastructure file does not trigger this primary match; cross-reference
      Component 0 in `multi-task-creation-standard.md` for the full rule rather than restating it.
- [x] In both files, point to Component 0 by path as the authority for the default and the reason *(completed)*
      lists, keeping the local text limited to the mechanical match criterion.
- [x] Leave each file's existing Component 4a overlap check (`skill-fix-it/SKILL.md` Step 8.2; *(completed)*
      `meta-builder-agent.md`'s 4a passage) untouched — it still runs afterward on whatever
      separate tasks survive consolidation.
- [x] Leave the existing user-facing grouped/separate/combined pickers and their option wording *(completed)*
      unchanged; this phase changes what gets *suggested*, not the user's control over it.
- [x] No task-number citations in either file. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two mirrored clustering implementations exist
(`agents/meta-builder-agent.md` Stage 3.5.1/3.5.2 around lines 453-520, and
`skills/skill-fix-it/SKILL.md` Step 7.5 around lines 201-216, reused by Step 7.7 for QUESTION
items). Confirm before editing with
`grep -rn 'Primary match\|shares 2+ key terms\|Clustering Algorithm' agent-system/extensions/core/`
— if a third copy exists, update it too in this phase rather than leaving a divergent one behind.

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` - Stage 3.5.1 extraction list and
  3.5.2 clustering pseudocode gain the shared-target/shared-gate primary branch.
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` - Step 7.5 extraction list and
  clustering algorithm gain the same branch, worded to match.

**Verification**:
- Both files place the new criterion as the first primary match, ahead of the existing branches.
- Both files carry the narrowness exclusion and the Component 0 path pointer.
- A diff read-through confirms the two copies' criteria are textually consistent.
- `grep -n 'Step 7.7' skills/skill-fix-it/SKILL.md` confirms the QUESTION-item path still reuses
  the amended Step 7.5 algorithm rather than a stale separate copy.
- `bash .claude/scripts/check-task-references.sh` clean for both files.

---

### Phase 4: Give `/errors` a non-interactive consolidation pre-pass [COMPLETED]

**Goal**: `/errors` applies the default-to-consolidate rule mechanically before drafting task
entries, without acquiring an interactive picker.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/commands/errors.md` immediately before editing. *(completed)*
- [x] Insert a new step before `### 4. Create Fix Tasks` (currently line 108), e.g. `### 3.5 *(completed)*
      Consolidate findings before drafting tasks`, specifying a mechanical, non-interactive
      pre-merge: group the errors/findings that would otherwise each become a task when they share
      a narrow file target or resolve the same named acceptance gate, and draft one task per
      resulting group.
- [x] Reference `.claude/docs/reference/standards/multi-task-creation-standard.md`'s Component 0 as *(completed)*
      the authority for the default and the divide-reason list; do not restate the lists here.
- [x] State explicitly that this step adds no user gate and no `AskUserQuestion` — `/errors` keeps *(completed)*
      its fast automatic triage posture, and the separate `--interactive` enhancement remains out
      of scope.
- [x] Carry the narrowness exclusion in one line (a shared broad infrastructure file does not merge *(completed)*
      findings).
- [x] Make sure the existing `## Suggested Tasks` report section (line 101) and *(completed)*
      `### 4a. Update Task Order Section` still read coherently with the pre-pass inserted — the
      report should present the consolidated set, not the pre-merge set.
- [x] Keep the existing Standards Reference line at 205 and extend it only if needed to name *(completed)*
      Component 0.
- [x] No task-number citations in this file. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the insertion point is immediately before `### 4. Create
Fix Tasks` at line 108, and that `/errors` has no existing grouping logic to reconcile with
(research confirmed zero `consolidat|group|cluster` hits). Confirm both with
`grep -n '^### \|consolidat\|group\|cluster' commands/errors.md` before editing; if any grouping
logic has since appeared, amend it in place rather than adding a second, competing pass.

**Files to modify**:
- `agent-system/extensions/core/commands/errors.md` - new non-interactive consolidation step before
  task creation, referencing Component 0.

**Verification**:
- The new step precedes `### 4. Create Fix Tasks` and is cited from nowhere else.
- The file contains no `AskUserQuestion` block added by this phase.
- `grep -n 'multi-task-creation-standard' commands/errors.md` shows the Component 0 reference.
- `bash .claude/scripts/check-task-references.sh` clean for this file.

---

### Phase 5: Inbound cross-reference, deploy, and full verification [NOT STARTED]

**Goal**: The guardrails document points back at the new component, the deployed tree matches the
source store, and the whole change passes the repository gate set with no restated-criteria drift.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s
      "Batching Is the Default" section immediately before editing.
- [ ] Add a short inbound cross-reference in that section (no relocation, no restatement per
      research Rec 6): this section governs which already-created tasks are run together; how many
      tasks to create in the first place is governed by Component 0 in
      `.claude/docs/reference/standards/multi-task-creation-standard.md`.
- [ ] Run the drift check: `grep -rn 'consolidate unless' agent-system/extensions/core/` must match
      the standard only; no other file may carry a full copy of the divide-reason list.
- [ ] Before deploying, run `git status --short agent-system/` and confirm no foreign uncommitted
      modifications outside this task's file_scope. If any are present, STOP, report the
      observation, and leave this phase `[BLOCKED]` rather than deploying another writer's partial
      work (see the concurrency note in this dispatch and
      `context/contracts/territory.md`'s Cross-Task Territory section).
- [ ] Redeploy: `bash .claude/scripts/deploy-headless.sh`.
- [ ] Confirm the six edited source files' deployed counterparts match byte-for-byte (`diff` each
      source/deployed pair, or `bash .claude/scripts/verify-deploy.sh`).
- [ ] Run `bash .claude/scripts/check-deploy-freshness.sh` and confirm `core` is no longer reported
      stale.
- [ ] Run `bash .claude/scripts/check-task-references.sh` repo-wide and confirm no new violations.
- [ ] Run `bash .claude/scripts/validate-wiring.sh` and `bash .claude/scripts/check-extension-docs.sh`
      and confirm no new failures attributable to these edits.
- [ ] Read the new Component 0 once end-to-end as a reader who has never seen the motivating
      incident, confirming the default, both reason lists, the bidirectionality paragraph and the
      guardrails boundary are each unambiguous.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that Phases 1-4 touched exactly five source files and
that this phase adds a sixth, so the deploy check compares six source/deployed pairs. Confirm the
real set at implementation time from `git diff --name-only` across this task's own commits rather
than from this count — if a phase legitimately touched an additional file (e.g. a third clustering
copy found by Phase 3's grep), include it in the byte-for-byte deploy comparison.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - inbound
  cross-reference in the "Batching Is the Default" section.

**Verification**:
- `check-deploy-freshness.sh` reports `core` fresh.
- `verify-deploy.sh` passes; each edited file's deployed copy matches its source.
- `check-task-references.sh`, `validate-wiring.sh`, `check-extension-docs.sh` show no new failures.
- The drift grep confirms the test text exists in exactly one file.
- The cross-reference is bidirectional: the standard points at the guardrails section (Phase 1) and
  the guardrails section points back (this phase).

---

## Testing & Validation

- [ ] `bash .claude/scripts/check-task-references.sh` - no new task-number citations outside
      `specs/**`.
- [ ] `bash .claude/scripts/verify-deploy.sh` - deployed tree matches source store.
- [ ] `bash .claude/scripts/check-deploy-freshness.sh` - `core` no longer stale.
- [ ] `bash .claude/scripts/validate-wiring.sh` - no broken references introduced by the new
      cross-references.
- [ ] `bash .claude/scripts/check-extension-docs.sh` - docs tree consistent.
- [ ] Drift check: the full default-plus-reason-lists text appears in exactly one file.
- [ ] Walkthrough of the motivating scenario against the amended text: two findings sharing one
      config file and one verify-deploy gate are consolidated by the stated rule, not by judgment.
- [ ] Walkthrough of the division direction: an over-large task with a genuine `task_type`/domain
      split or a size exceeding one agent dispatch is still divided under the same list.

## Artifacts & Outputs

- Amended `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
  with Component 0 and updated checklist/compliance/gaps sections.
- Amended `agent-system/extensions/core/commands/task.md` (Create Task Mode Step 2.5; Expand Mode
  Steps 2-3).
- Amended `agent-system/extensions/core/commands/errors.md` (non-interactive consolidation
  pre-pass).
- Amended `agent-system/extensions/core/agents/meta-builder-agent.md` and
  `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` (shared-target/shared-gate primary
  match).
- Amended `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  (inbound cross-reference).
- Regenerated `.claude/` deploy tree for the `core` extension.
- Execution summary at `specs/292_task_count_reasoning_in_task_creation/summaries/01_*-summary.md`.

## Rollback/Contingency

Every change is an additive or in-place documentation edit in the source store, committed per
phase, so reverting is a per-phase `git revert` of that phase's commit followed by
`bash .claude/scripts/deploy-headless.sh` to re-sync the deploy tree. If a phase's edit must be
abandoned mid-way, do not commit the partial edit; restore the file from `HEAD` with a
`git checkout -- <path>` only after taking a non-reverting checkpoint
(`bash .claude/scripts/git-snapshot.sh 292 --no-revert`), since the tree may carry a sibling task's
concurrent work that must not be discarded. If Phase 5's pre-deploy check finds foreign
uncommitted modifications, the correct contingency is to stop and report, leaving Phases 1-4
committed and the deploy for a later cycle — the source-store edits are correct and complete
without the deploy, which is a repo-wide operation.
