# Implementation Plan: Task #286

- **Task**: 286 - Shared-tree isolation posture verdict (rewrite the split verdict to a blanket verdict)
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/286_shared_tree_isolation_posture_verdict/reports/01_shared-tree-isolation-posture.md
- **Artifacts**: plans/01_shared-tree-isolation-posture.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a documentation-only transcription of an already-closed ruling. The
`## Working-Tree and Build Isolation Posture` section of
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (the source
store — never `.claude/**`) currently records a SPLIT verdict: per-dispatch git-worktree
isolation for implement-phase dispatches of the lean4/cslib family, shared tree plus
contended-path commit refusal elsewhere. It is replaced by a BLANKET shared-tree verdict with no
surviving selection predicate, exactly as ruled in
`specs/decisions/worktree-isolation-removal-verdict.md`.

The work splits cleanly along the dispatch's own four contracts: rewrite the verdict core
(phase 1), reframe the passages that survive as history or measurement (phase 2), correct the
`## Related Documents` list so `dispatch-worktree.sh` no longer reads as a live mechanism
(phase 3), and verify the acceptance criteria plus the single-file diff boundary (phase 4). No
script, test, or caller is touched; the ruling is not re-opened or re-scored at any point.

### Research Integration

The research report confirmed the edit target is singular (one section of one file, plus one
bullet in that file's `## Related Documents` list) and produced a subsection-by-subsection
disposition table that this plan consumes directly as its work order. It also resolved two
passages the dispatch text is silent about, and this plan adopts both of its recommendations:

- `### A Corrected Rationale for Hardlink-Over-Symlink` is marked historical, not deleted —
  it reasons about `dispatch-worktree.sh`'s own internal hardlink-vs-symlink choice, and that
  script survives this task; the dispatch's own "may be cited again" logic applies.
- The second `### Deliberate Divergences` bullet (PATH-shim wrapper, named-not-built) is merged
  into the new Mode 2 subsection, where the dispatch explicitly requires the decline and its
  residual to appear, and the now-duplicate standalone bullet is dropped.

The report also flagged the one acceptance criterion whose target sits outside the section
boundary: the `## Related Documents` first bullet presents the provisioning/land/release
lifecycle as the implementation "this document selects," which must stop being true even though
the script itself is untouched. That is phase 3.

Script *comments* in `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, and
`test-orchestrate-cycle-plan.sh` also cite the split verdict by name. The report confirmed via
repo-wide grep that these are the only other references and that they belong to the separately
sequenced removal task — out of scope here, recorded so the implementer does not go hunting.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- State one blanket shared-tree verdict for every dispatch, every phase, every `task_type`, with
  no surviving selection predicate anywhere in the section.
- Disclaim cost as the reason explicitly, citing the measurements as the proof.
- Record all three layer-induced defects and the structural argument that outlives them.
- Preserve the three-failure-mode taxonomy, the mode-1b decisive-evidence reasoning, the full
  measurements block, and the scoring table (the last reframed as history).
- State the mode 2 ruling as a principle and point at its mechanism's intended home without
  restating or implementing a predicate.
- Name the declined PATH-shim alternative and state its residual.
- Stop presenting `dispatch-worktree.sh` as a live mechanism in `## Related Documents`.

**Non-Goals**:
- Deleting `dispatch-worktree.sh`, its tests, or any caller wiring (the removal task).
- Unwiring `task_selected_for_worktree_isolation()` or `WORKTREE_ISOLATED_TASK_TYPES`.
- Implementing the build-heavy co-scheduling admission predicate (its own sequenced task).
- Editing script comments that cite the split verdict (removal task).
- Re-scoring the options or re-deriving the failure modes — the ruling is transcribed, not
  re-opened.
- Any edit under `.claude/**` (disposable deploy artifact; the source store is the edit target).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A selection predicate survives somewhere in the rewritten prose (a stray "implement-phase lean4/cslib" conditional), silently preserving the split verdict | H | M | Phase 4 greps the edited section for predicate vocabulary (`lean4`, `cslib`, `implement`-phase conditionals, "split") and confirms every surviving occurrence is either the mode 2 co-scheduling principle or explicitly marked historical |
| The `orchestrate-cycle-plan.sh` pointer reads as a claim the co-scheduling predicate already exists | M | M | Word it as a stated intent / future home, per the research report's Decision 5; phase 3 verification re-reads the bullet for present-tense implementation claims |
| Measurements or taxonomy get paraphrased rather than preserved, losing expensive-to-re-derive detail | H | L | Phases 1–2 never retype those blocks: the taxonomy and measurements subsections are left byte-identical and only gain a lead-in sentence; phase 4 diffs them against `git show HEAD` to confirm zero interior change |
| Scope creep into scripts or the deploy tree | M | L | Phase 4 asserts `git status --porcelain` names exactly one modified file, and that no path under `.claude/` or `scripts/` appears |
| A task-number citation leaks into a deliverable outside `specs/**` | M | L | Phase 4 runs the repo-wide task-reference check against the edited file; none of the planned content introduces a task number (the defect record cites mechanisms and scripts, not task numbers) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. Every phase here edits the same file, so the
chain is strictly linear by design — not because of logical dependency alone, but to keep the
edits non-overlapping and each one independently reviewable in the diff.

### Phase 1: Replace the Verdict Core [COMPLETED]

**Goal**: The section's opening framing and its `### The Split Verdict and Its Selection
Predicate` subsection are replaced by the blanket verdict, the cost disclaimer, the defect
record, the structural argument, and the mode 2 principle. After this phase no selection
predicate remains in the section.

**Tasks**:
- [x] Read the current section in full (`## Working-Tree and Build Isolation Posture` through the
      end of `### Deliberate Divergences`) and confirm its boundaries before editing. *(completed)*
