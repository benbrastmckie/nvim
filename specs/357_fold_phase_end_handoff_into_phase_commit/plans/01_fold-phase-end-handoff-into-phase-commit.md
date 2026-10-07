# Implementation Plan: Task #357

- **Task**: 357 - Fold phase-end handoff into phase commit
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/357_fold_phase_end_handoff_into_phase_commit/reports/01_fold_phase_end_handoff_into_phase_commit.md
- **Artifacts**: plans/01_fold-phase-end-handoff-into-phase-commit.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-staging-scope.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research settled the load-bearing question with evidence: no consumer anywhere in the source
store depends on the per-phase `handoffs/phase-{P}-handoff-*.md` file landing in a commit
separate from its phase's work commit. The one mtime/`dispatch_seq` freshness gate in the system
guards a different, singular artifact (`.orchestrator-handoff.json`) whose freshness is keyed to
filesystem mtime and an embedded content field, neither of which is a function of commit
boundaries. **The chosen outcome is therefore the fold**, delivered as a sequencing/emphasis
correction to agent prose plus a recorded contract sentence — not a staging-scope change (the
handoff path already sits inside the sanctioned task-directory pathspec) and not a schema or
content change to the handoff itself. Definition of done: the single-commit-per-phase expectation
is stated in `context/standards/git-staging-scope.md`, the production site in
`agents/general-implementation-agent.md` is reworded so the handoff is written before (and rides
inside) the phase's closing commit, two existing contracts carry one-sentence cross-references,
and the gates confirm no new document and no task-number references.

### Research Integration

Four findings from the report drive this plan directly:

1. **Not load-bearing** (report Decision 1). `orchestrator-runtime-files.md`'s Class Table has no
   row for `handoffs/*.md`; the only freshness gate reads `.orchestrator-handoff.json`. Folding
   defeats nothing.
2. **The dispatch's suspected production site is wrong** (report Executive Summary, final bullet).
   `skill-orchestrate/SKILL.md` and `scripts/orchestrate-cycle-postflight.sh` each hold exactly
   one `git-commit-scoped.sh` call site, firing once per dispatch *return*, never once per
   plan-phase. Both files are in this task's declared `file_scope` and **both are ruled out as
   edit targets** — see "File-Scope Correction" below. The real site is
   `agents/general-implementation-agent.md`'s Stage 4D-iii plus its Phase Checkpoint Protocol.
3. **Staging is already correct; only sequencing is wrong** (report, "Existing precedent").
   `git-staging-scope.md` already names `handoffs/` as durable content the exclusion-set design
   deliberately does *not* drop, and the Phase Checkpoint Protocol's step-5 pathspec is the whole
   task directory. The handoff rides along automatically if it exists by commit time.
4. **Crash-ordering is acceptable and must be recorded** (report Decision 5). Substantive phase
   work is already protected by the mandatory per-objective green-substep commits
   (`task {N} phase {P}.{O}: ...`), so a folded commit's content is bounded to phase wrap-up
   bookkeeping. Losing that to a crash means redoing bookkeeping, not work.

### File-Scope Correction

The task's declared `file_scope` is descriptive/anticipated, not validated. This plan corrects it
against the research:

| Declared path | Disposition |
|---|---|
| `core/context/standards/git-staging-scope.md` | **Edit** (Phase 1) — primary ruling home |
| `core/rules/git-workflow.md` | **Edit** (Phase 3) — commit-cadence cross-reference |
| `core/skills/skill-orchestrate/SKILL.md` | **Ruled out, no edit** — not the production site |
| `core/scripts/orchestrate-cycle-postflight.sh` | **Ruled out, no edit** — not the production site |

Two paths are **added** to the effective scope, neither claimed by a concurrent sibling (sibling
356 holds the extension implementation agents plus three other core files; sibling 358 holds
`report-format.md` and `plan-format.md`):

- `core/agents/general-implementation-agent.md` — the actual behavioral fix site (Phase 2)
- `core/context/contracts/phase-closure.md` — one-sentence cross-reference (Phase 3)

