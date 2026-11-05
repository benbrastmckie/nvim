# Implementation Plan: Task #395

- **Task**: 395 - Surface a failed per-cycle scoped commit into the dispatched task's own status
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/395_surface_failed_per_cycle_commit_into_task_status/reports/01_commit-failure-status-surfacing.md`
- **Artifacts**: plans/01_commit-failure-status-demotion.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-postflight.sh` writes an implement dispatch's `completed` status to
`state.json` at WORK (f) (~line 1323) hundreds of lines before WORK (i) (~line 1832) attempts
that cycle's scoped commit. When `git-commit-scoped.sh` exits a loud, attributable code, the
current branch emits an ERROR, an `issues.jsonl` entry, and a `note` field — but leaves the task
at `[COMPLETED]` with its deliverable changes uncommitted on disk. This plan closes that
residual by adding a narrowly-scoped corrective write inside WORK (i): when, and only when, this
same dispatch window's commit genuinely did not land for a task WORK (f) just marked
`completed`, the task is demoted to `partial` with a named blocker and the cycle's verdict is
flipped from `ok` to `defer`. Done means: a genuine commit failure leaves `[PARTIAL]` + a
blocker; a landed-commit code (`6`, `7`) and every non-implement dispatch outcome are provably
untouched.

### Research Integration

The research report is adopted in full, with its key conclusions carried into the phases below:

- **Option (b), not option (a).** Reordering WORK (f)/(i) requires splitting the single
  per-cycle commit into two (task files, then `state.json`/`TODO.md`), breaking the one-commit-
  per-cycle contract that `git-workflow.md` and `dispatch-metrics.sh`'s per-commit accounting
  both rest on. Re-confirmed against the live file during this planning pass.
- **Task 304's recorded reason does not hold mechanically, and nothing in this plan depends on
  it holding.** The monotonic-max clamp is opt-in (`clamp_mode` is `"monotonic-max"` only when
  `force_invoked == "true"`, source line 1165/1167), `partial` is deliberately unranked in
  `STATUS_VOCABULARY_LIFECYCLE_RANK` so `status_vocabulary_would_regress(completed, partial)` is
  false either way, and `update-task-status.sh` has no terminal-state guard on `postflight`
  writes at all — re-verified this pass: `map_status`'s `postflight:partial` arm
  (`scripts/update-task-status.sh:478`) is unconditional. The demotion write is therefore an
  ordinary postflight write, not a fight with a guard.
- **Exit `6` is excluded from the demotion set**, per `git-staging-scope.md`'s own table: V9
  means "the valid paths already committed successfully." Planning-pass confirmation the report
  could not supply: the existing suite already asserts this. `test-orchestrate-cycle-postflight.sh:3401`
  asserts `.verdict` is UNCHANGED between a stubbed exit-6 probe and a clean exit-0 baseline,
  with the inline note "a verdict demotion would fail this". Excluding 6 keeps that assertion
  passing verbatim; including it would require amending a currently-green regression test to
  accommodate a demotion the exit code's own documented semantics do not justify. The decision
  is therefore settled on two independent grounds, not one.
- **`persisted_status` needs no new wiring.** It is read fresh from `state.json` at emit time
  (~line 2190), after WORK (i), so the demotion surfaces in the emitted JSON for free.
- **The handoff must be amended, not just `state.json`.** `orchestrate-triage-classify.sh`
  checks continuation FIRST, then blockers; a bare demotion with neither reaches its
  "partial, neither -> implement" row and wastefully re-dispatches a finished task.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- A genuinely non-landing per-cycle commit (`git-commit-scoped.sh` exit 2, 3, 4, or 5) for an
  implement dispatch that WORK (f) just transitioned to `completed` leaves `state.json` at
  `partial`, not `completed`.
- The same event leaves `.orchestrator-handoff.json` carrying a named blocker and no
  continuation pointer, so the next `/orchestrate` cycle routes the task to `needs_human`
  rather than re-dispatching a redundant `implement` phase.
- The same event flips the emitted verdict from `ok` to `defer`, reusing that value's
  established "in-flight, retry the same phase next cycle" meaning.
- The demotion is loud: a named stderr line stating what was demoted, why, and the remedy.
- Every existing WORK (i) behavior for exit 1 and exit 6 is preserved byte-for-byte.

**Non-Goals**:

- Reordering WORK (f) and WORK (i), or splitting the per-cycle commit into two commits
  (option (a) — rejected, see Overview).
