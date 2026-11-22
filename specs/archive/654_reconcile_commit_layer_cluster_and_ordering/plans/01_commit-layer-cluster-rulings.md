# Implementation Plan: Task #654

- **Task**: 654 - Reconcile the open commit-layer cluster and write its dependency ordering
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/654_reconcile_commit_layer_cluster_and_ordering/reports/01_commit-layer-cluster-rulings.md
- **Artifacts**: plans/01_commit-layer-cluster-rulings.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research report ruled on all thirteen cluster members and settled the three judgment calls, but wrote nothing to `specs/state.json`. This plan turns those rulings into state: seven dependency edges, description revisions on the four NEEDS REVISION members (plus two addenda the rulings imply), and one decision record under `specs/decisions/`. No script and no file under `agent-system/**` or `.claude/**` is edited. The task is done when every ruling in the decision record has a matching, jq-checkable change in `specs/state.json`.

### Research Integration

Integrated from `reports/01_commit-layer-cluster-rulings.md`:

- Ruling tally: NEEDS EDGE 7 (486, 501, 524, 541, 553, 567, 570), NEEDS REVISION 4 (513, 535, 536, 592), UNAFFECTED 2 (508, 517), SUBSUMED 0. The fourteenth member named by the roadmap annotation (658) is completed and needs nothing.
- Seven edges producing the order `567 -> 535 -> 541 -> 486 -> 501 -> 524 -> 536 -> 553 -> 657 -> 655`, with `570 -> 501` and `513 -> 655` as side entries.
- Judgment 1: NO (neither source-store commit scoping nor the third containment site is a hard prerequisite for branch targeting). Judgment 2: NO (two separate defects; the dispatch composer stays the fix site). Judgment 3: YES (one detector with an expected-ref parameter).
- Two member descriptions (535, 536) are stale against the source store and are revised here.

Premise re-validation for this dispatch (the two flagged description lines):

- "This task is expected to modify NO script at all": confirmed. Every file in this plan's `Files to modify` blocks is under `specs/`.
- Judgment call 1's premise ("cannot target a chosen repository ... plausibly cannot target a chosen BRANCH"): the report rules it does not hold, on the evidence that `commit-source-store-path.sh` already serves the second-repository case. Checked live in this dispatch: all thirteen members are still `not_started`, their `dependencies` arrays match the report's table, and none of the seven edges is present yet.

One report claim did not survive the check: it says an edge is reversible with `--depends-on-remove`. `update-task-status.sh` has no such flag in either the deployed copy or the source store. Edge reversal is a `state-write.sh` jq removal (see Rollback/Contingency).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists, but `roadmap_flag` is not set for this task, so the plan carries no roadmap phases. This task is the root of the branch strand (656, 657 and 655 all depend on it); the roadmap is regenerated from `state.json` at orchestration conclusion and will pick up the new edges without a hand edit.

## Goals & Non-Goals

**Goals**:
- Write the seven edges with `update-task-status.sh preflight <N> edge_only ... --depends-on-add`.
- Apply the description revisions for 513, 535, 536 and 592, and the addenda for 570, 655 and 657.
- Write `specs/decisions/commit-layer-cluster-ordering.md` with every ruling, its basis, the edges, and the three judgments.
- Leave a ruling-to-state-change audit showing no ruling is missing its state change.

