# Implementation Plan: Task #668

- **Task**: 668 - Measure Claude Code harness behaviour for a worktree outside the project directory
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: 667
- **Research Inputs**: specs/668_measure_harness_behaviour_for_external_worktree/reports/01_external-worktree-harness-measurement.md
- **Artifacts**: plans/01_external-worktree-harness-measurement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The four measurements this task exists to take were already taken live during the research
dispatch, and its deliverable — `specs/decisions/external-worktree-harness-behaviour.md`, a
measurement record under `specs/decisions/` — already exists with a verdict that none of the four
results refutes R2's siting. What remains is closure, not measurement: the amending record that
*named* the precondition still tells every successor the siting "rests on harness behaviour that
has not been measured", the measurement record states some results without the literal call that
produced them, and the record is still untracked in git. This plan discharges the precondition in
the amending record, closes the measurement record against its own stated criterion, and commits
both.

No measurement is re-taken, no script is edited, and nothing is built under `agent-system/**`.

### Research Integration

- The research report's verdict (no result refutes the siting) is carried through unchanged; the
  refutation branch of the task description — append a dated `**Amended by**` note to R2 and
  "Measured precondition" — is **not** taken, and Phase 3 checks that it was not taken.
- Measurement 3's live result (`guard-destructive-git.sh` anchored to the primary tree regardless
  of a Bash command's own `cd` target) and the report's recommendation to treat both directions
  as one mechanism are left where the research put them: cited for the hooks successor, not acted
  on here.
- The report's Context Extension Recommendation (fold measurement 3 into a two-root hook context
  file) is explicitly assigned to the hooks successor and is a non-goal below.
- The report's one unmeasurable item is carried as a conditional in Phase 2 rather than guessed.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged two description lines. Both checked against the prior artifact and live
state; result stated explicitly even where it only confirms the description:

1. **"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**` ... then REDEPLOY via
   deploy-headless.sh."** Confirmed as a standing constraint, and confirmed **inapplicable to
   this task's scope**: the description's own later line ("This task edits no script. It builds
   nothing under `agent-system/**`") and the deliverable's siting (`specs/decisions/`) agree that
   no deliverable here lands under `agent-system/**`. Every path this plan touches is under
   `specs/**`, which `source-store-deploy-boundary-narrative.md` exempts. No source-store edit
   and no `deploy-headless.sh` redeploy is required; Phase 3 confirms none occurred.
2. **"PARTS OF THIS MAY NEED THE USER AT THE KEYBOARD ... return a `user_decision` rather than
   guessing."** Confirmed still accurate and still open. The research dispatch did exactly this:
   one item (file-tool behaviour for an external path under a non-`bypassPermissions` mode) was
   named unmeasurable, stated as such in the record's measurement 1, and returned as a
   non-blocking `user_decision`. No answer is recorded anywhere in the task directory as of this
   plan, so Phase 2 carries both branches (answer recorded as user-supplied, or re-relayed).

One further live-state check, not flagged by the dispatch but material to Phase 3: the
deliverable `specs/decisions/external-worktree-harness-behaviour.md` is **untracked**
(`git status --porcelain` shows `??`). The research-phase commit's staging scope covered the
report only. It must be staged in this task's own commit or it never lands.

One divergence from the task record, non-blocking: `state.json`'s `file_scope` for this task
anticipates `specs/decisions/external-worktree-harness-measurements.md` (plural), while the
record was written as `external-worktree-harness-behaviour.md`. `file_scope` is descriptive and
never filesystem-validated (`rules/state-management.md`), so this is a naming divergence, not a
defect; this plan declares the real paths.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set, so no roadmap
consultation was performed and no roadmap phases are added. The amending record's own "Roadmap"
note assigns its roadmap work to a `/roadmap` pass, not to this task.

## Goals & Non-Goals

**Goals**:
- Discharge the amending record's "Measured precondition" and R2 siting caveat against the
  measurement record, with a dated note that is a *discharge*, not an amendment.
- Make `specs/decisions/external-worktree-harness-behaviour.md` satisfy its own stated criterion
  on its face: each of the four results attributed to the exact command or tool call that
  produced it, and each result labelled agent-measured or user-supplied.
- State both residuals (non-`bypassPermissions` file-tool behaviour; the hook subprocess's raw
  OS `pwd`) in one named place in the record, with the reason the verdict does not turn on either.
- Get both decision records committed, the measurement record included.

**Non-Goals**:
- Re-taking any of the four measurements, or constructing a second scratch worktree.
- Measuring the non-`bypassPermissions` modes: that needs the user at the keyboard and is
  returned as a question, never guessed.
- Isolating the hook subprocess's raw OS `pwd`: doing so needs temporary diagnostic
  instrumentation in live personal settings, judged too invasive during research, and the verdict
  does not turn on it.
- Any edit under `agent-system/**`, any script change, any `deploy-headless.sh` redeploy.
- Any prose added to `skill-orchestrate/SKILL.md` or `commands/orchestrate.md` (both at byte
  ceilings).
- Folding measurement 3 into a two-root hook context file (the hooks successor owns that), or
  fixing `guard-destructive-git.sh`'s primary-tree anchoring (the hooks/cleanup successors own it).
- Exercising the harness's own per-agent worktree isolation option (the amending record's R5
  keeps it prohibited for this design).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A discharge note is mistaken for an amendment, implying the siting changed | H | M | Use a distinct `**Discharged by** <doc>, <date>:` marker; never `**Amended by**`. Phase 3 greps for a new `**Amended by**` occurrence as a negative check |
