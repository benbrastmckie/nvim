# Implementation Plan: Task #657

- **Task**: 657 - Branch-topology ruling, then milestone automation and review gates
- **Status**: [IMPLEMENTING]
- **Effort**: 10.5 hours
- **Dependencies**: 654 (completed), 656 (completed)
- **Research Inputs**: specs/657_branch_topology_ruling_and_milestone_automation/reports/01_branch-topology-milestone-automation.md
- **Artifacts**: plans/01_branch-topology-milestone-automation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task rules first and implements second. Phase 1 writes the branch-topology and
landing-strategy ruling as a decision record; Phase 2 writes the state changes that ruling
implies (one dependency edge, one task-description revision, one amendment note). Phases 3-6 then
build the automation Element 2 asks for on top of the ruling: a milestone review ref landed by
git ref plumbing at each task's completion transition, a milestone-completion prepare-and-handoff
step that routes through the existing consent-gated push path without ever pushing, and the
reconciliation of the written Branch Strategy standard with the mechanism actually built. Phase 7
redeploys and closes.

Every source-store edit targets `agent-system/extensions/core/**` in this repository (the
resolved `source_dir`), never a deployed `.claude/**` path, and carries no task-number reference
and no record-versioning language — both are lint-enforced outside `specs/**`.

### Premise Re-Validation

Each figure the dispatch and the research report carry forward was re-derived against live state
before this plan was written. Two are stale and this plan corrects them; the rest confirm
unchanged.

1. **Source store — CONFIRMED.** `jq -r '.extensions.core.source_dir' .claude-extensions.json`
   returns `/home/benjamin/.config/nvim/agent-system/extensions/core`. The edit target the
   dispatch names is correct.
2. **Binding evidence — CONFIRMED PRESENT.** `specs/decisions/worktree-isolation-removal-verdict.md`
   (14698 bytes) and `specs/decisions/worktree-isolation-removal-reaffirmation.md` (17313 bytes)
   both exist and are readable. Phase 1 reads both in full; this plan does not substitute the
   report's summary of them for that read.
3. **Consent-gated push mechanism — CONFIRMED PRESENT.** All five named surfaces exist in the
   source store: `hooks/please-grant.sh`, `hooks/guard-git-push.sh`, `scripts/git-push-granted.sh`,
   `commands/please.md`, `commands/merge.md`, plus `rules/pr-prohibition.md`.
4. **Zero branch awareness — CONFIRMED.** `grep -rn "git checkout -b\|git switch -c"` across the
   core extension's `scripts/` and `hooks/` returns exactly one hit,
   `scripts/git-snapshot.sh:493`, inside its `--branch` rollback path.
5. **CORRECTION — the `657 -> 553` edge is already resolved the other way, and must NOT be
   written.** The dispatch's ORDERING block ("this task now depends on
   `git_commit_scoped_gate_refusal_diagnostic` (553)") and the research report's Element 2
   recommendation 5 ("add `657 depends on 553`") are both stale. That edge was deliberately moved
   off this task and onto `branch_aware_orchestration_and_squash_landing` (655) — the remedy the
   cluster record itself names for the case where the ruling is wanted early. Live state:
   657's `dependencies` are `[654, 656]`; 655's are `[513, 553, 654, 657]`; and
   `specs/decisions/commit-layer-cluster-ordering.md`'s Edge 6 row names 655 as the target. Phase
   2 therefore does not re-add it; re-adding it would park this task's ruling behind the whole
   ten-task commit-layer chain, the exact outcome the move avoided.
6. **CORRECTION — the ROADMAP discrepancy the report flagged no longer reproduces.** The report
   recorded `specs/ROADMAP.md` printing `657 blocked:553` against a `state.json` that carried no
   such dependency. `specs/ROADMAP.md` now renders `657 ready` and
   `655 blocked:513,553,657`, consistent with `state.json`. No investigation of that
   discrepancy is carried into this plan.
7. **REFINEMENT — the schema already has the field the review gate needs, so no new status value
   is invented.** The report's Element 2 recommendation 1 proposed flipping
   `roadmap_milestones[].progress.status` to a value meaning "awaiting review" and leaving
   `review` alone. That is not available: `progress.status` is a closed vocabulary
   (`planned`/`active`/`closed`, per `context/formats/roadmap-format.md`'s field table and
   `context/schemas/state-schema.json`), so a new value would require changes to both of those
   files, neither of which is in this task's `file_scope`. Meanwhile `review.state`'s own enum
   already contains `prepared`, and `review.ref` is documented as "Branch or ref carrying the
   milestone's work" — the exact pair this handoff produces. This plan therefore writes
   `review.state: "prepared"` plus `review.ref`, and leaves `progress.status` to `/roadmap`'s
   judgment. See `## Decisions`, D4.
8. **Branch Strategy prose — RE-MEASURED.** The report called it "eleven lines"; measured, the
   `## Branch Strategy` section of `context/standards/git-workflow-narrative.md` spans lines
   235-247 (heading through the optional `task-{N}-{slug}` fenced block). Phase 6 replaces that
   span; the line numbers are a hypothesis to re-confirm then, not an anchor to trust.
