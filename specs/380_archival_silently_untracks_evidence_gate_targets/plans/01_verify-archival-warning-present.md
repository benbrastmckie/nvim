# Implementation Plan: Task #380

- **Task**: 380 - Warn that archival un-tracks evidence-gate targets under the moved task directory
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/380_archival_silently_untracks_evidence_gate_targets/reports/01_warning-already-present.md
- **Artifacts**: plans/01_verify-archival-warning-present.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research established that the warning this task asks for is already present, committed, and
deployed at both named `mv` sites in the source store. This plan therefore executes a
verification-and-closure pass rather than an edit: confirm the warning text still stands at both
sites with zero working-tree drift, cite the commit that introduced it as the implementing
evidence, and close the task through the normal summary artifact. No file under
`agent-system/extensions/core/**` is modified, because a second warning beside an already-warned
`mv` would be a duplicate, not a fix.

### Research Integration

Key findings carried into this plan:

- `agent-system/extensions/core/context/patterns/task-abandon-mode.md` carries the warning at
  lines 69-72, directly under the archival `mv` block.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` carries the comment-form equivalent
  at line 550, immediately above its `mv "$source_dir" "$target_dir"` step.
- Both landed in commit `7ffb3916658d795d617905b5ff612a11bb541bd7` ("core: note that an archival
  mv un-tracks every file under the moved task directory"), filed incidentally under an
  unrelated task directory's accounting, which is why this task survived past its own fix.
- `git diff --stat` against both files is empty: nothing uncommitted, nothing pending.
- The deployed `.claude/` copies match the source store for these two files, so the dispatch's
  `core`-extension staleness flag does not bear on this task's closure.
- Both remedies the existing text names ("re-pointed, or the file promoted into
  `specs/evidence/`") satisfy the description's "re-point or force-track" instruction in
  substance.
- Adjacent `mv` sites were checked and correctly left unwarned: the vault-renumbering `mv`
  (tracked to tracked) and the archive-to-vault `mv` (re-tracking, not un-tracking). Neither is
  this task's hazard, and neither is in `file_scope`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Confirm, at implementation time rather than on the strength of this plan alone, that the
  archival-untracks warning is present at both source-store `mv` sites and that neither file has
  drifted since commit `7ffb39166`.
- Record the existing commit as the implementing evidence for this task, so a future reader can
  verify closure without re-deriving it.
- Close the task through the standard meta-task terminus with a summary artifact.

**Non-Goals**:
- Adding a second, duplicate warning beside either already-warned `mv`.
- Any edit to `agent-system/extensions/core/context/patterns/task-abandon-mode.md` or
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`.
- The repo-side tracked-ness check in the BimodalLogic consumer repo's
  `scripts/check-evidence-probes.sh` — explicitly out of scope, already filed in that repo.
- Warning the vault-renumbering or archive-to-vault `mv` sites.
- Redeploying `.claude/`: the two files in scope already match, and a redeploy driven by the
  extension-wide staleness flag is a separate concern from this task's closure.
- Auditing or repairing the accounting error that filed this fix under another task's directory.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A sibling dispatch edits one of the two files mid-cycle, dropping the warning before verification runs | M | L | Phase 1 re-reads both files immediately before attesting, and `git log -1` on each confirms the last touching commit; a foreign commit or modification is reported, not worked around |
| Closing with no new source-store commit reads as an unverified no-op to a future reader | M | M | The summary artifact cites the commit SHA, both file:line locations, and the empty `git diff --stat`, forming the evidence trail in place of a fresh edit |
| The warning text is present but materially weaker than the description asks (e.g. omits the re-point/force-track remedy) | M | L | Phase 1 reads the full warning text at both sites against the description's acceptance wording, not merely greps for its presence; a genuine shortfall converts this into an edit phase and is reported rather than silently accepted |
| A future unrelated refactor silently drops the warning | L | M | Out of scope here; noted for whoever next touches either file |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Verify Warning Presence and Close on Existing Evidence [NOT STARTED]

