# Decision Record: Commit-Layer Cluster Rulings and Dependency Ordering

This record rules on the thirteen open tasks that touch phase-commit composition, containment
filtering, staging scope and scoped committing, and fixes the order in which they and the
branch-orchestration tasks run. It was written so that branch-aware orchestration
(`branch_aware_orchestration_and_squash_landing`, 655) neither duplicates a queued fix nor lands
on a surface another task is about to rewrite.

Every ruling below has a matching change in `specs/state.json`: a dependency edge, an appended
description block, or, for an UNAFFECTED ruling, no change. Decided 2026-11-20 by
`reconcile_commit_layer_cluster_and_ordering` (654). Tasks are named by slug with the number
alongside, because numbers are reassigned at a vault renumber and slugs are not.

## Rulings

Each member has one primary ruling. An edge can fall on a member whatever its primary ruling is;
the "State change" column lists everything written for that member.

| Slug (number) | Ruling | Basis | State change |
|---|---|---|---|
| `manifest_registration_dropped_from_phase_commit` (486) | NEEDS EDGE | Edits `is_contained()` in `git-commit-phase.sh`, shared with 535, 541 and 655. Its subject does not depend on branch target. Placed after 541 so the costlier snapshot fix is not parked behind it. | Edge 2 (target) |
| `cycle_postflight_containment_parity` (501) | NEEDS EDGE | Shares `orchestrate-cycle-postflight.sh` with 570 and both commit scripts with the rest of the chain. Placed after 570 (small, costly) and, through 486, 541 and 535, after 567, so its parity work starts from a third containment site that already strips. | Edge 3 (target) |
| `shared_extension_metadata_commit_containment` (508) | UNAFFECTED | Declares only the allowlist library and two sync tools. None is in 655's or 657's scope, and which paths the allowlist admits does not depend on the ref a commit lands on. **Falsified if** its ruling ends up editing a containment site directly, as its own territory paragraph anticipates. | None |
| `phase_commit_boundary_mechanical_check` (513) | NEEDS REVISION | Judgment 3: one detector covers commit existence and branch target. | Description revised; Edge 7 (predecessor) |
| `stage_regenerated_derived_files_in_phase_commits` (517) | UNAFFECTED | Scope is checkpoint prose, the implementation agent file, the probe library and `repo-level-declarations.md`; no commit script. Its only overlap with the cluster is the coarse agent file. **Falsified if** it adopts its option (b) by editing `git-commit-phase.sh`, or if 655 adds a declaration schema to `repo-level-declarations.md` before this task lands. In either case add 517 to 655's dependencies. | None |
| `scoped_commit_staged_vs_worktree_divergence` (524) | NEEDS EDGE | Already ordered after 501. It becomes the predecessor of 536, whose hunk-scoped staging question can only be answered once 524 has ruled on sub-file staging. | Edge 4 (predecessor) |
| `phase_commit_drops_own_plan_artifact` (535) | NEEDS REVISION | Its core defect is already closed in the source store; see Re-measured premises. | Description revised; Edge 1 (target) |
| `source_store_commit_and_registration_review` (536) | NEEDS REVISION | Judgment 1, and its commit-scoping half predates `commit-source-store-path.sh`. | Description revised; Edge 4 (target), Edge 5 (predecessor) |
| `snapshot_artifacts_contaminate_phase_commits` (541) | NEEDS EDGE | Already after 535. It must precede the branch feature on substance as well as territory: a squash landing folds any swept-in foreign file into one integration-branch commit, where it is harder to back out than in a single phase commit. | Edge 2 (predecessor) |
| `git_commit_scoped_gate_refusal_diagnostic` (553) | NEEDS EDGE | Edits the post-commit verdict block that every other scoped-commit task may move. Placed last in the chain, on its own stated principle that a message change is cheapest on settled structure. | Edge 5 (target), Edge 6 (predecessor) |
| `port_containment_strip_to_git_commit_scoped` (567) | NEEDS EDGE | Judgment 1: not a hard prerequisite, but the head of the chain. It is the smallest change, has no open predecessor, and removes the disagreement between the second and third containment sites that later containment tasks would otherwise design around. | Edge 1 (predecessor) |
| `stall_signal_counts_unattributed_commits` (570) | NEEDS EDGE | Shares the postflight script with 501, 655 and 657. It is also the member whose mechanism the branch feature should reuse: it decides how a commit is attributed to a dispatch, and 655 needs per-task commit attribution. | Edge 3 (predecessor); description addendum |
| `dispatch_starting_position_reverification` (592) | NEEDS REVISION | Judgment 2: an admission-time branch check does not satisfy it. Scope unchanged; the revision is an addendum recording the ruling and one constraint. | Description revised |
| `ignored_specs_predicate_and_commit_path` (658) | Completed | Nothing to order. Its landing changes the premises of 513 and 570, as recorded below. | None |

