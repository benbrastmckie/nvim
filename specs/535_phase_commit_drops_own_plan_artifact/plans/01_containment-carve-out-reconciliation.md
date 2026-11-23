# Implementation Plan: Task #535

- **Task**: 535 - Carve a task's own specs/ artifacts out of git-commit-phase.sh's containment filter, so a task's own plan file is never dropped from its own phase commit.
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: port_containment_strip_to_git_commit_scoped (567) — already completed; satisfied in fact, no edge needed
- **Research Inputs**: specs/535_phase_commit_drops_own_plan_artifact/reports/01_containment-filter-carve-out.md
- **Artifacts**: plans/01_containment-carve-out-reconciliation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The code defect this record opens with is already closed: `scripts/git-commit-phase.sh` admits
the committing task's own resolved task directory into the array its `is_contained()` predicate
iterates, and the suite pins that admission. What remains is a two-part reconciliation: the
standard document that specifies this filter still states a **false mechanism** for the carve-out,
and the suite does not yet pin two shapes the record's acceptance criteria name — a dotfile
sitting directly at the task-directory root, and a positive demonstration that the post-commit
completeness check actually RUNS in the single-own-file case rather than being silently disarmed.
This plan corrects the one false sentence and adds the two missing fixtures, without touching the
predicate, `git-commit-scoped.sh`, or the agent prose that is already the correct specification.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch extracted was checked against live state in this dispatch.
Results, stated explicitly even where they only confirm the description:

1. **"so a task's own plan file is never dropped from its own phase commit"** (title line) —
   **SUPERSEDED, as the description's own re-measurement paragraph already says.** The carve-out
   is landed in the source store: `scripts/git-commit-phase.sh` carries
   `file_scope_arr+=("${task_dir}/")` under its `Own-task-directory member` comment block, with
   `specs/TODO.md` and `specs/state.json` admitted a few lines below via the engine-written-state
   allowlist (hardcoded two-literal fallback if that library fails to resolve). Route (a) is done
   and MUST NOT be re-implemented.
2. **The false mechanism sentence in `context/standards/git-staging-scope.md`** — **CONFIRMED
   STILL PRESENT AND STILL FALSE**, verbatim, in the source-store copy's "Staging-Layer
   Containment Filter (a Refinement of the Fail-Safe Direction Above)" subsection: "...are never
   tested against this filter at all — they are appended to the staged set before the filtered
   loop runs, structurally outside its reach." A repo-wide grep for that phrase returns only this
   subsection (source-store copy plus its byte-identical deployed mirror). This is the record's
   one remaining genuine defect.
3. **`agents/general-implementation-agent.md`'s prose is already correct — do not edit it** —
   **CONFIRMED** by the research report, which read the "Phase-Commit Containment Self-Check"
   step 2 text and found it compatible with the landed admission-based mechanism. Treated here as
   a non-goal, not a work item.
4. **Acceptance item (1)'s "Case 7 (genuine out-of-scope drop) and Case 8 (fail-open on missing
   `file_scope`)"** — **STALE NUMBERING, GUARANTEES INTACT.** The suite has grown to 39 numbered
   cases / 98 assertions / 1676 lines. The two guarantees the record wants protected now live at
   Case 16 (paired genuine-excursion drop alongside an own-task-directory path), Cases 17a/b/c
   and 22 (fail-open across missing / empty / malformed `file_scope`), and Case 36 (undeclared
   path still dropped). The instruction's intent — extend, never replace — carries over unchanged
   to the current numbering.
5. **The research report's "98/98 passing" figure** — **RE-RUN LIVE IN THIS DISPATCH, CONFIRMED
   UNCHANGED**: `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` →
   `Results: 98 passed, 0 failed`. This is the baseline the new cases extend.
6. **Acceptance item (3)'s `specs/TODO.md` / `specs/state.json` half** — **ALREADY SATISFIED.**
   Case 21 (VERIFY 3) asserts both land with no drop warning when self-reported in
   `files_touched`, and are never proposed into `proposed_file_scope`. No new work is owed for
   that half; the `.orchestrator-handoff.json` half added by the later evidence section is NOT
   yet covered and is Phase 1's work.
