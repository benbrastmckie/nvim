# Implementation Plan: Task #685

- **Task**: 685 - Cut review branches and submit a stack of PRs from landed integration-branch work
- **Status**: [NOT STARTED]
- **Effort**: 10.5 hours
- **Dependencies**: 673 (completed)
- **Research Inputs**: specs/685_stack_pr_submission_from_integration_branch/reports/01_stack-pr-submission.md
- **Artifacts**: plans/01_stack-pr-submission.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Landed work reaches the integration branch as interleaved phase commits with one landing proof
per task; nothing cuts a review branch, chooses a PR base, or keeps a stack of dependent PRs
current. This plan adds one script, `review-stack-prepare.sh`, that builds a stack of review
branches from landing proofs by git plumbing alone, records it in a machine-local manifest, and
restacks it when a parent merges. `milestone-review-handoff.sh` prints the stack with the literal
commands, and `/merge` gains a user-invoked stack mode that opens the PRs. Done means: a stack of
three dependent review branches is prepared in a repository other than the source-store
repository, each with the correct base and in dependency order, a merged parent has a tested
disposition, and no agent-run code pushes or calls a forge.

The consent boundary is unchanged. Every push stays behind a typed `/please`, and every forge
call stays inside the user-invoked `/merge`.

### Research Integration

Adopted from the report: the landing contract as read (one proof per task, never a range); core
gets its own small implementation and cslib `/pr` is left untouched (D0); one task per review
unit (D1); local base resolution from a manifest (D2); dependency edges first, landing order to
break ties, refusal on contradiction (D3); restack by `git merge-tree --write-tree --merge-base`
and `git commit-tree`, never `git rebase` or `git replay` (D4); a separate script cuts and the
handoff prints (D5); GitHub, same repository only (D6); nothing hardcoded (D7).

Changed from the report: the manifest location (Decision PD4) and the `/merge` shape, which is
one whole-stack mode with an entry filter and no second per-PR mode (Decision PD8).

Settled by the relayed user answer: the bottom PR merges into a declared review base distinct
from the integration branch, under a new `review_base` key. A repository whose integration
branch is its review base gets a refusal and no PRs. Item 2 of the task description (bottom PR
targets the integration branch) is superseded by that answer.

### Premise Re-Validation

The dispatch flagged three description lines. Each was checked against the report and live
state at authoring time.

| Description line | Result |
|---|---|
| Source store is the edit target (`agent-system/extensions/core/**`) | Confirmed. `.claude-extensions.json` gives `core` a `source_dir` of `agent-system/extensions/core` inside this repository. |
| Consent boundary: `rules/pr-prohibition.md`, ruling R8, `hooks/guard-git-push.sh` | Confirmed. The rule text is unchanged and the hook exists in the source store. The report adds one qualification, re-confirmed here: only the push is mechanically guarded; PR creation is barred by the rule alone. |
| The landing task owes a contract | Confirmed present. `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`, section "Interface to review submission", answers all three owed items. No blocker. |

Carried figures, re-derived at authoring time: one batch record exists
(`specs/.orchestration/batch/sess_1795425897_6a25f2.json`), `integration_branch` `master`, one
landing proof (task 673, 13 commits, 17 paths, empty `shared_paths`); `commands/merge.md`
defaults the target to `main` and reads the remote `origin`; `hooks/please-grant.sh` mints the
`/merge` grant for `origin` and the checked-out branch; the handoff prints
`/please push <integration branch>` then `/merge`; the grant window is 600 seconds
(`PG_EXPIRY_WINDOW`); git is 2.54.0; cslib `commands/pr.md` is 2,406 lines.

CARRIED-UNVERIFIED (source: the research report): the fixture results E1 to E5, the forge
retargeting behaviour of GitHub and GitLab, and the count of remotes per host across sibling
repositories. The fixture results are re-established by this plan's own suite; the forge
behaviour is not exercised by any agent step.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Advances milestone M5, "Integration-branch landing and the PR stack", batch 1. This task supplies
the gate clause "a stack of pull requests is cut from that landed work". No roadmap phases are
added; `roadmap_flag` was not set.

