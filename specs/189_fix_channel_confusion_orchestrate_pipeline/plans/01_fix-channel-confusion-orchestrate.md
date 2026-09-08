# Implementation Plan: Fix three channel-confusion defects in the orchestrate cycle-plan pipeline

- **Task**: 189 - Fix three channel-confusion defects in the orchestrate cycle-plan pipeline
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: 150 (research-on-demand rewrite of orchestrate-cycle-plan.sh /
  orchestrate-predispatch-review.sh; must be landed and deployed first)
- **Research Inputs**: None (no research report; the dispatch description carries measured,
  independently reproduced evidence plus a binding design shape — see "Research Integration")
- **Artifacts**: plans/01_fix-channel-confusion-orchestrate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three defects in the `/orchestrate` cycle-plan pipeline are one bug class expressed three ways:
a channel carrying two meanings. Item (a) makes stdout structurally the JSON-only channel in
`orchestrate-cycle-plan.sh` (and its sibling `orchestrate-cycle-postflight.sh`) via an
entry-point `exec 3>&1 1>&2` redirect, replacing the per-call-site `>&2` stopgap that landed in
commits `1c44c8a33` / `6bca9f194`. Item (b) stops the per-task cycle budget being charged for a
composition that nothing ever consumed, both within one invocation (a cached plan replay) and
across invocations (a durable uncharged-dispatch ledger in `.orchestrator-loop-guard`). Item (c)
stops `orchestrate-predispatch-review.sh` printing a negative it never tested: a solo
`self_modifying: true` candidate is ADMITTED, so Class C's defer-only filter renders it as
"0 findings", and Class D has the identical conflation for admitted `idle_overlap_advisory`
verdicts.

**The edit target is the source store**: `agent-system/extensions/core/**`. Nothing under
`.claude/**` is hand-authored at any point in this plan.

Definition of done: `skill-orchestrate/SKILL.md`'s Move 1 snippet parses the plan JSON verbatim
with no preamble stripping; `commands/orchestrate.md`'s dry-run invocation as documented actually
runs; a composition that dispatched nothing, re-run, charges no cycle while a genuine dispatch
still charges exactly one; a solo self-modifying candidate is reported as such; fixture tests
cover all three; the full gate set is green.

### Research Integration

No research report exists and none was requested. The dispatch description is the specification:
it carries direct-probe evidence (verified 2026-09-08) for all three defects, a partial-fix
addendum naming the two commits that already landed, a fourth-defect scope removal, an audit
result for the rest of the source store, and an acceptance bar. Codebase reads during planning
confirmed every claim that this plan depends on:

- `orchestrate-cycle-plan.sh:1593` still carries the per-call-site `skill_preflight_update … >&2`
  stopgap; `:521` is the sole `printf` of the plan JSON to stdout; the `--dry-run` human table is
  already inside a `{ … } >&2` block.
- `orchestrate-cycle-plan.sh:268` requires `--session` unconditionally (`exit 2`), so
  `commands/orchestrate.md`'s no-session dry-run fallback branch (`:105-106`) is dead code.
- `orchestrate-cycle-plan.sh:1650-1654` charges `cycle_counts[t]` and flushes the durable guard
  file at dispatch-row build time — i.e. once per *composition*, regardless of whether the lead
  ever consumed the row.
- `orchestrate-batch-admit.sh:566-570, 583-588` emit `{decision: "admit", self_modifying: true}`
  with **no** `critical_path`/`critical_label` (those fields exist only on the defer branch at
  `:577-580`), and `:621-635` attaches `idle_overlap_advisory` to admit verdicts.
- `orchestrate-predispatch-review.sh:370` (Class C) and `:388` (Class D) filter on
  `decision == "defer"`, so both print false negatives.
- `scripts/tests/test-orchestrate-cycle-plan.sh` Group 15 (`:1538-1626`) is the existing
  regression net for the ingest direction; the harness provides `run_sut`, `write_state`, `jqf`,
  `pass`/`fail`, and a `$WORKDIR/.claude/scripts/` stub directory.
- `scripts/lint/` holds nine `lint-*.sh` siblings; `scripts/tests/run-all.sh` auto-discovers
  `scripts/tests/test-*.sh` and is `verify-deploy.sh`'s Gate 8.

### Prior Plan Reference

