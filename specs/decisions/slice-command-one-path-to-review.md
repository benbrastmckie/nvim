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
| 1 | `scripts/milestone-ref-land.sh` (244 lines; suite `scripts/tests/test-milestone-ref-land.sh` 368) | search 2 | No lifecycle caller: `grep -rl` finds the script, two suites, `manifest.json`, `suite-classification.data` and two context documents |
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

## The command surface

`/slice [description]`. User-invoked only, in the same class as `/tag`: no agent, skill or
lifecycle script invokes it. The description is optional and is never required.

Vocabulary used below. The **work ref** is where content is read from. The **target** is the
remote branch slices are based on and pull requests are opened against. A **series** is one
work ref cut into slices for one target.

What a user who types `/slice` with no argument and no prior setup sees, in order. The screens
below show the layout. Line 1 of prompt 1 and the bar line carry measured figures (E5, E6);
every other number in them is illustrative.

**1. Resolution. Printed, no question.**

```
work ref   <checked-out branch> at <short sha>
remote     <remote>            (the branch's configured remote; else the only remote)
fetched    <remote> just now   (or: fetch failed, figures are against the last fetch)
tree       3 uncommitted paths are not sliced   (only when the tree is dirty)
```

The remote is asked for only when the branch has none configured and the repository has more
than one. A repository with no remote stops here with one line saying there is nothing to open
a pull request against.

**2. Prompt 1: the target.** One question, with each candidate's measured difference from the
work ref beside it:

```
Slice <work ref> for review against which branch?

  1. <remote>/<default branch>     344 commits ahead, 937 files, 79,638 added lines
  2. <remote>/<other base>         base of your open pull request #NN; 12 commits ahead, 40 files
  3. <remote>/<stale base>         needs a merge-up first: 57 commits on it are not in the work ref
  4. another branch                (type its name)
```

The candidate set is read from three places and from no declaration:

- an in-flight series file for this work ref, shown first as `continue <series>: 3 of 7 merged`;
- the remote's default branch;
- the bases of the user's own open pull requests on that remote, where they differ;
- free entry, always last.

