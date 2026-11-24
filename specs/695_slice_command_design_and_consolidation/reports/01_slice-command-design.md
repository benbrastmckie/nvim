# Research Report: Task #695

**Task**: 695 - slice_command_design_and_consolidation
**Started**: 2026-11-24T00:00:00Z
**Completed**: 2026-11-24T00:40:00Z
**Effort**: one research dispatch; the ruling it feeds is one decision record plus six successor records
**Dependencies**: None (edges onto other records are named under Findings, "Edges")
**Sources/Inputs**:
- Source store at `cbe6bffd2`: `agent-system/extensions/core/scripts/{review-stack-prepare.sh,milestone-ref-land.sh,milestone-review-handoff.sh}`, `commands/{merge.md,please.md}`, `hooks/{please-grant.sh,guard-git-push.sh}`, `scripts/lib/push-grant-lib.sh`, `context/standards/repo-level-declarations.md`
- `specs/decisions/review-slices-are-declared-tasks.md`, the two worktree-isolation verdict records, `specs/state.json`
- sf1-engine at `1483e31` (working tree, one file modified): `integration/tools/build-pr-slices.sh`, `vision/pr-series.md`, `vision/decisions/pr-release-pipeline.md`
- sapience-app: `scripts/stack_cut.py`, `specs/decisions/branch-topology-and-landing-strategy.md`
- Live forge reads, 2026-11-24 UTC: `gh pr list --state all` in sf1-engine and sapience-app; `git for-each-ref` in four repositories
**Artifacts**: `specs/695_slice_command_design_and_consolidation/reports/01_slice-command-design.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The task description's starting finding is wrong, and the correction changes the verdict.** The sf1-engine builder has opened zero pull requests, not 22. No `pr/*` ref exists on that remote. Of the 19 merged pull requests there, 18 were written and merged by the remote owner from hand-made branches; the operator's own record is one merged (12 files) and one open (1,619 files). Neither implementation has production evidence.
- **There are three builders, not two.** sapience-app carries `scripts/stack_cut.py` (1,008 lines, hunk-level cut and restack). All three belong to the operator, all three build a review commit by the same plumbing overlay, and none has produced a merged pull request.
- **Basis verdict: neither is promoted.** `/slice` is a new, small script built on the one primitive all three converge on. `review-stack-prepare.sh` and its suite are deleted outright (2,708 lines). `build-pr-slices.sh` stays in sf1-engine as that repository's tool; its table grammar, its three structural checks and its ancestry refusal are the design carried upstream, not its code.
- **Review base: the two records disagree less than stated, and both are partly wrong.** A target branch always exists. A third, intermediate branch does not. The `review_base` key, its four refusals and the "must differ from the integration branch" rule are removed; the target is chosen in the `/slice` prompt.
- **Size bar: the method is portable, the numbers are not.** The same reviewer merges a median of 1,173 added lines in sf1-engine and 239 in sapience-app. `/slice` measures the target's merged history live, and refuses to build an over-bar slice without a recorded reason.
- **One survivor.** `/slice` replaces `/merge`, `review-stack-prepare.sh`, the handoff's printed push and merge lines, and the planned `/merge --stack`. Six parts of `review-slices-are-declared-tasks.md` are amended (S3, S4, S5 in part, S6, the retention list, and "Why not abandon").

## Context & Scope

In scope: which mechanism moves changes from a work branch into pull requests, the `/slice` command surface, the review-base contradiction, the size bar, deletions, and a disposition for each listed open record. No implementation.

Out of scope by direction: the commit-containment cluster on `scripts/git-commit-scoped.sh` and `context/standards/git-staging-scope.md`.

Not read: `extensions/cslib/commands/pr.md` beyond confirming it exists and calls the forge. The full text of the landing record beyond its L1 to L5 headings. `stack_cut.py` beyond its header and function list.

Constraints held fixed: `rules/pr-prohibition.md`; no literal branch, remote or consumer path in a deliverable under `agent-system/**`; the grant cost is stated, not designed around.

## Findings

### F1. The production evidence belongs to neither builder

Measured 2026-11-24 with `gh pr list --state all --limit 100 --json number,state,author,headRefName,baseRefName,additions,changedFiles,mergedBy` in sf1-engine:

| Measure | Value |
|---|---|
| Pull requests | 24 (19 merged, 5 open) |
| Merged, written by the remote owner | 18 of 19, each merged by its own author |
| Merged, written by the operator | 1 (#1: 12 files, 1,343 added lines) |
| Open, written by the operator | 1 (#34: 1,619 files, 481,380 added lines, base `sync-1116`) |
| Head branches named `pr/*` | 0 |
| `git for-each-ref refs/remotes` entries containing `/pr/` | 0 |
| Local `refs/heads/pr/*` | 46 |

The slice table agrees: of its 46 rows, 13 are `report written` and 33 are `planned`; none is `pushed`, `in review` or `merged` (`vision/pr-series.md` section 3). The sf1-engine record says so itself at line 6 to 7 ("no slice is pushed") and at lines 170 to 173 ("The bar is drawn from what has merged, not from what has been reviewed ... there are two data points").

The task description's "22 opened, of which 18 merged" reads the repository's whole pull-request population as the builder's output. The count has also moved since that record was written: 19 merged today, not 18.

The same pattern holds in sapience-app. The operator's seven pull requests there: none merged; four closed unmerged (three of 89 to 129 files, and one 15-file dependent closed with its parent); three open at 138, 1,530 and 1 file.

What the evidence does show, across both repositories: the operator's one merged pull request is 12 files; every unmerged one but two is 89 files or more. Size is the failure. No stack mechanic has been exercised at all.

### F2. Three builders, one primitive

| | A: `review-stack-prepare.sh` | B: `build-pr-slices.sh` | C: `stack_cut.py` |
|---|---|---|---|
| Home | agent-system source store | sf1-engine | sapience-app |
| Lines | 1,572 (suite 1,136; 61 cases pass, re-run this session) | 2,165 (negative-control driver 611) | 1,008 |
| Unit comes from | landing proofs, by inference | a hand-maintained path table | a hand-written manifest, hunk level |
| Callers | none (F3) | run by hand | run by hand |
| Pull requests opened | 0 | 0 | 0 |

All three build a review commit the same way: read a base tree into a private index, overlay the unit's blobs from the work ref, write the tree, `commit-tree`, compare-and-swap `update-ref`. A does it in `rsp_overlay_tree` (lines 870 to 904). B does it in `compose_tree` (606 to 648) and `build_one_slice` (749 to 857). C does it in `cut_one_part` (534 to 603). Three independent arrivals at one primitive is the strongest design signal in this research. Everything else in each file is how the unit is chosen and how it is checked.

### F3. A is unwired, undeclared, and has never cut a stack

- `grep -rl review-stack-prepare` over the core extension finds the script, its suite, `manifest.json`, `suite-classification.data` and two context documents. No command, skill, hook or lifecycle script calls it.
- `review_base` is declared in none of the four repositories checked (this one, sf1-engine, sapience-app, the dotfiles repository). Without it every `cut` exits 10 (`rsp_resolve_review_base`, lines 219 to 249).
- `specs/.orchestration/reviews/` exists in none of the four. No `refs/heads/review/*` ref exists in any of them.
- `review-slices-are-declared-tasks.md` rests its "Why not abandon the inference route entirely" section on "A stack already cut by `cut` exists and its manifest is on disk." That statement is false in every repository checked. The retention list (resolvers, manifest, `show`, `record-request`, `restack` as "the recovery path for a stack cut by the inference route") retains a recovery path for something that does not exist.
- A's machinery is specific to the problem it was built for: union-find merges (513 to 608), component building (649 to 680), topological sort with the contradiction refusal (681 to 749), the moved-base `merge-tree` (905 to 921), and restack (1165 to 1572). A declared path-cut slice needs none of it.

### F4. B is not promotable as code

- 83 lines reference `sf1-v2`, `diagnos*` or `run-tests`. Check 4 (lines 1119 to 1887) and report drafting (1888 to 2110) are bound to that repository's diagnostics; together they are about 990 of 2,165 lines.
- It reads its configuration out of prose: the two ceilings are found by `grep` for bold text in section 1 (`run_check3`, lines 1008 to 1011), and slices by parsing a markdown table with a glob grammar.
- The base is a literal: `MAIN_REF="origin/main"` (line 169). The record's RP1 rule 5 requires that it not read `integration_branch`.
- It is still moving: three commits on 2026-11-23 and an uncommitted 24-line change at the time of reading.
- It prints `/please push` then `/merge` with a note that the slice branch must be checked out by hand first (2103 to 2106), which its own record contradicts (section 5 step 8: "`/merge` is not used for a slice").

What B does have that A lacks, and that is worth carrying as design:

1. **Slices are path sets cut from the work-branch tip.** A file is in exactly one slice, so the `shared_paths` floor that A cannot get under (four of fourteen tasks, CARRIED-UNVERIFIED from `review-slices-are-declared-tasks.md`) does not arise.
2. **Check 1, exhaustiveness**: every changed path is in exactly one slice or on the not-landing list.
3. **Check 3, the size bar.**
4. **The ancestry refusal**: no build unless the target is an ancestor of the work ref (`resolve_refs`, 176 to 181).
5. **Re-derive, never rebase** (RP2 rule 1): a slice is rebuilt from its declaration on the current base. This makes a separate restack operation unnecessary.
6. **Dependency-scoped bases** (688 to 747): an independent slice is based on the target alone and can be opened in any order.

### F5. The review-base contradiction

S3 defines `review_base` as "the branch slices target". RP1 rejects "a review base cut from `main`", meaning a third branch standing between the work branch and the branch the owner merges into. In sf1-engine the slices target `origin/main` and the work branch is `integration/work`; in S3's own vocabulary that is a review base distinct from the integration branch. The records are closer than the task description frames them.

Where each is wrong:

- **S3's refusal compares names** (`[ "$value" = "$integration_branch" ]`, A line 244 to 246). A repository that works on its default branch and has unpushed commits has a real, non-empty difference between the local branch and its remote-tracking ref of the same name. This repository is one: work lands on `master`, the remote has `origin/master`. S3 refuses it "and gets no slices". The correct test is an empty diff, not equal names.
- **S3 requires a declaration nobody has made** (F3). A required key with no safe default means a user with no prior setup sees a refusal.
- **RP1 hardcodes the target.** sapience-app's pull requests target five different bases (`main`, `staging`, `integration/release-line`, a hotfix branch, another task branch). sf1-engine's #34 was opened against `sync-1116`, an ancestor of `main`, which is why it shows 1,619 files (RP8 evidence). The target is a per-invocation fact, and choosing it wrongly is an observed failure.

Ruling proposed: two roles only. The **work ref** is where content is read from. The **target** is a ref the slices are based on and the pull requests are opened against. There is no third branch, and RP1's rejection of one stands on its own evidence. The target is selected in the prompt with each candidate's diff size shown, which is the direct remedy for the #34 failure.

### F6. The size bar

Measured 2026-11-24 over merged pull requests, by base:

| Repository | Base | n | Median added | 75th pct added | Median files | 75th pct files |
|---|---|---:|---:|---:|---:|---:|
| sf1-engine | `main` | 19 | 1,173 | 1,915 | 10 | 14 |
| sapience-app | `main` | 14 | 239 | 763 | 3 | 7 |

Same reviewer, a fivefold difference in median. sapience-app's own record sets an 18,600-line bar (its R6), which its merged history does not support. The numbers are not portable; a bar copied from one repository to another is wrong in both directions.

The measurement is one forge read. It is cheap enough to run at every proposal.

### F7. `/merge` and the grant

- `commands/merge.md` acts on `git branch --show-current` (line 129), refuses on `main` or `master` (47, 126 to 145), reads the remote as the literal `origin` (51, 92, 201). The target defaults to `main` and is overridable by `--target` (30, 69); the task description's "hardcodes the target" is imprecise.
- Typing `/merge` already mints a push grant with no free-text parsing: `hooks/please-grant.sh` lines 64 to 65 and 83 to 87, remote fixed to `origin`, ref fixed to the checked-out branch. `/please` is one of four minting prefixes, not the only one.
- A grant is matched against `git rev-parse HEAD` at consume time (`scripts/lib/push-grant-lib.sh`, lines 453 to 464), inside `PG_EXPIRY_WINDOW`, default 600 seconds (line 101). For a slice ref built by plumbing, HEAD is not the commit being pushed. Two consequences: any commit by any session in the window kills the grant although the slice is untouched, and the grant does not pin what is pushed, since the slice ref can be rebuilt between mint and push without the match noticing.
- `milestone-review-handoff.sh` is live (called from `scripts/orchestrate-conclusion-roadmap.sh`). It prints `/please push` for the integration branch and then `/merge`. sf1-engine RP4 rule 3 records why those are not run: the first publishes the branch's whole difference, the second opens a pull request for the checked-out branch.
- `milestone-ref-land.sh` has no lifecycle caller (re-derived: the script, two suites, `manifest.json`, `suite-classification.data`, two context documents).

### F8. Every path that moves work toward review

Search 1: `grep -rlE "gh pr create|glab mr create|git push |git-push-granted"` over `agent-system/extensions`, excluding tests, context, docs, rules. Search 2, differently shaped: `grep -rlE "review\.state|refs/heads/(review|milestone|pr)/|update-ref"` over shell files. Union, less the grant machinery and `/tag`:

| # | Path | Found by |
|---|---|---|
| 1 | `scripts/milestone-ref-land.sh` | search 2 |
| 2 | `scripts/review-stack-prepare.sh` | search 2 |
| 3 | `scripts/milestone-review-handoff.sh` | both |
| 4 | `commands/merge.md` (and its mention in `skills/skill-git-workflow/SKILL.md`) | search 1 |
| 5 | `extensions/cslib/commands/pr.md` | search 1; **not in the task description's list** |
| 6 | sf1-engine `build-pr-slices.sh` | outside the store |
| 7 | sapience-app `stack_cut.py` | outside the store; **not in the task description's list** |

`scripts/roadmap-integration.sh` matches search 2 on `review.state` only; it renders that field and moves nothing.

### F9. Edges

- **Commit containment (out of scope).** A path-cut slice is read from the work-branch tip's tree, not from any task's commits, so it does not depend on commits being correctly scoped. The one soft edge: a task's `modified_files` is used as a grouping hint in the proposal. A wrong hint produces a worse proposal, which the approval prompt shows; it cannot produce a wrong tree.
- **`redeploy_phase_declaration_and_gate_criterion`.** The obligation in `review-slices-are-declared-tasks.md` to site one redeploy per batch exists only because S6 made each slice a task. With S6 overturned the obligation lapses.
- **`branch_aware_orchestration_and_squash_landing`.** Its generated-path declaration is the input to the slice bar's hand-written line count. Hard edge: the bar is miscounted in any repository with generated files until that declaration exists.

## Decisions

1. **Outcome overturned: the starting hypothesis.** "Promote B upstream and delete A's inference machinery" is half right. A is deleted. B is not promoted. Its production evidence does not exist (F1), and about half its lines are one repository's gate (F4).
2. **Ground overturned, outcome preserved: S1 and S2.** The outcome stands: a slice is declared before it is built and approved by a human, and it is not the task that did the work. The ground changes. The record argued from the `shared_paths` floor of an inference route with a stack on disk. The supported ground is F1: the only failure observed in either consumer repository is size, and a declared path cut with a bar is the direct remedy.
3. **Outcome overturned: S3.** No `review_base` key, no equal-name refusal. Two roles, target chosen at the prompt (F5).
4. **Outcome overturned: S4.** A slice is not landed "by an ordinary scoped commit from a working tree". That requires either checking a review branch out in the primary tree, which the integration-branch admission rule forbids, or a second working tree, which is ruled off. A slice is built by the plumbing overlay all three builders already use.
5. **Outcome overturned: S6.** A slice is not a task. Researching, planning and implementing a path subset that already exists on the work branch is lifecycle with no work in it. A slice is a row in one series file.
6. **Outcome overturned in part: S5.** Stacking by declared dependency stands. "Slice N+1 branches from slice N" becomes "a slice's base is the target plus only the slices it names". Restack by forge base edit is replaced by re-derivation after a merge-up.
7. **Outcome overturned: the retention list and "Why not abandon".** Nothing of A is retained as wired code (F3).
8. **S7 stands unamended.**
9. **RP1's "no review base" stands** as "no third branch". Its literal target does not carry upstream.
10. **One invocation, one target.** "Or branches as appropriate" is satisfied by a dependent slice's pull request being opened against its parent slice's branch. A second target is a second invocation.

## Recommendations

### R1. The command surface

`/slice [description]`, user-only, in the same class as `/merge` and `/tag`. The description, when given, steers the target and the grouping ("the hook changes, to the release line"). It is never required.

What a user with no argument and no prior setup sees, in order:

1. **Resolution, printed, no question.** Work ref: the checked-out branch. Remote: that branch's configured remote, else the only remote, else a question. A dirty tree prints one line saying uncommitted changes are not sliced.
2. **Prompt 1, the target.** Up to four options, each with its measured difference from the work ref:
   - an in-flight series, if a series file exists ("continue: 3 of 7 merged");
   - the remote's default branch;
   - bases of the user's open pull requests on this remote, when they differ from the above;
   - free entry.

   Each line reads like `<target>: 620 commits ahead, 1,479 files, 35,144 hand-written lines`. A candidate that is not an ancestor of the work ref is shown with "needs a merge-up first" and cannot be chosen; `/slice` does not merge.
3. **The bar, printed.** `bar: 1,915 lines / 14 files (75th percentile of 19 merged pull requests on <target>)`, or `declared`, or `default, unmeasured`.
4. **Prompt 2, the proposal. This is the product.** One table:

   | id | title | files | lines / bar | depends on | opens against |
   |---|---|---:|---|---|---|

   Under it, four fixed lines: `unassigned=0 duplicate=0`; the not-landing paths and generated paths excluded, with counts; every over-bar slice with its recorded reason or `NO REASON: will not build`; and the cost line, `7 slices: 7 typed pushes, then 1 /slice to open them`. Options: approve, revise (free text, re-proposes), cancel.
5. **On approval.** Write the series file. Build every slice ref by plumbing. Verify that overlaying every slice onto the target reproduces the work tree for the assigned paths. Print, per slice, the one line the user types to push it.
6. **A later `/slice` on an in-flight series** shows state per slice and does what is due: opens a pull request for each slice whose remote ref equals its built commit and whose dependencies leave it at most one unmerged parent, records the URL, marks merged slices merged, and after a merge-up rebuilds every unmerged slice whose base moved.

The proposal itself (which paths go together) is made by the command's model from the diff, directory structure and task `modified_files`. The script validates and builds. No inference code is written.

### R2. The mechanism

- One script, one series file at `specs/.orchestration/slices/<series id>.json`: target, remote, bar and its source, and per slice id, title, path globs, depends-on, over-bar reason, state, built commit, request URL. It is the single home for slice state.
- Subcommands: `check` (exhaustiveness, duplicates, size, ancestry), `build`, `status`. The forge call lives in the command file, never in the script.
- A size estimate of 400 to 600 lines is an estimate, not a measurement.
- Default: open a dependent slice only after its dependencies merge. That makes every slice a one-push, never-force-pushed branch based on the target. Opening a visible stack earlier is allowed and costs one further typed force-with-lease push per already-pushed dependent after each parent merge; the prompt states that count.

### R3. The size bar

- A refusal, not an advisory: `build` will not build an over-bar slice unless its row carries a reason (single unsplittable file, or a declared generated tree landing alone).
- Source, in order: a declared `slice_bar` object in `.claude-extensions.json`; else the 75th percentile of merged pull requests on the chosen target, when there are at least five; else a shipped default of 1,500 lines and 30 files, printed as unmeasured.
- Lines are added lines over hand-written paths. Generated paths come from the declaration `branch_aware_orchestration_and_squash_landing` owns.
- The 75th percentile was run against both live corpora (F6): 1,915 / 14 and 763 / 7. Run against sf1-engine's 46 declared rows (4 marked mechanical or escape-valve and exempt): none exceeds 1,915 lines, and 2 exceed 14 files. The measured file bar is tighter than that record's 30, so two rows that pass there would need a split or a reason here. The choice of the 75th percentile over the median is a preference. [CORPUS-UNVERIFIED: this repository, which has no merged pull requests / the shipped default has not been checked against a proposed cut of this repository's own unpushed work]

### R4. Survivor and deletions

| Path | Disposition |
|---|---|
| `/slice` (new command and script) | **The one survivor** |
| `scripts/review-stack-prepare.sh` | Deleted, all four subcommands |
| `scripts/tests/test-review-stack-prepare.sh` | Deleted, with its `suite-classification.data` and `manifest.json` rows |
| `review_base` section of `context/standards/repo-level-declarations.md`, and its mention in `orchestrator-runtime-files.md` | Deleted |
| `scripts/milestone-ref-land.sh` and its suite | Deleted, by `milestone_ref_land_recreates_retired_ref` as already owned |
| `scripts/milestone-review-handoff.sh` | Kept, narrowed: it detects a finished milestone and drafts the summary; it prints `/slice` and no push or merge line, and stops writing `review.state` and `review.ref` |
| `commands/merge.md` | **Removed, not fixed.** Fixing its three defects (explicit head, explicit base, resolved remote) produces `/slice`'s submit step; two commands with one submit step is two methods. `/slice` with one slice is the single-branch case. 29 files mention `/merge`; the rewrite is its own successor, including the `[PR READY]` text and the `merge` minting prefix |
| `/merge --stack` | Never built |
| `extensions/cslib/commands/pr.md` | Not ruled here; not read. Named so it is not silently orphaned |
| sf1-engine `build-pr-slices.sh`, sapience-app `stack_cut.py` | Not deleted by this repository. Each consumer retires its own once `/slice` is deployed there; sf1-engine's check 4 becomes a declared per-slice self-check command, a successor |

### R5. Grants, stated

- Today's cost for N independent slices: N typed `/please push`, each inside 600 seconds with HEAD unmoved, then one `/slice`. In a repository with live orchestration the HEAD binding will kill grants routinely.
- Named separate work, none assumed by this design:
  1. Bind a grant for a ref other than the checked-out branch to that ref's commit, not to HEAD. This both stops unrelated commits killing it and makes the grant pin what is pushed.
  2. Let a typed `/slice push <id>` mint for exactly that slice ref, as typing `/merge` mints today. N typed commands, no separate `/please`.
  3. A batch grant, one typed approval for N refs. A change to the consent model; not recommended ahead of 1 and 2.

### R6. Verdict on each open record

| Record | Verdict | Reason |
|---|---|---|
| `handoff_prints_review_stack` (692) | Survives revised | The handoff prints `/slice`, not a stack; its plan is rewritten |
| `merge_command_stack_mode` (693) | Abandon | `/merge` is removed and `--stack` is never built |
| `stack_pr_redeploy_and_second_repo_demo` (694) | Survives revised | Doc parity, redeploy and the runbook, for `/slice`; depends on the `/slice` build, not on 692 and 693 |
| `milestone_ref_land_recreates_retired_ref` (690) | Survives unchanged | The deletion it owns is confirmed (F7) |
| `branch_aware_orchestration_and_squash_landing` (655) | Survives revised | Its generated-path declaration gains a second consumer, the bar's line count; the priority raise stands on that ground |
| `two_root_contract_dispatch_and_commit_scripts` (670), `two_root_contract_in_hooks` (671), `two_root_classification_of_remaining_consumers` (672), `batch_worktree_cleanup_retention_orphan_report` (674), `batch_worktree_creation_when_isolation_on` (686) | Abandon, all five | Isolation is irrelevant to slicing. Its one review-side benefit was a clean per-task commit range (sf1-engine RP7: "That is the real loss of `off`"); a path cut from the tip does not need one. Slices are built without any working tree, and a self-check tree is made by `git archive`, which registers nothing. Any case for isolation must now be made on dispatch concurrency alone; two accepted records already rule against per-dispatch isolation on that ground. The batch-isolation record was not read in this research, so this verdict is the lowest-confidence row in the table and holding the five is the safe fallback |

### R7. Successors for the decision record to name

1. `/slice` script and command (check, build, status; target prompt; proposal prompt).
2. Live bar measurement and the `slice_bar` declaration.
3. Deletion of `review-stack-prepare.sh`, its suite and the `review_base` declaration.
4. Removal of `/merge` and the rewrite of its 29 references.
5. Handoff narrowing (revised 692).
6. Grant binding to the pushed ref (R5 item 1), filed against the consent hooks.

## Risks & Mitigations

- **Whole-file granularity.** A file that must be divided between two slices cannot be. sf1-engine RP2 rule 6 found none in 46 rows. Mitigation: it lands whole in the earlier slice; hunk-level cutting stays unbuilt until one real case exists.
- **A slice that omits a file it needs.** Tree equality proves the union is right, not that each slice stands alone. Mitigation: the optional declared self-check on a `git archive` of the slice; until it exists the prompt says no per-slice check ran.
- **Proposal quality rests on the model.** Mitigation: the script's checks are mechanical, and the approval prompt shows the over-bar and unassigned counts.
- **Deleting 2,708 tested lines.** They have no caller and no stack depends on them; git history keeps them.
- **Removing `/merge` touches 29 files and the consent hook.** Mitigation: its own successor, after `/slice` works.
- **This design also has zero production evidence.** The first successor should end with one real slice pushed and opened by the operator, not with a suite count.

## Context Extension Recommendations

None; this is a meta task.

## Appendix

- Commands used: `gh pr list --state all|merged --json ...` (two repositories); `git for-each-ref refs/heads/{pr,review,milestone} refs/remotes`; `grep -rl` for callers of each script; `bash scripts/tests/test-review-stack-prepare.sh` (61 passed, 0 failed); `wc -l` for every line count stated.
- Things built or planned that this report discards: `review-stack-prepare.sh` and its suite; the `review_base` declaration; `/merge`; the planned `/merge --stack`; the planned stack-printing handoff; slices as tasks (S6); slices landed by scoped commit (S4); the five held worktree and two-root records.
