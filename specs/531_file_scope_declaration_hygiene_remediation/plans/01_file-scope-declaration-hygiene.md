# Implementation Plan: Task #531

- **Task**: 531 - file_scope declaration hygiene remediation for the admission gate
- **Status**: [NOT STARTED]
- **Effort**: 3.0 hours
- **Dependencies**: None
- **Research Inputs**: specs/531_file_scope_declaration_hygiene_remediation/reports/01_file-scope-hygiene-remediation.md
- **Artifacts**: plans/01_file-scope-declaration-hygiene.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remediate the two live `file_scope` declaration-hygiene defects in `specs/state.json` so the
admission/overlap gate can see real collisions: narrow the two coarse whole-directory
declarations (projects 473 and 518) to the files they actually touch, and backfill the three
non-terminal tasks that declare no `file_scope` at all (567, 568, 607). Every write goes through
`scripts/state-write.sh`, the single mutex-guarded writer, and each phase re-derives its own file
list live before writing rather than trusting this plan's snapshot. A fourth, smaller piece of
work closes the dispatch's secondary scope item in the only honest way available: the script it
names as the place to add a one-line detector does not exist in this repository, so the two files
that cite it are corrected to describe the actual state instead.

### Research Integration

The research report's live re-derivation is the basis for every file list below, and this planning
pass re-ran each of its commands to confirm them (see Carried-Figure Re-Validation). Three
research findings shape the plan structure directly: (1) the defect set is two coarse entries plus
three absent ones, not the dispatch's snapshot of one Lean-subtree entry plus 28 absent ones;
(2) `scripts/check-evidence-probes.sh` does not exist anywhere in this repository's working tree
or git history, so the dispatch's "one-line `git ls-files --error-unmatch`" addition has no host;
(3) `file_scope` writes are task-management metadata, not deliverables, so the
source-store-deploy-boundary rule does not govern the `specs/state.json` edits — but it does
govern Phase 3's markdown edits, which must land in the source store, never in `.claude/**`.

Planning added one finding the report does not carry: `scripts/backfill-file-scope.sh` already
exists and already handles the automated half of defect (2). Its `--dry-run` run reports all three
remaining tasks as `SKIP -- no resolvable plan file (plan-less, left absent)`, and its header
records this as a deliberate design decision: it will not infer a `file_scope` from a task
description, because a wrong guess gives the collision guard false confidence. The three
backfills in Phase 2 are therefore hand declarations derived from each task's own explicitly
named edit targets and verified on disk — the creation-time declaration path, not an automated
inference — and Phase 2 must not be implemented by "just running the backfill script."

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

## Carried-Figure Re-Validation

The dispatch's Premise Re-Validation block flagged its own `## Description` for carried figures.
Each is checked here against live state, stated explicitly even where it only confirms the
description:

| Carried claim | Live result |
|---------------|-------------|
| "Task 177 declares `FormalSystem/Metalogic/Decidability/` as a WHOLE-DIRECTORY entry" | **FALSE here.** No project 177 exists in this repository's `state.json`; the path belongs to the BimodalLogic source repository this record migrated from. The live coarse entries are project 473 (`agent-system/extensions/core/docs/architecture/`, overlapping 11 non-terminal tasks) and project 518 (`agent-system/extensions/lean/agents/`, overlapping 5). |
| "28 of 52 non-terminal tasks declare NO `file_scope`" | **STALE.** Live: 3 missing-key, 0 literal-null, 0 empty-array, out of 137 non-terminal tasks (567, 568, 607). |
| "Check 8 (coarse whole-directory-root declarations) and Check 9 (duplicates)" enumerate both defects | **HALF-TRUE.** Check 8 is coarse declarations, as stated. Check 9 is duplicates, as stated — but Check 9 is already `[PASS]` and enumerates nothing. The absent-declaration defect is **Check 10** (missing / null / empty `file_scope`), not Check 9. |
| "the detector exists, the remediation does not" | **CONFIRMED** for defect (1). For defect (2) the picture is finer: `scripts/backfill-file-scope.sh` is a remediation tool that already exists and already ran to completion, and it declines these three tasks by design (see Research Integration above). |
| "`scripts/check-evidence-probes.sh:717-720`" | **FILE DOES NOT EXIST**, in the working tree or in any git history. The only two `WIRED_REPO` occurrences in the repository are the two prose/comment citations Phase 3 corrects. |
| `.claude/context/patterns/task-abandon-mode.md:58-65` | **NEAR MISS.** The `WIRED_REPO` citation is at line **71** of that file (the archive-`mv` note), not 58-65. |
| "Read the live validator output rather than trusting the counts above" | Followed: `bash .claude/scripts/validate-state.sh specs/state.json` was re-run during this planning pass, and every file list below was re-derived from live `grep`/scanner output. |