9. **Milestone store — CONFIRMED.** `roadmap_milestones` holds exactly one entry: `M1`
   ("Current work"), 30 batches, `progress.status: "active"`, `review.state: "none"`.
10. **The ruling does not trigger the dispatch's `CONDITION ON A RULING`.** That condition fires
    only if this task reinstates some form of tree isolation. It does not (Phase 1, ruling R5), so
    the one-HEAD-per-repository premise holds and
    `phase_commit_boundary_mechanical_check` (513)'s expected ref stays per-repository rather than
    becoming per-tree. Phase 2 records that confirmation rather than leaving it implicit.

### Research Integration

The report's central finding drives the design: the controlling hazard for a branch feature in
this system is not squash-content interleaving but `checkout` itself, which repoints the one
shared working tree's `HEAD` for every concurrent session. The design therefore avoids the hazard
structurally — phase commits stay on the already-checked-out branch, and each milestone's
review-ready history is built with `git commit-tree` + `git update-ref`, which touch neither the
working tree, the index, nor `HEAD`.

Two of Element 2's four automation points are already built and need confirmation rather than
construction: `orchestrate-conclusion-roadmap.sh` already regenerates `specs/ROADMAP.md`
unconditionally at Move 4 of every invocation, and `orchestrate-batch-gate.sh` already runs the
complete gate set once per invocation whenever any implement dispatch occurred. Phase 1 records
both as rulings so no parallel path is built; Phase 5 adds the one genuinely unbuilt piece.

Where this plan departs from the report, it says so in `### Premise Re-Validation` (items 5, 6,
7) and in `## Decisions`.

### Prior Plan Reference

No prior plan. `plans/` is empty for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap consultation was performed beyond
reading `roadmap_milestones` out of `specs/state.json` as implementation input. This task sits
under milestone `M1` in that store. The `roadmap_flag` is not set, so no roadmap review/regenerate
phases are added; Phase 7's redeploy path leaves ROADMAP.md regeneration to the existing
conclusion-stage caller, which runs unconditionally.

## Goals & Non-Goals

**Goals**:
- Rule on branch granularity, merge strategy, landing mechanics, and worktree isolation, with the
  binding evidence read and the recorded data-loss mechanism engaged by name.
- Write the state changes the ruling implies: the one dependency edge it newly justifies, the
  revision to the branch-aware-orchestration task's description, and an amendment note on the
  commit-layer cluster record.
- Land each completed task's work onto its milestone's review ref by ref plumbing, verified before
  the task's completion status is written.
- Prepare — never perform — the push and review request at milestone completion, handing the user
  the literal commands through the existing `/please` + `/merge` grant path.
- Record the two already-built Element 2 automation points as confirmed rather than rebuilding
  them.
- Make `context/standards/git-workflow-narrative.md`'s Branch Strategy prose describe the
  mechanism actually implemented.

**Non-Goals**:
- Reinstating per-dispatch worktree isolation in any form.
- Creating a branch per invocation, per task, or per milestone on the hot path.
- Any autonomous `git push`, PR/MR creation, `/merge` invocation, or grant minting — barred by
  `rules/pr-prohibition.md` and mechanically refused by `hooks/guard-git-push.sh`.
- Documenting the integration-branch declaration's schema in
  `context/standards/repo-level-declarations.md`. The ruling fixes the key's name and shape; the
  schema write and the admission-time enforcement belong to 655 (see `## Decisions`, D3).
- Narrowing `orchestrate-batch-gate.sh`'s existing trigger to batch membership.
- Expanding `progress.status`'s closed vocabulary, or touching
  `context/formats/roadmap-format.md` / `context/schemas/state-schema.json`.
- Editing `skills/skill-orchestrate/SKILL.md`. The new conclusion-stage step is reached from
  `orchestrate-conclusion-roadmap.sh`, which Move 4 already calls (see `## Decisions`, D5).
- Automatic rebasing of a milestone ref onto a moved integration-branch tip.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A wrong `commit-tree` invocation silently creates a commit with the wrong tree or parent | H | M | Phase 3's suite asserts, per simulated landing, the ref's commit count, its parent chain, and tree equality against the live branch — the same rigor `test-git-commit-scoped.sh` applies to the other commit primitives |
| Two tasks in one milestone land at the same instant and one `update-ref` silently drops the other's commit | H | L | Use the three-argument compare-and-swap form `git update-ref <ref> <new> <old>`, which fails if the ref moved; serialize retry through the existing task lock rather than a new lock |
| The completion status is written although the milestone-ref landing did not happen — the exact defect the reaffirmation record's live incident recorded | H | M | Phase 4 verifies the landing (`git merge-base --is-ancestor`) BEFORE `skill_postflight_update`, and refuses the completion write on failure, following the existing exit-6 deploy-pending refuse-and-defer shape rather than inventing a new one |
| The handoff step is read as authorization and something pushes | H | L | The handoff writes text and state only; it never calls `git push`, `git-push-granted.sh`, `gh`, or `/merge`, and never writes the grant store (`guard-git-push.sh` blocks that unconditionally anyway). Phase 5's suite asserts the absence of every such call |
| A milestone ref drifts far behind a fast-moving integration branch, producing a noisy review diff | M | M | Left explicitly to the human reviewer at review time, recorded as such in the ruling; no automatic rebase is built |
| `review.state: "prepared"` is written over a value a human set deliberately | M | L | Write only on the `none` -> `prepared` transition, and only when the milestone's derived `b_done == b` became true this invocation; never overwrite any other value |
| A new script is invisible to the deployed tree because its `manifest.json` entry is missing | M | M | `sync-manifest-scripts.sh --write` derives the entry from disk in the same phase that adds the script, and Phase 7 re-runs `--check` |
| The ruling is written without reading the binding evidence, making it out of order | H | L | Phase 1's first two tasks are the reads, and its verification criterion requires the named mechanism to appear in the record with its source |