- [x] Rewrite the intro paragraph: it currently frames a question answered by a "**split
      verdict**... scored below". Replace with a direct statement of the blanket verdict — every
      dispatch, every phase, every `task_type` runs in the repository's single working tree — and
      a statement that there is no selection predicate. Note that concurrency safety rests
      entirely on declared `file_scope`, `dependencies[]` edges, and the five contention inputs
      already in service. *(completed)*
- [x] Leave `### The Three Failure Modes` and `### Why Mode 1b Is the Decisive Evidence`
      byte-identical. Do not retype, reorder, or reword them. *(completed)*
- [x] Replace `### The Split Verdict and Its Selection Predicate` with a new verdict subsection
      stating the blanket ruling, that `git worktree` isolation is removed rather than narrowed,
      and that two orchestrations in different sessions of one repository may run concurrently in
      that single tree when no `file_scope` collision and no dependency edge relates them. *(completed)*
- [x] Add `#### Cost Was Not the Reason` (or an equivalently titled subsection): state explicitly
      that the disk-and-latency objection was measured and found small, cite the measurements
      block below by name rather than restating its numbers, and state that an argument from cost
      against this verdict is an argument against this repository's own evidence. *(completed)*
- [x] Add the defect record as a table mirroring the decision record's own three rows: the
      destructive release on a `nothing_to_land` verdict (branch-ancestry test that never inspects
      the working tree, folded into the same success branch as `landed`, then released);
      `git-commit-scoped.sh`'s false success inside a worktree (`PROJECT_ROOT` from
      `BASH_SOURCE[0]`, every pathspec falling through the WARN-and-drop branch while the script
      returns success); and the `lake-build-guard.sh` false green (`cp -al` sharing inodes for the
      guard's `build-guard.*` state files, `finalize_record()` truncating in place). Close with
      the explicit statement that no defect of any other origin was ever recorded against that
      dispatch path. *(completed)*
- [x] Add the structural argument as its own subsection: atomic-rename rebindability is a
      PER-WRITER property, not a property of the clone; a truncate-in-place writer never gets it;
      the exclusion list is therefore a hand-maintained enumeration of named files; every
      unrelated script keeping mutable state under a cloned directory is a fresh instance of the
      same hazard; and a layer whose correctness depends on the ongoing discipline of scripts
      that do not know it exists cannot be audited once and then trusted. State that this reason
      outlives all three defects. *(completed)*
- [x] Add the mode 2 ruling as a PRINCIPLE ONLY: build contention is closed by refusing to
      co-schedule two build-heavy implement tasks in one cycle. Do not state, restate, or
      implement the predicate — this document states principles only, so note that the mechanism
      belongs in `orchestrate-cycle-plan.sh`'s own header and that the pointer lives in
      `## Related Documents`. *(completed)*
- [x] In that same mode 2 subsection, name the declined alternative: the PATH-shim wrapper is
      considered and not adopted, and its residual is stated explicitly — a bare build-tool
      invocation from outside an orchestration remains unguarded; that is a different threat
      model from in-orchestration contention and the same exposure the opt-in guard carried
      before worktrees existed, so removal does not worsen it. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the research report places the section at lines 1382-1533 of a 1571-line
file, with `### The Split Verdict and Its Selection Predicate` at 1441-1458. Line numbers are a
hypothesis, not a fact — confirm by locating the headings themselves (`grep -n '^#\{2,4\} ' ` on
the file) before editing, and never by line offset alone.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - intro
  paragraph rewritten; `### The Split Verdict and Its Selection Predicate` replaced by the
  blanket verdict, cost disclaimer, defect record, structural argument, and mode 2 principle

**Verification**:
- Diff read-through confirms every changed hunk is markdown prose inside this one section.
- `grep -n` for `split verdict`, `Selection predicate`, `task_selected_for_worktree_isolation`
  inside the section returns either nothing or only occurrences that are explicitly historical.
- `### The Three Failure Modes` and `### Why Mode 1b Is the Decisive Evidence` show zero interior
  diff against `git show HEAD:` for the same file.
- The five new content obligations (blanket verdict, cost disclaimer, three defects, structural
  argument, mode 2 principle + declined PATH-shim with residual) are each locatable by grep.

---

### Phase 2: Reframe the Surviving Passages [COMPLETED]

**Goal**: Every passage that survives for its measurement, taxonomy, or historical-record value
is correctly framed under the new verdict — none silently dropped, none left reading as a live
selection rationale.

**Tasks**:
- [x] `### Scoring Table`: keep the four-row table verbatim. Add one lead sentence identifying it
      as the historical comparison that produced the now-superseded split verdict, so a reader
      does not mistake it for a live scoring of a live choice. Leave the honest-scoring paragraph
      beneath it intact. *(completed)*
- [x] `### Measurements That Informed the Verdict`: keep every bullet verbatim (worktree add at
      0.09-0.2s; the 16 GiB hardlink clone at ~0.8s with disk movement on the order of 1 GiB; the
      verified atomic-rename/inode experiment; the hunk-attribution infeasibility finding that
      rules out option 3(i)). Add a short lead-in tying the block explicitly to the cost
      disclaimer added in phase 1 — a cross-reference, not a second copy of the numbers. *(completed)*
- [x] `### A Corrected Rationale for Hardlink-Over-Symlink`: mark historical with a one-line
      lead-in (it records `dispatch-worktree.sh`'s own internal hardlink-vs-symlink rationale,
      and that script is not deleted by this change). Do not delete the passage; do not re-argue
      it. *(completed)*
- [x] `### Deliberate Divergences`, first bullet (script-provisioned worktrees vs. a
      harness-level isolation parameter, including the `specs/`-staleness argument and the Move 2
      isolation-forwarding MUST NOT): mark historical rather than dropping it, per the dispatch's
      explicit instruction — it is the record of why a harness-level whole-repo isolation
      parameter was refused, and that reasoning may be cited again. *(completed)*
- [x] `### Deliberate Divergences`, second bullet (PATH-shim wrapper, named-not-built): drop the
      standalone bullet, now that phase 1 states the decline and its residual in the mode 2
      subsection where the dispatch requires it. Confirm no content is lost in the move — the
      opt-in bypass mechanism, the "system-level answer" framing, and the deferral must all be
      present in their new home before this bullet is removed. *(completed)*
- [x] Re-read the whole section end to end for coherence: a reader arriving cold must see one
      verdict, clearly-labelled history, and no residual ambiguity about which posture is live. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - scoring
  table and measurements blocks gain lead-ins; hardlink-over-symlink and the first Deliberate
  Divergences bullet marked historical; the second Deliberate Divergences bullet removed

**Verification**:
- Diff read-through confirms the scoring table rows, the measurements bullets, the
  hardlink-over-symlink body, and the first Deliberate Divergences bullet body are all unchanged
  interiors — only lead-in/marker lines added.
- Every measurement named in the dispatch's survive list is still locatable by grep (`0.09`,
  `0.8 s`, `16 GiB`, `157,000`, `inode`, hunk-attribution).