## Goals & Non-Goals

**Goals**:
- A `review_base` declaration, with refusals when it is absent, malformed, unresolvable, or equal
  to the integration branch.
- A stack cut from landing proofs by plumbing, leaving `HEAD`, the index and the working tree
  unchanged.
- Local base resolution: each entry's base is its parent entry's branch; the bottom entry's base
  is the review base.
- Stack order derived from `dependencies` edges and path overlap, with a refusal when the edges
  contradict the landed order of path-overlapping tasks.
- A tested restack disposition when a parent merges.
- A handoff that names every PR in order with base, title, body path and the literal commands.
- A `/merge` stack mode that opens the PRs and pushes nothing.
- Refusal by name on any platform or repository arrangement that is not supported.
- No hardcoded repository, remote, branch or path, shown in a repository other than this one.

**Non-Goals**:
- Changing the consent boundary, the mint hook, or the push guard.
- Worktree isolation, and the landing mechanism itself.
- Editing or extracting the cslib `/pr` command.
- GitLab support, fork arrangements, native GitHub stack linkage, and `gh stack`.
- Fetching, and resolving restack conflicts. Both are the operator's.
- Fixing the single-branch `/merge` mode's own `origin` and `main` defaults.
- Reusing or deleting `milestone-ref-land.sh`. It stays on disk, unwired.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Overlay drops foreign edits when the review base has moved | H | M | Overlay only on `merge-base(review base, integration branch)`; move onto the base tip by three-way `merge-tree`. A fixture reproduces the moved-base case. |
| A grant dies when another session commits, since it is bound to `HEAD` | M | M | The handoff says so. The manifest is gitignored, so preparing a stack makes no commit of its own. |
| `--force-with-lease` refused where the remote's default branch is undetermined | M | M | Restack output checks `refs/remotes/<remote>/HEAD` and prints the `git remote set-head <remote> -a` line first. |
| Review fixes committed on a review branch are lost at the next cut | M | M | The script refuses to move a review ref whose remote-tracking ref holds a commit the manifest does not record. Fixes go on the integration branch. |
| Tasks with no landing proof | M | H | Bounded commit-subject attribution, as the handoff already does; the PR body states the entry was attributed without a proof. |
| An earlier unmerged task's lines ride along in a task's blobs | M | M | Treated as path overlap: the earlier task is pulled into the stack or the cut refuses, naming both. |
| The forge rebases branches server-side and local refs lag | M | L | Restack compares each local ref with its remote-tracking ref and refuses rather than overwrite. |
| PR creation is not mechanically guarded | H | L | The suite asserts the script and the handoff contain no push, `gh` or `glab` invocation. `/merge` remains user-only. |
| The live corpus has one proof, so three real dependent tasks cannot be cut here | M | H | The three-PR criterion runs on a fixture repository. Stated, not hidden; see Decision PD11. |
| An unused `/merge`-minted grant stays live for its window in stack mode | M | M | Stack mode revokes it as its first step (Phase 6); if that cannot be done from the command, the residue is documented in `merge.md`. |
| Shared territory: `milestone-review-handoff.sh`, `manifest.json` and `index-entries.json` are edited by other open tasks | M | M | Edits are confined to the printed-command block and additive rows; no unrelated refactor. |

## Decisions

- **PD1. Review base.** A top-level string key `review_base` in `.claude-extensions.json`,
  beside `integration_branch`. A `--review-base` flag overrides it for one invocation. The cut
  refuses, and prepares nothing, when the value is absent, empty, not a string, unresolvable to a
  commit, or names the integration branch. This follows the relayed user answer.
- **PD2. Own implementation.** Nothing in cslib `/pr` is importable as code: it is prose run by a
  model, it creates branches by checkout, and its base resolution is a forge read. Two ideas
  carry over: a chained base as the whole of stacking on the forge side, and a "Relationship to
  other PRs" section in each body. cslib `/pr` is not edited.
