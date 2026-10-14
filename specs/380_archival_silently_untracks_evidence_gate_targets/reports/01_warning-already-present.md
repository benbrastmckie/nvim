# Research Report: Task #380

**Task**: 380 - Warn that archival un-tracks evidence-gate targets under the moved task directory
**Started**: 2026-10-14T15:00:00Z
**Completed**: 2026-10-14T15:20:00Z
**Effort**: trivial (verification only; no edit required)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/context/patterns/task-abandon-mode.md` (source-store edit target)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (source-store edit target)
- `.claude/context/patterns/task-abandon-mode.md`, `.claude/skills/skill-todo/SKILL.md` (deployed copies, checked for parity)
- `git log`/`git show` on both source-store files
- `specs/state.json` task-380 entry; `git status --porcelain` on both files
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The exact warning this dispatch asks for is **already present, committed, and deployed** at
  both named mv sites: `task-abandon-mode.md` and `skill-todo/SKILL.md`.
- It landed in commit `7ffb3916658d795d617905b5ff612a11bb541bd7` ("core: note that an archival mv
  un-tracks every file under the moved task directory"), authored 2026-10-10 — roughly 10 hours
  *after* task 380 was created (2026-10-09T21:48:49Z) — but filed under an unrelated task
  directory's `.return-meta.json` (`specs/296_repo_hygiene_remove_stale_initluabackup_/`), not
  under task 380's own artifacts.
- `git diff --stat` against both files is empty: nothing uncommitted, nothing pending.
- Both the source store (the declared edit target per `rules/source-store-deploy-boundary.md`)
  and the currently-deployed `.claude/` tree already carry identical wording — the deploy is not
  stale for these two files, despite this task's dispatch-level `<deploy-freshness-context>`
  flag on the `core` extension as a whole (that staleness, if real, affects some other file in
  the extension, not these two).
- No code change is needed for this task's scope. The remaining gap is purely bookkeeping:
  task 380 is still `researching` with no artifacts recorded, even though its deliverable already
  exists in the repository, authored under a different task's accounting.

## Context & Scope

Task 380's description asks for one thing, scoped narrowly and explicitly: add a warning beside
the archival `mv` in `agent-system/extensions/core/context/patterns/task-abandon-mode.md` (around
its original lines 58-65) and beside the matching `mv` in
`agent-system/extensions/core/skills/skill-todo/SKILL.md`'s "Move directory from specs/ to
specs/archive/" step, stating that `specs/archive/` being gitignored un-tracks anything under the
moved directory that an external gate or document references, so a producer knows to re-point or
force-track before archiving. The repo-side consumer check (BimodalLogic's own
`scripts/check-evidence-probes.sh`) is explicitly out of scope and already filed as its own task
there.

This research verified, read-only, whether that warning exists today in both named files, in both
the source store and the deployed tree, and whether it is committed (not merely staged or
working-tree-only).

## Findings

### Both target sites already carry the warning, verbatim-equivalent to the ask

- `agent-system/extensions/core/context/patterns/task-abandon-mode.md`, directly under the "Move
  task directory to archive" step's `mv` block and its padding note, reads:
  > "Because `specs/archive/` is gitignored, this `mv` removes every file under the directory from
  > version control (the files stay on disk locally and are absent from every fresh clone), so any
  > guard that cites a file by its task-directory path -- the evidence-probe gate's `WIRED_REPO`
  > form in `scripts/check-evidence-probes.sh` -- must be re-pointed, or the file promoted into
  > `specs/evidence/`, before the task is archived."
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`, as a comment immediately above its
  "Move directory from specs/ to specs/archive/" step's `mv "$source_dir" "$target_dir"` line,
  carries the same statement in comment form, ending "... must be re-pointed, or the file promoted
  into specs/evidence/, before the task is archived."
- Both remedies named ("re-point" and "promote the file into `specs/evidence/`") satisfy the
  description's "re-point or force-track" instruction in substance: promoting a file into a path
  outside the gitignore is the concrete form "force-track" takes in this codebase's existing
  `specs/evidence/` convention.

### The fix is committed, not a working-tree artifact

- `git log --oneline -1` on either file's most recent entry is
  `7ffb39166 core: note that an archival mv un-tracks every file under the moved task directory`.