**Non-Goals**:
- Any edit to `git-commit-scoped.sh`, `git-commit-phase.sh`, `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, or any other file outside `specs/`.
- Implementing any cluster member, or fixing the defects the re-measurement found (the 570 ignored-specs blind spot, the false sentence in `git-staging-scope.md`). Those are recorded on the owning task.
- Ordering cluster members against open non-members (548, 598, 484, 639, 551, 609, 472, 520, 571, 618). These are listed in the decision record as residual, not ruled on.
- Editing `specs/ROADMAP.md` or `roadmap_batches`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A sibling task in the same session changes a member's status or dependencies between the report and the write | M | M | Phase 1 re-reads all fifteen affected tasks immediately before writing; a member that has gone terminal drops its edge and the record says so |
| A description append overwrites a concurrent edit to the same task | H | L | Append inside the `state-write.sh` jq expression (`.description += $addendum`), never read-then-replace with a shell-held copy |
| The write-time cycle refusal rejects an edge | M | L | The report's simulation found the set acyclic, but with its own reimplementation; on a refusal, stop, record the refused edge and the cycle path, and do not substitute a different edge |
| Edge 6 delays the topology ruling (657) behind the whole chain | M | H (by design) | Accepted; see Decisions. Fallback placement is stated there |
| Task numbers in appended descriptions go stale at a vault renumber | L | M | Every appended block names tasks by `project_name` slug first, number second |
| The decision record is dropped from the phase commit by the containment filter | M | M | Its path is declared in Phase 4's `Files to modify`, which the plan-postflight harvest merges into `file_scope` |

## Decisions

- **Edge 6 goes on 657, not 655.** The report asked the planner to confirm. 657 declares `git-commit-scoped.sh` and `orchestrate-cycle-postflight.sh` and runs before 655; an edge on 655 alone leaves six 657-versus-member pairs unordered. The latency cost is smaller than it looks: 655 is 657's only dependent, and 655 waits for the chain under either placement, so the only thing delayed is 657's own ruling and automation. If the user later wants that ruling early, the fallback is to remove `553` from 657's dependencies and add it to 655's.
- **Phases run strictly in sequence.** Phases 2 and 3 both write `specs/state.json` and both regenerate `specs/TODO.md`; running them in one wave would put two phase commits on the same two files.
- **570 gets an addendum although its ruling is NEEDS EDGE.** One primary ruling per member is the task's rule; the addendum records a re-measured fact (the ignored-specs blind spot) and an attribution request, and does not change 570's scope.
- **655 and 657 each get a one-paragraph pointer to the decision record.** Neither is a cluster member, but the report lists inputs 655 must not miss, and a record nobody is pointed at will not be read. This is a planning addition, not a research recommendation.
- **No `user_decision` is set.** Every choice here is reversible by a state write.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Baseline and Premise Re-Check [COMPLETED]

**Goal**: Capture the before-state of every task this plan writes to, and confirm the report's premises still hold at write time.

**Tasks**:
- [x] Save the current `status`, `dependencies` and description length of tasks 486, 501, 508, 513, 517, 524, 535, 536, 541, 553, 567, 570, 592, 655 and 657 to `specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` (one jq query over `specs/state.json`). *(completed)*
- [x] Save the full pre-change `description` of 513, 535, 536, 570, 592, 655 and 657 into the same file, so a revision can be reverted exactly. *(completed)*
- [x] Confirm each of the seven edge targets (535, 486, 501, 536, 553, 657, 655) is still `not_started`. For a target that has moved, use the status-replay pair for its current status instead of `edge_only`, as the `--depends-on-add` header in `update-task-status.sh` describes. For a target or predecessor that has gone terminal, drop that edge and note it for Phase 4. *(completed)*
- [x] Re-check the two stale-premise anchors against the source store: `grep -n 'file_scope_arr+=("${task_dir}/")' agent-system/extensions/core/scripts/git-commit-phase.sh` (535) and `ls agent-system/extensions/core/scripts/commit-source-store-path.sh` (536). If either is absent, do not apply that member's RE-MEASURED block in Phase 3; record the member as "premise could not be re-confirmed" in Phase 4 instead. *(completed)*
- [x] Run `bash .claude/scripts/validate-state.sh --deep` and record its exit status as the pre-change baseline. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Fifteen tasks are written to or read as predecessors (thirteen members plus 655 and 657), and all seven edge targets are `not_started`. Both figures were true when this plan was written; the implementer confirms them with the first and third tasks above.

**Tier Justification**: The only file written is a task-local JSON snapshot under `specs/`; `jq empty specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` covers it.

**Files to modify**:
- `specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` - new; before-state of the fifteen tasks and seven descriptions

**Verification**:
- `baseline.json` parses and holds fifteen task entries and seven full descriptions.
- The `validate-state.sh --deep` baseline exit status is recorded.

---

### Phase 2: Write the Seven Dependency Edges [COMPLETED]

**Goal**: Put every NEEDS EDGE ruling, and the edge judgment 3 requires, into `specs/state.json`.

**Tasks**:
- [x] For each row below, run `bash .claude/scripts/update-task-status.sh preflight <target> edge_only "$session_id" --depends-on-add='[<pred>]'`, one call per edge, in this order: *(completed)*

  | # | Target (gains the dependency) | Predecessor | Kind |
  |---|---|---|---|
  | 1 | 535 phase_commit_drops_own_plan_artifact | 567 port_containment_strip_to_git_commit_scoped | territory |
  | 2 | 486 manifest_registration_dropped_from_phase_commit | 541 snapshot_artifacts_contaminate_phase_commits | territory |
  | 3 | 501 cycle_postflight_containment_parity | 570 stall_signal_counts_unattributed_commits | territory |
  | 4 | 536 source_store_commit_and_registration_review | 524 scoped_commit_staged_vs_worktree_divergence | semantic + territory |
  | 5 | 553 git_commit_scoped_gate_refusal_diagnostic | 536 source_store_commit_and_registration_review | territory |
  | 6 | 657 branch_topology_ruling_and_milestone_automation | 553 git_commit_scoped_gate_refusal_diagnostic | territory |
  | 7 | 655 branch_aware_orchestration_and_squash_landing | 513 phase_commit_boundary_mechanical_check | semantic |

- [x] After each call, confirm the edge with `jq '.active_projects[]|select(.project_number==<target>)|.dependencies' specs/state.json`. *(completed)*
- [x] If the write-time cycle refusal rejects an edge, stop the phase, record the refused edge and the reported cycle, and mark the phase `[PARTIAL]`. Do not invent a replacement edge. *(completed)*
- [x] Run `bash .claude/scripts/validate-state.sh --deep` after all seven are written. *(completed)*
- [x] Run the drain confirmation the `--depends-on-add` header assigns to the caller: `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json 567 535 541 486 570 501 524 536 553 513 657 655`. A report that a member is blocked by an open non-member (for example 484 or 548) is expected and is not a failure; a report of a cycle or an undrainable set is. *(completed)*
- [x] Regenerate `specs/TODO.md` with `bash .claude/scripts/generate-todo.sh` if the edge calls did not already do so. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly seven edges are written, and no existing dependency is removed. Confirm by diffing each target's `dependencies` against `baseline.json`: each of the seven targets gains exactly one number and loses none.

**Tier Justification**: The edit is confined to `dependencies[]` in `specs/state.json`; `bash .claude/scripts/validate-state.sh --deep` (the cycle and schema check the edge primitive itself reuses) covers it.

**Files to modify**:
- `specs/state.json` - seven `dependencies[]` additions
- `specs/TODO.md` - regenerated from `state.json`

**Verification**:
- All seven jq queries show the predecessor in the target's `dependencies`.
- `validate-state.sh --deep` exits no worse than the Phase 1 baseline.
- The drain dry-run reports no cycle.

---

### Phase 3: Apply Description Revisions and Addenda [COMPLETED]

**Goal**: Put every NEEDS REVISION ruling into the affected task's `description`, and record the re-measured facts that other tasks must not miss.

**Tasks**:
- [x] Write each block below to a scratch text file, then append it with one `state-write.sh` call per task, using the object-update shape from `skill-reviser/SKILL.md`'s "For Description Update" block but appending in jq: `(.active_projects[] | select(.project_number == $num)) |= (.description += ("\n\n" + $add) | .last_updated = $ts)`, with `--session-id`, `--arg add`, `--arg ts`, `--argjson num`. Never replace a description with a shell-held copy. Pass `--regen-todo` on the last call only. *(completed)*
- [x] Each block opens with the heading line `RE-MEASURED AND RULED (commit-layer cluster ordering, specs/decisions/commit-layer-cluster-ordering.md):` so the audit in Phase 5 can find it. *(completed)*
- [x] **535 (NEEDS REVISION)**: the own-task-directory admission is present in `git-commit-phase.sh`'s Containment Self-Check and pinned by `test-git-commit-phase.sh` Cases 15 and 16, so route (a) is done and must not be re-implemented. Remaining work: correct the "structurally outside its reach" sentence in `git-staging-scope.md`'s Staging-Layer Containment Filter subsection; add the task-directory-root dotfile fixtures (`.return-meta.json`, `.orchestrator-handoff.json`) and the single-plan-file completeness assertion if Cases 15 and 16 do not cover them. Transplanted criterion (c) is moot because the landed carve-out is path-shaped. Now ordered after `port_containment_strip_to_git_commit_scoped`. *(completed)*
- [x] **536 (NEEDS REVISION)**: `commit-source-store-path.sh` already commits a source-store path in its own repository at phase closure, so a `--repo-root` option on `git-commit-scoped.sh` is not the default candidate. Open remainder of part (1): the foreign-hunk case and any commit outside phase closure, decided after `scoped_commit_staged_vs_worktree_divergence` rules on sub-file staging (now a dependency). Part (2), the registration-description review, is unchanged. Ruling: source-store commit scoping is not a prerequisite for branch-aware orchestration. *(completed)*
- [x] **513 (NEEDS REVISION)**: the check covers commit branch target in the same pass. (1) It takes an expected-ref parameter, default `HEAD`, and reports "commit exists but is not on the expected ref" as a finding class distinct from "no commit". (2) It runs before any squash landing, or reads the pre-squash ref. (3) Matching is subject-only, not `git log --grep`, which also searches bodies. (4) A phase whose only changes were gitignored `specs/` paths has no commit by design (`git-commit-scoped.sh` exit 8) and must not be counted. `branch_aware_orchestration_and_squash_landing` now depends on this task and passes the resolved work branch. *(completed)*
- [x] **592 (NEEDS REVISION)**: scope unchanged. Ruling: an admission-time branch check does not satisfy this task; the cited incident ran on the correct branch with a description stale against that same branch. The fix site stays the dispatch composer. Added constraint: if the age carrier is ever a commit SHA, it must not be one reachable only from a work branch, since a squash landing orphans it; prefer the timestamp or the existing `description_fingerprint`. *(completed)*
- [x] **570 (addendum; ruling is NEEDS EDGE)**: both stall probes are `git log --since=... -- "$TASK_DIR"`, which is structurally zero in a repository whose `specs/` is gitignored, so `stall_suspected` cannot fire there (read from the code, not reproduced in a fixture). Request: key the chosen attribution on the commit message's task/phase marker, not on `TASK_DIR` paths, so the branch feature's per-task attribution can reuse it. `cycle_postflight_containment_parity` now depends on this task. *(completed)*
- [x] **655 (pointer)**: name the decision record and list the inputs it carries for this task: source-store commits made by `commit-source-store-path.sh` land on whatever branch the second repository has checked out; switching the single shared working tree to land a squash carries concurrent siblings' uncommitted edits; `specs/state.json` and `specs/TODO.md` ride in every task's commits; `git-snapshot.sh --branch` moves `HEAD` during a snapshot. Now depends on `phase_commit_boundary_mechanical_check`. *(completed)*
- [x] **657 (pointer)**: name the decision record; state that this task is now ordered after `git_commit_scoped_gate_refusal_diagnostic` by file territory, and that judgment 1's evidence (one `HEAD` per repository) must be re-read if this task reinstates any form of tree isolation. *(completed)*
- [x] Do not touch the descriptions of 486, 501, 508, 517, 524, 541, 553 or 567. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: Seven descriptions change (513, 535, 536, 570, 592, 655, 657) and each only grows. Confirm against `baseline.json`: for each of the seven, the new description starts with the baseline description byte-for-byte; for the other eight tasks the description is unchanged.

**Tier Justification**: The edit is confined to `description` strings in `specs/state.json`; `bash .claude/scripts/validate-state.sh --deep` plus the prefix comparison against `baseline.json` named in the Scope Hypothesis covers it.

**Files to modify**:
- `specs/state.json` - seven `description` appends
- `specs/TODO.md` - regenerated from `state.json`

**Verification**:
- `jq -r '.active_projects[]|select(.description|contains("RE-MEASURED AND RULED (commit-layer cluster ordering"))|.project_number' specs/state.json` lists exactly 513, 535, 536, 570, 592, 655, 657.
- The prefix comparison passes for all seven and the other eight are unchanged.
- `validate-state.sh --deep` exits no worse than the Phase 1 baseline.

---

### Phase 4: Write the Decision Record [COMPLETED]

**Goal**: State the ordering and its basis in one durable record that matches the state actually written.

**Tasks**:
- [x] Create `specs/decisions/commit-layer-cluster-ordering.md`, following the shape of its siblings in `specs/decisions/` (title line, short statement of what the record decides, then sections). *(completed)*
- [x] Section "Rulings": one row per member (thirteen, plus the completed ignored-specs member as "completed, nothing to order"), each with slug, number, ruling, basis, and the state change that carries it (edge number, "description revised", or "none" for UNAFFECTED). For 508 and 517, include the falsification condition from the report. *(completed)*
- [x] Section "Edges": the seven edges as actually present in `state.json` after Phase 2, with kind and basis, the resulting order diagram, and the reason edge 6 sits on 657. If Phase 1 or Phase 2 dropped or failed to write an edge, say so here; do not list an edge that is not in `state.json`. *(completed)*
- [x] Section "Judgment calls": the three answers with the deciding evidence and, for judgment 1, what would change the ruling. *(completed)*
- [x] Section "Re-measured premises": 535 and 536 stale, 501 line numbers moved and its co-admission annotation moot, the 570 blind spot, each marked as read from code or reproduced. *(completed)*
- [x] Section "Inputs to the branch feature": the four items appended to 655 in Phase 3. *(completed)*
- [x] Section "Not ruled on": the residual overlaps with open non-members, and 618 as invisible to any overlap test because it declares no `file_scope`. *(completed)*
- [x] Section "How this was checked": the overlap predicate (exact-or-directory-prefix on declared `file_scope`, excluding `__WHOLE_TREE__`, `git-staging-scope.md` and `general-implementation-agent.md`), the before/after unordered-pair figures as the report's own simulation result, and a statement that the simulation was a reimplementation while the write-time cycle check was the real one. *(completed)*
- [x] Name tasks by slug with the number alongside. The record lives under `specs/`, so task numbers are permitted. *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: prose

**Scope Hypothesis**: The record carries fourteen ruling rows and seven edge rows. The figures "33 unordered pairs before, 0 after" and "123 open tasks sorted" come from the report's scratch simulation, which is not durable and was not re-run here; the record attributes them to that simulation and does not restate them as independently verified.

**Tier Justification**: A new markdown file wholly under `specs/**`, which plan-format.md's `__FULL_SWEEP__` sub-case (a) assigns to the `prose` row's diff read-through; no suite or gate covers it.

**Files to modify**:
- `specs/decisions/commit-layer-cluster-ordering.md` - new decision record

**Verification**:
- Every edge row in the record matches a jq query against `state.json`.
- Every NEEDS REVISION row names a task whose description carries the Phase 3 heading line.
- The record contains all three judgment answers.

---

### Phase 5: Ruling-to-State-Change Audit [COMPLETED]

**Goal**: Show that no ruling is missing its state change, and close the task's verification obligation.

**Tasks**:
- [x] For each NEEDS EDGE member (486, 501, 524, 541, 553, 567, 570), confirm with jq that it appears as target or predecessor in at least one of the seven edges present in `state.json`. *(completed)*
- [x] For each NEEDS REVISION member (513, 535, 536, 592), confirm its description carries the Phase 3 heading line. *(completed)*
- [x] For each UNAFFECTED member (508, 517), confirm its `dependencies` and description are identical to `baseline.json`. *(completed)*
- [x] Confirm no file outside `specs/` was modified by this task: `git status --short -- agent-system .claude` shows nothing attributable to this task, and in particular the four commit-layer scripts are untouched. *(completed)*
- [x] Run the scoped touched-path check: `bash .claude/scripts/verify-touched.sh --task-dir specs/654_reconcile_commit_layer_cluster_and_ordering`. *(completed)*
- [x] Run `bash .claude/scripts/validate-state.sh --deep` one last time. *(completed)*
- [x] Record in the phase's verification notes that the complete gate set is deferred to the orchestration close. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` - audit results appended under an `audit` key

**Verification**:
- All thirteen member checks pass; any that fails is reported as an incomplete deliverable, not waived.
- The scoped touched-path check (`verify-touched.sh`) is run and its verdict recorded. Under `/orchestrate`, the complete gate set (`bash .claude/scripts/verify-deploy.sh`) is deferred to the orchestration close and is not run independently by this phase; a standalone run of this plan runs it directly.

## Testing & Validation

- [x] Seven jq queries, one per edge, each showing the predecessor in the target's `dependencies`. *(completed)*
- [x] `validate-state.sh --deep` no worse than the pre-change baseline after Phases 2, 3 and 5. *(completed)*
- [x] Drain dry-run over the twelve chained tasks reports no cycle. *(completed)*
- [x] Seven descriptions carry the heading line and each begins with its baseline text. *(completed)*
- [x] Decision record's edge and revision rows all match `state.json`. *(completed)*
- [x] No path outside `specs/` modified. *(completed)*

## Artifacts & Outputs

- `specs/state.json` - seven new edges, seven description appends
- `specs/TODO.md` - regenerated
- `specs/decisions/commit-layer-cluster-ordering.md` - decision record
- `specs/654_reconcile_commit_layer_cluster_and_ordering/baseline.json` - before-state and audit results
- `specs/654_reconcile_commit_layer_cluster_and_ordering/summaries/01_commit-layer-cluster-rulings-summary.md` - implementation summary

## Rollback/Contingency

Every change is a state write, so reversal is also a state write; no working-tree rollback or snapshot is needed.

- **An edge**: `update-task-status.sh` has no removal flag. Remove one with `state-write.sh`, for example `(.active_projects[] | select(.project_number == $num)).dependencies -= [$pred]` with `--argjson num` and `--argjson pred`, then regenerate `TODO.md`.
- **A description append**: restore the exact pre-change text from `baseline.json` with the "For Description Update" `state-write.sh` block, after checking that the current description still equals baseline plus the appended block (so a later, unrelated edit is not lost).
- **The decision record**: delete the file, or correct it in place if the state it describes changed.
- **Partial completion**: if Phase 2 stops on a cycle refusal, the edges already written stay; the decision record then lists only edges present in `state.json` and names the refused one.