Ruling out the two heavily-contended declared paths is a direct benefit: `SKILL.md` is claimed by
five open tasks and `orchestrate-cycle-postflight.sh` by five, so not touching them removes this
task from that contention entirely.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:

- Record the ruling with its reason in `context/standards/git-staging-scope.md`'s `### implement`
  Per-Operation Scope section: one commit per phase; the phase's wrap-up provenance (heading
  marker, progress file, self-review annotations, phase-end handoff) rides in that same commit.
- Address the crash-between-commits ordering argument **in writing in a deliverable**, not only in
  the research report.
- Correct the sequencing prose at the real production site so the handoff is written before the
  phase-closing commit fires, with an explicit, standalone "do not commit this separately"
  instruction adjacent to the commit step.
- Cross-reference the ruling from `rules/git-workflow.md`'s commit-cadence list and from
  `phase-closure.md`'s existing marker/commit-synchrony bullet, so a reader finds it from any
  entry point.
- Classify the `(tracking update)` shape in writing and keep it explicitly out of the behavioral
  fix, while letting the contract sentence cover its *content class* on principle.
- Keep net document count flat; keep every deliverable free of task-number references; keep the
  deploy boundary (source store only).

**Non-Goals**:

- Changing what the handoff contains, or its schema.
- Stopping handoff writes. The provenance is wanted.
- Rewriting existing history in any repository.
- Touching any consumer repository, or any file under `.claude/**`.
- Adding a new standards document.
- Editing `skill-orchestrate/SKILL.md` or `orchestrate-cycle-postflight.sh` (ruled out above).
- Editing any extension implementation agent this cycle (sibling-held territory; recorded as a
  recommendation instead — see Phase 4).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Prose-only fix does not change agent behavior, since current prose already places the handoff write before the commit and agents still execute it out of order | H | M | Phase 2 makes the instruction a standalone, bolded sentence *immediately adjacent to the commit step* (not a trailing clause of a denser step) — the remediation style `phase-closure.md` already used for the analogous marker-promotion defect. The Phase Checkpoint Protocol step-5 code block is the last thing an agent reads before committing, so the instruction lands there too, not only at 4D-iii. |
| Extension implementation agents (books, cslib, email, latex, nix, nvim, python, rust, typst, web, z3) restate the same loop in their own words; a core-only fix may not reach them | M | H | The ruling lands in `git-staging-scope.md`, which every implementation agent already lists in its `## Context References`, so the contract reaches them without editing them. Phase 4 records the per-agent prose alignment as a named recommended follow-up rather than assuming propagation. Those files are sibling-356 territory this cycle and MUST NOT be edited here. |
| `git-staging-scope.md` is declared by four other open tasks; a sibling may edit it concurrently | M | M | Per the dispatch Territory block: re-read the file immediately before editing, stage only this task's own hunks via an explicit file list (never a directory or glob pathspec), and STOP and report any foreign commit or foreign uncommitted modification after confirming via `git log` that it is not this task's own. |
| The source store changed since research, invalidating the "no consumer" finding | H | L | Phase 1 re-runs the three decisive greps against the current source store before writing the ruling, and the ruling sentence states the finding as verified-at-authoring. |
| Generalizing the contract sentence to all phase wrap-up provenance is mistaken for folding the `(tracking update)` shape in by assumption | L | M | The sentence is justified by the general one-commit-per-phase principle, and Phase 1 explicitly scopes it as a content-class statement. The `(tracking update)` shape's *production site* remains unverified and explicitly out of scope; Phase 4 records that classification. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`general-implementation-agent.md` vs. `rules/git-workflow.md` + `phase-closure.md`), so the wave
is genuinely parallel-safe.

---

### Phase 1: Record the ruling in the staging-scope contract [COMPLETED]