Tally: NEEDS EDGE 7, NEEDS REVISION 4, UNAFFECTED 2, SUBSUMED 0. No member is closed by the
branch feature's own work.

## Edges

These seven edges are present in `specs/state.json`. Each was written with
`update-task-status.sh preflight <target> edge_only <session> --depends-on-add='[<pred>]'`, which
ran the write-time cycle refusal; none was refused.

| # | Target (gained the dependency) | Predecessor | Kind | Shared surface or reason |
|---|---|---|---|---|
| 1 | `phase_commit_drops_own_plan_artifact` (535) | `port_containment_strip_to_git_commit_scoped` (567) | territory | `tests/test-git-commit-phase.sh` |
| 2 | `manifest_registration_dropped_from_phase_commit` (486) | `snapshot_artifacts_contaminate_phase_commits` (541) | territory | `git-commit-phase.sh` |
| 3 | `cycle_postflight_containment_parity` (501) | `stall_signal_counts_unattributed_commits` (570) | territory | `orchestrate-cycle-postflight.sh` |
| 4 | `source_store_commit_and_registration_review` (536) | `scoped_commit_staged_vs_worktree_divergence` (524) | semantic and territory | `git-commit-scoped.sh`; 536's staging recipe depends on 524's ruling |
| 5 | `git_commit_scoped_gate_refusal_diagnostic` (553) | `source_store_commit_and_registration_review` (536) | territory | `git-commit-scoped.sh` |
| 6 | `branch_aware_orchestration_and_squash_landing` (655) | `git_commit_scoped_gate_refusal_diagnostic` (553) | territory | `git-commit-scoped.sh`, `orchestrate-cycle-postflight.sh` |
| 7 | `branch_aware_orchestration_and_squash_landing` (655) | `phase_commit_boundary_mechanical_check` (513) | semantic | 655 passes the work branch to 513's expected-ref parameter |

Together with the edges that already existed (541 after 535, 501 after 486, 524 after 501, 655
after 657), the order on the commit scripts is:

```
567 -> 535 -> 541 -> 486 -> 501 -> 524 -> 536 -> 553 -> 655
                      570 --^                           657 --^
                                                          513 --^
```

To check an edge: `jq '.active_projects[]|select(.project_number==N)|.dependencies' specs/state.json`.

**Why edge 6 sits on 655 and not on 657.** Both placements order 657 and 655 against the cluster
on `git-commit-scoped.sh` and the postflight script, because 655 is 657's only dependent and
waits for the chain either way. Placing the edge on 657 would additionally park 657's first
element -- a branch-topology ruling that edits no script -- behind the full ten-task chain, for
no gain on the landing commit that the cluster actually threatens. The edge therefore sits on
655, where the squash landing is, and 657's ruling runs as soon as its own predecessors (654,
656) are closed.

**Amended by this record, 2026-11-20:** edge 6's target was moved from 657 to 655 under the
remedy this record itself names, so that the branch-topology ruling could be orchestrated
without waiting on the commit-layer chain. The six 657-against-cluster-member pairs this leaves
unordered are acceptable: 657's declared scope on the two shared scripts is read-and-rule, and
655 -- which does edit them -- remains fully ordered behind 553.

**Reversing an edge.** `update-task-status.sh` has no removal flag. Use `state-write.sh` with
`(.active_projects[] | select(.project_number == $num)).dependencies -= [$pred]`, then regenerate
`specs/TODO.md`.

## Judgment calls

### 1. Are source-store commit scoping and the third containment site hard prerequisites for branch-aware orchestration? No.

- The branch a commit lands on is fixed by `HEAD` in the repository where `git commit` runs.
  `git-commit-scoped.sh` changes to its project root and commits. Its containment block only
  removes entries from the pathspec list beforehand. Neither step reads or writes a ref.
- A path the containment block strips stays uncommitted in the working tree, on any branch.
  Branch targeting neither causes nor worsens that.
