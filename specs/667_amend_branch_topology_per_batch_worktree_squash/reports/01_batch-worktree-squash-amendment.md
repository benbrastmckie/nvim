# Research Report: Task #667

**Task**: 667 - Amend branch-topology rulings R1-R3 and R5: per-batch worktree side branches with per-task squash landing onto the long-lived feature branch
**Started**: 2026-11-20T19:38:52Z
**Completed**: 2026-11-20T19:51:00Z
**Effort**: 1 research dispatch; the implementation it scopes is large (7 separable units, see Recommendations)
**Dependencies**: None declared on this task. Edges it should gain are ruled in Decisions.
**Sources/Inputs**: `specs/decisions/branch-topology-and-landing-strategy.md`, `specs/decisions/worktree-isolation-removal-verdict.md`, `specs/decisions/worktree-isolation-removal-reaffirmation.md`, `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md` (all four read in full), `specs/decisions/commit-layer-cluster-ordering.md` (Judgment calls, Edges, Inputs sections), the core extension source store (`agent-system/extensions/core/`), the live deployed `.claude/scripts/` tree run inside scratch fixtures, live refs of this repository, read-only inspection of one Lean consumer repository, git 2.54.0, Lake 5.0.0 (Lean 4.33.0-rc1). No web research was needed.
**Artifacts**:
- This report: `specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_batch-worktree-squash-amendment.md`
- Mechanical enumeration backing Element 3: `specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_two-root-consumers.tsv` (168 rows)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The amendment is sound and should be written, with three modifications to the proposed rulings.** The starting claim holds against the records: every recorded defect is a property of the per-dispatch layer and its `cp -al` clone, its ancestry-only landing verdict, or its unconditional status write. None is a property of `git worktree`. A batch-granularity worktree that clones nothing does not reproduce defects 1, 3 or 4 when landing verification and cleanup are built as ruled below. Defect 2 (wrong root) is not closed by design and is the bulk of the work, as the dispatch predicted.
- **Modification 1: the dispatch's premise that `specs/` is gitignored is false in this repository** and in the Lean consumer surveyed. `git check-ignore specs` matches nothing here; only `/.claude/` is ignored. A batch worktree therefore carries a HEAD-stale tracked copy of `specs/` (the derived hazard class the removal verdict records), and the symlink candidate cannot apply to a tracked directory. The design must hold for both postures.
- **Modification 2: reject the symlink candidate for both `specs/` and `.claude/`; use an explicit two-root contract instead.** Measured: a symlink is not matched by a directory-only ignore pattern (`/.claude/`, `/specs/`), so it shows as untracked and blocks `git worktree remove`; root resolution through it depends on logical-path `pwd` and flips to the primary tree for the six physical-path resolvers; hooks resolve through `$CLAUDE_PROJECT_DIR` regardless; and over a tracked `specs/` it produces spurious deletions. State stays in the primary tree, reached by absolute path; the code root is passed explicitly.
- **Modification 3: per-task landing must use attribution (`git cherry-pick -n` of the task's own commits), not `git merge --squash` of an end commit.** Measured in a fixture with two interleaved tasks: `merge --squash` of task 1's end commit co-lands task 2's unfinished phase commit. Attribution landed exactly task 1's two files, the back-merge was clean, and task 2 landed separately afterward.
- **The surviving shape of the wrong-root defect was reproduced with the live deployed script.** `git-commit-scoped.sh` invoked by its primary-tree path against a file modified in the worktree exits 1 with "nothing to commit ... (non-blocking)": the modify-only case is still a silent false success. The new-file and absolute-path cases are now loud (exit 2 and 4).
- **D1, D2 and D4 are all reproduced**, in a scratch repository with the script's own primitives and against this repository's live `refs/heads/milestone/M1`. Ruling: `milestone-ref-land.sh` is retired as a landing mechanism, and its `--verify` must be repaired first as an independent, urgent fix, because it strands completed tasks at `[IMPLEMENTING]` today.
- **Lean repositories: Option L1 (per-repository opt-out), not L2.** The surveyed Lean repository carries a 16 GiB `.lake/` of which 6.4 GiB is project-local build output for 1,468 source files. The pinned Lake does ship a local artifact cache (`lake cache`), but its cache directory does not exist on this host, the project's trace files embed absolute build paths, and no hit-rate across differing tree paths has been measured. L2 cannot be shown sound from here, so it is not ruled in.
- **One non-blocking `user_decision` is raised**: whether task-bookkeeping commits under a tracked `specs/` may keep landing directly on the integration branch between the per-task squash commits. Recommended: yes.

## Context & Scope

The dispatch asks for a ruling first and an implementation second. This report supplies the evidence for the ruling (Element 1), reproduces or refutes each claimed defect, and scopes Elements 2 to 7. It does not write the amending record, edit any script, or change any task record; those belong to plan and implement.

Two things in the dispatch were treated as claims to verify rather than premises: the defect table, and the statement that `specs/` and `.claude/` are gitignored. The task description was amended after the dispatch file was written (D1 confirmed live elsewhere, plus a D1 impact paragraph); the amended text was re-read from `specs/state.json` and is what this report answers.

Experiments ran in scratch repositories under the session scratchpad. The real `git-commit-scoped.sh` was exercised by copying the deployed `.claude/scripts/` tree into a fixture. No other repository was mutated: the Lean repository was inspected read-only, so no worktree was added there and no build was run.

## Findings

### 1. The recorded defects, engaged one by one

Each row names the recorded mechanism, whether the starting claim is confirmed, and what the amended design must do. "Closed by construction" means no code has to be right for the defect to stay closed.

| # | Recorded defect | Recorded mechanism | Starting claim | Status under the amended design |
|---|---|---|---|---|
| 1 | Destructive release on `nothing_to_land` (456 Lean lines) | `land` derived its verdict from `merge-base --is-ancestor` alone, never inspected the working tree, and postflight folded `nothing_to_land` into the success branch and released | Confirmed: the mechanism is the verdict logic plus a forced release | Closed only if cleanup is conditional on a recorded landing proof and never forced. Measured: `git worktree remove` without `--force` exits 128 on a modified file and on an untracked file. Residual found: it does not refuse on ignored files (finding 6) |
| 2 | `git-commit-scoped.sh` worktree-blind root | `PROJECT_ROOT` from `BASH_SOURCE[0]`, pathspecs fall through WARN-and-drop, exit 0 | Confirmed, and partly repaired since: drops now exit 2, 4, 6 or 7 | Not closed by design. One silent shape survives (finding 3). Primary risk |
| 3 | `lake-build-guard.sh` false green | `cp -al` shared the five `build-guard.*` inodes; `finalize_record()` truncates in place | Confirmed: the state files live at `<lean root>/.lake/build-guard.*`, resolved from `--dir` or `$PWD` upward | Closed by construction if nothing is cloned or linked: a second tree has its own `.lake/` and its own five files. The symlink candidate would have been the only new shared-path route, and it is rejected. A new cost replaces it (finding 9) |
| 4 | Tasks marked `completed` with 18 and 10 commits stranded | Postflight wrote the status regardless of landing outcome; hypothesised root cause is `modified_files` empty because edits were outside the main tree | Confirmed as recorded; the root-cause hypothesis remains unverified in the record | Closed only if landing and its verification run strictly before the status write and a failure refuses the write. The current code already has this ordering for the milestone ref; the verification predicate is what is broken (finding 2) |
| 5 | Repo-scanning pollution | Worktrees under the repository root were walked by generators that ignore `.gitignore` | Confirmed | Closed by siting the worktree outside the repository root entirely (finding 7) |

Three further hazards are recorded in the reaffirmation record and its report, and the dispatch's table omits them. The amending record should engage them by name:

- **HEAD-stale `specs/`** (removal verdict, "derived hazard class"; report question 11). It returns in full for a tracked-`specs/` repository. See finding 4.
- **Deferral invisibility** (report question 4): unlanded branch work is invisible to a sibling dispatched later against the shared tree. At batch granularity every task of the batch shares the one worktree, so intra-batch invisibility cannot occur. It persists between two concurrent batches until the first lands, which is ordinary branch semantics; `file_scope` admission across sessions is what keeps it from mattering.
- **Agent-tool isolation forwarding** (report question 6) and **raw `git` in the worktree** (task 119 never called the sanctioned commit script). Both recur. The amended R5 must keep the harness's own per-agent worktree option prohibited, and the dispatch row should carry only a code-root path so there is no isolation field to forward.

The **context-budget finding** also recurs, tighter than recorded: `skill-orchestrate/SKILL.md` measures 27,494 B against a 27,500 B ceiling (6 B of slack) and `commands/orchestrate.md` 21,496 B against 22,000 B. The design must add no prose to either file; everything goes in scripts and the dispatch composer.

### 2. D1 to D4 in the built mechanism

Reproduced with the script's own primitives (`commit-tree -p <parent>`, three-argument `update-ref`, the ancestry assertion) in a scratch repository, three landings in sequence:

| Landing | Ancestry verify (as built) | Tree equality |
|---|---|---|
| 1 | PASS | PASS |
| 2 | FAIL | PASS |
| 3 | FAIL | PASS |
| unlanded commit added after landing 3 (negative fixture) | n/a | FAIL, correctly |

- **D1 confirmed.** Only the first landing is parented on the work branch's `HEAD`; every later one is parented on the previous milestone tip, so the assertion is false permanently while the landed tree is correct. Live state agrees: `git merge-base --is-ancestor HEAD refs/heads/milestone/M1` exits 1 here, with `master` 11 commits past the ref and the ref 1 commit past `master`.
- **D2 confirmed.** The first landing's diff against its parent is empty in the fixture and on the live ref (`git diff --stat d3b552593 01bda07d9` prints nothing). The ref is the work branch's whole per-phase history plus one empty commit.
- **D3 confirmed.** `jq 'del(.extensions)' .claude-extensions.json` returns only `version`; no `integration_branch` key. Nothing in `orchestrate-cycle-plan.sh` reads one.
- **D4 confirmed.** After three landings the ref holds 3 commits the work branch lacks, with an identical tree; merging it back adds history and no content.
- **D1 impact confirmed by reading the call site.** `orchestrate-cycle-postflight.sh` lines 1378 to 1384 run land then `--verify`, set `milestone_landing_refusal`, and print "Re-run to retry the landing". A re-run lands again from the previous milestone tip, so it can never satisfy the ancestry check. The retry advice is unreachable.

Tree equality fails when it should: the negative fixture (a commit made after the last landing) is detected. A fixed check is therefore falsifiable.

### 3. The wrong-root defect, as it stands today

The live deployed `git-commit-scoped.sh` was run from a worktree's cwd by its primary-tree path, which is how a dispatched agent reaches it (agent cwd resets to the project directory between Bash calls, and `.claude/` is absent from a fresh worktree).

| Case | Pathspec | Result | Loud? |
|---|---|---|---|
| a | relative, file exists in both trees, modified only in the worktree | "nothing to commit ... (non-blocking)", exit 1 | **No. Silent false success** |
| a2 | relative, new file that exists only in the worktree | dropped as unmatched, exit 2 | Yes |
| a3 | absolute path into the worktree | dropped as out-of-repository, exit 2 | Yes |
| a4 | one existing plus one new | exit 4 | Yes |
| b | invoked through a `.claude` symlink in the worktree | commits in the worktree on the batch branch, exit 0 | Works, by logical-path accident |
| b2 | `specs/...` through a `specs` symlink | dropped as out-of-repository, exit 2 | Yes |

Case a is the recorded defect surviving in its most common form: an edit to an existing file. Every caller treats exit 1 as a benign no-op. The work stays uncommitted in the worktree, and under the old layer that is exactly what a release then destroyed.

A second wrong-root shape appeared by accident during the experiments: a shell sequence that changed directory into a worktree path that did not exist continued in the original directory, and its commits landed in the primary tree on the integration branch. Any `cd <worktree>; git ...` chain without fail-fast has this shape.

### 4. `specs/` is tracked here, and what follows

- This repository: `.gitignore` ignores `/.claude/` and a set of runtime files under `specs/`; `specs/` itself is tracked. The Lean consumer surveyed is the same (only `/.claude` matched).
- A fresh worktree of a tracked-`specs/` repository contains a full, HEAD-stale `specs/`, including a stale `state.json`. Any script or agent that reads `specs/` relative to the worktree reads stale state silently.
- Measured remedy: create the worktree with `--no-checkout`, then `git sparse-checkout set --no-cone '/*' '!/specs/'`. The worktree then has no `specs/` directory at all, status is clean, a commit and a back-merge that carries `specs/` changes from the integration branch both succeed. A stale read becomes a missing-file failure instead.
- A symlink placed over the sparse-excluded directory makes every tracked `specs/` file show as deleted. So in this posture state is reachable only by absolute path into the primary tree.
- Consequence for commits: state and artifact commits (`task N: complete research`, plan and phase-marker commits) must be made in the primary tree, on the integration branch, by the script invoked with the primary root. Code commits go to the batch branch. One phase can therefore produce two commits in two trees. This is the origin of the `user_decision` below.
- A side effect that helps: `commit-layer-cluster-ordering.md`'s Input 3 (the two generated state files ride in every task's commits, so per-task ranges are not separable by path) dissolves under this split, because those files never appear on the batch branch.
- Admission cannot require a fully clean primary tree in this posture. This session started with nine modified tracked files under `specs/` and one top-level declarations file. "Clean" has to mean no uncommitted change to tracked paths outside the state territory.