- **PD3. Review unit.** One task, built from its landing proof as one commit. Two tasks become
  one unit when either proof's `shared_paths` names the other's files, or when the operator
  passes `--merge`. Selection is a milestone id, a batch session id, or an explicit task list.
  Branch name: `<prefix>/<stack id>/<NN>-<task slug>`, prefix `review` unless `--prefix` is
  given. The slug is used because task numbers are reassigned.
- **PD4. Manifest location.** `specs/.orchestration/reviews/<stack id>/manifest.json`, with one
  body file per entry beside it. The report proposed a tracked `specs/reviews/`. A gitignored
  location is chosen instead for three reasons: the review refs the manifest names are local
  until pushed, the batch records it is built from are already machine-local, and a tracked
  manifest would invite commits between pushes, each of which moves `HEAD` and kills a live
  grant. The existing `**/.orchestration/` ignore class covers the path.
- **PD5. Order.** Tasks are grouped into connected components over dependency edges and proof
  path overlap. Each component is one linear stack. Within it the order is topological over
  dependency edges, ties broken by end-commit ancestry. Two path-overlapping tasks ordered
  against their landing order produce a refusal naming both and offering the merged unit.
  Path-disjoint tasks follow the edges freely. `--order` supplies an operator order under the
  same refusal.
- **PD6. Cut in two moves.** Overlay each unit on `merge-base(review base, integration branch)`,
  where the overlay is exact. If the review base tip is past that merge base, move each commit
  onto the tip with the three-way `merge-tree`. One primitive then serves the first cut and
  every restack.
- **PD7. Restack.** Detection is local, against the fetched remote-tracking ref of the review
  base: the parent's commit is an ancestor of it, or merging the parent into it yields the base's
  own tree. `--merged NN` lets the operator state it. Descendants are recomputed and local refs
  moved by compare-and-swap. A conflicting restack refuses and names the path. The push and the
  forge base change are prepared, never run.
- **PD8. Handoff and `/merge`.** The handoff calls the script non-fatally and prints its `show`
  output. A stack of N entries costs N typed `/please push` grants, one per branch, plus one
  `/merge --stack <stack id>`. The grant count is stated in the printed output and is not
  designed around. `/merge --stack` takes `--only NN` and `--retarget`; no separate per-PR mode
  is built.
- **PD9. Platform.** GitHub, head and base in the same repository. A GitLab remote, an
  unrecognised host, and a remote whose push URL differs from its fetch URL are each refused by
  name with the reason.
- **PD10. No shared proof helper.** The script carries its own reader over
  `batch_admission_record_for_task`, the same few lines the handoff has. Moving the handoff's
  private function into `batch-admission-lib.sh` would widen the edit to a library eight suites
  cover, for one new caller.
- **PD11. What an agent can and cannot verify.** The criterion "the prepared commands, run by
  the operator, produce the stack on the forge" needs a push and a forge write. No agent step
  discharges it. The summary records it as operator-owed with a runbook, and the plan verifies
  what stands in for it: refs, bases, order, the printed commands, and the absence of any push
  or forge call.
- **PD12. Simulating the remote in fixtures.** The suite never runs `git push`. A bare fixture
  repository fetches the review refs from the working fixture, which leaves the same remote
  state a push would.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. This plan is fully sequential: phases 1 to
4 edit the same script and suite, and phases 5 and 6 read the manifest shape phases 3 and 4 fix.

### Phase 1: Review-base declaration, resolution and refusals [NOT STARTED]

**Goal**: The script exists, is registered, and resolves or refuses every input a cut needs
before any ref is built.

**Tasks**:
- [ ] Read `context/patterns/ref-plumbing-landing.md` and `scripts/task-landing-verify.sh` for
      the plumbing and deployed-shape conventions the new script follows.
- [ ] Create `scripts/review-stack-prepare.sh` with subcommands `cut`, `restack`, `show` and
      `record-request`, a `--dry-run` flag, and the header convention the handoff uses: a
      statement of what the script never calls. Later phases fill `cut`, `restack`, `show` and
      `record-request`; in this phase each resolves its inputs and stops.
- [ ] Resolve the integration branch as the handoff does: the batch record, then
      `batch_admission_integration_branch`, then the branch `HEAD` names.