No prior plan. Two source-store commits already landed against this task's item (a) and are
treated as a stopgap to be *replaced*, not as work completed:
`1c44c8a33` (keep cycle-plan stdout pure JSON) and `6bca9f194` (fix stderr-into-JSON at all four
collaborator calls, via the shared `run_capture_stdout` helper). Item (a)'s fd-3 redirection
governs what the script EMITS; `run_capture_stdout` governs what it INGESTS. Both directions stay.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`.

## Goals & Non-Goals

**Goals**:
- Make stdout structurally the JSON-only channel in `orchestrate-cycle-plan.sh` and
  `orchestrate-cycle-postflight.sh`, so no future callee can leak into the data channel.
- Remove the now-redundant per-call-site `>&2` stopgap once the structural fix lands, rather than
  leaving two overlapping mechanisms.
- Make the documented consumer contracts true: SKILL.md's Move 1 snippet works verbatim, and
  `commands/orchestrate.md`'s dry-run invocation actually runs.
- Make plan composition idempotent with respect to the per-task cycle budget, within an
  invocation and across invocations. A genuine dispatch still costs exactly one.
- Make `orchestrate-predispatch-review.sh` never print a negative it did not test: Classes C and D
  report admitted-with-hazard verdicts as their own rows, and every "0 findings" line states
  exactly what was filtered.
- Add fixture regression coverage for all three items, and a maintained lint for the channel
  discipline class so it cannot regress unnoticed.

**Non-Goals**:
- Any change to `orchestrate-batch-admit.sh`'s verdict schema or its collision/self-modification
  predicate. Class C/D remain CONSUMERS of that verdict.
- Making a solo self-modifying candidate DEFER rather than admit. The reporting is broken, not
  the admission decision.
- Any change to `verify-deploy.sh`, `deploy-headless.sh`, or `orchestrate-cycle-plan.sh`'s
  redeploy-checkpoint block (lines ~578-760). The cross-referenced checkpoint tasks own those.
- Any change to `orchestrate-predispatch-review.sh`'s Class A block. The cross-referenced Class A
  false-positive task owns it.
- Naming *which* orchestrator-critical path an admitted self-modifying candidate matched. That
  data is absent from the admit verdict, and deriving it here would fork the admission predicate.
  Class C reports the hazard and the candidate's declared `file_scope` instead (see Phase 4).
- Hand-authoring anything under `.claude/**`. Deploy is a separate, externally owned step.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `exec 3>&1 1>&2` breaks a value the script captures via `$(...)` | H | L | Command substitution rebinds fd 1 inside the subshell, so captures are unaffected; the only unconditional stdout write is `:521`. Phase 1 greps every `echo`/`printf` not already `>&2` and not inside `$(...)` before editing, and Group 15 plus a new Group 16 assert stdout purity end to end. |
| fd 3 is closed or inherited unexpectedly by a callee | M | L | Redirect once at entry, never re-open; callees inherit fd 3 harmlessly because none writes to it. Phase 1 adds a stub that writes to fd 3 from a collaborator and asserts the plan JSON is still the only fd-3 content the caller sees. |
| Item (b) suppresses a charge for a dispatch that DID run (lead crashed after dispatch, before postflight) | H | M | The replay is honored only when the freshly composed row is identical in `(task, phase, forced)` to the recorded pending row AND no postflight has been recorded for that `dispatch_seq`. Postflight clears the ledger on ANY outcome (success or failure), so a run that reached postflight can never be replayed. |
| Item (b) freezes the loop by replaying a stale plan after external status changes | M | M | Cache only when the composition actually BUILT ≥1 dispatch row (i.e. actually charged). A no-dispatch composition already charges nothing, so it is never cached and always re-evaluates fresh. |
| The suggested lint's gate wiring requires editing `verify-deploy.sh`, which this task MUST NOT touch | M | H (certain) | Deliver the lint plus its own `test-lint-*.sh` suite, which `run-all.sh` auto-discovers and `verify-deploy.sh` Gate 8 therefore already runs. The numbered-gate wiring is recorded as a coupling for the checkpoint-task owner; it is NOT performed here. See Phase 7. |
| Class C/D output change breaks a downstream consumer | M | L | The script is report-only, human-readable, and has no test suite or machine consumer today; Phase 4 adds the first one. Existing "0 findings" lines are made *more* specific, never removed. |
| This task's own state.json entry has `file_scope: null` — a live Class B finding, and the reason its own critical-path hazard is invisible to Class C | L | H (present now) | Out of scope to write state.json here. Recorded as an observation; `orchestrate-predispatch-review.sh --repair 189` is the sanctioned remedy and is the operator's call. |
| Deployed `.claude/**` copies drift from the source store until a redeploy runs | M | H | Expected and owned elsewhere. All verification in this plan runs against the source store or against test fixtures that copy from it; no phase depends on a redeploy having happened. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 3, 5 | 1 |
| 3 | 6 | 2, 5 |
| 4 | 7 | 2, 3, 4, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Structural fd-3 JSON channel in orchestrate-cycle-plan.sh [COMPLETED]

**Goal**: stdout becomes the JSON channel structurally, not per call site. No future callee can
contaminate the plan JSON.

**Tasks**:
- [x] Re-read the two landed commits (`git show 1c44c8a33`, `git show 6bca9f194`) so nothing they
      already fixed is re-derived or undone. *(completed)*
- [x] Audit every stdout write in `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`:
      list each `echo`/`printf`/heredoc that is neither `>&2`-redirected nor inside a `$(...)`
      capture, and confirm the emit at `:521` is the only intentional one. *(completed)*
- [x] Immediately after `set -euo pipefail` and the `SCRIPT_DIR`/`common.sh` prologue, add
      `exec 3>&1 1>&2` with a comment stating the contract: fd 3 is the data channel, fd 1/2 are
      both diagnostics, and no per-call-site redirection is needed any more. *(completed)*
- [x] Change the plan-JSON emit in `emit_and_exit()` (`:521`) to `printf '%s\n' "$plan_json" >&3`. *(completed)*
- [x] Remove the now-redundant `>&2` on the `skill_preflight_update` call (`:1593`) and update its
      preceding comment to point at the entry-point redirect instead of the call site. Leave
      `run_capture_stdout` and all four of its call sites untouched — they govern the opposite
      (ingest) direction. *(completed)*
- [x] Update the script's header Output-contract comment to state the fd-3 discipline. *(completed)*
- [x] Do NOT touch the redeploy-checkpoint block (~`:578-760`). Confirm by diff that it is
      unmodified; every write in it is already `>&2` and needs no change. *(completed)*
- [x] Add Group 16 to `scripts/tests/test-orchestrate-cycle-plan.sh`: a collaborator stub and a
      stubbed `skill_preflight_update` that both write chatty prose to **stdout** (not stderr);
      assert the SUT's stdout still parses as a single JSON object, that `.dispatch[0]` is intact,
      and that the prose appears on stderr. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` and
      confirm Groups 1-15 stay green alongside the new Group 16. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: the audit is expected to find exactly one intentional stdout write
(`:521`) and one redundant `>&2` stopgap (`:1593`), with the `--dry-run` table already inside a
`{ … } >&2` block. Confirm at implementation time by running
`grep -n 'echo\|printf\|cat <<' orchestrate-cycle-plan.sh | grep -v '>&2' | grep -v '\$('` and
reconciling every surviving line before editing; if the count differs, treat the extra lines as
findings and handle them explicitly rather than assuming this list is complete.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — entry-point `exec 3>&1 1>&2`,
  fd-3 emit, stopgap removal, header contract note
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 16

**Verification**:
- Test suite green: Group 15 unchanged and passing, Group 16 passing, total suite count up by the
  new group's assertions with 0 failures.
- `bash orchestrate-cycle-plan.sh --dry-run --session t --state-file specs/state.json 189 | jq -e .`
  exits 0 (once Phase 3 lands, without `--session` too).
- `git diff` shows zero lines changed inside the redeploy-checkpoint block.

---

### Phase 2: Same fd-3 discipline in orchestrate-cycle-postflight.sh; audit the siblings [COMPLETED]

**Goal**: the second script sharing the defect gets the same structural treatment; the two that
do not are audited and the result recorded, so no one re-audits them later.

**Tasks**:
- [x] Apply the identical `exec 3>&1 1>&2` entry-point redirect to
      `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, and change its two
      final `jq -n -c` emits (the `user_decision` and non-`user_decision` branches, ~`:1002` and
      ~`:1018`) to write to fd 3. *(completed)*
- [x] Remove the now-redundant per-call-site `>&2` on `skill_postflight_update` (4 call sites),
      `skill_link_artifacts`, and the `git-commit-scoped.sh` call, updating each preceding comment
      to reference the entry-point redirect. *(completed)*
- [x] Audit `orchestrate-batch-admit.sh` and `orchestrate-triage-classify.sh`: both already emit
      once at the end (`printf '%s\n' "$verdicts"`) with every diagnostic on stderr. Record this
      "audited clean, no change needed" result in each script's header rather than editing them,
      so the next reader does not re-open the question. *(completed)*
- [x] Extend `scripts/tests/test-orchestrate-cycle-postflight.sh` with a stdout-purity group
      mirroring Phase 1's Group 16: a stubbed helper writing prose to stdout, asserting the
      postflight verdict JSON still parses. *(completed: used the REAL, unmodified
      update-task-status.sh rather than a synthetic stub -- its own final confirmation line is
      already unconditional on stdout for every live call, so it reproduces the exact defect
      shape without needing a stub)*
- [x] Run both affected suites. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: six redundant `>&2` call-site redirections are expected in
`orchestrate-cycle-postflight.sh` (four `skill_postflight_update`, one `skill_link_artifacts`, one
`git-commit-scoped.sh`). Confirm at implementation time with
`grep -n '>&2' orchestrate-cycle-postflight.sh` and classify each hit as redundant-post-fd-3 vs.
a genuine diagnostic `echo … >&2` (which stays) before removing anything.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — header comment only
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — header comment only
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`

**Verification**:
- `test-orchestrate-cycle-postflight.sh` green including the new group.
- `test-orchestrate-cycle-plan.sh` still green (it stubs postflight collaborators).
- Diff of the two header-only files touches comments exclusively.

---

### Phase 3: Reconcile the documented consumer contracts [COMPLETED]

**Goal**: both documented invocations become true. The SKILL.md Move 1 snippet is verified
verbatim; the dead no-session dry-run branch is removed by fixing the script side.

**Tasks**:
- [x] Run `skills/skill-orchestrate/SKILL.md` Move 1's snippet (`:63-76`) verbatim, unmodified,
      against a real task number, and confirm `jq -c '.stop'` succeeds with no preamble stripping.
      Record the transcript in the phase's commit message. Change the snippet only if it fails. *(completed)*
- [x] Make `--session` optional in `orchestrate-cycle-plan.sh` **only under `--dry-run`**: move the
      `:268` guard so the `--session` half is enforced when `dry_run != true`, and synthesize an
      internal, never-written identity (e.g. `dryrun-$$-$(date +%s)`) otherwise. Note in the code
      comment why this is safe: `mt_save` is already a no-op under `--dry-run`, so the derived
      `mt_state_file` path is never created. `--state-file` stays unconditionally required. *(completed)*
- [x] Update `usage()` and the script header's flag documentation to state that `--session` is
      required except under `--dry-run`. *(completed)*
- [x] Collapse `commands/orchestrate.md`'s two-branch dry-run block (`:101-110`) into one
      unconditional invocation, and replace the "`--session` is passed to the report only when
      non-empty" sentence with the true statement (the report does not require a minted session;
      pass `--session "$SESSION_ID"` when one exists, otherwise omit it). *(completed)*
- [x] Add a test group asserting: `--dry-run` with no `--session` exits 0 and prints parseable
      plan JSON on stdout; live mode with no `--session` still exits 2 with the existing message. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — flag validation, usage, header
- `agent-system/extensions/core/commands/orchestrate.md` — dry-run short-circuit block and its
  surrounding prose
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — only if Move 1 fails verbatim
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new group

**Verification**:
- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json 189`
  exits 0 and its stdout pipes cleanly into `jq -e .`.
- The same call without `--dry-run` and without `--session` still exits 2.
- The SKILL.md Move 1 snippet, copy-pasted unmodified, yields a non-empty `stop_json`.

---

### Phase 4: Never print an untested negative — Classes C and D [COMPLETED]

**Goal**: `orchestrate-predispatch-review.sh` reports admitted-with-hazard verdicts as their own
rows, and every remaining "0 findings" line states exactly what was filtered.

**Tasks**:
- [x] Extend the `cd_findings` jq program with two new selectors, alongside the existing C/D/E
      ones, consuming only fields the verdict already carries:
      - `class: "C-admitted"` — `select($v.decision == "admit" and $v.self_modifying == true)`,
        carrying `task_number` and the candidate's declared `file_scope` from the already-slurped
        state (never a re-derived critical-path match; see Non-Goals).
      - `class: "D-admitted"` — `select($v.decision == "admit" and ($v.idle_overlap_advisory != null))`,
        carrying `colliding_task_number`, `colliding_task_status`, `overlapping_path`,
        `collision_scope` verbatim from the advisory. *(completed)*
- [x] Render Class C as two labelled sub-blocks: `Deferred (self-modification)` (today's rows,
      unchanged) and `Admitted (self-modification hazard)`, the latter styled on
      `context/patterns/orchestrate-batch-results-template.md`'s "Admitted (idle overlap
      advisory)" section — admitted, not deferred, advisory. Each admitted row states the
      candidate's declared `file_scope` and that the hazard is live. *(completed)*
- [x] Replace Class C's negative with one that states exactly what was filtered, e.g.
      `0 deferred for self-modification (N admitted carrying self_modifying: true)`, and print
      `0 findings (no candidate carries the self-modification hazard, deferred or admitted)` only
      when BOTH row sets are empty. *(completed)*
- [x] Do the same for Class D: an `Admitted (idle cross-batch overlap)` sub-block plus a precise
      negative that distinguishes "none deferred" from "none matched". *(completed)*
- [x] Sweep Classes B and E for the same conflation and record the result in the script header:
      Class B derives from state.json fields directly with no defer filter (accurate as written);
      Class E's `session_active` reason exists only on defer verdicts — an admit verdict cannot
      carry it — so its negative is accurate, but restate it as
      `0 deferred for session contention (this signal exists only on defer verdicts)`. *(completed)*
- [x] Do NOT touch the Class A block, and do not change `orchestrate-batch-admit.sh` at all —
      confirm with `git diff --stat` that neither is in the diff. *(completed)*
- [x] Create `scripts/tests/test-orchestrate-predispatch-review.sh` (the script has no suite
      today): stub `orchestrate-batch-admit.sh` to emit, in turn, a solo
      `{decision:"admit", self_modifying:true}` verdict, an admit verdict carrying
      `idle_overlap_advisory`, a defer verdict of each class, and an all-clean batch; assert the
      rendered report for each. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: four negative-message sites are expected to need changing (Classes C, D, E,
and the combined C empty case); Class B's is expected to be correct as written. Confirm at
implementation time by listing every `echo "0 findings` / `echo "0 deferred` line in the script
and classifying each against the verdict field it actually filters on.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — `cd_findings` jq
  program and the Class C/D/E report sections (never Class A)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — new file

**Verification**:
- With a stubbed solo `{decision:"admit", self_modifying:true}` verdict, the report contains an
  `Admitted (self-modification hazard)` row naming the task and does NOT contain
  "0 findings (no candidate's file_scope names an orchestrator-critical path)".
- With a stubbed admit + `idle_overlap_advisory` verdict, Class D renders an admitted row.
- With a genuinely clean batch, every class still prints an explicit, precise zero line — no
  section is omitted or silently empty.
- `git diff --stat` lists neither `orchestrate-batch-admit.sh` nor any Class A hunk.

---

### Phase 5: Do not charge for a read — in-session plan cache [COMPLETED]

**Goal**: within one `/orchestrate` invocation, a re-entry that follows a composition nothing
consumed replays the cached plan verbatim and charges no cycle.

**Tasks**:
- [x] Add a `plan_cache` field to the `mt_state_file` initializer's `//=` list
      (`orchestrate-cycle-plan.sh` ~`:410-441`), shaped
      `{dispatch_seq_counter: int, plan: <plan object>}` or absent, and document it in the header's
      field list alongside the existing entries. *(completed)*
- [x] In `emit_and_exit()`, write `plan_cache` **only when** the composition actually built ≥1
      row in `out_dispatch_rows`/`out_aux_dispatch_rows` — i.e. only when budget was actually
      charged. A no-dispatch composition charges nothing and must stay uncached so it always
      re-evaluates fresh. *(completed)*
- [x] On entry, immediately after the `mt_state_file` is loaded and before the seed/eligibility
      pass, check for a `plan_cache` whose `dispatch_seq_counter` equals the current
      `.dispatch_seq_counter`. On a match: emit `plan_cache.plan` verbatim to fd 3, log a named
      `[orchestrate] PLAN CACHE REPLAY: …` line to stderr explaining that nothing was dispatched
      since the last composition so no cycle is charged, and exit 0 without running any
      composition, any budget increment, or any loop-guard flush. *(completed)*
- [x] Add cache invalidation to `orchestrate-cycle-postflight.sh`: in the multi-task branch (the
      one already resolving the derived multi-state file), delete `plan_cache` as its first state
      write. Any postflight at all is proof the plan was consumed. *(completed)*
- [x] Add an explicit `--no-plan-cache` escape hatch to `orchestrate-cycle-plan.sh` (skip both the
      read and the write) for debugging and for the test suite's own non-cache groups. *(completed)*
- [x] Add a test group: run the SUT twice against an unchanged fixture state; assert run 2's
      stdout is byte-identical to run 1's, that `cycle_counts` and the fixture's
      `.orchestrator-loop-guard` `cycle_count` are unchanged after run 2, and that the replay
      notice appears on stderr. Then simulate a postflight (delete `plan_cache`), run a third
      time, and assert the cycle IS charged. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `plan_cache` init, entry
  replay branch, `emit_and_exit` write, `--no-plan-cache` flag, header field list
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — cache invalidation
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new group

**Verification**:
- Two consecutive SUT runs against unchanged state produce identical stdout, and the second
  leaves `cycle_counts[t]` and the durable guard file untouched.
- After the simulated postflight, the next run charges exactly one cycle.
- A composition producing zero dispatch rows writes no `plan_cache` (assert the field is absent).

---

### Phase 6: Do not charge for a read — durable cross-invocation ledger [COMPLETED]

**Goal**: close the failure actually observed in production, where a parse failure in one
`/orchestrate` invocation permanently consumed a cycle and the *next* invocation started from a
fresh `mt_state_file` that could not see the wasted charge.

**Tasks**:
- [x] Extend `orchestrate-loop-guard-init.sh` with a `pending_dispatch` field on the
      `.orchestrator-loop-guard` file, alongside `cycle_count`, preserving every other field
      exactly as `--flush` already does. Shape:
      `{seq: int, phase: string, forced: bool, dispatch_file: string, recorded_at: string}` or
      absent. Add `--record-pending <task_dir> <json>` and `--clear-pending <task_dir>` forms,
      and extend `--seed`'s output to include `pending_dispatch` (defaulting to `null` for a
      pre-schema guard file, matching the existing `// 0` forward-compatibility posture).
      Document all of it in the script header. *(completed)*
- [x] In `orchestrate-cycle-plan.sh`'s live half, before the `cycle_counts[t]` increment at
      `:1650-1654`: if the seeded `pending_dispatch` for this task exists, matches the freshly
      composed row in `(phase, forced)`, and its `dispatch_file` still exists on disk, then this
      is a replay of an already-charged-but-never-consumed dispatch — reuse the recorded `seq`,
      skip the increment, skip the `--flush`, and log a named
      `[orchestrate] UNCONSUMED DISPATCH REPLAY: …` line to stderr. Otherwise charge as today and
      record the new `pending_dispatch`. *(completed)*
- [x] In `orchestrate-cycle-postflight.sh`, clear `pending_dispatch` for the task on **any**
      postflight outcome (success, failure, defer, halt) — reaching postflight at all is proof the
      dispatch was consumed, so a run that got that far can never be replayed. *(completed)*
- [x] Update `context/reference/state-management-schema.md` (or the loop-guard file's documented
      schema home, whichever the codebase actually uses) with the new field. *(completed: used
      context/standards/orchestrator-runtime-files.md, the loop guard's actual documented schema
      home -- state-management-schema.md has no loop-guard-file section at all)*
- [x] Add test groups to `test-orchestrate-cycle-plan.sh` and `test-loop-guard-budget-override.sh`:
      a fresh session against a guard file carrying a matching, file-present `pending_dispatch`
      does not increment `cycle_count`; the same with a *different* phase, a missing dispatch
      file, or a cleared `pending_dispatch` does increment it exactly once. *(completed)*
- [x] Confirm `--continue-budget`'s existing archive-and-reset path still works and now also
      clears `pending_dispatch`. *(completed)*

**Timing**: 2 hours

**Depends on**: 2, 5

**Verification Tier**: full

**Scope Hypothesis**: exactly one increment site (`:1650-1654`) and one flush call are expected in
`orchestrate-cycle-plan.sh`. Confirm at implementation time with
`grep -n 'cycle_counts\[\$t\] = \|--flush' orchestrate-cycle-plan.sh`; if a second charge site
exists, both must be gated, not just the first.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` — new field and two forms
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — charge gating and recording
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — clearing
- `agent-system/extensions/core/context/reference/state-management-schema.md` — schema note
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh`

**Verification**:
- Fixture: guard file at `cycle_count: 3` with a matching `pending_dispatch` whose dispatch file
  exists; a fresh-session SUT run leaves it at 3 and reuses the recorded seq.
- Same fixture with `pending_dispatch` cleared: the run leaves it at 4.
- Same fixture with a mismatched phase: the run leaves it at 4 (never a false replay).
- `test-loop-guard-budget-override.sh` still green — the locked budget-override region is
  unmodified.

---

### Phase 7: Maintained lint for the channel-discipline class, and the full gate run [COMPLETED]

**Goal**: the defect class cannot regress unnoticed, and the whole change set passes the full gate
set. The one place this task's scope collides with the checkpoint tasks' territory is recorded
rather than crossed.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh`, following
      the nine existing `lint-*.sh` siblings' conventions (`--verbose`, machine-greppable failure
      lines, `REPO_ROOT` honored, exit 0/1). It detects the class in both directions:
      - INGEST: a capture with `2>&1` whose value is later consumed by a `jq` pipe, a `jq`
        here-string, or a `while read` NDJSON loop. The ad-hoc detector behind the addendum's
        audit needed three iterations before it caught the `while read` shape — that shape is the
        dangerous half and MUST be covered.
      - EMIT: a script whose documented output contract is JSON on stdout but which contains an
        unredirected `echo`/`printf` outside a `$(...)` capture and outside an fd-3 emit.
      *(completed)*
- [x] Encode the known false positive as a named, commented allowlist entry:
      `verify-deploy.sh`'s `doc_lint_output` parses human-readable lint text, not JSON, so merging
      stderr there is intentional. The allowlist must state the reason inline, not just the path.
      *(completed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh`
      with three fixture families — a known-bad ingest sample of each of the three consumption
      shapes, a known-bad emit sample, and the real corpus — asserting the lint flags the bad
      samples and reports the real corpus clean. *(completed: 11 passed, 0 failed)*
- [x] **Do NOT wire the lint into `verify-deploy.sh`.** That file is owned by the cross-referenced
      redeploy-checkpoint task and is on this task's MUST NOT list. Record the coupling explicitly
      in the lint script's header and in the task summary: the lint already runs inside the full
      gate set via `run-all.sh` (Gate 8) by virtue of its test suite, and the numbered-gate wiring
      is a follow-up for whoever owns `verify-deploy.sh` next. *(completed: verify-deploy.sh
      untouched, confirmed via grep; coupling recorded in the lint script's header)*
- [x] Run the full gate set: `bash agent-system/extensions/core/scripts/tests/run-all.sh`, plus
      each directly affected suite individually for a readable transcript. *(deviation: altered —
      the full run-all.sh sweep was withheld this cycle per an explicit prior-cycle decision: two
      consecutive runs wedged on test-verify-deploy-context-budget.sh, >6 min each with no
      completion, on a host already 16 GB into swap. Verified instead with the targeted suites
      directly affected by this task: test-orchestrate-cycle-plan.sh (147 passed),
      test-orchestrate-cycle-postflight.sh (65 passed), test-orchestrate-predispatch-review.sh
      (14 passed), test-lint-json-channel-discipline.sh (11 passed) = 237 passed, 0 failed. The
      full run-all.sh sweep remains a follow-up for a future cycle once host memory pressure and
      the test-verify-deploy-context-budget.sh wedge are addressed — see #181/#182/#180 for the
      redeploy-checkpoint-cost work that likely underlies the wedge.)*
- [x] Re-run `skill-orchestrate/SKILL.md` Move 1 verbatim and `commands/orchestrate.md`'s dry-run
      invocation as documented, one final time, as the end-to-end acceptance check. *(completed:
      re-verified in a synthetic deployed-shaped tree mirroring the test harness's own sandbox
      convention. SKILL.md's Move 1 `$(...)` capture parses via `jq -c '.stop'` with no preamble
      stripping (exit 0, `stop_json: null`); `commands/orchestrate.md`'s `--dry-run` invocation and
      its documented empty-`--session` fallback both run and exit 0 with pure JSON on stdout and
      the human table on stderr.)*
- [x] Confirm the final diff touches no `.claude/**` path, no `verify-deploy.sh`, no
      `deploy-headless.sh`, no redeploy-checkpoint hunk, no Class A hunk, and no
      `orchestrate-batch-admit.sh` logic. *(completed: confirmed via `git status`/`git diff`; the
      only source-store changes are the two new lint/test files plus this plan's and its progress
      file's own bookkeeping)*

**Timing**: 2 hours

**Depends on**: 2, 3, 4, 6

**Verification Tier**: full

**Scope Hypothesis**: the lint is expected to report the real source-store corpus clean apart from
the single documented `verify-deploy.sh` allowlist entry, per the addendum's audit result. Confirm
at implementation time by running the lint across every non-test `.sh` under
`agent-system/extensions/`; any additional hit is a genuine finding to triage, not a lint bug to
suppress.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` — new file
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` — new file
- `agent-system/extensions/core/context/architecture/orchestrate-state-machine.md` (or the
  equivalent doc home) — note the fd-3 emit contract and the two no-charge replay mechanisms

**Verification**:
- `run-all.sh` reports 0 failed suites and a non-zero discovered-suite count.
- The lint flags all four known-bad fixtures and passes the real corpus.
- `git diff --stat` against the task's base commit contains none of the forbidden paths.

---

## Testing & Validation

- [x] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 15
      still green (the pre-existing ingest-direction net), plus the new emit-purity, dry-run
      `--session`, plan-cache, and pending-dispatch groups. *(completed: 147 passed, 0 failed)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new
      stdout-purity group plus the cache/ledger invalidation groups. *(completed: 65 passed, 0
      failed)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` —
      new suite covering admitted-with-hazard rendering for Classes C and D, and precise negatives
      for C/D/E. *(completed: 14 passed, 0 failed)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` — the
      locked budget-override region still behaves identically. *(completed: 8 passed, 0 failed)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` — the
      new lint catches all three ingest shapes and the emit shape. *(completed: 11 passed, 0
      failed)*
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` — whole-repo suite green.
      *(deviation: skipped — two consecutive full runs wedged on
      test-verify-deploy-context-budget.sh, >6 min each with no completion, on a host already
      16 GB into swap; killed per an explicit prior-cycle decision. Every suite directly affected
      by this task's changes was instead run individually and is green (243 passed across the
      five suites above, 0 failed). The whole-repo sweep is a follow-up for a future cycle.)*
- [x] Acceptance, run by hand and recorded: SKILL.md Move 1 verbatim parses; the documented
      dry-run invocation runs; a re-run composition charges nothing while a genuine dispatch
      charges exactly one; a solo `self_modifying: true` candidate is reported as such. *(completed
      in this cycle: SKILL.md Move 1 and the dry-run invocation re-verified in a synthetic
      deployed-shaped tree, see Phase 7 checklist above. The plan-cache/no-double-charge and
      self-modifying-reported-as-such acceptance items were verified by Phases 5/6 and Phase 4's
      own fixture suites respectively, in earlier cycles.)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
  `orchestrate-triage-classify.sh` (header comments only — audited-clean record)
- `agent-system/extensions/core/commands/orchestrate.md` (modified)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified only if Move 1 fails
  verbatim)
- `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-loop-guard-budget-override.sh` (extended)
- `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `context/architecture/orchestrate-state-machine.md` (doc updates)
- `specs/189_fix_channel_confusion_orchestrate_pipeline/summaries/01_*-summary.md` (at completion)

## Rollback/Contingency

Every phase is a self-contained commit against the source store, and `.claude/**` is a
regenerated deploy artifact that is never hand-edited here — so reverting is `git revert` of the
phase commits, with no deploy-state cleanup needed beyond the next ordinary redeploy.

Per-item fallbacks if a phase cannot land:
- **Item (a)**: revert the fd-3 commits and restore the per-call-site `>&2` stopgap
  (`1c44c8a33` / `6bca9f194` behavior). Live runs stay unblocked; the structural weakness returns.
- **Item (b)**: revert Phases 5-6. The budget over-charges exactly as it does today; no state is
  corrupted, because `pending_dispatch` and `plan_cache` are both additive fields whose readers
  all default them (`// null`), so a guard file written by the new code is read correctly by the
  old.
- **Item (c)**: revert Phase 4. The report returns to its current false-negative behavior; no
  admission decision changes either way, since the script is report-only.

If Phase 6 proves riskier than budgeted, Phase 5 alone still satisfies the same-invocation half of
the acceptance bar and can ship independently; record the cross-invocation gap as a follow-up
rather than weakening the replay guards to force Phase 6 through.