- The PATH-shim content appears exactly once in the file, in the mode 2 subsection.
- Section reads as one verdict plus labelled history; no sentence presents the split verdict as
  current.

---

### Phase 3: Correct the Related Documents List [COMPLETED]

**Goal**: `## Related Documents` no longer presents `dispatch-worktree.sh` as the live mechanism
this document selects, and it points at the mode 2 mechanism's intended home without claiming the
predicate exists today.

**Tasks**:
- [x] Rewrite the first bullet ("Working-tree and build isolation posture") so it states the
      posture above is now blanket shared-tree; that the `dispatch-worktree.sh`
      provisioning/land/release lifecycle implemented the now-superseded split verdict and
      remains in the tree pending a separately sequenced removal (so a reader who greps for it is
      not left thinking it vanished, or that it is unexplained dead code); and that the mode-1b
      contended-path refusal in `git-commit-scoped.sh` and the staging qualification in
      `context/standards/git-staging-scope.md` are unchanged, those mechanisms being unaffected by
      the posture change. *(completed)*
- [x] Add the mode 2 mechanism pointer, naming `orchestrate-cycle-plan.sh`'s own header as where
      the build-heavy co-scheduling rule belongs. Word it as a stated intent / pointer to that
      mechanism's home, not as a claim that a predicate is implemented there today. Do not
      restate the principle and do not state the predicate. *(completed)*
