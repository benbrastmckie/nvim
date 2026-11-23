# Implementation Plan: Task #541

- **Task**: 541 - Stop git-snapshot.sh's --no-revert artifacts from contaminating phase commits with OTHER tasks' files
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: `specs/535_phase_commit_drops_own_plan_artifact` (status `completed` in `specs/state.json` as read at plan time -- the shared-file dependency is already discharged, so this task is unblocked)
- **Research Inputs**: specs/541_snapshot_artifacts_contaminate_phase_commits/reports/01_snapshot-artifact-containment-fix.md
- **Artifacts**: plans/01_snapshot-artifact-containment-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two cooperating defects let a `--no-revert` snapshot's artifacts reach a phase commit: the
snapshot's untracked-file enumeration is repository-wide and unfiltered, and the phase-commit
wrapper stages the whole task directory as a single directory pathspec that no containment check
ever inspects. The fix closes both halves at their own sites, registers the
`untracked-backup-*/` artifact class in the canonical ephemeral-runtime-file library so every
consumer repository inherits the ignore pattern, and leaves `working-progress-*.patch` durable
and tracked-eligible by deliberate design. The deliverable that proves it is a pair of
regression cases demonstrated RED against the unmodified scripts before either fix lands.

### Premise Re-Validation

The dispatch's `## Premise Re-Validation` section flagged four description lines. Each was
checked against the research report and against live state; results stated explicitly, including
where the description is simply confirmed unchanged:

1. **The `b7bba072e` measured evidence (13 files, four unrelated tasks).** CONFIRMED unchanged.
   The research report re-derived it in the originating repository and found the file list and
   the source issue-log entry (`iss_1792263251358_jTp86B`, `class: tooling`, `severity: minor`,
   `resolution: null`) matching the description verbatim. Not re-derived again here, per the
   dispatch's own instruction.
2. **`git-commit-phase.sh`'s fixed `stage_paths` seed and its "never tested" header.** CONFIRMED
   LIVE at plan time: the seed reads
   `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")` with the header comment
   declaring it "always staged, never tested by the Containment Self-Check below". One addition
   the description does not mention: the seed is handed to `git-commit-scoped.sh`, which already
   performs a CONDITIONAL `:(exclude)` injection for a `specs/NNN_*/` directory pathspec from its
   own `candidate_excludes` list -- that list covers five loop-guard/lock names and covers
   NEITHER snapshot artifact. The mechanism to copy therefore already exists one layer down; the
   NON-GOALS bar editing it there, so this plan mirrors the idiom in the phase-commit wrapper's
   own seed instead.
3. **Question (2), where the artifacts belong.** MATERIALLY CHANGED relative to the description's
   framing, and this is the plan's most consequential live-state correction. This repository's
   own root `.gitignore` ALREADY carries `**/untracked-backup-*/`, added by the same work that
   introduced `--no-revert` mode, with a comment naming exactly the three effects the research
   independently re-derived. The originating repository carries no such pattern in either its
   root or its `specs/` ignore file. That asymmetry, not a difference in the scripts, is why the
   incident reproduced there and not here. Consequence: registering the class in
   `scripts/lib/runtime-file-patterns.sh` is a PROPAGATION fix -- it makes every consumer
   repository inherit what one repository had by hand -- not a new idea, and in this repository
   it is a no-op at runtime. `working-progress-*.patch` is confirmed NOT ignored anywhere
   (`git check-ignore` reports no match), so its sole defense really is the phase-commit
   exclusion, exactly as the dispatch anticipated.
4. **The acceptance criterion (extend both suites, demonstrate RED, redeploy, confirm
   `RESULT=landed_verify_clean`).** CONFIRMED actionable. Both suites exist in the source store
   and are extensible in place; `test-git-snapshot.sh`'s own header already establishes the
   demonstrated-RED-as-deliverable precedent this plan follows.

### Research Integration

The research report settles every question the dispatch posed, and this plan adopts its answers:
the `--no-revert` untracked enumeration is used by no other mode (default and `--branch` capture
untracked files through `git stash push -u` and never populate the backup directory), so
narrowing it costs those modes nothing; the two artifacts warrant different dispositions; and the
phase-commit exclusion is load-bearing for the patch and redundant-by-design for the backup
directory. The report's flag that `scripts/orchestrate-cycle-postflight.sh` builds a structurally
identical seed at its own site is adopted as a Non-Goal with a follow-up note, not silently
widened into this task's scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; no roadmap
consultation applies.

