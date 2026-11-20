# Research Report: Task #654

**Task**: 654 - Reconcile the open commit-layer cluster and write its dependency ordering
**Started**: 2026-11-20T08:33:00Z
**Completed**: 2026-11-20T08:45:00Z
**Effort**: Small to implement (state writes plus one decision record; no script edits)
**Dependencies**: None (this task is the root of 656 -> 657 -> 655)
**Sources/Inputs**: - `specs/state.json` (descriptions, `dependencies`, `file_scope` of every cluster member and of 655/656/657/658); source store under `agent-system/extensions/core/` (`scripts/git-commit-scoped.sh`, `scripts/git-commit-phase.sh`, `scripts/orchestrate-cycle-postflight.sh`, `scripts/commit-source-store-path.sh`, `scripts/git-snapshot.sh`, `scripts/update-task-status.sh`, `scripts/tests/test-git-commit-phase.sh`, `context/standards/git-staging-scope.md`, `context/standards/repo-level-declarations.md`, `context/patterns/batch-orchestration-guardrails.md`); `specs/archive/state.json`; one cross-repo issue log entry. No web sources.
**Artifacts**: - specs/654_reconcile_commit_layer_cluster_and_ordering/reports/01_commit-layer-cluster-rulings.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Seven edges give the whole cluster plus the branch tasks a total order on every narrowly shared file.** Simulated against the live graph: acyclic (123 open tasks topologically sorted), and unordered narrow overlaps inside cluster + 655/656/657 drop from 33 pairs to 0.
- **Two member descriptions are stale against the source store and need revision before anyone plans them.** `phase_commit_drops_own_plan_artifact` (535) describes a code defect closed on 2026-11-06; `source_store_commit_and_registration_review` (536) predates `commit-source-store-path.sh`.
- **Judgment 1: NO.** Neither source-store commit scoping (536) nor the third containment site (567) is a hard prerequisite for branch targeting. Both are ordering predecessors by file territory only.
- **Judgment 2: two separate defects.** An admission-time branch check does not satisfy `dispatch_starting_position_reverification` (592); the cited incident would have passed a branch check.
- **Judgment 3: one detector.** `phase_commit_boundary_mechanical_check` (513) should carry a ref parameter and cover branch target in the same pass; 655 then depends on it.
- **The fourteenth member (658, ignored-specs predicate) has already completed.** Re-measuring after it surfaces two new interactions: the stall probe (570) and the per-phase commit-existence check (513) both go blind or false-positive in a repository whose `specs/` is gitignored.
- **No member is SUBSUMED by the branch feature.** Tally: NEEDS EDGE 7, NEEDS REVISION 4, UNAFFECTED 2 (plus the completed fourteenth member, which needs nothing).

## Context & Scope

This is the research phase of a ruling task. Nothing was written to `specs/state.json` task entries; every edge and revision below is a recommendation for the implement phase to apply and verify. The task's own description forbids editing the four commit-layer scripts, and none was edited.

The roadmap annotation on this task adds a fourteenth member ("also rule on the ignored-specs predicate ... and re-measure after it"). That task, `ignored_specs_predicate_and_commit_path` (658), and its followers 659, 660, 661 and 662 are all `completed`, so each member premise was re-read against the current store rather than taken from its description.

Task 655's description is itself provisional: `branch_topology_ruling_and_milestone_automation` (657) has reopened branch granularity and worktree isolation. Rulings here are written to hold for any topology (per invocation, per milestone, per task); the two places where they depend on topology are named in Risks.

## Findings

### Codebase Patterns

**Current live ordering (terminal dependencies removed).** Twelve of the dependency numbers the members carry are already completed and archived (328, 418, 430, 435, 446, 448, 449, 461, 476, 494, 515, 543). What actually still gates each member:

| Task | Slug | Live predecessors |
|---|---|---|
| 486 | manifest_registration_dropped_from_phase_commit | 484 |
| 501 | cycle_postflight_containment_parity | 472, 484, 486 |
| 508 | shared_extension_metadata_commit_containment | 486 |
| 513 | phase_commit_boundary_mechanical_check | 479 |
| 517 | stage_regenerated_derived_files_in_phase_commits | 455 |
| 524 | scoped_commit_staged_vs_worktree_divergence | 484, 501 |
| 535 | phase_commit_drops_own_plan_artifact | none |
| 536 | source_store_commit_and_registration_review | none |
| 541 | snapshot_artifacts_contaminate_phase_commits | 535 |
| 553 | git_commit_scoped_gate_refusal_diagnostic | 548 |
| 567 | port_containment_strip_to_git_commit_scoped | none |
| 570 | stall_signal_counts_unattributed_commits | 519 |
| 592 | dispatch_starting_position_reverification | 599 |

**Territory.** Declared claimants among cluster + branch tasks:

| File | Declared by |
|---|---|
| `scripts/git-commit-scoped.sh` | 501, 524, 536, 553, 567, 655, 657 |
| `scripts/git-commit-phase.sh` | 486, 535, 541, 655 |
| `scripts/orchestrate-cycle-postflight.sh` | 501, 570, 655, 657 |
| `scripts/orchestrate-cycle-plan.sh` | 655, 657 |
| `scripts/skill-base.sh` | 513 |

Before any new edge, 33 pairs in this set share a file with no ordering path between them.

**Two paths are coarse and should not trigger edges on their own.** `context/standards/git-staging-scope.md` is declared by 9 open-or-recent tasks and `agents/general-implementation-agent.md` by 7. Under the Narrowness qualifier in `batch-orchestration-guardrails.md` ("Batching Is the Default"), a widely edited shared file does not make every claimant one mandatory group. Task 524's own description already leaves the standard's doc-only overlap unsequenced for this reason.

**Re-measured member premises.**