7. **Transplanted criterion (c)** ("class membership from a single source of truth shared with
   `orchestrator-runtime-files.md`") — **MOOT**, as the description's own re-measurement rules:
   the landed carve-out is a direct path-shaped literal and never consults
   `scripts/lib/runtime-file-patterns.sh`. No class-membership question survives to be settled.
8. **Dependency on 567** — **SATISFIED IN FACT**: `specs/state.json` shows 567 `completed`;
   task 535's own `depends_on` is `null`. No edge is added — an edge onto a completed task
   changes no admission outcome and would be bookkeeping noise.

### Research Integration

The research report's five recommendations are adopted in full and map onto the phases below:
recommendation 1 → Phase 2; recommendations 2 and 3 → Phase 1; recommendation 4 (the correctly
re-scoped fails-first discipline) → Phase 1's deliberate-revert probe; recommendation 5 (no change
to the predicate, `git-commit-scoped.sh`, any V-gate, or the agent prose) → the Non-Goals below.

One refinement the plan makes on recommendation 3: rather than asserting the completeness check
ran only *via negativa* (absence of the four skip-family warning strings), Phase 1 uses the
planted-`pre-commit`-hook technique the suite's own Case 1 already uses to make the check's
execution **positively observable** — a hook that reverts the own-task-directory artifact inside
the temporary partial index forces `exit 6` naming that path if and only if the check ran. This
is strictly stronger than the via-negativa form and is what makes the fails-first demonstration
mean something: with the carve-out line removed, `files_touched` empties, `run_completeness_check`
flips to `false`, and the same fixture returns `rc=0` with no `exit 6` — the exact disarmament the
record identifies as the real cost.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Replace the false "structurally outside its reach" mechanism claim in
  `context/standards/git-staging-scope.md` with an accurate statement of how the carve-out is
  actually achieved, reconciled with the already-correct "implicit, unconditional in-scope member"
  sentence immediately preceding it.
- Pin, by regression fixture, that a dotfile sitting **directly at the task-directory root**
  (`.return-meta.json`, `.orchestrator-handoff.json`) is admitted exactly as a path one level
  down already is.
- Pin, by regression fixture, that the post-commit completeness check **runs** when a phase's only
  self-reported file is the task's own plan artifact.
- Demonstrate both new fixtures fail against a deliberately-reverted copy of the carve-out, then
  pass against the real one.
- Land the result in the deployed tree with `RESULT=landed_verify_clean`.

**Non-Goals**:
- Any change to `is_contained()`, `file_scope_arr`'s construction, or any other logic in
  `scripts/git-commit-phase.sh`. Route (a) is landed; re-implementing it is the failure mode this
  plan guards against.
- Any change to `agents/general-implementation-agent.md` — its prose is the correct specification
  and is the authority the fixtures verify against.
- Any change to `scripts/git-commit-scoped.sh` or any of its V-gates.
- Any change to the drop-and-warn policy, the `issue-record.sh` integration, or the fail-open
  direction for genuine excursions.
- Any change to `scripts/lib/runtime-file-patterns.sh` or
  `context/standards/orchestrator-runtime-files.md` — admitted as permissible territory by the
  transplant, but with criterion (c) moot there is nothing to do there.
