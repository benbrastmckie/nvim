# Research Report: Task #685

**Task**: 685 - Cut review branches and submit a stack of PRs from landed integration-branch work
**Started**: 2026-11-23T14:58:22Z
**Completed**: 2026-11-23T15:06:00Z
**Effort**: about 0.5 hours of research; implementation estimated at 6 to 9 hours
**Dependencies**: 673 (completed)
**Sources/Inputs**: source store under `agent-system/extensions/core/` and `agent-system/extensions/cslib/`; `specs/decisions/`; task 673's summary; the live batch record; a scratch fixture repository; GitHub and GitLab documentation (web)
**Artifacts**: specs/685_stack_pr_submission_from_integration_branch/reports/01_stack-pr-submission.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The contract the landing task owes exists and answers all three owed items. It is in
  `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`, "Interface to
  review submission". No blocker on that count.
- One premise of the task description does not survive that contract. Item 2 says the bottom PR
  targets the integration branch. The work is already on that branch, and in a fixture a review
  branch cut from the batch's cut point conflicted when merged into it. The bottom PR needs a
  base that does not yet hold the work. This is raised as a non-blocking user decision; the
  recommendation is a declared review base distinct from the integration branch.
- A three-branch stack was cut in a fixture by plumbing alone, with `HEAD`, the index and the
  working tree unchanged. Restacking after a squash-merged parent also works by plumbing
  (`git merge-tree --write-tree --merge-base`), so `git rebase` is not needed.
- The cslib `/pr` command should not be extracted. It is 2,406 lines of prose executed by a
  model, it creates branches by `git checkout -b`, and its base resolution calls the forge. Core
  needs a small scripted implementation; two idioms carry over.
- `/merge` cannot submit a stack as it stands. It acts on the checked-out branch, refuses on
  `main` and `master`, and hardcodes `origin` and `main`. It needs a mode that names the head
  branch and the base and does not push.
- A stack of N PRs costs N `/please` grants plus one `/merge` invocation per PR, or one `/merge`
  for the whole stack if that mode is built. The grant count cannot be reduced without editing
  the mint hook, which is out of scope.

## Context & Scope

Researched: the landing contract, the review handoff script, `/merge`, `/please` and the push
guard, the cslib `/pr` command, forge behaviour when a parent PR merges, and the plumbing needed
to cut and restack review branches. Seven numbered items of the task description are each ruled
on under Decisions.

Not researched: worktree isolation (held), the landing mechanism (ruled by 673), and the consent
boundary (unchanged). No push and no forge write was made. The only forge contact was reading
public documentation.

Constraint carried through every finding: an agent never pushes and never creates a PR. The
verification criterion goes further, "no agent having pushed or called a forge API", which also
excludes read calls such as `gh pr list` from anything an agent runs.

## Findings

### The landing contract (read, not re-derived)

From the decision record, "Interface to review submission":

| Owed item | What the contract says |
|---|---|
| Ref to branch from | The integration branch named in the batch record. Never rewritten. |
| Commit range | Not a range per task. Per task, a landing proof: commit list, `end_commit`, path set. Per batch, `integration_tip_at_cut` to the highest `tip_at_verification`. |
| One commit per task? | No. One proof per task. One commit per task is built at review time by blob overlay. |

It also states the limit (`shared_paths` tasks cannot be separated by path) and the fallback for
a task with no proof (attribution by commit subject, bounded below by the task's `created`
time). The proof shape is documented in
`agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`, "The batch
record".

Live state: one batch record exists, `specs/.orchestration/batch/sess_1795425897_6a25f2.json`,
with `integration_branch: "master"` and one landing proof (task 673: 13 commits, 17 paths, empty
`shared_paths`). Batch records are gitignored and machine-local. Neither this repository nor any
of the nine sibling repositories checked under `~/Projects` and `~/.dotfiles` declares
`integration_branch`.

Consequence for verification: a real stack of three dependent tasks cannot be built from proofs
in this repository today, because only one task has a proof. The fallback path or a fixture is
what the three-PR criterion will run on at first.

### What the contract leaves open: what the bottom PR merges into