- Undoing `skill_orchestrate_propagate_completion`'s already-fired side effects (roadmap item
  propagation, `completion_summary`). The underlying work genuinely happened; only the
  commit/status bookkeeping is corrected. A demoted task legitimately still carries a completion
  summary.
- Demoting on a `researched` or `planned` dispatch outcome. Those resting states are
  non-terminal under the permissive transition model, so a later cycle recovers them without a
  demotion; only `completed` is the terminal state this task's hard constraint is about.
- Demoting on exit `6` (V9), exit `7` (V10 containment drop), or an unrecognized future code —
  all three mean a commit landed or may have landed, and the `*)` catch-all stays deliberately
  non-demoting as the fail-open direction.
- Retrying the failed commit, or committing the demotion write itself. The demotion lands on
  disk uncommitted and is picked up by whichever later cycle's commit succeeds; `state.json` is
  machine truth read directly by the next cycle's triage, so routing is correct regardless.
- Adopting exit `7` into the explicit exit-code list (a separately-named future pass in
  `git-staging-scope.md`'s residual paragraph).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Demotion fires for a commit that actually landed (exit 6 or 7), punishing a healthy task | H | L | Trigger set is the closed literal `2\|3\|4\|5`; `6` keeps today's non-demoting arm and `7` stays in the `*)` catch-all. Phase 2 asserts both negatives directly. |
| Bare demotion routes the next cycle back into a redundant `implement` dispatch | M | H if unmitigated | Phase 1 amends the handoff (`blockers[]` appended, `continuation_path` nulled, `continuation_context.handoff_path` nulled) in the same block, hitting the classifier's `needs_human` row. Verified against `orchestrate-triage-classify.sh`'s precedence order (continuation checked before blockers). |
| Handoff amendment corrupts or truncates the file under a jq failure | H | L | Write to a temp file and `mv` only on jq success; on failure emit a named WARNING and leave the original untouched. The `state.json` demotion still stands on its own (worst case: the next cycle re-dispatches rather than escalating — degraded, not wrong). |
| Six-plus sibling tasks contend on this exact file; a rebase or a sibling edit moves the insertion point | M | H | Re-read WORK (i) immediately before editing (Phase 1 task 1); stage only this task's own hunks, never a directory add. Line numbers in this plan are stated as hypotheses, not facts (see each phase's Scope Hypothesis). |
| The in-place handoff amendment makes the file look stale to a freshness-checking reader | M | L | `orchestrate-triage-classify.sh` applies no freshness gate to its handoff read (verified: it reads `blockers`, the continuation pointer, and an advisory `age_min` only). Phase 1 preserves `dispatch_seq`/`dispatch_start_ts` untouched so WORK (a)'s own gates behave exactly as they would have. |
| The new `verdict="defer"` collides with loop-control expectations | M | L | `defer` with `infra_exempt_cycle=false` is already a live, handled combination (`skill-orchestrate/SKILL.md` Move 3 acts only on `defer` + `infra_exempt_cycle=true`, and on `failed`); an ordinary `defer` simply leaves the task in-flight for the next cycle's triage. Phase 2 asserts `infra_exempt_cycle` stays `false`. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Commit-landing status correction in WORK (i) [COMPLETED]

**Goal**: A genuine non-landing commit for a just-completed implement dispatch demotes the task
to `partial`, amends its handoff, flips the verdict to `defer`, and says so loudly — as one
atomic change, so no intermediate deployed state can demote without also escalating.

**Tasks**:

- [x] Re-read WORK (i) (`grep -n "WORK (i)"`) in
      `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` immediately before
      editing; six-plus sibling tasks contend on this file and the line numbers below will have
      moved. Confirm the `case "$commit_rc" in` arms and the trailing `HARD CONSTRAINT` comment
      block are still shaped as this plan describes before touching anything. *(completed)*
- [x] Leave the existing `2|3|4|5|6)` arm **byte-for-byte unchanged** (ERROR line,
      `commit_attribution_note`, `issue-record.sh` call). The new logic is a *separate,
      subsequent* block, not a split of that arm — this avoids duplicating the arm's body and
      keeps every existing exit-6 assertion valid by construction. *(completed)*
