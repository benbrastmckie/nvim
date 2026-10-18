# Implementation Plan: Task #442

- **Task**: 442 - Evaluate deploying before implement-phase postflight so a stale deploy tree does not cost a full orchestration cycle per task
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: 426
- **Research Inputs**: specs/442_deploy_before_implement_postflight_to_avoid_cycle_cost/reports/01_pre-postflight-deploy-timing.md
- **Artifacts**: plans/01_pre-postflight-deploy-evaluation-record.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research reached a negative-but-documented verdict: a once-per-batch, pre-postflight-sweep
deploy trigger is theoretically safe at the Move 2/Move 3 boundary, but is not worth building,
because it would make a third mechanically-audited genuine caller of the deploy/regeneration
script and would remove a cost that is already bounded and already fully self-resolving. This
plan therefore implements **no behavioral change to any gate or trigger** and instead lands the
evaluation record the dispatch explicitly asks for when no behavioral change is made: a new
subsection in `batch-orchestration-guardrails.md` immediately after "The Postflight
Completion-Deploy Gate", plus two short pointer comments at the exact script sites where a
future reader would naturally re-ask the question. The final phase redeploys the source store
and runs the full gate set.

### Research Integration

Four findings from the report drive the plan's content and shape:

1. The stated concurrency objection in the guardrails document ("a sibling task's own
   still-in-flight dispatch") does not describe a same-cycle hazard at the Move 2/Move 3
   boundary — Move 3 runs strictly after every Move 2 Agent call has returned. The surviving
   hazard is cross-session deploy-lock contention, already accepted at both existing trigger
   sites. The record must narrow the objection honestly rather than restate it.
2. `scripts/tests/test-lint-deploy-caller-wrap.sh` asserts exactly two genuine
   `deploy-headless.sh` callers and would need deliberate widening — the concrete structural
   cost of a third trigger site. That same lint classifies a comment line as a MENTION, never a
   GENUINE caller, which is why Phase 2's pointer comments are safe to add.
3. The deferred cost is one additional, largely empty cycle round trip — not a repeated deploy,
   verify, or implementation pass — because the post-deploy reconcile pass promotes a
   deploy-pending task to completed before the following cycle's dispatch derivation runs.
4. The report states the cost claim qualitatively on purpose (no wall-clock number was measured);
   the record must preserve that qualitative framing so it does not go stale.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; roadmap consultation skipped.

## Goals & Non-Goals

**Goals**:
- Record, at the subsection a future reader checks first, that a pre-postflight-sweep deploy
  trigger was evaluated and intentionally left unimplemented, with the reasoning that produced
  that verdict (the same-cycle narrowing, the structural third-caller cost, the bounded nature
  of the deferred cost).
- Make the record reachable from the two script sites where the question naturally arises: the
  exit-6 DEPLOY-PENDING branch and the Inter-Cycle Redeploy Checkpoint.
- Leave the completion-deploy gate's fail-closed posture provably untouched — by changing no
  gate logic at all.
- Redeploy the source store so the running tree carries the new guidance.

**Non-Goals**:
- Any new `deploy-headless.sh` trigger site, per task or per batch.
- Any change to the completion-deploy gate's refusal logic, exit code, trigger predicate, or
  message text.
- Any change to the Inter-Cycle Redeploy Checkpoint's branches, ledger, or reconcile pass.
- Widening `test-lint-deploy-caller-wrap.sh`'s two-caller assertion (no third caller is added,
  so nothing to widen).
- Fixing the stale "not-yet-built postflight composer" phrasing in `orchestrate-cycle-plan.sh`'s
  header — the report flagged it as incidental and explicitly out of this task's scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A pointer comment naming `deploy-headless.sh` is misread by `test-lint-deploy-caller-wrap.sh` as a new genuine caller | H | L | The lint classifies any line whose first non-whitespace character is `#` as a MENTION before any other test; keep both comments as plain `#` lines and never in command position. Phase 2 runs that lint explicitly. |
| The record is written as a safety verdict ("the deferral is structurally necessary") when research concluded a cost/benefit verdict | M | M | Phase 1 acceptance requires the text to state the pre-sweep deploy is judged *safe* and left unbuilt on cost/benefit grounds — the two must not be conflated. |
| Task-number references or record-versioning language leak into `agent-system/**` | M | L | Both are mechanically caught: gate 4 (task-reference lint) in Phase 1's check, and the full gate set in Phase 3. Draft from the research appendix, which was already written task-number-free. |
| The subsection quotes a wall-clock cost figure research did not measure | M | L | Phase 1 acceptance forbids a numeric cost claim; the record states "one additional, largely empty cycle round trip". |
| Deploy in Phase 3 overwrites the running copy of a script it is itself executing | H | L | Phase 3 invokes `deploy-headless.sh` from the shell, not from inside a deployed script that continues afterward, so the self-overwrite wrap discipline is not implicated; no new caller site is created. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Land the evaluation record in the guardrails document [COMPLETED]