- The premise "it cannot target a chosen repository, so it cannot target a chosen branch" does
  not hold. The second-repository case is already served by a separate script,
  `commit-source-store-path.sh`, not by `git-commit-scoped.sh`.

Both tasks (536 and 567) are ordering predecessors of the branch tasks by file territory only.

What would change this ruling: a 655 design that routes the landing commit through
`git-commit-scoped.sh --task` in a second repository, or a 657 ruling that reinstates any form of
tree isolation, since the evidence rests on one `HEAD` per repository.

### 2. Should `dispatch_starting_position_reverification` be revised so that an admission-time branch check satisfies it? No. They are two separate defects.

- 592's object is the description's hand-authored claims about tree content. The branch
  feature's admission check concerns the ref an invocation starts from.
- In the incident 592 cites, the dispatch ran on the correct branch and the description was
  stale against that same branch (it named three landed schemas where the tree carried five). A
  branch check passes and the defect remains.
- The fix site for 592 stays the dispatch composer, `orchestrate-build-dispatch.sh`.

One constraint was added to 592: if its age carrier is ever a commit SHA, it must not be one
reachable only from a work branch, because a squash landing orphans it. No edge was added; 592
and 655 share no file.

### 3. Should `phase_commit_boundary_mechanical_check` cover commit branch target in the same pass? Yes. One detector.

- The check is "for every completed phase, a phase commit exists". That is a `git log` query,
  and a `git log` query always names a ref. Giving it the expected ref makes existence and
  branch target one query: a commit found under `--all` but not reachable from the expected ref
  is the wrong-branch finding.
- Two detectors would read the same plan markers and the same commits twice and could disagree.

513's description now requires: an expected-ref parameter defaulting to `HEAD`, with "exists but
not on the expected ref" as its own finding class; running before any squash landing or reading
the pre-squash ref; subject-only matching, because a squash commit body may list phases; and no
finding for a phase whose only changes were gitignored `specs/` paths. 513 lands first and 655
passes the resolved work branch (edge 7).

## Re-measured premises

Each member's premise was re-read against the source store under `agent-system/extensions/core/`
instead of taken from its description.

| Member | Finding | How established |
|---|---|---|
| 535 | Stale. `git-commit-phase.sh` admits the committing task's own task directory inside its Containment Self-Check, and `tests/test-git-commit-phase.sh` Cases 15 and 16 pin it. What remains is the sentence in `git-staging-scope.md`'s Staging-Layer Containment Filter subsection saying the carve-out paths are "structurally outside its reach", and possibly dotfile fixtures. | Read from code; re-confirmed at implementation time with a fixed-string grep. The tests were not run. |
| 536 | Stale in part. `commit-source-store-path.sh` commits a source-store path in its own repository at phase closure. Still open: the foreign-hunk case, commits outside phase closure, and the registration-description review. | Read from code; the script's presence was re-confirmed at implementation time. |
| 501 | Still open as described. Its line numbers have moved. The bar against co-admitting it with the ignored-specs postflight narrowing, recorded in that task's description, is moot because that task has completed. | Read from code. 501's description was not edited. |
| 567 | Still open as described. The third containment site reads `file_scope` with no deployed-tree strip. | Read from code. |
| 570 | Still open, with a blind spot its description does not name. Both stall probes are `git log --since=... -- "$TASK_DIR"`. Where `specs/` is gitignored no commit touches the task directory, so the count is always zero and the stall signal cannot fire. | Read from code. Not reproduced in a fixture. |
| 513 | Premise holds, with one addition. A phase whose only changes were gitignored `specs/` paths has no commit by design. | Read from code and `rules/git-workflow.md`. Not reproduced in a fixture. |
| 486, 508, 517, 541, 553, 592 | Premises hold. | Anchors located in code. |

## Inputs to the branch feature

These are not rulings on members. They are facts 655 must design for, and they are also appended
to 655's description.

1. A source-store path committed by `commit-source-store-path.sh` lands on whatever branch the
   second repository has checked out. "Phase commits land on the work branch" is not true for
   those commits unless 655 designs for it, and that script is not in 655's `file_scope`.
2. Landing a squash by switching the single shared working tree carries concurrent siblings'
   uncommitted edits across the switch. Concurrent writers are the normal condition.
3. `specs/state.json` and `specs/TODO.md` ride in every task's commits, so per-task ranges on a
   shared branch are not separable by path for those two files.