### 5. Symlink candidate: measured, rejected

| Check | Result |
|---|---|
| Ignore matching | `/.claude/` and `/specs/` do not match a symlink; both show as untracked. A slashless pattern in the shared `info/exclude` fixes status |
| `git worktree remove` | Refuses while the symlinks are untracked; with them excluded it removes the links and leaves the targets intact |
| Root resolution | `common_repo_root` uses logical `pwd`, so a script reached through the link resolves the worktree as its root. A physical-path resolver resolves the primary tree. Six core scripts use physical resolution, including `git-commit-scoped.sh` itself, `state-write.sh` and `central-log-lib.sh` |
| Hooks | The deployed settings file references `$CLAUDE_PROJECT_DIR` 27 times in its hook commands, so hooks resolve the primary tree whatever the worktree contains |
| Tracked `specs/` | Unusable (finding 4) |
| Shared-inode hazard | Not reintroduced for `.claude/` or `specs/`. It would be for a linked `.lake/`, which is why no build directory may ever be linked |

The link makes the root depend on how a script happened to be addressed. That is the recorded defect's own shape (correctness depending on a caller that does not know the mechanism exists), so it is rejected as the primary mechanism. Not measured: Claude Code path-glob rule matching and permission prompts for paths outside the project directory.

### 6. Landing, back-merge and cleanup: measured