| Deleting the amending record's "if a measurement refutes the siting ... not worked around" sentence while discharging the precondition | H | M | Phase 1 keeps that sentence verbatim: discharge records that the measurement ran, it does not retire the standing rule for a future re-measurement |
| Adding the scratch fixture's absolute path or a literal branch name to a record, breaking the repo-agnostic constraint | M | M | Name fixture paths relative to the worktree root only. Phase 3 greps both files for absolute paths and this repository's own directory name |
| The measurement record is never committed (it is untracked today) | H | M | Phase 3 stages it explicitly by path and checks `git diff --staged --name-only` before committing |
| Guessing the unmeasured permission-mode behaviour to "finish" the record | H | L | Phase 2's conditional forbids it: record the user's answer if one exists, otherwise leave it open and re-relay the `user_decision` |
| Reconstructing a multi-line block of either record from string slices and silently duplicating a region | M | L | `Edit` with a unique `old_string` per site (`rules/bounded-block-edit` guidance); no whole-section rewrite |
| Line numbers cited here drift before implementation | L | M | Every edit site is located by section heading and sentence text at implementation time, never by the line number this plan happens to record |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 edit two different files with
no content dependency between them (Phase 1 cites the measurement record by path and by a verdict
Phase 2 does not change).

### Phase 1: Discharge the measured precondition in the amending record [COMPLETED]

**Goal**: `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` stops telling
successors the siting rests on unmeasured behaviour, and points at the measurement record
instead, without claiming anything was amended.

**Tasks**:
- [x] Locate both edit sites by text, not by line number: `grep -n "has not been measured"` and
      `grep -n "^## Measured precondition"` in the amending record; read the surrounding sections
      before editing. *(completed)*
- [x] Replace R2's closing sentence ("The siting rests on harness behaviour that has not been
      measured. See \"Measured precondition\".") with a sentence stating that the siting's
      precondition was measured live and is unrefuted, citing
      `specs/decisions/external-worktree-harness-behaviour.md`, and keeping the pointer to the
      "Measured precondition" section. *(completed)*
