# Implementation Plan: Task #403

- **Task**: 403 - Share one verify-deploy gate run across an /orchestrate batch instead of one full run per task
- **Status**: [COMPLETED]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/403_share_one_verify_deploy_gate_run_per_batch/reports/01_batch-level-verify-deploy-gate.md
- **Artifacts**: plans/01_batch-shared-verify-deploy-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Split the per-task full-gate obligation into two mechanisms that already have precedent in this
codebase. **Mechanism A** (dispatch-time deferral) narrows what a *single* final-implement-phase
dispatch must independently discharge when that task is one of several in an `/orchestrate`
batch, carried on the `.dispatch/{seq}.md` file the way `concurrent_siblings` territory already
is — the plan file's own `**Verification Tier**: full` field is never edited. **Mechanism B**
(shared run) adds one new once-per-invocation engine stage at the Move 4/5 seam that runs
`verify-deploy.sh` exactly once after the loop's last cycle and attributes each confirmed finding
back to the task whose own `modified_files` plausibly caused it, reusing
`scripts/lib/deploy-baseline-lib.sh`'s existing per-task attribution function
(`deploy_baseline_self_attributable_findings`) rather than building a new library.

The split is what makes the design safe: a bare `/implement N` (never enters the four-move loop,
so no Move 4/5 seam exists to defer to) keeps running the full gate inline at its final phase,
byte-for-byte unchanged, because Mechanism A fires only from `orchestrate-cycle-plan.sh`'s
dispatch composition.

### Research Integration

Key findings carried into this plan:

- **The `full` final-phase mandate is a planning-time convention, not a mechanical gate today.**
  `validate-artifact.sh`'s tier enforcement is `--strict`-only/advisory, and the companion check
  for "did the final phase actually invoke the full gate" is explicitly an unbuilt future item.
  That is the leverage point Mechanism A uses — no mechanical enforcer has to be fought.
- **The attribution machinery already exists at the needed grain.**
  `deploy_baseline_self_attributable_findings` (mode=`attributable`) already takes ONE task's own
  `modified_files` JSON array and answers "is this finding plausibly mine", with a documented
  fail-safe asymmetry. `orchestrate-cycle-plan.sh`'s deploy-pending path already builds a
  per-task `modified_files` map (`deploy_pending_modified_files_json`) from each task's
  `.return-meta.json` — a directly reusable template.
- **The right seam exists with documented precedent.** `skills/skill-orchestrate/SKILL.md`'s Move
  5 (`context/contracts/conclusion-stage.md`) proves the engine already supports a
  once-per-invocation post-loop stage that aggregates evidence across every task an invocation
  touched. Mechanism B is sited as a *second, independent* stage at the same seam, never folded
  into Move 5's body.
- **The single-capture-sharing precedent does NOT transfer, and the plan states why.**
  `context/patterns/batch-orchestration-guardrails.md` records a REJECTED design that shared one
  Gate-8 capture across the Inter-Cycle Redeploy Checkpoint's own pre/post pair, because ~41 of
  ~73 Gate-8 suites resolve the DEPLOYED copy of their subject-under-test in preference to the
  source-store copy — so a pre-redeploy capture and a post-redeploy capture are provably not
  interchangeable. Mechanism B shares one capture across sibling *tasks* within one
  already-deployed tree, after each has committed its own work; it never straddles a deploy
  boundary. The rejection is cited as a landmine to avoid re-triggering, not a blocker.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch.

## Goals & Non-Goals

**Goals**:

- A multi-task `/orchestrate` invocation runs the complete `verify-deploy.sh` gate set ONCE, after
  the last implement phase closes, instead of once inside each task's own final phase.
- Each confirmed finding from that shared run is attributed to the task(s) whose own
  `modified_files` plausibly caused it; an unattributable finding is recorded at batch level and
  stays blocking rather than being pinned on one arbitrary task.
- A final-implement-phase dispatch inside a multi-task batch receives an explicit, auditable
  dispatch-time directive narrowing its own obligation to a scoped tier, with the full-set
  criterion deferred to the shared run.
- A bare `/implement N` and a single-task `/orchestrate N` keep today's observable behavior: one
  full gate run covering that task's work before the task is done.