## Goals & Non-Goals

**Goals**:
- Narrow `git-snapshot.sh`'s `--no-revert` untracked-file enumeration to the dispatching task's
  declared `file_scope`, with the task's own directory always admitted and a loud, named
  narrowing fallback when `file_scope` cannot be resolved.
- Add conditional `:(exclude)` entries for both snapshot artifact names to
  `git-commit-phase.sh`'s own fixed `stage_paths` seed, mirroring the conditional-injection idiom
  already proven one layer down.
- Register `untracked-backup-*/` as a member of the canonical ephemeral-runtime-file class so
  every consumer repository inherits the ignore pattern from the library rather than by hand.
- Keep `working-progress-*.patch` durable, un-ignored, and tracked-eligible, as its own script's
  documented design states.
- Land a regression case in each suite that is demonstrated FAILING against the unmodified
  scripts and passing after the fix.

**Non-Goals**:
- No history rewrite to purge already-committed foreign copies.
- No change to `git-commit-scoped.sh`, its `candidate_excludes` list, or its exit-code contract.
- No change to the guard-hook marker protocol, single-shot marker consumption, or the
  stash-identity scheme.
- No change to the containment predicate's treatment of genuinely out-of-scope paths.
- No edit to `context/standards/git-staging-scope.md`: it is absent from the declared
  `file_scope`, and the record that shares these two files has just corrected a sentence there.
  Documentation of the new exclusion entries goes into the two standards files that ARE in scope.
- No edit to `scripts/orchestrate-cycle-postflight.sh`, despite its structurally identical seed.
  Recorded as a follow-up below.
- Removing the one still-tracked `working-progress-*.patch` file in the originating repository is
  optional cleanup and is not performed here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new case cannot be made to fail against the unmodified scripts, because this repository already ignores `untracked-backup-*/` | H | M | Every fixture is a fresh `mktemp -d` repository outside this working tree with its own `.gitignore`, so the parent repository's patterns never reach it. The Half 2 fixture deliberately does NOT seed the ephemeral ignore block, which is the condition under which the sweep reproduces. |
| An unconditional `:(exclude)` entry naming an already-ignored path makes `git add` abort the whole add | H | H | Copy the conditional-injection posture verbatim: inject an entry only for a path that exists on disk and that `git check-ignore -q` does NOT report as covered, with the same deliberate fall-through direction (only a definitive exit 0 skips injection). |
| `git check-ignore` is asked about a literal glob string rather than a real path and answers misleadingly | M | M | Expand each candidate glob against the task directory on disk first (nullglob), then probe each concrete hit. A glob with no on-disk hit needs no exclusion entry at all. |
| Registering a class member breaks the byte-pinned doc block, the consumer gitignore, or the index line counts | H | H | All three coupled surfaces are declared in the same phase that edits the library and regenerated there: the standards file's fenced block, `specs/.gitignore` via `init-specs.sh`, and `index-entries.json` via the line-count generator. |
| Narrowing the backup loses data a user wanted | M | L | `--no-revert` reverts nothing, so an un-copied untracked file remains exactly where it was. The deliberate whole-tree override flag continues to request the repository-wide backup. |
| The file_scope resolution needed by the new scoping lives inside a block that `--no-revert` currently skips entirely | M | H | Phase 2's first task is to lift the resolution into a form both branches can read, without changing the reverting modes' fail-closed refusal semantics. |

## Decisions

- **The `--no-revert` enumeration is narrowed, not left alone.** It is confirmed mode-specific:
  no other mode reads or populates the backup directory. Since this mode reverts nothing, a
  narrower backup loses no recovery value for the dispatching task, while a repository-wide one
  writes other tasks' files into a directory the commit wrapper stages wholesale.
- **The dispatching task's own directory is always admitted** into the narrowed enumeration,
  mirroring the own-task-directory widening already universal at the containment sites, so a
  task's own untracked work inside its own directory is still captured.