**Goal**: Attest that both source-store `mv` sites carry the archival-untracks warning with zero
drift since the commit that added it, and close the task on that evidence without editing any
source-store file.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/patterns/task-abandon-mode.md` around the
      "Move task directory to archive" step and read the full warning text that follows the `mv`
      block (expected around lines 69-72).
- [ ] Re-read `agent-system/extensions/core/skills/skill-todo/SKILL.md` around its "Move
      directory from specs/ to specs/archive/" step and read the full comment-form warning above
      the `mv "$source_dir" "$target_dir"` line (expected around line 550).
- [ ] Check each warning against the description's acceptance wording: it must state that the
      `mv` into gitignored `specs/archive/` un-tracks files under the moved directory, and must
      name a producer remedy (re-point the reference, or promote the file to a tracked path).
- [ ] Run `git diff --stat -- agent-system/extensions/core/context/patterns/task-abandon-mode.md agent-system/extensions/core/skills/skill-todo/SKILL.md`
      and confirm it is empty.
- [ ] Run `git log --oneline -1 --` on each of the two files and confirm the last touching commit
      is `7ffb39166`; if a different SHA appears, check whether it is a sibling's in-flight work
      before proceeding, and report rather than dismiss it.
- [ ] If either warning is absent or materially weaker than the acceptance wording, STOP and
      report: this phase then becomes an edit phase against the source store only (never
      `.claude/**`), scoped to the two `file_scope` files.
- [ ] Write the summary artifact to
      `specs/380_archival_silently_untracks_evidence_gate_targets/summaries/01_verify-archival-warning-present-summary.md`,
      citing commit `7ffb3916658d795d617905b5ff612a11bb541bd7`, both file:line locations, the
      verbatim warning text, and the empty `git diff --stat` as the evidence trail.
- [ ] Commit only this task's own artifact files, by explicit file list, never a directory or
      glob pathspec.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the warning is present at exactly two sites, at
`task-abandon-mode.md` lines 69-72 and `skill-todo/SKILL.md` line 550, and that no source-store
file needs editing. Line numbers are a reading aid, not a fact — confirm by reading each file's
`mv` step and its surrounding text at implementation time, not by trusting the cited offsets, and
treat a shifted offset with the warning still present as confirmation, not a discrepancy.

**Files to modify**:
- None under `agent-system/extensions/core/**` — this is the planned outcome, not an omission.
- `specs/380_archival_silently_untracks_evidence_gate_targets/summaries/01_verify-archival-warning-present-summary.md` -
  new summary artifact recording the evidence trail.

**Verification**:
- Both warning texts read in full and judged against the description's acceptance wording.
- `git diff --stat` on both source-store files is empty.
- `git log --oneline -1` on both files reports the expected commit.
- Full gate set run and observed green: `bash .claude/scripts/verify-deploy.sh` (source-store
  path: `bash agent-system/extensions/core/scripts/verify-deploy.sh`), which is this plan's final
  phase and therefore runs the complete aggregated gate set rather than any `--only-gate` or
  `--only` subset.
- The summary artifact validates: `bash .claude/scripts/validate-artifact.sh specs/380_archival_silently_untracks_evidence_gate_targets/summaries/01_verify-archival-warning-present-summary.md summary`.

---

## Testing & Validation

- [ ] The warning at `task-abandon-mode.md`'s archival `mv` states the un-tracking consequence
      and names a producer remedy.
- [ ] The warning at `skill-todo/SKILL.md`'s archival `mv` states the same.
- [ ] No source-store file was modified by this task.
- [ ] `git diff --stat` on both `file_scope` files is empty at phase close.
- [ ] The full gate set (`verify-deploy.sh`) passes green.
- [ ] The summary artifact exists, validates, and cites the commit SHA plus both file locations.

## Artifacts & Outputs

- `specs/380_archival_silently_untracks_evidence_gate_targets/plans/01_verify-archival-warning-present.md` (this plan)
- `specs/380_archival_silently_untracks_evidence_gate_targets/summaries/01_verify-archival-warning-present-summary.md` (the closure evidence trail)
- No source-store or deployed-tree file changes.

## Rollback/Contingency

Nothing to roll back in the ordinary path: the phase modifies no source-store file, and its only
write is a new summary artifact under `specs/**`, removable without side effects.

If verification finds a warning absent or materially weaker than the acceptance wording, the
contingency is to convert Phase 1 into an edit phase: add the missing warning beside the
affected `mv` in the source store only (`agent-system/extensions/core/**`, never `.claude/**`,
per `rules/source-store-deploy-boundary.md`), keep the edit inside this task's declared
`file_scope`, and report the divergence from this plan's premise in the handoff.