- Plan files stay reusable across both invocation styles — no plan's `**Verification Tier**:
  full` field is rewritten by this task, and `plan-format.md`'s non-negotiable invariant ("the
  full gate set still runs ... unchanged" in aggregate) stays intact.

**Non-Goals**:

- Making the per-phase tier field mechanically enforced (the unbuilt `--strict` promotion and the
  "did it actually run the gate" companion check stay out of scope).
- Reducing the cost of one full gate run (parallelism, suite pruning, `--skip-slow` posture). The
  target is "once per batch", not "cheaper per run" and not "never".
- Changing the Inter-Cycle Redeploy Checkpoint's own pre/post capture behavior, or sharing a
  capture across a deploy boundary (the explicitly rejected design — see Research Integration).
- Folding the new stage into Move 5's Conclusion body, or gating it behind Move 5's approval
  channels.
- Preventing sibling-caused gate noise *during* a phase. Mechanism A removes the per-task full
  run that produced the noise; it does not make a narrowed in-phase check concurrency-immune.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new dispatch-file section silently inerts the IDENTICAL DISPATCH HALT (`cycle_plan_dispatch_hash()`'s strip pattern is a documented standing obligation, already broken once between 2026-10-03 and its repair) | H | M | Phase 3 explicitly decides and records that the deferral block is NOT stripped — its content varies only with real batch membership, exactly like the `## Territory` payload, which is deliberately unstripped because a changed payload IS a behavioral change. Phase 3 adds a `test-orchestrate-cycle-plan.sh` case pinning that two dispatches differing only in deferral state hash UNEQUAL |