- [ ] Resolve the review base per PD1 and implement its five refusals, each with a named reason
      on standard error and a distinct exit code.
- [ ] Resolve the remote: `--remote`, else the integration branch's configured upstream remote,
      else the only remote, else a refusal that asks for `--remote`.
- [ ] Detect the platform from the remote URL and implement the three refusals of PD9.
- [ ] Add the `review_base` section to `context/standards/repo-level-declarations.md`, beside
      `integration_branch`: schema, the refusal table, and the fail-open-on-absence row (absent
      means no stack can be cut; nothing else changes).
- [ ] Create `scripts/tests/test-review-stack-prepare.sh` in the deployed-shape sandbox
      convention of `test-milestone-review-handoff.sh`. Fixture repositories use a remote that is
      not named `origin` and branches not named `main` or `master`. Mark synthetic task numbers
      with the `task-ref-ok` markers that suite uses.
- [ ] Suite cases: each PD1 refusal; each PD9 refusal; each remote-resolution branch; and two
      static assertions over the script's non-comment lines: no push, `gh`, `glab`, checkout,
      switch, rebase or replay invocation, and no literal `origin`, `main`, `master` or
      `upstream` word.
- [ ] Register the script and suite: run `scripts/sync-manifest-scripts.sh --write`, and add the
      suite's row to `scripts/tests/suite-classification.data` as `unit`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: `sync-manifest-scripts.sh --write` is taken to add exactly two entries to
core's `provides.scripts` (the script and its suite) and nothing else. Confirm with
`git diff -- agent-system/extensions/core/manifest.json` before committing; if it adds unrelated
entries, add the two by hand instead and record the others as a follow-up.

**Tier Justification**: `manifest.json`'s `provides.scripts` and `suite-classification.data` are
the registration surfaces the deploy engine and `run-all.sh` discovery read for every suite, which
the selector maps to several dozen suites across the corpus and no single-module check covers.

**Files to modify**:
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - created
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - created
- `agent-system/extensions/core/manifest.json` - two `provides.scripts` entries
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one row
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - `review_base`
  section; exists, confirmed at authoring time