- Any widening of the carve-out to admit paths outside the repository (the detached-provenance
  observation in the description is explicitly a different record's business).
- Any `file_scope` or `depends_on` mutation, any retroactive cleanup of already-written spurious
  issue rows, and any renumbering or replacement of existing cases.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The implementer reads the description's opening paragraphs and re-implements the already-landed carve-out | H | M | Premise Re-Validation item 1 above states the closure with its concrete code anchor; Non-Goals names re-implementation first. Any diff touching `scripts/git-commit-phase.sh` beyond the temporary Phase 1 probe is out of scope. |
| The deliberate-revert probe is left in place, shipping a broken script | H | L | The probe is confined to Phase 1, is performed on a scratch copy outside the source store rather than by editing the real file in place, and Phase 1's verification re-runs the full suite against the untouched real script before the phase closes. |
| New fixtures duplicate Case 15/16's coverage without adding signal | M | M | The new paths must be dotfiles **directly at the task-directory root** with no intervening named subdirectory — mechanically distinct from Case 15's `reports/01_probe-report.md` — and the completeness-check case must assert `exit 6`, which no existing own-task-directory case does. |
| The corrected sentence contradicts its own neighbouring prose | M | M | Phase 2 reconciles the two sentences explicitly: admission into `file_scope_arr` IS the mechanism that makes those paths "implicit, unconditional in-scope members", rather than leaving two coexisting claims about one path set. |
| New case numbers collide with a concurrently-growing suite | L | M | Phase 1 re-reads the live file's highest case number immediately before authoring, rather than trusting this plan's assumed 40/41. |
| The corrected sentence restates the policy a third time | M | L | The correction replaces the mechanism clause only; the policy conclusion in the same subsection is already accurate and is left untouched. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Pin dotfile-at-root admission and completeness-check execution [COMPLETED]

**Goal**: Extend `scripts/tests/test-git-commit-phase.sh` with the two regression shapes the
record's acceptance criteria name and the suite does not yet carry, each demonstrated to fail
against a deliberately-reverted copy of the carve-out before passing against the real one.

**Tasks**:
- [x] Re-read the live tail of `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`
      and record the current highest case number; author the new cases strictly after it. Do not
      renumber, reorder, or alter any existing case. *(completed: highest case was 39/98
      assertions; new cases appended as 40/41)*
- [x] Re-read Case 15 (own-task-directory admission) and Case 1 (the planted-`pre-commit`-hook
      `exit 6` fixture) as the two shape templates the new cases follow. *(completed)*
- [x] Add a dotfile-at-task-directory-root case: a fixture whose declared, non-empty `file_scope`
      names only source paths (`src/a.txt`-family, as the existing fixtures do), whose
      `files_touched` carries `specs/999_probe/.return-meta.json` and
      `specs/999_probe/.orchestrator-handoff.json` — both dotfiles directly at the task-directory
      root, with no intervening named subdirectory. Assert, for each: `rc=0`; the path appears in
      `git show --name-only --format= HEAD`; no `dropping out-of-scope path '<path>'` warning is
      emitted; and no `scope excursion` row is written to the fixture's `issues.jsonl`.
      *(completed: Case 40)*
- [x] Add a completeness-check-runs case: a fixture whose sole `files_touched` entry is the task's
      own plan artifact (`specs/999_probe/plans/01_probe-plan.md`), with a planted `pre-commit`
      hook that reverts that path inside the temporary partial index via
      `git update-index --cacheinfo` against its pre-commit blob sha, exactly as Case 1 does.
      Assert: `rc=6`; the plan path is named in the completeness-check failure output; and the
      commit is still created (HEAD advances by 1). An `exit 6` here is only reachable if
      `run_completeness_check` survived containment filtering — that is the point of the case.
      *(completed: Case 41)*
- [x] Add a sibling assertion in the same fixture family confirming the ordinary (unhooked)
      single-plan-file run returns `rc=0` with none of the four skip-family warning strings
      present (`progress file not found`, `progress file is not valid JSON`, `nothing to derive`,
      `completeness check failed`), so the pair reads as "the check ran, and it ran clean".
      *(completed: Case 41 sibling, unhooked)*
- [x] Fails-first demonstration: copy `scripts/git-commit-phase.sh` to a scratch path outside the
      source store, delete the `file_scope_arr+=("${task_dir}/")` line (and the engine-written-state
      allowlist splice) from the COPY only, point the new cases at the copy, and confirm each new
      assertion fails. Record the observed pre-fix behaviour in the implementation notes. Restore
      the cases to the real script path and confirm green. The real
      `scripts/git-commit-phase.sh` is never edited. *(completed: Case 40 dropped both dotfiles
      with warnings pre-fix; Case 41 returned rc=5 (git-commit-scoped.sh's own V8 partial-commit
      mismatch) instead of the expected rc=6 pre-fix, since the plan path never survived
      containment to reach the completeness check at all. Both pass against the real script;
      `git diff -- agent-system/extensions/core/scripts/git-commit-phase.sh` stayed empty
      throughout.)*
- [x] Add a short header comment above each new case stating what it pins and, for the
      completeness-check case, that `exit 6` is the positive observable for the check having run.
      Cite durable anchors only — function names (`is_contained`), variable names
      (`files_touched`, `file_scope_arr`, `run_completeness_check`), file names. No task-number
      references, no record-versioning language. *(completed)*
- [x] Run the full suite and confirm every pre-existing case stays green alongside the additions.
      *(completed: 104 passed, 0 failed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh agent-system/extensions/core/scripts/git-commit-phase.sh` covers this phase's whole declared set — the selector maps it to `test-commit-source-store-path.sh`, `test-derived-artifact-probe-lib.sh`, `test-git-commit-phase.sh`, `test-git-commit-scoped.sh`, `test-milestone-ref-land.sh`, `test-skill-base-lifecycle.sh`, `test-task-reference-patterns-lib.sh` and `test-update-task-status.sh`, the third of which is the suite this phase edits.

**Scope Hypothesis**: This phase assumes two new numbered cases suffice (one dotfile-at-root case
carrying both dotfile paths, one completeness-check case carrying the hooked and unhooked runs),
appended after the suite's current highest case number, which this plan read as 39 across 98
assertions. Confirm at implementation time by re-reading the live tail of the test file before
authoring; if the suite has grown, renumber the additions upward and leave the plan's figures
standing as the hypothesis they were.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - append the two new
  regression cases after the current highest-numbered case; no existing case altered.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - declared for the fails-first probe
  only. The probe operates on a scratch COPY outside the source store; this file is expected to
  end the phase byte-identical to its starting state, with no net change and nothing to commit
  from it. If a diff against it survives the phase, that is a defect, not a deliverable.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` runs green with every
  pre-existing assertion still passing and the new assertions added.
- `git diff -- agent-system/extensions/core/scripts/git-commit-phase.sh` is empty.
- The fails-first observation is recorded: each new assertion failed against the reverted scratch
  copy, and in the completeness-check case specifically the reverted copy returned `rc=0` rather
  than `rc=6`, demonstrating the disarmament the fixture exists to prevent.

---

### Phase 2: Correct the containment filter's stated mechanism [COMPLETED]

**Goal**: Replace the false "structurally outside its reach" mechanism claim in
`context/standards/git-staging-scope.md` with an accurate account of how the carve-out is
achieved, reconciled with the correct sentence immediately preceding it.

**Tasks**:
- [x] Re-read the "Staging-Layer Containment Filter (a Refinement of the Fail-Safe Direction
      Above)" subsection in full, including the "The dispatching task's own resolved task
      directory is always an implicit, unconditional in-scope member" sentence that immediately
      precedes the false one, and the "Three Containment sites, not one" paragraph further down
      that the correction must stay consistent with. *(completed)*
- [x] Replace the mechanism clause so it states what actually happens: the task's own resolved
      task directory, `specs/TODO.md` and `specs/state.json` are explicit members of the array
      `is_contained()` iterates and ARE tested by it like any other entry — they pass because they
      are admitted, not because they are skipped. Make plain that admission into that array IS the
      mechanism by which they are "implicit, unconditional in-scope members", so the two adjacent
      sentences read as one claim rather than two coexisting ones. *(completed)*
- [x] Distinguish the fourth path honestly: the plan path supplied via `--plan-path` is appended to
      `stage_paths` on a separate code path and genuinely is never tested by the predicate — and
      that is harmless, because it is always a sub-path of the admitted task directory. State this
      once; it is the only one of the four for which the original "outside its reach" framing was
      ever true. *(completed)*
- [x] Do not restate the policy conclusion — it is already correct in this subsection and
      elsewhere in the document, and a second differently-worded convention is explicitly
      unwanted. *(completed: policy conclusion left untouched)*
- [x] Optionally (advisory, from the research report's Context Extension recommendation) note in
      one sentence that the containment test is plain bash case-pattern matching rather than
      filesystem glob expansion, which is why a dotfile at any depth under an admitted directory
      needs no separate carve-out. Keep it to one sentence or omit it. *(completed: one sentence
      added)*
- [x] Confirm the edited prose carries no task-number references and no record-versioning language
      (no "previously", "no longer", "formerly", "used to"): state the current mechanism directly,
      with no reference to what the sentence used to say. *(completed: confirmed by read-through)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/git-staging-scope.md` covers this edit — the selector maps it to `test-git-commit-phase.sh` and `test-todo-move-pair-staging.sh`, not to the `__FULL_SWEEP__` sentinel.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - replace the mechanism
  clause in the "Staging-Layer Containment Filter" subsection; policy conclusion untouched.

**Verification**:
- `grep -n "structurally outside its reach" agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns nothing.
- `grep -n "never tested against this filter at all" agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns nothing.
- Read-through of the edited subsection confirms the "implicit, unconditional in-scope member"
  sentence and the replacement sentence state one mechanism, not two.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/git-staging-scope.md`
  reports green.
- A task-reference and record-version read-through of the changed hunk confirms neither class of
  forbidden language was introduced.

---

### Phase 3: Deploy and verify [NOT STARTED]

**Goal**: Land both source-store edits into the deployed tree and confirm the deploy reports a
clean verification.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm it reports
      `RESULT=landed_verify_clean`.
- [ ] Confirm the deployed mirrors match the source store for both edited files:
      `diff -q .claude/scripts/tests/test-git-commit-phase.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`
      and the `context/standards/git-staging-scope.md` counterpart.
- [ ] Re-run `bash .claude/scripts/tests/test-git-commit-phase.sh` against the deployed copy and
      confirm it is green there too.
- [ ] Run the scoped touched-path check over this task's touched paths:
      `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh agent-system/extensions/core/context/standards/git-staging-scope.md`.
- [ ] Defer the complete gate set to the orchestration close (Move 4) rather than invoking the
      full battery independently here.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire
  deployed tree. The sentinel is the whole declaration: the regenerated mirrors of both edited
  files are covered by it and are never named directly, since a deployed-tree path is not a
  legitimate scope member and is never hand-edited.

**Verification**:
- `deploy-headless.sh` prints `RESULT=landed_verify_clean`.
- Both `diff -q` comparisons report no difference.
- `bash .claude/scripts/tests/test-git-commit-phase.sh` is green against the deployed copy.
- The scoped touched-path check above reports green; the complete gate set is explicitly deferred
  to the orchestration close, which discharges it once for the invocation.

## Testing & Validation

- [ ] The full `test-git-commit-phase.sh` suite is green, with every pre-existing assertion still
      passing alongside the additions.
- [ ] A dotfile at the task-directory root (`.return-meta.json`, `.orchestrator-handoff.json`)
      self-reported in `files_touched` lands with no drop warning and no `scope excursion` row.
- [ ] The post-commit completeness check demonstrably RUNS in the single-plan-file case —
      `exit 6` is reachable with a planted hook, and the unhooked run returns `rc=0` with none of
      the four skip-family warnings.
- [ ] Each new assertion was observed to fail against a deliberately-reverted copy of the
      carve-out before passing against the real one.
- [ ] A genuine out-of-territory path is still dropped, still warned, and still recorded (Case 16
      and Case 36 remain green), and fail-open on missing / empty / malformed `file_scope` is
      unchanged (Cases 17a/b/c and 22 remain green).
- [ ] `grep` finds no surviving occurrence of either false-mechanism phrase in the standard.
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — two new regression cases.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — corrected mechanism
  statement in the "Staging-Layer Containment Filter" subsection.
- Regenerated deploy mirrors of both files under `.claude/`.
- `specs/535_phase_commit_drops_own_plan_artifact/summaries/01_*-summary.md` at completion.

## Rollback/Contingency

Both deliverables are additive and independently revertible. If the new fixtures prove unsound,
`git checkout` the test file to its pre-phase state — the pre-existing 98 assertions are
unaffected by the additions, so reverting costs nothing already landed. If the corrected sentence
proves to misdescribe the mechanism, revert that single hunk and re-derive the wording by reading
`scripts/git-commit-phase.sh`'s `Own-task-directory member` comment block directly. Neither phase
modifies executable logic, so no runtime rollback is required. If `deploy-headless.sh` reports
anything other than `RESULT=landed_verify_clean`, do not hand-edit under `.claude/**` to force
convergence — diagnose at the source store and redeploy.