- **An unresolvable `file_scope` narrows to the task's own directory and says so loudly.** It
  does not silently fall back to repository-wide copying, and it does not refuse: `--no-revert`
  is the sanctioned non-destructive checkpoint and must stay available on a RED tree. This
  degrade-with-a-named-warning posture is deliberately weaker than the reverting modes'
  fail-closed refusal, because this mode destroys nothing.
- **The deliberate whole-tree override flag continues to mean whole-tree here too**: passing it
  restores the repository-wide backup, preserving one explicit escape hatch rather than removing
  the capability.
- **`untracked-backup-*/` joins the ephemeral runtime-file class; `working-progress-*.patch`
  does not.** The backup is a literal duplicate of files that are themselves untracked and are
  never deleted by this mode, so making the copy ephemeral costs no real data and buys structural
  protection: an ignored path swept up implicitly by a bare directory pathspec is silently
  skipped. The patch is the only record of the tracked-change diff a reverting mode discards, and
  its own script documents it as deliberately not ignored; converting it into timed-deletion
  scratch would trade a real recovery artifact for tidiness.
- **Therefore the phase-commit exclusion is load-bearing for the patch and redundant-by-design
  for the backup directory**, and both entries are added regardless -- matching this codebase's
  existing precedent of keeping a redundant check in place even once a stronger site subsumes it.
- **This repository's hand-added root ignore line is left untouched.** It is wider than the
  `specs/`-scoped managed block (it covers the whole tree), it is outside the declared edit
  surface, and a duplicate ignore pattern is harmless. Removing it would narrow protection here
  for no gain.
- **Follow-up, not scope creep**: the whole-task completion commit's seed in
  `scripts/orchestrate-cycle-postflight.sh` carries the same shape and is not edited here. Record
  it in the issue log as a follow-up during implementation so it is not lost; the two seeds are
  near-identical and porting the same entries is a small separate piece of work.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Demonstrated-RED regression cases in both suites [COMPLETED]

**Goal**: Land one new case in each suite that reproduces a half of the defect against the
unmodified scripts, and capture the observed failure as this phase's evidence.

**Tasks**:
- [x] Read `scripts/tests/test-git-snapshot.sh` in full, including its header's statement that a
      demonstrated RED is itself a phase deliverable, and its `make_scoped_repo` /
      `run_snapshot` / `common_test_pass` / `common_test_fail` helpers and `FIXTURE_NUM`
      convention. Extend; do not replace or renumber existing cases. *(completed)*
- [x] Add a case to `scripts/tests/test-git-snapshot.sh`: build a fresh fixture repository
      containing the fixture task's own directory plus a SECOND, foreign `specs/{NNN}_{slug}/`
      directory holding untracked files, with `specs/state.json` declaring a `file_scope` that
      covers the fixture task only. Run a `--no-revert` snapshot for the fixture task. Assert the
      resulting backup directory contains NO path belonging to the foreign directory, and that
      the fixture task's own in-scope untracked content IS present. *(completed)*
- [x] Read `scripts/tests/test-git-commit-phase.sh`'s `build_repo` / `write_progress` /
      `run_phase_commit` helpers and follow their fixture shape exactly. *(completed)*
- [x] Add a case to `scripts/tests/test-git-commit-phase.sh`: build a fixture repository whose
      task directory contains both a `working-progress-{ts}.patch` and an
      `untracked-backup-{ts}/` tree holding a foreign path, with the ephemeral ignore block
      deliberately NOT seeded into the fixture's `.gitignore`. Run the phase commit and assert
      neither artifact appears in the staged index or in the resulting commit's file list. *(completed)*
- [x] Run both suites and record the new cases' FAILING output verbatim in the phase's progress
      notes. A case that passes before the fix proves nothing and must be strengthened until it
      fails for the right reason. *(completed)*
- [x] Record a non-fatal issue-log entry noting the demonstrated-RED evidence, and a `win` entry
      if the existing fixture helpers covered the new cases without new scaffolding. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Both suites are extensible in place with their existing helpers and need no
new scaffolding, and the two new cases are purely additive to the existing case sets. Confirm at
implementation time by running each suite before and after the addition and comparing the total
case counts and the pre-existing cases' results, rather than assuming the counts observed at
plan time still hold.