A candidate that is not an ancestor of the work ref is shown and cannot be chosen. `/slice`
never merges; it says which merge is needed. A candidate whose difference from the work ref is
empty is shown as `nothing to slice`. The target may have the same name as the work branch
(line 1 above is this repository's own case, E6); what makes a target unusable is an empty
difference, never an equal name.

The measured difference is on every line because choosing the wrong base is an observed
failure: the operator's open 1,619-file pull request in sf1-engine was opened against a base
that is an ancestor of the intended one (E4).

**3. The bar. Printed, no question.**

```
bar        1,915 added lines / 14 files   measured: 75th percentile of 19 merged on <target>
```

or `declared in .claude-extensions.json`, or `default, unmeasured`. See "The size bar".

**4. Prompt 2: the proposal. This prompt is the product.**

```
 id  title                          files   lines / bar     depends on   opens against
 a   <title>                           9     1,204 / 1,915   -            <target>
 b   <title>                          12     1,610 / 1,915   a            <target>, after a merges
 c   <title>                           1     3,300 / 1,915   -            <target>   OVER: one unsplittable file
 d   <title>                          31       840 / 1,915   -            <target>   OVER, NO REASON: will not build

 assigned     53 of 53 changed paths      unassigned 0   in two slices 0
 not landing  826 paths under <glob>, 2 others (listed on request)
 generated    none declared; every path counts toward the bar
 cost         4 slices: 4 typed pushes, one at a time, then 1 /slice to open them

 approve / revise (say what to change) / cancel
```

The four fixed lines under the table are always printed, with zeros shown as zeros. "Revise"
takes free text ("split d by directory", "move the hook files into a", "bar 1,500 / 30",
"nothing under specs/ lands") and re-proposes. The bar itself is revisable here; see below.
Nothing is written before "approve".

**5. On approval.** The series file is written. Every slice that can be built is built, by
plumbing, without touching `HEAD`, the index or the working tree. The union is verified: the
target's tree overlaid with every slice equals the work ref's tree on every assigned path. Then,
per built slice, the one line the user types:

```
a  built  <short sha>   /please push <remote> slice/<series>/a
b  waits on a
c  built  <short sha>   /please push <remote> slice/<series>/c
d  not built: over the bar with no reason
then: /slice
```

**6. A later `/slice` while a series is in flight.** Prompt 1 offers `continue` first. Choosing
it prints one state line per slice and one question listing only what is due:

- for each slice whose remote branch equals its built commit and has no pull request: the pull
  request to open, shown as base, head and title, opened on "yes" and its URL recorded;
- for each slice whose paths at the target's tip now equal the slice's own content: marked
  merged (a content test, so a squash merge is recognised);
- for each unmerged slice whose base has moved, once the work ref contains the target again:
  rebuilt from its declaration, with the push line printed again (a plain push if it was never
  pushed; `--force-with-lease` if it was);
- if the target is not an ancestor of the work ref: one line naming the merge-up needed, and
  nothing else.

**With a description.** `/slice "the hook changes, to the release line"` steers both prompts. A
description that names exactly one candidate target answers prompt 1, which is then printed
instead of asked. A description never answers prompt 2: the proposal is always shown and always
needs "approve".

**One invocation, one target.** "Or branches as appropriate" is met in two ways and no third. A
dependent slice's pull request may be opened against its parent slice's branch (see "The
mechanism", visible stack). Work bound for a second target is a second series, started by a
second `/slice`. One series never spans two targets, because the bar, the ancestry test and the
exhaustiveness check are all facts about one target.

## The mechanism

One script, one series file, one command file.

**The series file** is `specs/.orchestration/slices/<series id>.json`, and it is the single
home of slice state:

- `target` (remote and branch), `work_ref`, and the commits of each at the last build;
- `bar`: lines, files, and source (`declared`, `measured` with n, `default`, or `chosen at
  prompt`);
- `not_landing`: path globs that are in the difference and deliberately in no slice;
- per slice: `id`, `title`, `paths` (globs), `depends_on`, `over_bar_reason`, `state`
  (`proposed`, `built`, `pushed`, `open`, `merged`), `ref`, `commit`, `base_commit`,
  `request_url`. The pull-request body is a file beside it,
  `specs/.orchestration/slices/<series id>/<slice id>.md`, drafted at approval and editable
  until the request is opened.

**The script** has three subcommands and no other entry point.

- `check`: target is an ancestor of the work ref; every path in `git diff --name-only <target>
  <work ref>` is in exactly one slice or on `not_landing`; no glob matches nothing; every
  `depends_on` names a slice and the edges have no cycle; every slice is at or under the bar or
  carries a reason. It prints the counts prompt 2 shows.
- `build`: for each slice with at most one unmerged dependency, read the base tree into a
  private index, set each of the slice's paths to its blob at the work ref (or remove it, for a
  path the work ref deletes), `write-tree`, `commit-tree`, and move
  `refs/heads/slice/<series>/<id>` by compare-and-swap. The base is the target's tip overlaid
  with the slices in the dependency closure; the parent commit is the target's tip, or the one
  unmerged dependency's commit. A slice with two or more unmerged dependencies waits until all
  but one have merged, so no slice commit ever has two parents. `build` refuses any slice
  `check` refuses.
- `status`: per slice, local ref against recorded commit, remote ref against recorded commit,
  and the merged test of step 6.

This is the one primitive all three existing builders arrived at independently (E1, E2, E3):
private index, base tree, overlay, `write-tree`, `commit-tree`, ref move. Nothing else in any
of them is needed.

**The command file** owns everything a script must not: the two prompts, the proposal, the
pull-request bodies, and the forge call. The proposal (which paths go together, in what order,
with what titles) is made by the command's model from the diff, the directory structure and,
as a hint only, completed tasks' `modified_files`. The script validates and builds what was
approved. **No inference code is written**: no union-find, no topological sort, no overlap
analysis. A bad proposal is caught by the counts in prompt 2 and by the person reading it.

**Order of opening.** The default is that a dependent slice is built and opened only after its
dependencies have merged. Under the default every slice is one commit on the target's tip, is
pushed once, and is never force-pushed. A **visible stack** (opening a dependent slice early,
against its one unmerged parent's branch) is allowed when the user asks for it in "revise". Its
cost is stated in the cost line before approval: after each parent merges, every
already-pushed dependent is rebuilt on the new base and needs one further typed
`--force-with-lease` push.

**Re-derive, never rebase.** A slice is always rebuilt from its declaration against the current
base. There is no restack operation, no three-way merge of slice commits and no conflict
resolution inside `/slice`. Conflicts are resolved once, by the ordinary merge of the target
into the work branch, which `/slice` waits for and does not perform.

## Basis

**Neither existing builder is promoted, and no existing code is the basis.** The task
description's hypothesis, "promote B upstream and delete A", is half right.

- **Builder A is deleted.** It has no caller (E1), its required declaration exists nowhere (E6),
  no stack it cut exists anywhere (E6), and 61 passing cases test machinery (union-find,
  components, topological order, moved-base `merge-tree`, restack) whose only purpose is to
  recover review units from history that did not record them. A declared path set needs none of
  it. Its overlay function is 35 lines; that is the part worth having, and it is cheaper to
  write again inside a 400 to 600 line script (an estimate, not a measurement) than to carve
  out of 1,572.
- **Builder B is not promoted.** The evidence that was to justify promoting it does not exist:
  it has opened no pull request (E4, E9). As code, 993 of its 2,187 lines are one repository's
  diagnostics gate and report template, its base is a literal, its configuration is read out of
  prose by `grep`, and it changed four times on the day it was read (E2).
- **Builder C is not promoted.** It refuses to write a branch, so nothing it cuts can be pushed
  as a pull-request head (E3), and its manifest pins every file to a blob at a named commit by
  hand.

What is carried upstream from B is design, not code:

1. A slice is a **path set cut from the work-ref tip**. A file is in exactly one slice.
2. **Exhaustiveness**: every changed path is in exactly one slice or on a not-landing list.
3. **A size check that can refuse.**
4. **The ancestry refusal**: no build unless the target is an ancestor of the work ref.
5. **Re-derive, never rebase.**
6. **Dependency-scoped bases**: an independent slice is based on the target alone, so
   independent slices can be opened and merged in any order.

Carried from A: compare-and-swap ref moves, and the static rule its suite enforces that the
script contains no push, checkout, merge or forge invocation. Carried from C: nothing as
mechanism; its `verify` idea (a slice should stand alone) is named under "Risks" as unbuilt.

The consumer-repository builders are not deleted by this repository. Each consumer retires its
own once `/slice` is deployed there. sf1-engine's check 4 is a per-repository gate, and what it
needs from upstream is at most a declared per-slice self-check command, which is named as a
possible later successor and is not part of this ruling.

## Review base

**There is no review base.** Two roles exist, the work ref and the target, and no third branch
stands between them.

The slices record's S3 and the sf1-engine record's RP1 were framed as contradicting each
other. They contradict less than that, and each is partly wrong.

- RP1 rejects "a review base cut from `main`": an intermediate branch between the work branch
  and the branch the owner merges into (E2). That rejection stands. Such a branch costs a
  second merge only the remote owner can perform and protects nothing, since the target
  already contains everything a slice is based on.
- S3 defines `review_base` as "the branch slices target". In RP1's own repository that is
  `main`, which RP1 uses. So S3's *role* exists in both records; what S3 adds is a required
  **declaration** and a **refusal**, and both are wrong.
- The declaration is wrong because nobody has made it (E6), it has no safe default, and the
  right value is not a per-repository fact: sapience-app's pull requests use six different
  bases (E4). A user with no prior setup must see a prompt, not exit 10.
- The refusal is wrong because it compares names (E1, lines 243 to 245). This repository works
  on `master` and is 344 commits ahead of `origin/master` (E6). S3 says such a repository "is
  refused and gets no slices". It should get slices. The condition S3 was reaching for is an
  empty difference between work ref and target, and that is what `/slice` tests.
- RP1 is wrong where it makes the target a literal (E2, line 169). The target is a
  per-invocation fact, and choosing it badly is an observed failure (E4).

Therefore: the `review_base` key, `--review-base`, the four `review_base_*` refusals (exits 10
to 13) and the documentation section that defines the key are removed. `integration_branch`
keeps the meaning the landing record gives it, the branch orchestrated work is committed on,
and `/slice` does not read it: the work ref is whatever is checked out.

## The size bar

**The bar is approved, then enforced.**

- **It is a refusal.** `build` does not build a slice over the bar unless its row carries a
  reason. Two reasons are accepted and both are recorded in the series file and printed in the
  pull-request body: a single file that cannot be divided, and a declared generated or
  mechanical tree landing alone. An advisory would not do: size is the one failure the evidence
  shows (E4), and an advisory is what the builders that produced no merged work already have
  (E3, `size_report`).
- **Where the number comes from, in order.** (1) A declared `slice_bar` object, `{lines,
  files}`, in `.claude-extensions.json`. (2) Otherwise the 75th percentile, nearest-rank, of
  added lines and of changed files over merged pull requests on the chosen target, when there
  are at least five. (3) Otherwise a shipped default of 1,500 lines and 30 files, printed as
  `default, unmeasured`.
- **The user approves it.** The bar and its source are printed before the proposal, and
  "revise" can replace it; a replaced bar is recorded as `chosen at prompt`. This is required
  by E5, not a convenience. A measured bar is only as good as its population: in this
  repository the measurement is 52 lines and 1 file, drawn from small outside contributions,
  and would refuse every slice of the operator's own work. In sf1-engine it is drawn almost
  entirely from the owner's self-merged work. The measurement is the best available opening
  offer; it is not a fact about what a reviewer will read.
- **What is counted.** Added lines over the slice's paths (`git diff --numstat <target> <work
  ref> -- <paths>`, first column), and the number of paths. Paths declared generated are
  excluded from the line count and still listed. The declaration of generated paths is owned
  by `branch_aware_orchestration_and_squash_landing` (655); until it exists every path counts
  and prompt 2 says so.

**Portability.** The method is portable. The numbers are not. The same measurement gives 1,915
lines and 14 files in sf1-engine, 763 and 7 in sapience-app, and 52 and 1 here (E5). A bar
copied from one repository into another is wrong in both directions, which is why the shipped
default is labelled unmeasured wherever it is used and why no number appears in any deliverable
as a property of the system.

**Rejected: the median.** It is the more cautious number and it is the wrong one: by
construction it refuses half of what has already merged on that target.

**Not verified.** No proposed cut of any repository's real difference has been run against a
bar by `/slice`, because `/slice` does not exist. sf1-engine's own table passes its own
1,500-line ceiling by its own check 3 (CARRIED-UNVERIFIED from that record, line 173; not
re-run here). Whether the 75th percentile is the right opening offer is a preference the
operator can change at no cost before the successor that builds the measurement runs.

## One survivor, and what is deleted

Paths are relative to `agent-system/extensions/core/` unless stated.

| # | Path | Disposition |
|---|---|---|
| new | `commands/slice.md`, one script with `check`, `build`, `status`, and its suite | **The one survivor.** Built by the first successor |
| 1 | `scripts/milestone-ref-land.sh` | **Deleted.** Already owned by `milestone_ref_land_recreates_retired_ref` (690) |
| 1 | `scripts/tests/test-milestone-ref-land.sh`, with its `suite-classification.data` and `manifest.json` rows | **Deleted**, by the same record |
| 2 | `scripts/review-stack-prepare.sh` | **Deleted**, all four subcommands |
| 2 | `scripts/tests/test-review-stack-prepare.sh`, with its `suite-classification.data` and `manifest.json` rows | **Deleted** |
| 2 | `context/standards/repo-level-declarations.md`, the section "The `review_base` Declaration" | **Deleted** (the section, not the file) |
| 2 | `context/standards/orchestrator-runtime-files.md`, its row for the review-stack manifest (line 69) | **Deleted** (the row, not the file) |
| 3 | `scripts/milestone-review-handoff.sh` | **Kept, narrowed.** It still detects a finished milestone once and drafts the summary. It prints one line, `/slice`, and no push or merge line. It stops writing `review.ref`; `review.state` stays as its own fired-once marker and means nothing about slices |
| 4 | `commands/merge.md` | **Deleted.** See below |
| 4 | `skills/skill-git-workflow/SKILL.md`, its `/merge` mention; the `/merge` minting branch of `hooks/please-grant.sh`; `/merge` named in `rules/pr-prohibition.md`, `rules/state-management.md`, `merge-sources/claudemd.md`, `templates/claudemd-header.md` and the other files of E7's 27 | **Rewritten** to name `/slice`, by the `/merge` removal successor |
| 4 | `/merge --stack` (planned by `merge_command_stack_mode`, 693) | **Never built** |
| 5 | `extensions/cslib/commands/pr.md` | **Outside this ruling; not changed.** It is another extension's command for one upstream project: it starts new work on a branch cut from that upstream and runs that project's CI. It does not move a work branch's changes into slices. It is named here so that it is known to exist; whether it should sit on `/slice`'s `build` is a question for that extension |
| 6 | sf1-engine `integration/tools/build-pr-slices.sh` | **Not this repository's to delete.** Retired by its own repository after `/slice` is deployed there |
| 7 | sapience-app `scripts/stack_cut.py` | **Not this repository's to delete.** Same |

**Files deleted from the source store**, as a list: `scripts/review-stack-prepare.sh`;
`scripts/tests/test-review-stack-prepare.sh`; `scripts/milestone-ref-land.sh`;
`scripts/tests/test-milestone-ref-land.sh`; `commands/merge.md`. Sections deleted: "The
`review_base` Declaration" in `context/standards/repo-level-declarations.md` (lines 331 to
367), and the review-stack manifest row of `context/standards/orchestrator-runtime-files.md`.
The five files are 3,805 lines (1,572 + 1,136 + 244 + 368 + 485; `wc -l`).

**`/merge` is removed, not fixed.** Its defects are that it acts on the checked-out branch,
refuses on the default branch, and hardcodes the remote (E7). Fixing all three means giving it
an explicit head, an explicit base and a resolved remote, and a command with those three is
`/slice`'s open step. Two commands that open pull requests are two methods, and every record
that has routed around `/merge` (the handoff suppressing its printed line, the sf1-engine
record's "`/merge` is not used for a slice") is evidence of what a second method costs. The
single-branch case is `/slice` with a one-slice proposal: one prompt more than `/merge` asks
today, and a size figure `/merge` never showed. `/merge` is removed after `/slice` has opened
one real pull request, not before.

## Grants

Stated, not designed around.

- **The cost today.** N slices cost N typed `/please push <remote> slice/<series>/<id>` lines,
  then one `/slice` to open them. Only one grant is live at a time (E7), so the pushes are
  typed and performed one at a time, never queued. Under the default order of opening a
  dependent slice costs its push later, after its parent merges; a visible stack costs one
  further typed `--force-with-lease` push per pushed dependent per parent merge.
- **The window.** Each grant lives 600 seconds and is matched against `HEAD` at the moment of
  the push (E7).
- **Two consequences of the `HEAD` binding for a ref built by plumbing.** `HEAD` is not the
  commit being pushed. So (a) any commit by any session inside the window kills the grant
  although the slice is untouched, which in a repository with live orchestration will happen
  routinely; and (b) the grant does not pin what is pushed, because the slice ref can be
  rebuilt between the typed line and the push without the match noticing.

Three pieces of separate work would lower this cost. **This design assumes none of them** and
is complete without them.

1. Bind a grant for a ref other than the checked-out branch to that ref's commit instead of to
   `HEAD`. This removes both consequences above and is the one recommended first.
2. Let a typed `/slice push <id>` mint for exactly that slice ref, as a typed `/merge` mints
   today (E7). Still N typed lines; no separate `/please`.
3. A batch grant: one typed approval for N refs. This changes the consent model and is not
   recommended ahead of the other two.

## Constraints held

- **`rules/pr-prohibition.md` binds unamended in substance.** No agent-reachable path pushes or
  opens a pull request. Every push is behind a typed grant. The forge call is in a user-invoked
  command file and nowhere else; the script contains no push and no forge invocation and its
  suite asserts that statically. The rule's text names `/merge`; the removal successor changes
  that name to `/slice` and changes nothing else in it.
- **Repo-agnostic.** No branch name, remote name or consumer path appears in any deliverable
  under `agent-system/**`. The target, the remote and the bar are resolved or chosen at run
  time. Consumer repositories appear in this record as evidence only.
- **The commit-containment cluster is not edited and is not depended on.** A slice is read from
  the work ref's committed tree, not from any task's commits, so it is correct whether or not
  commits were scoped correctly. The one edge is soft: `modified_files` is a grouping hint for
  the proposal, and a wrong hint gives a worse proposal that prompt 2 shows, never a wrong tree.

## Rejected alternatives

- **Promote the sf1-engine builder.** It would bring a table grammar parsed out of markdown, a
  literal base and a thousand lines of one repository's gate into a repo-agnostic system, on
  the strength of production evidence that turned out to belong to someone else's hand-made
  branches.
- **Finish the inference route.** Inference recovers review units from history that did not
  record them. Its floor is structural: where two writers touched one path the units cannot be
  separated, and a person must decide anyway. Asking that person first is cheaper and needs no
  code.
- **Fix `/merge`.** See above: the fixed command is `/slice`'s open step.
- **A declared `review_base`.** A declaration is right for a fact that is stable per
  repository. The target is not one, and a required key with no default turns first use into a
  refusal.
- **Slices as task records.** A slice's content already exists on the work ref. Researching,
  planning and implementing a subset of paths that are already written is a lifecycle with no
  work in it, costs a dispatch per slice, and makes a slice's commit a working-tree commit,
  which needs either a branch switch in the primary tree or a second working tree. Both are
  ruled out by records that stand.
- **A fixed portable bar.** One number for every repository is wrong by more than thirtyfold
  across the three measured here (E5).
- **Hunk-level cutting.** A file that must be divided between two slices cannot be. It lands
  whole in the earlier slice. No builder has it, no case has been met, and it is not built
  until one is.
- **Asking nothing and using the default branch.** It is what `/merge` does and what produced
  a 1,619-file pull request against the wrong base.

## Verdict on each open record

Status and edges are as read from `specs/state.json` at `fbdccb9dd`. Each row has exactly one
disposition. Nothing in this table was applied by this record; see "Operator worklist".

| Record | Status read | Verdict | Reason, and for "revised" what changes |
|---|---|---|---|
| `handoff_prints_review_stack` (692) | planned; depends on 695 | **Survives revised** | The handoff prints `/slice`, not a stack and not `/please` or `/merge` lines. It stops writing `review.ref`. Its existing plan, written to print a stack cut by `review-stack-prepare.sh`, is replaced |
| `merge_command_stack_mode` (693) | planned; depends on 695 | **Abandon** | `/merge` is removed and `--stack` is never built. Nothing of its deliverable survives |
| `stack_pr_redeploy_and_second_repo_demo` (694) | not started; depends on 691, 692, 693, 695 | **Survives revised** | It becomes doc parity, redeploy and the operator runbook for `/slice`. Its acceptance becomes one real slice pushed and opened by the operator in a second repository. Its edges onto 692 and 693 are replaced by an edge onto the `/slice` build successor; 691 is completed |
| `milestone_ref_land_recreates_retired_ref` (690) | not started; depends on 692 | **Survives unchanged** | The deletion it owns is confirmed: the script has no lifecycle caller (E8) |
| `branch_aware_orchestration_and_squash_landing` (655) | not started; depends on 513, 517, 553, 654, 657 | **Survives revised** | Its generated-path declaration gains a second consumer, the bar's line count. Its description is re-grounded on that, since the ground it was last given (S4 of the slices record) is overturned here |
| `two_root_contract_dispatch_and_commit_scripts` (670) | hold | **Abandon** | See below |
| `two_root_contract_in_hooks` (671) | hold | **Abandon** | See below |
| `two_root_classification_of_remaining_consumers` (672) | hold | **Abandon** | See below |
| `batch_worktree_cleanup_retention_orphan_report` (674) | hold | **Abandon** | See below |
| `batch_worktree_creation_when_isolation_on` (686) | hold | **Abandon** | See below |
| `redeploy_phase_declaration_and_gate_criterion` (509) | not started; not on the task's list | **Unaffected** | One obligation the slices record laid on it lapses; see "The lapsed obligation" |

`stack_pr_submission_from_integration_branch` (685) is `expanded` and
`restack_review_stack_when_parent_merges` (691) is `completed`; both are terminal and get no
verdict. What 691 built is the restack subcommand of `review-stack-prepare.sh`, which this
record deletes with the rest of that script.

### The five held records: declared slices make isolation irrelevant to review

The question the task asked is whether declared slices make isolation attractive, irrelevant or
abandonable. Each held record's own hold reason asks it in the same terms: "first answer
whether a slice task needs an isolated tree at all ... If the answer is no, this record may be
abandonable rather than resumable" (`specs/state.json`, 670 and 686, re-judged 2026-11-23).

The answer is no, on three readings.

1. **A slice needs no working tree.** Under this record a slice is not a task and is not
   committed from a tree. It is built by a private index and `commit-tree` with `HEAD`, the
   index and the working tree untouched ("The mechanism"). The hold reasons' premise, that "a
   slice task is a natural fit for its own worktree", rested on S4 and S6 of the slices record,
   which are overturned.
2. **The one thing isolation was built to deliver is no longer wanted.**
   `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` opens by stating its
   purpose: it "reinstates working-tree isolation at one granularity only ... and rules how a
   task's work lands on the long-lived integration branch as one squash commit" (lines 3 to 7).
   Its isolation-off section states the whole price of not having it: "**What it loses.** The
   per-task squash. Nothing else." (line 353). The sf1-engine record says the same from the
   consumer's side: "a forward milestone becomes a clean commit range. That is the real loss of
   `off`" (E2). A path set cut from the work-ref tip does not read a commit range and does not
   need one commit per task. The loss is no longer a loss.
3. **Nothing else argues for it.** The landing record states that isolation off "is the only
   path being built" by operator direction (its lines 3 to 5).
   `specs/decisions/worktree-isolation-removal-verdict.md` ("The Verdict", lines 17 to 30) and
   its reaffirmation already rule against per-dispatch isolation on concurrency grounds, and
   the batch record does not withdraw them (its "R5, amended"). Any future case for isolation
   has to be made on dispatch concurrency alone, against those two records, and is not a case
   about review.

So the five are abandonable. The fallback, if the operator prefers not to abandon, is that they
stay held with their hold reason rewritten to say that review no longer bears on them; nothing
in this ruling depends on which is chosen. The declared `worktree_isolation` key and its
reader are not ruled on here: they are built and belong to the completed
`integration_branch_admission_and_batch_worktree` (669).

### The lapsed obligation

The slices record, under "Obligations on the implementing plan", required a plan to "site the
redeploy once per batch at the close rather than once per slice", and named 509 as the owner of
the gate criterion. The obligation existed only because S6 made each slice a task with its own
redeploy phase. A slice is no longer a task, so no slice declares a redeploy and the obligation
lapses. 509's own subject, the redeploy declaration and gate criterion for ordinary tasks, is
untouched.

## Successors

Each is a separate piece of work, proposed as a task record that the operator creates. None is
created by this record. Territory is relative to `agent-system/extensions/core/`.

| # | Successor | Territory | Ordered after |
|---|---|---|---|
| 1 | **`/slice` build.** The script (`check`, `build`, `status`), the series file, the command with both prompts, the open step, the suite | new `commands/slice.md`, one new script and suite, `manifest.json`, `suite-classification.data` | nothing |
| 2 | **Bar measurement and the `slice_bar` declaration** | the script; `context/standards/repo-level-declarations.md` | 1. The line count is wrong in any repository with generated files until 655's declaration exists: a hard edge from the *accuracy* of the bar onto 655, not from its existence |
| 3 | **Delete the inference route**: `review-stack-prepare.sh`, its suite, the `review_base` section, the review-manifest row | the files of "One survivor, and what is deleted", rows 2 | nothing; it has no caller. Independent of 1 |
| 4 | **Narrow the handoff** (692, revised) | `scripts/milestone-review-handoff.sh`, its suite, `context/contracts/conclusion-stage.md` | 1, so the line it prints names a command that exists |
| 5 | **Remove `/merge`** and rewrite its references, including the `merge` minting branch and the rule text that names it | `commands/merge.md`, `hooks/please-grant.sh`, and the other files of E7's 27 | 1, and only after `/slice` has opened one real pull request |
| 6 | **Bind a grant to the pushed ref** ("Grants", item 1) | `hooks/please-grant.sh`, `hooks/guard-git-push.sh`, `scripts/lib/push-grant-lib.sh` | nothing; independent. Shares `hooks/please-grant.sh` with 5 and is sequenced against it |

Doc parity, redeploy and the runbook are 694, revised, after 1, 4 and 5.

**The acceptance bar for successor 1** is not a suite count. It ends with one real slice of a
real difference, pushed by a typed grant and opened as a pull request by the operator typing
`/slice`. Two builders with green suites and no pull request are what this record deletes.

## Operator worklist

Nothing below was run by this record's author. Each line is what the operator runs to apply a
verdict.

| Verdict | Command |
|---|---|
| Abandon 693 | `/task --abandon 693` |
| Abandon the five held records | `/task --abandon 670,671,672,674,686` (or leave held and rewrite the hold reason) |
| Revise 692 | `/revise 692`, with this record named as the ruling; its plan is rewritten to successor 4 |
| Revise 694 | `/revise 694`; then replace its edges onto 692 and 693 with one onto successor 1's record. `update-task-status.sh` carries `--depends-on-add`; no edge-removal flag was found in it, so the removal is by whatever means the operator already uses |
| Revise 655 | `/revise 655`, re-grounding its description on the bar's line count |
| 690 | nothing; it proceeds as written. Its edge onto 692 still holds, since both touch the handoff's suite |
| Create successors 1, 2, 3, 5, 6 | `/task "<description>"` for each, citing this record by section; 4 is 692 revised |
| Two dispatches in flight | 692 and 693 are `planned` against the overturned ruling and depend on 695. Their plans must not be implemented as written |

## What is discarded

Built, and now to be deleted:

- `review-stack-prepare.sh`, 1,572 lines, and its 61-case suite, 1,136 lines: unit inference by
  union-find, component building, topological ordering with a contradiction refusal, the
  moved-base `merge-tree` recompute, the stack manifest, `show`, `record-request`, and
  `restack` (the element `restack_review_stack_when_parent_merges` completed).
- The `review_base` declaration: the key, its documentation section, `--review-base`, and four
  refusals.
- `/merge`, 485 lines, and its grant-minting branch.
- `milestone-ref-land.sh` and its suite (already retired; its deletion is confirmed).
- The handoff's printed `/please push` and `/merge` lines and its `review.ref` write.

Planned, and now not to be built:

- `/merge --stack` (693).
- The stack-printing handoff as planned (692's current plan).
- A second-repository demonstration of the inference route (694 as written).
- The five held worktree and two-root records.

Ruled, and now overturned:

- Slices as task records (S6), slices landed by a scoped commit from a working tree (S4), the
  declared and refused review base (S3), restack by forge base edit (S5 in part), and the
  retention list of the slices record.

## Risks

- **This design has no production evidence either.** Like the three builders it replaces, it
  has opened no pull request. The mitigation is the acceptance bar above, and the order: `/merge` is not removed
  until `/slice` has opened a pull request.
- **Whole-file granularity.** A file that belongs to two slices lands whole in the earlier one.
  If that proves common the proposal will show it as slices that cannot be separated, and
  hunk-level cutting is then a case with evidence instead of a guess.
- **A slice may not stand alone.** The union check proves that all slices together reproduce
  the work ref. It does not prove that slice `b` builds or passes without slice `c`. Nothing in
  this design checks that. Prompt 2 and every pull-request body say that no per-slice check
  ran, until a declared self-check command exists (materialised from `git archive` of the slice
  commit, which registers no worktree).
- **Proposal quality rests on a model.** The checks are mechanical and the approver sees the
  counts, but a proposal can be exhaustive, under the bar and still badly drawn. Only the
  approver catches that.
- **The measured bar can be the wrong population** (E5). The mitigation is that the bar is
  printed with its source and count and is approved, not assumed.
- **Grants die under live orchestration** ("Grants"). Until successor 6, pushing N slices in a
  repository with a running orchestration may take more than N typed lines.
- **A merge-up is a precondition `/slice` does not perform.** After each merge on the target
  the work branch must merge it before any rebuild. In a repository that declares
  `integration_branch`, that merge is an ordinary commit on the work branch and is the
  operator's or an ordinary task's to make.

## Assertions amended

### In `specs/decisions/review-slices-are-declared-tasks.md`

| Part | Assertion | Now |
|---|---|---|
| S1 | The reviewable unit is declared before the work; "A review slice is a task record" | **Outcome stands, ground and form change.** A slice is declared and approved by a person before it is built, and no boundary is inferred. It is declared after the work and before the review, as a row in a series file, not as a task record |
| S2 | A slice is not the task that did the work; a slice containing both writers of a shared path is clean by construction | **Stands**, on a simpler ground: a file is in exactly one slice, so which task wrote which line is never presented and the `shared_paths` floor has nothing to act on |
| S3 | `review_base` is a declared key; a repository whose `review_base` equals its `integration_branch` is refused | **Overturned.** No key, no refusal by name. The target is chosen at the prompt; an empty difference is the only unusable target ("Review base") |
| S4 | A slice lands by an ordinary scoped commit from a working tree; "nothing is overlaid blob by blob" | **Overturned.** A slice is built by overlay in a private index. The measurement S4 quotes ("the only landing that worked was an ordinary scoped commit") is about landing uncommitted work onto a side ref while the primary tree stays dirty (landing record, option A). A slice is cut from a committed tip and leaves `HEAD`, index and tree untouched, so that objection does not reach it; the landing record's own interface section measured the overlay as working |
| S5 | Slice `N+1` branches from slice `N`; order is `dependencies[]` edges between slice tasks; a merged parent changes the child's base by a forge base edit | **Overturned in part.** Stacking by declared dependency stands. A slice's base is the target plus only the slices it names, so independent slices are not chained. Order is the `depends_on` field of the series file. After a parent merges, the child is rebuilt from its declaration; no forge base edit |
| S6 | Approval creates one task per slice; slices are researched, planned, implemented and verified as ordinary tasks | **Overturned.** A slice is not a task ("Rejected alternatives") |
| S7 | Every push behind a typed `/please`, every forge call inside the user-invoked `/merge`, `rules/pr-prohibition.md` unamended | **Stands**, with `/slice` as the user-invoked command in place of `/merge` |
| "What is retained from the inference route" | The resolvers, the manifest, `show`, `record-request` and `restack` are retained and still wired | **Overturned.** Nothing of `review-stack-prepare.sh` is retained |
| "Why not abandon the inference route entirely" | "A stack already cut by `cut` exists and its manifest is on disk" | **Overturned; the premise is false.** No manifest, no review ref and no `review_base` declaration exists in any of four repositories checked (E6) |
| "Obligations on the implementing plan", redeploy declaration | Site the redeploy once per batch, not once per slice | **Lapses** with S6 |
| "Obligations", grant count | State the count; do not design around it | **Stands**; restated under "Grants" with the one-live-grant fact added |
| "Obligations", slice proposal quality | The proposal shows each slice's contents, order and shared paths | **Stands and is made concrete** as prompt 2. "Paths shared with another slice" becomes the `in two slices` count, which must be zero |
| "What this does not deliver", last paragraph | Whether declared slices make isolation attractive again is open work | **Closed**: irrelevant to review; the five held records are abandonable |

### In `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`

Each row reads as it stands after both this record and the slices record.

| Part | Assertion | Now |
|---|---|---|
| L3 | The reviewable unit of a task is its attributed commit set | The reviewable unit is a slice: a declared path set cut from the work-ref tip. A task's attributed commit set remains the unit of landing verification and is not read to build a slice |
| L4 | One commit per task is produced at review time, on a review ref, by plumbing | One commit per **slice** is produced at review time, on a slice branch, by plumbing. "By plumbing" stands as L4 wrote it; "per task" does not |
| Interface, "The ref it reads" | The integration branch named in the batch record | The checked-out work ref, at its tip |
| Interface, "The range" and "Whether it is one commit per task" | One landing proof per task | No proof is read. A completed task's `modified_files` is a grouping hint for the proposal and nothing more |
| Interface, "How one commit per task is built" | The blob overlay, with tree equality as the check | The same overlay and the same check, applied to declared path sets taken at the tip |
| Interface, "The stated limit" | Per entangled task the review step chooses between accepting, naming or merging | Does not arise: a file is in exactly one slice |
| Interface, "Tasks with no proof" | Attribution by V2 is the fallback | Not needed; nothing is attributed |

L1, L2, L5, the landing predicate V1 to V5, the landing proof and the retirement order are not
amended. L5's retirement is completed by the deletion ruled here.

### In the stack-PR design record

Its rulings PD1 to PD12 describe `review-stack-prepare.sh`. With that script deleted they have
no subject. PD1's `review_base` refusal, as implemented at the script's lines 217 to 247, is
overturned by "Review base". The record itself was not read for this ruling; the slices
record's own table lists PD3, PD5, PD6 and PD7 as amended and the rest as not, and that table
is superseded by the deletion.
