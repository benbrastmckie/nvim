# Implementation Plan: Task #669

- **Task**: 669 - Add integration-branch admission and the isolation declaration
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: 517, 541, 667, 668 (all completed)
- **Research Inputs**: specs/669_integration_branch_admission_and_batch_worktree/reports/01_integration-branch-admission.md
- **Artifacts**: plans/01_integration-branch-admission.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-plan.sh` gains a once-per-invocation admission gate that reads two new
repo-level declarations, `integration_branch` and `worktree_isolation`, refuses an invocation
through the script's existing generic `stop` object, and on admit writes one batch record per
invocation under the primary tree's state directory. The mechanics live in a new shared library
and the cycle-plan script; no prose is added to `skills/skill-orchestrate/SKILL.md` or
`commands/orchestrate.md`. Everything is built and verified with isolation off, the only path
that exists while worktree creation is held in `batch_worktree_creation_when_isolation_on`
(task 686). Done means: both schema rows are documented with live versus unimplemented values
stated, the three refusals fire in fixtures, the batch record is written and registered, and the
source store is redeployed.

### Research Integration

Integrated from `reports/01_integration-branch-admission.md`:

- Insertion site: after the plan-cache replay block, before `orchestrate_cycle_plan_main`'s
  redeploy checkpoint, exiting through `emit_and_exit` with a new `stop_reason` (report
  Recommendation R-1).
- Predicate order and the three stop reasons (R-2); the three-member state territory (R-3);
  advisory-only behaviour when `integration_branch` is undeclared (R-4); batch record path and
  shape (R-5); delivery as a shared library with its own suite (R-6); schema-row content (R-8).
- Two suites copy an explicit library list beside the cycle-plan script and need the new
  library added (report finding 10).

### Premise Re-Validation

Each trigger-class line the dispatch extracted from the description, checked against the report
and against live state at authoring time (`HEAD` = `e67339326`):

| Description claim | Result |
|---|---|
| Source store is `agent-system/extensions/core/**`; redeploy via `deploy-headless.sh` | Confirmed: `.claude-extensions.json` `.extensions.core.source_dir` resolves to this repository's `agent-system/extensions/core`; `scripts/deploy-headless.sh` exists there. |
| Worktree element moved to its own held task | Confirmed: task 686 `batch_worktree_creation_when_isolation_on`, status `hold`, depends on 669. |
| `worktree_isolation` values `batch` and `off`, undeclared means `off`; neither key declared by this task | Confirmed against the amending record's "R5, amended"; `jq keys .claude-extensions.json` returns only `extensions`, `version`. |
| Admission sits "beside the existing lock probe and queue-check gates" in the cycle-plan script | Corrected: only the lock probe is in `orchestrate-cycle-plan.sh`. The blocking `queue-check` lives in `commands/orchestrate.md`, which is at its byte ceiling (21,496 bytes, re-measured) and cannot take the gate. The cycle-plan script is the site. |
| Admission refuses off-branch or dirty-outside-state-territory invocations | Narrowed by the record, which wins: "R5, amended" says a repository that declares nothing "behaves as it does today, apart from the R1 branch check once `integration_branch` is declared". Both refusals arm only when the key is declared. See Decisions. |
| One batch record per invocation, composing with task-lock, session registry, queue, MAX_TASKS | Confirmed feasible: the record's own existence is the first-cycle marker, so it is one per session by construction and touches none of those mechanisms. |

Report line references re-checked live: `emit_and_exit()` at line 730, `orchestrate_cycle_plan_main()`
at line 850, plan-cache replay block at lines 662-675, the real-`git` arm of the cycle-plan suite
at line 4882, and the four per-session resolvers ending at line 487 of
`lib/runtime-file-patterns.sh` all match. Document line counts match the report (315 and 666).
The enumeration of suites with an explicit library list was re-derived with a different pattern
than the report used (suites naming `batch-gate-marker-lib.sh` without a wholesale `lib/*.sh`
copy): four hits, of which two sandbox the cycle-plan script (`test-orchestrate-cycle-plan.sh`,
`test-orchestrate-unwind-dispatch.sh`) and two copy that one library for another script
(`test-batch-gate-pending-marker.sh`, `test-orchestrate-batch-gate.sh`). Same two suites as the
report.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was supplied in this dispatch. The task is the first member of the running
orchestration's batch (669, 673, 685, 675); tasks 673 and 686 depend on it.

## Goals & Non-Goals

**Goals**:
- Schema rows for `integration_branch` and `worktree_isolation` in
  `context/standards/repo-level-declarations.md`, stating type, values, default, which values
  are live, and the exact state-territory path set.
- Admission in `orchestrate-cycle-plan.sh`: refuse `worktree_isolation: batch` (and any unknown
  value) loudly, naming the held task by slug; refuse an off-branch primary tree and
  dirty tracked paths outside state territory when `integration_branch` is declared; print one
  named advisory when it is not.
- One batch record per invocation at `specs/.orchestration/batch/{session_id}.json`, registered
  in `context/standards/orchestrator-runtime-files.md`, shaped so the deferred batch-branch and
  worktree-path fields arrive later as an additive field write.
- A dedicated suite for the library and a real-`git` group in the cycle-plan suite.
- Redeploy from the source store.

**Non-Goals**:
- Worktree creation, siting, sparse checkout, resume idempotence (task 686).
- Appending landing proofs, or fixing their element shape beyond "append-only array" (task 673).
- Migrating the two existing inline `integration_branch` readers in `milestone-ref-land.sh` and
  `milestone-review-handoff.sh` to the shared reader (in task 673's `file_scope`).
- Rewriting `git-workflow-narrative.md`'s sentence about admission (task 675).
- Declaring either key in any repository's `.claude-extensions.json`.
- Any edit to `skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`, or the dispatch
  composer.
- An exemption for dirt owned by a live sibling orchestration.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new hard-sourced library breaks sandboxed suites that copy an explicit library list | H | H | Phase 3 adds the library to both lists in the same phase that adds the `source` line; the suite run in Phase 3 proves it. |
| Roughly thirty existing cycle-plan suite groups run in a non-`git` sandbox and would change behaviour | H | M | The predicate skips the branch test, dirty test and record write silently when the project root is not a `git` work tree; Phase 2 pins this with a fixture. |
| The real-`git` arm of the cycle-plan suite sees a new advisory line on standard error | M | M | Phase 3 reads that arm's assertions before wiring; the advisory goes to standard error only and never to the JSON channel on fd 3. |
| `index-entries.json` currently carries a sibling orchestration's uncommitted one-line `line_count` hunk (for `standards/git-staging-scope.md`) | M | H | Phase 1 checks `git diff HEAD -- agent-system/extensions/core/index-entries.json` before editing. If a foreign hunk is still present, it is left untouched (never reverted), the phase edits only its own two `line_count` values, and an `issue-record.sh` row names the foreign hunk that rides along in the commit. |
| A declaring repository is refused while another orchestration has uncommitted work in the same tree | M | H (once declared) | Ruled by R1 and not softened here. The refusal lists every dirty path. No repository is affected until it declares the key. A remedy, if needed, is a dated amendment to the record. |
| A refused invocation has already registered its session and queue entries | M | L | `SKILL.md` routes any non-null `stop` to the conclusion moves, which release both. The suite pins the contract the skill consumes: a non-null `stop` with `reason` and `message`, zero dispatch rows, no plan cache, no batch record. End-to-end release is observed once in Phase 4. |
| Doc and code drift on the state-territory set or the held task's slug | M | M | The library suite pins both strings against the schema document (a doc-sync assertion), which is why Phase 2 depends on Phase 1. |
| A name collides with the removal guard in `test-askuserquestion-rehome.sh` | L | L | No new identifier contains `dispatch-worktree.sh` or `task_selected_for_worktree_isolation`. |
| `guard-destructive-git.sh` judges the primary tree while a suite builds scratch fixtures | L | M | Fixtures are built without discard forms (`git checkout -- path`, `git restore`, `git reset --hard`); a file is restored with `git show HEAD:path > path` where needed. |
| The task's stored `file_scope` still names `scripts/batch-worktree.sh` and its suite | L | H | Neither path appears in any phase here. If plan-postflight harvest unions rather than replaces, the two stale entries need removing from task 669's `file_scope` by the orchestrator; flagged in the handoff. |

## Decisions

- **Both branch and dirty refusals arm only when `integration_branch` is declared.** The
  description reads as unconditional; the amending record's "R5, amended" and "Isolation-off
  repositories (Option L1)" sections limit an undeclaring repository to today's behaviour, and
  the description defers to the record. Undeclared yields one advisory naming the key, the
  declarations file and the checked-out branch, matching the two existing readers' fallback.
- **State territory is exactly `specs/`, `.claude-extensions.json`, `.memory/`.** R1 names the
  first two and delegates the exact set to this task; the report's measurement M2 shows
  `.memory/memory-index.json` is dirtied by ordinary operation with no task editing it.
  Source-store `index-entries.json` files are excluded: they are derived from real edits and
  naming them would put a repository-specific path in a deliverable.
- **Only tracked changes count.** `git diff --name-only -z HEAD` with pathspec exclusions;
  untracked files never refuse. R1 says "tracked paths".
- **`worktree_isolation` is checked first and every cycle; an unknown value refuses like
  `batch`.** It needs no `git`, and a repository must not ask for a mode and get silence. This is
  the one loud exception to the declarations document's fail-open posture, on the same ground as
  its declared-but-unusable `closing_gate` exception.
- **The branch test runs every cycle; the dirty test runs on the first cycle only.** R1 says the
  primary tree is never switched during orchestration; after the first cycle this invocation's
  own dispatches legitimately leave uncommitted work. "First cycle" means no batch record exists
  for this session.
- **Detached `HEAD` refuses.** The branch is read with `git symbolic-ref -q --short HEAD`, not
  `git rev-parse --abbrev-ref HEAD`, which prints the literal `HEAD` when detached.
- **Deferred fields live under one absent `isolation` object.** Adding it later is a single
  field write and no reader of the existing fields changes.
- **Stop reasons**: `isolation_unimplemented`, `off_integration_branch`, `dirty_primary_tree`.
- **Delivery as a library, not inline.** The landing, worktree and cleanup tasks all read or
  extend the record; `repo-level-declarations.md` records a second consumer as the trigger for
  promoting an inline reader to `scripts/lib/`.
- **No `user_decision`.** Every choice is settled by the record or by measurement.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

All paths below are source-store paths. Before the Phase 4 redeploy, run every suite and helper
from `agent-system/extensions/core/scripts/`, never from the deployed `.claude/scripts/` copy,
which does not yet contain this task's edits.

### Phase 1: Schema rows and runtime-file registration [COMPLETED]

**Goal**: The two standards documents state the declarations, the state territory, which values
are live, and the batch record's place and disposition.

**Tasks**:
- [x] Check `git diff HEAD -- agent-system/extensions/core/index-entries.json`. If a hunk not
      belonging to this task is present, leave it in place and record one `issue-record.sh` row
      naming it (see Risks). *(completed)*
- [x] In `context/standards/repo-level-declarations.md`, add a section "The `integration_branch`
      Declaration": top-level string key, shape as fixed by ruling R4 of the decision record
      `branch-topology-and-landing-strategy.md`; live. State that declaring it is what arms
      admission; that undeclared, empty or non-string yields one named advisory and no refusal;
      the two refusals and their stop reasons; that only tracked changes are tested; and the
      exact state-territory set (`specs/`, `.claude-extensions.json`, `.memory/`) with one
      sentence on why a blanket clean-tree test is refused. Include the fail-open table in the
      document's existing form. *(completed)*
- [x] Add a section "The `worktree_isolation` Declaration": top-level string key; values `off`
      (live) and `batch` (declared, not implemented); undeclared means `off`. State that `batch`
      and any unrecognised value are refused at admission with reason `isolation_unimplemented`,
      name the implementing work by its slug `batch_worktree_creation_when_isolation_on`, and
      cite the document's `closing_gate` exception by section name as the precedent for a loud
      refusal in an otherwise fail-open document. *(completed)*
- [x] Extend the Overview's enumeration of schemas and the See Also list to cover both keys and
      the new library `scripts/lib/batch-admission-lib.sh`. *(completed)*
- [x] In `context/standards/orchestrator-runtime-files.md`, add a Class Table row for
      `specs/.orchestration/batch/{session_id}.json`: writer (admission in
      `orchestrate-cycle-plan.sh` via the library, once per invocation), readers, cleanup
      (never; out of the session reaper's reach because its globs match literal filenames
      directly under `specs/.orchestration/`), disposition "durable provenance, but untracked"
      alongside the queue archive row. State the field list, that `landing_proofs` is an
      append-only array written under the existing `specs/.commit-lock` mutex by the landing
      mechanism, and that batch-branch name and absolute worktree path are added later as a
      single `isolation` object, an additive field write that reshapes nothing. *(completed)*
- [x] Update the two documents' `line_count` values in `index-entries.json` with a targeted
      in-place edit of those two integers to match `wc -l` (no whole-file `jq` rewrite). *(completed)*
- [x] Write no task number and no record-versioning phrasing into either document; name the
      held work by slug only, and state the current design only. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The schema document is 315 lines and the runtime-files document 666 lines
at authoring (re-measured); confirm with `wc -l` before editing and set `line_count` from the
post-edit `wc -l`, not from an estimate. The suite list in the Tier Justification is the
selector's output at authoring; re-run it if the phase's file set changes.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's three paths covers the index edit, selecting test-audit-task-proposals.sh, test-context-reachability.sh, test-deploy-orphans.sh, test-deploy-propagation.sh, test-handoff-dispatch-identity.sh, test-index-entries-schema.sh, test-install-uninstall-extension.sh, test-manifest-scripts-sync.sh, test-roadmap-command-registration.sh, test-runtime-file-tracking.sh and test-session-runtime-files.sh, and the unmapped schema document is covered by the doc-lint and task-reference gates via `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4` with this repository's root as target.

**Files to modify**:
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - two new
  declaration sections, Overview and See Also entries. Exists (confirmed at authoring).
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - one Class
  Table row and its field description. Exists (confirmed at authoring).
- `agent-system/extensions/core/index-entries.json` - `line_count` for the two documents above
  (coupled generated surface; the drift check is not commit-blocking here, no `pre-commit` hook
  is installed, and it is reconciled in this same phase anyway).

**Verification**:
- Diff read-through: every changed hunk in the two documents is prose or table text.
- The narrowed pass and the gate 3,4 pass named in Tier Justification are green (exit status
  checked, not only output).
- `grep -n 'worktree_isolation\|integration_branch'` on the schema document shows both sections;
  the `worktree_isolation` section states `off` is live and `batch` is not implemented.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no new finding
  for the two documents.

---

### Phase 2: Admission library, path resolver and library suite [COMPLETED]

**Goal**: A sourced library that reads both declarations, evaluates the admission predicate and
writes the batch record, with a suite covering every verdict.

**Tasks**:
- [x] Add `runtime_batch_record_path <specs_dir> <session_id>` to
      `scripts/lib/runtime-file-patterns.sh` beside the four existing per-session resolvers,
      returning `<specs_dir>/.orchestration/batch/<session_id>.json`, with the same
      compute-only contract comment. Additive; no existing function changes. *(completed)*
- [x] Create `scripts/lib/batch-admission-lib.sh` with a double-source guard and these
      functions (names may be adjusted, but must avoid the strings `dispatch-worktree.sh` and
      `task_selected_for_worktree_isolation`): *(completed)*
  - a reader for `worktree_isolation` returning `off`, `batch`, or the raw unrecognised value;
    absent key or missing `jq`/declarations file reads as `off`;
  - a reader for `integration_branch` returning the declared name or empty for undeclared,
    empty-string or non-string;
  - the state-territory set as one array constant (`specs`, `.claude-extensions.json`,
    `.memory`) and a function listing tracked dirty paths outside it via
    `git diff --name-only -z HEAD` with `:(exclude)` pathspecs;
  - the predicate, taking project root, specs dir, session id and a dry-run flag, and reporting
    a verdict (`admit`, `skip`, or `refuse`), a reason and a message through named output
    variables or a single JSON line, never by exiting;
  - the record writer, tmp-file-then-rename, creating `batch/` on demand.
- [x] Implement the predicate order exactly: (1) `worktree_isolation` not absent/`off` refuses
      with `isolation_unimplemented`, the message naming the declared value and the slug
      `batch_worktree_creation_when_isolation_on`; (2) not a `git` work tree: `skip`;
      (3) `integration_branch` undeclared: advisory on standard error on the first cycle only,
      no refusal; (4) declared and `git symbolic-ref -q --short HEAD` differs or fails: refuse
      with `off_integration_branch`, naming both; (5) declared, no batch record for this
      session, dirty paths outside state territory: refuse with `dirty_primary_tree`, listing
      every path; (6) admit, writing the record when none exists and not under dry-run. *(completed)*
- [x] Record shape: `schema` (1), `session_id`, `orchestration_id` (or null), `task_numbers`,
      `admitted_at`, `integration_branch` (the declared name, or the checked-out branch when
      undeclared), `integration_branch_declared`, `integration_tip_at_cut` (40-hex, or null on
      an unborn branch), `worktree_isolation` (`off`), `landing_proofs` (`[]`). No `isolation`
      key. *(completed)*
- [x] Create `scripts/tests/test-batch-admission-lib.sh`, building scratch `git` repositories
      under a temporary directory without discard-form commands. Cover the report's fourteen
      fixtures (clean admit; dirt only inside state territory; untracked file outside it; staged
      new file; staged rename; working-tree deletion; other branch; detached `HEAD`; `batch`;
      unknown value; explicit `off`; undeclared key; unborn branch; non-`git` root), plus:
      record shape and absence of an `isolation` key; second call in the same session skips the
      dirty test and does not rewrite the record; dry-run writes nothing; refusal writes nothing;
      the `isolation_unimplemented` message contains the slug and no task number. *(completed)*
- [x] Add doc-sync assertions to the same suite: each state-territory member and the slug
      appear in `context/standards/repo-level-declarations.md`. *(completed)*
- [x] Register both new files with
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`, then confirm
      `--check` is clean. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Fourteen report fixtures plus five added assertions is the planned
coverage, not a required count; the implementer confirms each of the six predicate steps has at
least one admit-side and one refuse-side fixture where both exist. The suite list below is the
selector's output at authoring, when neither new file exists (the source-store corpus returns
the first forty-four names; the deployed corpus adds the five other-extension suites named
last); once
`test-batch-admission-lib.sh` exists the selector may add it, and it is run directly in any case.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's four paths covers the additive resolver and the manifest registration, selecting test-batch-gate-pending-marker.sh, test-common-lib.sh, test-deploy-baseline-lib.sh, test-deploy-orphans.sh, test-deploy-propagation.sh, test-deploy-verify-overlap.sh, test-double-loading-check.sh, test-gate3-parallel-equivalence.sh, test-gate3-strict-equivalence.sh, test-gate8-expected-new-distinction.sh, test-gate8-suite-selection.sh, test-gate-cache-equivalence.sh, test-gate-lock-host-scope.sh, test-gate-lock.sh, test-git-commit-phase.sh, test-index-entries-schema.sh, test-init-specs.sh, test-install-uninstall-extension.sh, test-lint-branch-gated-sections.sh, test-lint-task-lookup-adoption.sh, test-lint-test-root-resolution.sh, test-manifest-scripts-sync.sh, test-mcp-merge-target.sh, test-orchestrate-conclusion-roadmap.sh, test-orchestrate-cycle-plan.sh, test-orchestrate-cycle-postflight.sh, test-orchestrate-recap.sh, test-orchestrate-unwind-dispatch.sh, test-plan-file-scope-harvest.sh, test-roadmap-command-registration.sh, test-routing-resolution.sh, test-run-all-failure-reporting.sh, test-run-all-parallel.sh, test-run-all-selection.sh, test-run-all-shared-fixture.sh, test-run-task-observers.sh, test-runtime-file-tracking.sh, test-script-inventory.sh, test-skill-base-lifecycle.sh, test-source-store-path-lib.sh, test-validate-artifact.sh, test-validate-no-python-state-write.sh, test-verify-deploy-context-budget.sh and test-verify-deploy-gate-selection.sh, plus test-approve-paths.sh, test-approve-structural.sh, test-lean-challenge-observe.sh, test-lean-challenge-snapshot.sh and test-lean-plan-compliance-check.sh when the same paths are resolved against the deployed suite corpus, and nothing sources the new library yet.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/batch-admission-lib.sh` - new library (created by
  this phase).
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - new batch-record path
  resolver beside the four per-session resolvers. Exists (confirmed at authoring).
- `agent-system/extensions/core/scripts/tests/test-batch-admission-lib.sh` - new suite (created
  by this phase).
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entries for the two new
  files (coupled generated surface, regenerated in this phase by the manifest sync helper's
  write mode).

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-batch-admission-lib.sh` exits 0.
- Non-vacuity: temporarily inverting the dirty-path exclusion (or removing one state-territory
  member) makes at least one fixture fail; restore by re-applying the edit, not by a discard
  command.
- The narrowed pass named in Tier Justification is green.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- `bash -n` on both new files and on `runtime-file-patterns.sh`.

---

### Phase 3: Wire admission into the cycle-plan script [NOT STARTED]

**Goal**: Every `/orchestrate` invocation passes through the predicate once before any mutation,
and a refusal reaches the operator through the existing `stop` channel.

**Tasks**:
- [ ] Read the real-`git` arm of `scripts/tests/test-orchestrate-cycle-plan.sh` (near line 4882)
      and note any assertion on exact standard-error content that an advisory line could break.
- [ ] In `scripts/orchestrate-cycle-plan.sh`, source `lib/batch-admission-lib.sh` in the
      existing hard-sourced library block, following the neighbouring libraries' failure
      handling.
- [ ] Add one admission function and call it after the plan-cache replay block and before
      `orchestrate_cycle_plan_main`'s redeploy checkpoint (so before `deploy-headless.sh` can
      run). On `refuse` it sets `stop_reason` and `stop_message` and calls `emit_and_exit`; on
      `admit` or `skip` it returns. It passes `dry_run` through so `--dry-run` evaluates and
      reports the verdict but writes no record. Advisory and diagnostic text goes to standard
      error only; nothing is written to the JSON channel except through `emit_and_exit`.
- [ ] Confirm a refusal builds no dispatch row, so `emit_and_exit` writes no plan cache and a
      re-run re-evaluates.
- [ ] Pass the invocation's task numbers and orchestration id (where the script already holds
      them) into the record writer; pass null for an id the script does not hold. Do not add a
      new command-line flag to obtain one.
- [ ] Add `batch-admission-lib.sh` to the inline library list in
      `scripts/tests/test-orchestrate-cycle-plan.sh` and to `REQUIRED_LIB_SCRIPTS` in
      `scripts/tests/test-orchestrate-unwind-dispatch.sh`.
- [ ] Add one group to `test-orchestrate-cycle-plan.sh` that makes the sandbox a real `git`
      repository for that group only, following the existing arm's setup and teardown, and
      asserts through the real script: declared and off-branch gives `stop.reason`
      `off_integration_branch`; declared and dirty outside state territory gives
      `dirty_primary_tree` with the path in the message; `worktree_isolation: batch` gives
      `isolation_unimplemented` with the slug in the message; each refusal has zero dispatch
      rows, no plan cache and no batch record; a clean declared run admits and writes exactly
      one record; a second cycle in the same session leaves the record unchanged and does not
      re-run the dirty test; `--dry-run` reports a refusal and writes nothing; undeclared keys
      leave the pre-existing output unchanged apart from one advisory line on standard error.
- [ ] Make no edit to `skills/skill-orchestrate/SKILL.md` or `commands/orchestrate.md`; confirm
      both byte counts are unchanged (27,494 and 21,496 at authoring).

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: Exactly two suites carry an explicit library list beside a sandboxed copy
of the cycle-plan script (derived twice at research and authoring with different patterns).
Confirm at implementation by running every suite in the Tier Justification list: a third
explicit list would surface as a sourcing failure there, and is then added to this phase's
edits and recorded as a deviation.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's three paths runs the changed script plus every suite that sandboxes it, selecting test-batch-gate-pending-marker.sh, test-deploy-baseline-lib.sh, test-deploy-ledger-lib.sh, test-force-phases.sh, test-gate-out-self-attribution.sh, test-git-commit-scoped.sh, test-handoff-dispatch-identity.sh, test-handoff-reader-parity.sh, test-lint-deploy-caller-wrap.sh, test-lint-json-channel-discipline.sh, test-mint-dispatch-seq.sh, test-orchestrate-batch-gate.sh, test-orchestrate-build-dispatch.sh, test-orchestrate-churn.sh, test-orchestrate-context-growth.sh, test-orchestrate-cycle-plan.sh, test-orchestrate-cycle-postflight.sh, test-orchestrate-predispatch-review.sh, test-orchestrate-record-decision.sh, test-orchestrate-triage-classify.sh, test-orchestrate-unwind-dispatch.sh, test-postflight-deploy-gate.sh, test-redeploy-checkpoint-promotion.sh, test-resume-scan-nonconformance.sh, test-routing-resolution.sh and test-session-runtime-files.sh.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - source line, admission
  function, one call site. Exists (confirmed at authoring).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - library list
  entry and one new real-`git` group. Exists (confirmed at authoring).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` - one new
  entry in its required-library array. Exists (confirmed at authoring).

**Verification**:
- The narrowed pass named in Tier Justification is green, including every pre-existing
  cycle-plan suite group (the non-`git` sandbox groups prove the silent skip).
- The new group fails when the admission call is commented out (non-vacuity), then passes with
  it restored.
- `wc -c` on `skills/skill-orchestrate/SKILL.md` and `commands/orchestrate.md` is unchanged.
- `bash agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` exits 0.

---

### Phase 4: Redeploy and close [NOT STARTED]

**Goal**: The deployed tree carries the admission gate and documents, and the task's whole
touched set is verified against it.

**Tasks**:
- [ ] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh` and check its
      exit status and reported result. Its `line_count` auto-repair should report nothing to
      correct for the two documents; if it corrects either, the regenerated
      `index-entries.json` is staged in this phase's commit.
- [ ] Confirm the deployed copies exist: `.claude/scripts/lib/batch-admission-lib.sh`,
      `.claude/scripts/tests/test-batch-admission-lib.sh`, and the two documents under
      `.claude/context/standards/`.
- [ ] Run the deployed cycle-plan script once with `--dry-run` in this repository (both keys
      undeclared) and confirm: one advisory naming `integration_branch`, no `stop`, no batch
      record written.
- [ ] Confirm the three owned criteria against suite evidence and record where each is pinned:
      off-branch or dirty refusal; loud `batch` refusal naming the held work; both schema rows
      with live versus unimplemented values.
- [ ] Confirm `.claude-extensions.json` in this repository declares neither key
      (`jq 'has("integration_branch"), has("worktree_isolation")'` prints `false` twice).
- [ ] Run the task-reference lint and the record-versioning lint over every file this task
      edited under `agent-system/**`.
- [ ] Record issues and wins with `issue-record.sh` as they arise in every phase; if a phase has
      none, say so in the summary.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - only if the redeploy's `line_count`
  auto-repair changes it (coupled generated surface of Phase 1's document edits).
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this task's full touched
  set (the two standards documents, `index-entries.json`, `manifest.json`,
  `lib/batch-admission-lib.sh`, `lib/runtime-file-patterns.sh`, `orchestrate-cycle-plan.sh`,
  and the three suites) is green against the redeployed tree.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- The task-reference and record-versioning lints report no new finding.
- As the final phase, this phase's own in-dispatch obligation is the scoped touched-path check
  above plus an explicit deferral of the complete gate set
  (`bash .claude/scripts/verify-deploy.sh`) to the orchestration close under `/orchestrate`,
  never an independent full-battery run as this phase's own criterion. A standalone,
  non-orchestrated run of this phase runs the complete gate set directly.

## Testing & Validation

- [ ] An invocation off the declared integration branch is refused with `off_integration_branch`
      (library suite and cycle-plan suite).
- [ ] An invocation with tracked dirt outside `specs/`, `.claude-extensions.json` and `.memory/`
      is refused with `dirty_primary_tree`, listing the paths; dirt only inside that set, and
      untracked files anywhere, admit.
- [ ] `worktree_isolation: batch` and any unknown value are refused with
      `isolation_unimplemented`, the message naming `batch_worktree_creation_when_isolation_on`.
- [ ] With `integration_branch` undeclared: one advisory, no refusal, existing suite output
      otherwise unchanged.
- [ ] Exactly one batch record per session; later cycles neither rewrite it nor re-test dirt;
      the branch test still runs every cycle.
- [ ] `--dry-run` and every refusal write no record and no plan cache.
- [ ] A non-`git` project root skips silently; all pre-existing cycle-plan suite groups pass.
- [ ] Both schema sections present; `off` stated live, `batch` stated not implemented.
- [ ] `skills/skill-orchestrate/SKILL.md` and `commands/orchestrate.md` byte-identical.
- [ ] No task number, literal branch name, consumer-repository path or record-versioning
      phrasing in any file under `agent-system/**` touched by this task.
- [ ] Neither key declared in any `.claude-extensions.json`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/batch-admission-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-batch-admission-lib.sh` (new)
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` (resolver added)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (admission wired)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` (updated)
- `agent-system/extensions/core/context/standards/repo-level-declarations.md`,
  `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (updated)
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  (regenerated surfaces)
- Redeployed `.claude/` tree
- `specs/669_integration_branch_admission_and_batch_worktree/summaries/01_integration-branch-admission-summary.md`

## Rollback/Contingency

Each phase is one commit, so a phase is undone with `git revert` of that commit followed by a
redeploy with `deploy-headless.sh`. Reverting Phase 3 alone removes the gate from every
invocation while leaving the library and documents inert, which is the fastest safe fallback if
admission misfires in live use. No repository declares either key, so the only live behaviour
change before a declaration is one advisory line and one small untracked record per invocation.
If uncommitted work must be discarded mid-phase, follow the snapshot-then-rollback recipe in
`context/contracts/recovery.md`'s rollback rung; do not discard files directly, because the
primary tree carries other orchestrations' uncommitted work.