**Tier Justification**: Both edits are confined to standalone test suites with no importer and no
exported interface, and are covered by running
`bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's whole
`Files to modify` set, which selects and runs every suite those paths map to.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` - new Half 1 scoping case with a foreign untracked task directory in its fixture
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - new Half 2 exclusion case asserting neither snapshot artifact is staged or committed

**Verification**:
- Each suite runs to completion and reports exactly the expected new failure, with every
  pre-existing case still passing.
- The captured failure output names the foreign path (Half 1) and the artifact paths (Half 2),
  so the RED is attributable to the defect rather than to a broken fixture.

---

### Phase 2: Scope the `--no-revert` untracked enumeration [COMPLETED]

**Goal**: Make the `--no-revert` backup copy only untracked files the dispatching task's declared
`file_scope` covers, with a named, non-silent fallback when that scope cannot be resolved.

**Tasks**:
- [x] Lift the `file_scope` resolution currently nested inside the reverting-modes-only guard
      into a form the `--no-revert` branch can also read. Leave the reverting modes' fail-closed
      refusal semantics exactly as they are -- this phase adds a second reader, it does not
      relax the first. *(completed)*
- [x] In the `--no-revert` branch, filter the enumerated untracked list through the canonical
      containment predicate already sourced into this script, admitting the dispatching task's
      own resolved directory unconditionally. *(completed)*
- [x] Implement the unresolvable-scope fallback: back up only untracked files inside the task's
      own directory, and print a named warning on stderr stating that the backup was narrowed
      and why. Never silent, never repository-wide by default. *(completed)*
- [x] Honor the deliberate whole-tree override flag by restoring the repository-wide enumeration
      when it is passed. *(completed)*
- [x] Update the script's own header so the mode description and the artifact contract match the
      new behavior. Use durable anchors only -- variable names, flag names, filenames -- with no
      record-number citation and no draft-history language. *(completed)*
- [x] Re-run the snapshot suite and confirm Phase 1's new case flips from RED to green with no
      other case regressing. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The change is confined to one script and needs no new predicate, because
the containment predicate is already sourced into it and the new filter is a second call site
rather than a new mechanism. Confirm at implementation time by grepping the script for its
existing source line and predicate call before writing the filter.

**Tier Justification**: The edit is confined to one script with no exported function and no other
file importing it, and is covered by
`bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/git-snapshot.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` - scope-filtered untracked enumeration in the non-reverting branch, named narrowing fallback, override-flag passthrough, header update

**Verification**:
- The snapshot suite's new case passes; every pre-existing case still passes.
- A manual fixture run with no declared `file_scope` prints the named narrowing warning and
  produces a backup containing only the task's own directory.
- A manual fixture run with the whole-tree override flag still produces the repository-wide
  backup.

---

### Phase 3: Exclude both snapshot artifacts from the phase-commit fixed scope [COMPLETED]

**Goal**: Stop the phase-commit wrapper's directory pathspec from reaching either snapshot
artifact, using the conditional-injection posture already proven one layer down.

**Tasks**:
- [x] Read the conditional `:(exclude)` injection block in `scripts/git-commit-scoped.sh` as
      reference, including its reasoning for why injection is conditional and its deliberate
      fall-through direction. Do not edit that file. *(completed)*
- [x] In `scripts/git-commit-phase.sh`'s fixed `stage_paths` construction, expand two candidate
      globs against the task directory on disk (`working-progress-*.patch` and
      `untracked-backup-*`). For each concrete hit, probe it with `git check-ignore -q` and add a
      `:(exclude)` entry only when the probe does NOT report it as already covered. Preserve the
      safe fall-through direction: only a definitive "already ignored" result skips injection. *(completed)*
- [x] Keep at least one positive entry in the resulting pathspec list, so the wrapper never hands
      down an exclude-only list. *(completed)*
- [x] Update the fixed-scope header comment to state that the seed now subtracts the two snapshot
      artifact classes, and that the subtraction is conditional and why. Durable anchors only. *(completed)*
- [x] Re-run the phase-commit suite and confirm Phase 1's new case flips from RED to green with
      no other case regressing. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The existing `candidate_excludes` list one layer down covers neither