- [x] Immediately after that `case` statement (and before the `HARD CONSTRAINT` comment block),
      add a second, narrowly-gated block:
      `case "$commit_rc" in 2|3|4|5)` AND `[ "$dispatch_status" = "implemented" ]` AND
      `[ "$implemented_gate_passed" = "true" ]` AND `[ "$deploy_pending_refusal" != "true" ]`
      AND `[ "$derived_staleness_refusal" != "true" ]` — exactly the conjunction under which
      WORK (f) wrote `completed` and the verdict resolver chose `ok`. All four variables are
      initialized unconditionally at top level (lines 1146, 1161, 1162) and `dispatch_status` is
      in scope, so the block is safe under this script's `set -u`. *(completed)*
- [x] Inside the gate, call
      `skill_postflight_update "$task_number" "implement" "$session_id" "partial" "" "$TASK_DIR" ""`
      — the exact call shape WORK (f)'s own `partial)` arm already uses, resolving through
      `skill-base.sh`'s `partial)` case to `update-task-status.sh postflight <N> partial <sess>`.
      Pass an empty phase-check argument and an empty clamp mode (a clamp is a forced-dispatch
      concept and is a provable no-op for an unranked target; passing it would mislead). *(completed)*
- [x] Amend `$handoff_file` (set unconditionally at line 526) in place when it exists and parses:
      append one `blockers[]` entry (`phase`, `target`, `what_was_tried`, `why_it_failed` — the
      schema's own shape, `phase`/`target` required), set `.status = "partial"`, set
      `.continuation_path = null`, and null `.continuation_context.handoff_path` if present
      (both accepted continuation forms must be cleared — the classifier checks continuation
      before blockers). Build the blocker text from the already-populated
      `$commit_attribution_note`. Write via temp file + `mv`, only on jq success; on jq failure
      emit a named WARNING and leave the original file untouched. *(completed)*
- [x] Leave `dispatch_seq`, `dispatch_start_ts`, `phases_completed`, `phases_total`, and
      `artifacts[]` on the handoff untouched — this is a targeted amendment, never a rewrite. *(completed)*
- [x] Set `verdict="defer"` inside the same gate. The verdict resolver runs at ~line 1625-1671,
      before WORK (i), and the emit block reads `$verdict` at ~line 2240, after it — so a
      reassignment here is read by both `jq -n` branches with no other wiring. *(completed)*
- [x] Emit one loud, named stderr line (`STATUS DEMOTED:` prefix, via `$notice_prefix`) naming
      the task, the exit code, the `completed -> partial` transition, the handoff blocker, and
      the remedy (commit by hand, then reconcile; the task now routes to `needs_human`). *(completed)*
- [x] Do NOT fire a second `issue-record.sh` call — the existing arm's entry already records
      this event; a duplicate would double-count in `orchestrate-conclusion-aggregate.sh`. *(completed)*
- [x] Rewrite the trailing `HARD CONSTRAINT: do NOT change verdict, halt, infra_exempt_cycle, or
      any status write here.` comment block so it documents the new, narrowly-scoped carve-out
      (what demotes, what deliberately does not: exit 1, exit 6, exit 7/`*)`, non-implement
      outcomes, and the untouched `halt`/`infra_exempt_cycle`) instead of standing stale and
      contradicted by the code beneath it. *(completed)*

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly one file is edited in this phase
(`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`), with the insertion
confined to the WORK (i) block currently spanning ~1832-1968 and the gate variables resolved at
lines 1146/1161/1162/526. Confirm at implementation time by re-running
`grep -n "WORK (i)\|implemented_gate_passed=\|deploy_pending_refusal=\|derived_staleness_refusal=\|^handoff_file="`
against the live file before editing; if any of those anchors has moved or changed shape, re-read
the surrounding region rather than applying the edit at a remembered offset.

**Tier Justification**: the edit is confined to one script with no change to any externally
visible signature, and is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-skill-base-lifecycle.sh,test-handoff-reader-parity.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add the gated
  demotion block (status write, handoff amendment, verdict flip, loud stderr line) after the
  existing exit-code `case`; rewrite the stale HARD CONSTRAINT comment.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` parses clean.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-skill-base-lifecycle.sh,test-handoff-reader-parity.sh`
  exits 0 — in particular the pre-existing case 980 assertion (`.verdict` unchanged between the
  exit-6 probe and the exit-0 baseline) must still pass untouched.
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` exits 0 (no
  hand-rolled bare `git commit` introduced).
- Reading the diff confirms the `2|3|4|5|6)` arm's body is unchanged.

---

### Phase 2: Test coverage for the demotion and its negatives [COMPLETED]

**Goal**: Both polarities are pinned by the suite — a genuine failure demotes and escalates; a
landed-commit code and a non-implement outcome provably do not.

**Tasks**:

- [x] Extend `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      using the existing case 980/981 machinery verbatim (`write_case98x_fixture`,
      `stub_git_commit_scoped`, `run_sut`, `jqf`) rather than inventing new helpers. Keep the
      surrounding `task-ref-ok` fixture-number comment block's reasoning intact for any new
      synthetic candidate numbers. *(completed)*
