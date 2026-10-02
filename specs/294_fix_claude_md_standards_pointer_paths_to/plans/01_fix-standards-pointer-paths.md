# Implementation Plan: Task #294

- **Task**: 294 - Fix CLAUDE.md standards pointer paths to the nonexistent extensions/nvim directory
- **Status**: [NOT STARTED]
- **Effort**: 0.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/294_fix_claude_md_standards_pointer_paths_to/reports/01_fix-standards-pointer-paths.md
- **Artifacts**: plans/01_fix-standards-pointer-paths.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Root `CLAUDE.md` points four `[Used by: ...]` standards references at
`.claude/extensions/nvim/context/project/neovim/standards/{documentation-policy,box-drawing-guide,emoji-policy,lua-assertion-patterns}.md`.
That directory tree does not exist — `.claude/extensions/nvim/` holds only `manifest.json` — while
all four real standards files exist flat at `.claude/context/project/neovim/standards/`. The fix is
a single-prefix substring substitution on four lines of one file, followed by a path-resolution
check and a repo-wide confirming grep. Definition of done: all four pointers resolve to existing
files, the dead prefix no longer appears in any deliverable file, and nothing else in `CLAUDE.md`
changed.

### Research Integration

Findings from `reports/01_fix-standards-pointer-paths.md` integrated into this plan:

- The four wrong-prefix lines are at `CLAUDE.md:34,37,40,63`; the filename segment and the rest of
  each sentence are already correct and must stay untouched. Only the directory prefix changes.
- The fix target is outside `.claude/**`, so `.claude/rules/source-store-deploy-boundary.md` does
  not apply. Re-confirmed during this planning pass: root `CLAUDE.md` is git-tracked and not
  gitignored, the nvim extension has no `merge-sources/` directory, and the only `claudemd.md`
  merge sources in the source store (`agent-system/extensions/{core,literature}/merge-sources/`)
  feed the generated `.claude/CLAUDE.md`, not root `CLAUDE.md`. Root `CLAUDE.md` is therefore
  hand-maintained and the correct, durable edit target.
- The report's "Historical Context" section is carried into Risks below: archived artifacts using
  a recycled task number contain an opposite-direction change to these same four lines. The live
  `.claude-extensions.json` `installed_files` manifest and the live filesystem are authoritative
  and both confirm the flat `.claude/context/...` form is correct today.
- No test suite exercises these strings; they are documentation pointers, not code-resolved paths.
  Verification is existence-checking and grepping, not a build.

### Prior Plan Reference

No prior plan for this task round. (An archived task reusing the number 294 has a plan that made
the opposite change; it is superseded, not a prior plan for this work — see Risks.)

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch, so no roadmap phases are added. For reference
only, `specs/ROADMAP.md:251` already characterizes this work as "a wrong-pointer fix, not a
missing-content one", which matches this plan's scope. This plan does not modify ROADMAP.md.

### Concurrency Note

Four sibling tasks (314, 315, 277, 309) are dispatched this same cycle on this shared working
tree. None of their declared `file_scope` entries include `CLAUDE.md`, so no overlap is expected.
Per `context/contracts/territory.md` (Cross-Task Territory): re-read `CLAUDE.md` immediately
before editing it, stage only `CLAUDE.md` by explicit path (never `git add -A`, never a directory
or glob pathspec), do not run `git-snapshot.sh` in its reverting default mode, and if a foreign
commit or foreign uncommitted modification to `CLAUDE.md` appears, stop and report rather than
proceeding.

## Goals & Non-Goals

**Goals**:
- Correct the directory prefix on all four standards pointers in root `CLAUDE.md` so each resolves
  to an existing file.
- Confirm by live check that all four corrected paths exist and the dead prefix is gone from
  `CLAUDE.md`.
- Confirm repo-wide that no other deliverable file carries the dead prefix.

**Non-Goals**:
- Editing, moving, or reviewing the content of the four standards files themselves — research
  confirmed they are correct and current.
- Changing `.claude/CLAUDE.md` (auto-generated) or anything under `.claude/**`.
- Changing the source store under `agent-system/` — root `CLAUDE.md` has no source-store origin.
- Retroactively correcting the dead prefix inside `specs/**` artifacts (review reports, archived
  vault plans, `state.json` descriptions). Those are historical records that correctly quote the
  defect; rewriting them would destroy the audit trail.
- Any deploy, sync, or regeneration run.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit touches lines or sections beyond the four pointers | M | L | Substitute only the exact dead-prefix substring; review `git diff` and confirm exactly 4 changed lines before committing |
| A future pass finds the archived recycled-number precedent (`specs/vault/01-vault/archive/294_fix_extension_dependent_refs/plans/02_extension-refs.md`) and reverts the fix | H | L | Risks and Research Integration above record that the live `installed_files` manifest and filesystem are ground truth; the archived precedent reflects a superseded deploy convention |
| A fifth occurrence exists elsewhere and is missed | L | L | Phase 2 runs a repo-wide confirming grep; this planning pass already ran it and found none outside `specs/**` and the vault |
| Implementer "fixes" the dead prefix inside `specs/**` historical artifacts too | M | L | Non-Goals explicitly excludes them; Phase 2's grep assertion is scoped to deliverable files only |
| Implementer adds a task-number reference to `CLAUDE.md` while editing | M | L | `CLAUDE.md` is outside `specs/**`; `.claude/rules/no-task-references-in-deliverables.md` forbids task-number citations there. The edit adds no prose at all — prefix substitution only |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Correct the four standards pointer prefixes in root CLAUDE.md [NOT STARTED]

**Goal**: All four `[Used by: ...]` standards pointers in root `CLAUDE.md` resolve to existing
files, with no other content changed.