snapshot artifact name, so this phase adds a genuinely new exclusion rather than duplicating an
existing one. Confirm at implementation time by grepping that list for both artifact names before
writing the new block.

**Tier Justification**: The edit is confined to one script's local pathspec construction, changes
no function signature and no caller contract, and is covered by
`bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/git-commit-phase.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - conditional `:(exclude)` injection for both snapshot artifact classes in the fixed stage_paths seed, plus the header note

**Verification**:
- The phase-commit suite's new case passes; every pre-existing case still passes.
- A fixture whose task directory holds an already-ignored backup directory commits successfully
  rather than aborting with an ignored-path error, proving the conditional guard works in the
  direction the hazard requires.

---

### Phase 4: Register the backup class and reconcile its coupled surfaces [COMPLETED]

**Goal**: Make `untracked-backup-*/` a first-class ephemeral runtime-file member so every
consumer repository inherits the ignore pattern from the library, and bring every surface that
derives from that library back into sync in this same phase.

**Tasks**:
- [x] Add the new member to every parallel array in
      `scripts/lib/runtime-file-patterns.sh` -- id, gitignore pattern, representative probe path,
      tracked-file regex, directory-class flag, and directory basename -- keeping all arrays in
      lockstep index order and appending at the end so no existing index shifts. The member is
      directory-class and is deliberately not dot-prefixed, unlike most existing members. *(completed)*
- [x] Reconcile the library header's membership count with the actual array length, and add the
      per-member rationale note in the same style the existing members use: this class is a
      duplicate of content that is itself untracked, so it is ephemeral by construction, and its
      originals are never deleted by the mode that writes it. *(completed)*
- [x] Update `context/standards/orchestrator-runtime-files.md`: add the Class Table row, and
      regenerate its Consumer Repo Setup fenced block so it stays byte-identical to the library's
      emitted block. That block is machine-pinned to the library; a hand edit that drifts from it
      fails the pin. *(completed)*
- [x] Update `context/patterns/checkpoint-before-overflow.md` so the checkpoint procedure states
      the two artifacts' dispositions: the backup directory is ephemeral class and reaped on the
      ordinary schedule, the patch is durable and stays under the task directory. Keep the
      existing handoff-line shape intact. *(completed)*
- [x] Regenerate this repository's `specs/.gitignore` managed block from the library via
      `bash .claude/scripts/init-specs.sh`, so the ignore-coverage check and the library agree
      here as well as in a fresh consumer repository. *(completed: ran the source-store copy of init-specs.sh directly -- it resolves its own lib and specs/.gitignore target relative to cwd/SCRIPT_DIR with no deploy-root-guard, so it read the freshly-edited lib rather than the stale deployed copy)*
- [x] Re-sync `index-entries.json`'s `line_count` for both edited markdown files via
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, and
      stage the regenerated file with this phase's own commit. *(completed)*
- [x] Run the runtime-file-tracking suite and the runtime-file-tracking lint, confirming the
      doc-sync pin holds and the new member's probe path is genuinely ignored. *(completed: the deploy-tree-preferring test-runtime-file-tracking.sh and check-runtime-file-tracking.sh ran clean against the still-stale deployed tree by design; the doc-sync byte-identity and the new member's ignore coverage were additionally confirmed directly against the source-store lib/doc/suite copies, and will be re-confirmed by the deploy-preferring suite itself once Phase 5 redeploys)*
- [x] Record the postflight-sibling follow-up in the issue log so the structurally identical seed
      in the whole-task completion commit is not forgotten. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The library's parallel arrays are the single definition point, so one
appended member propagates to the lint, the two deploy-harness fixtures, and the consumer
gitignore without any of them needing a hand edit; and the header's stated membership count is
stale relative to the actual array length. Confirm both at implementation time by counting the id
array directly and by grepping for every consumer that sources the library, rather than trusting
either figure as read at plan time.

**Tier Justification**: The library exports arrays consumed by several enumerable files outside
it -- the tracking lint, the specs initializer, and three deploy-harness fixtures -- so the
covering check must reach those dependents, which
`bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's full
`Files to modify` set does, while no single-file check would.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - new directory-class member across all parallel arrays, header count and rationale note
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Class Table row and the regenerated, byte-pinned Consumer Repo Setup block
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` - the two artifacts' dispositions stated in the checkpoint procedure
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` values for the two edited markdown files
- `specs/.gitignore` - managed block regenerated from the library so ignore coverage matches the new membership