- `agent-system/extensions/core/index-entries.json` - the declarations file's `line_count`
  moves; reconciled by Phase 7's redeploy, since the check is not commit-blocking here

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` exits 0, and
  each refusal case was first observed failing against a script without the refusal.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's paths reports
  green; under `/orchestrate` the complete gate set is deferred to the orchestration close.
- Run in this repository, `review-stack-prepare.sh cut --dry-run` refuses with the
  review-base-undeclared reason and writes nothing.

---

### Phase 2: Unit selection and stack ordering [NOT STARTED]

**Goal**: `cut --dry-run` prints the units, their order and their bases for any selection, or
refuses with a reason.

**Tasks**:
- [ ] Selection: `--milestone ID`, `--batch SESSION`, or `--tasks N,N,...`. The stack id is the
      milestone id, or `--stack-id NAME`, which is required for the other two forms.
- [ ] Read each task's landing proof through `batch_admission_record_for_task` (PD10): commit
      list, `end_commit`, path set, `shared_paths`.
- [ ] Fallback for a task with no proof: the commit-subject convention bounded below by the
      task's `created` time, as the handoff's `task_review_line` does. The path set is the union
      of paths its attributed commits changed outside the state territory; the end commit is the
      last attributed commit. Mark the unit as attributed without a proof. A task with neither is
      refused by name.
- [ ] Build units per PD3, including the `shared_paths` merge and `--merge N+M`.
- [ ] Detect an earlier unmerged task whose commits touch a selected unit's paths and are not on
      the review base; pull it in when it is selectable, else refuse naming both.
- [ ] Order per PD5: components, topological order over `dependencies` from `specs/state.json`
      and its archive, end-commit ancestry for ties, the contradiction refusal, and `--order`.
- [ ] Assign each unit its branch name and its base: the parent unit's branch, or the review base
      for the bottom of each component.
- [ ] Suite cases: three dependent tasks order bottom-up; two path-disjoint tasks follow the
      edge even against landing order; two path-overlapping tasks ordered against landing order
      are refused; a `shared_paths` pair becomes one unit; a no-proof task is attributed and
      marked; two components yield two stacks, each bottomed on the review base.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: At authoring time `suite_selection_select` returns only the sentinel for
this phase's two paths, because neither file exists until Phase 1 creates them. Once they exist
the selector is expected to map the script to its own suite. Rerun
`verify-touched.sh` over the two paths at implementation time and treat its output as the
authority; if it selects further suites, run them.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's two paths, for which the selector's entire output at authoring time is `__FULL_SWEEP__`
because neither file exists yet, so the phase's own suite is also run directly.

**Files to modify**:
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - selection, units, ordering
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - ordering cases

**Verification**:
- The suite exits 0; the contradiction refusal was observed failing before it was implemented.
- `cut --dry-run` on the three-task fixture prints three units in dependency order with bases
  review base, unit 1's branch, unit 2's branch, and creates no ref and no file.

---

### Phase 3: Cut the stack and write the manifest [NOT STARTED]

**Goal**: `cut` builds the review refs, the manifest and the PR bodies without touching `HEAD`,
the index or the working tree, and `show` prints the stack.

**Tasks**:
- [ ] Overlay per PD6 with a temporary index (`GIT_INDEX_FILE`): read the parent tree, set each
      path of the unit's set to its blob at the unit's end commit (`git update-index --cacheinfo`,
      `--force-remove` for a deleted path), `git write-tree`, `git commit-tree -p <parent>`.
- [ ] When the review base tip is past the merge base, move each commit onto the tip with
      `git merge-tree --write-tree --merge-base=<old parent> <new parent> <commit>`; a conflict
      refuses and names the path.
- [ ] Move refs with compare-and-swap `git update-ref`. A re-cut with unchanged inputs is a
      no-op. Refuse to move a ref whose remote-tracking ref holds a commit the manifest does not
      record.
- [ ] Commit message and PR title: the subject of the task's completion commit with the
      task-number prefix removed. Body file: Summary, Relationship to other PRs (parent and child
      branches), Changed files, and the attributed-without-a-proof or co-landed-lines notice
      where one applies.
- [ ] Write the manifest per PD4: stack id, remote, integration branch, review base, and per
      entry its ordinal, tasks, branch, base, commit, parent commit, title, body path, state, and
      an empty request field. `record-request NN URL` fills the request field.
- [ ] `show` prints, per entry in order: branch, base, title, body path, then
      `/please push <remote> <branch>`; after the last entry, `/merge --stack <stack id>` and one
      line stating that N entries need N typed grants and that this script runs none of them.
      `show --json` emits the manifest.
- [ ] Document the manifest and body files as a class in
      `context/standards/orchestrator-runtime-files.md`: location, machine-local, gitignored,
      written only by this script.
- [ ] Suite cases: three branches, one commit each, each parented on the one below; each
      commit's diff holds only its unit's paths; the top tree differs from the integration tip
      only in paths outside every unit's set; `HEAD`, `.git/index` and `git status` identical
      before and after; idempotent re-cut; the moved-base case keeps a foreign line; the
      unknown-remote-commit refusal; `show` output matches the manifest.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The `**/.orchestration/` ignore class is taken to cover
`specs/.orchestration/reviews/` with no new pattern in `scripts/lib/runtime-file-patterns.sh`.
Confirm with `git check-ignore -v specs/.orchestration/reviews/x/manifest.json` and by reading
the class table. If a per-class pattern row is required, add it and its file to this phase and
say so in the summary.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's four paths, which the selector resolves to `test-audit-task-proposals.sh`,
`test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-deploy-propagation.sh`,
`test-handoff-dispatch-identity.sh`, `test-index-entries-schema.sh`,
`test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`,
`test-roadmap-command-registration.sh`, `test-runtime-file-tracking.sh` and
`test-session-runtime-files.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - the cut, show and
  record-request subcommands
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - cut cases
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - one class
  entry; exists, confirmed at authoring time