- [x] In "Measured precondition", immediately below the existing four-item list, add one dated
      note of the form `**Discharged by** external-worktree-harness-behaviour.md, <ISO date>:`
      stating that all four were measured live against a scratch repository and a real `git`
      worktree sited outside the repository and its parent, that none refutes the siting, and
      naming the two residuals (file-tool behaviour under a non-`bypassPermissions` mode, needing
      the user; the hook subprocess's raw OS `pwd`, deliberately not isolated) as residuals that
      do not bear on the siting. *(completed)*
- [x] Keep the section's existing conditional sentence ("**If a measurement refutes the siting,
      the siting ruling is amended by a dated note on this record. It is not worked around** in a
      script, by a symlink, or by moving the worktree inside the repository.") exactly as written.
      *(completed)*
- [x] Do not use the `**Amended by**` marker anywhere in this file: nothing was refuted, so the
      task description's amendment instruction (conditional on refutation) does not fire.
      *(completed)*
- [x] Make each change with `Edit` on a unique `old_string`; do not rewrite either section as a
      reconstructed block. *(completed)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: exactly two edit sites exist in this file — R2's closing sentence and the
"Measured precondition" section. Confirm at implementation time by grepping for
`has not been measured` and for `not been measured`/`unmeasured` across the whole file; if a third
site asserting the precondition is unmeasured exists, edit it too under the same marker and record
the deviation via `issue-record.sh`.

**Tier Justification**: `suite_selection_select` run at plan time over this phase's whole
`Files to modify` set returned `__FULL_SWEEP__` (every touched path unmapped), and the path lies
under `specs/**` and is not a report/plan/summary artifact, so the covering check is the `prose`
row's diff read-through — no suite covers this file and none is claimed.

**Files to modify**:
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` - R2's closing siting
  caveat replaced; one dated `**Discharged by**` note added under "Measured precondition"

**Verification**:
- `git diff -- specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` read through
  in full: every changed hunk is prose inside R2 or "Measured precondition", nothing else moved.
- `grep -n "has not been measured"` on the file returns nothing.
- `grep -c "Discharged by"` on the file returns 1; `git diff` shows no added `**Amended by**`
  occurrence.
- The "If a measurement refutes the siting ... not worked around" sentence is present and
  byte-identical in the diff's context, not in its removals.

---

### Phase 2: Close the measurement record against its own stated criterion [COMPLETED]

**Goal**: `specs/decisions/external-worktree-harness-behaviour.md` states, on its own face, the
exact command or tool call behind each of the four results, who measured each one, and both
residuals in one named place.

**Tasks**:
- [x] Add an appendix section listing, per measurement, the exact command or tool call that
      produced each result, taking the literal calls from the research report's Appendix: the
      `Read` calls on the worktree's `README.md` and its tracked `lua/existing.lua`; the `Write`
      of a new file under the worktree's `lua/` directory and the `Edit` on its tracked
      `lua/existing.lua`; the two same-session `Read` touches of the `lua/**/*.lua` glob in
      order (external first, in-project second, including the nonexistent in-project path);
      `cd <clean external worktree> && git reset --hard HEAD` as a single Bash call; and the
      three separate Bash calls `pwd`, `cd /tmp && pwd`, `pwd`, run both in the dispatch and in a
      freshly spawned context-free subagent. *(completed)*
- [x] Name every fixture path relative to the worktree root (or as `<external worktree>/...`),
      never as an absolute path and never naming a real repository — the repo-agnostic constraint
      applies to this deliverable. *(completed)*
- [x] Extend the record's "Attribution" section so each of the four measurements is labelled
      agent-measured or user-supplied explicitly. As of this plan all four are agent-measured and
      nothing is user-supplied; state that, rather than leaving it inferable. *(completed)*
- [x] Add a "Residuals" section collecting both residuals in one place: (i) file-tool behaviour
      for an external path under a non-`bypassPermissions` mode (`default`, `plan`,
      `acceptEdits`) — not observable from a dispatched agent, needs the user; (ii) the hook
      subprocess's own raw OS-level `pwd`, as distinct from `$CLAUDE_PROJECT_DIR` — deliberately
      not isolated, because doing so needed temporary diagnostic instrumentation in live personal
      settings. For each, state in one sentence why the verdict does not turn on it. *(completed)*
- [x] Conditional on the open question's state at implementation time: if the user has answered
      it, record the answer in "Residuals" labelled as user-supplied with its date; if not, leave
      it stated as open and re-relay it as a non-blocking `user_decision` in `.return-meta.json`.
      Never write a mode's behaviour that was not observed, and never infer it from the
      `bypassPermissions` result. *(completed: unanswered as of this dispatch; left open,
      re-relayed as non-blocking user_decision)*
- [x] Leave the "Verdict" and "Provenance" sections' substance unchanged: no result changed, so
      the verdict does not, and "Amends nothing" stays true. *(completed)*

**Timing**: 0.6 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` run at plan time over this phase's whole
`Files to modify` set returned `__FULL_SWEEP__` (the path is unmapped), and the path lies under
`specs/**` and is not a report/plan/summary artifact, so the covering check is the `prose` row's
diff read-through.

**Files to modify**:
- `specs/decisions/external-worktree-harness-behaviour.md` - per-measurement exact-call appendix
  added; "Attribution" extended to label each measurement's source; "Residuals" section added

**Verification**:
- `git diff -- specs/decisions/external-worktree-harness-behaviour.md` read through in full: all
  changed hunks are prose; no measured result's substance is altered.
- Each of the four measurements has at least one literal command or tool call attributed to it in
  the appendix; confirm by reading the appendix against the four measurement headings.
- `grep -nE "/home/|nvim|dotfiles"` on the file returns nothing (repo-agnostic constraint holds).
- `grep -n "Amended by"` on the file shows only the pre-existing Verdict sentence stating that no
  such note is appended — no new amendment marker.
- If the open question is still unanswered, `.return-meta.json` carries it as a non-blocking
  `user_decision`; if answered, "Residuals" names the answer as user-supplied with a date.

---

### Phase 3: Verify closure, confirm the refutation branch was not taken, and commit [COMPLETED]

**Goal**: both records are consistent, no constraint was breached, and both land in one commit —
including the measurement record, which is untracked today.

**Tasks**:
- [x] Negative check on the refutation branch: confirm the amending record carries no
      `**Amended by**` note attributable to this task, and the measurement record's Provenance
      still reads "Amends nothing". A refuting result was never found, so neither file may claim
      an amendment. *(completed: confirmed via grep -- only the pre-existing Verdict/Provenance
      sentences mention "Amended by"/"Amends nothing"; no new amendment note added)*
- [x] Confirm scope: `git status --short` lists only the two decision records and this task's own
      `specs/668_measure_harness_behaviour_for_external_worktree/**` artifacts. No
      `agent-system/**` path appears, so no source-store edit was made and
      `deploy-headless.sh` is neither required nor run. *(completed: both decision records had
      already landed in the Phase 1/2 commits by the time Phase 3 ran, so `git status --short`
      at Phase 3 start showed only this task's own `specs/668_*/**` artifacts -- confirming the
      same scope from the other direction)*
- [x] Confirm the byte-ceiling constraint: `git status --short` has no entry for
      `skill-orchestrate/SKILL.md` or `commands/orchestrate.md` under any root. *(completed)*
- [x] Confirm the repo-agnostic constraint across both edited files with one grep for absolute
      paths, this repository's own directory name, and any literal branch name. *(completed:
      `grep -nE "/home/benjamin|/home/|nvim|dotfiles"` over both files returned nothing)*