- **535, closed in code.** `git-commit-phase.sh` now appends `file_scope_arr+=("${task_dir}/")` inside the Containment Self-Check (commit `eeacd7d47`, 2026-11-06, from archived task 494). `test-git-commit-phase.sh` Cases 15 and 16 pin the admission and the paired genuine-excursion drop. What remains is the false sentence the description itself names: `git-staging-scope.md` lines 363-365 still say the four carve-out paths are "structurally outside its reach".
- **536, commit-scoping half largely delivered.** `scripts/commit-source-store-path.sh` commits one source-store path in its own repository and is called from `git-commit-phase.sh` at phase closure. `git-commit-scoped.sh` still resolves `PROJECT_ROOT` from `BASH_SOURCE` (lines 358-360). The part of 536 still open is the foreign-hunk case (the helper stages a whole file) and the registration-description review.
- **567, still open as described.** `git-commit-scoped.sh`'s V10 block (from line 559) reads `file_scope` straight from `specs/state.json` into `containment_scope_arr` with no `.claude/**` strip. Test Case 26 is still titled "fails open at Site 2 only".
- **501, still open as described.** Site 1 still uses bare `startswith($f)` (postflight line 1792; the description's line numbers have moved). Its annotation, "never co-admit with the ignored-specs postflight narrowing", is moot because that task (659) has completed.
- **570, still open, with a new blind spot.** Both probes are still `git log --since=@ts -- "$TASK_DIR"` (lines 1049 and 2452). In a repository whose `specs/` is gitignored, no commit ever touches `TASK_DIR`, so this count is structurally zero and `stall_suspected` cannot fire. This is read from the code, not reproduced in a fixture.
- **541, 553, 513, 592, 486, 508, 517**: premises still hold; anchors located (`UNTRACKED_BACKUP`/`PATCH_PATH` under `TASK_DIR` in `git-snapshot.sh`; the V8 "PARTIAL commit" and "non-blocking" text at lines 1322 and 1339; `skill_corroborate_phase_counts` at `skill-base.sh:1592`; the composer's Premise re-validation block and `description_fingerprint`).

**Branch awareness.** Outside tests, the only branch creation in `scripts/` and `hooks/` is `git-snapshot.sh`'s `--branch` mode. `commit-source-store-path.sh` refuses a detached HEAD in the second repository but otherwise commits to whatever branch is checked out there. Nothing in the four commit-layer scripts reads or asserts a ref.

**Declaration site.** `context/standards/repo-level-declarations.md` already documents top-level hand-authored keys in `.claude-extensions.json` as the per-repository declaration point (`derived_artifact_probes`, `coupled_generated_surfaces`, `verification_scope`). This is the existing home for 655's integration-branch declaration (element A) and generated-path declaration (element F).

### External Resources

None used. Every question here is answered by the store and the task graph.

## Recommendations

### 1. Ruling per member

One primary ruling each. Edges that fall on a member as an ordering consequence are listed in section 2 regardless of its primary ruling.

| Task | Slug | Ruling | Basis |
|---|---|---|---|
| 486 | manifest_registration_dropped_from_phase_commit | NEEDS EDGE | Edits `is_contained()` in `git-commit-phase.sh`, shared with 535, 541 and 655. Subject is independent of branch target. Goes after 541 so the costlier snapshot fix is not parked behind 484. |
| 501 | cycle_postflight_containment_parity | NEEDS EDGE | Shares postflight with 570 and both commit scripts with the rest of the chain. Goes after 570 (small, costly) and, transitively, after 567 so its parity work starts from a Site 3 that already strips. |
| 508 | shared_extension_metadata_commit_containment | UNAFFECTED | Declares only the allowlist library and two sync tools; none appears in 655 or 657's scope, and its subject (which paths the allowlist admits; narrowing `--write`) does not depend on which ref a commit lands on. Falsified if its ruling ends up editing a containment site directly, as its own TERRITORY paragraph anticipates. |
| 513 | phase_commit_boundary_mechanical_check | NEEDS REVISION | Judgment 3. See section 4. |
| 517 | stage_regenerated_derived_files_in_phase_commits | UNAFFECTED | Scope is checkpoint prose, the agent file, the probe library and `repo-level-declarations.md`; no commit script. Its only cluster overlap is the coarse agent file. Falsified if it adopts option (b) by editing `git-commit-phase.sh`, or if 655 adds its declaration schema to `repo-level-declarations.md` before 517 lands; add `655 += 517` in either case. |
| 524 | scoped_commit_staged_vs_worktree_divergence | NEEDS EDGE | Already ordered after 501. It becomes the predecessor of 536, whose hunk-scoped staging recipe is only sound in light of 524's ruling on sub-file staging. |
| 535 | phase_commit_drops_own_plan_artifact | NEEDS REVISION | Core defect already closed in the store. See section 3. |
| 536 | source_store_commit_and_registration_review | NEEDS REVISION | Judgment 1, and the commit-scoping half predates `commit-source-store-path.sh`. See section 3. |
| 541 | snapshot_artifacts_contaminate_phase_commits | NEEDS EDGE | Already after 535. Must precede the branch feature on substance as well as territory: a squash landing would fold swept-in foreign files into one integration-branch commit, where they are harder to back out than in a single phase commit. |
| 553 | git_commit_scoped_gate_refusal_diagnostic | NEEDS EDGE | Edits the post-commit verdict block every other scoped-commit task may move. Goes last in the chain, on its own stated principle that a message change is cheapest on top of settled structure. |
| 567 | port_containment_strip_to_git_commit_scoped | NEEDS EDGE | Judgment 1: not a hard prerequisite, but the head of the chain. Smallest change, no live predecessors, and it removes the Site 2/Site 3 disagreement the later containment tasks would otherwise design around. |
| 570 | stall_signal_counts_unattributed_commits | NEEDS EDGE | Shares postflight with 501, 655, 657. Also the one member whose mechanism the branch feature should reuse: 655 element D needs per-task commit attribution "not from assuming contiguity", and 570 decides how a commit is attributed to a dispatch. |
| 592 | dispatch_starting_position_reverification | NEEDS REVISION | Judgment 2. Scope unchanged; a short addendum records the ruling. See section 4. |
| 658 | ignored_specs_predicate_and_commit_path | (completed) | Nothing to order. Its landing changes 513 and 570 as noted. |

### 2. Edges to write

| # | Command target | Adds | Kind |
|---|---|---|---|
| 1 | 535 | 567 | territory (`test-git-commit-phase.sh`) |
| 2 | 486 | 541 | territory (`git-commit-phase.sh`) |
| 3 | 501 | 570 | territory (postflight) |
| 4 | 536 | 524 | semantic + territory (`git-commit-scoped.sh`) |
| 5 | 553 | 536 | territory (`git-commit-scoped.sh`) |
| 6 | 657 | 553 | territory (`git-commit-scoped.sh`, postflight) |
| 7 | 655 | 513 | semantic (detector ref seam) |

Resulting order on the commit scripts:

```
567 -> 535 -> 541 -> 486 -> 501 -> 524 -> 536 -> 553 -> 657 -> 655
                      570 --^                                   ^-- 513
```

Result of running this edge set against the live graph (script kept at `/tmp/claude-1000/-home-benjamin--config-nvim/94ae85c2-0054-4d16-8e1a-a056d6d03f03/scratchpad/sim.py`; the scratchpad is not durable):

- Acyclic: all 123 open tasks sort topologically.
- Unordered narrow-overlap pairs inside cluster + 655/656/657: 0 (from 33).
- Cost: 657 gains 17 open ancestors; the longest chain ending at 655 is 10 tasks.

The overlap test was exact-or-directory-prefix match on declared `file_scope`, excluding `__WHOLE_TREE__` and the two coarse paths. A second, differently shaped check compared declared scope against script names merely mentioned in descriptions: 508, 513, 535 and 541 mention `git-commit-scoped.sh` without declaring it, and 513, 517 and 535 mention the postflight script likewise. In each case the description disclaims an edit there, so no further edge is proposed; 513's option (b) is the one conditional exception.

Each edge is one call (all seven targets are `not_started`, so the `edge_only` vehicle applies):

```
bash .claude/scripts/update-task-status.sh preflight <N> edge_only <session_id> --depends-on-add='[<pred>]'
```

The deployed copy supports `edge_only` (19 occurrences) even though the dispatch reports the deployed `core` tree as stale; the flag runs the write-time cycle refusal itself. Verify afterwards with `jq '.active_projects[]|select(.project_number==N)|.dependencies' specs/state.json`.

**Why edge 6 sits on 657 and not 655.** 657 declares `git-commit-scoped.sh` and the postflight script and runs before 655. An edge only on 655 would leave six 657-versus-member pairs unordered. The catch is that 657's first element is a ruling that edits no script, and this edge delays it behind the whole chain. The alternative is to put the edge on 655 and accept those six pairs as serialized only by in-batch admission. I recommend the 657 placement; the planner should confirm it, because it trades ruling latency for ordering.

### 3. Revisions to apply (stale premises)

Per the memory note in the dispatch, a dispatched agent cannot use `/revise`; the sanctioned route is the "For Description Update" `state-write.sh` object-merge block in `skill-reviser/SKILL.md` Stage 7. Append, do not replace.

**535.** Append a RE-MEASURED block stating:
- the own-task-directory admission is present in `git-commit-phase.sh` and pinned by Cases 15-16, so route (a) is done and must not be re-implemented;
- remaining work is (i) correct the "structurally outside its reach" sentence in `git-staging-scope.md`'s Staging-Layer Containment Filter subsection, (ii) add the dotfile-at-task-directory-root fixtures (`.return-meta.json`, `.orchestrator-handoff.json`) and the assertion that the completeness check runs in the single-plan-file case, if Cases 15-16 do not already cover them;
- transplanted criterion (c) (single source of truth for runtime-class membership) is moot, because the landed carve-out is path-shaped.

**536.** Append a RE-MEASURED block stating:
- `commit-source-store-path.sh` already commits a source-store path in its own repository at phase closure, so the `--repo-root` option on `git-commit-scoped.sh` is no longer the default candidate;
- the open remainder of part (1) is the foreign-hunk case and any commit outside phase closure, to be decided after 524 rules on sub-file staging;
- part (2), registration-description review, is unchanged;
- the ruling that source-store commit scoping is not a prerequisite for branch-aware orchestration.

### 4. The three judgment calls

**Judgment 1. Are source-store commit scoping and the third containment site hard prerequisites? No.**

- Which branch a commit lands on is fixed by `HEAD` in the repository where `git commit` runs. `git-commit-scoped.sh` does `cd "$PROJECT_ROOT"` and commits; V10 only removes entries from the pathspec list beforehand and reports exit 7 as observability. Neither touches a ref.
- A path V10 strips stays uncommitted in the working tree today, on any branch. Branch targeting neither causes nor worsens that.
- The premise "cannot target a chosen repository, so cannot target a chosen branch" does not hold: the second-repository case is already served by a separate script, not by `git-commit-scoped.sh`.
- What would change this ruling: a 655 design that routes the landing commit through `git-commit-scoped.sh --task` in a second repository.

One scope statement 655 must make as a result: a source-store path committed by `commit-source-store-path.sh` lands on whatever branch the second repository has checked out. Element C's "phase commits land on that branch" is not true for those commits unless 655 designs for it, and that script is not in 655's `file_scope`.

**Judgment 2. Should 592 be revised so an admission-time branch check satisfies it? No; they are separate defects.**

- 592's object is the description's hand-authored claims about tree content. Its cited entry `iss_1794371652447_TTinEN` (now under `~/Projects/BimodalLogic/specs/archive/917_.../issues.jsonl`) reads: the block "names THREE landed depth-0 cell-equality schemas; the tree now carries FIVE".
- 655 element A's object is the ref the invocation starts from.
- Counterfactual: in that incident the dispatch ran on the right branch and the description was stale against that same branch. A branch check passes; the defect remains.
- Right fix site for 592 stays the dispatch composer (`orchestrate-build-dispatch.sh`), under its emits-not-adjudicates ruling.

Addendum for 592: record this ruling, and add one constraint. If the age carrier is ever a commit SHA, it must not be one reachable only from a work branch, since a squash landing would orphan it; prefer the timestamp or the existing `description_fingerprint`. No edge: 592 and 655 share no file.

**Judgment 3. Should 513 cover branch target in the same pass? Yes; one detector.**

- 513's proposed check is "for every completed phase, a `task {N} phase {P}` commit exists". That is a `git log` query, and a `git log` query always names a ref. Giving it the expected ref makes existence and branch target one query; a commit found under `--all` but not reachable from the expected ref is the wrong-branch finding.
- Two detectors would read the same plan markers and the same commit set twice and could disagree.
- Sequencing: 513 lands first with a ref parameter defaulting to `HEAD`; 655 passes the resolved work branch. Hence edge 7.

Revision for 513 (append):
1. The check takes an expected-ref parameter, default `HEAD`, and reports "commit exists but not on the expected ref" as a finding class distinct from "no commit".
2. It runs before any squash landing, or reads the pre-squash ref; after a squash, per-phase commits are intentionally absent from the integration branch.
3. Shape 1 matching must be subject-only. 513's own repro uses `git log --grep`, which also searches bodies, and 655 element D puts the phase list in the squash commit body.
4. A phase whose only changes were gitignored `specs/` paths legitimately has no commit (`git-commit-scoped.sh` exit 8); the check must not count it.

Also append to 570: the ignored-specs blind spot above, and a request that the chosen attribution be keyed on the commit message's task/phase marker rather than on `TASK_DIR` paths, so 655 element D can reuse it.

### 5. Decision record

Write `specs/decisions/commit-layer-cluster-ordering.md` (name suggested; siblings in that directory use descriptive kebab-case). Contents: the ruling table, the seven edges with kind and basis, the three judgments with the deciding evidence, and the inputs to 655 listed under Risks.

## Decisions

- Treated `git-staging-scope.md` and `general-implementation-agent.md` as coarse; no edge is proposed for an overlap on those alone.
- Gave each member exactly one primary ruling, as the task requires, and listed edges separately so a revised member can still sit in the chain.
- Did not propose edges between cluster members and open non-members. The residual unordered overlaps are listed under Risks.
- Did not set `user_decision`. The one preference-shaped choice (edge 6 placement) has a recommended default and is reversible with `--depends-on-remove`.
- Wrote no edges and no description changes in this phase.

## Risks & Mitigations

- **Chain length.** A single chain of ten delays small costly fixes behind large ones only where I could not avoid it (553 behind 501 and 524). Mitigation: 567, 535, 541 and 570 are placed at the front; if 553's cost matters more than its rebase risk, move it to depend on 567 alone and make 501 depend on it.
- **Topology may change.** If 657 reinstates any form of tree isolation, judgment 1's evidence (one `HEAD` per repository) needs re-reading, and 513's "expected ref" becomes per-tree. The ref parameter survives either way.
- **Unverified by execution.** The 570 blind spot and the 513 exit-8 exemption are derived from reading the code and `rules/git-workflow.md`, not from a fixture. The edge simulation used my own reimplementation of the overlap and cycle tests, not `validate-state.sh --deep`; the real `--depends-on-add` call re-checks cycles at write time.
- **Residual overlaps with open non-members** (unordered after the seven edges; outside the named cluster, so not ruled on):
  - `git-commit-scoped.sh`: 548 and 598 (`v10_containment_remedy_for_coupled_pair_paths`) against 501, 524, 536, 567; 598 against 553; 484 against 567. 548 and 598 both work on V10, the block 567 edits.
  - `git-commit-phase.sh`: 484 against 535, 541; 639 (`make_issue_record_failures_visible`) against 486, 535, 541.
  - postflight: 551, 609, 639, 472 against 501 and/or 570.
  - composer: 520, 571, 639 against 592.
  - 618 (`working_tree_residue_disposition_policy`) edits `git-commit-scoped.sh` but declares no `file_scope`, so no overlap test can see it.
- **Inputs 655 should not miss** (for the decision record, not rulings on members):
  - Landing a squash on the integration branch by switching the single shared working tree would carry concurrent siblings' uncommitted edits across the switch; 524's evidence shows concurrent writers are the normal condition.
  - `specs/state.json` and `specs/TODO.md` ride in every task's commits, so per-task ranges on a shared branch are not separable by path for those two files.
  - `git-snapshot.sh --branch` moves `HEAD` off the work branch during a snapshot.

## Context Extension Recommendations

none (meta task)

## Appendix

- Overlap and edge simulation: `/tmp/claude-1000/-home-benjamin--config-nvim/94ae85c2-0054-4d16-8e1a-a056d6d03f03/scratchpad/overlap.py` and `/tmp/claude-1000/-home-benjamin--config-nvim/94ae85c2-0054-4d16-8e1a-a056d6d03f03/scratchpad/sim.py` (session scratch; re-create from the predicate described in section 2 if gone).
- Key greps: `git checkout -b|git switch -c|rev-parse --abbrev-ref|symbolic-ref` over `scripts/` and `hooks/`; `containment_scope_arr` in `git-commit-scoped.sh`; `file_scope_arr+=` and `is_contained` in `git-commit-phase.sh`; `startswith($f)` and `stall_commit_count=` in the postflight script; `git log -S'file_scope_arr+=("${task_dir}/")'`.
- Issue log: one `stale premise` entry recorded for this dispatch (535 and 536).