The record calls the review ref "the thing merged" and does not say into what. The task
description says the integration branch. Measured in the fixture (E3):

- A review branch for task 1, cut from the batch's cut point, merged into the integration
  branch: `git merge-tree --write-tree` exited 1, content conflict in a file task 2 edited
  later.
- The top of the full stack merged cleanly, and the result equalled the integration branch's
  own tree. It merges only as a no-op.
- Overlaying a task directly on the integration tip produced a negative diff: it removed the
  later task's line from the shared file.

So a PR into the integration branch is reviewable (the three-dot diff shows the task's files)
and not mergeable. Either the bottom PR targets a different branch, or these PRs are review-only
and are closed, never merged.

### Cutting the stack by plumbing (E1)

Fixture: `main`, an integration branch `integ` with three tasks' phase commits interleaved, a
bookkeeping commit, and a state file touched by every commit. Task 2 also edits a file task 1
owns.

For each task in landing order: read the parent's tree into a temporary index
(`GIT_INDEX_FILE`), set each path of the task's set to its blob at the task's end commit
(`git update-index --cacheinfo`, or `--force-remove` for a deleted path), `git write-tree`,
`git commit-tree -p <parent>`, then `git update-ref refs/heads/<branch> <new> ""`.

Result: three branches, one commit each, each parented on the one below. Task 2's commit showed
its own file plus its one line in task 1's file. The top of the stack differed from the
integration tip only under `specs/`. `HEAD`, `.git/index` and `git status` were byte-identical
before and after, and the checked-out branch did not change.

### Ordering (E2)

- Path-disjoint tasks commute. Placing task 3 first instead of last gave an identical final
  tree.
- Path-overlapping tasks do not. With task 2 placed before task 1, task 2's commit carried all of
  task 1's lines in the shared file, and task 1's commit then removed task 2's line. The overlay
  is only correct in landing order for tasks that share a path.

### Restacking after a parent merges (E4, E5)

The bottom PR was squash-merged into `main` (simulated with `git commit-tree`). Before any
restack, `main..review/t2` held two commits and the three-dot diff listed task 1's files again:
a stale stack.

| Method | Result | Touches working tree |
|---|---|---|
| Rebuild by overlay on the new base | Trees equal to the old stack's | No |
| `git merge-tree --write-tree --merge-base=<old parent> <new base> <child>` then `git commit-tree` | Exit 0, tree equal to the rebuild | No |
| `git replay --onto <new base> <old parent>..<child>` | Worked and moved the refs itself | No, but marked EXPERIMENTAL in git 2.54, and its default of updating refs directly differs from earlier releases |
| `git rebase --onto` | Not run | Yes: it checks the branch out, which the branch-topology ruling forbids in the primary tree |

The two plumbing methods differ when the mainline has moved independently (E5). A foreign commit
on `main` edited a file task 2 owns. The overlay replaced the file with task 2's blob and lost
the foreign line. The three-way `merge-tree` kept the foreign line and both of task 2's lines.
The overlay is exact only on a base that is an ancestor of the integration branch.

### The consent machinery as it bears on a stack

- `hooks/please-grant.sh` mints one grant per human-typed prompt, revokes any earlier grant
  first, and binds it to the remote, the ref, the force mode and the SHA of `HEAD` at mint time.
  It expires after 600 seconds.
- A review branch name with a slash is accepted by the `/please push <remote> <branch>` grammar.
- The grant is bound to `HEAD`, not to the pushed ref. Review branches are built without moving
  `HEAD`, so the grant holds. A concurrent session committing to the integration branch inside
  the window moves `HEAD` and kills the grant.
- `--force-with-lease` is mintable on any branch other than the remote's default branch. Where
  the default branch cannot be determined (no `refs/remotes/<remote>/HEAD` and no
  `init.defaultBranch`), every force form is refused. A restack push in such a repository fails
  until `git remote set-head <remote> -a` has been run.
- For `/merge` the hook mints a grant for the remote `origin` and the checked-out branch, with
  no parsing of arguments.
- `hooks/guard-git-push.sh` blocks every ungranted `git push`. Nothing in `hooks/` or `scripts/`
  mentions `gh pr create` or `glab mr create` (one grep over both directories): PR creation is
  barred by `rules/pr-prohibition.md` only, not mechanically.

### `/merge` as it stands

`commands/merge.md` takes the head from `git branch --show-current`, refuses on `main` or
`master`, pushes `HEAD` to `origin`, and defaults the target to `main`. The handoff script today
prints `/please push <integration branch>` followed by `/merge`. In this repository the
integration branch is `master`, so the printed `/merge` refuses. On a feature integration branch
it opens one PR for the whole branch.

### The cslib `/pr` command

`agent-system/extensions/cslib/commands/pr.md`, 2,406 lines.

| Part | Portable? | Why |
|---|---|---|
| Workflow selection (new, stacked, update, amend) | Idea only | Flag parsing in prose; nothing to import |
| Base resolution for `--stacked` | No | `gh pr view --json headRefName`: a forge call, and only needed because the parent's branch name is not known locally |
| Parent auto-detection | No | `gh pr list --author benbrastmckie --repo leanprover/cslib`, with a hardcoded absolute path to the checkout |
| Branch creation | No | `git checkout upstream/main -b` and `git checkout origin/<head> -b`: moves the working tree |
| Branch naming `feat/<slug>` | Idea only | A cslib contribution convention |
| CI pipeline | No | Seven `lake` steps |
| PR body format | Partly | "Summary", "Relationship to Other PRs" and "Changed Files" are generic; the rest is Lean-specific |

Two idioms carry over: `gh pr create --base <parent head branch>` as the whole of stacking on
the forge side, and a "Relationship to Other PRs" section in each body. A stack that records its
own branch names locally needs no PR number to resolve a base, which removes the forge read that
cslib's resolution depends on.

### Forge behaviour when a parent merges (documentation, not tested here)

- GitHub: since 2020, deleting a merged PR's head branch retargets open PRs based on it to the
  merged PR's base. Stacked pull requests became generally available on 2026-10-06 on
  github.com: same repository only, cross-fork stacks unsupported, merge from the bottom up, and
  after a bottom merge the remaining branches are rebased, server-side or by `gh stack sync`,
  which rebases locally and pushes with `--force-with-lease`.
- Not established: whether ordinary PRs opened with a chained `--base` join a native stack on
  their own or must be linked through `gh stack` or the REST API. Two documentation pages were
  silent on it.
- GitLab: an open merge request is retargeted when its target branch merges; documented limits
  include a small cap on how many are updated, no retargeting for forks, and none when the source
  branch is removed by the button after the merge.
- Of the remotes configured across the repositories checked, 40 are on github.com and 4 on
  gitlab.com.

## Decisions

Each is a research ruling for the planner to adopt or overturn, numbered to the task
description.

**D0. Prior art: core gets its own smaller implementation.** Nothing in cslib `/pr` is
importable as code, its branch creation violates the rule that the primary tree never changes
branch, and its base resolution is a forge call an agent may not make. cslib `/pr` is left
untouched.

**D1. Review unit: one task, by its landing proof.** One PR is one commit built from one proof.
Two tasks become one unit when either proof has a non-empty `shared_paths` naming the other's
files, or when the operator asks. Selection is a milestone, a batch record, or an explicit task
list. Branch name: `review/<stack id>/<NN>-<task slug>`, where the stack id is the milestone id
or an operator-supplied name, and the prefix `review/` is overridable. The slug is used, not the
task number, because numbers are reassigned.

**D2. Base resolution is local.** The stack is written to a manifest (proposed:
`specs/reviews/<stack id>.json`) listing each entry's branch, parent branch, commit, title, body
path and state. An entry's base is its parent entry's branch name; the bottom entry's base is
the review base (see the user decision). An existing parent is detected from the manifest and
from `refs/remotes/<remote>/<branch>`, not from the forge. Whether a PR already exists for a
branch is checked inside the user-invoked `/merge`, where a forge read is permitted.

**D3. Order: dependency edges first, landing order to break ties, refusal on contradiction.**
Tasks are grouped into connected components over two kinds of edge: `dependencies` in
`specs/state.json`, and path overlap between proofs. Each component is one linear stack; a
component of one task is a single PR on the review base. Within a component the order is
topological over dependency edges, ties broken by end-commit ancestry. If two path-overlapping
tasks would be ordered against their landing order, the step refuses and names both, offering
the merged unit of D1. Path-disjoint tasks may follow the edges freely, since E2 showed they
commute. The operator may supply an order; the same refusal applies.

**D4. Re-targeting: prepared, by plumbing, never automatic.**
- Automated locally: detecting that a parent has merged (its branch is an ancestor of the
  fetched review base, or a commit with the parent's tree is), recomputing each descendant with
  `git merge-tree --write-tree --merge-base=<old parent> <new parent> <child>` and
  `git commit-tree`, and moving the local review refs by compare-and-swap `git update-ref`.
- Prepared for the operator: one `/please push <remote> <branch> --force-with-lease` per
  restacked branch, and the base change for the next PR up where the forge has not already
  retargeted it.
- Refused, naming the path: a restack whose `merge-tree` conflicts.
- Out of scope: fetching (the operator fetches; the step reads remote-tracking refs), resolving
  restack conflicts, native GitHub stack linkage, and `gh stack`.
- Not used: `git rebase` in any form, and `git replay` while it is marked experimental.

**D5. Handoff: a separate script cuts the stack; the handoff prints it.** The handoff's test
suite asserts the handoff contains no ref-writing git call, and that assertion is worth keeping.
A new script builds the review refs and the manifest; `milestone-review-handoff.sh` calls it and
prints, per entry in order: branch, base, title, body path, and the literal commands. A stack of
N PRs needs N `/please push` grants, typed one at a time, each confirmed. PR creation is a
further user-invoked step: `/merge` gains a mode naming the head, the base, the title and a body
file, which pushes nothing and checks that the remote branch equals the local one first. With a
per-PR mode that is 2N typed commands; with a whole-stack mode reading the manifest it is N + 1.

**D6. Platform: GitHub supported, same repository only; everything else refused by name.**
GitLab is refused in the first build with the reason stated: its retargeting limits were read
from documentation and not exercised. A fork arrangement, where the head and base repositories
differ, is refused for any entry above the bottom, since a base branch must exist in the base
repository. An unrecognised host is refused.

**D7. No hardcoded repository, remote, branch or path.** The remote comes from the integration
branch's configured upstream, else the only remote, else a refusal that asks for `--remote`. The
integration branch comes from the batch record, then the declaration, then `HEAD`, as the
handoff already resolves it. The review base comes from a declaration or a flag.

## Recommendations

1. **Settle the review base before planning the build** (user decision below). Recommended: a
   top-level `review_base` key in `.claude-extensions.json` beside `integration_branch`,
   documented in `context/standards/repo-level-declarations.md`. When it is undeclared, or equal
   to the integration branch, the step refuses and says no mergeable PR can be cut.
2. **Build the stack in two moves.** Overlay each task on `merge-base(review base, integration
   branch)`, where the overlay is exact. If the review base has moved past that merge base,
   transplant each commit onto the review base tip with the three-way `merge-tree` of D4. One
   primitive then serves both the first cut and every restack.
3. **Add one script and one suite**, proposed `scripts/review-stack-prepare.sh` and
   `scripts/tests/test-review-stack-prepare.sh`, with modes for cutting, restacking and a dry
   run. Reuse `batch_admission_record_for_task` and the handoff's `proof_for_task` logic.
4. **Extend `/merge`** with the head-and-base mode of D5, replacing the hardcoded `origin` and
   `main` defaults in that mode. In that mode it revokes the grant the mint hook issued for the
   checked-out branch, since it pushes nothing.
5. **Fix the handoff's printed commands.** Stop printing a bare `/merge` after
   `/please push <integration branch>`.
6. **Widen `file_scope`.** The declared scope lacks the new script, its suite,
   `scripts/tests/suite-classification.data`, `context/standards/repo-level-declarations.md`, and
   `context/standards/orchestrator-runtime-files.md` if the manifest is documented there.
7. **Verify in a fixture repository created outside the source-store repository**, with its own
   remote name, a feature integration branch and a bare repository as the remote. The pushes and
   PR creation in the "run by the operator" criterion cannot be discharged by an agent; the plan
   should name them as operator steps and say what the agent verifies instead (refs, bases,
   order, printed commands, and the absence of any push or forge call in the scripts).

Recommendations 2 and 3 propose a mechanical rule over a corpus (the set of landed tasks). It was
run against the fixture only. Against the live corpus it can run on one task, the only one with
a proof, so the three-task case is unmeasured here.

### User decision raised (non-blocking)

What does the bottom PR of a stack merge into?

- **A. A declared review base distinct from the integration branch** (recommended). PRs are
  mergeable. A repository whose integration branch is its default branch, as this one is, gets a
  refusal and no PRs.
- **B. The integration branch, as the task description says.** PRs can be read and approved and
  are then closed. They cannot be merged, and no restack question arises.

## Risks & Mitigations

- **Overlay loses foreign edits on a moved base.** Measured (E5). Mitigation: overlay only on an
  ancestor of the integration branch; transplant with the three-way merge.
- **A grant dies when another session commits.** The grant is bound to `HEAD`. Mitigation: say
  so in the printed handoff; the push simply needs a fresh `/please`.
- **Force-with-lease refused where the default branch is undetermined.** Mitigation: the
  restack output checks `refs/remotes/<remote>/HEAD` and prints the `git remote set-head` line.
- **Review fixes made on a review branch are lost at the next rebuild.** Mitigation: state that
  fixes go on the integration branch and the stack is recut; refuse to move a review ref whose
  remote-tracking ref holds commits the manifest does not know.
- **Tasks without proofs.** Most completed tasks predate the proof. Mitigation: the bounded
  subject-attribution fallback, marked in the PR body as attributed without a proof.
- **Unmerged earlier work under a stack.** A task's end-commit blob contains every earlier
  change to its files. If an earlier unmerged task touched them and is not in the stack, its
  lines ride along. Mitigation: treat it as a path overlap under D3 and pull that task in, or
  refuse.
- **Native GitHub stacks may rebase branches server-side.** The local refs then lag. Mitigation:
  the restack step compares against the remote-tracking ref and refuses rather than overwrite.
- **PR creation is not mechanically guarded.** Only the push is. Mitigation: the new script's
  suite asserts, as the handoff's does, that it contains no `gh`, `glab` or push invocation.

## Context Extension Recommendations

none (meta task)

## Appendix

Experiments, all in a scratch fixture, git 2.54.0:

- E1 stack cut by blob overlay; E2 ordering, overlapping and disjoint; E3 base choices and
  merge into the integration branch; E4 restack after a squash-merged parent, three methods; E5
  overlay against a moved mainline.

Files read: `specs/decisions/branch-topology-and-landing-strategy.md`,
`specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`,
`specs/673_per_task_attribution_squash_landing/summaries/01_landing-verification-gate-summary.md`,
and under `agent-system/extensions/core/`: `scripts/milestone-review-handoff.sh`,
`commands/merge.md`, `commands/please.md`, `hooks/guard-git-push.sh`, `hooks/please-grant.sh`,
`scripts/lib/push-grant-lib.sh` (exclusion and default-branch functions),
`scripts/git-push-granted.sh` (header), `context/standards/orchestrator-runtime-files.md` (batch
record section); under `agent-system/extensions/cslib/`: `commands/pr.md` (by grep and step
outline, not in full), `context/project/cslib/pr-command-workflow.md`.

Searches: `grep -rIl -i stacked agent-system`; `grep -rln "gh pr create\|glab mr create"
core/hooks core/scripts`; `grep -rn milestone-review-handoff` over the core extension.

Web sources:

- https://github.blog/changelog/2020-05-19-pull-request-retargeting
- https://github.blog/changelog/2026-10-06-stacked-pull-requests-generally-available
- https://docs.github.com/en/pull-requests/get-started/about-stacked-prs
- https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests
- https://archives.docs.gitlab.com/16.1/ee/user/project/merge_requests