- `agent-system/extensions/core/index-entries.json` - the runtime-files document's `line_count`
  moves; reconciled by Phase 7's redeploy

**Verification**:
- The suite exits 0, including the byte-identical `HEAD`, index and status assertions.
- `verify-touched.sh` over the four paths reports green.
- The script's static assertions from Phase 1 still pass.

---

### Phase 4: Restack when a parent merges [NOT STARTED]

**Goal**: A merged parent yields a stated disposition for every descendant: restacked locally
with the commands printed, or refused with the reason.

**Tasks**:
- [ ] `restack --stack-id NAME [--merged NN]`: read the manifest and the remote-tracking ref of
      the review base. Fetching is not done; if that ref is absent, refuse and print the fetch
      the operator runs.
- [ ] Detect a merged entry per PD7, bottom-up. A merged entry's state becomes `merged` and the
      next entry's base becomes the review base.
- [ ] Recompute each descendant with the three-way `merge-tree` onto its new parent, write it
      with `git commit-tree`, and move its ref by compare-and-swap. A conflict refuses, names the
      path, and moves nothing.
- [ ] Refuse when a local review ref and its remote-tracking ref disagree in a way the manifest
      does not explain.
- [ ] Print, per restacked branch, `/please push <remote> <branch> --force-with-lease`, and once
      `/merge --stack <stack id> --retarget` for the forge base change. When
      `refs/remotes/<remote>/HEAD` is absent, print `git remote set-head <remote> -a` first with
      the reason.
- [ ] When nothing has merged, report that and change nothing. A base that moved without a
      merged entry is reported as a stale stack with the restack it would perform.
- [ ] Suite cases: bottom entry squash-merged, descendants restacked, their diffs against the
      new base list only their own paths; the same with a foreign commit on the base, whose line
      survives; a merge-commit parent detected by ancestry; a conflicting restack refused; no
      merged parent is a no-op; `HEAD`, index and status unchanged throughout.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: As in Phase 2, the selector's authoring-time output for this phase's two
paths is the sentinel alone because the files do not exist yet. Rerun `verify-touched.sh` at
implementation time and follow its output.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's two paths, for which the selector's entire output at authoring time is `__FULL_SWEEP__`
because neither file exists yet, so the phase's own suite is also run directly.

**Files to modify**:
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - `restack`
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - restack cases