One further live fact bears on the acceptance bar: `validate-state.sh` exits **0** today — Checks
8, 9, 10 and 11 are WARN-only in base mode. `--strict` promotes them, but it also promotes two
**out-of-scope** Check 4 WARNs (`audit_override` and `audit_verdict` as unknown entry fields,
across ~110 tasks) and so cannot be this task's acceptance bar. The bar in Phase 4 is therefore
per-check cleanliness on Checks 8/9/10 in base mode, which this task can actually reach.

## Goals & Non-Goals

**Goals**:

- Project 473's single coarse `docs/architecture/` entry is replaced by the 5 files that carry the
  record-versioning occurrences the task exists to triage.
- Project 518's 16 coarse `<extension>/agents/` entries are replaced by the 40 extension-agent
  files that carry the targeted boilerplate paragraph; its 7 existing file-level entries are left
  untouched.
- Projects 567, 568 and 607 carry a concrete, on-disk-verified `file_scope` derived from the edit
  targets their own descriptions name.
- `validate-state.sh` Check 8 names no project, Check 9 stays `[PASS]`, and Check 10 reports
  `0 missing-key, 0 literal-null, 0 empty-array`.
- The two files citing a non-existent `scripts/check-evidence-probes.sh` describe the actual state
  of this repository instead.

**Non-Goals**:

- Building a `check-evidence-probes.sh` equivalent, or any mechanical `WIRED_REPO` detector. The
  dispatch describes this as a one-line addition to an existing script; no such script exists
  here, so the work is a materially different and larger piece than the dispatch scopes. Phase 3
  corrects the false citations; the "should a detector exist here at all" question is recorded as
  a follow-up recommendation, not executed.
- Doing any of 473's or 518's own substantive work (the record-versioning rewrite, the
  admission-contract prose). This task derives their `file_scope` only.
- Resolving the out-of-scope Check 4 `audit_override`/`audit_verdict` unknown-entry-field WARNs,
  or making any caller pass `--strict`.
- Regenerating the deployed `.claude/**` tree. Regeneration is manual-only; Phase 3 edits the
  source store and stops there.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrency drift: six sibling dispatches share this working tree and several declare `agent-system/extensions/core/` paths | M | H | Every phase re-derives its own file list live (re-run the named scanner/grep) immediately before writing, rather than copying this plan's snapshot. Re-read each file immediately before editing it. |
| `specs/state.json` is written by every sibling's own postflight, so a commit staging it may carry a sibling's legitimate status transition | M | H | Write via `state-write.sh` (mutex-guarded) and commit promptly after each write, keeping the window small. Review `git diff --staged` before committing and report — never revert — a foreign hunk. Never run `git-snapshot.sh` in its reverting default mode, and never `git checkout`/`git restore` `specs/state.json`. |
| A hand-derived backfill for a plan-less task is a prediction that could be wrong, which is exactly what `backfill-file-scope.sh` declines to risk | M | M | Declare only paths each description names **explicitly** and that exist on disk; never infer an adjacent file. `file_scope` is documented as descriptive/anticipated, and plan-time harvest is additive, so a later plan widens it without conflict. Record the derivation basis in the commit message. |
| 473's true file set could grow past 5 if a later edit introduces a new record-versioning occurrence under `docs/architecture/` | L | M | Acceptable: 473 is still `researched`, and its own plan-time harvest is additive. Narrowing from a whole directory to 5 files is strictly an improvement over the status quo in either direction. |
| 518's approach choice (A/B/C/D, undecided) could shrink its real file set | L | M | Acceptable and harmless: 40 file-level entries are strictly narrower than the 16 directory entries they replace, so over-declaration costs only extra serialization and can never hide a collision. |
| Narrowing 518's `lean/agents/` entry drops `lean-implementation-hard-agent.md`, which a sibling (515) also declares | L | M | Correct and intended: the live grep confirms that file does not carry the targeted boilerplate. The real overlap on `lean-implementation-agent.md` survives narrowing, which is the point. |
| `--strict` is mistaken for the acceptance bar and the task appears to fail on out-of-scope findings | M | M | Phase 4's criteria name per-check cleanliness in base mode explicitly, and the Non-Goals name the Check 4 WARNs as out of scope. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 are chained on
`specs/state.json` commit ordering, not on a logical data dependency: both write the same file,
and a clean one-commit-per-phase boundary requires the earlier write to be committed first.