**Goal**: `batch-orchestration-guardrails.md` carries a new subsection, immediately after "The
Postflight Completion-Deploy Gate" and before "## Absent file_scope Hazard: The Split Admission
Posture", that records the evaluation and its verdict.

**Tasks**:
- [x] Resolve the source store via `.claude-extensions.json`'s `extensions.core.source_dir`;
      confirm it resolves to `agent-system/extensions/core` and edit only there. *(completed)*
- [x] Read the tail of the "### The Postflight Completion-Deploy Gate" subsection to match its
      voice, heading depth (`###`), and emphasis conventions. *(completed)*
- [x] Insert a new `###`-level subsection, titled so it reads as a closed evaluation (e.g.
      "A Pre-Postflight-Sweep Deploy Trigger: Evaluated, Intentionally Not Built"), adapting the
      draft in the research report's Appendix. It MUST cover all four points below. *(completed)*
- [x] (a) The same-cycle narrowing: Move 3 runs only after every Move 2 Agent call has returned,
      so the "sibling task's own still-in-flight dispatch" objection does not describe a hazard at
      that boundary; the surviving hazard is a *different*, concurrently-running session racing
      the fail-open deploy-lock mutex, which both existing trigger sites already accept at the
      same degree. Cross-reference the Direction-3 discussion that already makes this argument.
      *(completed)*
- [x] (b) The structural cost: a third genuine caller of the deploy/regeneration script, which
      `scripts/tests/test-lint-deploy-caller-wrap.sh` mechanically asserts does not exist and
      would have to be deliberately widened; plus re-threading (not duplicating) the existing
      baseline-relative branches, confirmation/attribution filters, idempotence guard, and
      durable ledger, and the same self-overwrite-hazard wrap discipline. *(completed)*
- [x] (c) The bounded cost: the deploy/verify pass is paid once regardless of which boundary
      triggers it, and the post-deploy reconcile pass promotes a deploy-pending task to completed
      before the following cycle's own dispatch derivation runs, so nothing is re-implemented or
      re-dispatched; what remains is one additional, largely empty cycle round trip. State this
      qualitatively — no wall-clock number. *(completed)*
- [x] (d) The explicit verdict and its kind: judged *safe* at that boundary, left unimplemented
      on **cost/benefit** grounds, so a later pass does not re-propose it without re-deriving
      this reasoning. *(completed)*
- [x] Add the new subsection to any in-document navigation or "Related Documents" listing only
      if the file already indexes its `###` subsections there; do not invent a new index.
      *(completed: Related Documents indexes other files thematically, not this document's own
      `###` subsections — no new index added)*
- [x] Self-check the inserted text for task-number references and for record-versioning language
      ("previously", "no longer", "v1", "supersedes") before running the gate subset. *(completed:
      grep of the inserted span found zero matches)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core` covers this single markdown file's only executable surface (doc-lint and the task-reference lint), with the explicit source-store TARGET the no-argument form would silently SKIP.

**Scope Hypothesis**: exactly one file changes in this phase, with no change to any surrounding subsection's text. Confirm with `git diff --stat` showing a single path and an insertion-only hunk before closing the phase.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - new `###` subsection after "The Postflight Completion-Deploy Gate"

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core` is green (neither selected gate reaches a zero-check SKIP).
- `git diff --stat` shows exactly one changed path, insertions only.
- Read-through confirms the four required content points (a)-(d) are present, that the verdict
  is stated as cost/benefit rather than as a safety necessity, and that no wall-clock figure is
  asserted.

---

### Phase 2: Add pointer comments at the two script sites [COMPLETED]

**Goal**: A reader standing at the exit-6 DEPLOY-PENDING branch, or at the Inter-Cycle Redeploy
Checkpoint, can reach the evaluation record without already knowing it exists.

**Tasks**:
- [x] In `orchestrate-cycle-postflight.sh`, immediately above the DEPLOY-PENDING notice branch
      (currently near the `postflight_rc -eq 6` arm), add a one-or-two-line `#` comment naming
      `context/patterns/batch-orchestration-guardrails.md` and the new subsection heading, stating
      in one clause that deploying earlier in the cycle was evaluated and intentionally not built.
      *(completed)*
- [x] In `orchestrate-cycle-plan.sh`, add the equivalent `#` comment adjacent to the existing
      Inter-Cycle Redeploy Checkpoint header comment that already cross-references the same
      document. *(completed)*
- [x] Verify both additions are plain comment lines (first non-whitespace character `#`) and that
      neither places a deploy invocation token in command position. *(completed: git diff -U0
      confirms every added line begins with `#`)*
