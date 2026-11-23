# Implementation Plan: Task #675

- **Task**: 675 - Rewrite the branch-strategy documentation to state the implemented integration-branch contract
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None blocking. `per_task_attribution_squash_landing` (completed) supplies the third ruling record this task documents; `two_root_classification_of_remaining_consumers` and `batch_worktree_cleanup_retention_orphan_report` are held and are deliberately NOT waited on — this task documents the implemented contract, not the deferred one.
- **Research Inputs**: `specs/675_branch_topology_documentation_parity/reports/01_branch-topology-doc-parity.md`
- **Artifacts**: plans/01_branch-topology-doc-parity.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The branch-strategy documentation currently describes an un-amended contract — a milestone ref
landed per completed task, an admission check deferred to a "consumer-owned concern," a worktree
question treated as wholly closed — none of which matches what the scripts now do. This plan
rewrites `git-workflow-narrative.md`'s Branch Strategy section to state the implemented
integration-branch contract, adds the missing point-of-use branch rule to `rules/git-workflow.md`,
and fixes the two confirmed-stale pages the sweep found outside the declared `file_scope`
(`conclusion-stage.md`, `shared-worktree-discipline.md`). The research pass verified every claim
against the live scripts rather than the records, and verified that two of the five named edit
targets (`ref-plumbing-landing.md`, `repo-level-declarations.md`) already state the implemented
contract correctly — those are confirmed, not rewritten. The plan closes with a parity
re-verification against the scripts, a line-count regeneration, and a redeploy.

### Research Integration

The research report's per-document classification is carried directly into the phase split:

- `git-workflow-narrative.md` Branch Strategy — **stale**, needs substantial rewrite (Phase 1).
- `rules/git-workflow.md` — **absent, not stale**; the branch rule is additive (Phase 2).
- `conclusion-stage.md` and `shared-worktree-discipline.md` — **confirmed stale**, both outside
  today's declared `file_scope`; the sweep recommends fixing both (Phase 3).
- `ref-plumbing-landing.md` and `repo-level-declarations.md` — **already current**, verified
  against the live scripts; confirmed and left untouched (Phase 4 records the verdict).
- `git-staging-scope.md` — **no stale claim found**; explicitly excluded (Phase 3's Scope
  Hypothesis).
- `index-entries.json` — mechanical; `deploy-headless.sh` auto-repairs `line_count` from `wc -l`
  before deploy via `generate-context-line-counts.sh --write`, so this plan regenerates it
  in each editing phase rather than hand-computing counts.

Facts re-confirmed at plan time (not carried from the report on trust):

