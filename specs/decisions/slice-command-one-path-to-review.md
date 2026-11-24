# Decision Record: `/slice` Is the One Path From a Work Branch to Review

This record rules how changes on a work branch become pull requests: the `/slice` command, the
single mechanism behind it, and the removal of every other path. It amends
`specs/decisions/review-slices-are-declared-tasks.md` (the "slices record") and
`specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (the "landing
record") in the places listed under "Assertions amended".

Decided 2026-11-24 (UTC) by `slice_command_design_and_consolidation` (695), session
`sess_1795478339_253676`, under operator direction of 2026-11-23 that nothing built or planned is
assumed right or worth keeping. Research:
`specs/695_slice_command_design_and_consolidation/reports/01_slice-command-design.md` (the
"research report"). Tasks are named by slug with the number alongside.

This record rules. It builds nothing. No file under `agent-system/**` or `.claude/**` was changed
by it, and no other task record was changed by it; "Operator worklist" names what the operator
runs to apply its verdicts.

**The ruling in six lines.**

1. One mechanism survives: `/slice`, a user-invoked command over one small script and one series
   file. A slice is a declared set of paths cut from the work-branch tip.
2. Neither existing builder is its basis as code. `review-stack-prepare.sh` and its suite are
   deleted. Consumer-repository builders stay where they are until their repositories retire them.
3. There is no review base. Two roles exist: the work ref and the target. The target is chosen at
   the prompt, never declared.
4. The size bar is a refusal with a recorded-reason escape. Its method is portable and its numbers
   are not.
5. `/merge` is removed, not fixed. `/merge --stack` is never built.
6. Of the ten listed open records, one survives unchanged, three survive revised, and six are to
   be abandoned: `merge_command_stack_mode` and the five held worktree and two-root records. An
   eleventh, unlisted record is touched and gets a row.

## Evidence

Every figure below was re-derived on 2026-11-24 (UTC) from the live files or the live forge, at
these commits. Nothing in this section is carried from the task description or the research
report unless marked CARRIED-UNVERIFIED.

| Repository | Commit read | Branch | State of the files read |
|---|---|---|---|
| This repository (owns the source store at `agent-system/extensions/core`) | `fbdccb9dd` | `master` | Source-store files below unmodified in the working tree |
| sf1-engine | `a859d1c` | `integration/work` | `integration/tools/build-pr-slices.sh` committed and clean; last commit to it 2026-11-23T16:11:58-08:00 |
| sapience-app | `ad5c3ce3` | `mvp` | `scripts/stack_cut.py` clean; last commit to it `d542cf88` |

Paths under "this repository" are relative to `agent-system/extensions/core/` unless they begin
with `specs/`.

### E1. Builder A: `scripts/review-stack-prepare.sh`

| Fact | Value | Where |
|---|---|---|
| Length | 1,572 lines; suite `scripts/tests/test-review-stack-prepare.sh` 1,136 lines | `wc -l` |
| Suite result | `Results: 61 passed, 0 failed` | run from the source store this session |
| Subcommands | `cut`, `restack`, `show`, `record-request` | dispatch `case` at 1452 to 1455; branches at 1550 to 1564 |
| Declared review base is read from | the top-level `review_base` key of `.claude-extensions.json` | `_rsp_declared_review_base`, 206 to 215 |
| Refusal when undeclared | exit 10 `review_base_undeclared` | `rsp_resolve_review_base`, 219 to 247, at 234 |
| Refusal when equal to the integration branch | a comparison of names: `[ "$value" = "$integration_branch" ]`, exit 13 | 243 to 245 |
| Union-find over tasks | `uf_find`, `uf_union`, `rsp_build_task_merges`, `rsp_build_units` | 513 to 608 |
| Components over dependency edges and path overlap | `comp_find`, `comp_union`, `rsp_build_dependency_edges_and_components` | 628 to 680 |
| Contradiction refusal and topological sort | `rsp_check_order_contradictions`, `rsp_topo_sort_component` | 681 to 749 |
| Overlay primitive | private index, `read-tree` the base, set blobs, `write-tree` | `rsp_overlay_tree`, 870 to 904 (`read-tree` 874, `write-tree` 889) |
| Moved-base recompute | `git merge-tree --write-tree --merge-base=...` | `rsp_move_commit_onto_new_parent`, 905 to 921 (call at 908) |
| Commit and ref move | `commit-tree` 1020 and 1048; compare-and-swap `update-ref` 1049 | `rsp_cut_execute`, 983 to 1093 |
| Restack | `rsp_restack_*` | 1165 to the end of the file |

Callers, by `grep -rl review-stack-prepare` over the core extension: the script, its suite,
`manifest.json`, `scripts/tests/suite-classification.data`, and two context documents
(`context/standards/orchestrator-runtime-files.md`,
`context/standards/repo-level-declarations.md`). No command, skill, hook or lifecycle script
calls it. The same search over the rest of `agent-system/` returns nothing.

### E2. Builder B: sf1-engine `integration/tools/build-pr-slices.sh`

| Fact | Value | Where |
|---|---|---|
| Length | 2,187 lines (`vision/pr-series.md` 418; `vision/decisions/pr-release-pipeline.md` 518) | `wc -l` |
| Base ref | a literal: `MAIN_REF="origin/main"` | line 169 |
| Work ref | `HEAD`, overridable by a test flag | line 174 |
| Ancestry refusal | `git merge-base --is-ancestor "$MAIN_REF" "$WORK_REF"`, else exit 2 | `resolve_refs`, 176 to 181 (test at 179) |
| Overlay primitive | private index, `read-tree` the base, `write-tree` | `compose_tree`, 606 to 648 (`read-tree` 615, `write-tree` 645) |
| Slice build | `commit-tree` 827; compare-and-swap `update-ref` 829 | `build_one_slice`, 749 to 857 |
| Dependency-scoped bases | each row's base is the base ref plus only the closure of the rows it names | `compute_slice_closures` 688 to 722, `compose_slice_bases` 723 to 748 |
| Check 1, exhaustiveness | every changed path in exactly one row or on the not-landing list | `run_check1`, 878 to 936 |
| Check 2, tree equality | built ref's diff against its base equals the row's path set | `run_check2`, 937 to 991 |
| Check 3, size | ceilings read by `grep` for bold text in a prose section of the slice table | `run_check3`, 1007 to 1118 (the two `grep` lines at 1009 and 1010) |
| Check 4, that repository's diagnostics gate | `check4_*` and `run_check4` | 1119 to 1887 (769 lines) |
| Report drafting from that repository's template | `load_sec4_template` to `write_reports_and_print` | 1888 to 2111 (224 lines) |
| Lines naming that repository's own tree, diagnostics or test runner | 83 | `grep -cE 'sf1-v2|diagnos|run-tests'` |
| Printed operator commands | `/please push origin <ref>` then `/merge`, with a note that the slice branch must be checked out by hand first | 2102 to 2104 |

Checks 4 and report drafting together are 993 of 2,187 lines. The file had four commits on
2026-11-23 (`829cd73`, `2f09580`, `1483e31`, `a859d1c`).

The slice table's state column (`vision/pr-series.md` section 3): 33 rows `planned`, 13 rows
`report written`; no row is `built`, `pushed`, `in review` or `merged`.

The sf1-engine record (`vision/decisions/pr-release-pipeline.md`), as read:

- Lines 5 to 7: "No key is declared, no branch is renamed and no slice is pushed".
- RP1 (39 to 83): "There is no separate review-base branch. An independent slice is based on
  `origin/main`. A dependent slice is based on the slices its 'Depends on' cell names." The
  rejected alternative (80 to 83) is "a review base cut from `main`", which "protects against
  nothing here: `main` already contains everything a slice is based on."
- RP3 (135 to 181): a backlog ceiling of 1,500 hand-written changed lines and 30 files, a
  milestone dividing above 3,000 lines or 30 files; evidence over 18 merged pull requests (median
  10 files, 1,258 added lines). Lines 170 to 173: "The bar is drawn from what has merged, not from
  what has been reviewed. In the direction this pipeline serves ... there are two data points".
- RP7 (309 to 358): isolation is off; of declaring it on, "a forward milestone becomes a clean
  commit range. That is the real loss of `off`" (355 to 356).
- Section 5, step 8 (446 to 450): the pull request is opened by a hand-typed `gh pr create --base
  <base> --head pr/<id>`; "`/merge` is not used for a slice, because it opens a pull request for
  the checked-out branch."
- Section 8 (497 to 518): the "Upstream requirements" row is "filed in the agent-system
  source-store repository, not here".

### E3. Builder C: sapience-app `scripts/stack_cut.py`

Read: lines 1 to 110, 369 to 640, 727 to 741 and 861 to 906 in full; the remaining functions by
signature and docstring.

| Fact | Value | Where |
|---|---|---|
| Length | 1,008 lines | `wc -l` |
| Subcommands | `provenance`, `validate`, `cut`, `verify`, `restack` | header 11 to 26 |
| Unit comes from | a hand-written manifest: per part, a file list, each file pinned to a blob at a named commit | schema 60 to 97 |
| Granularity | whole-file blobs; one variant (`history_blob_minus`) takes a blob and reverse-applies named whole commits to it | `resolve_blob`, 462 to 488 |
| Overlay primitive | private index, `read-tree` the base, `update-index --cacheinfo` per path, `write-tree`, `commit-tree` | `cut_one_part`, 534 to 601 |
| Ref move | two-argument `update-ref`, not compare-and-swap | line 597 |
| Where it writes refs | never under `refs/heads/**`; default namespace `refs/stackcut-test` | `assert_safe_ref_namespace` 378 to 380; defaults at 973, 981, 986 |
| Size | reported, "informational only"; no refusal | `size_report`, 727 to 740 |
| Restack | rebuild a part on a moved base after checking its own paths did not change underneath | `restack_one_part`, 861 to 904 |

Refs it has written in that repository: `refs/l1-cut/L1-1`, `refs/l1-cut/L1-2`,
`refs/stackcut-test/L1-1`, `refs/stackcut-test/L1-2`. None is a branch, so none can be a
pull-request head as written.

### E4. What the three builders have produced

`gh pr list --state all --limit 200 --json
number,state,author,headRefName,baseRefName,additions,changedFiles,mergedBy`, and `git
for-each-ref`, in each repository.

| Measure | sf1-engine | sapience-app | This repository |
|---|---|---|---|
| Pull requests | 24: 19 merged, 5 open | 30: 14 merged, 9 open, 7 closed unmerged | 16: 12 merged, 4 closed unmerged |
| Head branches named `pr/*`, `review/*` or `slice/*` | 0 | 0 | 0 |
| Remote-tracking refs containing `/pr/` | 0 of 27 | 0 of 406 | 0 of 6 |
| Local `refs/heads/pr/*` | 46 | 0 | 0 |
| Local `refs/heads/review/*` | 0 | 0 | 0 |
| Local `refs/heads/milestone/*` | 4 | 8 | 4 |
| Merged, by author | 18 by the remote owner (all 18 self-merged), 1 by the operator | 9 by one maintainer (self-merged), 4 and 1 by two others, 0 by the operator | 1 by the operator; 11 by nine outside contributors |
| The operator's own | #1 merged (12 files, 1,343 added); #34 open (1,619 files, 481,380 added, base `sync-1116`) | 0 merged; 4 closed unmerged (89, 100, 129 and 15 files); 3 open (138, 1,530 and 1 file) | not measured per pull request |
| Distinct bases used | `main`; `sync-1116` | `main`, `staging`, `integration/release-line`, a hotfix branch, a task branch, a release branch | `master`, `lua` |

No pull request in any of the three repositories has a head ref any of the three builders
wrote. **None of the three builders has opened a pull request.**

Across the operator's own pull requests in the two consumer repositories: the one that merged
is 12 files; of the eight that did not, six are 89 files or more, one is a 15-file dependent
closed with its parent, and one is a 1-file request still open.

### E5. Merged-history size, by target

Merged pull requests whose base is the repository's default branch. Percentiles are
nearest-rank (the value at position `ceil(q * n)` of the sorted list), chosen because it always
names a pull request that actually merged.

| Repository | n | Median added lines | 75th percentile added | Median files | 75th percentile files | Largest |
|---|---:|---:|---:|---:|---:|---|
| sf1-engine | 19 | 1,173 | 1,915 | 10 | 14 | 42,260 lines, 230 files |
| sapience-app | 14 | 117 | 763 | 3 | 7 | 22,311 lines, 96 files |
| This repository | 11 | 7 | 52 | 1 | 1 | not recorded |

Two facts about these populations bear on the ruling. In sf1-engine 18 of 19 merged pull
requests were written and merged by the same person, so the distribution measures what the
remote owner writes for himself, not what he accepts from a reviewer-facing contributor. In this
repository the merged population is small outside contributions to a repository the operator
owns and pushes to directly; `git diff --shortstat origin/master master` is 937 files and 79,638
added lines (826 of the files under `specs/`, 110 under `agent-system/`), against a measured
75th percentile of 52 lines and 1 file.

### E6. Declarations and state on disk

| Check | This repository | sf1-engine | sapience-app | The dotfiles repository |
|---|---|---|---|---|
| Top-level `review_base` in `.claude-extensions.json` | absent | absent | absent | absent |
| Top-level `integration_branch` | absent | `integration/work` | `integration/release-line` | absent |
| `specs/.orchestration/reviews/` | absent | absent | absent | absent |
| `refs/heads/review/*` | 0 | 0 | 0 | 0 |

`review_base` is declared nowhere, so builder A's `cut` exits 10 in every repository checked,
and no stack manifest exists anywhere. This repository's local `master` is 344 commits ahead of
`origin/master` and 0 behind (`git rev-list --left-right --count origin/master...master`): a
repository that works on its default branch has a real, non-empty difference between a branch
and the remote ref of the same name.

### E7. `/merge` and the push grant

| Fact | Value | Where |
|---|---|---|
| `/merge` acts on | `git branch --show-current` | `commands/merge.md` line 129 |
| Refuses on | `main` or `master` | 47, 126 to 145 |
| Remote | the literal `origin` (`git remote get-url origin`, `git push -u origin HEAD`) | 51, 92, 201 |
| Target | defaults to `main`, overridable by `--target BRANCH` | 30, 69, 81 |
| Prompt prefixes that mint a grant | exactly four: `/please`, `/merge`, `/tag`, `/pr` | `hooks/please-grant.sh` 4, 60 to 71 |
| A typed `/merge` or `/pr` mints | `push_branch`, remote `origin`, ref the checked-out branch, no free-text parsing | 82 to 88 |
| `/please push <remote> <branch>` | names any branch, checked out or not | 127 to 134 |
| One grant at a time | every mint revokes the previous grant first | 231 to 232 |
| A grant is matched against | `git rev-parse HEAD` at consume time | `scripts/lib/push-grant-lib.sh` 453, 464 |
| Expiry | `PG_EXPIRY_WINDOW`, default 600 seconds | line 101 |

Files in `agent-system/extensions` mentioning `/merge` as a command
(`grep -rlE '(^|[^a-zA-Z/.-])/merge\b'`): 27.

### E8. Every path that moves work toward review

Search 1: `grep -rlE "gh pr create|glab mr create|git push |git-push-granted"` over
`agent-system/extensions`, excluding tests, context, docs and rules. Search 2, differently
shaped: `grep -rlE "review\.state|refs/heads/(review|milestone|pr)/|update-ref"` over shell
files, excluding tests. The union, less the grant machinery itself (`commands/please.md`,
`hooks/guard-git-push.sh`, `hooks/please-grant.sh`, `scripts/git-push-granted.sh`,
`scripts/lib/push-grant-lib.sh`), the tag path (`commands/tag.md`, `skills/skill-tag/SKILL.md`)
and three index files that only list the others (`index-entries.json`, `manifest.json`,
`README.md`):

| # | Path | Found by | What it does today |
|---|---|---|---|
| 1 | `scripts/milestone-ref-land.sh` (244 lines) | search 2 | No lifecycle caller: `grep -rl` finds the script, two suites, `manifest.json`, `suite-classification.data` and two context documents |
| 2 | `scripts/review-stack-prepare.sh` | search 2 | E1; no caller |
| 3 | `scripts/milestone-review-handoff.sh` (299 lines) | both | Live: called from `scripts/orchestrate-conclusion-roadmap.sh` (line 254). Writes `review.state` and `review.ref`, drafts a summary, prints `/please push <integration branch>` then `/merge` (272 to 273, 294 to 295) |
| 4 | `commands/merge.md` (485 lines), with its mention in `skills/skill-git-workflow/SKILL.md` | search 1 | E7 |
| 5 | `extensions/cslib/commands/pr.md` (2,406 lines) | search 1 | A separate extension's user-invoked command: branches from a named upstream, runs that project's CI steps, pushes and opens a pull request; has its own `--stacked` mode (37, 51 to 54) |
| 6 | sf1-engine `build-pr-slices.sh` | outside the store | E2 |
| 7 | sapience-app `stack_cut.py` | outside the store | E3 |

`scripts/roadmap-integration.sh` matches search 2 on `review.state` only; it renders that field
and moves nothing.

### E9. Where this evidence differs from what was carried

| Carried claim | Source | Live result |
|---|---|---|
| The sf1-engine builder "has opened 22, of which 18 merged" | task description | It has opened none. The 22 (now 24) are that repository's whole pull-request population; 18 of the 19 merged were written by the remote owner on hand-made branches |
| Two independent implementations exist | task description | Three: sapience-app's `stack_cut.py` is the third |
| Four overlapping mechanisms plus one outside | task description | Seven rows (E8); the cslib `/pr` command and `stack_cut.py` are the two not listed |
| `/merge` "hardcodes ... the target `main`" | task description | The remote is hardcoded; the target is a default with a `--target` override |
| Builder B is 2,165 lines with an uncommitted change | task description; research report | 2,187 lines, committed, at `a859d1c`. Every line number in E2 is against that commit; the research report's line numbers for B are superseded |
| Builder C is a "hunk-level cut" | research report | Whole-file blobs, with one variant that subtracts named whole commits from a blob. It does not cut arbitrary hunks |
| All three builders move refs by compare-and-swap | research report | A and B do. C uses a two-argument `update-ref` and refuses to write a branch at all |
| sf1-engine 75th percentile 1,915 lines and 14 files | research report | Confirmed under nearest-rank. Linear interpolation gives 1,899.5 and 13; this record fixes the method |
| sapience-app median 239 added lines | research report | 117 under nearest-rank over the same 14 (178 as the mean of the two middle values); 239 is the eighth of fourteen |
| "this repository ... has no merged pull requests" | research report | It has 12 merged, 11 of them on `master` (E5) |
| 29 files mention `/merge` | research report | 27 by the search stated in E7 |
| RP3 median 1,258 over 18 merged | task description | 1,173 over 19 today; the population has moved since that record was written |