4. `git-snapshot.sh --branch` moves `HEAD` off the work branch during a snapshot.
5. `.claude-extensions.json` top-level keys, documented in `repo-level-declarations.md`, are the
   existing home for a per-repository integration-branch or generated-path declaration.

## Not ruled on

Overlaps between cluster members and open tasks outside the named cluster remain unordered.
They are listed so the next reader does not take the chain for a complete ordering of every
claimant.

- `git-commit-scoped.sh`: `plan_contingency_file_scope_and_containment_drop` (548) and
  `v10_containment_remedy_for_coupled_pair_paths` (598) against 501, 524, 536 and 567; 598
  against 553; `collapse_perpath_scope_excursion_issue_rows_into_o` (484) against 567. 548 and
  598 both work on the containment block 567 edits.
- `git-commit-phase.sh`: 484 against 535 and 541; `make_issue_record_failures_visible` (639)
  against 486, 535 and 541.
- `orchestrate-cycle-postflight.sh`: 551, 609, 639 and 472 against 501, 570 or both.
- The dispatch composer: 520, 571 and 639 against 592.
- `working_tree_residue_disposition_policy` (618) edits `git-commit-scoped.sh` but declares no
  `file_scope`, so no overlap test can see it.

Two members are also gated today by open tasks outside the chain: 570 by 519 and 513 by 479.

## How this was checked

- **Overlap predicate.** Two tasks overlap when a declared `file_scope` entry of one equals, or
  is a directory prefix of, an entry of the other. `__WHOLE_TREE__` was excluded, as were two
  widely declared files, `context/standards/git-staging-scope.md` and
  `agents/general-implementation-agent.md`, which do not on their own justify an edge.
- **Research simulation.** The research report's own scratch simulation found 33 unordered
  overlapping pairs among the cluster and the three branch tasks before the edges and none
  after, with all 123 open tasks sorting topologically. That simulation reimplemented the overlap
  and cycle tests, its scripts were session scratch, and it was not re-run when the edges were
  written. Those figures are the report's, not an independent measurement.
- **Write-time checks, which were run.** All seven `--depends-on-add` calls passed the real
  cycle refusal. `validate-state.sh --deep` exited 0 before and after with the same counts (21
  passed, 10 warnings, 0 failed). A dry run of `orchestrate-cycle-plan.sh` over the twelve
  chained tasks reported no cycle and no stop.
- **Before-state.** `specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` holds
  the dependencies and full descriptions of the fifteen affected tasks as they stood before any
  write. Each of the seven edge targets gained exactly one dependency and lost none. Each of the
  seven revised descriptions begins with its baseline text, and the other eight are unchanged.
  The appended blocks open with `RE-MEASURED AND RULED (commit-layer cluster ordering`.

**Amended by** `specs/decisions/branch-topology-and-landing-strategy.md`, 2026-11-20: the
branch-topology ruling has landed (rulings R1-R8). Ruling R6 confirms the one-HEAD-per-repository
premise holds, so `phase_commit_boundary_mechanical_check` (513)'s expected ref stays
per-repository rather than becoming per-tree, and this record's `CONDITION ON A RULING` material
(see `## Judgment calls`, item 1) does not fire. Ruling R4 also triggers this record's own
falsification condition for `stage_regenerated_derived_files_in_phase_commits` (517): because the
branch-topology ruling allocates the integration-branch declaration schema row in
`context/standards/repo-level-declarations.md` to `branch_aware_orchestration_and_squash_landing`
(655), 517 is now a predecessor of 655, per the Rulings table's own stated falsification
condition for 517.

**Amended by** batch-worktree-isolation-and-task-squash-landing.md, 2026-11-20: the condition
`## Judgment calls` item 1 names as what would change its ruling ("a 657 ruling that reinstates
any form of tree isolation") has fired. `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
amends the branch-topology record's R5 to reinstate isolation at batch granularity, so the
one-`HEAD`-per-repository evidence item 1 rests on no longer holds where a repository declares
isolation on. Source-store commit scoping (536) and the third containment site (567) become
semantic predecessors of the two-root work on the commit scripts, not territory-only ones, and
the expected ref of `phase_commit_boundary_mechanical_check` (513) becomes per tree there. The
note above this one, recording that the condition did not fire, describes the ruling as it stood
before this amendment. The edges written for this are listed in the amending record's Edges
section; no edge in this record's own Edges table is removed.
