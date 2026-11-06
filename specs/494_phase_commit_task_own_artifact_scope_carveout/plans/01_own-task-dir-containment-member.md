# Implementation Plan: Exempt a task's own artifact directory from the phase-commit containment predicate

- **Task**: 494 - Exempt a task own artifact directory from the phase-commit containment predicate
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (this record is the predecessor; tasks 430 and 486 each depend on it)
- **Research Inputs**: specs/494_phase_commit_task_own_artifact_scope_carveout/reports/01_phase-commit-own-task-dir-carveout.md
- **Artifacts**: plans/01_own-task-dir-containment-member.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-staging-scope.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-phase.sh`'s Phase-Commit Containment Self-Check (site 2 of three Containment sites)
widens its `file_scope_arr` with the shared engine-written-state allowlist but never with the
dispatching task's own resolved artifact directory, unlike sites 1
(`orchestrate-cycle-postflight.sh` WORK (h)) and 3 (`git-commit-scoped.sh` V10), which both
already carry that member. The consequence is that a `files_touched` entry under the task's own
directory is staged unconditionally by the script's `stage_paths` seed and then removed again by
the self-check whenever the task's declared `file_scope` is non-empty and does not happen to name
that directory — silently dropping a task's own required artifact from its own phase commit. This
plan adds that one member as a per-site splice, pins the behavior with three new regression
fixtures, records the member and two prose corrections in `git-staging-scope.md`, and redeploys.
Done means: the new fixtures pass, the existing excursion and fail-open fixtures still pass
unmodified, the doc records the member, and the full gate set is green on a redeployed tree.

### Research Integration

The research report settles every open question the dispatch raised, and this plan implements its
Decisions 1-5 directly:

- **The asymmetry is confirmed in the source store.** `task_dir` is already a local variable at
  `git-commit-phase.sh:193` in exactly the relative-path form `file_scope_arr` entries use, so
  the fix needs no new sourcing, no helper call, and no archive-awareness concern. Re-derived at
  plan time: the `stage_paths` seed sits at line 201; the Containment Self-Check spans roughly
  lines 234-324, with the non-empty `file_scope_arr` guard opening around line 247 and the
  engine-written-state splice around lines 249-270.
- **The WHERE ruling is per-site splice, on documentary authority rather than preference.**
  `engine-written-state-paths-lib.sh`'s own header names "any task-owned `specs/{NNN}_*/` path"
  as an explicitly *rejected* candidate for that shared allowlist, because a per-task directory
  fails the library's "engine-written on behalf of every/many tasks" admission half. Sites 1 and
  3 both already implement this as a per-site splice for that same reason. No shared-library
  member and no shared-library signature change.
- **The `missing_key`-yet-dropped question is resolved and implies no second code change.**
  `orchestrator-postflight.sh` Stage 7 writes `file_scope` additively via `--file-scope-add`,
  sourced from a research report's `proposed_file_scope` or from `plan-file-scope-harvest.sh`'s
  harvested "Files to modify" union — both source-path-only by construction. A task genuinely
  carrying no `file_scope` at pre-dispatch review can therefore legitimately hold a real,
  non-empty, source-only `file_scope` by the time a later phase commit fires. The fail-open guard
  behaved exactly as designed; the two observations are correct descriptions of two different,
  legitimate moments in the task's lifecycle. The follow-on is "none" — only the recorded
  explanation, which Phase 3 lands in `git-staging-scope.md` so the answer outlives this record.
- **Two prose corrections belong in the same doc edit.** `git-staging-scope.md` currently asserts
  that site 3 "structurally subsumes site 2's own reach" and that site 2's self-check is
  "deliberately redundant, not load-bearing." Both claims hold for the *engine-written-state
  allowlist* gap (V10 does close that system-wide for every site-2 caller, since
  `git-commit-phase.sh` always forwards `--task`) but are false for the task-directory member
  specifically: site 2 removes an uncontained path from its own `stage_paths` pathspec *before*
  `git-commit-scoped.sh` is ever invoked, so V10 never sees — let alone restores — a path site 2
  already dropped. The live symptom's warning text is site 2's own wording, confirming the drop
  happened upstream of V10. Left un-narrowed, that prose invites a future reader to delete site 2
  as redundant and reintroduce this exact defect.
- **Fixture placement follows the file's established paired-fixture house style** (the existing
  Case 13 shape: a positive admission proven in the same run as a paired negative that still
  drops), as new cases numbered from 15.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:
- Add the dispatching task's own resolved artifact directory as an implicit, unconditional
  in-scope member of site 2's containment predicate, as a per-site splice inside the existing
  non-empty `file_scope_arr` guard.
- Pin the new behavior with an acceptance fixture (own-directory artifact lands, zero scope-
  excursion issue records), a paired negative fixture (a genuine out-of-territory source path is
  still dropped, still warned, still recorded), and a fail-open fixture proving the new splice
  sits inside the non-empty guard.
- Record site 2's new member in `git-staging-scope.md`'s "Three Containment sites, not one"
  section, with its relationship to sites 1 and 3 and to the `stage_paths` seed, plus the two
  prose corrections and the `missing_key` resolution.
- Redeploy the source store and leave the full gate set green.

**Non-Goals**:
- Any change to sites 1 or 3 — both already carry the member.
- Any change to the fail-open posture, or to making the check fatal.
- Any change to `engine-written-state-paths-lib.sh` (its header explicitly rejects this kind of
  member) or to its function signature.
- Any change to the `stage_paths` seed, which is already correct.
- Any change to `is_contained()`'s trailing-slash or deep-glob normalization.
- Any change to `orchestrator-postflight.sh` or `plan-file-scope-harvest.sh` — the
  `missing_key` question is fully explained by their existing, correct behavior.
- Migrating the hand-typed `stage_paths` shape in the per-extension implementation agents
  (already recorded in `git-staging-scope.md` as a separately-scoped follow-up).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new splice is placed outside the non-empty `file_scope_arr` guard, silently granting every task a scope member it never declared and contradicting the fail-open posture | H | M | Place the line inside the existing `if [ "${#file_scope_arr[@]}" -gt 0 ]; then` block, exactly where the engine-written-state splice already sits; pin the placement with Phase 2's fail-open fixture, which only passes if the guard is never entered |
| The member widens scope enough to mask a genuine excursion | H | L | The member is one directory prefix scoped to the committing task's own tree; Phase 2's paired-negative fixture proves a genuinely out-of-territory source path in the *same run* is still dropped, warned, and recorded |
| A malformed `task_dir` (empty `project_name`) composes a degenerate prefix | M | L | `task_dir` is built from `--task`/`--project`, both validated by the script's own `usage()` before argument parsing completes; an empty value is unreachable. No extra guard needed |
| A sibling task (430 or 486) edits the same three files concurrently | M | M | Both already carry a serializing dependency on this record; per the dispatch's territory block, re-read each file immediately before editing, stage only this task's own hunks, never a directory or glob `git add` |
| A future reader trusts the un-narrowed "site 3 subsumes site 2" / "deliberately redundant" prose and deletes site 2, reintroducing this defect | M | M | Phase 3's doc narrowing closes this directly, stating the pathspec-ordering reason the subsumption does not reach the task-directory member |
| The fix lands in the source store but the deployed `.claude/` tree is left stale, so nothing observable changes | M | M | Phase 4 runs `deploy-headless.sh` and then the full gate set against the redeployed tree |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Splice the own-task-directory member into site 2's containment predicate [COMPLETED]

**Goal**: `git-commit-phase.sh`'s Phase-Commit Containment Self-Check admits every path under the
committing task's own resolved artifact directory, without any change to the fail-open posture,
the staging seed, or `is_contained()`'s normalization.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-commit-phase.sh` immediately before
      editing (line numbers drift, and siblings 430/486 declare this same file). *(completed)*