**Tasks**:
- [ ] Re-read `CLAUDE.md` immediately before editing (sibling-concurrency precaution) and re-run
      `grep -n "extensions/nvim/context/project/neovim/standards" CLAUDE.md` to confirm the live
      occurrence set and line numbers
- [ ] Replace the substring `.claude/extensions/nvim/context/project/neovim/standards/` with
      `.claude/context/project/neovim/standards/` on each occurrence, leaving the filename segment
      and surrounding sentence untouched
- [ ] Confirm `grep -c "extensions/nvim/context/project/neovim/standards" CLAUDE.md` now returns 0
- [ ] Confirm each of the four corrected paths exists on disk
- [ ] Review `git diff -- CLAUDE.md` and confirm exactly 4 changed lines, each differing only by
      the removed `extensions/nvim/` segment
- [ ] Commit `CLAUDE.md` by explicit single-path staging

**Timing**: 0.15 hours

**Depends on**: none

**Verification Tier**: prose

Rationale for `prose`: the change is confined to markdown prose with zero compile, elaboration, or
runtime surface — there is no module to build, so `local` has no meaning here. The tier's named
blind spot is precisely "broken cross-references or links", which is the defect under repair, so
the diff read-through is paired with an explicit path-existence check on all four corrected paths;
Phase 2 then closes the repo-wide half of that blind spot. The final gate set still runs before the
phase closes, unchanged.

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly 4 occurrences, at `CLAUDE.md` lines 34, 37, 40,
and 63. Confirm at implementation time with
`grep -n "extensions/nvim/context/project/neovim/standards" CLAUDE.md` before editing: if the count
is not 4, or the line numbers have shifted (a sibling or an intervening commit may have moved
them), correct every occurrence the grep reports and record the actual count in the summary rather
than assuming the planned line numbers.

**Files to modify**:
- `CLAUDE.md` - replace the dead `.claude/extensions/nvim/context/project/neovim/standards/` prefix with `.claude/context/project/neovim/standards/` on the four standards pointer lines (Documentation Policy, Box Drawing, Character Encoding and Emoji Policy, Lua Testing Assertion Patterns)

**Verification**:
- `grep -c "extensions/nvim/context/project/neovim/standards" CLAUDE.md` returns 0
- `grep -n "\.claude/context/project/neovim/standards/" CLAUDE.md` returns 4 lines
- All four exist: `.claude/context/project/neovim/standards/{documentation-policy,box-drawing-guide,emoji-policy,lua-assertion-patterns}.md`
- `git diff --stat -- CLAUDE.md` shows 4 insertions, 4 deletions, in `CLAUDE.md` only

---

### Phase 2: Repo-wide confirming grep and close-out [NOT STARTED]

**Goal**: Establish that no deliverable file outside `specs/**` still carries the dead prefix, so
the task can close without a known residual occurrence.

**Tasks**:
- [ ] Run `grep -rn "extensions/nvim/context/project/neovim/standards" .` across the repository
- [ ] Classify every hit: expected and permitted are `specs/**` task artifacts, `specs/reviews/**`,
      `specs/ROADMAP.md`, `specs/TODO.md`, `specs/state.json`, and `specs/vault/**` archives — all
      historical records that correctly quote the defect and are excluded by Non-Goals
- [ ] Assert zero hits in any file outside `specs/**`
- [ ] If an unexpected out-of-scope hit appears, do not silently widen scope: record it in the
      summary as a follow-up finding and report it

**Timing**: 0.1 hours

**Depends on**: 1

**Verification Tier**: prose

Rationale for `prose`: read-only grep classification over prose files; no file is modified in this
phase, so there is no compile or behavior surface at all.

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts zero remaining occurrences outside `specs/**`. That count
was confirmed at planning time by the same repo-wide grep (hits found only in `CLAUDE.md` itself
plus `specs/**` artifacts and vault archives). Re-confirm it at implementation time rather than
inheriting it — a sibling task's edits this same cycle could in principle introduce a new
occurrence.

**Files to modify**:
- none planned (read-only verification phase)

**Verification**:
- Repo-wide grep output contains no path outside `specs/**`
- Every remaining hit is accounted for as a historical `specs/**` record

---

## Testing & Validation

- [ ] The dead prefix string appears nowhere in `CLAUDE.md`
- [ ] Each of the four corrected pointer paths resolves to an existing file on disk
- [ ] `git diff` for the task touches `CLAUDE.md` only, with exactly 4 modified lines
- [ ] No file under `.claude/**` and no file under `agent-system/**` was modified
- [ ] Repo-wide grep shows no dead-prefix occurrence outside `specs/**`
- [ ] No test suite run is required: these are documentation pointers, not code-resolved paths
      (confirmed by research)

## Artifacts & Outputs

- `CLAUDE.md` - four corrected standards pointer paths (the only file modified)
- `specs/294_fix_claude_md_standards_pointer_paths_to/summaries/01_fix-standards-pointer-paths-summary.md` - execution summary, recording the actual occurrence count found and corrected
- One commit scoped to `CLAUDE.md`

## Rollback/Contingency

The change is four single-line substitutions in one git-tracked file, committed on its own, so
rollback is a targeted revert of that commit (`git revert <sha>`) — no working-tree-discarding
operation and therefore no snapshot requirement. If the edit is still uncommitted and must be
undone, re-apply the prefix substitution in reverse on the four lines rather than running a
tree-discarding `git checkout`/`restore`, since sibling tasks are live in this same working tree
this cycle. Should a genuine whole-tree rollback ever become necessary, follow
`context/contracts/recovery.md`'s rollback rung for the correct invocation shape including its
out-of-scope override flag.
