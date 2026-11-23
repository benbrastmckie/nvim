# Research Report: Task #673

**Task**: 673 - Land one reviewable commit per completed task on the integration branch and verify it before the status write
**Started**: 2026-11-23T10:58:02Z
**Completed**: 2026-11-23T11:20:00Z
**Effort**: one research dispatch; implementation estimated at 4 to 5 phases
**Dependencies**: 669 (completed). 670 and 671 are held and no longer block.
**Sources/Inputs**: - the amending decision record, read in full; the source store under `agent-system/extensions/core/`; this repository's commit history; scratch-repository fixtures under the session scratchpad. No web sources were needed.
**Artifacts**: - `specs/673_per_task_attribution_squash_landing/reports/01_isolation-off-landing-ruling.md` (this report)
  - `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (the ruling)
  - `specs/673_per_task_attribution_squash_landing/reports/01_fixtures/` (the three scripts behind every measurement below)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The contradiction is ruled: option B at landing time, with option C's squash handed to the
  review step under a stated interface. Option A is rejected.** The ruling is recorded in
  `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` and names the
  eight assertions of the amending record it amends.
- **Landing becomes a five-part verification (V1 to V5) plus a recorded proof.** Blob equality
  alone (V4) is trivially true in a single tree and would not close defect 4. The branch check,
  the non-empty attribution check and the nothing-left-in-the-working-tree check are what catch
  the single-tree shapes of that defect. All four negative fixtures were observed refusing.
- **Run against 14 completed tasks in live history, the predicate refused none** once the state
  territory is excluded from the path set. With the state files included it refused one correct
  landing.
- **Three facts about this repository's history change the design and were not in the task
  description**: task numbers are reused (an unbounded subject match attributed 22 commits to a
  task that made 9), 15% of recent commits belong to no task, and 31% of recent completions went
  through a path that bypasses the place the landing check is wired today.
- **One commit per task is still obtainable, on a review ref.** A blob overlay driven by the
  landing proof built it in a fixture with no working tree, index or `HEAD` involvement. A
  `merge-tree` replay of the same commits conflicted on the generated state file.
- **Defect 4 is live today in its single-tree shape**: postflight writes `completed`, then
  attempts the leftover commit, and treats that commit's failure as non-blocking. The plan must
  reorder those steps for V5 to be sound.

## Context & Scope

The task description requires the research round to rule between three options before anything
is built, because the amending record's landing mechanism reads a batch branch that does not
exist with isolation off, and isolation-off is now the only path. In scope: the ruling, the
verification predicate, the proof, the two-batch case, second-repository commits, retirement of
`milestone-ref-land.sh`, and the contract owed to the PR-submission task (685). Out of scope:
worktree isolation and the back-merge, both deferred.

Every experiment ran in a throwaway repository under the session scratchpad. Nothing in this
repository's refs, index or working tree was changed by them. The corpus measurements are
read-only `git log`, `git diff-tree` and `git rev-parse` over this repository.

What was not established is stated where it applies and collected under "Risks & Mitigations".

## Findings

### Codebase Patterns

**What exists today.**

- `scripts/milestone-ref-land.sh` snapshots `HEAD`'s whole tree onto `refs/heads/milestone/<id>`
  by `commit-tree` and compare-and-swap `update-ref`. Its `--verify` is full-tree equality
  between that ref and `HEAD`. It is a no-op for a task in no roadmap milestone batch, so for
  such a task there is no landing verification at all today.
- `scripts/orchestrate-cycle-postflight.sh` calls it at lines 1378 to 1380, before the status
  write, and gates the write and the commit message on `milestone_landing_refusal` at four
  further sites (1411, 1883, 2119, 2255) and in the verdict JSON (2617, 2641).
- `scripts/lib/batch-admission-lib.sh` (task 669) writes
  `specs/.orchestration/batch/{session_id}.json` with `integration_branch`,
  `integration_tip_at_cut`, `task_numbers` and an empty `landing_proofs` array whose element
  shape is explicitly left to the landing mechanism. The live record for this session has
  `integration_branch: "master"`, `integration_branch_declared: false`, zero proofs.
- `scripts/milestone-review-handoff.sh` computes its range as
  `<integration>..refs/heads/milestone/<id>` and requires the commit count to equal the done-task
  count. It is called from `orchestrate-conclusion-roadmap.sh` line 254.
- `integration_branch` and `worktree_isolation` are both undeclared in this repository.

**The completion write has more than one caller.** Found with
`grep -rn "skill_postflight_update\|postflight.*implement\|post-deploy reconcile"` over
`scripts/` and `scripts/lib/`, and cross-checked against commit subjects. The list is what
those two patterns returned and is not claimed complete:

| Caller | Runs the milestone landing check today |
|---|---|
| `orchestrate-cycle-postflight.sh` (cycle postflight) | yes |
| `lib/redeploy-checkpoint-lib.sh` (post-deploy reconcile, via `reconcile-task-status.sh`) | no |
| `reconcile-task-status.sh` (two promotion branches, lines 685 and 745) | no |
| `orchestrate-stage5-postflight.sh` line 161 | no |
| `command-gate-out.sh` | no |

All of them reach `update-task-status.sh postflight <N> implement`, which already hosts the
phase-count gate and the deploy gate (exit 6). In the last 700 commits, 53 completion commits
carry the plain subject and 24 carry `(post-deploy reconcile)`: 31% of completions bypassed the
only site where landing is checked.

**The live defect-4 shape.** In the cycle postflight the order is: landing check, status write,
then the per-cycle commit of leftover `modified_files` (line 2150). That commit's exit 1 is
"non-blocking", and exits 2 to 6 log "The work is on disk, UNCOMMITTED" and proceed. A task can
therefore be `completed` with reported work uncommitted. Line 2106 separately warns "no
modified_files reported ... source-file changes NOT committed automatically" and proceeds.

### Corpus measurements

Script: `reports/01_fixtures/corpus-predicate.sh`. Window: `HEAD~700..HEAD` on the checked-out
branch. For each task, the verification point is the parent of its first
`complete implementation` commit.

| Measurement | Result |
|---|---|
| Completed tasks evaluated | 14 (669, 484, 541, 535, 477, 567, 683, 682, 678, 677, 667, 668, 657, 654). 486 and 681 had no completion commit in the window and were skipped |
| V4 refusals, path set excluding generated state files | 0 of 14 |
| V4 refusals, full path set | 1 of 14 (567, two state files, interleaved with 477) |
| Commits in the window attributable to no task | 108 of 700 (65 free-form, 11 `roadmap:`, 7 `core:`, 6 `meta:`, 5 `todo:`, and smaller classes) |
| Merge commits in the window | 0 |
| Task numbers with more than one plain completion commit in all history | 438 |
| Attribution for 669: unbounded / bounded by the task's `created` time / the 700-commit window | 22 / 9 / 9 |
| Same for 477 | 20 / 13 / 13 |
| Tasks whose own paths were also touched by another writer between their first and end commit | 4 of 14 (669: 1 commit; 683: 9; 682: 5; 677: 6) |

The exclusion list used in the script is narrower than `BATCH_ADMISSION_STATE_TERRITORY` (it
names seven state paths instead of all of `specs/`). The ruling excludes the whole territory. A
zero-mismatch result over the larger path set implies zero over the smaller one, so the 0 of 14
carries over. The 4 of 14 is an upper bound under the ruling's exclusion; the shared paths
inspected for 683 were all outside `specs/` (an extension's `index-entries.json`, one domain
document, three scripts), so it is not expected to fall.

V5 cannot be evaluated against history, because past working-tree states are not recorded.

### Fixture measurements

Script: `reports/01_fixtures/options-abc.sh`, git 2.54.0.

**E1, option B.** Two tasks committing in interleaved order on one branch, with a state file in
every commit and one unattributed commit.

| Case | Result |
|---|---|
| Both tasks, clean | PASS, branch unchanged |
| A task's file edited and never committed | REFUSE V5, names the path |
| A reported new file never committed | REFUSE V5, names the path |
| A foreign commit overwrites task 1's file after its end commit | REFUSE V4 for task 1, names the commit; task 2 still PASSES |
| Commits made on a detached `HEAD` | REFUSE V1; after returning to the branch, REFUSE V2 (no attributed commit) |
| State file left in the path set | blobs differ between tip and task 2's end commit: a false refusal |

**E2, option A.** Phase commits written to `refs/batch/s1` through a temporary index.

| Observation | Result |
|---|---|
| Side ref history | three phase commits; integration branch did not move |
| `git status --porcelain` in the primary tree afterwards | ` M src/a.txt`, ` M src/b.txt` |
| `batch_admission_dirty_paths` (live library) | lists both paths |
| `git cherry-pick -n` of task 1's side commits in the primary tree | exit 128, "local changes ... would be overwritten"; tree unchanged |
| Landing by an ordinary scoped commit of the task's paths | works; blob equal to the side ref's end commit; the sibling's path stays dirty |

**E3, option C.** A review ref built from the interleaved integration history.

| Technique | Result |
|---|---|
| `git merge-tree --write-tree --merge-base=<c>^ <review tip> <c>` per commit | CONFLICT on the first task's second commit and on the second task's only commit, both on the state file |
| Same, two tasks editing distant lines of one file, no state file | ok, final tree equal |
| Same, two tasks editing the same line alternately | CONFLICT |
| Blob overlay from each task's path set and end commit, then one trailing remainder commit (`reports/01_fixtures/review-overlay.sh`) | one commit per task, one bookkeeping commit, final tree equal to the integration tip, `HEAD` and working tree untouched |

### External Resources

None consulted. Every primitive used (`commit-tree`, three-argument `update-ref`,
`merge-tree --write-tree --merge-base`, `update-index --cacheinfo`, a private `GIT_INDEX_FILE`)
was exercised directly in the fixtures.

## Decisions

- **Ruled B at landing, C at review, A rejected**, in
  `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`.
- **Attribution is bounded by the task's `created` timestamp**, not by
  `integration_tip_at_cut`: a resumed task has commits older than the current invocation's cut.
- **The path set excludes the state territory.**
- **Refusal on an unattributable commit is re-keyed to effect** (it changed one of the task's
  paths after the end commit), because unattributable commits are ordinary on an integration
  branch.
- **`modified_files` may only add a refusal** (V5's widening). It never establishes landing.
- **The amending record itself was not edited.** The new record lists what it amends; adding the
  dated `**Amended by**` notes to the amending record is left to the implementing plan's first
  phase, so that a research dispatch does not edit a second task's ruling.
- **No blocking user decision is raised.** One non-blocking decision is recorded in the return
  metadata: the integration branch's own history stays one commit per phase.

## Recommendations

1. **Phase 1, record.** Add dated `**Amended by**` notes to the amending record at R3-amended,
   "Isolation-off repositories" and "Built-mechanism verdicts", pointing at the new record. No
   code.
2. **Phase 2, the predicate as its own script** (`scripts/task-squash-land.sh` is the name in
   the declared `file_scope`; a name without "squash" would describe it better, and the plan
   should rule on that before the manifest entry is written). Modes: verify-and-record, and a
   read-only check. Exit codes distinct per refusal (V1, V2, V4, V5). Suite carries the four
   negative fixtures of E1, each observed failing first, plus the two-batch case (E1 NEG-b) and
   the idempotent re-run. Port `reports/01_fixtures/options-abc.sh`'s `verify` function; it is
   30 lines and already passes those cases.
3. **Phase 3, wiring.** Reorder the cycle postflight to: commit leftovers, verify, write status,
   completion commit. Keep the `milestone-ref-land.sh` calls alongside until phase 4. Put the
   phase list, the attributed commit list and any second-repository commits in the completion
   commit's body. Decide the choke-point question below before writing this phase.
4. **Phase 4, retirement.** Remove the two `milestone-ref-land.sh` calls; rename
   `milestone_landing_refusal` or keep it as the one refusal variable (it is read at six sites
   and emitted in the verdict JSON, so renaming touches a consumer contract); re-point
   `milestone-review-handoff.sh`; update the two context documents that describe the retired
   mechanism (`ref-plumbing-landing.md`, `git-workflow-narrative.md` lines 254 to 270,
   `conclusion-stage.md` lines 409 to 414). The last two documents belong to
   `branch_topology_documentation_parity` (675) by its description; the plan should leave them
   there unless a lint forces the edit earlier.
5. **Phase 5, redeploy and close.**

**The choke-point question, for the planner.** The criterion "a completion status write cannot
occur without the landing verification having passed" is not met by wiring the cycle postflight
alone. Either (a) host the predicate as a gate inside `update-task-status.sh postflight
implement`, beside the phase and deploy gates, which needs that file added to `file_scope` and
overlaps open tasks 438 and 598; or (b) wire each caller in the table above and prove the list
complete with two differently-shaped searches. (a) is the smaller and safer change.
[CORPUS-UNVERIFIED: the five completion-write callers found by one grep / whether a sixth caller
exists was not cross-checked with a second pattern]

**V5's false-refusal rate is unmeasured.** V5 will refuse a completion whenever a reported path
is dirty at verification time, including a `file_scope` excursion that the commit scripts
dropped on purpose. History shows that happening (`7a24cc678`, a hand commit landing a file
"dropped from phase 5's commit as out-of-scope"). Refusing there is the ruling's intent, but the
plan should make the refusal message name the remedy.
[CORPUS-UNVERIFIED: 14 completed tasks in HEAD~700..HEAD / V5 working-tree cleanliness at
verification time, which history does not record]

**Territory.** `orchestrate-cycle-postflight.sh` is also in the declared scope of eight open
tasks (639, 472, 501, 519, 551, 570, 609, 655). `milestone-review-handoff.sh` is also in 685's,
which depends on this task, so the order is already fixed.

## Risks & Mitigations

- **A single-tree V4 is weak by itself.** Mitigated by V1, V2 and V5, each with a negative
  fixture.
- **Subject-convention attribution trusts commit subjects.** A raw commit with a wrong task
  number is attributed to the wrong task. Unchanged from the amending record's defect 8; not
  closed here.
- **Clock dependence.** V2's lower bound compares commit dates with a `created` timestamp. A
  commit carrying an older author or committer date would be missed, and the task would refuse
  on V2 instead of passing silently, which is the safe direction.
- **`shared_paths` tasks do not separate cleanly at review time.** Stated as a limit of the
  interface; the review step must not present such a commit as one task's work alone.
- **The batch record is untracked and machine-local.** Proofs do not travel with a clone. The
  V2 fallback covers a missing proof.
- **Reordering the postflight commit ahead of the status write** changes which commit carries
  the `completed` state file. The completion commit still follows the status write, so the
  state change is still committed; the plan should confirm against the postflight suite.
- **Second-repository commits are recorded, not verified.**

## Context Extension Recommendations

none (meta task)

## Appendix

- Fixture scripts: `reports/01_fixtures/options-abc.sh` (arguments: a scratch directory and the
  path to `batch-admission-lib.sh`), `review-overlay.sh` (run after the first; argument: the
  same scratch directory), `corpus-predicate.sh` (arguments: task numbers; run from the
  repository root). The first two create and write only inside the scratch directory given.
- One gate collision during research: `guard-destructive-git.sh` refused the first fixture
  script because its text contained a HEAD-moving reset aimed at the scratch repository. The
  hook judges the command text from its own process directory, the behaviour the amending
  record's defect 1 already notes. The fixtures were rewritten without it. Recorded in the
  task's issue log, with one win entry for the corpus run.
- Searches: `grep -rln "milestone-ref-land"`, `grep -rn "milestone-review-handoff.sh"`, the
  completion-caller grep quoted above, and a grep for HEAD-relative dirt tests
  (`status --porcelain`, `diff --quiet`, `diff HEAD`, `diff --cached`, `diff-index`,
  `ls-files -m`) over `scripts/` and `hooks/`, which returned six non-test files.