## Decisions

- **D1 — The hot-path branch is whatever single branch is already checked out, verified rather
  than assumed.** No new branch is created during dispatch work at any granularity. This makes the
  measured "every phase commit lands on whatever branch the operator left checked out" behaviour
  the explicit design, and it removes the checkout hazard from the common path entirely. The
  admission-time check that the checked-out branch matches the declared integration branch stays
  655's Element A work, unchanged by this ruling.
- **D2 — A milestone's review history is built by ref plumbing, never by checkout or
  `git merge --squash`.** One squash commit per completed task is appended to
  `refs/heads/milestone/<id>` via `git commit-tree` + compare-and-swap `git update-ref`. 655's
  squash-per-task decision survives; only its mechanism changes. Rationale: `commit-tree` and
  `update-ref` touch neither working tree, index, nor `HEAD`, so a concurrent sibling in the same
  tree is structurally unaffected.
- **D3 — The ruling fixes the integration-branch declaration key; 655 documents and enforces
  it.** This task's scripts READ the key (with a loud advisory fallback to the current branch when
  it is undeclared); the schema row in `context/standards/repo-level-declarations.md` and the
  admission-time assertion are 655's. This keeps that file out of this task's territory and
  triggers the cluster record's own stated condition, which Phase 2 discharges as the one new
  edge: 655 gains 517 as a predecessor.
- **D4 — Milestone completion records `review.state: "prepared"` and `review.ref`, not a new
  `progress.status` value.** `review.state`'s enum already contains `prepared` and `review.ref` is
  defined as the ref carrying the milestone's work, so the handoff state is expressible within the
  existing closed vocabulary and bounds. This decides, for the mechanical-handoff case only, the
  question 656's follow-ups recorded as undecided ("nothing writes `review` except a `/roadmap`
  judgment pass"): the handoff writes it because `prepared` exists for exactly this state and
  nothing else can reach it at the moment the handoff is prepared. `review.request` stays empty —
  it is documented as a PR identifier or URL, and no PR exists until the user acts.
  `progress.status` and milestone closure stay `/roadmap`'s judgment.
- **D5 — The new conclusion-stage step is reached from `orchestrate-conclusion-roadmap.sh`, not
  from a new Move 4 call site.** That script is already called unconditionally at Move 4, already
  computes the milestone state the handoff needs, and is declared by no other open task. Adding a
  call site in `skills/skill-orchestrate/SKILL.md` would instead collide with five open tasks
  declaring that file.
- **D6 — `orchestrate-batch-gate.sh`'s existing trigger is kept as-is.** "Any implement dispatch
  happened" is a safe superset of "every batch member reached a terminal status"; the narrower form
  would require reading `roadmap_milestones[].batches[]` at a call site that uses no milestone
  data today, for strictly less testing. Element 2's batch-completion criterion is satisfied by
  recording this confirmation, not by new code.
- **D7 — This plan's territory deliberately excludes both scoped-commit scripts, which keeps the
  moved edge sound.** `git-commit-scoped.sh` and `git-push-granted.sh` are in this task's
  creation-time `file_scope` but no phase here touches either: the ref-plumbing landing is a new
  standalone script, and the handoff never invokes the push wrapper. The harvested per-phase file
  set therefore narrows this task's declared scope away from the commit-layer chain's shared
  surface, which is exactly the condition under which moving the `553` edge onto 655 (see
  `### Premise Re-Validation` item 5) is the right ordering. If implementation finds it genuinely
  must edit either script, that condition is falsified: stop and re-derive the edge rather than
  editing them under the narrowed scope.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 3 |
| 4 | 6 | 1, 4, 5 |
| 5 | 7 | 2, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Read the binding evidence and write the branch-topology ruling [COMPLETED]

**Goal**: A decision record that rules on branch granularity, merge strategy, landing mechanics
and worktree isolation, with the recorded data-loss mechanism engaged by name rather than
asserted away.

**Tasks**:
- [x] Read `specs/decisions/worktree-isolation-removal-verdict.md` in full. *(completed)*
- [x] Read `specs/decisions/worktree-isolation-removal-reaffirmation.md` in full. *(completed)*
- [x] Read `specs/decisions/commit-layer-cluster-ordering.md`'s "Inputs to the branch feature" *(completed)*
      and `CONDITION ON A RULING` material.