Fixture: integration branch in the primary tree, one batch branch in an external worktree, two tasks with disjoint paths committing in interleaved order, an unrelated state commit and an unrelated dirty file in the primary tree.

- `git worktree add`: 0.009 s.
- **Snapshot landing is wrong for interleaved tasks.** The merged tree for task 1's end commit includes task 2's `b/f`.
- **Attribution landing is exact.** Selecting commits by subject (`^task N( phase P)?:`) between the merge base and the batch tip, then `git cherry-pick -n` and one commit in the primary tree, landed exactly task 1's two files. The unrelated dirty file in the primary tree was untouched.
- **Verification that can fail.** Blob equality over the task's own path set, between the new integration tip and the task's end commit, passed after landing and failed against the pre-landing commit. Full-tree equality is the wrong predicate once the integration branch carries anything else (a state commit, another batch's landing).
- **Back-merge is clean.** Merging the integration branch into the batch branch after a landing succeeded with no conflict (both sides carry identical changes), and task 2's later landing picked only its own commits when merge commits were excluded.
- **Whole-batch predicate.** `git merge-tree --write-tree <integration> <batch>` equal to the integration tree means nothing remains to land. It is also true for a branch that never changed anything, so it is a necessary check, never by itself a landing proof.
- **Cleanup.** `git branch -d` refuses a fully landed batch branch ("not fully merged"), as predicted. `git update-ref -d <ref> <proven tip>` is a compare-and-swap deletion: it refused a wrong old value and succeeded on the recorded tip, so a branch that advanced after its proof was recorded cannot be deleted by it.
- **Residual in removal.** `git worktree remove` does not refuse on ignored files. A report or build product written to an ignored path inside the worktree is deleted without complaint. Removal needs its own precondition: `git status --porcelain --ignored` in the worktree shows nothing outside a declared allowlist.

### 7. Where the worktree lives

Inside the repository root is the recorded pollution case, and the record shows `.gitignore` does not help tools that never read it. A sibling directory is seen by any scan rooted one level up. A directory under the git metadata directory relies on every walker skipping it, which is the same unaudited assumption. The only location no repository-rooted scan can reach is outside the repository and its parent: a per-user state directory keyed by a hash of the primary root and the session identity, never the system temp directory (a reboot would discard uncommitted worktree edits). The path is recorded in a batch record under the primary tree's state directory, so no script derives it.

### 8. Two-root enumeration (Element 3)

Search pattern: non-test `*.sh`, `*.py`, `*.lua` files in the eight loaded extensions (`core`, `lean`, `literature`, `sapience`, `email`, `nvim`, `nix`, `approvals`), excluding `deprecated/` and the vendored Python environment, matching any of: fixed-depth resolution from the script's own location, `rev-parse --show-toplevel`, `CLAUDE_PROJECT_DIR`, physical-path resolution, `REPO_ROOT`, a git write verb, a git read verb. The full table with per-file counts is `reports/01_two-root-consumers.tsv`.

| Extension | Files | Fixed-depth from script location | `show-toplevel` | Physical path | Git write | References `specs/` |
|---|---|---|---|---|---|---|
| core | 135 | 105 | 36 | 6 | 23 | 88 |
| literature | 13 | 8 | 5 | 0 | 0 | 13 |
| sapience | 9 | 6 | 8 | 0 | 2 | 1 |
| lean | 8 | 0 | 5 | 1 | 2 | 1 |
| approvals | 3 | 0 | 1 | 0 | 0 | 1 |
| email, nvim, nix | 0 | 0 | 0 | 0 | 0 | 0 |

168 files in total. 32 use both fixed-depth and `show-toplevel` resolution in one file, and 25 use neither (they take their path from elsewhere).

Cross-check with a differently shaped pattern (any mention of `git`, a `_ROOT` variable, or a parent-relative `_DIR`): 26 further non-vendored files, absent from the table. They are hooks and libraries that resolve no root of their own and take a path from the hook payload or a caller (for example `validate-no-task-references.sh`, `validate-meta-write.sh`, `validate-state-sync.sh`, `email/hooks/mail-guard.sh`). They still need classifying, because a payload path inside an external worktree is outside the project directory. So the audit surface is 194 files, plus 27 agent, skill and command documents that invoke `.claude/scripts/` by relative path (`git-commit-scoped.sh` 18 times, `state-write.sh` 29 times). This enumeration is of files matching the two patterns; per-file classification into code-root, state-root or both was done by hand only for the git-writing scripts below. [COVERAGE-UNVERIFIED: the two patterns above / a consumer that reaches a root only through a sourced library function with neither token in its own file would match neither, and `*.md` instruction files were counted by one pattern only]

How the three mechanisms behave under a batch worktree:

- **Fixed-depth from script location** (the dominant one): follows the path the script was invoked by. Invoked from the primary tree it yields the state root, always. Correct for state, wrong for code, and it does not know which it is being asked for.
- **`show-toplevel`**: follows the cwd. Yields the code root only if the caller changed directory first.
- **`$CLAUDE_PROJECT_DIR`**: the session's project directory, so the primary tree.

Git-writing scripts that must become two-root aware, by hand classification: `git-commit-scoped.sh` and `git-commit-phase.sh` (code pathspecs to the code root, `specs/` pathspecs to the state root), `git-snapshot.sh` (snapshots the tree that holds the task's edits), `verify-touched.sh`, `orchestrator-postflight.sh`, `milestone-ref-land.sh` (retired), `skill-base.sh`, `lake-build-guard.sh` (already resolves from `--dir`, needs the code root passed). `commit-source-store-path.sh` takes an explicit target root already and is the model for the rest. `task-lock.sh` and `state-write.sh` are state-root only and correct as they are.

One hook defect was observed directly rather than inferred. `guard-destructive-git.sh` decides whether a destructive command is safe from `git status --porcelain` in its own process directory, with no handling of `cd` or `git -C` in the command text. During this research it blocked commands aimed at a scratch repository because this repository's tree was dirty. The same logic in reverse allows a destructive command aimed at a dirty batch worktree whenever the primary tree is clean. Under the amended design that is a route back to defect 1 and must be closed in the audit.

### 9. Lean repositories (Element 6 and the scope of R5)

Measured, read-only, in one Lean consumer repository on Lean 4.33.0-rc1 / Lake 5.0.0:

| Item | Value |
|---|---|
| `.lake/` total | 16 GiB |
| `.lake/build` (project-local) | 6.4 GiB, 1,210 `.olean` files for 1,468 source files |
| Dependencies | Mathlib and seven others, about 9.6 GiB |
| Filesystem | `ext4`, 70 GiB free; no reflink |
| `lake cache` subcommand | Present (`get`, `put`, `add`, `stage`, `unstage`, `clean`) |
| Local cache directory (`LAKE_CACHE_DIR`) | Configured under the toolchain directory; **does not exist on disk** |
| Trace files | Embed absolute paths under the tree's own `.lake/build` |
| `specs/` | Tracked |

A fresh worktree would need the dependency tier fetched and unpacked again (about 9.6 GiB per batch on a disk with 70 GiB free) and the 1,468-file project tier rebuilt from nothing. That is the full cold build the user ruled out. No build was run to time it, because that would have meant adding a worktree to another repository; the sizes alone settle it.

Option L2 needs the pinned Lake's artifact cache to restore project-local outputs into a tree at a different path. The facility exists, but it has never been populated on this host, the traces are path-keyed for at least the link step, and whether a restore is a hit across paths is unmeasured. The binding rule from the records (never share a writable build directory between concurrent builders) rules out every shortcut that is not this cache. So L2 is a feasibility spike, not a design.

A further cost is specific to worktrees and independent of L1 or L2: `build-guard.lock` is per tree, so two batches building in two trees are no longer serialized against each other, where two sessions in one tree are today. The build-heavy co-scheduling rule covers one orchestration only.

Other Element 6 items:

- **`deploy-headless.sh` and the source store.** `.extensions.<name>.source_dir` is an absolute path into the primary tree. In a repository that owns its source store, a batch's source-store edits live in the worktree and are not what a redeploy reads until they land. Postflight already refuses completion on a pending deploy, so the order has to be land, redeploy, then verify. In a consumer repository the source store is a second repository with its own single tree; `commit-source-store-path.sh` commits there directly and those commits are outside the batch branch and outside the squash.
- **`lean-lsp` and Sapience registrations.** Both are keyed on the session's project path, which stays the primary tree. Sapience is unaffected. `lean-lsp` would serve the primary tree's files, not the worktree's, which is moot under L1.

### 10. Related task records

- `branch_aware_orchestration_and_squash_landing` (655): dependencies `[513, 517, 553, 654, 657]`, seven files in `file_scope`. Its description carries three stacked override blocks; its Elements B to E are what this amendment reinstates in a different form.
- `re_site_branch_aware_batch_after_prerequisites` (666): `not_started`, no dependencies. Commit `7231ccbe2` ("roadmap: maintenance pass (re-site the branch-aware batch after its prerequisites)") changed the roadmap data after this task was created, so its work may already be applied. [CARRIED-UNVERIFIED: commit `7231ccbe2` subject line; the authored batch positions were not re-read]

## Decisions

Recommended rulings for the amending record. Each is a research recommendation for the plan and implement phases to adopt or refuse; nothing here has been written to a decision record.

1. **Confirm the amendment.** The four defects and the pollution hazard are properties of the removed layer. Write the dated `**Amended by**` note and the amending record, engaging all five rows of finding 1 plus the three omitted hazards.
2. **R1, confirmed with one change.** The primary tree stays on the declared integration branch and is never switched. Admission refuses when it is on another branch, or when tracked paths outside the state territory are dirty. A blanket "clean" test is refused: it would reject every invocation in a tracked-`specs/` repository.
3. **R2, confirmed.** One side branch and one worktree per invocation, cut from the integration tip, named from the session identity, reused on resume, sited outside the repository in a per-user state directory, recorded in a batch record under the primary tree's state directory. In a tracked-`specs/` repository the worktree is sparse and excludes `specs/`.
4. **R3, modified.** One squash commit per completed task lands on the integration branch, built by attribution (`cherry-pick -n` of that task's own commits, merge commits excluded), not by `merge --squash` of an end commit. Landing refuses, loudly, if the unlanded range holds a commit attributable to no task or a pick conflicts. Verification is blob equality over the task's own path set and runs strictly before the status write. The landing is idempotent: a re-run after a recorded proof is a no-op.
5. **R5, confirmed with scope limits.** Isolation returns at batch granularity only. Nothing is cloned, hardlinked or symlinked into the worktree, with no exception for build directories. Per-dispatch worktrees, hardlink cloning and the harness's per-agent worktree option stay removed. Isolation is a per-repository declaration and is off for Lean repositories (decision 9).
6. **R6 consequence.** The one-HEAD premise no longer holds where isolation is on, so the expected-ref parameter of `phase_commit_boundary_mechanical_check` becomes per tree: the batch branch, queried in the batch worktree. `commit-layer-cluster-ordering.md`'s Judgment 1 condition fires. Its evidence was that `git-commit-scoped.sh` "changes to its project root and commits"; with two roots that step chooses a HEAD. Source-store commit scoping (536) and the third containment site (567) therefore become semantic predecessors of the two-root work, not territory-only ones. Both already precede 655 transitively through 553, so no existing edge is wrong; the new tasks that edit the commit scripts must depend on 553 and 513 in their own right, and the cluster-ordering record needs a dated amendment note saying its Judgment 1 ruling has changed.
7. **`milestone-ref-land.sh` is retired as a landing mechanism.** Under the amended R3 the integration branch itself carries one squash commit per task, so a parallel ref adds only D4's duplicate history. `milestone-review-handoff.sh` should point its review range at the integration branch. Before retirement lands, repair `--verify` as its own small task: compare the landed commit's tree to the tree of the source commit recorded at landing time, make a second landing of an unchanged tree a no-op, and replace the retry message. Ship it with the negative fixture from finding 2.
8. **Symlinks are rejected** for `specs/`, `.claude/` and any build directory (finding 5).
9. **Lean: Option L1.** `worktree_isolation` (name to be fixed by the amending record) is a top-level key in `.claude-extensions.json` beside `integration_branch`. With it off, a repository gets the admission-time branch check and nothing else: phase commits land directly on the integration branch as they do today, and there is no per-task squash. What is lost is exactly the squash; the user's review unit there is the range of a task's commits, or a squash chosen at merge time. A plumbing squash inside one shared tree was considered and refused: it requires the single tree's HEAD to sit on a side branch, which every concurrent session in that tree would then share. L2 is deferred to a feasibility spike with a stated protocol (populate the local Lake cache from one tree, build a second tree at a different path with the network blocked, count rebuilt modules).
10. **Wrong root is a refusal, not a warning.** While a batch record is live for the session, the commit scripts refuse a code pathspec with no code root, the write-time hooks refuse an edit to a tracked non-state path under the primary root, and the destructive-git guard evaluates the tree the command targets.
11. **Cleanup.** When every task of the batch has a recorded landing proof: check the worktree for modified, untracked and non-allowlisted ignored content; `git worktree remove` without `--force`; delete the branch by compare-and-swap against the proven tip. Any task left partial, blocked, failed or abandoned keeps both, including when siblings have landed; landed siblings' commits simply remain on the branch as history already present on the integration branch. `/refresh` lists batch records whose session is not live and whose worktree still exists, and removes nothing.
12. **Task records.** 655 is superseded by the units in Recommendations, apart from its Element F (generated-file declaration), which is unrelated to topology and should survive as 655's whole remaining scope with a rewritten description. 666 should be checked against commit `7231ccbe2` and abandoned as already applied if the positions are fixed.

`user_decision` (non-blocking, recorded in `.return-meta.json`): in a tracked-`specs/` repository, may bookkeeping commits keep landing directly on the integration branch between squash commits (recommended; simple, durable, and how it works today), or must each task's state and artifact changes be held uncommitted and folded into its squash commit (one commit per task with nothing between, at the cost of state sitting uncommitted for the life of a task, against the commit-per-green-substep mandate)?

## Recommendations

Split the work. The ruling, the audit and the landing mechanics are separable, and the audit alone covers 194 files.

1. **Repair `milestone-ref-land.sh --verify` now**, independently of everything else. Tasks are being stranded at `[IMPLEMENTING]` today. Scope: the script, its test, and the one message line in `orchestrate-cycle-postflight.sh`. It shares that file with the commit-layer chain, so it needs a territory edge or a deliberately early slot.
2. **Write the amending record** and the dated notes on `branch-topology-and-landing-strategy.md` and `commit-layer-cluster-ordering.md`; rewrite 655's description; settle 666; write the edges with `update-task-status.sh --depends-on-add`.
3. **Declarations and admission**: the `integration_branch` and isolation keys, their schema rows, the branch and dirtiness assertion in `orchestrate-cycle-plan.sh`'s preflight, the batch record, and idempotent worktree creation (sparse where `specs/` is tracked).
4. **Two-root audit**: an explicit code-root parameter carried in the dispatch file by `orchestrate-build-dispatch.sh`; the commit scripts, snapshot, verification and build-guard callers made two-root aware; the three hook classes in decision 10; the 27 instruction documents. Start from `reports/01_two-root-consumers.tsv` and classify every row.
5. **Per-task landing and verification** in postflight, under the existing commit mutex, with the negative fixture and a conflict fixture for two concurrent batches (refuse, leave the task un-completed and the branch intact, resume by back-merging and re-running).
6. **Cleanup, retention and `/refresh` reporting**, with the ignored-file precondition.
7. **Documentation parity**: `git-workflow-narrative.md`'s Branch Strategy section, `ref-plumbing-landing.md`, the branch-target rule in `rules/git-workflow.md`, and the schema rows in `repo-level-declarations.md`. Current design only.

Measure before adopting, since none of these could be measured from a dispatched research agent: whether Claude Code file tools prompt or refuse for a worktree outside the project directory; whether path-scoped rules apply to files there; the working directory a hook process actually receives; and the L2 spike in decision 9.

Keep the design free of new prose in `skill-orchestrate/SKILL.md` and `commands/orchestrate.md`; 6 B and 504 B of headroom remain.

## Risks & Mitigations

- **An agent edits the primary tree out of habit.** Its cwd resets there on every Bash call and every relative path resolves there. Mitigation: the write-time refusal in decision 10, plus an absolute code-root path in the dispatch file. This is the most likely failure in practice.
- **The silent exit-1 case in `git-commit-scoped.sh`** is treated as benign by every caller. Mitigation: refuse before staging when a batch record is live and no code root was given, so the case cannot reach exit 1.
- **Attribution depends on the commit-subject convention**, and the records show agents committing with raw `git`. Mitigation: landing refuses on any unattributed commit in the range instead of skipping it.
- **Two concurrent batches landing on one integration branch** make the second landing a real three-way pick that can conflict. Mitigation: refusal with the branch intact, resume path as in Recommendation 5; cross-session `file_scope` admission keeps it rare.
- **Unserialized builds across trees** for any non-Lean build-heavy repository that turns isolation on. Mitigation: named in the amending record as a cost; a host-wide lock is a separate decision.
- **Disk.** Each batch worktree is a full checkout. Negligible here, decisive for Lean, hence L1.
- **A user who disagrees with the `user_decision` default** changes where state commits go, which touches the commit scripts' two-root split. Mitigation: resolve it before the two-root audit is planned.

## Context Extension Recommendations

None. This is a meta task; the documentation it requires is its own Element 7.

## Appendix

**Experiments** (scratch repositories under the session scratchpad; none mutated a real repository):

- Fixture with ignored `.claude/` and `specs/`, external worktree, the deployed scripts copied in: symlink ignore matching, the six `git-commit-scoped.sh` cases of finding 3, logical versus physical resolution, shared `info/exclude`, symlink-safe removal.
- Three-landing replay of `milestone-ref-land.sh`'s primitives with ancestry and tree-equality checks and an unlanded negative fixture.
- Two interleaved tasks on one batch branch: snapshot versus attribution landing, path-set verification with a negative case, back-merge, second landing, whole-batch predicate, removal with untracked and modified files, `branch -d`, compare-and-swap deletion.
- Tracked-`specs/` fixture: sparse worktree, commit, landing, back-merge, symlink over the excluded directory.

**Commands used against live state**: `git check-ignore -v specs .claude agent-system`; `git merge-base --is-ancestor HEAD refs/heads/milestone/M1`; `git rev-list --count` in both directions; `git diff --stat d3b552593 01bda07d9`; `jq 'del(.extensions)' .claude-extensions.json`; `wc -c` on the two budgeted files; `lake --version`, `lake cache --help`, `lake env` and `du` in the Lean repository.

**Not done**: no build was timed; no harness behaviour was measured; the 168-row table was classified by hand only for the git-writing scripts; `orchestrate-cycle-plan.sh`'s preflight was surveyed by landmark, not read in full, so the exact insertion point for admission is for the planner to fix.