- [x] Locate the non-empty `file_scope_arr` guard inside the Containment Self-Check (the
      `if [ "${#file_scope_arr[@]}" -gt 0 ]; then` block, around line 247) and the
      engine-written-state-paths splice immediately inside it. *(completed)*
- [x] Add one array member inside that guard, alongside (not inside) the engine-written-state
      widening: `file_scope_arr+=("${task_dir}/")`, using the already-local `task_dir` from
      around line 193. No new `source`, no helper call, no archive-aware lookup. *(completed)*
- [x] Add a comment above the new line stating: that this is the task's own resolved artifact
      directory; that it mirrors the per-site splices sites 1 and 3 already carry; that it is
      deliberately NOT a member of `engine-written-state-paths-lib.sh`, whose own header rejects
      any task-owned `specs/{NNN}_*/` path because a per-task directory is authored by one task's
      own dispatch rather than engine-written on behalf of every task; and that its placement
      inside this guard is what preserves the fail-open posture. Cite durable anchors (file and
      section names) only — no task numbers, no draft-history phrasing. *(completed)*
- [x] Confirm by inspection that the `stage_paths` seed (around line 201), the `is_contained()`
      trailing-slash and `/**` normalization, and the fail-open guard conditions are all
      byte-unchanged. *(completed)*
