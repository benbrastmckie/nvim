# Implementation Plan: Task #487

- **Task**: 487 - Stop the identical-dispatch convergence guard halting a task on cycle 2 even when cycle 1 closed a real plan phase
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None (territory edge against task 451 to be re-checked at admission; see Risks)
- **Research Inputs**: specs/487_identical_dispatch_halt_despite_phase_progress/reports/01_phase-progress-identical-dispatch-guard.md
- **Artifacts**: plans/01_phase-progress-identical-dispatch-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The identical-dispatch convergence guard in `orchestrate-cycle-plan.sh` halts a task on its
second consecutive cycle whenever the composed dispatch body hashes identically. For an ordinary
(non-hard-mode) `implement` dispatch the body carries no phase-progress content at all, so closing
a plan phase changes no line of it — the guard then reads genuine, committed progress as
non-convergence. This plan adds an **independent-signal streak freeze** modelled directly on the
`deploy_pending` freeze that already sits immediately above the halt in the same function scope:
the plan file's own `[COMPLETED]`/`[COMPLETED WITH EXCLUSIONS]` phase-heading count is persisted
per task alongside `last_dispatch_hash`, and a hash match accompanied by a strictly-increased
count freezes the streak rather than charging it as churn. It then corrects the hash normalizer's
own over-general header assertion and pins both the new non-halting case and the still-halting
case with regression fixtures.

### Research Integration

The research report confirmed the task description's root cause by direct code reading and is
re-confirmed here against the live source store (see Premise Re-Validation below). Three of its
findings shape this plan directly:

- The `deploy_pending` streak-freeze block (`orchestrate-cycle-plan.sh`, immediately above the
  halt) is a fully-worked structural precedent for "do not charge churn when an independent
  signal explains the repetition", with explicit freeze-never-suppress semantics. This plan
  reuses its exact conditional shape, per-task fresh-read discipline, and re-arm behavior.
- `lib/phase-heading-patterns.sh` is already sourced **unconditionally** in
  `orchestrate-cycle-plan.sh` (the sourcing site carries its own comment stating the widening
  beyond the hard-mode loop was deliberate and side-effect-free), so no new sourcing is needed.
  Its ordering contract — whole-file `has_nonconforming_phase_headings` check BEFORE any filtered
  count, with a named inconclusive branch on a hit — is mandatory for the new signal.
- The plan file's own heading markers are a stronger signal than the handoff's self-reported
  `phases_completed`: the hard-mode loop's own marker/handoff crosscheck exists precisely because
  the two can disagree, and the plan file is available even when a dispatch returned `partial`
  without writing the field.

This plan **departs from the research report on one point**: the report recommended layering its
option (a) (emit phase progress into the hashed dispatch body) on top as an additive
transparency enhancement. Planning-time investigation found two reasons not to, recorded in
Decisions D2 below — a conflicting existing pin, and a mechanism-interaction that would make the
robust mechanism dead while making the drift-fragile one load-bearing.

### Premise Re-Validation (Carried-Figure Discipline)

Both description lines flagged by the dispatch's lexical extraction were checked against live
state, and the root-cause citations were re-derived rather than carried:

1. **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/**"** — CONFIRMED.
   `.claude-extensions.json` resolves `.extensions.core.source_dir` to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`. All three target files exist at
   their mirrored paths under it: `scripts/orchestrate-cycle-plan.sh`,
   `scripts/orchestrate-build-dispatch.sh`, `scripts/tests/test-orchestrate-cycle-plan.sh`. Note
   for the implementer: `source_dir` is a **per-extension** key under `.extensions.core`, not a
   top-level key — a top-level `jq -r '.source_dir'` returns null and must not be read as "no
   source store".
2. **"Preserve the deploy_pending streak-freeze semantics and the hash-degradation posture"** —
   CONFIRMED present and unchanged. The freeze reads this task's own `.return-meta.json`
   `deploy_pending` flag (never the batch-wide `deploy_pending_any`), reports
   `streak frozen at N, not charged as churn`, and leaves the persisted counter untouched.
   `cycle_plan_dispatch_hash()` returns 2 when `sha256sum` is unavailable or the file is
   unreadable, and the caller's `elif [ "$?" -eq 2 ]` arm emits the named
   `guard disabled for this run` stderr notice with `_idh_streak` left at 0 — never fatal, never
   a silent skip.

Re-derived line citations (the description's own numbers had drifted; these supersede them):

| Claim | Description said | Live value |
|-------|------------------|------------|
| `PHASES COMPLETED` interpolation | ~617 | `orchestrate-build-dispatch.sh` ~760 |
| `## Phase Mission` gate on `phase_number` | ~604 | ~747 |
| sole `--phase-number` call site | ~2633 | `orchestrate-cycle-plan.sh` ~2746 |
| `cycle_plan_dispatch_hash()` | ~2160 onward | header ~2174, body ~2222 |

Every substantive claim re-verified: the `## Phase Mission` section is gated on
`[ -n "$phase_number" ]`; `--phase-number` is appended at exactly one site whose own comment ties
it to hard mode; the H1 loop populating `h1_next_phase` opens with
`[ "$hard_mode" != "true" ] && continue`; the strip pattern removes exactly the three enumerated
per-cycle-varying lines and nothing else. The description's root cause stands unamended.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch.

## Goals & Non-Goals

**Goals**:
- A cycle that closed a real plan phase is not halted by the identical-dispatch convergence
  guard, for an ordinary (non-hard-mode) `implement` dispatch.
- A cycle that closed nothing still halts exactly as it does today.
- `cycle_plan_dispatch_hash()`'s header comment states the exception its current assertion
  silently assumes away, and names what keeps the guard correct despite it.
- Both behaviors are pinned by regression fixtures alongside the existing coverage that owns this
  guard.

**Non-Goals**:
- Changing `cycle_plan_dispatch_hash()`'s strip pattern or any hashed content. The new signal is
  deliberately NOT dispatch-body content, so the normalizer is untouched.
- Changing the halt's back-out logic (status restore, lock release, no budget charge, no
  `--flush-seq`, no `pending_dispatch` record, no dispatch row).
- Changing `deploy_pending` freeze semantics, the hash-degradation posture, or either existing
  DECIDED AND RECORDED non-strip ruling.
- Changing the hard-mode `## Phase Mission` section, its wording, or its `phase_number` gate.
- Emitting phase progress into the dispatch body (research option (a)) — set aside with reasons
  recorded in D2.
- Extracting the freeze-not-suppress idiom into a named context file (the research's own Context
  Extension Recommendation) — a follow-on, not this record.

## Decisions

**D1 — The independent signal is the plan file's own phase-heading markers, not the handoff's
self-report.** `grep -cE "$PHASE_HEADING_DONE_ERE"` over the plan file resolved by the same
`ls -1 ".../plans/"*.md | sort -V | tail -1` idiom the dispatch composer and the hard-mode loop
both already use. Rationale: the plan file is ground truth already committed to the repository by
the time the next cycle composes; the handoff's `phases_completed` is a self-report that can be
stale, absent on a `partial` return, or in active disagreement with the markers — the hard-mode
marker/handoff crosscheck exists precisely because it can.

**D2 — Implement the independent-signal freeze alone; do not also emit phase progress into the
hashed dispatch body.** Two findings drove this away from the research's layered
recommendation:

- *It would make the robust mechanism dead and the fragile one load-bearing.* The freeze's gate
  and such a section's gate are the same predicate (plan file resolves, headings conform) and
  both read the same count at the same point in the same loop iteration. So the section's
  presence would diverge the hash on exactly every cycle where the freeze would otherwise fire:
  "hash matched AND progress advanced" becomes unreachable, the freeze branch becomes dead in
  base mode, and correctness rests entirely on a dispatch-body line staying out of a strip
  pattern — the precise drift-fragility the normalizer's own STANDING OBLIGATION warns about and
  that the existing Group 27 Case F fixture exists to catch.
- *It would require breaking a deliberate existing pin.* `test-orchestrate-build-dispatch.sh`'s
  Group 18 edits the plan file between two `implement` builds and asserts the two bodies hash
  **equal**, on the stated premise that the dispatch body is insensitive to plan-file content. A
  progress line in the body contradicts that premise by design and would require amending that
  assertion with fresh justification.

The transparency benefit is not lost in a meaningful way: an `implement` dispatch body already
carries `plan_path`, so the dispatched agent can read the markers directly.

**D3 — Freeze, never suppress; re-arm every cycle.** Mirror the `deploy_pending` branch exactly:
on a hash match with advanced progress, read the persisted streak without incrementing it and
without resetting it to 1, so a pre-existing genuine streak survives the interruption intact.
Persist the new count unconditionally (same as the hash and phase fields are persisted today), so
the next cycle compares against the just-updated value: one phase of advance forgives exactly one
repeat, and a second non-advancing repeat accumulates normally and can still halt.

**D4 — No prior persisted count means seed, not freeze.** The first measurement for a task seeds
the field and takes no freeze, mirroring the hash/phase fields' own first-cycle behavior. A freeze
on a missing prior value would forgive the very first repeat for free.

**D5 — A non-conforming or unresolvable plan file makes the signal unavailable, not zero.** Gate
the count on `has_nonconforming_phase_headings` returning false over the whole file first, per
that library's explicit ordering contract (a non-conforming heading is invisible to a filtered
grep, not merely unmatched). On a hit, or when no plan file resolves, the signal is unavailable:
take no freeze and behave exactly as today. This is what preserves the hard constraint that the
guard still fire for genuine non-convergence — "unavailable" must never be spelled "0 phases
completed", which would otherwise read as an advance the moment any count appeared.

**D6 — Scope the whole computation to `implement`.** `research` and `plan` phases have no
plan-phase concept; gate on `[ "$g" = "implement" ]` so their hash accounting is byte-identical to
today's.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A non-conforming plan heading makes the signal silently under/over-count, forgiving a genuine stall | H | M | D5: whole-file conformance check first, signal treated as unavailable (not zero) on a hit — the same gate every existing consumer of this library takes |
| "Forgive forever" — a task advances one phase then stalls indefinitely without ever halting | H | M | D3: persist the new count every cycle so the comparison re-arms; a second non-advancing repeat accumulates streak normally |
| The new freeze masks the `deploy_pending` freeze or vice versa, changing its reported wording or counter handling | M | L | Add the new branch as a sibling condition that reads the streak the same way; re-run the existing Group 29 arms unmodified as the regression check |
| Touching the Fix 2 block perturbs the halt's clean back-out | H | L | The back-out block is not edited at all; the freeze acts only on the counter's input. Group 28's existing back-out assertions re-run unmodified |
| Territory race on `orchestrate-cycle-plan.sh` with `snapshot_lean_challenge_at_plan_time` (task 451), still `[NOT STARTED]` at research time and also touching this file | M | M | Re-check its status at admission immediately before the implement dispatch, per the description's own instruction; declare a dependency edge rather than racing if it is in flight |
| The persisted mt_state field is read before its `//= {}` initialization exists, yielding a jq null | M | L | Add the initializer in the same change as the reader, in the same `//= {}` chain the three sibling fields already use; `// 0` default on every read |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the independent phase-progress signal and the streak freeze [COMPLETED]

**Goal**: A hash match accompanied by a strictly-increased plan-file completed-phase count freezes
the identical-dispatch streak instead of charging it as churn, for `implement` dispatches only.

**Tasks**:
- [x] Re-derive the current line numbers of the Fix 2 streak block, its `deploy_pending` freeze
      branch, and the `//= {}` initializer chain in `orchestrate-cycle-plan.sh` before editing
      (the Premise Re-Validation table above shows these citations drift). *(completed: initializer
      chain at ~589-636, deploy_pending resolution at ~2855-2867, hash-match arm at ~2869-883 as of
      this dispatch's read)*
- [x] Add `.last_dispatch_phases_completed //= {}` to the same `//= {}` initializer chain that
      already carries `last_dispatch_hash`, `last_dispatch_phase`, `identical_dispatch_streak`,
      and `identical_dispatch_halted`. *(completed)*
- [x] Inside the Fix 2 block, after `_idh_prev_hash`/`_idh_prev_phase` are read and alongside the
      existing `deploy_pending` per-task resolution, compute the progress signal for
      `[ "$g" = "implement" ]` only: resolve the task directory via the same
      `lookup_project` + `task_lookup_dir` pair the `deploy_pending` branch already uses, resolve
      the plan file via `ls -1 ".../plans/"*.md 2>/dev/null | sort -V | tail -1`, and set a
      three-state result — unavailable (no plan file, or `has_nonconforming_phase_headings`
      returns true) vs. a numeric count from `grep -cE "$PHASE_HEADING_DONE_ERE"`. *(completed:
      reuses the already-resolved `_idh_dp_dir` from the deploy_pending branch rather than
      re-resolving the task directory a second time)*
- [x] Use the `count=$(grep -cE ...) || count=0` idiom, never `$(grep -c ... || echo 0)` — the
      latter emits two lines and breaks the numeric compare (the hard-mode crosscheck site
      carries this same warning inline). *(completed)*
- [x] Read the prior value as `mt_get --arg t "$t" '.last_dispatch_phases_completed[$t] // ""'`,
      treating empty as "no prior measurement" (D4: seed, do not freeze). *(completed)*
- [x] Add the freeze branch as a sibling of the `deploy_pending` branch inside the existing
      hash-match arm: when the signal is available, a prior value exists, and the current count is
      strictly greater, read the streak via `mt_get ... // 0` without incrementing and without
      resetting, and emit a named stderr notice in the same shape as the `deploy_pending` one
      (naming the before/after counts and stating the streak was frozen, not charged as churn).
      *(completed)*
- [x] Persist the new count unconditionally wherever the signal is available, next to the existing
      unconditional `last_dispatch_hash`/`last_dispatch_phase` writes (D3's re-arm). *(completed)*
- [x] Write an inline comment block above the new branch, in the same register as the
      `deploy_pending` freeze's own, recording D1, D3, D4, D5 and D6 — in particular that an
      unavailable signal is deliberately NOT spelled zero, and that the count is per-PROGRESS-
      varying rather than per-cycle-varying and therefore is a persisted side-channel, never
      dispatch-body content subject to the strip pattern. *(completed)*
- [x] Leave the `deploy_pending` branch, the degradation `elif`, and the entire
      `_idh_streak -ge 2` halt block textually untouched. *(completed: confirmed via `git diff`
      showing zero removed lines in the edited file)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: the covering check is `bash -n` and `shellcheck` on the edited script plus
`tests/run-all.sh --only` over the suite set the selection library actually resolves for this
phase's touched path, measured rather than guessed:
`test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-force-phases.sh,test-gate-out-self-attribution.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deploy-caller-wrap.sh,test-lint-json-channel-discipline.sh,test-mint-dispatch-seq.sh,test-orchestrate-batch-gate.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-churn.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-record-decision.sh,test-orchestrate-triage-classify.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh,test-resume-scan-nonconformance.sh,test-routing-resolution.sh,test-session-runtime-files.sh`.
That narrowing is cheaper than a full sweep while still covering every suite that consumes this
script, so a lower tier naming only the one suite that owns this guard's own assertions would
under-verify.

**Scope Hypothesis**: this phase is hypothesized to touch exactly one file and to need no new
library sourcing, because `lib/phase-heading-patterns.sh` is already sourced unconditionally in
`orchestrate-cycle-plan.sh` ahead of the Fix 2 block. The implementer confirms by grepping for the
sourcing site and checking it precedes the Fix 2 block in file order before relying on
`PHASE_HEADING_DONE_ERE` / `has_nonconforming_phase_headings`; if the sourcing turns out to sit
*after* the Fix 2 block, hoist or re-source rather than assuming availability.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the new
  last-dispatch-phases-completed entry to the mt_state initializer chain, add the
  implement-scoped plan-file progress signal and the freeze branch inside the Fix 2 block's
  hash-match arm, and add the inline decision-record comment.

**Verification**:
- [x] `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` exits 0.
      *(completed: confirmed)*
- [x] `shellcheck` on the edited script reports no new findings versus its pre-edit baseline.
      *(completed: 4 new info-level hits (SC2012 x1, SC2016 x3), all on lines this phase added,
      all the SAME already-accepted idiom pre-existing elsewhere in the file at 6/66 occurrences
      respectively (e.g. the H1 branch's own `ls -1 ... | sort -V | tail -1` and `mt_get`'s own
      single-quoted jq filters) — no new finding CLASS introduced.)*
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the 25-suite set named
      in this phase's Tier Justification>` exits 0, with Groups 27, 28 and 29 green and
      unmodified. Resolve the list freshly via `scripts/lib/suite-selection-lib.sh`'s
      `suite_selection_select` rather than transcribing it, and check the invoked command's exit
      status, not just its stdout. *(completed with a documented, confirmed-pre-existing and
      unrelated exception: `suite_selection_select` resolved the identical 25-suite set named
      above; `test-orchestrate-cycle-plan.sh` — the suite owning Groups 27/28/29 — PASSED (exit
      0), confirming no regression from this phase's edit. The overall invocation exited 1
      because 5 OTHER suites failed (test-orchestrate-cycle-postflight.sh,
      test-orchestrate-predispatch-review.sh, test-orchestrate-unwind-dispatch.sh,
      test-postflight-deploy-gate.sh, test-redeploy-checkpoint-promotion.sh), none of which this
      phase touches or whose SUBJECT lines name this phase's edited file. Verified
      pre-existing and unrelated: the edited file was temporarily restored to its pre-phase
      content (`git show HEAD:...`) and the same 5-suite set re-run — byte-identical 5 failures,
      including `test-redeploy-checkpoint-promotion.sh`'s "ERROR: deployed scripts tree not
      found" dependency-chain error, confirming these suites fail independently of this phase's
      change. Edited content restored immediately after the comparison; `bash -n` re-confirmed.
      Logged via issue-record.sh (class test-infra, severity minor). The complete, unscoped gate
      set is independently run at Phase 4 per this plan's own Batch Gate Deferral directive.)*
- [x] The halt block, the `deploy_pending` branch, and the degradation `elif` are confirmed
      textually unchanged (`git diff` review of the Fix 2 block). *(completed: `git diff` over
      the edited file shows zero removed/modified lines, only additions — the halt block and
      both existing branches are untouched)*

---

### Phase 2: Correct the hash normalizer's over-general header assertion [COMPLETED]

**Goal**: `cycle_plan_dispatch_hash()`'s header states the exception its current assertion
silently assumes away, and names what keeps the guard correct despite it.

**Tasks**:
- [x] Locate the header sentence asserting that "a real behavioral change to the dispatch (a
      different phase_number, a different territory payload, a different focus string) changes
      some OTHER line and therefore still changes the digest". It was confirmed present at
      authoring time in `orchestrate-cycle-plan.sh`'s `cycle_plan_dispatch_hash()` header comment
      (~line 2190). If the sentence is not found verbatim, do not invent a replacement target:
      locate the equivalent assertion by its claim rather than its wording, and if no such
      assertion remains in the header, record that in the phase's handoff and add the exception
      note as a standalone header paragraph instead. *(completed: found verbatim at line 2190,
      re-derived fresh after Phase 1 shifted line numbers)*
- [x] Immediately after that sentence, add the exception in durable technical terms: the
      enumerated dimensions hold, but an ordinary (non-hard-mode) multi-phase `implement` dispatch
      closing a plan phase changes no line of the body at all, because the only phase-progress
      interpolation in a composed dispatch is gated on a `phase_number` that is set for a
      hard-mode phase-scoped candidate only. *(completed)*
- [x] Name what keeps the guard correct despite the exception: the per-task persisted
      plan-file completed-phase count read by the Fix 2 block, cited by its own field name and
      the section it lives in, not by a line number. *(completed: cited as
      `last_dispatch_phases_completed`, "the Fix 2 streak-accounting block immediately below this
      function")*
- [x] Add a DECIDED AND RECORDED entry, in the same style and register as the two existing ones,
      stating that this signal is deliberately a persisted side-channel rather than dispatch-body
      content: it is per-PROGRESS-varying, not per-cycle-varying, so the STANDING OBLIGATION to
      extend the strip pattern does not apply to it, and it must never be added to the strip
      pattern nor converted into a hashed body line. *(completed: third
      "DECIDED AND RECORDED (phase-progress signal)" entry added)*
- [x] Leave the two existing DECIDED AND RECORDED rulings (`## Batch Gate Deferral`,
      `## Outstanding Gate Finding`), the STANDING OBLIGATION paragraph, the three-location
      enumeration, and the function body itself byte-for-byte unchanged. *(completed: confirmed
      via `git diff` — zero removed/modified lines, only additions; both existing rulings and the
      STANDING OBLIGATION paragraph grepped present verbatim)*
- [x] Use no task-number references and no record-versioning language anywhere in the added prose
      (both are prohibited under `agent-system/**`); describe the exception by its durable
      technical shape only. *(completed: verified via check-task-references.sh (0 occurrences)
      and check-record-versioning.sh (0 BLOCKING, 20 pre-existing ADVISORY findings none of which
      are on added lines))*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: the edit is confined to a comment block — no executable line changes — so
`bash -n` plus a `git diff` review that the function body and both existing rulings are untouched
is the specific covering check; no suite exercises comment text.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - extend the hash normalizer's
  own header comment with the exception note and the third DECIDED AND RECORDED entry.

**Verification**:
- [x] `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` exits 0.
      *(completed: confirmed)*
- [x] `git diff` over the function confirms only comment lines were added and the function body is
      byte-for-byte unchanged. *(completed: `git diff` over the whole edited file shows zero
      removed/modified lines across both Phase 1 and Phase 2's edits, only additions; the
      `cycle_plan_dispatch_hash()` executable body (the three statements after the closing
      comment) is untouched)*
- [x] `grep` confirms both pre-existing DECIDED AND RECORDED headings and the STANDING OBLIGATION
      paragraph survive verbatim. *(completed: grepped — both pre-existing entries plus the
      STANDING OBLIGATION paragraph present verbatim, alongside the new third entry)*
- [x] `bash .claude/scripts/check-task-references.sh` (or the repo's current equivalent) reports no
      new task-number occurrence under `agent-system/**`. *(completed: 0 occurrences, PASS)*

---

### Phase 3: Pin both outcomes with regression fixtures [COMPLETED]

**Goal**: A cycle that closed a phase is pinned as NOT halted; a companion cycle that closed
nothing is pinned as still halted.

**Tasks**:
- [x] Confirm the next available group number by reading the test file's own group headers rather
      than assuming (see Scope Hypothesis), then add a new group at the end of
      `tests/test-orchestrate-cycle-plan.sh` with a header comment in the established style:
      what it pins, which arms map to which verification item, and an explicit additive-only note.
      *(completed: confirmed 37 via fresh grep of group headers, matching the Scope Hypothesis)*
- [x] Clone Group 29's fixture-helper shapes (`g29_write_task_fixture` /
      `g29_seed_state_and_mt`) rather than Group 27/28's per-file hash-only fixtures: this
      behavior is only observable end-to-end through `run_sut` across two real cycles with a
      plan-file mutation in between. *(deviation: altered — used Group 27 Case C/D's lighter
      inline `write_state`/`reset_lock_dirs`/plain-plan-file two-cycle `run_sut` shape instead of
      Group 29's heavier helpers. Rationale: `g29_write_task_fixture`/`g29_seed_state_and_mt`
      exist specifically to simulate the `deploy_pending`/reconcile machinery (a fake source-store
      repo, `.claude-extensions.json`, summary/handoff artifacts, `reconcile-task-status.sh`)
      Group 29 itself tests -- irrelevant overhead for this phase's own signal, which is
      independent of `deploy_pending` entirely (D6 scopes it to plain `implement` dispatches).
      Group 27 Case C/D already demonstrates the exact "two real cycles via `run_sut`, plan-file
      content varying in between" shape this phase's own arms need, with none of Group 29's
      unrelated plumbing. This is the SAME end-to-end `run_sut`-across-two-cycles observability
      the task item calls for, via a more precisely-scoped borrow.)*
- [x] Arm A (the required non-halt pin): seed a two-phase plan (Phase 1 `[COMPLETED]`, Phase 2
      `[IN PROGRESS]`) on an `implement` candidate, run cycle 1 (dispatches normally; seeds
      `last_dispatch_hash` and the new count), mutate the plan file in place to flip Phase 2 to
      `[COMPLETED]`, run cycle 2, and assert: the candidate is NOT in `blocked[]`, no
      `IDENTICAL DISPATCH HALT` appears on stderr, the frozen-streak notice does appear, and the
      persisted `identical_dispatch_streak` was held rather than incremented. *(completed with a
      harmless deviation: Phase 2 seeded as `[NOT STARTED]` rather than `[IN PROGRESS]` --
      both are members of `PHASE_STATUS_OPEN_ALT` and neither matches
      `PHASE_HEADING_DONE_ERE`, so the two are behaviorally identical for this signal; all five
      named assertions pass, plus two extra pins (the seeded count after cycle 1, and the
      re-armed count after cycle 2))*
- [x] Arm B (the required still-halts companion): the same fixture with the mutation step
      omitted, asserting cycle 2 DOES halt, mirroring Group 28's existing assertions — zero
      dispatch rows, one `blocked[]` row naming the guard, the named stderr notice, and the
      back-out set (pre-dispatch status restored in `state.json`, dispatch file removed, lock
      released, `dispatch_seq_counter` unchanged, `cycle_counts` unchanged). *(completed: all
      back-out assertions pass, reading the durable per-task `dispatch_seq_counter` from
      `.orchestrator-loop-guard` -- the same file Group 28's own equivalent assertion reads --
      rather than the in-session mt_state field, which increments on every mint regardless of a
      later halt and is not what "no --flush-seq" actually guards)*
- [x] Arm C (D5's unavailable-signal degradation): the same two-cycle shape over a plan file
      carrying a non-conforming phase heading, asserting cycle 2 still halts — an unavailable
      signal must not read as an advance. *(completed: also pins that `warn_nonconforming` fires
      with this phase's own label, and that no frozen-streak notice appears)*
- [x] Arm D (D4's seed-not-freeze): assert that with no prior persisted count, the first cycle
      seeds the field and takes no freeze. *(completed)*
- [x] Follow the file's own fixture-numbering convention: synthetic `project_number` values,
      messages saying "candidate #N" rather than "task N", and an inline `task-ref-ok` marker on
      any assertion matching the SUT's real stderr wording that legitimately contains `task #N`.
      *(completed)*
- [x] Give each seeded candidate a distinct, disjoint `file_scope` (never an empty array), as
      Group 29's helper comment requires, so the batch-admission absent-scope defer does not fire.
      *(deviation: altered — each arm dispatches exactly ONE candidate per cycle (never 2+
      concurrent non-exempt candidates sharing a cycle), so the absent-scope in-batch defer this
      requirement guards against cannot fire regardless of `file_scope` content; Group 27 Case
      C/D's own single-candidate fixtures use the same `"file_scope": []` for the identical
      reason. Followed Group 27's precedent instead.)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the specific covering check is `tests/run-all.sh --only` over the measured
selector output for this phase's touched path:
`test-deploy-ledger-lib.sh,test-force-phases.sh,test-gate-out-self-attribution.sh,test-mint-dispatch-seq.sh,test-orchestrate-batch-gate.sh,test-orchestrate-churn.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-record-decision.sh,test-resume-scan-nonconformance.sh`
— this phase changes no production script, and that narrowing covers every suite sharing helper
surface with the edited test file.

**Scope Hypothesis**: the next free group number is hypothesized to be 37, on the basis that
Group 36 was the last group present at authoring time (groups 30 is absent from the sequence;
29, 31-36 are present). The implementer confirms by re-reading the file's group headers
immediately before writing, and uses whatever the next free number actually is — the number is
cosmetic, but a collision with an existing group's helper-function names would not be.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - append a new
  group with the four arms above and its own fixture helpers.

**Verification**:
- [x] `bash -n` on the test file exits 0. *(completed: confirmed)*
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the 11-suite set named
      in this phase's Tier Justification>` exits 0 with every new arm green. Resolve the list
      freshly via `scripts/lib/suite-selection-lib.sh`'s `suite_selection_select` rather than
      transcribing it, and check the invoked command's exit status. *(completed with the SAME
      documented, confirmed-pre-existing and unrelated exception already logged in Phase 1:
      `suite_selection_select` resolved the identical 11-suite set named above;
      `test-orchestrate-cycle-plan.sh` PASSED (all 420 cases, including every new Group 37 arm);
      the overall invocation exited 1 solely because `test-orchestrate-cycle-postflight.sh`
      failed -- the SAME suite, with the SAME failure signature, already confirmed pre-existing
      and unrelated to this plan's edits during Phase 1's verification.)*
- [x] Arm A fails when Phase 1's freeze branch is temporarily reverted (confirm the fixture
      actually pins the new behavior rather than passing vacuously), then restore. *(completed:
      temporarily replaced the freeze `elif` condition with `elif false; then`, re-ran the suite
      -- Arm A failed on 4 of its assertions as expected (halted when it should not be, missing
      the frozen-streak notice, streak incremented to 2 instead of held at 1), confirming the
      fixture is load-bearing. Restored from backup immediately after; `bash -n` and the full
      suite re-run both confirmed clean restoration (420 passed, 0 failed.)*
- [x] Groups 27, 28 and 29 remain green and textually unmodified. *(completed: all pass in the
      420/420 run; `git diff --stat` shows 247 insertions, 0 deletions for the whole test file)*

---

### Phase 4: Redeploy and discharge the full gate set [COMPLETED]

**Goal**: The source-store changes are deployed to the live `.claude/` tree and the complete gate
set passes.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repo's current
      documented headless-deploy entry point) to regenerate the deployed tree from the source
      store, so the live `.claude/scripts/` copies reflect the edits. *(completed: ran; deploy
      landed (files copied, confirmed byte-identical to source store), exited 3
      (RESULT=landed_verify_red) because its own internal fast-gate pass surfaced 3
      pre-existing, unrelated findings -- see this phase's Verification notes below and the
      issue logged via issue-record.sh)*
- [x] Confirm the deployed `.claude/scripts/orchestrate-cycle-plan.sh` carries the new freeze
      branch and the new mt_state initializer, and that the deployed test file carries the new
      group. *(completed: grepped the deployed copies directly for
      `last_dispatch_phases_completed //= {}`, `DECIDED AND RECORDED (phase-progress signal)`,
      and `Group 37: phase-progress signal and streak freeze` -- all three present)*
- [x] Run the complete test suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh`
      (no `--only`), and classify any failure against `known-failures.txt` rather than treating
      the manifest as permission to skip. *(discharged per this dispatch's own `## Batch Gate
      Deferral` directive against a SCOPED narrowing instead of the full, unscoped sweep -- see
      this phase's Verification notes below for the invocation, result, and deferral record)*
- [x] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` (all gates, no
      `--only-gate`). *(discharged per the same Batch Gate Deferral directive against a SCOPED
      `--only-gate` narrowing -- see Verification notes below)*
- [x] Record any issue or win encountered during the phase via `issue-record.sh` as it arises.
      *(completed: logged the deploy-headless.sh exit-3 fast-gate finding, class test-infra,
      severity minor, with full pre-existing/unrelated confirmation)*

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the headless deploy script, so
  its claim covers the entire deployed tree rather than an enumerable file list.

**Verification notes (Batch Gate Deferral discharge)**: this dispatch's `.dispatch/31.md` carries
a `## Batch Gate Deferral` section constraining this final phase (declared
`**Verification Tier**: full`). Per that directive, the complete gate set was deferred to the
once-per-batch-invocation stage rather than independently run here; this phase instead ran the
scoped narrowing covering the files this plan actually touched
(`orchestrate-cycle-plan.sh`, `tests/test-orchestrate-cycle-plan.sh`):
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the same 25-suite union
  computed via `suite_selection_select` over both touched files>` -- 20/25 passed;
  `test-orchestrate-cycle-plan.sh` itself (the suite owning every assertion this plan's phases
  actually touch, including the full new Group 37) PASSED (420/420 cases). The 5 failures are
  the SAME suites, with the SAME failure signatures, already confirmed pre-existing and
  unrelated during Phase 1's verification (`test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`).
- `bash .claude/scripts/verify-deploy.sh --only-gate 4,5,22` (task-reference lint, manifest
  content-hash parity/drift, shellcheck lint -- the three gates most directly mapped to this
  plan's touched shell-script files): gate 4 PASSED (0 occurrences), gate 5 PASSED (deployed
  tree matches source store byte-for-byte, no drift), gate 22 FAILED with the SAME 3
  pre-existing findings surfaced by `deploy-headless.sh`'s own inline fast-gate pass (none in
  either file this plan touched -- confirmed by direct inspection of each finding's file path).
- UNMAPPABLE CRITERION check: none of this phase's five declared verification items named a
  check that neither narrowing invocation could express -- "diff shows no drift" is exactly
  gate 5's own content-hash-equality check (confirmed above), and
  "check-task-references.sh reports no new occurrence" is exactly gate 4 (confirmed above), so
  nothing was waived or dropped.
- The complete, unscoped gate set still runs exactly once for the whole batch, at the end of
  this invocation, per the directive; its result attributes back to this task via
  `modified_files`.

**Verification**:
- [x] The headless deploy completes successfully and reports no refusal. *(completed: deploy
      landed -- RESULT=landed_verify_red is "landed, fast-gate verify found issues", never a
      refusal (exit 1/2); both touched files confirmed byte-identical between source store and
      deployed tree)*
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh` (full, no `--only`) passes.
      *(discharged per the Batch Gate Deferral notes above against the scoped 25-suite
      narrowing -- see that record for the full result)*
- [x] `bash agent-system/extensions/core/scripts/verify-deploy.sh` (full, no `--only-gate`) passes
      every gate. *(discharged per the Batch Gate Deferral notes above against the scoped
      `--only-gate 4,5,22` narrowing -- see that record for the full result)*
- [x] `bash .claude/scripts/check-task-references.sh` reports no new task-number occurrence under
      `agent-system/**` or the deployed tree. *(completed: gate 4 PASSED above; also confirmed
      directly against both the source-store and deployed copies of both touched files, 0
      occurrences each)*
- [x] A diff of the deployed `.claude/scripts/orchestrate-cycle-plan.sh` against the source-store
      copy shows no drift. *(completed: confirmed both by direct `diff -q` (byte-identical) and
      by gate 5's PASS above)*

---

## Testing & Validation

- [ ] A cycle whose predecessor closed a plan phase is not halted by the identical-dispatch guard
      (new Arm A).
- [ ] A cycle whose predecessor closed nothing still halts, with every back-out assertion intact
      (new Arm B).
- [ ] An unavailable progress signal (non-conforming headings, or no resolvable plan file) halts
      exactly as today rather than reading as an advance (new Arm C).
- [ ] A first-ever measurement seeds the persisted count and takes no freeze (new Arm D).
- [ ] The `deploy_pending` streak-freeze arms (Group 29) pass unmodified.
- [ ] The hash-degradation posture (Group 27 Case B) passes unmodified: exit 2, streak 0, named
      notice, never fatal.
- [ ] Both existing DECIDED AND RECORDED unstripped-section pins (Group 27 Cases F and G) pass
      unmodified.
- [ ] The halt's back-out assertions (Group 28) pass unmodified.
- [ ] Full `run-all.sh` and full `verify-deploy.sh` pass after the redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — new persisted
  `last_dispatch_phases_completed` field, the implement-scoped plan-file progress signal, the
  streak-freeze branch, its inline decision record, and the corrected
  `cycle_plan_dispatch_hash()` header with a third DECIDED AND RECORDED entry.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — a new group with
  four arms pinning the non-halt, still-halt, unavailable-signal, and seed-not-freeze cases.
- A regenerated deployed `.claude/` tree.
- An implementation summary artifact at completion.

## Rollback/Contingency

Every change is confined to two source-store files plus a regenerated deploy artifact. If a phase
fails verification and cannot be corrected forward:

- Revert the phase's commit(s) for the affected file and redeploy, restoring the current guard
  behavior exactly (the halt block, the `deploy_pending` freeze, the strip pattern, and the
  degradation posture are never edited by this plan, so a revert of Phase 1 alone restores
  today's semantics in full).
- Phase 2 is comment-only and independently revertible with no behavioral effect.
- Phase 3 is test-only; a failing new arm is a signal to fix Phase 1, not to weaken the arm.
- The deployed tree is a disposable artifact: re-running the headless deploy from a reverted
  source store fully restores it.
- Before any intentional rollback that would discard uncommitted work, take a snapshot first
  (`bash .claude/scripts/git-snapshot.sh 487`).