- The source store resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core` via
  `.claude-extensions.json`'s `.extensions.core.source_dir`. All seven candidate target files
  exist there at the line counts `index-entries.json` records (297 / 98 / 207 / 418 / 61 / 540 /
  1259), so every correction target named below exists.
- All three ruling records exist in `specs/decisions/`:
  `branch-topology-and-landing-strategy.md`,
  `batch-worktree-isolation-and-task-squash-landing.md`,
  `isolation-off-landing-verification-and-review-time-squash.md`.
- `milestone-ref-land.sh`'s own header states its retired standing in its own words;
  `milestone-review-handoff.sh` resolves an integration branch and sets
  `review.ref="refs/heads/<integration branch>"`, reading landing proofs — both confirmed by
  reading the live scripts.
- `.claude-extensions.json` declares neither `integration_branch` nor `worktree_isolation` in
  this repository today (both `null`), so this repository runs in the advisory-only posture.
- This task's `file_scope` in `specs/state.json` holds exactly the five originally named paths
  and does NOT include the two sweep targets. Declaring them in a phase's `Files to modify`
  block is itself the widening mechanism: `plan-file-scope-harvest.sh` harvests that block and
  plan postflight forwards it to `update-task-status.sh --file-scope-add`, a union-merge.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied with this dispatch; no roadmap consultation was performed and no
roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- The rules, the narrative, and the scripts state the same contract, with every documented claim
  re-derivable by reading a live script.
- No page describes worktree isolation or a batch branch as live machinery; every mention names
  it as declared-but-unimplemented and points at the held work by slug.
- A reader can tell which branch their work lands on and what refuses them if they start
  elsewhere, from either the rule file or the narrative.
- The sweep's findings are acted on (`conclusion-stage.md`, `shared-worktree-discipline.md`), not
  merely reported.

**Non-Goals**:
- Re-arguing any of the three ruling records. They are binding and are cited, not re-derived.
- Documenting the batch-worktree contract as if it were live. The worktree half is documented as
  declared-but-unimplemented only.
- Editing `git-staging-scope.md`. The research sweep found no stale branch/worktree-topology
  claim in it, and manufacturing an edit to satisfy the instruction's letter is explicitly out.
- Rewriting `ref-plumbing-landing.md` or `repo-level-declarations.md`, which already state the
  implemented contract. Phase 4 confirms rather than edits them.
- Building, un-holding, or scoping any of the five held worktree/two-root successor tasks.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The rewrite drifts from the scripts again once a held successor is un-held and built | M | M | State mechanisms by behavior and script name, and keep every stated constant (exit code, stop-reason string) to facts a reader can `grep` to re-verify; Phase 4 re-checks each against the live script before closing |
| The two sweep targets sit outside the declared `file_scope`, so an implementer may skip them or trip a scope-excursion check | H | M | Both are declared explicitly in Phase 3's `Files to modify`; harvest + `--file-scope-add` widens `file_scope` at plan postflight, before implementation begins |
| Record-versioning language leaks into the rewrite (the existing section's "this section previously offered ... is removed along with it" is exactly this shape) | M | H | Phase 1 explicitly deletes that sentence rather than revising it; `hooks/validate-no-record-versioning.sh` gates the write and Phase 4 re-greps |
| A held successor is cited by task number instead of slug, violating `no-task-references-in-deliverables.md` under `agent-system/**` | M | M | The five slugs are enumerated verbatim in Phase 1's task list; `hooks/validate-no-task-references.sh` gates the write; Phase 4's gate 4 pass re-checks |
| Line counts in `index-entries.json` go stale against the rewritten files | L | H | Each editing phase runs `generate-context-line-counts.sh --write` itself and declares `index-entries.json` in its own `Files to modify`, rather than deferring to the redeploy's auto-repair |
| `shared-worktree-discipline.md`'s fix over-corrects and reopens the per-dispatch question that genuinely stays settled | M | L | The fix is scoped to separating the two granularities; per-dispatch/per-agent isolation is restated as a settled non-goal verbatim, and only batch granularity is described as declared-but-unimplemented |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

All paths below are relative to the repository root
`/home/benjamin/.config/nvim`. Every edit target is a source-store path under
`agent-system/extensions/core/` — never the deployed `.claude/**` mirror, which Phase 4's
redeploy regenerates.

---

### Phase 1: Rewrite the Branch Strategy section of the narrative [NOT STARTED]

**Goal**: `context/standards/git-workflow-narrative.md`'s Branch Strategy section states the
implemented integration-branch contract — admission, landing-as-verification, review handoff, and
the declared-but-unimplemented worktree mode — with nothing described as live that is not built.

**Tasks**:
- [ ] Read all three ruling records before writing:
      `specs/decisions/branch-topology-and-landing-strategy.md`,
      `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`, and
      `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (the
      load-bearing third record: it settles what a reviewable unit is).
- [ ] Re-read the live scripts the rewrite will describe, so every claim is script-derived:
      `scripts/lib/batch-admission-lib.sh` (the stop reasons and the exact state-territory list —
      transcribe the list from the script, do not copy a list from this plan),
      `scripts/orchestrate-cycle-plan.sh` (the `batch_admission_evaluate` call site),
      `scripts/update-task-status.sh` (the PHASE 0.6 landing gate and its exit code),
      `scripts/task-landing-verify.sh`, `scripts/milestone-ref-land.sh` (header), and
      `scripts/milestone-review-handoff.sh`.
- [ ] Rewrite `### The Hot-Path Branch`: the primary tree stays on the declared
      `integration_branch` and is never switched during dispatch work; no branch is created at any
      granularity, verified rather than asserted — `grep -rn "git checkout -b\|git switch -c"
      scripts/ hooks/` returns exactly one hit, `git-snapshot.sh`'s `--branch` recovery path.
      State the two live admission refusals (`off_integration_branch`, `dirty_primary_tree`) and
      their exact arming condition: both arm ONLY when `integration_branch` is declared in
      `.claude-extensions.json`; an undeclaring repository gets one advisory per session and no
      refusal. Delete the stale "a separate, consumer-owned concern" clause — the check is built.
- [ ] Rewrite `### Milestone Review History: Ref Plumbing, Never checkout Or git merge --squash`:
      phase commits land on the integration branch as made and stay there — nothing is picked,
      squashed, or rewritten there. Landing is a VERIFICATION, not an operation:
      `scripts/task-landing-verify.sh`, run inside `update-task-status.sh` at its postflight
      landing gate, strictly before the completion status write, refusing (exit 7, writing no
      state) rather than skipping. State that `milestone-ref-land.sh` is retired as a landing
      mechanism and stays on disk as a hand-run snapshot utility whose ref is a parallel history.
      Point at `context/patterns/ref-plumbing-landing.md`'s "The Landing Mechanism" section for
      where the plumbing idiom is actually used today, and keep that page's concurrency-safety
      argument referenced rather than duplicated.
- [ ] Rewrite `### Merge Strategy`: replace "Squash per task, landed onto the milestone ref" with
      the reviewable-unit ruling from
      `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` — state what
      a reviewable unit is under the isolation-off mechanism and that any squash is a review-time
      act of human judgment, not an automated landing step.
- [ ] Rewrite `### Milestone Completion: Prepare, Never Push` to match the live handoff script:
      `milestone-review-handoff.sh` resolves the integration branch (from the newest landing
      proof, else the declared `integration_branch`, else the branch HEAD names), records
      `review.state: "prepared"` plus `review.ref` as `refs/heads/<integration branch>` — not a
      `refs/heads/milestone/<id>` ref — attributes each task by its landing proof's commit list,
      drafts the review summary, and prints the literal `/please`/`/merge` commands. Keep the
      never-pushes/never-mints-a-grant paragraph intact.
- [ ] Rewrite `### Worktree Isolation: Not Reinstated` so it distinguishes the two granularities:
      per-dispatch/per-agent isolation stays a settled non-goal; batch-granularity isolation is
      a DECLARED-BUT-UNIMPLEMENTED mode — `worktree_isolation` is `off` unless declared `batch`,
      and `batch` is refused loudly (`isolation_unimplemented`) rather than silently honored,
      because nothing builds it yet. Name the five held successors BY SLUG, never by number:
      `batch_worktree_creation_when_isolation_on`,
      `two_root_contract_dispatch_and_commit_scripts`, `two_root_contract_in_hooks`,
      `two_root_classification_of_remaining_consumers`,
      `batch_worktree_cleanup_retention_orphan_report`.
- [ ] Delete the record-versioning sentence in the existing Worktree Isolation subsection ("The
      unenforced, optional per-task branch-naming convention this section previously offered is
      removed along with it...") rather than revising it; state the current design only.
- [ ] Verify no task-number reference and no record-versioning phrasing entered the file:
      `grep -nEi "task [0-9]+|previously|formerly|no longer|supersedes|used to" agent-system/extensions/core/context/standards/git-workflow-narrative.md`
      and inspect every hit (a hit inside an unrelated, pre-existing sentence is acceptable only
      if it was already there and is not about this section's own history).
- [ ] Regenerate line counts:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, then
      confirm `index-entries.json`'s `standards/git-workflow-narrative.md` row matches
      `wc -l` on the rewritten file.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/context/standards/git-workflow-narrative.md agent-system/extensions/core/index-entries.json` covers this phase's whole touched set, selecting `test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-guard-destructive-git.sh`, `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, and `test-roadmap-command-registration.sh`.

**Scope Hypothesis**: the Branch Strategy section is a single contiguous region of
`git-workflow-narrative.md` spanning its five existing `###` subsections (`The Hot-Path Branch`,
`Milestone Review History`, `Merge Strategy`, `Milestone Completion`, `Worktree Isolation`), with
no branch-topology claim elsewhere in the file. Confirm at implementation time by running
`grep -n '^#' agent-system/extensions/core/context/standards/git-workflow-narrative.md` and
`grep -nEi "branch|worktree|milestone ref|squash" agent-system/extensions/core/context/standards/git-workflow-narrative.md`
across the WHOLE file before editing; if a branch-topology claim is found outside the section,
fix it in this phase and note the excursion rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - Branch Strategy section rewritten to the implemented contract
- `agent-system/extensions/core/index-entries.json` - `standards/git-workflow-narrative.md` `line_count` regenerated (coupled generated surface: the rewrite moves the quantity this file derives)

**Verification**:
- Every factual claim in the rewritten section traces to a live script read in this phase, not to
  a decision record alone.
- `grep -n "milestone-ref-land\|refs/heads/milestone" agent-system/extensions/core/context/standards/git-workflow-narrative.md`
  returns only the retired-standing mention, never a live-landing-mechanism claim.
- No batch branch and no worktree is described as live anywhere in the section; the five held
  successor slugs appear and no task number does.
- `bash .claude/scripts/verify-touched.sh` over this phase's two declared paths passes.
- `index-entries.json`'s row for the file matches `wc -l`.

---

### Phase 2: State the branch rule at the point of use in `rules/git-workflow.md` [NOT STARTED]

**Goal**: `rules/git-workflow.md` states, in its own short-rule-plus-pointer idiom, which branch a
commit lands on and that no script creates or switches branches during dispatch work.

**Tasks**:
- [ ] Re-read the Branch Strategy section as rewritten in Phase 1, so the rule file and the
      narrative state the same contract rather than two paraphrases of it.
- [ ] Add a short new section (placed beside `## Commit Timing` / `## Commit Message Format`,
      matching this file's existing convention of a two-or-three-sentence rule plus a pointer):
      a commit lands on the primary tree's already-checked-out branch, which is the declared
      `integration_branch` where one is declared and is verified at admission; no script creates
      or switches a branch during dispatch work, the single exception being `git-snapshot.sh`'s
      `--branch` recovery path.
- [ ] State the refusal in one clause, so a reader knows what stops them: an orchestration started
      off the declared integration branch, or with a dirty state territory, is refused at
      admission before any dispatch is composed — and that both refusals arm only where
      `integration_branch` is declared.
- [ ] Point at `context/standards/git-workflow-narrative.md`'s Branch Strategy section for the
      full detail and at `context/standards/repo-level-declarations.md` for the declaration
      schema; do not duplicate the narrative's length here.
- [ ] Confirm no task-number reference and no record-versioning phrasing entered the file.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/rules/git-workflow.md` covers this phase's single touched path, selecting `test-guard-destructive-git.sh`, `test-plan-file-scope-harvest.sh`, `test-validate-no-task-references.sh`, and `test-validate-wiring.sh`.

**Scope Hypothesis**: `rules/git-workflow.md` carries no branch rule of any kind today, so this
phase is purely additive and rewrites no existing section. Confirm before editing with
`grep -nEi "branch" agent-system/extensions/core/rules/git-workflow.md` — if an existing branch
claim is found, reconcile it in place in this phase instead of adding a second, competing
statement.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - new point-of-use branch rule plus pointers (the index does not carry `rules/**` rows, so no `index-entries.json` change is owed by this phase)

**Verification**:
- The new section states the same contract as the rewritten narrative, checked by reading both
  side by side.
- A reader of this file alone can tell which branch their work lands on and what refuses them if
  they start elsewhere.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/rules/git-workflow.md`
  passes.

---

### Phase 3: Act on the sweep — fix the two confirmed-stale pages [NOT STARTED]

**Goal**: the two pages the sweep confirmed stale state the implemented contract:
`conclusion-stage.md` no longer names a retired landing mechanism, and
`shared-worktree-discipline.md` distinguishes the settled per-dispatch non-goal from the
declared-but-unimplemented batch mode.

**Tasks**:
- [ ] `context/contracts/conclusion-stage.md`, the milestone push/review handoff paragraph:
      replace the "`refs/heads/milestone/<id>`, landed by `scripts/milestone-ref-land.sh` at each
      task's own completion" clause with what the live script does — `milestone-review-handoff.sh`
      resolves the integration branch, reads each task's landing proof, and records
      `review.ref` as `refs/heads/<integration branch>`. Keep the never-pushes / never-mints-a-grant
      guarantees and the `/please`/`/merge`-printing behavior intact, and keep the cross-reference
      to `../patterns/ref-plumbing-landing.md` pointed at the section that is actually about the
      landing mechanism.
- [ ] `context/standards/shared-worktree-discipline.md`, the opening sentence: split the single
      "per-agent worktree isolation is a settled non-goal, not an open question" claim into two —
      per-dispatch/per-agent isolation remains a settled non-goal (citing the removal
      reaffirmation record, unchanged by either amendment); batch-granularity worktree isolation
      is a separate mode, off unless declared, declared-but-unimplemented, with named held
      successors. Draw the distinction the same way
      `context/standards/repo-level-declarations.md` already draws it for `worktree_isolation`.
- [ ] In the same file, re-read the `## Detached worktree` section's appeals to "the settled
      per-dispatch worktree-isolation question above" and make sure they still read correctly
      against the amended opening — that section is about per-dispatch granularity and should stay
      accurate without widening.
- [ ] Cite the held successors by slug only, never by number, in both files.
- [ ] Re-verify the sweep's negative finding rather than assuming it:
      `grep -nEi "cherry-pick|squash|milestone|landing|integration branch|per-dispatch working-tree isolation" agent-system/extensions/core/context/standards/git-staging-scope.md`
      and read each hit. Expectation: no stale branch/worktree-topology claim, so no edit. If the
      re-verification instead finds a stale claim, record it via `issue-record.sh` and surface it
      in the handoff rather than editing a file this phase's Scope Hypothesis excludes.
- [ ] Re-run `grep -rln "milestone-ref-land" --include="*.md" agent-system/extensions/core/` to
      confirm no fourth stale reference exists beyond the files this plan touches.
- [ ] Regenerate line counts:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/context/contracts/conclusion-stage.md agent-system/extensions/core/context/standards/shared-worktree-discipline.md agent-system/extensions/core/index-entries.json` covers this phase's whole touched set, selecting `test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, `test-orchestrate-conclusion-aggregate.sh`, `test-orchestrate-conclusion-backstop.sh`, `test-orchestrate-conclusion-roadmap.sh`, `test-orchestrate-recap.sh`, and `test-roadmap-command-registration.sh`.

**Scope Hypothesis**: exactly two files carry the sweep's confirmed staleness
(`conclusion-stage.md` and `shared-worktree-discipline.md`), and `git-staging-scope.md` carries
none and is deliberately EXCLUDED from this phase's edits. Every task above is consistent with
that exclusion: `git-staging-scope.md` is read and re-verified in this phase, never written. If
the re-verification contradicts the hypothesis, the contradiction is recorded and surfaced, not
silently resolved by editing the excluded file.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - milestone handoff paragraph corrected to the live `review.ref` / landing-proof mechanism
- `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` - opening sentence split into the settled per-dispatch non-goal and the declared-but-unimplemented batch mode
- `agent-system/extensions/core/index-entries.json` - `contracts/conclusion-stage.md` and `standards/shared-worktree-discipline.md` `line_count` rows regenerated (coupled generated surface)

**Verification**:
- `grep -n "milestone-ref-land\|refs/heads/milestone" agent-system/extensions/core/context/contracts/conclusion-stage.md`
  returns no live-landing-mechanism claim.
- `shared-worktree-discipline.md`'s opening no longer lets a reader conclude the whole
  worktree-isolation topic is closed, while still stating plainly that per-dispatch isolation is.
- The `git-staging-scope.md` re-verification result is recorded explicitly (edited: no; reason
  stated), satisfying the task's own sweep-reporting criterion.
- `bash .claude/scripts/verify-touched.sh` over this phase's three declared paths passes.

---

### Phase 4: Parity verification, already-current confirmations, and redeploy [NOT STARTED]

**Goal**: the rules, the narrative, and the scripts are confirmed to state one contract; the two
already-current pages are confirmed rather than assumed; the source store is redeployed and the
deployed tree verified.

**Tasks**:
- [ ] Parity read-through, scripts first: re-read `scripts/lib/batch-admission-lib.sh`,
      `scripts/orchestrate-cycle-plan.sh`'s admission call site, `scripts/update-task-status.sh`'s
      postflight landing gate, `scripts/task-landing-verify.sh`, and
      `scripts/milestone-review-handoff.sh`, then check each documented claim in
      `git-workflow-narrative.md`, `rules/git-workflow.md`, `conclusion-stage.md`, and
      `shared-worktree-discipline.md` against them. Any divergence is fixed here, in this phase.
- [ ] Confirm the two already-current pages against the same scripts rather than against the
      research report: `context/patterns/ref-plumbing-landing.md` (its "The Landing Mechanism"
      section, and that its concurrency-safety argument survives intact) and
      `context/standards/repo-level-declarations.md` (both declaration rows, the stop reasons,
      the fail-open-on-absence table, and the live-versus-declared-not-implemented distinction
      for `worktree_isolation`). Record the confirmation verdict. Edit only if the confirmation
      fails or if a Phase 1-3 edit left a dangling or duplicated cross-reference.
- [ ] Repo-wide staleness re-sweep:
      `grep -rn "refs/heads/milestone\|milestone-ref-land" --include="*.md" agent-system/extensions/core/`
      and `grep -rniE "worktree isolation" --include="*.md" agent-system/extensions/core/` — read
      every hit and confirm none describes worktree isolation or a batch branch as live.
- [ ] `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, then
      confirm zero drift with `... --check` (or the equivalent check mode the script exposes).
- [ ] Redeploy the source store: `bash agent-system/extensions/core/scripts/deploy-headless.sh`
      (whole-tree regeneration — this is why `__WHOLE_TREE__` is declared below).
- [ ] Scoped touched-path check as this phase's own in-dispatch obligation:
      `bash .claude/scripts/verify-touched.sh` over every path this task actually touched
      (the four edited markdown files plus `index-entries.json`), and
      `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
      for the doc-lint and task-reference-lint gates over the redeployed tree.
- [ ] Under `/orchestrate`, the complete gate set is DEFERRED to the orchestration close
      (`context/contracts/batch-gate-stage.md`), not run independently here. In a standalone,
      non-orchestrated run with no such close to defer to, run
      `bash .claude/scripts/verify-deploy.sh` in full instead.
- [ ] Record the sweep's findings (what was stale, what was fixed, what was confirmed clean,
      and that `git-staging-scope.md` was deliberately not edited) in the implementation summary,
      satisfying the task description's "Report what the sweep found."

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/**` tree
- `agent-system/extensions/core/index-entries.json` - final `line_count` reconciliation across every file this task edited
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` - confirm-only; edited solely if the confirmation fails or a cross-reference went dangling
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - confirm-only; edited solely if the confirmation fails or a cross-reference went dangling

**Verification**:
- Every documented claim across the four edited files matches a live script, checked by reading
  the scripts and not the decision records.
- No page in `agent-system/extensions/core/**` describes worktree isolation or a batch branch as
  live machinery; every mention names it declared-but-unimplemented and points at the held work
  by slug.
- `generate-context-line-counts.sh --check` reports zero drift.
- `deploy-headless.sh` completes, and
  `verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` passes on the
  redeployed tree.
- `verify-touched.sh` passes over every path this task touched; the complete gate set is deferred
  to the orchestration close, stated explicitly in the handoff.

## Testing & Validation

- [ ] A reader of `rules/git-workflow.md` alone can name the branch their work lands on and what
      refuses them if they start elsewhere.
- [ ] A reader of `git-workflow-narrative.md`'s Branch Strategy section can distinguish built
      machinery from deferred design, and can find the held work by slug.
- [ ] Every stated constant (stop-reason string, exit code, ref shape, script name) is
      `grep`-verifiable against a live script.
- [ ] No task-number reference and no record-versioning phrasing exists in any file this task
      touched under `agent-system/**`.
- [ ] `verify-touched.sh` passes for each phase's declared path set;
      `verify-deploy.sh --only-gate 3,4` passes over the redeployed tree.
- [ ] `index-entries.json` carries no `line_count` drift.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` (rewritten Branch
  Strategy section)
- `agent-system/extensions/core/rules/git-workflow.md` (new point-of-use branch rule)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (corrected handoff
  paragraph)
- `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` (corrected
  opening, two granularities separated)
- `agent-system/extensions/core/index-entries.json` (regenerated line counts)
- Regenerated deployed `.claude/**` tree
- `specs/675_branch_topology_documentation_parity/summaries/01_*-summary.md`, carrying the sweep
  report the task description asks for

## Rollback/Contingency

Every change is confined to markdown prose plus a mechanically regenerated JSON index, so rollback
is a content revert, never a state repair. If a phase's edits must be undone, take a defensive
checkpoint first with `bash .claude/scripts/git-snapshot.sh 675 --no-revert`, then revert the
specific file(s) from the prior commit with `git show <sha>:<path>` written back to the path —
never a tree-wide or path-reverting git operation, which would revert concurrent sibling work in
this shared tree (see `context/standards/shared-worktree-discipline.md`). After any revert, re-run
`generate-context-line-counts.sh --write` and redeploy, so the deployed tree and the index do not
retain the reverted content. If the redeploy itself fails, the source store is still correct and
the deploy can be re-run; no documentation change depends on the deploy having succeeded.