---

### Phase 1: Narrow the two coarse `file_scope` declarations [NOT STARTED]

**Goal**: Projects 473 and 518 declare file-level scope only, and `validate-state.sh` Check 8
names no project.

**Tasks**:

- [ ] Re-derive 473's file list live: `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/docs/architecture/`, and collect the distinct files carrying findings. Expect 5. If the set differs from the five named below, use the live set and say so in the commit message.
- [ ] Re-derive 518's file list live: `grep -rl "BOTH required top-level fields" agent-system/extensions/*/agents/ | grep -v '^agent-system/extensions/core/' | sort`. Expect 40. If the count differs, use the live set and say so in the commit message.
- [ ] Re-read project 473's current entry (`jq '.active_projects[] | select(.project_number==473) | .file_scope' specs/state.json`) to confirm it still holds exactly the one directory entry.
- [ ] Replace 473's `file_scope` with the 5 live-derived files via a single `state-write.sh` call, passing the array as `--argjson` and scoping the filter to `project_number == 473`: `bash .claude/scripts/state-write.sh '.active_projects |= map(if .project_number == 473 then .file_scope = $scope else . end)' --session-id "$SESSION_ID" --argjson scope "$SCOPE_JSON" --regen-todo`. Run it once with `--dry-run` first and read the proposed diff.
- [ ] Confirm Check 8 no longer names 473: `bash .claude/scripts/validate-state.sh specs/state.json 2>&1 | grep -E 'Coarse file_scope'`.
- [ ] Commit this sub-step: `bash .claude/scripts/git-commit-scoped.sh --message "task 531: narrow project 473 file_scope to measured files" --session "$SESSION_ID" --task 531 -- specs/state.json specs/TODO.md`, after reviewing `git diff --staged`.
- [ ] Re-read project 518's current entry and confirm it still holds 7 file entries plus 16 `<extension>/agents/` directory entries.
- [ ] Replace 518's `file_scope` with its 7 existing file entries plus the 40 live-derived files, via the same single-call `state-write.sh` shape scoped to `project_number == 518`. Preserve the 7 existing entries verbatim; do not re-derive or re-word them.
- [ ] Confirm Check 8 now names no project at all, and that Check 9 still reports `[PASS] No duplicate file_scope entries found`.
- [ ] Commit this sub-step: `task 531: narrow project 518 file_scope to measured files`, staging `specs/state.json specs/TODO.md`.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The only edited file is `specs/state.json` (plus its generated
`specs/TODO.md`) — data with no compile, elaboration, or executable surface — and the specific
covering check is `bash .claude/scripts/validate-state.sh specs/state.json`, which validates every
invariant this edit can break: Checks 8, 9, 10 and 11 on `file_scope` itself, plus the schema and
enum Checks 1-7 that catch a malformed write.

**Scope Hypothesis**: 473 narrows from 1 directory entry to exactly 5 files
(`batch-admit-schema.md`, `extension-system.md`, `handoff-schema.md`,
`orchestrate-cycle-postflight.md`, `orchestrate-state-machine.md` under
`agent-system/extensions/core/docs/architecture/`), and 518 narrows from 16 directory entries to
exactly 40 extension-agent files while keeping its 7 existing file entries — 47 entries total.
Both counts were measured live during this planning pass (0 BLOCKING / 43 ADVISORY across 5 files;
40 files from the boilerplate grep). Confirm each by re-running the two commands in the first two
tasks above before writing; if either count has moved, write the live set and record the delta in
the commit message rather than forcing the predicted count.

**Files to modify**:

- `specs/state.json` - replace project 473's and project 518's `file_scope` arrays with file-level entries
- `specs/TODO.md` - regenerated by `state-write.sh --regen-todo`

**Verification**:

- `bash .claude/scripts/validate-state.sh specs/state.json 2>&1 | grep -c 'Coarse file_scope declaration'` returns 0.
- `bash .claude/scripts/validate-state.sh specs/state.json 2>&1 | grep 'duplicate file_scope'` still shows `[PASS]`.
- `jq '.active_projects[] | select(.project_number==473) | .file_scope | length' specs/state.json` returns the live-derived count (5 as measured), and no entry ends in `/`.
- `jq '.active_projects[] | select(.project_number==518) | [.file_scope[] | select(endswith("/"))] | length' specs/state.json` returns 0.
- Two commits exist, one per sub-step, each staging only `specs/state.json` and `specs/TODO.md`.

---

### Phase 2: Backfill the three absent declarations and correct this task's own stale entry [NOT STARTED]

**Goal**: No non-terminal task declares an absent `file_scope`, and task 531's own declaration
names the files this plan actually edits.

**Tasks**:

- [ ] Re-confirm the absent set is still exactly {567, 568, 607}: `bash .claude/scripts/validate-state.sh specs/state.json 2>&1 | grep 'file_scope missing_key'`. If a task has appeared or disappeared, handle the live set and record the delta.
- [ ] Re-confirm each backfill path exists on disk with a `test -f` loop over the three lists below. Declare only paths that exist; drop and report any that do not rather than declaring a path that is not there.
- [ ] Backfill 567 with `scripts/git-commit-scoped.sh`, `scripts/tests/test-git-commit-scoped.sh`, `scripts/tests/test-git-commit-phase.sh` (all under `agent-system/extensions/core/`), via one `state-write.sh` call scoped to `project_number == 567`.
- [ ] Backfill 568 with `scripts/tests/test-orchestrate-cycle-postflight.sh`, `scripts/orchestrate-cycle-postflight.sh`, `scripts/orchestrator-postflight.sh`, `scripts/update-task-status.sh` (all under `agent-system/extensions/core/`), scoped to `project_number == 568`.
- [ ] Backfill 607 with `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `context/config/orchestrator-context-budget.json`, `scripts/gate-registry.data`, `scripts/verify-deploy.sh` (all under `agent-system/extensions/core/`), scoped to `project_number == 607`.
- [ ] Correct task 531's own stale `file_scope`: it currently declares `agent-system/extensions/core/scripts/validate-state.sh`, which this plan does not modify. Replace it with the four paths this plan actually edits (`specs/state.json`, `specs/TODO.md`, and Phase 3's two source-store markdown files). This is the same class of defect the task exists to fix, applied to itself.
- [ ] Confirm Check 10 now reports `0 missing-key, 0 literal-null, 0 empty-array` and that Check 8 still names no project.
- [ ] Commit: `task 531: backfill absent file_scope declarations (567, 568, 607)`, staging `specs/state.json specs/TODO.md`, after reviewing `git diff --staged`.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Identical edit class to Phase 1 — `specs/state.json` data only, no
executable surface — and the same specific covering check, `bash
.claude/scripts/validate-state.sh specs/state.json`, validates the invariant this phase targets
(Check 10's missing/null/empty count) along with the schema checks that catch a malformed write.

**Scope Hypothesis**: Exactly 3 tasks need backfilling (567, 568, 607), with 3, 4 and 5 paths
respectively, plus 1 self-correction (531), for 4 entries edited and 16 paths written. Measured
live during this planning pass: Check 10 reported `3 missing-key ... out of 137 non-terminal`, and
all 12 backfill paths were confirmed present with `test -f`. Deliberately EXCLUDED from this
phase: running `scripts/backfill-file-scope.sh` to do the work, because it reports all three as
plan-less and declines them by design. Confirm the absent set and each path's existence by
re-running the first two tasks above before writing.

**Files to modify**:

- `specs/state.json` - add `file_scope` to projects 567, 568, 607 and replace project 531's stale entry
- `specs/TODO.md` - regenerated by `state-write.sh --regen-todo`

**Verification**:

- `bash .claude/scripts/validate-state.sh specs/state.json 2>&1 | grep 'file_scope visibility'` reports `0 missing-key, 0 literal-null, 0 empty-array`.
- `bash .claude/scripts/validate-state.sh specs/state.json 2>&1 | grep -c 'file_scope missing_key'` returns 0.
- For each of 567, 568, 607: `jq '... | .file_scope | length'` returns the declared count, and every entry resolves to an existing file.
- `jq '.active_projects[] | select(.project_number==531) | .file_scope' specs/state.json` no longer contains `validate-state.sh`.
- One commit exists, staging only `specs/state.json` and `specs/TODO.md`.

---

### Phase 3: Correct the two citations to a non-existent evidence-probe script [NOT STARTED]

**Goal**: Neither citing file claims a mechanical `WIRED_REPO` detector exists in this repository,
while both still state the underlying hazard.

**Tasks**:

- [ ] Re-confirm the citation sites: `grep -rn "WIRED_REPO" agent-system/` must return exactly the two source-store occurrences (`context/patterns/task-abandon-mode.md` and `skills/skill-todo/SKILL.md` under `agent-system/extensions/core/`). If either has already been corrected by another task, skip it and say so in the commit message; if both are already corrected, close this phase as a no-op with that finding recorded.
- [ ] Re-confirm the script is still absent: `test -e .claude/scripts/check-evidence-probes.sh` fails, and `git log --all --oneline -- '**/check-evidence-probes.sh'` is empty. If it has since appeared, stop and report — the dispatch's original one-line-addition scope becomes live again and this phase's premise is void.
- [ ] Re-read `agent-system/extensions/core/context/patterns/task-abandon-mode.md` around the archive-`mv` note (line 71 as measured) and rewrite the clause so it states the real hazard — archiving into the gitignored `specs/archive/` removes every file under the directory from version control, so a guard or probe citing a file by its task-directory path breaks, and such a file must be promoted into `specs/evidence/` before archival — without asserting that any script enforces it. Note plainly that no mechanical detector exists in this repository and the discipline is manual.
- [ ] Re-read `agent-system/extensions/core/skills/skill-todo/SKILL.md` around line 488 and apply the same correction to the `#` comment there, keeping it a comment inside its fenced block.
- [ ] Read the resulting diff hunk by hunk and confirm every change lies inside markdown prose or a `#` comment, with no edit crossing into executable shell.
- [ ] Run the doc and task-reference lints over the source store: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.
- [ ] Commit: `task 531: correct citations to a non-existent evidence-probe script`, staging only the two source-store markdown files.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Every changed hunk lies in markdown prose or inside a `#` comment in a
fenced bash block, with zero executable surface; the one blind spot the `prose` row names for this
edit — broken cross-references — is covered specifically by `bash
/home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
/home/benjamin/.config/nvim`, whose `TARGET` is the repository root that holds both the deployed
`.claude/` tree and the `agent-system/extensions` source store, as gate 3 requires.