**Goal**: The single-commit-per-phase expectation, its evidence, and the crash-ordering rationale
are stated in the designated contract home, so the next reader does not re-open the question.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` immediately
      before editing (sibling-contention guard per the Territory block).
- [x] Re-run the three decisive greps against the current source store and record their results
      inline in the dispatch's issue log or the eventual summary:
      (a) `grep -rn 'handoffs/' agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
      — expect no Class Table row for the per-phase markdown handoff;
      (b) `grep -rln 'phase-.*-handoff' agent-system/ --include=*.sh` — expect no shell consumer;
      (c) `grep -rn 'mtime\|dispatch_seq' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
      — expect every hit to concern `.orchestrator-handoff.json`, not `handoffs/*.md`.
      If any grep contradicts the research finding, STOP, do not edit, and return `blocked` with
      the contradicting output quoted.
- [x] Add a short subsection (or a clearly delimited paragraph block) to the `### implement`
      section under `## Per-Operation Scope`, stating: a plan phase closes with **exactly one**
      commit; that phase's wrap-up provenance — the phase-heading marker promotion, the progress
      file, the post-phase self-review annotations, and the phase-end handoff under
      `handoffs/` — is written *before* that commit and staged into it; a trailing,
      provenance-only commit after an already-fired phase commit is not sanctioned.
- [x] In the same block, state the evidence for why this is safe: the per-phase handoff is
      ordinary durable task content with no freshness consumer (contrast
      `.orchestrator-handoff.json`, whose mtime/`dispatch_seq` gate is independent of commit
      boundaries), and the handoff's own filename embeds a UTC timestamp, so any
      filename-derived freshness signal survives being staged into the work commit unchanged.
- [x] In the same block, address the crash-ordering argument explicitly in one or two sentences:
      a crash before the single commit loses the phase's wrap-up bookkeeping but not its
      substantive work, which the mandatory per-objective green-substep commits already landed;
      the smaller commit count is preferred over a loss window bounded to re-doable bookkeeping.
- [x] Confirm in the same block that this does not widen staging scope: `handoffs/` already lies
      inside `specs/{padded}_{slug}/` and is already named in this document's own
      "Canonical Runtime-File Exclusion Set" rationale as content the exclusion design
      deliberately does not drop.
- [x] Add a pointer from the new block to `context/contracts/phase-closure.md`'s
      "Marker/commit synchrony is bidirectional" section (the other half of the same principle).
- [x] Stage and commit only this file, by explicit path.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new block inside
  `### implement` under `## Per-Operation Scope` (currently lines ~132-145), carrying the ruling,
  its evidence, the crash-ordering rationale, the no-scope-widening confirmation, and the
  `phase-closure.md` pointer.

**Verification**:

- `grep -n 'exactly one' agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns the new ruling sentence inside the `implement` section.
- `grep -n 'handoff' agent-system/extensions/core/context/standards/git-staging-scope.md` shows
  the new block in addition to the pre-existing exclusion-set mention.
- The three greps above are recorded with their actual output; none contradicts the finding.
- Diff read-through confirms every changed hunk is prose inside this one file and the file still
  parses as the same document structure (no heading-level change, no section reorder).
- `git status --short` shows exactly one modified file for this phase's commit.

---

### Phase 2: Correct the sequencing prose at the production site [COMPLETED]

**Goal**: The implementation agent that actually produces the two commits is reworded so the
handoff write is bound to the phase-closing commit, with the instruction placed where it will be
read immediately before committing.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md` immediately
      before editing.
- [x] In `#### 4D-iii. Progressive Handoff Update` (currently ~lines 465-485), add a standalone,
      bolded sentence stating that this file is staged into the phase's own closing commit (the
      Phase Checkpoint Protocol step-5 commit below) and MUST NOT be committed separately; no
      `add phase-end handoff` commit, or any other provenance-only commit, is sanctioned after a
      phase commit has already fired. Point at the new `git-staging-scope.md` block.
- [x] Keep 4D-iii's existing "may be omitted on the last phase" note intact — omission remains
      permitted; only the separate commit is forbidden.
- [x] In `## Phase Checkpoint Protocol` step 4 (currently ~line 876), make the ordering explicit:
      the self-review (4D-ii) and the handoff write (4D-iii) both complete *before* step 5 fires,
      because step 5's pathspec is what carries them into history.
- [x] In `## Phase Checkpoint Protocol` step 5, immediately adjacent to the
      `git-commit-scoped.sh` code block, add a one-line statement that the `"${task_dir}/"`
      pathspec already sweeps in the marker, progress file, self-review annotations, and handoff,
      so step 5 is the *only* commit this phase produces.
- [x] Add a matching entry to the file's `**MUST NOT**` list: do not issue a second,
      provenance-only commit after a phase's closing commit.
- [x] Verify no task-number reference was introduced (the file lives under `agent-system/**`;
      `{N}`/`{P}` placeholders are the convention and are fine, a literal number is not).
- [x] Stage and commit only this file, by explicit path.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - bolded binding sentence
  in `4D-iii`; ordering clarification in Phase Checkpoint Protocol step 4; single-commit statement
  adjacent to step 5's code block; one new `MUST NOT` entry.

**Verification**:

- `grep -n 'separately\|only commit' agent-system/extensions/core/agents/general-implementation-agent.md`
  returns the new statements at both 4D-iii and the Phase Checkpoint Protocol.
- `grep -c 'git-commit-scoped.sh' agent-system/extensions/core/agents/general-implementation-agent.md`
  is unchanged from before the edit (no commit call site added or removed).
- Diff read-through confirms every changed hunk is prose; no code block's command, flags, or
  `stage_paths` contents were altered.
- `bash .claude/scripts/check-task-references.sh` reports no new violation for this file.

---

### Phase 3: Cross-reference from the two existing contract entry points [COMPLETED]

**Goal**: A reader arriving at commit cadence from `rules/git-workflow.md`, or at phase closure
from `phase-closure.md`, finds the ruling without having to already know it lives in
`git-staging-scope.md`. Net document count stays flat — both are sentence additions to existing
files.

**Tasks**:

- [x] Re-read both target files immediately before editing.
- [x] In `agent-system/extensions/core/rules/git-workflow.md`, qualify the
      `### Create Commits After` bullet "Each implementation phase completion" (currently line 43)
      so it reads as *exactly one* commit per phase completion, carrying that phase's wrap-up
      provenance, with a pointer to the new `git-staging-scope.md` block.
- [x] In the same file's `### Do Not Commit` list, add a bullet forbidding a trailing,
      provenance-only commit issued after a phase's closing commit has already fired.
- [x] Leave the `## Commit Conventions` Standard Actions table untouched — `task {N} phase {P}:
      {phase_name}` already is the one sanctioned per-phase message and no new row is needed; the
      improvised `add phase-end handoff` subject is not being added as a convention, it is being
      retired by the ruling.
- [x] In `agent-system/extensions/core/context/contracts/phase-closure.md`, extend the
      **Promotion-on-commit (the under-claim direction)** bullet (currently ~lines 153-161) with
      one sentence naming the phase-end handoff (and the progress file / self-review annotations)
      alongside the marker as same-commit content, under the identical "sequencing requirement,
      not a new staging requirement" framing the bullet already uses, pointing at the new
      `git-staging-scope.md` block.
- [x] Stage and commit both files together by explicit two-path list (one logical change), or as
      two per-file commits — either satisfies the staging contract; never a directory pathspec.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/rules/git-workflow.md` - qualified `Create Commits After` bullet;
  one new `Do Not Commit` bullet.
- `agent-system/extensions/core/context/contracts/phase-closure.md` - one sentence appended to the
  promotion-on-commit bullet of `## Marker/commit synchrony is bidirectional`.

**Verification**:

- `grep -n 'phase completion' agent-system/extensions/core/rules/git-workflow.md` shows the
  qualified bullet.
- `grep -n 'handoff' agent-system/extensions/core/context/contracts/phase-closure.md` returns the
  new sentence.
- Both files' heading structure is unchanged (`grep -c '^#'` identical before and after).
- Diff read-through confirms prose-only hunks.

---

### Phase 4: Gates, ruled-out-file confirmation, and recorded follow-ons [COMPLETED]

**Goal**: Every acceptance criterion is mechanically confirmed, the two ruled-out declared-scope
files are proven untouched, and the two out-of-scope items (extension-agent prose alignment, the
`(tracking update)` shape) are recorded as classified recommendations rather than silently
dropped.

**Tasks**:

- [x] Confirm **zero** changes to the two ruled-out files:
      `git diff --stat HEAD -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
      must be empty for this task's commits. If a sibling task modified them this cycle, confirm
      via `git log` that the change is not this task's own, and report it rather than reverting it.
      *(completed: `git show --stat` on each of this task's three phase commits confirms neither
      file appears)*
- [x] Confirm **zero** changes to any extension implementation agent (sibling-356 territory):
      `git diff --stat HEAD -- 'agent-system/extensions/*/agents/*implementation*'` shows nothing
      attributable to this task. *(completed: confirmed via per-commit `git show --stat`)*
- [x] Confirm net document count did not increase: `git status --porcelain` and
      `git log --diff-filter=A --name-only` for this task's commits show **no added** file under
      `agent-system/**`. Only modifications. *(completed: zero added files under agent-system/**)*
- [x] Confirm no task-number references in any deliverable outside `specs/**`:
      `bash .claude/scripts/check-task-references.sh` clean for all four changed files.
      *(completed: all four PASS with 0 occurrences)*
- [x] Shellcheck: **not applicable** — this task changes no shell script. Record that explicitly
      rather than silently skipping it, and confirm it by showing that every changed path ends in
      `.md`. *(completed: confirmed, with one deviation — see Scope Hypothesis re-ruling below)*
- [x] Run the repository gate set: `bash .claude/scripts/verify-deploy.sh`. If it reports a
      failure in a file outside this task's four changed paths, treat it as possibly a sibling's
      in-flight edit per the Territory block — check `git log`/`git diff` for authorship before
      concluding it is a regression from this task. *(completed: see Scope Hypothesis re-ruling
      and the summary's Verification section for the full triage)*
- [x] Record in the execution summary, as classified recommendations (not as edits):
      (a) **extension-agent prose alignment** — the eleven extension implementation agents that
      independently restate the phase loop should receive the same sequencing correction; confirmed
      present in the books agent, unverified in the others; deferred because those files are
      concurrently held this cycle;
      (b) **the `(tracking update)` shape** — same general defect family (late-sequenced
      provenance trailing an already-fired work commit), but a **different and unverified
      production site**: its content is plan-checklist and progress-file updates, not a handoff
      file, and the preceding work commit in the one measured instance does not even follow the
      `task {N} phase {P}: {phase_name}` subject convention. It is **not** ruled legitimate — no
      contract sanctions a trailing tracking-only commit either — and the new contract block
      covers its content class on principle, but its production site is explicitly out of scope
      here and warrants a separate audit;
      (c) **consumer-repo consequence** — the fold changes future behavior only; existing history
      in any consumer repository stays as it is, and no consumer repository was touched.
- [x] Commit the summary and metadata with this task's closing commit.

**Timing**: 45 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This plan asserts **four** changed files
(`git-staging-scope.md`, `general-implementation-agent.md`, `rules/git-workflow.md`,
`phase-closure.md`) and **zero** changed shell scripts. Confirm at implementation time with
`git diff --name-only HEAD` filtered to this task's commits: the result must be exactly those
four `.md` paths under `agent-system/extensions/core/` (plus `specs/**` artifacts). A fifth
source-store path, or any `.sh` path, means the scope hypothesis failed and must be re-ruled
before the task closes — not silently absorbed. Likewise, the report's claim that the eleven
extension implementation agents restate the loop is confirmed for the books agent only; the
remaining ten are unverified and are deliberately not asserted as fact by this plan.

**Scope Hypothesis — RE-RULED (per its own "not silently absorbed" instruction)**: a FIFTH
source-store path was touched: `agent-system/extensions/core/index-entries.json` (JSON, not
`.sh`). Cause: Gate 3 (doc-lint Rule R) FAILed because `git-staging-scope.md` and
`phase-closure.md`'s line counts grew (533->564, 192->196) as a direct result of this task's own
planned edits, staling their `index-entries.json` `line_count` fields. Remedy: a surgical 2-line
JSON patch updating only those two entries' `line_count` values to the new actual counts,
verified via `git diff` to touch no sibling-owned entry. This is ruled **mechanical bookkeeping
required by the planned edits' own growth, not scope creep** — no new behavioral content, no
new standards document, and the hypothesis's "zero `.sh` files" half still holds exactly. A
SECOND deviation surfaced in the same gate pass: Gate 20 (orchestrator eager-context budget)
regressed because `git-workflow.md` is eager-loaded and Phase 3's originally-drafted bullets
added 531 B; both bullets were rewritten to compact pointer form (net +264 B instead of +531 B),
landing the live measurement 58 B under the fixed baseline with no baseline change. See the
summary's Verification section for the full `verify-deploy.sh` gate-by-gate triage.

**Files to modify**:

- `specs/357_fold_phase_end_handoff_into_phase_commit/summaries/01_*-summary.md` - execution
  summary carrying the three recorded recommendations.
- `specs/357_fold_phase_end_handoff_into_phase_commit/plans/01_fold-phase-end-handoff-into-phase-commit.md` -
  phase status markers.

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` exits 0 (or its only failures are provably attributable
  to a sibling task's in-flight edits, with the `git log` evidence quoted).
- `bash .claude/scripts/check-task-references.sh` exits 0.
- `git diff --name-only` over this task's commits lists exactly the four source-store `.md` paths
  plus `specs/**` artifacts — no added file, no `.sh` file, no ruled-out file.
- The summary contains all three recorded recommendations, each explicitly labelled as a
  recommendation rather than a completed change.

---

## Testing & Validation

- [ ] The three decisive greps (Phase 1) are re-run against the current source store and none
      contradicts the "no consumer" finding.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0.
- [ ] No file added under `agent-system/**` (net document count flat).
- [ ] No `.sh` file changed (shellcheck therefore not applicable, recorded explicitly).
- [ ] `skill-orchestrate/SKILL.md` and `orchestrate-cycle-postflight.sh` unmodified by this task.
- [ ] No extension implementation agent modified by this task.
- [ ] The crash-between-commits argument appears in a deliverable under `agent-system/**`, not
      only in the research report.
- [ ] The `(tracking update)` classification appears in the execution summary.
- [ ] Every commit uses an explicit path list; no directory or glob `git add` pathspec appears in
      any command run.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/git-staging-scope.md` (modified) — the ruling,
  its evidence, the crash-ordering rationale, the no-scope-widening confirmation.
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified) — the
  behavioral sequencing fix at the real production site.
- `agent-system/extensions/core/rules/git-workflow.md` (modified) — commit-cadence
  cross-reference and the new `Do Not Commit` bullet.
- `agent-system/extensions/core/context/contracts/phase-closure.md` (modified) — one-sentence
  cross-reference completing the marker/handoff symmetry.
- `specs/357_fold_phase_end_handoff_into_phase_commit/summaries/01_*-summary.md` (new) — execution
  summary with the three recorded recommendations.
- No new document under `agent-system/**`. No shell change. No consumer-repo change.

## Rollback/Contingency

All four source-store changes are prose-only additions to existing markdown files, each landing in
its own phase commit. Reverting is `git revert` of the specific phase commit(s) — no working-tree
discard, no snapshot, and no history rewrite is required or permitted here.

Should Phase 1's re-confirmation greps contradict the research finding (i.e. a real consumer of
the separate commit is discovered), the task pivots to the **other valid completion**: no fold,
and instead record in the same `git-staging-scope.md` block *why* the separation is load-bearing,
naming the consumer. Phases 2 and 3 then change character — Phase 2 becomes a no-op (no sequencing
fix, since the separation is required) and Phase 3's cross-references point at the
load-bearing ruling instead. That pivot is a full completion, not a partial one; the dispatch
admits either outcome. Do not proceed past Phase 1 on a contradiction without re-ruling.

If a sibling task lands a conflicting edit to `git-staging-scope.md` mid-phase, stop, re-read the
file, and re-apply this task's hunk onto the sibling's version rather than reverting the sibling's
work or force-staging over it.