- [x] Positive case (stub exit 3): assert `.persisted_status == "partial"`, `.verdict == "defer"`,
      `.halt == false`, `.infra_exempt_cycle == false`, a `STATUS DEMOTED` line naming the task
      on stderr, and that the fixture's `state.json` row reads `partial` after the run. *(completed)*
- [x] Positive case, handoff half: assert the fixture's `.orchestrator-handoff.json` has
      `(.blockers | length) > 0`, `.continuation_path == null`, and
      `(.continuation_context.handoff_path // null) == null` after the run — i.e. the exact
      shape `orchestrate-triage-classify.sh`'s `needs_human` row requires. *(completed)*
- [x] Negative case (stub exit 6): assert `.persisted_status == "completed"` and the handoff's
      `blockers` stays empty — the landed-commit code must not demote. This complements, and
      must not replace, the existing case 980 verdict-unchanged assertion. *(completed)*
- [x] Negative case (stub exit 3 on a `planned` dispatch): assert no demotion and no
      `STATUS DEMOTED` line — the gate is implement-only. *(completed)*
- [x] Negative case (stub exit 1): assert the existing non-blocking WARNING path is entirely
      unchanged (no demotion, empty `.note`), re-using case 981's assertions as the model. *(completed)*
- [x] Add a clean-baseline (stub exit 0) companion run for the positive case, mirroring case
      980's baseline/probe pairing, so each new assertion discriminates the stubbed failure from
      the fixture itself. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly one file is edited
(`scripts/tests/test-orchestrate-cycle-postflight.sh`), and the existing
`write_case98x_fixture`/`stub_git_commit_scoped` helpers (currently ~lines 3336-3370) suffice
without modification for the `implemented` cases. Confirm at implementation time by re-reading
those helpers; a `planned`-dispatch negative case may need a small fixture variant, and if so
add it as a sibling helper rather than mutating the existing one (which other cases depend on).

**Tier Justification**: the edit is confined to one test file with no externally visible
signature change, and the suite selects itself under
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - new
  demotion cases (positive, handoff shape, and the exit-6 / `planned` / exit-1 negatives).

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  exits 0 with every new case reported PASS and no pre-existing case regressed.
- Each new positive assertion is confirmed to discriminate: temporarily reverting Phase 1's gate
  makes it FAIL (checked by inspection or a scratch run, not left in the tree).

---

### Phase 3: Document the sanctioned terminal-state exception [COMPLETED]

**Goal**: The one sanctioned write out of `[COMPLETED]` is written down where a future reader
looks for it, and the now-false "unimplemented follow-up" text in `git-staging-scope.md` is
corrected.

**Tasks**:

- [x] In `agent-system/extensions/core/context/standards/status-markers.md`, amend the
      `#### [COMPLETED]` section's `**Valid Transitions**: Terminal state (no further
      transitions)` line to name the single sanctioned exception: a postflight-synthesized
      demotion to `partial` when that same dispatch window's per-cycle scoped commit
      demonstrably did not land (`git-commit-scoped.sh` exit 2/3/4/5 at
      `orchestrate-cycle-postflight.sh`'s WORK (i)). Cross-reference `git-staging-scope.md`'s
      exit-code table. *(completed)*
- [x] Amend the same file's `### Status Transition Validation` -> `**Terminal States** (block
      all transitions)` list entry for `[COMPLETED]` so the two statements in one file do not
      contradict each other — the exception must be visible from both places or a reader
      consulting only the second will conclude the code is a bug. *(completed)*
- [x] In `agent-system/extensions/core/context/standards/git-staging-scope.md`, rewrite the
      "Recorded caller-escalation residual" paragraph's closing sentences: the demotion is no
      longer an unimplemented follow-up. State what now happens (exits 2-5 demote a just-
      completed implement task to `partial` with a handoff blocker and flip the verdict to
      `defer`; exit 6 and exit 7 deliberately do not, because both mean a commit landed), and
      keep the still-true note that exit `7` has not yet been adopted into the explicit list. *(completed)*
- [x] Describe behavior in the present tense throughout, with no "previously"/"no longer"/
      version-lineage framing (`.claude/rules/no-record-versioning-in-deliverables.md`), and no
      task-number citations outside `specs/**`
      (`.claude/rules/no-task-references-in-deliverables.md`). *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two markdown files are edited, at four edit sites (two in
`status-markers.md`, one paragraph in `git-staging-scope.md`, plus the exit-7 sentence inside
it). Confirm at implementation time with
`grep -n "Terminal state (no further transitions)\|No further transitions" context/standards/status-markers.md`
and `grep -n "Recorded caller-escalation residual" context/standards/git-staging-scope.md`; if
either anchor has moved or been reworded by a sibling task, re-read the section before editing.

**Tier Justification**: both edits are confined to prose with no compile or elaboration surface,
covered by the diff read-through the `prose` row prescribes plus
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-lifecycle-status-var.sh,test-todo-move-pair-staging.sh`
(the suites `suite_selection_select` resolves for these two paths — this is a mapped pair, not a
`__FULL_SWEEP__` case).

**Files to modify**:

- `agent-system/extensions/core/context/standards/status-markers.md` - `[COMPLETED]` valid-
  transitions line and the terminal-states list entry gain the named exception.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - the caller-escalation
  residual paragraph describes the implemented demotion instead of an open follow-up.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-lifecycle-status-var.sh,test-todo-move-pair-staging.sh`
  exits 0.
- Diff read-through confirms every changed hunk is prose, states current behavior in the present
  tense, and carries no task-number citation.
- `grep -n "unimplemented follow-up" agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns nothing for this residual.

---

### Phase 4: Deploy and full gate [COMPLETED WITH EXCLUSIONS]

**Goal**: The source-store change reaches the deployed tree and the complete gate set is green.

**Tasks**:

- [x] Confirm every edit from Phases 1-3 landed under
      `agent-system/extensions/core/`, never hand-authored under `.claude/**`
      (`.claude/rules/source-store-deploy-boundary.md`). *(completed: all four task files diffed
      byte-identical between source store and deployed tree, both before and after the deploy run
      below)*
- [x] Run `timeout 540 bash .claude/scripts/deploy-headless.sh` and confirm it completes.
      *(completed: exit 0, `RESULT=landed_verify_clean`, 36 checks / 0 failures in the deploy's
      own fast-gate verify pass)*
- [x] Diff the deployed `.claude/scripts/orchestrate-cycle-postflight.sh` against the source-
      store copy to confirm the deploy is current (the research pass established these are
      byte-identical when the deploy is fresh). *(completed: `diff` empty, confirmed both pre-
      and post-deploy)*
- [ ] Run the complete gate set and triage any failure attributable to this task's file scope;
      treat a failure in a file outside that scope as possibly a sibling's in-flight edit, per
      the dispatch's Territory block, and report it rather than silently fixing it.
      *(deviation: narrowed per the dispatch file's Batch Gate Deferral directive — this
      dispatch is one of several `implement`-phase dispatches in one multi-task `/orchestrate`
      batch invocation. Ran the scoped narrowing instead:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
      test-orchestrate-cycle-postflight.sh,test-skill-base-lifecycle.sh,test-handoff-reader-parity.sh,test-lint-lifecycle-status-var.sh,test-todo-move-pair-staging.sh`
      — 5 passed, 0 failed, 0 skipped. `deploy-headless.sh`'s own fast-gate `verify-deploy.sh`
      pass (36 checks, 0 failures, including doc-lint/gate 3, task-reference lint/gate 4, and
      agent-contracts lint/gate 6) ran as part of the deploy step above; it logged "shell test
      suite deferred" for gate 8's full battery, deferred to the once-per-invocation batch-level
      stage per the dispatch's Batch Gate Deferral section rather than independently run here.)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Full gate set (incl. gate 8, the complete shell-suite battery) run independently in this dispatch | Dispatch file (`.dispatch/11.md`) carries a `## Batch Gate Deferral` section: this task is one of several `implement`-phase dispatches in one multi-task `/orchestrate` batch invocation, and the directive requires discharging this phase against a scoped narrowing instead, with the full set deferred to a once-per-invocation batch-level stage attributed back via `modified_files`. | `deploy-headless.sh` ran the fast-gate `verify-deploy.sh` pass (36 checks, 0 failures) and explicitly logged "shell test suite deferred"; the scoped narrowing `run-all.sh --only test-orchestrate-cycle-postflight.sh,test-skill-base-lifecycle.sh,test-handoff-reader-parity.sh,test-lint-lifecycle-status-var.sh,test-todo-move-pair-staging.sh` (covering every suite named in Phases 1-3's own Tier Justification fields) reported 5 passed, 0 failed, 0 skipped. |

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase modifies no source files of its own; it regenerates the
deployed `.claude/` tree. Confirm by checking `git status --short` shows only `.claude/**`
regeneration (which is gitignored in a deployed tree) and no unexpected source-store
modification attributable to this phase.

**Files to modify**:

- none planned (deploy regenerates `.claude/**`; no hand-authored file is edited in this phase)

**Verification**:

- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully.
- The complete gate set —
  `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`,
  all gates including gate 3 (doc-lint), gate 4 (task-reference lint), gate 6 (agent contracts
  lint) and gate 8 (the full shell-suite battery) — reports no failures attributable to this
  task's file scope.
- `diff agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh .claude/scripts/orchestrate-cycle-postflight.sh`
  is empty.

---

## Testing & Validation

- [x] `bash -n` clean on the edited script (Phase 1). *(completed)*
- [x] New positive case: exit 3 on a just-completed implement dispatch yields
      `persisted_status == "partial"`, `verdict == "defer"`, a `STATUS DEMOTED` stderr line, and
      a handoff carrying a blocker with no continuation pointer in either accepted form
      (Phase 2). *(completed)*
- [x] New negative cases: exit 6 does not demote; exit 3 on a `planned` dispatch does not
      demote; exit 1 keeps its existing non-blocking WARNING path verbatim (Phase 2). *(completed)*
- [x] The pre-existing case 980 assertion (`.verdict` unchanged between the exit-6 probe and the
      exit-0 baseline) still passes unmodified (Phases 1-2). *(completed)*
- [x] `lint-scoped-commit-boundary.sh` exits 0 (Phase 1). *(completed)*
- [x] Doc-lint and the two doc-mapped suites green after the prose edits (Phase 3). *(completed)*
- [x] Full `verify-deploy.sh` green after `deploy-headless.sh` (Phase 4). *(completed: fast-gate
      pass, 36/0; full gate 8 battery deferred to batch stage per Batch Gate Deferral directive
      — see Phase 4's Reasoned Exclusions)*

**On end-to-end verification**: there is no harness that forces a real `git-commit-scoped.sh`
failure inside a live `/orchestrate` cycle, and manufacturing one on the shared working tree
would be actively hazardous with six-plus sibling tasks in flight. The stubbed-exit-code fixture
pattern the suite already uses (cases 980/981) is the sanctioned and strictly more repeatable
verification surface, and Phase 2 extends it rather than inventing a live-failure rig.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — gated demotion block
  in WORK (i) plus the rewritten HARD CONSTRAINT comment.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new
  positive and negative demotion cases.
- `agent-system/extensions/core/context/standards/status-markers.md` — the sanctioned terminal-
  state exception, recorded in both places that assert terminality.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — corrected caller-
  escalation residual paragraph.
- `specs/395_surface_failed_per_cycle_commit_into_task_status/summaries/01_commit-failure-status-demotion-summary.md`
  (written at implementation close).

## Rollback/Contingency

Every change is additive: one gated block in one bash script, new test cases, and prose. There
is no migration, no schema change, and no persisted artifact whose format changes — a revert
restores exactly today's observability-only behavior. Phases 1, 2, and 3 are independently
revertible by file.

If a later gate run proves the change must come out, revert the specific commits rather than
discarding the working tree. If a rollback genuinely requires discarding uncommitted work first,
take the snapshot per `context/contracts/recovery.md`'s rollback rung — including its
out-of-scope override flag for the deliberate whole-tree case — and never reach for a bare
reverting `git-snapshot.sh` as a routine precaution. For an ordinary defensive checkpoint before
Phase 1's edit, use the durable non-reverting form (`git-snapshot.sh --no-revert`).

A reverted deployed tree is recovered by re-running `deploy-headless.sh`, never by hand-patching
under `.claude/**`.

If the demotion is found to fire in a case it should not, the narrowest safe mitigation is to
tighten the gate conjunction (never to widen the exit-code set), since every variable in that
conjunction is already independently observable in the emitted JSON.