- `git show --stat 7ffb39166` touches exactly these two files (plus `.return-meta.json`,
  `issues.jsonl`, `metrics.jsonl` under `specs/296_repo_hygiene_remove_stale_initluabackup_/` —
  an unrelated hygiene task's directory, evidence this fix was produced as an incidental
  by-product of that task's dispatch rather than task 380's own lifecycle).
- `git diff --stat -- <both files>` against the working tree is empty: no uncommitted changes
  exist to lose or reconcile.

### The deployed `.claude/` tree already matches

- `.claude/context/patterns/task-abandon-mode.md` and `.claude/skills/skill-todo/SKILL.md` both
  contain the identical warning text today. The dispatch's `<deploy-freshness-context>` block
  flags the `core` extension as stale relative to the source store in general, but that staleness
  — if it affects any file — does not affect either of these two; a redeploy is not required to
  close this specific task.

### No corresponding scope creep

- The skill-todo vault-renumbering `mv` (around original line 821, `specs/{old}_{name}` ->
  `specs/{new}_{name}`) and the archive-to-vault `mv` (around original line 685,
  `specs/archive` -> `${vault_path}/archive`) were checked and correctly left unwarned: the first
  renames within the tracked `specs/` tree (both endpoints tracked, nothing un-tracked), and the
  second moves content *out of* the gitignored archive into a tracked vault location (re-tracking,
  not un-tracking). Neither is the hazard this task targets, and task 380's own `file_scope`
  (`task-abandon-mode.md`, `skill-todo/SKILL.md`) does not reach either of them either.

## Decisions

- No edit is proposed to `agent-system/extensions/core/context/patterns/task-abandon-mode.md` or
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`: a second warning beside an
  already-warned `mv` would be a duplicate, not a fix, and the deliverable this task's
  `file_scope` names already exists, committed, in exactly the two files named.
- This report documents the existing commit as the evidence that satisfies the task's acceptance
  criteria, rather than fabricating new work to justify a plan/implement phase.

## Recommendations

1. **Close task 380 on the existing evidence rather than re-implementing.** The planning phase
   (or a direct status transition, if the orchestrator's own judgment permits skipping a
   do-nothing plan/implement cycle) should record commit `7ffb3916658d795d617905b5ff612a11bb541bd7`
   as the implementing artifact and move the task to its standard meta-task terminus
   (`[COMPLETED]`) rather than dispatching an implementation agent to re-author text that is
   already in place.
2. **If a plan phase is still dispatched**, it should be a single trivial phase: "verify the
   warning is present at both sites (it is); no file changes; cite the existing commit as
   evidence" — matching the git-workflow guidance that failed/empty work should not be committed,
   and that a no-op should not be disguised as a code change.
3. **Process note for the orchestrator/meta layer** (informational, not a new task): this defect
   was fixed as a side effect of an unrelated task's dispatch (296) without that dispatch
   recording task 380 as resolved, which is how task 380 was left open against already-satisfied
   work. No action is requested here beyond noting it as a contributing factor in why the task
   survived past its fix.

## Risks & Mitigations

- **Risk**: closing task 380 without any new commit might look like an unverified no-op to a
  future reader. **Mitigation**: this report cites the exact commit SHA, its diff, and confirms
  zero working-tree drift since, as the evidence trail.
- **Risk**: a future edit to either file could silently drop the warning during an unrelated
  refactor. **Mitigation**: out of scope for this task; no action proposed here.

## Context Extension Recommendations

None (meta task; no context documentation gap identified).

## Appendix

- `git log --oneline -5 -- agent-system/extensions/core/context/patterns/task-abandon-mode.md`
- `git log --oneline -5 -- agent-system/extensions/core/skills/skill-todo/SKILL.md`
- `git show --stat 7ffb39166`
- `git diff --stat -- agent-system/extensions/core/context/patterns/task-abandon-mode.md agent-system/extensions/core/skills/skill-todo/SKILL.md` (empty)
- `grep -n "un-tracks every file\|re-pointed" .claude/context/patterns/task-abandon-mode.md .claude/skills/skill-todo/SKILL.md` (both matched)