- [x] Confirm no other bullet in the list needs touching (`file-footprint-overlap.md`,
      `task-lock.md`, `commands/orchestrate.md` + `skill-orchestrate/SKILL.md`,
      `handoff-schema.md`, `multi-task-creation-standard.md`,
      `orchestrator-critical-paths.json`, `regeneration-is-manual-only.md` are all mechanisms
      unaffected by the isolation-posture change). *(completed)*

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - the first
  `## Related Documents` bullet rewritten; mode 2 mechanism pointer added

**Verification**:
- The phrase presenting a lifecycle as the one "it selects" is gone; grep the bullet for
  "selects" and confirm the framing changed.
- `dispatch-worktree.sh` still appears (not silently erased) but only as the superseded
  implementation pending removal.
- The `orchestrate-cycle-plan.sh` pointer contains no present-tense claim that the co-scheduling
  predicate is implemented.
- Diff shows no other bullet in the list changed.

---

### Phase 4: Verify Acceptance and Diff Boundary [COMPLETED]

**Goal**: Every acceptance criterion in the dispatch is mechanically confirmed, and the diff is
proven to touch exactly one file.

**Tasks**:
- [x] Walk the dispatch's ACCEPTANCE list item by item against the edited file and record the
      confirming evidence for each: one blanket verdict with no surviving selection predicate;
      cost explicitly disclaimed as the reason; all three defects and the structural argument
      recorded; measurements and taxonomy survived; mode 2 principle stated with its mechanism
      pointed at rather than duplicated; `## Related Documents` no longer presenting
      `dispatch-worktree.sh` as live. *(completed)*
- [x] Run the repo-wide task-reference check (`bash .claude/scripts/check-task-references.sh`, or
      the equivalent entry point present in this deploy) and confirm the edited file introduces no
      task-number citation — it lives outside `specs/**`, so the rule applies in full. *(completed)*
- [x] Confirm `git status --porcelain` shows exactly one modified path under
      `agent-system/extensions/core/context/patterns/`, and that nothing under `.claude/`,
      `scripts/`, or `tests/` is modified by this task. *(completed)*
- [x] Confirm `dispatch-worktree.sh`, `task_selected_for_worktree_isolation()`, and
      `WORKTREE_ISOLATED_TASK_TYPES` are all still present and untouched — this task changes
      documentation only. *(completed)*
- [x] Read the final rendered section once more top to bottom as a cold reader would, confirming
      a future reader re-running the measurements cannot conclude the decision was a cost mistake. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- None (verification only)

**Verification**:
- Every ACCEPTANCE bullet from the dispatch has a recorded confirming grep, diff hunk, or quoted
  passage.
- Task-reference check passes for the edited file.
- `git status --porcelain` names exactly one modified file.
- Markdown structure is intact: heading levels consistent, no orphaned table rows, no broken
  intra-repo path references introduced.

## Testing & Validation

- [x] The section states exactly one verdict; no conditional selects a posture by phase or
      `task_type` except the mode 2 co-scheduling principle, which selects a *scheduling*
      constraint, not an isolation posture. *(completed)*
- [x] Cost is explicitly disclaimed as the reason, with the measurements cited as proof. *(completed)*
- [x] All three layer-induced defects are recorded with their mechanisms, plus the statement that
      no defect of any other origin was ever recorded against that dispatch path. *(completed)*
- [x] The structural (per-writer atomic-rename) argument is recorded as outliving all three
      defects. *(completed)*
- [x] The three-failure-mode taxonomy, the mode-1b decisive-evidence reasoning, and the full
      measurements block survive with unchanged interiors. *(completed)*
- [x] The scoring table survives, reframed as history. *(completed)*
- [x] The mode 2 mechanism is pointed at, never duplicated or implemented here. *(completed)*
- [x] The declined PATH-shim alternative and its residual are stated exactly once. *(completed)*
- [x] `## Related Documents` no longer presents `dispatch-worktree.sh` as a live mechanism. *(completed)*
- [x] Exactly one file modified; no script, test, or `.claude/**` path touched. *(completed)*
- [x] No task-number reference introduced outside `specs/**`. *(completed)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — rewritten
  `## Working-Tree and Build Isolation Posture` section and corrected `## Related Documents` first
  bullet (the sole deliverable file).
- `specs/286_shared_tree_isolation_posture_verdict/summaries/01_*-summary.md` — execution summary
  at implementation close.

## Rollback/Contingency

The change is confined to one markdown file with no executable surface, so rollback is a single
`git checkout HEAD -- agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
once the tree is otherwise clean (or `git revert` of the phase commits if already committed).
Nothing downstream consumes this section programmatically — `.claude/**` is regenerated from the
source store by the loader, so no deploy step needs undoing. If a phase lands partially, the
previous phase's commit is a coherent resting point: phase 1 alone already states the correct
verdict, and phases 2-3 only improve the framing of surviving material.