- [x] Scoped touched-path check: run
      `bash .claude/scripts/verify-touched.sh specs/decisions/external-worktree-harness-behaviour.md specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
      and record its verdict verbatim. The selector returns `__FULL_SWEEP__` for this set (every
      touched path unmapped — the normal result for `specs/**` prose); record the sentinel result
      honestly and claim no suite. *(deviation: altered -- this dispatch's own dispatch file
      (`.dispatch/3.md`, Batch Gate Deferral section) directs running `verify-touched.sh` with NO
      arguments, since it derives touched paths itself from the whole working tree plus the
      committed diff, rather than the plan's two-path invocation. Run as directed: 98 passed, 0
      failed; "36 suite(s) selected, 5 owed, 0 no-suite-by-class, across 16 touched path(s) --
      touched-path narrowed via verify-touched.sh, NOT a full-battery pass." The run took longer
      than the harness's 180s foreground-display threshold and was auto-backgrounded twice; both
      times resolved with a bounded `kill -0` wait on the real OS PID, never a retry.)*
- [x] Under `/orchestrate`, defer the complete gate set to the orchestration close rather than
      invoking it here, and record that deferral in this phase's own verification notes. On a
      standalone, non-orchestrated run with no orchestration close to defer to, run
      `bash .claude/scripts/verify-deploy.sh` directly instead. *(completed: this dispatch runs
      under `/orchestrate` (`orchestrator_mode: true`); the complete gate set is deferred to the
      orchestration close, per the dispatch file's Batch Gate Deferral section)*
- [x] Stage both decision records explicitly by path and commit via
      `.claude/scripts/git-commit-scoped.sh`. Targeted file-list staging only — no `git add -A`,
      no `git add .`, no directory or glob pathspec, no `git commit -am`. *(completed earlier:
      both records were staged and committed via `git-commit-phase.sh` at the close of Phase 1
      and Phase 2 respectively, each using targeted file-list staging derived from that phase's
      own `files_touched`; neither is re-staged here since both are already clean against HEAD)*
- [x] Record at least one `issue-record.sh` entry for this dispatch (`--kind issue` or
      `--kind win`); if genuinely nothing arose, attest that explicitly in the handoff summary
      rather than silently recording nothing. *(completed: one `--kind win` entry recorded)*

**Timing**: 0.4 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: exactly two non-artifact files land in this task's commit
(`specs/decisions/external-worktree-harness-behaviour.md` and
`specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`), alongside this task's own
`specs/668_*/**` artifacts. Confirm with `git status --short` before staging; if a third
non-artifact path appears, stop and report rather than widening the staging.

**Files to modify**:
- `specs/decisions/external-worktree-harness-behaviour.md` - staged and committed (untracked
  before this phase)
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` - staged and committed