- [x] Write `specs/decisions/branch-topology-and-landing-strategy.md`, following the structure of *(completed)*
      `commit-layer-cluster-ordering.md` (a rulings table with Basis and State-change columns,
      then an Edges section, then the re-measured premises) and naming tasks by slug with the
      number alongside.
- [x] Record ruling R1 (hot-path branch = the already-checked-out branch, verified at admission; *(completed)*
      no branch creation at any granularity during dispatch work) with its basis: the measured
      single-hit branch-awareness grep, and the checkout hazard against a shared working tree.
- [x] Record ruling R2 (milestone review history via `git commit-tree` + compare-and-swap *(completed)*
      `git update-ref` onto `refs/heads/milestone/<id>`, one squash commit per completed task,
      resolved from `roadmap_milestones[].id` rather than any literal milestone name).
- [x] Record ruling R3 (merge strategy: squash per task, which is the short-lived-unit squash *(completed)*
      external convention endorses; whether the milestone ref is itself squashed when it finally
      merges stays the human reviewer's call at review time; no automatic rebase onto a moved
      base).
- [x] Record ruling R4 (the integration-branch declaration's key name and shape are fixed here; *(completed)*
      the schema row and admission enforcement are allocated to 655 — see `## Decisions`, D3 —
      and this task's scripts are consumers with a loud advisory fallback).
- [x] Record ruling R5 (worktree isolation is NOT reinstated) with the binding-evidence *(completed)*
      engagement written out: name the specific measured data-loss mechanism both records
      identify, and show why this design cannot reproduce it structurally — it creates no clone
      of mutable state, so there is no shared inode and no exclusion list for an unrelated script
      to miss; and the non-landing defect is closed by Phase 4 verifying the landing before the
      completion status write, not by assuming it.
- [x] Record ruling R6: the one-HEAD-per-repository premise holds, so 513's expected ref stays *(completed)*
      per-repository and the dispatch's `CONDITION ON A RULING` does not fire.
- [x] Record ruling R7: `orchestrate-conclusion-roadmap.sh`'s existing unconditional Move 4 *(completed)*
      regenerate already satisfies Element 2's roadmap bullet, and `orchestrate-batch-gate.sh`'s
      existing once-per-invocation complete-gate run already satisfies its batch-testing bullet
      (see `## Decisions`, D6). No parallel path is built for either.
- [x] Record ruling R8: the milestone-completion step PREPARES the push and review request and *(completed)*
      hands them to the user through `/please` and `/merge`; it never mints a grant, never infers
      permission from completion, and never pushes or opens a PR. State this explicitly as a
      deliverable property, not an implementation note.
- [x] Record, in a re-measured-premises section, the corrections in this plan's *(completed)*
      `### Premise Re-Validation` items 5, 6 and 7, so a later reader does not re-derive them.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Every touched path lies under `specs/**`, so sub-case (a) applies and the
covering check is the `prose` row's diff read-through — a decision record is not a
report/plan/summary artifact, so `validate-artifact.sh` has no type to check it against.

**Files to modify**:
- `specs/decisions/branch-topology-and-landing-strategy.md` - new: the Element 1 ruling, R1-R8 plus a re-measured-premises section

**Verification**:
- The record exists and contains all eight rulings R1-R8 as distinguishable, separately stated
  items.
- R5 names the specific measured data-loss mechanism from the verdict and reaffirmation records,
  cites both records by filename, and states the structural reason this design cannot reproduce
  it. A reader cannot satisfy this criterion from the research report alone — the mechanism's
  wording must trace to the records themselves.
- Diff read-through confirms every changed hunk lies inside the new file.

---

### Phase 2: Write the state changes the ruling implies [COMPLETED]

**Goal**: The ruling's dependency edge, task-description revision, and cluster-record amendment
note are written to durable state, with the already-resolved edge left alone.

**Tasks**:
- [x] Re-confirm, with `jq` against `specs/state.json`, that 657's `dependencies` are `[654, 656]` *(completed)*
      and 655's are `[513, 553, 654, 657]`. If 553 appears in 657's list, STOP and reconcile
      against `specs/decisions/commit-layer-cluster-ordering.md`'s Edge 6 row before proceeding —
      do not add it, and do not remove it without recording why.
- [x] Write the one new edge the ruling justifies: 655 gains 517 *(completed)*
      (`stage_regenerated_derived_files_in_phase_commits`) as a predecessor, because ruling R4
      allocates the integration-branch declaration schema in
      `context/standards/repo-level-declarations.md` to 655, which is the falsification condition
      the cluster record itself states for 517. Use
      `bash .claude/scripts/update-task-status.sh preflight 655 edge_only "$session_id" --depends-on-add='[517]'`
      and let its write-time cycle refusal run; if refused, record the refusal and the reason in
      the decision record rather than forcing the write.
- [x] Revise 655's description via `state-write.sh` (jq filter + `--arg`, `--regen-todo`): append a *(completed)*
      block recording that the branch-topology ruling has landed, naming the decision record;
      state that per-invocation branch creation and `git merge --squash` landing are superseded by
      R1 and R2; state that Element A's admission-time branch check survives unchanged; state that
      655 now owns the `repo-level-declarations.md` schema row for the integration-branch key and
      the admission assertion; and state that the stale `BINDING CONSTRAINT, NOT RE-OPENABLE`
      block is superseded by the ruling, per that description's own trailing deference paragraph.
- [x] Append a dated amendment note to `specs/decisions/commit-layer-cluster-ordering.md` in the *(completed)*
      sanctioned `**Amended by** <doc>, <date>:` shape, recording: that the branch-topology ruling
      has landed and where; that ruling R6 confirms the one-HEAD-per-repository premise, so 513's
      expected ref stays per-repository and the record's `CONDITION ON A RULING` does not fire;
      and that 517 is now a predecessor of 655 under the record's own stated condition. The target
      file exists (confirmed at authoring time); if it is absent when this phase runs, write the
      same content into the new decision record's own amendment section instead and say so there.
- [x] Regenerate `specs/TODO.md` (`bash .claude/scripts/generate-todo.sh`) if `--regen-todo` was *(completed)*
      not used on every write.
- [x] Record in the decision record's Edges section that exactly one new edge was written, and *(completed)*
      that the `657 -> 553` candidate was already resolved by moving it to 655 — with the live
      `dependencies` arrays quoted as the evidence.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly one new dependency edge (655 gains 517) and one description revision
(655) are owed, on the hypothesis that no other open task's territory is newly claimed by the
ruling. Confirm at implementation time by re-running the overlap scan over this plan's full file
set — `jq` over every non-terminal `active_projects[].file_scope` for each path in Phases 3-6 —
and add any further edge the scan justifies, recording it in the decision record. The live
`dependencies` arrays quoted in `### Premise Re-Validation` item 5 are carried from a `jq` read
taken at plan-authoring time against `specs/state.json`; re-read them rather than trusting them.

**Tier Justification**: `bash .claude/scripts/validate-state.sh` is the specific check covering a
`specs/state.json` mutation — it enforces every field bound and enum this phase's writes touch —
run together with the diff read-through the prose-adjacent `specs/**` edits need.

**Files to modify**:
- `specs/state.json` - 655's `dependencies` gains 517; 655's `description` gains the ruling-revision block
- `specs/TODO.md` - regenerated view of the above
- `specs/decisions/commit-layer-cluster-ordering.md` - dated amendment note recording the ruling's effect on the cluster
- `specs/decisions/branch-topology-and-landing-strategy.md` - Edges section records what was written and what was deliberately not

**Verification**:
- `jq -r '.active_projects[]|select(.project_number==655)|.dependencies' specs/state.json`
  includes 517, and 657's `dependencies` still exclude 553.
- `bash .claude/scripts/validate-state.sh` passes.
- 655's description contains the revision block and names the decision record by filename.
- `specs/decisions/commit-layer-cluster-ordering.md` carries exactly one new amendment note, in
  the `**Amended by**` shape, with no version-lineage language elsewhere in the file.

---

### Phase 3: Build the milestone-ref landing script and its suite [NOT STARTED]

**Goal**: A tested script that appends one squash commit per completed task onto its milestone's
ref, without ever touching the working tree, the index, or `HEAD`.

**Tasks**:
- [ ] Write `agent-system/extensions/core/scripts/milestone-ref-land.sh`: given a task number and
      session id, resolve the task's milestone from `roadmap_milestones[].batches[].task_ids`
      (no milestone -> clean no-op exit 0 with a named note, never an error).
- [ ] Resolve the integration branch from the declaration key ruling R4 fixes, falling back to the
      currently checked-out branch with a loud, named advisory when the key is undeclared.
- [ ] Compute `tree=$(git rev-parse HEAD^{tree})`; compute the parent as the milestone ref's
      current tip, or the integration branch's tip for the milestone's first landing.
- [ ] Create the commit with `git commit-tree`, subject `task {N}: {title}` per
      `rules/git-workflow.md`'s convention, with the phase list in the body.
- [ ] Update the ref with the three-argument compare-and-swap form
      `git update-ref refs/heads/milestone/<id> <new> <old>`; on a lost race, re-read the tip,
      recompute, and retry under the existing task lock — never a new lock, never a force update.
- [ ] Add a `--verify` mode asserting `git merge-base --is-ancestor HEAD refs/heads/milestone/<id>`,
      for Phase 4's pre-completion check.
- [ ] Assert the script never calls `git checkout`, `git switch`, `git merge`, `git push`, or
      `git reset`, and document that property in its header.
- [ ] Write `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh`: per simulated
      landing, assert the ref's commit count, its parent chain, and tree equality against the live
      branch; assert `HEAD`, the index, and the working tree are byte-identical before and after;
      assert the compare-and-swap refusal path; assert the no-milestone no-op; assert the
      undeclared-key advisory fallback.
- [ ] Add the suite's row to `agent-system/extensions/core/scripts/tests/suite-classification.data`
      (TAB-separated: basename, class, reason) — a data edit, never a documentation edit.
- [ ] Register the new scripts with `bash .claude/scripts/sync-manifest-scripts.sh --write`, then
      confirm with `--check`.
- [ ] Re-run the suite selector over this phase's paths and add a
      `scripts/tests/suite-selection-map.data` row only if basename pairing does not resolve the
      new script to its new suite.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Two new files (one script, one suite) plus two registration edits
(`suite-classification.data`, `manifest.json`) are the whole footprint, on the hypothesis that
basename pairing resolves the new script to its new suite with no
`suite-selection-map.data` row needed. Confirm by running `suite_selection_select` over this
phase's `Files to modify` paths once both files exist on disk, and add the row if the script's own
path is reported unmapped.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, invoked
over this phase's `Files to modify` paths, resolves them to their covering suites and runs that
narrowed pass — the specific check covering a self-contained new script that has no call site
yet.

**Files to modify**:
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` - new: ref-plumbing landing plus `--verify` mode
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` - new: landing, idempotence, race-refusal, no-op and fallback coverage
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one new classification row for the suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entries for the two new files, derived from disk

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` passes.
- `bash .claude/scripts/sync-manifest-scripts.sh --check` reports no gap in either direction.
- `bash .claude/scripts/lint/lint-unit-integration-boundary.sh` reports no unclassified suite.
- A manual run against a scratch clone leaves `git status --porcelain`, `git rev-parse HEAD` and
  `git rev-parse --abbrev-ref HEAD` unchanged while the milestone ref advances by exactly one
  commit.

---

### Phase 4: Verify the landing before the completion status write [NOT STARTED]

**Goal**: A task's `[IMPLEMENTING] -> [COMPLETED]` transition cannot succeed unless its work has
actually landed on its milestone ref.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, immediately
      before the `skill_postflight_update "$task_number" "implement" ...` call that writes the
      completion status, invoke `milestone-ref-land.sh` for the task, then its `--verify` mode.
- [ ] On a landing or verification failure, do NOT call `skill_postflight_update`: leave the task
      at its in-flight status and emit a named notice stating the remedy, following the shape the
      existing exit-6 deploy-pending refusal already uses at that site rather than inventing a new
      control path.
- [ ] Keep the no-milestone case a clean pass-through: a task in no batch lands nothing and its
      completion write proceeds exactly as today.
- [ ] Record the non-landing defect this closes in the script's own comment, citing the
      reaffirmation record by filename — no task-number reference, per the deliverable lint.
- [ ] Extend `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`:
      assert the completion write is refused when landing fails; assert it proceeds when landing
      succeeds; assert the no-milestone pass-through; assert ordering (verify strictly before the
      status write).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: One call site in `orchestrate-cycle-postflight.sh` and one existing suite
extension are the whole footprint, on the hypothesis that the completion status write for
`/orchestrate` happens only at that one site. Confirm at implementation time by grepping the
script for every `skill_postflight_update ... "implement"` occurrence and wiring each one that
writes a completion status, not only the first found.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, invoked
over this phase's `Files to modify` paths, resolves them to their covering suites and runs that
narrowed pass — the specific check covering a new guarded call site inside an existing
orchestration script.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - landing plus `--verify` call before the completion status write, with a refuse-and-defer branch on failure
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - refusal, success, pass-through and ordering cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes.
- A fixture run with a forced landing failure leaves the task's `state.json` status unchanged and
  prints the named notice.
- A fixture run with no milestone membership completes exactly as before the change.

---

### Phase 5: Prepare the milestone push/review handoff [NOT STARTED]

**Goal**: When a milestone's derived batch-done count reaches its batch count, the system prepares
the push and review request, records `review.state: "prepared"` with the ref, and hands the user
the literal commands — without pushing anything.

**Tasks**:
- [ ] Write `agent-system/extensions/core/scripts/milestone-review-handoff.sh`: for each
      milestone, derive `b_done`/`b` the same way `roadmap-integration.sh` does (every
      `task_ids` member terminal in `active_projects` or absent from it) and act only on the
      milestone whose completion became true during this invocation.
- [ ] Confirm `refs/heads/milestone/<id>` exists and its commit count matches the milestone's
      derived done-task count; on a mismatch, emit a named warning and prepare nothing.
- [ ] Compute the commit range against the integration branch's current tip and draft a
      review-request summary, one bullet per landed task's squash-commit subject, written to
      `specs/milestones/<id>-review-handoff.md`.
- [ ] Write `review.state: "prepared"`, `review.ref: "refs/heads/milestone/<id>"` and
      `review.updated: <YYYY-MM-DD>` via `state-write.sh`, only on the `none -> prepared`
      transition. Leave `review.request` empty (it is a PR identifier or URL, and no PR exists
      yet), and leave `progress.status` untouched.
- [ ] Print the exact literal commands for the user to type — the `/please` push request for the
      milestone ref, then `/merge` — as the handoff's final output, and state in the output that
      the system will not run them.
- [ ] Assert, in the script's header and in its suite, that it calls no `git push`, no
      `git-push-granted.sh`, no `gh`/`glab`, and no `/merge`, and never writes the grant store or
      key path.
- [ ] Invoke the handoff from `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh`
      after a successful regenerate, non-fatally: a handoff failure must never fail the roadmap
      stage.
- [ ] Write `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh`:
      assert the fires-once-on-transition behaviour, the ref-mismatch warning path, the
      `review` field writes and their enum conformance, the untouched `progress.status`, the
      literal-command output, and the absence of every push-shaped call.
- [ ] Extend `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh`
      with the wiring and non-fatal-failure cases.
- [ ] Add the new suite's row to `scripts/tests/suite-classification.data` and register the new
      script with `sync-manifest-scripts.sh --write`, then `--check`.

**Timing**: 2 hours

**Depends on**: 3

**Scope Hypothesis**: `review.state`'s enum containing `prepared` and `review.ref`'s documented
meaning are carried from `context/formats/roadmap-format.md`'s field table and
`context/schemas/state-schema.json`, both read at plan-authoring time. Re-read both before writing
the field, and if either has moved, record the change and write only values the live schema admits
— `validate-state.sh` is the arbiter, not this plan.

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, invoked
over this phase's `Files to modify` paths, resolves them to their covering suites and runs that
narrowed pass — the specific check covering a new script plus one non-fatal call site in an
existing conclusion-stage script.

**Files to modify**:
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` - new: detection, verification, draft, `review` write, literal-command output
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` - non-fatal handoff invocation after a successful regenerate
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` - new: transition, mismatch, field-write, and no-push coverage
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` - wiring and non-fatal-failure cases
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one new classification row
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entries for the two new files

**Verification**:
- Both suites pass, and `sync-manifest-scripts.sh --check` reports no gap.
- A fixture milestone whose batches all complete produces `specs/milestones/<id>-review-handoff.md`,
  a `review.state` of `prepared` with the ref set, an unchanged `progress.status`, and the literal
  `/please` and `/merge` command text in the output.
- `bash .claude/scripts/validate-state.sh` passes against the mutated fixture state.
- A grep over the new script finds no `git push`, `git-push-granted.sh`, `gh pr`, `glab mr`, or
  `/merge` invocation.

---

### Phase 6: Reconcile the written standards with the implemented mechanism [NOT STARTED]

**Goal**: The Branch Strategy standard, the git-integration standard, and a new pattern document
describe the mechanism that now exists, so the written standard and the enforced behaviour agree.

**Tasks**:
- [ ] Replace `context/standards/git-workflow-narrative.md`'s `## Branch Strategy` section with
      the ruled contract: the single long-lived checked-out branch for phase commits, the
      per-milestone review ref built by ref plumbing, and the `/please` + `/merge` handoff. Remove
      the unenforced optional task-branch convention. Re-locate the section by heading, not by the
      line numbers measured at plan-authoring time.
- [ ] Update `context/standards/git-integration.md` wherever it states branch behaviour that the
      ruling changes; if it states none, record that finding rather than editing it.
- [ ] Add `context/patterns/ref-plumbing-landing.md`: the `commit-tree`/`update-ref` idiom, its
      concurrency-safety property (no working tree, index or `HEAD` mutation), the compare-and-swap
      obligation, and the prohibition on reaching for `checkout` to land work in a shared tree.
- [ ] Add a step to `context/contracts/conclusion-stage.md` documenting the handoff as the
      roadmap stage's downstream, non-fatal companion, and stating that it prepares and never
      pushes.
- [ ] Add the new context file's entry to `agent-system/extensions/core/index-entries.json`
      (path, domain, subdomain, summary, line_count, keywords, topics, load_when, on_demand).
- [ ] Cross-check every new or edited file for task-number references and record-versioning
      language; both are lint-enforced outside `specs/**`.

**Timing**: 1.5 hours

**Depends on**: 1, 4, 5

**Scope Hypothesis**: The Branch Strategy section occupies `git-workflow-narrative.md` lines
235-247 and `git-integration.md` carries branch prose needing reconciliation — both measured at
plan-authoring time against the live source store. Re-locate the section by its `## Branch
Strategy` heading before editing, and re-read `git-integration.md` to confirm whether it needs an
edit at all; record "no change needed" explicitly if it does not, rather than inventing one.

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, invoked
over this phase's `Files to modify` paths, resolves them to their covering suites and runs that
narrowed pass — the specific check covering a guidance-markdown edit set plus its index
registration.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - Branch Strategy replaced with the ruled contract
- `agent-system/extensions/core/context/standards/git-integration.md` - branch prose reconciled, or a recorded finding of no change needed
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` - new: the no-checkout landing idiom and its concurrency property
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - the handoff step documented as the roadmap stage's non-fatal companion
- `agent-system/extensions/core/index-entries.json` - entry for the new pattern file; `line_count` for every context file this phase edits

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh` reports no undeclared or unindexed context file.
- `bash .claude/scripts/check-task-references.sh` and the record-versioning lint report no new
  occurrence under `agent-system/**`.
- `grep -n "task-{N}-{slug}" agent-system/extensions/core/context/standards/git-workflow-narrative.md`
  returns nothing.
- Diff read-through confirms the Branch Strategy section now names the ref-plumbing mechanism and
  the consent-gated handoff.

---

### Phase 7: Redeploy, reconcile derived surfaces, and close [NOT STARTED]

**Goal**: The source-store changes are present in the deployed tree, every derived surface is
reconciled, and the complete gate set is accounted for.

**Tasks**:
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --write` to reconcile
      `index-entries.json` line counts moved by Phase 6.
- [ ] Run `bash .claude/scripts/sync-manifest-scripts.sh --check` and resolve any remaining gap.
- [ ] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh` so the new
      scripts, context files and contract text reach `.claude/**`.
- [ ] Confirm the deployed copies of the two new scripts exist and are executable, and that
      `run-all.sh` discovers both new suites in the merged deployed tests directory.
- [ ] Run the scoped touched-path check over everything this task touched, and record that the
      complete gate set is deferred to the orchestration close rather than run independently here.
- [ ] Confirm `specs/ROADMAP.md` renders consistently with `specs/state.json` after Phase 2's
      edge write — specifically that 655's blocked token now includes 517.

**Timing**: 1 hour

**Depends on**: 2, 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `agent-system/extensions/core/index-entries.json` - line counts reconciled from disk
- `agent-system/extensions/core/manifest.json` - any residual `provides.scripts` gap closed

**Verification**:
- Under `/orchestrate`, this phase's own in-dispatch obligation is the scoped touched-path check —
  `bash .claude/scripts/verify-touched.sh` over this task's touched paths — plus an explicit
  statement that the complete gate set is deferred to the orchestration close (the
  once-per-invocation batch gate stage), not run independently here.
- Run standalone, outside `/orchestrate`, this phase instead runs
  `bash .claude/scripts/verify-deploy.sh` in full.
- `bash .claude/scripts/sync-manifest-scripts.sh --check` and
  `bash .claude/scripts/generate-context-line-counts.sh --check` both report no gap.
- The deployed tree contains both new scripts and the new pattern file.

---

## Testing & Validation

- [ ] `test-milestone-ref-land.sh` passes, including the parent-chain, tree-equality,
      working-tree-unchanged, compare-and-swap-refusal, no-milestone and advisory-fallback cases.
- [ ] `test-orchestrate-cycle-postflight.sh` passes, including the refuse-the-completion-write
      case and the strict ordering of verification before the status write.
- [ ] `test-milestone-review-handoff.sh` passes, including the fires-once-on-transition case, the
      `review` field writes, the untouched `progress.status`, and the no-push assertions.
- [ ] `test-orchestrate-conclusion-roadmap.sh` passes, including the non-fatal handoff-failure
      case.
- [ ] `lint-unit-integration-boundary.sh` reports every new suite classified.
- [ ] `validate-state.sh` passes after Phase 2's and Phase 5's state writes.
- [ ] `check-task-references.sh` and the record-versioning lint report no new occurrence under
      `agent-system/**`.
- [ ] A grep across the new scripts finds no `git push`, `git checkout`, `git switch`,
      `git merge`, `gh pr`, `glab mr`, or `/merge` invocation.

## Artifacts & Outputs

- `specs/decisions/branch-topology-and-landing-strategy.md` — the Element 1 ruling (R1-R8).
- A dated amendment note in `specs/decisions/commit-layer-cluster-ordering.md`.
- One new dependency edge (655 gains 517) and one revised task description (655) in
  `specs/state.json`, reflected in `specs/TODO.md`.
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` and its suite.
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` and its suite.
- A landing call site in `orchestrate-cycle-postflight.sh` and a handoff call site in
  `orchestrate-conclusion-roadmap.sh`.
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md`, plus the reconciled
  Branch Strategy and conclusion-stage text.
- `specs/milestones/<id>-review-handoff.md`, produced at runtime when a milestone completes.

## Rollback/Contingency

The work divides cleanly at the ruling boundary. Phases 1-2 produce only `specs/**` records and
state edges; reverting them means removing the decision record, removing the 517 edge with
`update-task-status.sh --depends-on-remove` (or its equivalent), and reverting the description
block — no code is affected.

Phases 3-6 are revertible per phase at their commit boundaries, since each phase commits its own
green sub-steps. The two new scripts are additive; the two call sites are the only changes to
existing behaviour, and each is a single guarded block whose removal restores the prior path
exactly. A milestone ref left behind by a partial run is inert: nothing reads
`refs/heads/milestone/<id>` except the handoff step, and `git update-ref -d` removes it without
touching the working tree.

If a rollback must discard uncommitted working-tree changes, take the snapshot first using the
rollback-rung invocation shape in `context/contracts/recovery.md` — including its out-of-scope
override flag for the deliberate whole-tree case — and only then run the destructive command. Do
not emit a bare snapshot call as a routine start-of-phase precaution; for an ordinary defensive
checkpoint before risky work, use the non-reverting checkpoint form instead.