- [x] Run `bash -n` and `shellcheck` on the edited script. *(completed: both clean; shellcheck's two SC1091 info notes are pre-existing, confirmed byte-identical against HEAD)*
- [x] Run the existing suite to prove no regression:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh` *(completed: 2 passed, 0 failed)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts a single-file, roughly one-statement-plus-comment edit
confined to the non-empty `file_scope_arr` guard. Confirm at implementation time by reading the
final `git diff` for this file: it must touch only lines inside that guard block and add no new
`source` statement, no new function, and no change to `stage_paths`, `is_contained()`, or the
guard's own conditions. If the diff reaches beyond the guard, stop and re-derive before
committing.

**Tier Justification**: `local` is the cheapest covering tier because the edit is one array
append inside one shell script with no signature change and no new sourcing, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh`
is the suite pair `suite_selection_select` resolves for this exact path, covering both the
changed predicate and its downstream caller.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - add `file_scope_arr+=("${task_dir}/")` plus its explanatory comment inside the existing non-empty `file_scope_arr` guard

**Verification**:
- `bash -n` and `shellcheck` both clean on the edited script.
- `run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh` passes, with Cases 7,
  8, 10-14 all still passing unmodified.
- `git diff` for the file shows additions only inside the non-empty `file_scope_arr` guard.

---

### Phase 2: Pin the member with acceptance, paired-negative, and fail-open fixtures [COMPLETED]

**Goal**: three new regression cases in `test-git-commit-phase.sh` prove the own-directory
admission, prove a genuine excursion still drops in the same run, and prove the new splice never
runs outside the non-empty guard — all in the file's established house style.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` immediately
      before editing. Confirm the existing case numbering ends at Case 14, that `build_repo`'s
      declared `file_scope` is `["src/a.txt","src/b.txt","src/c.txt"]` (which already omits the
      probe task's own `specs/999_probe/` directory, so no fixture-scope change is needed), and
      that the file-wide `task-ref-ok:begin`/`:end` marker pair still encloses the case bodies —
      append the new cases INSIDE that pair. *(completed)*
- [x] Add **Case 15 (acceptance)**: a `files_touched` entry under the probe task's own directory
      (e.g. `specs/999_probe/reports/01_probe-report.md`, seeded and committed as a baseline,
      then modified) lands in the phase commit with exit 0, with NO
      `dropping out-of-scope path 'specs/999_probe/...'` warning, and with zero scope-excursion
      issue records — assert the absence by checking that no `scope excursion` row naming that
      path was written to the fixture repo's own issue log (locate the log the deployed
      `issue-record.sh` writes to inside the scratch repo; if the fixture repo has no such log
      at all after the run, that absence is itself the assertion). *(completed)*
- [x] Add **Case 16 (paired negative, Case 13's shape)**: in the SAME fixture run as an
      own-directory artifact path, a genuinely out-of-territory source path
      (`other/outside.txt`) is STILL dropped, STILL warned with the existing message text, STILL
      left modified/uncommitted on disk for manual review, and STILL recorded as a
      `scope excursion` issue — proving the admission is not a blanket pass. *(completed)*
- [x] Add **Case 17 (fail-open, Cases 8/14's shape)**: with the probe task's `state.json` entry
      carrying no `file_scope` at all, a `files_touched` path under the task's own directory
      commits with no drop warning and without the new splice ever running — proving the splice
      sits inside, not outside, the non-empty guard. Add the same assertion for an empty
      (`"file_scope": []`) and a malformed (non-array) `file_scope` value, so all three shapes of
      "missing" the dispatch names are pinned. *(completed)*
- [x] Prove the fixtures are genuinely red without the fix, WITHOUT leaving an uncommittable red
      state in the tree: copy the current `git-commit-phase.sh` to a scratch path, strip the new
      `file_scope_arr+=("${task_dir}/")` line from the copy with `sed`, point a one-off fixture
      run at that stripped copy, and confirm Case 15's own-directory path IS dropped there.
      Record the observed output in the phase's own notes. Delete the scratch copy afterwards.
      *(completed: red-proof confirmed Cases 15 and 16 genuinely FAIL against the stripped copy
      — see this phase's own progress-file note for the corrected effect: the report still lands
      in HEAD via the unconditional `stage_paths` directory seed even pre-fix, so the provable
      defect is a spurious drop warning plus a spurious scope-excursion issue-log entry, not an
      actual silent omission from the commit in this configuration. Case 17 passed unchanged in
      both configurations, confirming fail-open independence. Scratch copies deleted.)*
- [x] Run `bash -n` and `shellcheck` on the edited test file. *(completed: both clean; the two
      info-level notes are pre-existing and unchanged)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh`
      and confirm all cases 1-17 pass. *(completed: 32 assertions passed, 0 failed)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly three new numbered cases (15, 16, 17) appended
to one test file, with no edit to any existing case body and no change to `build_repo`,
`write_progress`, or `run_phase_commit`. Confirm at implementation time by reading the `git diff`
for the file: it must be append-only within the `task-ref-ok` marker pair apart from the Summary
block's position, and must leave every existing `common_test_pass`/`common_test_fail` string
byte-identical. If an existing case needs modifying to accommodate a new one, stop and re-derive.

**Tier Justification**: `local` is the cheapest covering tier because the edit is confined to one
test file with no externally visible signature, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh` is
the suite `suite_selection_select` resolves for this exact path, executing every assertion the
edit adds and every existing one it must not disturb.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - append Cases 15 (own-directory acceptance), 16 (paired negative: genuine excursion still drops/warns/records), and 17 (fail-open across missing, empty, and malformed `file_scope`)

**Verification**:
- `run-all.sh --only test-git-commit-phase.sh` passes with every case 1-17 green.
- The red-proof run against the splice-stripped scratch copy shows Case 15's own-directory path
  dropped, confirming the fixture actually exercises the new member.
- `bash -n` and `shellcheck` clean on the test file.
- `git diff` shows no modification to any existing case's assertions.

---

### Phase 3: Record site 2's member, the two prose corrections, and the `missing_key` resolution [NOT STARTED]

**Goal**: `git-staging-scope.md`'s "Three Containment sites, not one" section records site 2's
new member and its relationship to sites 1, 3, and the staging seed; narrows the two
now-overbroad claims about site 3 subsuming site 2; and records why a task reported as carrying
no `file_scope` can still see a drop at a later phase commit.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md`'s "Three
      Containment sites, not one" section (currently around lines 342-412) immediately before
      editing — siblings 430 and 486 declare this same file.
- [ ] Add a paragraph recording that all three sites now additionally admit the committing task's
      own resolved artifact directory as an implicit, unconditional in-scope member, implemented
      at each site as a per-site splice rather than a shared-library member, because
      `engine-written-state-paths-lib.sh`'s own header rejects any task-owned `specs/{NNN}_*/`
      path: a per-task directory is authored by one task's own dispatch rather than engine-written
      on behalf of every task, so it fails the library's admission bar. Name how each site obtains
      the directory (site 1 strips the project root off its absolute task dir; site 2 reuses the
      local `task_dir` it already builds; site 3 calls `task_lookup_dir()`).
- [ ] Narrow the existing "Site 3 therefore structurally subsumes site 2's own reach" paragraph
      and its "Site 2's self-check is consequently deliberately redundant, not load-bearing"
      sentence: state that both hold for the engine-written-state allowlist specifically, and do
      NOT hold for the task-directory member, because site 2 removes an uncontained path from its
      own `stage_paths` pathspec before `git-commit-scoped.sh` is ever invoked — V10 only tests
      paths it is actually handed, so it can neither see nor restore a path site 2 already
      dropped. Make explicit that site 2 is therefore load-bearing for this member, so a future
      reader does not delete the self-check as redundant.
- [ ] Record the staging-seed relationship explicitly: `git-commit-phase.sh`'s unconditional
      `stage_paths` seed already stages the whole task directory regardless of declared scope,
      while its containment self-check did not admit that directory — the parity between staging
      and containment that an earlier record assumed was true of the seed and false of the
      check. State the asymmetry as a durable fact about the two constructs, citing the script
      and the two construct names, never a task number or a draft-history framing.
- [ ] Record the `missing_key`-yet-dropped resolution: `orchestrator-postflight.sh`'s additive
      `--file-scope-add` write-back (fed by a research report's `proposed_file_scope` or
      `plan-file-scope-harvest.sh`'s harvested "Files to modify" union, both source-path-only by
      construction) can populate a previously-absent `file_scope` between a pre-dispatch review
      and a later phase commit. A pre-dispatch "no declared scope" observation and a later
      commit-time drop are therefore both correct readings at two different points in a task's
      lifecycle, not a fail-open defect. State that the fail-open posture is unchanged and
      deliberate.
- [ ] Verify the edit carries no task-number references and no record-versioning language
      (`.claude/rules/no-task-references-in-deliverables.md`,
      `.claude/rules/no-record-versioning-in-deliverables.md`): cite filenames, section headings,
      and construct names only.
- [ ] Run the doc/task-reference gate subset from the repository root (which is simultaneously
      the deploy consumer and the source store):
      `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
- [ ] Commit this green sub-step.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the edit is confined to one section of one markdown file
("Three Containment sites, not one" plus its immediately adjacent allowlist paragraph), adding
new prose and narrowing two existing sentences, with no other section touched. Confirm at
implementation time by reading the `git diff` for the file: every changed hunk must fall inside
that section's line range. If the narrowing requires editing a second section, state why in the
phase notes before committing.

**Tier Justification**: `local` is the cheapest covering tier because the edit is prose in one
markdown file with no executable surface, and `suite_selection_select` returns no
`test-git-commit-phase.sh`-equivalent suite that executes it; the honest covering check for a
source-store, non-`specs/**` markdown edit is the gate subset
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` (doc-lint plus
task-reference lint, with the repository root as `TARGET` since it holds both a deployed
`.claude/` tree and the `agent-system/extensions` source store), run together with the `local`
row's own lint/diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - record site 2's new own-task-directory member and the per-site-splice ruling; narrow the site-3-subsumes-site-2 and "deliberately redundant" claims to the engine-written-state allowlist; record the staging-seed-vs-containment asymmetry and the `missing_key`-yet-dropped resolution

**Verification**:
- `verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` passes, with neither gate reported
  as SKIP.
- Diff read-through confirms every changed hunk lies inside the "Three Containment sites, not
  one" section and its adjacent allowlist paragraph.
- `grep` over the diff finds no task-number reference and no record-versioning phrasing.

---

### Phase 4: Redeploy and close on the full gate set [NOT STARTED]

**Goal**: the source-store changes are regenerated into the deployed `.claude/` tree and the
complete gate set for the repository is green.

**Tasks**:
- [ ] Confirm Phases 1-3 are committed and the working tree holds no uncommitted source-store
      changes for this task's own files.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate the
      deployed `.claude/` tree from the source store.
- [ ] Confirm the deployed copies now carry the change:
      `grep -n 'task_dir' .claude/scripts/git-commit-phase.sh` shows the new splice, and
      `.claude/scripts/tests/test-git-commit-phase.sh` carries Cases 15-17.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`), with no `--skip-slow` and no
      `--only-gate` narrowing — including Gate 8's full shell-suite battery.
- [ ] Triage any failure: a failure in a file outside this task's own `file_scope` may be a
      concurrently-dispatched sibling's in-flight edit rather than a regression here — check
      `git log` and the territory block's sibling list before attributing it.
- [ ] Commit the redeploy.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the deploy touches only the deployed `.claude/` tree
plus whatever `deploy-headless.sh` regenerates, and that the three source-store files from
Phases 1-3 are the only source-store paths this task changed. Confirm at implementation time
with `git status --short` after the deploy: no unexpected source-store path should appear.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree, an implicit scope claim over that whole tree
- `.claude/scripts/git-commit-phase.sh` - regenerated from the source store
- `.claude/scripts/tests/test-git-commit-phase.sh` - regenerated from the source store
- `.claude/context/standards/git-staging-scope.md` - regenerated from the source store

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate it aggregates reported green,
  including Gate 8's full shell-suite battery (no `--skip-slow`, no `--only-gate`).
- The deployed `git-commit-phase.sh` and `test-git-commit-phase.sh` carry the Phase 1 and 2
  changes; the deployed `git-staging-scope.md` carries the Phase 3 changes.
- `git status --short` shows no unexpected source-store path changed by the deploy.

## Testing & Validation

- [ ] Acceptance: a task whose declared, non-empty `file_scope` omits its own artifact directory
      has a report written under that directory land in its phase commit, with zero
      scope-excursion issue records emitted for it (Case 15).
- [ ] Acceptance: in the same run, a genuinely out-of-territory source path is still dropped,
      still warned with the existing message text, still left uncommitted on disk, and still
      recorded as a scope excursion (Case 16).
- [ ] Acceptance: the fail-open posture holds for a missing, empty, and malformed `file_scope`
      (Case 17), and the pre-existing Cases 8 and 14 still pass unmodified.
- [ ] The existing excursion and normalization fixtures (Cases 7, 10, 11, 12, 13) pass
      unmodified — the trailing-slash and `/**` normalization and the engine-written-state
      allowlist are untouched.
- [ ] `run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh` passes.
- [ ] `verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` passes for the doc edit with
      neither gate SKIPped.
- [ ] `bash .claude/scripts/verify-deploy.sh` (full, unnarrowed) passes after the redeploy.
- [ ] The `missing_key`-yet-dropped answer is recorded in `git-staging-scope.md` (the durable
      home) in addition to the research report.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-phase.sh` — one spliced array member plus its
  explanatory comment.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — Cases 15, 16, 17.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — site 2's member, the
  per-site-splice ruling, the two narrowed claims, the staging-seed asymmetry, and the
  `missing_key` resolution.
- A regenerated deployed `.claude/` tree.
- `specs/494_phase_commit_task_own_artifact_scope_carveout/summaries/01_own-task-dir-containment-member-summary.md`
  at implementation completion.

## Rollback/Contingency

Each phase commits independently and green, so the cheapest contingency is a forward fix on the
single file that phase touched. If a genuine rollback of uncommitted work is required, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag — never a bare precautionary snapshot. Because
sibling tasks 430 and 486 declare these same three files and share this working tree, never run
`git-snapshot.sh` in its reverting default mode here; an ordinary defensive checkpoint uses
`--no-revert`.

Per-phase contingency:
- Phase 1: revert the one spliced line; the predicate returns to its current behavior with no
  other construct affected.
- Phase 2: the new cases are append-only, so removing them restores the suite exactly.
- Phase 3: the doc edit is prose-only and carries no executable consequence; reverting the
  section restores the prior text.
- Phase 4: re-running `deploy-headless.sh` after a source-store revert regenerates a deployed
  tree matching the reverted source. If the full gate fails on a file outside this task's
  `file_scope`, check `git log` for a sibling's in-flight commit before reverting anything here.