- [x] Do not alter the DEPLOY-PENDING message string, any branch condition, or any executable
      line in either script. *(completed: diff shows comment-only additions)*

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-deploy-caller-wrap.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-cycle-plan.sh` is the covering subset for these two paths' comment-only edit, and the first of those three is precisely the lint that would flag a mis-classified new caller.

**Scope Hypothesis**: this phase adds only comment lines — zero executable lines change in either script. Confirm with `git diff -U0` on both paths showing every added line beginning with `#` and no removed non-comment line.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - pointer comment above the exit-6 DEPLOY-PENDING branch
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - pointer comment at the Inter-Cycle Redeploy Checkpoint header

**Verification**:
- `bash -n` is clean on both scripts.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-deploy-caller-wrap.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-cycle-plan.sh` is green; the caller-wrap lint still classifies exactly two genuine callers.
- `git diff -U0` on both paths shows comment-only additions.

---

### Phase 3: Redeploy and run the full gate set [COMPLETED]

**Goal**: The running `.claude/` tree carries the new guidance, and the whole change set passes
the repository's complete gate set.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (invoked from the shell,
      not from inside a continuing deployed script) to regenerate the deployed tree. *(completed)*
- [x] Confirm the deployed copy of `batch-orchestration-guardrails.md` contains the new
      subsection and that the two deployed scripts carry the pointer comments. *(completed: grep
      confirms the new subsection heading and both pointer comments in the deployed tree)*
- [x] Run the complete gate set and resolve any finding attributable to this change set.
      *(deviation: per this dispatch's Batch Gate Deferral directive, discharged against the
      scoped fast-gate tier that `deploy-headless.sh`'s own inline verification already runs
      (gates 1-24 minus gate 8, deferred to the once-per-batch full sweep) rather than
      independently invoking the complete gate set again; see Verification notes below)*
- [x] Confirm no third genuine `deploy-headless.sh` caller was introduced anywhere. *(completed:
      `test-lint-deploy-caller-wrap.sh` passed in Phase 2 and still finds exactly two genuine
      callers)*

**Timing**: 0.6 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: the deploy touches the generated `.claude/` tree only as a regeneration product; no additional source-store file changes in this phase. Confirm by re-running `git status --short` and checking that every non-`.claude/` modified path is one of the three already changed in Phases 1-2.

**Files to modify**:
- none (regeneration only; the deploy rewrites `.claude/**`, a disposable deploy artifact)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) is green.
- `grep` of the deployed `.claude/context/patterns/batch-orchestration-guardrails.md` finds the
  new subsection heading.
- `bash .claude/scripts/check-deploy-freshness.sh` reports the deployed tree fresh relative to
  the source store.

**Batch Gate Deferral note**: this dispatch carried a `## Batch Gate Deferral` section naming
this phase's `full` tier. `deploy-headless.sh`'s own non-optional inline verification already
ran the complete fast-gate battery (gates 1-24, `--skip-slow`) as part of landing the deploy, and
every gate passed except gate 10 (`specs/state.json` schema validation), which failed on a 30s
timeout under concurrent batch load; re-running gate 10 alone passed cleanly, confirming a
transient flake unrelated to this task's three-file change set (recorded in the issue log). Gate
8 (the slow shell-test battery, `tests/run-all.sh`) is the one deferred piece: this phase's own
targeted subset of it (`test-lint-deploy-caller-wrap.sh`, `test-orchestrate-cycle-postflight.sh`,
`test-orchestrate-cycle-plan.sh`) already ran green in Phase 2, and the complete gate 8 battery
is deferred to the once-per-batch full sweep at the end of this orchestrate invocation, per the
dispatch's own narrowing directive — not independently re-run here.

---

## Testing & Validation

- [ ] The new subsection exists in the source store, sits between "The Postflight
      Completion-Deploy Gate" and "Absent file_scope Hazard", and carries content points (a)-(d).
- [ ] No gate logic, exit code, trigger predicate, or message string changed anywhere — the
      fail-closed posture of the completion-deploy gate is byte-identical.
- [ ] `test-lint-deploy-caller-wrap.sh` still finds exactly the two known genuine caller sites.
- [ ] Doc-lint and task-reference lint are green against the source store with an explicit TARGET.
- [ ] The complete gate set (`verify-deploy.sh`) is green after redeploy.
- [ ] No task-number references and no record-versioning language in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- Updated `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  (new evaluation-record subsection).
- Pointer comments in `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` and
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`.
- Regenerated `.claude/` deploy tree.
- Implementation summary under
  `specs/442_deploy_before_implement_postflight_to_avoid_cycle_cost/summaries/`.

## Rollback/Contingency

Every change in this plan is additive and documentation-only. To revert, drop the three source-store
hunks (`git checkout` the three paths from HEAD, after a `git-snapshot.sh 442 --no-revert`
checkpoint if the tree is dirty) and redeploy. No gate, trigger, or state-machine behavior is
touched, so a revert cannot strand a task or change any admission or completion decision.

If the full gate set in Phase 3 surfaces a finding unrelated to these three paths, treat it as
pre-existing: record it in the issue log and do not expand this task's scope to fix it.