**Verification**:
- `grep -n "Amended by"` across both files shows no note attributable to this task.
- `git status --short` before staging matches the Scope Hypothesis exactly.
- `verify-touched.sh` run over the two declared paths; its **exit status** checked (not only its
  stdout read) and its verdict (`__FULL_SWEEP__` for this set) recorded in the phase notes.
- The complete gate set's deferral to the orchestration close is recorded in the phase notes
  (orchestrated path), or `verify-deploy.sh` ran green (standalone path).
- `git diff --staged --name-only` lists exactly the intended paths before the commit; `git log -1
  --stat` afterwards shows the measurement record present in the commit.

## Testing & Validation

- [ ] The amending record no longer states the siting rests on unmeasured behaviour, and points
      at the measurement record by path.
- [ ] The amending record's standing "if a measurement refutes the siting" rule survives verbatim.
- [ ] Neither record carries an `**Amended by**` note added by this task.
- [ ] Each of the four measurements in the record is attributed to an exact command or tool call
      and labelled agent-measured or user-supplied.
- [ ] Both residuals are stated in one named section with the reason the verdict does not turn on
      either.
- [ ] No path outside `specs/**` is modified; no redeploy performed.
- [ ] Both decision records are tracked and committed.
- [ ] The open permission-mode question is either recorded as answered (user-supplied, dated) or
      re-relayed as a non-blocking `user_decision`.

## Artifacts & Outputs

- `specs/decisions/external-worktree-harness-behaviour.md` (updated; the task's deliverable)
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (precondition discharged)
- `specs/668_measure_harness_behaviour_for_external_worktree/summaries/01_*-summary.md`
- One commit carrying both records

## Rollback/Contingency

Every change is additive prose in two `specs/decisions/` markdown files; nothing executable
changes, so there is no build or runtime state to restore. If a change must be undone after it is
committed, revert the single commit; if before, discard the specific hunks by re-editing the
prose (never a destructive git operation on a dirty tree — `guard-destructive-git.sh` governs, and
a genuine rollback would need `git-snapshot.sh <task-number>` first).

If the user's answer to the open permission-mode question later contradicts the record's
`bypassPermissions`-only finding, that is a new measured result, not a rollback: it is recorded in
the record's "Residuals"/"Attribution" sections as user-supplied, and only if it refutes the
siting does the amending record's conditional fire and an `**Amended by**` note become due.