**Verification**:
- The runtime-file-tracking suite passes, including the case asserting the standards file's
  fenced block is byte-identical to the library's emitted block.
- The runtime-file-tracking lint's ignore-coverage check passes with the new member's probe path
  reported as ignored.
- The line-count generator's check mode reports no remaining mismatch for either edited markdown
  file.

---

### Phase 5: Deploy, confirm acceptance, and close [NOT STARTED]

**Goal**: Regenerate the deployed tree, confirm the deploy lands clean, and demonstrate both
regression cases now pass against the fixed scripts.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm it reports
      `RESULT=landed_verify_clean`. A different result is a stop condition, not a note.
- [ ] Stage every derived file the deploy regenerated as part of this phase's commit, so no
      generated surface is left dirty behind the commit.
- [ ] Re-run both extended suites against the deployed copies and confirm the two new cases pass
      and no pre-existing case regressed.
- [ ] Re-read every file this task edited for deliverable hygiene: no record-number citations and
      no draft-history or supersession language anywhere outside `specs/**`.
- [ ] Record the final issue-log entries, including an explicit attestation if nothing further
      arose.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: The deploy regenerates the whole deployed tree plus the derived index
files, so the set of dirty paths after the deploy is wider than this task's own edits. Confirm at
implementation time by reading `git status --short` after the deploy and staging exactly what the
deploy produced, rather than assuming the edited set and the dirty set coincide.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script
- `agent-system/extensions/core/index-entries.json` - any further regenerated line-count values the deploy itself produces

**Verification**:
- `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- Both extended suites pass in full against the deployed copies.
- In-dispatch obligation under `/orchestrate`: run the scoped touched-path check
  `bash .claude/scripts/verify-touched.sh` over this task's touched paths and observe it green.
  The complete gate set is deferred to the orchestration close rather than invoked independently
  here; a standalone, non-orchestrated run of this phase instead runs
  `bash .claude/scripts/verify-deploy.sh` in full.

---

## Testing & Validation

- [ ] The new snapshot-suite case fails against the unmodified script and passes after Phase 2.
- [ ] The new phase-commit-suite case fails against the unmodified script and passes after
      Phase 3.
- [ ] Every pre-existing case in both suites still passes.
- [ ] The runtime-file-tracking suite's doc-sync pin case passes after Phase 4.
- [ ] The runtime-file-tracking lint's ignore-coverage and tracked-file checks pass.
- [ ] A fixture whose task directory holds an already-ignored backup directory commits without an
      ignored-path abort.
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- Updated `agent-system/extensions/core/scripts/git-snapshot.sh` with a scope-filtered
  non-reverting backup and a named narrowing fallback.
- Updated `agent-system/extensions/core/scripts/git-commit-phase.sh` with conditional exclusion
  entries for both snapshot artifact classes.
- Updated `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` registering the
  backup directory class.
- Updated `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` and
  `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md`.
- Two new regression cases, one in each of
  `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` and
  `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`.
- Regenerated `specs/.gitignore` managed block and `index-entries.json` line counts.
- Issue-log entries capturing the demonstrated RED, the postflight-sibling follow-up, and any
  deviation encountered.

## Rollback/Contingency

Each phase commits independently, so reverting is per-phase rather than wholesale. If Phase 2's
narrowing proves to lose something a real workflow depended on, revert that phase's commit alone:
Phase 3's exclusion and Phase 4's class registration each close the observed contamination on
their own and do not depend on it. If Phase 4's class registration turns out to break a consumer
repository's ignore posture, reverting that phase's commit restores the prior membership, and
this repository's own hand-added root pattern continues to cover the backup directory
independently. Should an intentional rollback of uncommitted work be required at any point, use
the snapshot-then-rollback recipe in `context/contracts/recovery.md`'s rollback rung, including
its out-of-scope override flag for the deliberate whole-tree case -- never a bare precautionary
snapshot as a routine phase opener.