**Scope Hypothesis**: Exactly 2 files carry the citation, measured live during this planning pass
via `grep -rn "WIRED_REPO" agent-system/` (two hits, both in the source store; the two further
hits under `.claude/` are the deploy mirror and are not edited). Deliberately EXCLUDED from this
phase: creating `scripts/check-evidence-probes.sh`, adding any `git ls-files --error-unmatch`
check, and hand-editing the `.claude/**` mirror. Confirm both counts by re-running that grep
before editing.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/task-abandon-mode.md` - correct the archive-`mv` note's citation of a non-existent script; state the hazard and that the discipline is manual
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - apply the same correction to the matching `#` comment

**Verification**:

- `grep -rn "check-evidence-probes" agent-system/` returns no hits.
- `grep -rn "WIRED_REPO" agent-system/` either returns no hits, or returns only text that does not assert an existing detector.
- The archival hazard is still described in both files (a reader learns that archiving un-tracks the files and that promotion into `specs/evidence/` is the remedy).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` reports no blocking finding, and neither selected gate SKIPs.
- No file under `.claude/` was modified: `git status --short .claude/` shows nothing from this phase.

---

### Phase 4: Final verification and completion [NOT STARTED]

**Goal**: The full gate set passes, every acceptance criterion is confirmed against live output,
and the task closes with its deviations recorded.

**Tasks**:

- [ ] Run the full aggregator: `bash .claude/scripts/verify-deploy.sh`. Read every finding and attribute each one to this task or to pre-existing/sibling state before proceeding.
- [ ] Run the shell test suite: `bash .claude/scripts/tests/run-all.sh`.
- [ ] Run `bash .claude/scripts/validate-state.sh specs/state.json` and capture the Check 8, 9 and 10 lines verbatim as the acceptance evidence.
- [ ] Run `bash .claude/scripts/validate-artifact.sh specs/531_file_scope_declaration_hygiene_remediation/plans/01_file-scope-declaration-hygiene.md plan` to confirm this plan's own authoring shape.
- [ ] Re-run `bash .claude/scripts/backfill-file-scope.sh --dry-run` and confirm it now reports 0 plan-less tasks (or names only tasks created after this task began, which are out of scope).
- [ ] Record, in the task summary, the three premise corrections this task made to its own dispatch description (project 177 does not exist here; 3 absent not 28; the absent-declaration defect is Check 10, not Check 9), and the deliberate non-goal around the evidence-probe detector.
- [ ] Record the follow-up recommendation: resolve whether this repository should have a `WIRED_REPO`/evidence-probe detector at all, now that both citing files no longer claim one exists.
- [ ] Write the implementation summary and close the task.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:

- `specs/531_file_scope_declaration_hygiene_remediation/summaries/01_file-scope-declaration-hygiene-summary.md` - implementation summary

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates, not a `--only-gate` subset and not `--skip-slow`) reports no finding attributable to this task.
- `bash .claude/scripts/tests/run-all.sh` passes in full, with no `--only` narrowing.
- `bash .claude/scripts/validate-state.sh specs/state.json` shows: no `Coarse file_scope declaration` line; `[PASS] No duplicate file_scope entries found`; `file_scope visibility: 0 missing-key, 0 literal-null, 0 empty-array`; `[PASS] No glob-shaped file_scope entries found`.
- `bash .claude/scripts/validate-artifact.sh <this plan> plan` passes.
- The two out-of-scope Check 4 WARNs (`audit_override`, `audit_verdict`) are still present and are reported as out of scope, not treated as a failure of this task.

---

## Testing & Validation

- [ ] `bash .claude/scripts/validate-state.sh specs/state.json` — Check 8 names no project.
- [ ] Same run — Check 9 reports `[PASS]`.
- [ ] Same run — Check 10 reports `0 missing-key, 0 literal-null, 0 empty-array` out of the live non-terminal count.
- [ ] Same run — Check 11 still reports `[PASS] No glob-shaped file_scope entries found`.
- [ ] Every `file_scope` entry written by this task resolves to a file that exists on disk.
- [ ] No `file_scope` entry written by this task ends in `/`.
- [ ] `grep -rn "check-evidence-probes" agent-system/` returns no hits.
- [ ] `bash .claude/scripts/tests/run-all.sh` passes in full.
- [ ] `bash .claude/scripts/verify-deploy.sh` reports no finding attributable to this task.
- [ ] No file under `.claude/` was hand-edited.

## Artifacts & Outputs

- Narrowed `file_scope` for projects 473 and 518 in `specs/state.json`.
- Backfilled `file_scope` for projects 567, 568 and 607, plus a corrected declaration for 531.
- Regenerated `specs/TODO.md`.
- Two corrected source-store markdown files (`task-abandon-mode.md`, `skill-todo/SKILL.md`).
- An implementation summary recording the premise corrections and the evidence-probe non-goal.
- A follow-up recommendation (not a created task): decide whether this repository should have a
  `WIRED_REPO`/evidence-probe detector, and build it or leave the manual discipline documented.

## Rollback/Contingency

Every change is a small, reversible edit inside this repository, committed per sub-step, so
rollback is per-commit rather than wholesale.

- **A `state.json` write lands wrong**: do not `git checkout` or `git restore` the file — siblings
  write it concurrently. Apply a corrective `state-write.sh` call that sets the intended value,
  and commit that as its own fix. `state-write.sh` is idempotent under a repeated identical write.
- **A write needs a true revert**: `git revert <sha>` the specific sub-step commit. If a reverting
  working-tree operation is genuinely required, take a snapshot first with
  `bash .claude/scripts/git-snapshot.sh 531` and only then run the destructive command.
- **A markdown correction is judged wrong**: revert that single commit; nothing else depends on it.
- **A foreign commit or foreign uncommitted modification is observed**: stop, confirm via
  `git log` that the work is not this task's own, and report it rather than proceeding or
  reverting it.
- **`scripts/check-evidence-probes.sh` turns out to exist after all**: Phase 3's premise is void.
  Stop that phase, leave both citations untouched, and report — the dispatch's original one-line
  detector addition becomes the correct scope instead.