| Implementing agents keep running the full gate anyway, because `phase-closure.md`'s no-promotion-without-evidence rule says a `full` declaration is discharged only by the complete gate set | H | H | Phase 1 carves the dispatch-time deferral into that exact rule, and Phase 1 also updates `agents/general-implementation-agent.md` so the consuming agent is told to honor the directive. Without both edits Mechanism A is inert prose |
| A task's `modified_files` from an EARLIER cycle is lost, so the shared run under-attributes | M | H | `.return-meta.json` is overwritten per dispatch and `cycle_modified_files` is reset at each cycle-plan run (`redeploy-checkpoint-lib.sh`). Phase 2 therefore adds a separate, invocation-scoped, per-task accumulator that is never reset, rather than reading `.return-meta.json` at the end |
| Attribution wrongly clears a finding the batch caused, masking a real regression | H | M | Reuse `deploy_baseline_self_attributable_findings` unchanged, including its identifier-free-line rule and the governed-globs second signal. A finding attributable to NO task is recorded as batch-level and stays blocking — never dropped, never assigned to one arbitrary task |
| Flaky-under-load findings are reported as real | M | M | Run `deploy_baseline_confirm_new_findings` against a fresh confirmation snapshot before attributing, exactly as the redeploy checkpoint already does |
| Re-triggering the rejected single-capture premise | H | L | Phase 4's script header states the distinguishing axis (no deploy boundary is straddled) explicitly, so a future reader does not have to re-derive it |
| The shared stage never fires (e.g. an invocation that ends via `stop_json` before Move 4's wiring point) | M | M | Phase 5 sites the call after Move 4's `exit_status` resolution and before consolidated-output emission, which every exit path reaches; Phase 6 verifies the no-implement-dispatch case is a clean no-op |
| A new context file is an unreachable orphan (`test-context-reachability.sh` exit non-zero) | M | M | Phase 5 registers it in `index-entries.json` with non-empty `load_when` AND references it by basename from `skills/skill-orchestrate/SKILL.md` — two of the three reachability styles |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 (for 3), 2 (for 4) |
| 3 | 5 | 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Tier vocabulary, contract carve-out, and agent-side honoring [COMPLETED]

**Goal**: Make the batch-aware deferral legible and permitted in the three prose contracts that
would otherwise forbid it, so Mechanism A is not inert once the engine starts emitting it.

**Tasks**:
- [x] In `context/formats/plan-format.md`'s `## Verification Tiers` section, add a subsection *(completed)*
      defining the batch-aware variant: the plan's declared tier is the CEILING the standalone
      path must meet; a dispatch-time batch override narrows what THIS dispatch must
      independently discharge, without editing the plan's own tier field. State the two
      obligations the override does and does not change.
- [x] In the same section, state explicitly that the non-negotiable invariant is preserved: the *(completed)*
      complete gate set still runs, once, before the batch concludes — a narrowed per-dispatch
      obligation is not a fifth tier and not a weakening, exactly parallel to the existing
      "`--skip-slow` is never a tier" ruling.
- [x] In `context/contracts/phase-closure.md`'s "No-promotion-without-evidence" bullet, carve out *(completed)*
      the one case where a `full` declaration is discharged by something other than a local
      complete-gate run: a dispatch carrying the batch-gate deferral directive. Name what the
      agent runs instead (the directive's scoped tier) and that the full set is owed by the
      batch-level stage, not forgiven.
- [x] In `agents/general-implementation-agent.md`, add the consuming instruction: when the *(completed)*
      dispatch file carries a `## Batch Gate Deferral` section, discharge the final phase against
      the scoped tier the directive names, record in the phase's own verification notes that the
      full set was deferred to the batch stage, and do NOT invoke `verify-deploy.sh` at full
      depth for this phase.
- [x] Add a MUST NOT to the same agent file: never treat the deferral directive as license to *(completed)*
      skip verification entirely, and never apply it to a phase whose dispatch file carries no
      such section.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: All four touched paths are source-store, non-`specs/**` markdown with no
mapped suite (`suite_selection_select` returns `__FULL_SWEEP__`), so plan-format.md's
`__FULL_SWEEP__` sub-case (b) applies: `bash <source_dir>/scripts/verify-deploy.sh --skip-slow
--only-gate 3,4 <source_dir>` (doc-lint and task-reference lint, explicit TARGET) is the honest
covering check, run alongside the `local` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - new batch-aware-variant subsection inside `## Verification Tiers`, plus the invariant-preserved statement
- `agent-system/extensions/core/context/contracts/phase-closure.md` - carve-out in the no-promotion-without-evidence bullet
- `agent-system/extensions/core/agents/general-implementation-agent.md` - consuming instruction plus the matching MUST NOT

**Verification**:
- `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` exits 0.
- `grep -n "Batch Gate Deferral" agent-system/extensions/core/agents/general-implementation-agent.md` matches.
- Diff read-through confirms no existing tier-table row, the `prose`/`local`/`interface`/`full`
  vocabulary, or the `--skip-slow`-is-never-a-tier ruling was altered — only additive text.

---

### Phase 2: Invocation-scoped per-task modified_files accumulator [COMPLETED]

**Goal**: Give the shared stage a per-task `modified_files` map that survives the whole
invocation, since the two existing carriers do not.

**Tasks**:
- [x] In `scripts/orchestrate-cycle-postflight.sh`, at the same site that already accumulates *(completed)*
      `cycle_modified_files` from `.return-meta.json`, additionally accumulate into a new
      `invocation_modified_files` object in `mt_state_file`, keyed by task number as a STRING key
      (jq object keys always are), union-ing with `unique` per task.
- [x] Confirm by reading `scripts/lib/redeploy-checkpoint-lib.sh`'s reset line that the new field *(completed)*
      is NOT reset there, and add a one-line comment at the new accumulation site stating the
      field is deliberately invocation-scoped (never per-cycle) and naming why
      `cycle_modified_files` could not be reused.
- [x] Ensure the field is initialized defensively (`//= {}`) wherever `mt_state_file` is seeded in *(completed)*
      `scripts/orchestrate-cycle-plan.sh`, alongside the existing `cycle_modified_files //= []`.
- [x] Add regression cases to `scripts/tests/test-orchestrate-cycle-postflight.sh`: two postflight *(completed)*
      calls for the same task across two cycles union into one task key; two different tasks
      produce two keys; a task reporting no `modified_files` adds no key; an absolute-path entry
      (the known counter-example the existing excursion logic already drops) does not corrupt the
      map.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes exactly one accumulation site for `cycle_modified_files`
in `orchestrate-cycle-postflight.sh` and exactly one reset site in `redeploy-checkpoint-lib.sh`.
Confirm at implementation time with `grep -rn "cycle_modified_files" agent-system/extensions/core/scripts/`
and widen the task list if a second site of either kind exists.

**Tier Justification**: The edit is confined to one accumulation block in one script plus a
defensive initializer, with no externally visible signature change; it is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-orchestrate-cycle-plan.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add `invocation_modified_files` accumulation beside the existing `cycle_modified_files` block
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add `.invocation_modified_files //= {}` to the mt_state seeding block
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - four new regression cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-orchestrate-cycle-plan.sh` exits 0.
- The four new cases are present and passing by name in that suite's output.
- `grep -n "invocation_modified_files" agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` returns nothing (not reset per cycle).

---

### Phase 3: Dispatch-time batch-gate deferral directive [COMPLETED]

**Goal**: Emit the deferral directive on exactly the dispatches that should receive it, and on no
others, without inerting the identical-dispatch halt.

**Tasks**:
- [x] In `scripts/orchestrate-build-dispatch.sh`, add a `--batch-gate-deferral` flag following the *(completed)*
      file's empty-value-skips-flag convention. When present AND `phase` is `implement`, emit a
      `## Batch Gate Deferral` section naming: that the plan's final phase declares `full`; that
      THIS dispatch discharges a scoped tier against the files this phase actually touched; the
      two sanctioned narrowing invocations (`run-all.sh --only ...`, `verify-deploy.sh --only-gate
      ...`); and that the complete set runs once for the batch at the end of this invocation with
      its result attributed back to this task.
- [x] Add the flag to the script's usage block and doc header, following the `--compare`/`--gate` *(completed)*
      precedent, and state the byte-identical-when-absent invariant explicitly.
- [x] In `scripts/orchestrate-cycle-plan.sh`'s `build_args` composition block, append *(completed)*
      `--batch-gate-deferral` when the dispatched phase is `implement` AND the invocation is a
      multi-task batch (`mt_state_file`'s `.task_numbers | length > 1`) — the invocation-level
      signal, NOT the per-cycle `probed_dispatch_post_h1` count, so a batch whose siblings are
      staggered across cycles still defers.
- [x] DECIDE AND RECORD, in a comment at `cycle_plan_dispatch_hash()`: the new section is NOT *(completed)*
      added to the strip pattern, because its presence tracks real batch membership exactly as
      the unstripped `## Territory` payload does — a change in it is a genuine behavioral change,
      not per-cycle-varying boilerplate. Reference the standing obligation that comment block
      already carries so a future reader sees the decision was made, not missed.
- [x] Add cases to `scripts/tests/test-orchestrate-build-dispatch.sh`: flag absent yields a *(completed)*
      dispatch file byte-identical to the pre-flag build; flag present on `implement` emits the
      section; flag present on `research`/`plan` emits nothing.
- [x] Add a case to `scripts/tests/test-orchestrate-cycle-plan.sh`: two dispatch files for the *(completed)*
      same task/phase differing only in deferral state hash UNEQUAL under
      `cycle_plan_dispatch_hash()`.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The dispatch-file body is a contract consumed by `orchestrate-cycle-plan.sh`'s
hash normalizer and by the dispatched agent, so the enumerated one-hop dependent set is the two
scripts and their suites: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - new `--batch-gate-deferral` flag, doc-header paragraph, usage line, and the `## Batch Gate Deferral` emission block
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - append the flag in `build_args`; strip-pattern decision comment at `cycle_plan_dispatch_hash()`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - three new cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - one new hash-inequality case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh` exits 0.
- A hand-run `orchestrate-build-dispatch.sh` with and without the flag produces identical output
  when absent (`diff` empty) and exactly one added section when present.
- The `## Batch Gate Deferral` section names a concrete narrowing invocation, not a description
  of one.

---

### Phase 4: The shared batch-gate stage script [COMPLETED]

**Goal**: One new script that runs the complete gate set once per invocation and produces a
per-task attributed, durable record — the whole of Mechanism B's logic, independently testable
before any engine wiring exists.

**Tasks**:
- [x] Create `scripts/orchestrate-batch-gate.sh` taking `--session SID --state-file PATH` *(completed)*
      (plus `--dry-run` for fixtures). Source `lib/deploy-baseline-lib.sh`; set no shell options a
      caller inherits, matching that library's own stated convention.
- [x] Trigger condition: no-op (exit 0, one explanatory line) unless at least one `implement`-phase *(completed)*
      dispatch occurred this invocation, read from `mt_state_file`. Mirrors the existing
      "don't fire on every invocation regardless of relevance" reasoning already recorded for the
      Inter-Cycle Redeploy Checkpoint.
- [x] Capture: `deploy_findings_snapshot` at full depth (NO `--skip-slow`), with the explicit *(completed)*
      source-store TARGET resolved from `.claude-extensions.json`, exactly once.
- [x] Confirm: take a second fresh snapshot and pass both through *(completed)*
      `deploy_baseline_confirm_new_findings`, dropping candidates that did not reproduce under
      ambient load.
- [x] Attribute: for each task in `.task_numbers`, call *(completed)*
      `deploy_baseline_self_attributable_findings` with that task's own entry from
      `invocation_modified_files`. A confirmed finding matching no task's files is recorded as a
      batch-level unattributed finding and stays blocking — never dropped and never assigned to
      one arbitrary task.
- [x] Record: write a `batch_gate` object into `mt_state_file` — the gate's exit code, the *(completed)*
      confirmed-finding set, a per-task attributed map, and the unattributed set — following the
      durable-record precedent of `verify_deploy_baseline_notices`.
- [x] Doc header: state the single-capture distinction explicitly (this stage shares one capture *(completed)*
      across sibling TASKS inside one already-deployed tree after each committed its own work; it
      never straddles a deploy boundary, which is the axis on which the rejected pre/post
      single-capture design was unsafe), citing `context/patterns/batch-orchestration-guardrails.md`.
- [x] Create `scripts/tests/test-orchestrate-batch-gate.sh` with fixture-driven cases: no-implement *(completed)*
      no-op; a finding attributed to exactly one of two tasks; a finding attributable to neither
      landing in the unattributed set; an identifier-free finding never cleared; a non-reproducing
      candidate dropped by confirmation; `batch_gate` record shape; and the usage-error/degenerate
      paths the sibling suites already pin.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `deploy_baseline_self_attributable_findings` needs no
extension to serve per-task attribution against one shared snapshot (research called the
extension "light", not certain). Confirm at implementation time by running the new suite's
two-task attribution case against the unmodified library; if it cannot express the case, add the
extension inside this phase and note it in the handoff rather than deferring it.

**Tier Justification**: The work is one new self-contained script plus its own new suite, with no
existing caller yet (wiring is Phase 5), so `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-batch-gate.sh,test-deploy-baseline-lib.sh` covers both the new logic and the library it reuses.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - NEW: the once-per-invocation shared gate stage
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` - NEW: fixture-driven suite for the above

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-batch-gate.sh,test-deploy-baseline-lib.sh` exits 0.
- `bash agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` with no arguments exits
  non-zero with a usage message (sibling-suite convention).
- A fixture `mt_state_file` with no implement dispatch yields exit 0 and no `batch_gate` key.
- `bash -n` clean on the new script; `shellcheck` reports no new findings relative to a sibling
  orchestrate script.

---

### Phase 5: Engine wiring, stage contract, rendering, and registration [COMPLETED]

**Goal**: Make the stage actually fire once per invocation, render its result in the consolidated
output, and register every new file so the deploy and reachability gates see it.

**Tasks**:
- [x] Create `context/contracts/batch-gate-stage.md` mirroring `conclusion-stage.md`'s structure *(completed)*
      (Overview, Trigger / Evidence Base, Executable Stage Body, and a Coexistence Boundary With
      the Conclusion Stage section stating the two are disjoint mechanisms sharing one trigger
      seam, per the norm that file already sets).
- [x] In `skills/skill-orchestrate/SKILL.md`'s Move 4, add the stage call after `exit_status` *(completed)*
      resolution and BEFORE consolidated-output emission (so the rendered result and
      `.return-meta-multi-*.json` both carry it), using the bounded-waiter idiom the Move 1 call
      already demonstrates — this is a long-running detached command, so a hard timeout, writer
      liveness via `kill -0` on a captured PID, and one waiter per log, per
      `context/patterns/bounded-build-waiter.md`.
- [x] Reference `context/contracts/batch-gate-stage.md` by basename from that same SKILL.md edit, *(completed)*
      and add the new script to SKILL.md's `## Context References` list.
- [x] Add `batch_gate` to the `.return-meta-multi-${session_id}.json` metadata shape documented in *(completed)*
      `context/formats/return-metadata-file.md`, and to the `jq -n` field list named in Move 4.
- [x] Add a batch-gate result section to *(completed)*
      `context/patterns/orchestrate-batch-results-template.md`: the gate's outcome, the per-task
      attributed findings, and the unattributed batch-level set rendered as a batch-attributed
      result — never folded into one task's own completion status.
- [x] Document the stage in `docs/architecture/orchestrate-state-machine.md` at the Move 4/5 *(completed)*
      boundary, including the single-task/`/implement` invariance statement.
- [x] Register in `manifest.json`: `orchestrate-batch-gate.sh` under `provides.scripts` and *(completed)*
      `tests/test-orchestrate-batch-gate.sh` under the tests list (`provides.context` is
      whole-directory, so the new contract file needs no manifest entry).
- [x] Add an `index-entries.json` entry for `contracts/batch-gate-stage.md` with a non-empty *(completed)*
      `load_when` (commands: `orchestrate`), matching the `conclusion-stage.md` entry's shape.

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: interface

**Tier Justification**: The edit changes the engine's Move 4 call surface plus three registries
with enumerated direct dependents, covered by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-index-entries-schema.sh,test-context-reachability.sh,test-orchestrate-batch-gate.sh`.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - NEW: the stage contract
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 4 stage call, Context References entry, contract basename reference
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - `batch_gate` field in the multi-task return-meta shape
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - batch-gate result rendering
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - the new stage at the Move 4/5 boundary
- `agent-system/extensions/core/manifest.json` - register the new script and test suite
- `agent-system/extensions/core/index-entries.json` - index entry for the new contract file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-index-entries-schema.sh,test-context-reachability.sh,test-orchestrate-batch-gate.sh` exits 0.
- `test-context-reachability.sh` reports `batch-gate-stage.md` reachable with both `filename` and
  `index` among its styles.
- `jq -e '.provides.scripts | index("orchestrate-batch-gate.sh")' agent-system/extensions/core/manifest.json` succeeds.
- Diff read-through of SKILL.md confirms the call sits after `exit_status` resolution and before
  consolidated-output emission, and that Move 5's body is untouched.

---

### Phase 6: Integration verification and complete gate set [COMPLETED WITH EXCLUSIONS]

**Goal**: Verify end to end that a multi-task invocation defers and shares, a single-task
invocation and a bare `/implement` do not, and that the whole change set passes the complete gate
set.

**Tasks**:
- [x] Deploy the source store into the consumer tree so the deployed copies under `.claude/`
      reflect every Phase 1-5 edit, since ~41 Gate-8 suites resolve the DEPLOYED copy of their
      subject-under-test in preference to the source-store copy. *(completed: four
      `deploy-headless.sh --skip-verify` passes, the latter three re-syncing after a concurrent
      sibling commit and this phase's own Gate 20 fix; `diff -q` confirmed every Phase 1-5 file
      byte-identical between source and deployed copy)*
- [x] Multi-task case: with a fixture `mt_state_file` carrying two task numbers and at least one
      implement dispatch, confirm `orchestrate-build-dispatch.sh` emits `## Batch Gate Deferral`
      for an implement dispatch and that `orchestrate-batch-gate.sh` produces a `batch_gate`
      record with per-task attribution. *(completed: a live two-candidate `orchestrate-cycle-plan.sh`
      run against a fresh fixture state.json confirmed `--batch-gate-deferral` on both implement
      argv lines; Phase 4's own `test-orchestrate-batch-gate.sh` Cases 3/7 already cover per-task
      attribution and `batch_gate` record shape)*
- [x] Single-task invariance case: with a one-task `mt_state_file`, confirm no deferral flag is
      appended by `orchestrate-cycle-plan.sh`'s `build_args` block and the composed dispatch file
      is byte-identical to a pre-change build. *(completed: a live solo-candidate
      `orchestrate-cycle-plan.sh` run confirmed no `--batch-gate-deferral` in argv; combined with
      `test-orchestrate-build-dispatch.sh` Group 19's byte-identical-when-absent case)*
- [x] Bare-`/implement` invariance case: confirm no file on that path references the deferral
      directive — `grep -rn "batch-gate-deferral\|Batch Gate Deferral"` returns hits only in the
      orchestrate engine, its dispatch writer, the three Phase 1 contract files, and the new
      stage's own files. *(completed: grep across agent-system/ returned hits only in
      orchestrate-cycle-plan.sh, orchestrate-build-dispatch.sh, orchestrate-batch-gate.sh,
      batch-gate-stage.md, the three Phase 1 contract files, orchestrate-state-machine.md,
      index-entries.json, the two test suites, and this task's own plan/progress files)*
- [x] Run the complete gate set and resolve every finding, or close the phase
      `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record enumerating each
      remaining item with evidence. *(completed: one genuine regression — Gate 20's per-file
      ceiling for skills/skill-orchestrate/SKILL.md, caused by this task's own Phase 5 — fixed
      inline; the remaining 4 of 37 failures are pre-existing/sibling-caused, see Reasoned
      Exclusions below)*
- [x] Write the execution summary under `specs/403_share_one_verify_deploy_gate_run_per_batch/summaries/`. *(completed)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` - integration cases for the three invocation paths, if not already covered by Phase 4's unit cases
- `specs/403_share_one_verify_deploy_gate_run_per_batch/plans/01_batch-shared-verify-deploy-gate.md` - phase marker promotions

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, all 23 gates including
  Gate 8's full `run-all.sh` battery, no `--skip-slow` and no `--only-gate` narrowing.
- The three invocation-path cases above each produce their stated result.
- `git status --short` shows no unstaged source-store changes outside this task's declared file
  set.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 doc-lint: `lean` extension's two fixture scripts (`scripts/tests/fixtures/challenge/plan_keyword_noise.md`, `plan_list_item_goals.md`) not in `provides.scripts`, plus `project-wide` Rule S finding that `context/project/lean4/patterns/measurement-harness-strictness.md` has no `.claude/context/index.json` entry | Pre-existing lean4-extension documentation drift, wholly outside task 403's `core`-only file_scope; matches the known pre-existing baseline measured this session by task 389's implement phase (iss_1792019093789_pEpEft) | `bash .claude/scripts/check-extension-docs.sh` output: `[lean] FAIL: script file on disk NOT in provides.scripts: ...` (x2) and `[project-wide] FAIL: Rule S: deployed context/project/lean4/patterns/measurement-harness-strictness.md has no entry in .claude/context/index.json`; no lean4 file appears in task 403's declared file_scope |
| Gate 4 task-reference lint: one unexempted occurrence at `agent-system/extensions/core/context/standards/task-reference-exemptions.md:48` (`"Task 101: specs/101_remove_trivial_operator/summaries/01_summary.md"` inside the exemption table's own illustrative example row, missing a `task-ref-ok` marker) | Landed by a concurrent, unrelated commit (`acf5a523b`, "core: make the memory vault a path-level task-reference exemption") at 17:46:05 -- two minutes after this phase's first deploy pass, outside both task 403's and siblings 404/406's declared file_scope. Not previously enumerated in this dispatch's known-baseline list; recorded here for traceability (see `issues.jsonl`, class `pre-existing-unrelated-gate-failure`) | `bash .claude/scripts/check-task-references.sh` output: `FAIL: 1 unexempted task-reference occurrence(s) found` citing exactly that line; `git log -1 --format='%H %ai' -- agent-system/extensions/core/context/standards/task-reference-exemptions.md` shows `acf5a523b ... 17:46:05`, and `git status --porcelain` on that file is clean (not part of this task's or any sibling's uncommitted work) |
| Gate 8 `run-all.sh` (exit 1): at minimum `test-detect-noop-bash.sh` and `test-guard-git-push.sh` fail, matching the known pre-existing baseline (iss_1792019093909_Zk3nZO); a standalone re-run additionally tripped `test-update-task-status.sh`'s own "contamination guard" (its baseline-vs-final real-`specs/`-tree diff) | `test-guard-git-push.sh` is explicitly in sibling task 406's declared file_scope this cycle per this dispatch's own Territory block. `test-update-task-status.sh`'s failure is not a regression in `update-task-status.sh`: its baseline and final `git status` snapshots differ by exactly one line -- `?? specs/406_.../handoffs/phase-5-handoff-20261015T020309Z.md` -- a file sibling task 406 wrote to the real `specs/` tree during this suite's own run window. This is a live, first-hand instance of the exact cross-task gate-noise problem task 403 exists to fix | Direct re-run: `timeout 1200 bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` log showing `[FAIL] .../test-detect-noop-bash.sh`, `[FAIL] .../test-guard-git-push.sh`, `[FAIL] .../test-update-task-status.sh`; `test-update-task-status.sh`'s own direct-run output at its "contamination guard" section showing the single-line baseline/final diff naming sibling 406's handoff file |
| Gate 20: eager-load total (67,088 B) exceeds `eager_load.baseline_bytes` (66,100 B), 988 B over | Pre-existing, matches the known baseline measured this session by task 389's implement phase exactly (988 B over; iss_1792015798103_u6yBQB). Confirmed unrelated to task 403: `measure-eager-context.sh --check`'s own breakdown (`parent_chain`/`claudemd`/`at_import`/`rules` subtotals) contains no `skills/` category at all, so `skills/skill-orchestrate/SKILL.md`'s growth (the one file task 403's Phase 5 touched that is also budget-tracked) cannot be the cause of this separate sub-check; the companion per-file-ceiling sub-check for that same file was the genuine Phase-5-caused regression and was fixed inline in this phase, not excluded (see Decisions/Follow-ups in the summary) | `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` output: `TOTAL: 67088 B`, with `SUBTOTAL parent_chain 2982`, `SUBTOTAL claudemd 32679`, `SUBTOTAL at_import 0`, `SUBTOTAL rules 31427` (sums to 67088; no `skills` row present) |

## Testing & Validation

- [x] `bash .claude/scripts/verify-deploy.sh` exits 0 (complete gate set, Phase 6). *(deviation:
      altered — exits 4 of 37 failed, all pre-existing/sibling-caused per Phase 6's Reasoned
      Exclusions; the one genuine task-403-caused failure, Gate 20's SKILL.md per-file ceiling,
      was fixed inline and now passes)*
- [x] New suite `test-orchestrate-batch-gate.sh` passes, including the no-implement no-op, the
      two-task attribution split, the unattributable-finding case, the identifier-free-finding
      case, and the confirmation-drop case. *(completed: 22 passed, 0 failed)*
- [x] `test-orchestrate-build-dispatch.sh` passes, including byte-identical-when-flag-absent. *(completed: 155 passed, 0 failed)*
- [x] `test-orchestrate-cycle-plan.sh` passes, including the deferral-state hash-inequality case. *(completed: 371 passed, 0 failed)*
- [x] `test-orchestrate-cycle-postflight.sh` passes, including the four `invocation_modified_files`
      cases. *(completed: 238 passed, 0 failed)*
- [x] `test-context-reachability.sh`, `test-index-entries-schema.sh`, and
      `test-manifest-scripts-sync.sh` pass with the new files registered. *(completed: 15/0, 9/0,
      and 16/0 passed/failed respectively)*
- [x] Single-task and bare-`/implement` invariance confirmed (Phase 6). *(completed: live
      orchestrate-cycle-plan.sh runs and a repo-wide grep, see Phase 6's own task checklist)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` (new)
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` (new)
- Edits to `plan-format.md`, `phase-closure.md`, `general-implementation-agent.md`,
  `orchestrate-build-dispatch.sh`, `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`,
  `skill-orchestrate/SKILL.md`, `return-metadata-file.md`,
  `orchestrate-batch-results-template.md`, `orchestrate-state-machine.md`, `manifest.json`,
  `index-entries.json`, and three existing test suites
- `specs/403_share_one_verify_deploy_gate_run_per_batch/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is additive and independently revertible: Mechanism A is inert until
`orchestrate-cycle-plan.sh` appends `--batch-gate-deferral` (Phase 3's single `build_args` line),
and Mechanism B is inert until SKILL.md's Move 4 calls the new script (Phase 5's single call
block). Reverting either one line restores today's behavior without touching the other mechanism
or any plan file.

If the shared stage proves unreliable in practice, revert Phase 5's SKILL.md call block FIRST —
that restores the per-task full gate as the only gate, because Phase 3's directive would then
defer to a stage that never runs. The two must be reverted together, in that order: never leave
the deferral directive live with the shared stage disabled.

Before any rollback that would discard uncommitted work, take a durable checkpoint with
`bash .claude/scripts/git-snapshot.sh 403 --no-revert`; use the reverting default form only for a
genuine rollback, per `rules/git-workflow.md`.