**Verification**:
- The suite exits 0. The stale-stack assertion (the descendant's three-dot diff lists the
  parent's files before the restack and not after) was observed in both states.

---

### Phase 5: Handoff prints the stack [NOT STARTED]

**Goal**: The milestone handoff names every PR of the stack in order with its commands, and no
longer prints a `/merge` that cannot work.

**Tasks**:
- [ ] In `milestone-review-handoff.sh`, after the per-task listing, call
      `review-stack-prepare.sh cut --milestone <id>` non-fatally, then `show`. The handoff itself
      still contains no ref-writing git call.
- [ ] When the cut succeeds, write its `show` output into
      `specs/milestones/<id>-review-handoff.md` and print it as the final output, in place of the
      two lines printed today.
- [ ] When the cut refuses, print the refusal reason, keep the per-task listing, print
      `/please push <integration branch>` alone, and do not print `/merge`.
- [ ] Add one printed line: a grant is bound to `HEAD` at the time it is typed, so a commit by
      another session in between means typing the grant again.
- [ ] Update the handoff's header comment, and the two documents that describe its printed
      commands: `context/contracts/conclusion-stage.md` and
      `context/standards/git-workflow-narrative.md`. State the current behaviour only.
- [ ] Suite: add the stack-printed case and the refusal-fallback case; keep the assertion that
      the handoff holds no push-shaped and no ref-writing call; install the new script in the
      suite's sandbox.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's five paths, which the selector resolves to `test-context-reachability.sh`,
`test-deploy-orphans.sh`, `test-guard-destructive-git.sh`, `test-index-entries-schema.sh`,
`test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`,
`test-milestone-review-handoff.sh`, `test-orchestrate-conclusion-aggregate.sh`,
`test-orchestrate-conclusion-backstop.sh`, `test-orchestrate-conclusion-roadmap.sh`,
`test-orchestrate-recap.sh` and `test-roadmap-command-registration.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` - printed-command block and
  header; exists
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` - two cases;
  exists
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - the handoff paragraph;
  exists, confirmed at authoring time
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - the handoff
  paragraph; exists, confirmed at authoring time
- `agent-system/extensions/core/index-entries.json` - two `line_count` values move; reconciled
  by Phase 7's redeploy

**Verification**:
- `test-milestone-review-handoff.sh` and `test-orchestrate-conclusion-roadmap.sh` exit 0.
- `verify-touched.sh` over the five paths reports green.
- `grep -n '/merge' agent-system/extensions/core/scripts/milestone-review-handoff.sh` shows no
  bare `/merge` line printed after a push of the integration branch.

---

### Phase 6: `/merge` stack mode [NOT STARTED]

**Goal**: A user-invoked `/merge --stack <stack id>` opens the stack's PRs from the manifest and
pushes nothing.

**Tasks**:
- [ ] Add the mode to `commands/merge.md`: `--stack <stack id>`, `--only NN`, `--retarget`, and
      the existing `--draft`. Update the frontmatter argument hint and the options table. The
      single-branch mode is left as it is.
- [ ] Stack mode steps, in order: revoke the prompt-minted grant, since this mode pushes nothing;
      read the manifest with `review-stack-prepare.sh show --json`; refuse a platform PD9 does
      not support; show one approval prompt listing every PR with its head and base.
- [ ] Per entry, bottom-up: confirm the remote branch tip equals the manifest commit with
      `git ls-remote <remote> refs/heads/<branch>`, and stop naming the `/please push` to type
      when it does not; look for an open PR on that head; create one with the manifest's head,
      base, title and body file when there is none; record the URL with
      `review-stack-prepare.sh record-request`.
- [ ] `--retarget`: for each open entry whose PR base differs from the manifest base, change the
      PR's base. State that the forge may already have done this when the parent's branch was
      deleted.
- [ ] State in the command that the remote and every branch name come from the manifest, never
      from a default.
- [ ] Keep the "Agent Restrictions" section; add that stack mode is user-only on the same
      ground.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: Revoking the prompt-minted grant is taken to be possible from the command
by sourcing `scripts/lib/push-grant-lib.sh` and calling `pg_grant_revoke`. Confirm by reading
that function and `hooks/guard-git-push.sh`. If the command cannot do it, leave the grant to
expire, and state in `merge.md` that stack mode leaves an unused grant live for its window.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` alone for
`commands/merge.md`, so the covering check is the doc-lint and task-reference gates:
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 "$(git rev-parse --show-toplevel)"`.

**Files to modify**:
- `agent-system/extensions/core/commands/merge.md` - stack mode; exists

**Verification**:
- The gate 3,4 invocation above exits 0.
- A read-through confirms: stack mode contains no push step; every `gh` call takes its head and
  base from the manifest; the words `origin` and `main` do not appear in the stack-mode steps.
- No agent runs `/merge`. The mode's live behaviour is operator-owed (PD11).

---

### Phase 7: Redeploy, second-repository demonstration and close [NOT STARTED]

**Goal**: The deployed tree carries the work, the whole flow is shown in a repository other than
this one, and the operator has a runbook for the steps no agent may take.

**Tasks**:
- [ ] Update the `/merge` row and usage in `README.md`, `merge-sources/claudemd.md` and the
      `/merge` section of `docs/guides/user-guide.md` to name the stack mode.
- [ ] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh`; check its
      exit status, and that `index-entries.json` line counts were reconciled
      (`generate-context-line-counts.sh --check`).
- [ ] Demonstration, in a scratch repository created outside this repository: its own remote
      name, a bare repository as the remote, a feature integration branch, a distinct review
      base, a batch record with three dependent tasks' proofs, and the deployed scripts copied
      from `.claude/scripts/`. Run `cut`, `show`, simulate the three pushes by fetching from the
      bare side (PD12), simulate the bottom entry's squash-merge on the bare side, fetch, run
      `restack`. Capture the output.
- [ ] Record from the demonstration: the three branches and their bases; the dependency order;
      the printed commands; the restack disposition; unchanged `HEAD`, index and status; and a
      grep of the deployed script showing no push and no forge invocation.
- [ ] Live check in this repository: `cut --dry-run --tasks 673 --stack-id probe` refuses,
      because no review base is declared, and creates nothing.
- [ ] Write the operator runbook into the summary: declare `review_base`; run the cut; type each
      `/please push`; type `/merge --stack <stack id>`; after a parent merges, fetch, run
      `restack`, type each `--force-with-lease` grant, type `/merge --stack <stack id> --retarget`.
      Mark the on-forge criterion as operator-owed and not claimed.
- [ ] Record follow-ups rather than doing them: GitLab support; a mechanical guard on PR
      creation; the single-branch `/merge` defaults.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/README.md` - `/merge` row; exists
- `agent-system/extensions/core/merge-sources/claudemd.md` - `/merge` row; exists
- `agent-system/extensions/core/docs/guides/user-guide.md` - `/merge` section; exists
- `agent-system/extensions/core/index-entries.json` - `line_count` values reconciled by the
  redeploy
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- `deploy-headless.sh` exits 0 and `.claude/scripts/review-stack-prepare.sh` exists.
- The demonstration shows three review branches with bases review base, entry 1, entry 2, in
  dependency order, and a restack after the simulated merge.
- Scoped check for this dispatch: `bash agent-system/extensions/core/scripts/verify-touched.sh`
  with no arguments reports green. Under `/orchestrate` the complete gate set is deferred to the
  orchestration close and that deferral is recorded in the phase's notes. In a standalone run,
  `bash .claude/scripts/verify-deploy.sh` is run directly instead.
- `bash .claude/scripts/check-task-references.sh` reports no new finding under
  `agent-system/**`.

## Testing & Validation

- [ ] `test-review-stack-prepare.sh` exits 0: refusals, ordering, cut, restack, static
      assertions.
- [ ] `test-milestone-review-handoff.sh` and `test-orchestrate-conclusion-roadmap.sh` exit 0.
- [ ] A stack of three dependent entries is prepared in a repository outside this one, with
      correct bases and order.
- [ ] `HEAD`, the index and `git status` are identical before and after every `cut` and
      `restack`.
- [ ] A merged parent produces restacked descendants or a named refusal, never a silent stale
      base.
- [ ] No push, `gh` or `glab` invocation exists in `review-stack-prepare.sh` or
      `milestone-review-handoff.sh`; no agent ran `/please` or `/merge`.
- [ ] No literal remote or branch name in the script; the fixture's remote is not `origin`.
- [ ] No task-number reference and no record-versioning language under `agent-system/**`.
- [ ] The complete gate set passes at the orchestration close.
- [ ] Operator-owed, not claimed by any agent: the prepared commands produce the stack on the
      forge.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/review-stack-prepare.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` (new)
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` and its suite (revised)
- `agent-system/extensions/core/commands/merge.md` (stack mode)
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` (`review_base`)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (manifest class)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`,
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md`,
  `agent-system/extensions/core/README.md`,
  `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/docs/guides/user-guide.md` (references)
- `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/scripts/tests/suite-classification.data`,
  `agent-system/extensions/core/index-entries.json` (registration and derived counts)
- `specs/685_stack_pr_submission_from_integration_branch/summaries/01_stack-pr-submission-summary.md`,
  with the demonstration output and the operator runbook

## Rollback/Contingency

Every change is additive except the handoff's printed-command block and the documents that
describe it. Each phase is one commit, so a phase is reverted with `git revert <commit>` followed
by a redeploy; no uncommitted work is discarded. Review refs and the manifest are local and
unpushed: a stack is removed with `git update-ref -d` per branch and by deleting its directory
under `specs/.orchestration/reviews/`. If the handoff integration misbehaves, reverting Phase 5
alone restores the previous printed output while the script and `/merge` mode remain usable by
hand. Should a rollback ever need to discard uncommitted work, follow the rollback rung of
`context/contracts/recovery.md`.
