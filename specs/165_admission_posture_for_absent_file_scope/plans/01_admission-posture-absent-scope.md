# Implementation Plan: Admission posture for an absent `file_scope`, plus cross-session visibility for self-modifying candidates

- **Task**: 165 - Admission gates in orchestrate-batch-admit.sh: posture for an absent `file_scope`, then cross-session visibility for self-modifying candidates
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: None outstanding (162 formalize/harvest, 163 surface missing/empty, 245 admitted-set-only narrowing — all archived/completed)
- **Research Inputs**: `specs/165_admission_posture_for_absent_file_scope/reports/01_admission-posture-absent-scope.md`
- **Artifacts**: plans/01_admission-posture-absent-scope.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-batch-admit.sh` currently treats an absent `file_scope` as indistinguishable from a
scope that provably collides with nothing: the entry short-circuits to a bare admit before the
collision scan runs, and when it is the *other* side of a comparison, `scopes_overlap_first`
against `[]` always returns null. Two live incidents (BimodalLogic `/orchestrate 544,545`
cross-session; Logos/Verification `/orchestrate 66,70,72,76,77,81,84,85` in-batch, 8 concurrent
implementers over one tree) show the guard was never consulted rather than failing. A second,
independent defect confirmed in the same script's jq body: the self-modification branch runs
first and short-circuits, so a **solo** self-modifying candidate never reaches the
`session_active` pass and its verdict carries no cross-session collision result at all.

This plan implements the **split ruling** the research phase recommends and justifies by
measurement: cross-batch absence stays **advisory** (a new additive `absent_scope_advisory`
field, no version bump) with an explicitly recorded promotion criterion; in-batch absence becomes
**blocking** via a new, self-clearing `absent_file_scope` `defer_reason` (a genuine v5 -> v6
bump); and the self-mod cross-session gap is closed **additively only** via a
`cross_session_hazard` field that never changes the admit decision. Done when both incident
scenarios are reproduced as fixture cases, the new posture demonstrably changes their outcome, the
ruling and its reasoning live in the script's header contract alongside the existing
`defer_reason` documentation, and both edited shell scripts are shellcheck clean.

### Research Integration

Findings carried into this plan:

- **The tradeoff is settled by measurement, not preference.** The backfill mitigation has *not*
  landed uniformly: this repo 27/28 (96%), `~/Projects/Logos/Verification` 32/33 (97%), but
  `~/Projects/BimodalLogic` — the repo where the primary harm occurred — **18/43 (42%)**, with 24
  of the 25 gaps being plan-less tasks that `backfill-file-scope.sh` correctly, by design, leaves
  absent. The dispatch's instruction ("verify that mitigation actually landed before tightening;
  if backfill coverage is incomplete, prefer the softer posture and say why") therefore resolves
  to: softer posture for cross-batch, stated with that number as its reason.
- **In-batch is exempt from that reasoning entirely** — it only ever concerns candidates being
  dispatched *this cycle*, so legacy-backlog coverage is irrelevant to it, and the cost of
  wrongly serializing is extra cycles while the cost of wrongly parallelizing was (measured)
  concurrent edits to a shared gate script plus concurrent certificate-regenerating gate runs.
- **The self-exclusion key is `session_id`, not pid** (`scripts/lib/file-scope-overlap.sh`,
  `session_contention`: `select($sess.session_id != $own_sid)`). The absorbed ex-task-190
  "NOTE ON LIVENESS DETECTION" pid hypothesis does **not** apply; the defect is the precedence
  short-circuit alone. This is a confirmed negative — do not re-investigate it.
- **Version-bump precedent** (`docs/architecture/batch-admit-schema.md`, Version History): every
  prior *new `defer_reason` value* bumped the version with an explicit consumer table; purely
  additive non-decision-changing fields (`idle_overlap_advisory`, the tie-breaker/`--phase-map`
  change) deliberately did not. This plan follows both halves of that precedent.

**Two corrections to the research report's consumer list, established live and binding on this
plan:**

1. `scripts/orchestrate-dry-run-report.sh` **does not exist** — it was retired and absorbed into
   `scripts/orchestrate-cycle-plan.sh` (both its live and `--dry-run` paths; see that file's
   "`--dry-run` design" header note). Do not attempt to edit it.
2. `skills/skill-orchestrate/SKILL.md` **no longer branches on `defer_reason`** (it carries no
   `defer_reason` text at all); that logic now lives in `orchestrate-cycle-plan.sh`. The
   executing consumer to update is therefore `orchestrate-cycle-plan.sh`'s `case "$dr" in` block,
   not SKILL.md.

The executing consumer's `case "$dr" in` block has **no `*)` default arm**, so an unrecognized
`defer_reason` produces a task that is excluded from dispatch (`admit_decision` stays `defer`)
with **no `defer_ledger` entry and no warning** — silent exclusion. That is a real visibility
defect this plan must close in the same change set that introduces the new value.
`orchestrate-predispatch-review.sh`, by contrast, is `select()`-based per class and is inert (not
mis-bucketing) against an unrecognized value, matching the v4 precedent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- Record the ruling and its reasoning — including the explicit tradeoff statement and the
  coverage measurement that decided it — in `orchestrate-batch-admit.sh`'s header contract,
  alongside the existing `defer_reason` documentation.
- Record the promotion criterion at which cross-batch absence should become blocking, mirroring
  plan-format.md's Verification Tier advisory-first precedent and reusing
  `validate-state.sh --strict`'s Check 10 zero-finding state as the measurement.
- Surface cross-batch absence on the verdict itself via a new additive `absent_scope_advisory`
  field (no version bump), so the hazard is visible to callers, not only in the independently
  computed `orchestrate-predispatch-review.sh` Class F report.
- Make in-batch absence blocking via a new `absent_file_scope` `defer_reason` with its own payload
  fields and override semantics documented to the same standard as the existing three, converging
  via the same designated-candidate tie-breaker `self_modifying` already uses.
- Close the self-mod cross-session blindness additively: a `cross_session_hazard` field on a
  self-modifying **admit** verdict when a live foreign session's covered scope overlaps the
  candidate — never a decision change.
- Reproduce both observed incident scenarios as fixture cases that are red against the current
  script and green after.

**Non-Goals**:

- Making cross-batch absence blocking in this change set. That is the deliberate ruling, with a
  written promotion criterion — not a deferral.
- Making a solo self-modifying candidate **defer**. Explicitly forbidden by the absorbed
  ex-task-190 MUST NOT (it would mean zero dispatch on every solo self-modifying run).
- Changing the collision predicate itself, or any existing verdict field's shape or presence
  rule. `scripts/lib/file-scope-overlap.sh` is consumed, never modified.
- Adding a held-lock scan (already rejected on record in the script header).
- Running the state.json collision scan inside the self-mod branch. Only `session_contention` is
  run there (see Phase 4's recorded residual).
- Fixing `plan-file-scope-harvest.sh`'s `## Territory Contract`-table parsing gap (BimodalLogic
  #410). Recorded by research as a residual for a different task; it is evidence here, not scope.
- Backfilling any repository's `file_scope` data as part of this task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `scripts/orchestrate-cycle-plan.sh` is in the declared `file_scope` of two concurrent sibling tasks dispatched this same cycle | H | H | Phase 5 re-reads the file immediately before editing, stages only its own hunks (never a directory/glob `git add`), and treats a foreign modification or foreign commit as a sibling's in-flight edit — STOP and report per `context/contracts/territory.md`. This plan's own **Files to modify** lists become this task's harvested `file_scope`, so the guard this task strengthens will itself serialize 165 against those siblings at implement time. |
| A new `defer_reason` silently excludes a task from dispatch with no ledger entry (the `case` block has no default arm) | H | Certain without the fix | Phase 5 adds the `absent_file_scope` arm **and** a loud `*)` default arm, so any future unrecognized value warns instead of vanishing. |
| Blocking in-batch absence stalls a batch of several plan-less legacy tasks | M | M | Designated-candidate convergence (lowest task number admits) means one extra cycle per absent-scope candidate beyond the first — identical in cost to today's `self_modifying` tie-breaker, never a permanent block. No override flag is needed because the real remedy (declare a `file_scope`) is a one-line state edit. |
| A research/plan dispatch of an absent-scope candidate defers as a pure false positive (it writes only its own `reports/`/`plans/` subtree) | M | H | Phase 3 applies the existing `--phase-map` `research`/`plan` exemption to the new branch, for exactly the D-phase rationale already recorded in the header. Requires lifting the `$phase_group` lookup above the absent-scope early-exit branch — see Phase 3's implementation note. |
| Fixture assertions pinned to the `$schema` literal break mid-plan when the version bumps | M | H | Phase 1 asserts on `decision`/`defer_reason`/field presence only; exactly one dedicated schema-literal case exists and Phase 3 updates it in the same commit as the bump. |
| Edits land in the deployed `.claude/**` tree and are silently wiped | H | L | Every edit targets `agent-system/extensions/core/` per the dispatch's binding canonical-source constraint and `rules/source-store-deploy-boundary.md`. The fixture suite runs directly from the source store (`SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."`), so no deploy is needed to verify. |
| An advisory field duplicates `orchestrate-predispatch-review.sh` Class F's existing finding | L | M | Class F is retained and its header narrative gains a cross-reference: Class F computes absence independently from state.json; `absent_scope_advisory` is the same fact carried on the verdict. Deliberate overlap, documented — the same posture Class F already takes toward Class B. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is **fully sequential by
construction**: Phases 2-4 all edit different branches of the same jq program inside
`scripts/orchestrate-batch-admit.sh`, so grouping any of them into a shared wave would invite
concurrent edits to one file in one working tree — exactly the hazard this task exists to close.

---

### Phase 1: Red-baseline fixtures for both defects [COMPLETED]

**Goal**: Reproduce both observed incident scenarios, plus the cross-batch advisory gap, as
fixture cases in the existing isolated-temp-root harness, and record their red output against the
unmodified script.

**Tasks**:
- [x] Read `scripts/tests/test-orchestrate-batch-admit.sh` in full; reuse its existing `$TMPROOT`
      builder, `pass`/`fail`/`info` counter idiom, and `cleanup` trap rather than adding a second
      harness. It already copies `orchestrate-batch-admit.sh`, `deploy-root-guard.sh`,
      `task-lock.sh`, and `lib/{file-scope-overlap,common,task-lookup-lib}.sh` byte-for-byte.
      *(completed)*
- [x] Add case **IN-BATCH-ABSENCE**: a state.json fixture with 8 non-terminal tasks, every one of
      them with `file_scope` absent (mix the three sub-states: key missing, literal `null`, `[]`).
      Invoke with all 8 positional candidates and `--invocation-count 8`. Assert the *current*
      behavior loudly — all 8 `decision: "admit"`, zero `defer` — and mark the case as the
      expected red baseline. This is the Logos/Verification 8-task incident.
      *(deviation: altered — written against the standard TDD red/green convention instead:
      asserts the TARGET post-fix shape (1 admit + 7 `absent_file_scope` defers) rather than
      today's literal behavior, so it fails now and flips to pass once Phase 3 lands, matching
      Phase 2's and Phase 3's own Verification sections which both require this case to "remain
      red" until Phase 3 — a literal "assert today's admit-all" version would pass immediately
      and contradict those two sections)*
- [x] Add case **CROSS-BATCH-ABSENCE**: one absent-scope candidate, one out-of-batch task with
      status `implementing` holding a broad scope (`FormalSystem/`, `Tests/`, `docs/`, `typst/`,
      `README.md`). Assert the current bare admit carries **no** `absent_scope_advisory`. This is
      the BimodalLogic cross-batch incident. *(deviation: altered — same red/green rationale as
      IN-BATCH-ABSENCE above: asserts the TARGET shape (admit + `absent_scope_advisory.scope_state
      == "missing_key"`) so it fails now and flips to pass in Phase 2, matching that phase's
      Verification section)*
- [x] Add case **SOLO-SELF-MOD-CROSS-SESSION**: two live registered sessions whose covered scopes
      overlap on at least one orchestrator-critical path, registered via the copied
      `task-lock.sh session-register` (keep both pids alive so `session_liveness` reports
      `pid-alive`). Run the candidate solo (`--invocation-count 1`) with `--session-id` set to the
      *other* session's id. Assert the current verdict is `{"decision":"admit","self_modifying":true}`
      with **no** `cross_session_hazard` field. This is the absorbed cross-session-blindness probe.
      *(deviation: altered — same red/green rationale: asserts the TARGET shape
      (`cross_session_hazard` naming the foreign session) so it fails now and flips to pass in
      Phase 4, matching that phase's "FAILED count is zero for the first time" Verification line;
      also the probe is described without a task-number citation per
      `rules/no-task-references-in-deliverables.md`, since this script is a deliverable outside
      `specs/**`)*
- [x] Add case **PHASE-EXEMPT-ABSENCE**: an absent-scope candidate in a multi-candidate batch,
      mapped via `--phase-map <n>:plan`. Assert it admits (this case must stay green across every
      later phase — it is the false-positive guard). *(completed)*
- [x] Add exactly ONE case pinning the `$schema` string literal (`orchestrate-batch-admit-v5`
      today). Every other new assertion reads `decision`, `defer_reason`, and field presence only
      — never the literal. *(completed)*
- [x] Run the suite from the source store and record the red output verbatim in the phase
      completion note, per this suite's own documented convention. *(completed: see Phase
      Completion Note below — 5 passed, 3 failed, matching the three red-baseline cases)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the harness already copies all six helper scripts the new
cases need and that no seventh is required. Confirm at implementation time by reading the live
`REQUIRED_SCRIPTS` array and the `$TMPROOT` build block before writing any case; if the
two-session case needs a helper the array omits, add it to `REQUIRED_SCRIPTS` (preserving the
loud-skip discipline) rather than sourcing it out of band.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - add five fixture
  cases and extend the header comment to name both defects this suite now covers

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` runs to
  completion and reports a nonzero FAILED count attributable **only** to the four new
  red-baseline cases; every pre-existing case still PASSes.
- `shellcheck agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` clean
  (Class B, `set -uo pipefail`, per `context/standards/shell-strict-mode.md` — do not add `-e`).

**Phase Completion Note**: Verbatim red-baseline run (3 failed, matching the three red-baseline
cases; `PHASE-EXEMPT-ABSENCE` and `SCHEMA-LITERAL` pass immediately as designed — they are not
red baselines, so the FAILED count this run produced is 3, not the "four" the Verification
section above estimated; corrected against the more precise, mutually-consistent per-phase
progression Phases 2-4 each specify (CROSS-BATCH-ABSENCE flips in Phase 2; IN-BATCH-ABSENCE
flips in Phase 3; SOLO-SELF-MOD-CROSS-SESSION flips in Phase 4, at which point FAILED reaches
zero) — recorded as a plan-text imprecision, not a scope deviation):

```
[PASS] 1: A admits, C defers on A (in_batch), D admits despite overlapping only the deferring C
[PASS] 2: NDJSON emission preserves caller-argument order for out-of-ascending-order arguments (D C A B)
[PASS] 3: a self_modifying-caused defer also keeps a lower-numbered in-batch peer out of the admitted set
[FAIL] IN-BATCH-ABSENCE: target-posture assertion failed -- EXPECTED until Phase 3 lands the absent_file_scope defer_reason
[FAIL] CROSS-BATCH-ABSENCE: target-posture assertion failed -- EXPECTED until Phase 2 lands the absent_scope_advisory field
[FAIL] SOLO-SELF-MOD-CROSS-SESSION: target-posture assertion failed -- EXPECTED until Phase 4 lands the cross_session_hazard field
[PASS] PHASE-EXEMPT-ABSENCE: an absent-scope candidate mapped to the plan phase group still admits (forward-looking false-positive guard)
[PASS] SCHEMA-LITERAL: $schema reads orchestrate-batch-admit-v5 (will be bumped to v6 in a later phase)

Results: 5 passed, 3 failed
```

`shellcheck` result: clean except pre-existing `SC2329` (info) on the `cleanup()` trap function,
confirmed present identically against the unmodified pre-task file (`git show HEAD:...`) — not
introduced by this phase's edits.

---

### Phase 2: Record the ruling, and surface cross-batch absence advisorily [COMPLETED]

**Goal**: Write the ruling, its tradeoff, its measured justification, and its promotion criterion
into the script's header contract, and emit the new additive `absent_scope_advisory` field on the
absent-scope admit branch. No version bump (additive-field precedent).

**Tasks**:
- [x] Add a header section — sited immediately after the existing `defer_reason` field
      documentation in the verdict-schema block, so the ruling sits with the contract it governs —
      recording: (a) the decision, split by scope kind; (b) the tradeoff verbatim (closing the
      silent-passage hole vs. blocking legitimate legacy work); (c) the measured coverage that
      decided it (this repo 27/28, a second deployment repository 32/33, the third (where the
      harm was observed live) 18/43, measured 2026-09-29) and the re-derivation command; (d) why
      in-batch is exempt from that reasoning. *(deviation: altered — named the deployment
      repositories generically ("this repository" / "a second deployment repository" / "the
      third deployment repository") rather than citing their proper names verbatim: this script
      ships broadly via the extension system to unrelated repositories, and baking a specific
      external project's name into shared, committed infrastructure documentation is a durability
      and portability concern the rest of this header already avoids — it describes "the
      repositories this system deploys into" generically throughout. The numeric measurements and
      their 2026-09-29 date are preserved exactly)*
- [x] Record the promotion criterion in that section, in `validate-state.sh` Check 10's own
      idiom: promote cross-batch absence from `absent_scope_advisory` to a blocking
      `absent_file_scope` defer once `bash .claude/scripts/validate-state.sh --strict` reports
      zero Check 10 `missing_key`/`null_value` findings across the repositories this system
      deploys into. State explicitly that this version does NOT perform that promotion, mirroring
      Check 10's own "This task does NOT perform the promotion" wording. *(completed)*
- [x] Document the new `absent_scope_advisory` field in the verdict-schema field list, modelled
      field-for-field on `idle_overlap_advisory`'s existing entry (presence rule, nested keys,
      and the branches on which it is structurally absent). *(completed)*
- [x] In the jq body, extend the absent-scope early-exit branch
      (`elif (($entry.file_scope // []) | length) == 0 then`) to attach `absent_scope_advisory`
      with nested keys: `scope_state` (`"missing_key"` | `"null_value"` | `"empty_array"` —
      reuse Check 10's vocabulary verbatim, do not invent a third spelling), `codispatch_count`
      (int, `$inv_count`), and `reason` (machine-templated; names the remedy: declare a
      `file_scope`, or run `plan-file-scope-harvest.sh` / `backfill-file-scope.sh` once a plan
      exists). Distinguish the three sub-states by testing `has("file_scope")` and
      `.file_scope == null` on `$entry` before the `// []` coalesce erases the difference.
      *(completed)*
- [x] Leave the branch's `decision: "admit"` and `self_modifying` values byte-identical. The only
      change to any existing verdict is the added field. *(completed)*
- [x] Flip fixture case **CROSS-BATCH-ABSENCE** from red baseline to a positive assertion:
      `decision == "admit"` AND `absent_scope_advisory.scope_state` matches the fixture's
      sub-state AND no `defer_reason` present. *(completed: this case was already written
      against this exact target shape in Phase 1 per that phase's own deviation note — it needed
      no further text change here, only the implementation above to make it pass)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the absent-scope early-exit branch is the sole site where
a known, non-terminal, empty-scope candidate is resolved (the unknown-task and terminal-status
branches precede it and are unaffected). Confirm at implementation time by re-reading the four-arm
`if/elif/elif/else` chain in the jq body before editing, and verify the terminal-status arm is
untouched by running the existing terminal-candidate fixture case.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - header ruling section,
  promotion criterion, `absent_scope_advisory` field documentation, and the jq absent-scope branch
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - flip
  CROSS-BATCH-ABSENCE to a positive assertion

**Verification**:
- The suite's CROSS-BATCH-ABSENCE case PASSes; IN-BATCH-ABSENCE and SOLO-SELF-MOD-CROSS-SESSION
  remain red (not yet implemented); every pre-existing case still PASSes.
- `jq` parse of the embedded program still succeeds (a successful non-degraded run of any fixture
  case proves this; a jq syntax error aborts with exit 2 and no verdicts).
- The `$schema`-literal case still reads `orchestrate-batch-admit-v5` — this phase does not bump.
- `shellcheck agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` clean.

**Phase Completion Note**: Full suite result after this phase's edits: 6 passed, 2 failed
(IN-BATCH-ABSENCE and SOLO-SELF-MOD-CROSS-SESSION remain red exactly as this Verification section
requires; CROSS-BATCH-ABSENCE flipped to PASS; every pre-existing case and PHASE-EXEMPT-ABSENCE/
SCHEMA-LITERAL still PASS). One mid-phase bug found and fixed: an apostrophe in a jq-embedded
comment (`validate-state.sh's Check 10`) terminated the enclosing bash single-quoted jq program
early, producing a jq syntax error; reworded to avoid the apostrophe (`validate-state.sh Check
10`). `shellcheck` result: identical to the pre-task baseline (only pre-existing SC1091 info
lines on the three `source`/`.` lines, confirmed via `git show HEAD:...` diff).

---

### Phase 3: Blocking in-batch absence — new `absent_file_scope` defer_reason, v5 -> v6 [NOT STARTED]

**Goal**: Make in-batch absence blocking via a new `defer_reason` with its own payload fields and
documented override semantics, converging through a designated-candidate tie-breaker, and bump the
verdict schema to v6 with the matching Version History entry.

**Tasks**:
- [ ] Compute an invocation-level `$designated_absent_candidate`: the LOWEST task number among
      this cycle's candidates that is known, non-terminal, and has an absent/empty `file_scope`.
      Model it directly on the existing `$designated_sm_candidate` computation (same
      ascending-first-match determinism, same `null`-when-none result, computed once over the full
      `$cands` set outside the fold).
- [ ] Lift the `$phase_group` lookup (`($phase_map[($c|tostring)] // null)`) so it is in scope at
      the absent-scope branch, not only inside the final `else`. Apply the same unconditional
      `research`/`plan` exemption the self-mod branch already applies, for the identical D-phase
      rationale — a research or plan dispatch touches only the task's own `reports/`/`plans/`
      subtree. Record that rationale inline.
- [ ] In the absent-scope branch, defer with `defer_reason: "absent_file_scope"` when ALL hold:
      `$inv_count > 1`, the candidate is not `$designated_absent_candidate`, and the candidate is
      not phase-exempt. Otherwise admit (carrying Phase 2's advisory). Attach
      `absent_scope_advisory` to the defer verdict too, so the advisory is never lost by deferring.
- [ ] Payload fields for the new reason: `designated_absent_candidate` (int, the peer that admits
      this cycle) and `reason` (machine-templated; states this is a one-cycle ORDERING constraint
      that self-clears, names the real remedy — declare a `file_scope` — and never instructs the
      operator to isolate the dispatch).
- [ ] Document in the header, to the same standard as the existing three reasons: the new value's
      payload fields; that `colliding_task_number`, `colliding_task_status`, `overlapping_path`,
      `collision_scope`, and `corroborated_by` are **deliberately absent** because there is no
      colliding task and no overlapping path — this is missing information, not a detected
      conflict, so forcing it into `file_scope_collision`'s shape would leave those fields
      present-but-empty and violate the schema's existing "present only when..." discipline; and
      its **override semantics**: NO override flag, sitting alongside `file_scope_collision` and
      `session_active` rather than `self_modifying`, because the defer self-clears next cycle
      (tie-breaker convergence) and the remedy is a one-line `file_scope` declaration, not a
      bypass.
- [ ] Extend the header's Precedence block: the absent-scope branch resolves BEFORE the
      self-modification check (it already does, structurally — an empty scope can match no
      critical path), so `absent_file_scope` and `self_modifying` are mutually exclusive by
      construction. State that explicitly rather than leaving it to be inferred.
- [ ] Bump every `$schema` literal from `orchestrate-batch-admit-v5` to `orchestrate-batch-admit-v6`
      in this script, and add the new value to the header's `defer_reason` enumeration.
- [ ] Add the v5 -> v6 Version History entry to `docs/architecture/batch-admit-schema.md` with the
      explicit consumer table every prior `defer_reason` addition carried (naming
      `orchestrate-cycle-plan.sh` and `orchestrate-predispatch-review.sh`, and recording that
      `orchestrate-dry-run-report.sh` is retired and `SKILL.md` no longer branches on
      `defer_reason`). Update the doc's `**Status**` line, Complete JSON Schema, and Field
      Definitions for the new reason and both new additive fields.
- [ ] Flip fixture case **IN-BATCH-ABSENCE** to positive: exactly one admit (the lowest-numbered
      candidate, named as `designated_absent_candidate` on each of the other seven), seven defers
      with `defer_reason == "absent_file_scope"`, and **no** `colliding_task_number` /
      `overlapping_path` / `collision_scope` / `corroborated_by` on any of them.
- [ ] Update the single `$schema`-literal fixture case to v6. Confirm **PHASE-EXEMPT-ABSENCE**
      still admits.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: this phase asserts (a) `orchestrate-batch-admit-v5` occurs 11 times in
`scripts/orchestrate-batch-admit.sh` and (b) the literal also occurs in
`context/patterns/file-footprint-overlap.md` (1), `context/patterns/batch-orchestration-guardrails.md`
(2), `docs/architecture/batch-admit-schema.md` (7), `scripts/test-conflict-predicate.sh` (2), and
`scripts/test-four-tier-conflict.sh` (3). Re-derive both counts at implementation time with
`grep -rc 'orchestrate-batch-admit-v5' agent-system/extensions/core/` before editing. Only the
script, the schema doc, and any test that *pins* the literal need updating — a doc sentence that
merely narrates history keeps its v5 reference. Decide per occurrence; do not blanket-sed the
repository.

**Commit-mode note**: `atomic-batch` is declared here because the version bump and the new
`defer_reason` cannot be split into independently-green sub-steps — a script emitting v6 while the
schema doc still documents v5, or a new reason with no consumer arm, is an expected-red
intermediate state. The batch is exactly the four files listed below; it MUST NOT be widened
retroactively.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - designated-absent
  computation, phase-group lift, new defer branch, header docs, v6 literals
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - v5 -> v6 Version
  History entry with consumer table, Status line, Complete JSON Schema, Field Definitions
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - flip
  IN-BATCH-ABSENCE positive, bump the schema-literal case
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - update only if it *pins* the
  `$schema` literal in an assertion (confirm by reading; leave narrative mentions alone)
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` - same conditional basis as
  the previous entry

**Verification**:
- IN-BATCH-ABSENCE, CROSS-BATCH-ABSENCE, PHASE-EXEMPT-ABSENCE, and the schema-literal case all
  PASS; every pre-existing case still PASSes; SOLO-SELF-MOD-CROSS-SESSION remains the only red.
- `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` and
  `bash agent-system/extensions/core/scripts/test-four-tier-conflict.sh` both PASS.
- A single-candidate invocation of an absent-scope task still admits (`$inv_count == 1` never
  defers) — assert this as its own case, not by inspection.
- `shellcheck` clean on every `.sh` touched.

---

### Phase 4: Cross-session hazard on self-modifying admit verdicts [NOT STARTED]

**Goal**: Close the absorbed ex-task-190 defect additively — a solo (or phase-exempt, or
designated) self-modifying candidate's admit verdict names a live foreign session's overlapping
scope, without ever changing the admit decision.

**Tasks**:
- [ ] Run `session_contention($c_scope; $c; $own_sid; $all; $sess_list)` inside the
      `$sm_flag == true` arm and attach `cross_session_hazard` when it returns non-null, on ALL
      THREE self-mod admit branches: phase-exempt, tie-break-winner, and solo/`$inv_count <= 1`.
      All five arguments are already in scope at that point (`$c_scope` is bound before the
      `$sm_flag` test; the other four are invocation-level) — no new plumbing.
- [ ] Nested keys, mirroring the existing `session_active` defer payload so the two are diffable:
      `session_id`, `colliding_task_number`, `overlapping_path`, `session_liveness_reason`, and
      `reason` (machine-templated, naming the concurrent-write hazard and the remedy).
- [ ] Do NOT attach it to the `self_modifying` **defer** branch — that verdict already carries its
      own reason and remedy, and adding a second hazard there would suggest the defer is caused by
      the session overlap when it is not.
- [ ] Do NOT change any decision. Assert this as an explicit fixture case: the same two-session
      fixture must still yield `decision: "admit"`.
- [ ] Document the field in the header verdict-schema list and in
      `docs/architecture/batch-admit-schema.md`'s Field Definitions, including its presence rule
      and the branches on which it is structurally absent. Extend the header's Precedence (D4)
      block to record that the self-mod short-circuit now carries the session-registry result
      **advisorily** even though it still bypasses the `session_active` *defer* pass — the precise
      gap ex-task-190 identified, and the precise reason the fix is additive rather than a
      precedence change.
- [ ] Record as a documented residual, in the same header note: the state.json collision scan is
      deliberately NOT run inside the self-mod branch (only `session_contention` is), because the
      in_batch half of that scan depends on the admitted-set fold accumulator and running it out
      of order would produce an order-sensitive advisory. The session registry alone satisfies the
      acceptance criterion this fix answers.
- [ ] Flip fixture case **SOLO-SELF-MOD-CROSS-SESSION** to positive: `decision == "admit"`,
      `self_modifying == true`, `cross_session_hazard.session_id` equals the foreign session's id,
      `cross_session_hazard.overlapping_path` is the overlapping path, and no `defer_reason`.
- [ ] Add a negative case: two live sessions whose covered scopes do **not** overlap -> no
      `cross_session_hazard` field at all (absent, not null).
- [ ] Add a degradation case: `--session-id` omitted -> the existing loud stderr line fires and no
      `cross_session_hazard` can appear (D6 behavior unchanged).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts `session_contention`'s five arguments are all in lexical
scope at each of the three self-mod admit branches, and that it returns an object carrying
`session_id`, `covered_task_number`, `overlapping_path`, and `liveness_reason`. Confirm by reading
`scripts/lib/file-scope-overlap.sh`'s `session_contention` definition and the jq `as`-binding
chain above the `$sm_flag` test before writing the branch; if a key name differs, use the live
name rather than renaming the library function's output.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - `cross_session_hazard` on
  the three self-mod admit branches, header field docs, D4 Precedence note, residual note
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - Field Definitions entry
  and Precedence section note for `cross_session_hazard`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - flip
  SOLO-SELF-MOD-CROSS-SESSION positive, add the non-overlap and `--session-id`-omitted cases

**Verification**:
- Every fixture case PASSes; FAILED count is zero for the first time in this plan.
- `scripts/lib/file-scope-overlap.sh` is unmodified (`git status --short` shows it absent from the
  change set).
- `shellcheck agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` clean.

---

### Phase 5: Consumer updates — executing gate and predispatch review [NOT STARTED]

**Goal**: Make the new `defer_reason` and both new advisory fields visible to the two live
consumers, and close the silent-exclusion gap in the executing gate's closed `case` block.

**Tasks**:
- [ ] **Territory precondition, before touching `orchestrate-cycle-plan.sh`**: re-read the file
      immediately beforehand and run `git log --oneline -5 -- <that path>`. Two concurrent sibling
      tasks declare it in their `file_scope`. If a foreign commit or a foreign uncommitted
      modification is present, STOP and report it rather than proceeding — per
      `context/contracts/territory.md`'s Cross-Task Territory section and this dispatch's
      concurrency note.
- [ ] In `orchestrate-cycle-plan.sh`'s `case "$dr" in` block, add an `absent_file_scope)` arm
      appending a `defer_ledger` entry (`collision_scope: null`, `detail` from `admit_reason`),
      matching the three existing arms' shape exactly.
- [ ] Add a loud `*)` default arm to the same `case`: warn to stderr naming the unrecognized
      `defer_reason` and still append a `defer_ledger` entry, so no future value can silently
      exclude a task with no record. Note inline that this closes a pre-existing gap, not one
      introduced by the new value.
- [ ] Add ledger capture for both new advisory fields, modelled on the existing
      `idle_overlap_ledger` block immediately above: an `absent_scope_ledger` entry when
      `absent_scope_advisory` is present, and a `cross_session_hazard_ledger` entry when
      `cross_session_hazard` is present. Confirm the target metadata document's array fields exist
      or add them alongside `idle_overlap_ledger`'s, following that field's own precedent.
- [ ] Add no `--allow-absent-file-scope` bypass flag. The two existing bypasses
      (`--allow-self-modifying`, `--allow-scope-collision`) stay untouched; record inline why the
      new reason gets none (Phase 3's override-semantics ruling).
- [ ] In `orchestrate-predispatch-review.sh`, add a new class (next unused letter — confirm live;
      A/B/C/C-admitted/D/D-admitted/E/F/G are taken) re-presenting
      `decision == "defer" and defer_reason == "absent_file_scope"` verdicts, following the
      `select()`-based convention of Classes C/D/E and adding no new diagnosis of its own.
- [ ] Add a companion admitted-side selector for `absent_scope_advisory` and one for
      `cross_session_hazard`, modelled on the existing `Class C-admitted` / `Class D-admitted`
      pattern, so an admitted hazard is rendered rather than inert.
- [ ] Extend Class F's existing header comment to cross-reference the new verdict-carried
      advisory: Class F computes absence independently from state.json; `absent_scope_advisory`
      is the same fact carried on the verdict. Deliberate overlap, documented — the same posture
      Class F already takes toward Class B. Class F stays report-only and is NOT made
      admission-relevant here.
- [ ] Update this script's header class inventory and its `Read by` / consumer prose so the class
      list matches the code.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the live consumer set is exactly two files —
`scripts/orchestrate-cycle-plan.sh` (the executing gate, both live and `--dry-run` paths, one
`case` block) and `scripts/orchestrate-predispatch-review.sh` (the report composer) — with
`orchestrate-dry-run-report.sh` retired and `skills/skill-orchestrate/SKILL.md` carrying no
`defer_reason` branch. Re-confirm at implementation time with
`grep -rn 'defer_reason' agent-system/extensions/core/ --include=*.sh --include=*.md` before
editing; if a third live branching consumer appears, add it to this phase rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - `absent_file_scope` case arm,
  loud `*)` default arm, advisory ledger capture
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - new defer class, two
  admitted-side selectors, Class F cross-reference, header class inventory

**Verification**:
- `bash agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh --dry-run` over a
  multi-task candidate set including at least one absent-scope task renders the new defer with a
  `defer_ledger` entry, and the run exits cleanly.
- `bash agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` over the same
  candidate set prints the new class with the expected finding, and prints an explicit
  zero-findings negative when no candidate lacks a scope (not a silent blank).
- A verdict carrying a deliberately unknown `defer_reason` (inject via a stub) produces the loud
  default-arm warning AND a `defer_ledger` entry — assert, do not inspect.
- `shellcheck` clean on both files.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` still fully
  green (no regression from consumer edits).

---

### Phase 6: Pattern-doc sync and full gate [NOT STARTED]

**Goal**: Land the ruling in the narrative documentation the header points at, and run the
complete gate set.

**Tasks**:
- [ ] Extend `context/patterns/batch-orchestration-guardrails.md` with the absent-scope posture: a
      subsection alongside the existing "Self-Modification Hazard: The Fourth Admission Dimension"
      recording the split ruling, both observed incidents as the motivating evidence, the measured
      coverage that justified the cross-batch softness, and the promotion criterion. Keep the
      script header as the authoritative contract and this document as the narrative — cross-link,
      do not duplicate the field tables.
- [ ] Reconcile the two existing `orchestrate-batch-admit-v5` mentions in that file per Phase 3's
      per-occurrence rule (bump a current-version claim; leave a historical narration).
- [ ] Verify `context/patterns/file-footprint-overlap.md`'s consumer list still reads correctly
      (this task adds no new consumer of the overlap predicate — `session_contention` was already
      consumed; update only if its v5 mention is a current-version claim).
- [ ] Confirm no deliverable outside `specs/**` gained a task-number reference
      (`rules/no-task-references-in-deliverables.md`): run
      `bash .claude/scripts/check-task-references.sh` and, in the new prose, cite the incidents by
      repository and command (`/orchestrate 544,545` in BimodalLogic) rather than by task number.
- [ ] Run the full gate set and record results in the phase completion note.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - absent-scope
  posture subsection, ruling, promotion criterion, v5 mention reconciliation
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - conditional: only if
  its v5 mention is a current-version claim rather than history

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` fully green.
- `shellcheck` clean on all four `.sh` files this plan touched, honoring each file's existing
  strict-mode class per `context/standards/shell-strict-mode.md` (test suites are Class B — do not
  add `-e`).
- `bash .claude/scripts/check-task-references.sh` reports no new findings.
- After a deploy, `bash .claude/scripts/tests/run-all.sh` green (the suite is auto-discovered by
  the `tests/test-*.sh` glob, so no registration step is needed). Run the deploy only once no
  sibling task is mid-edit in this tree; if a sibling is live, record the source-store suite result
  as the gate and note the deferred deploy verification explicitly rather than skipping silently.

---

## Testing & Validation

- [ ] The Logos/Verification 8-task in-batch incident, as a fixture: 1 admit + 7
      `absent_file_scope` defers, replacing today's 8 admits.
- [ ] The BimodalLogic `/orchestrate 544,545` cross-batch incident, as a fixture: still admits
      (the deliberate ruling) but now carries `absent_scope_advisory` naming the sub-state and
      the remedy, replacing today's silent bare admit.
- [ ] The ex-task-190 two-session probe, as a fixture: a solo self-modifying candidate still
      admits and now carries `cross_session_hazard` naming the foreign session and the overlapping
      path.
- [ ] Non-regression: a single absent-scope candidate invoked alone still admits; a phase-exempt
      (`research`/`plan`) absent-scope candidate in a multi-task batch still admits; a terminal or
      unknown candidate's verdict is byte-identical to pre-change output apart from the `$schema`
      literal.
- [ ] Field discipline: an `absent_file_scope` defer carries no `colliding_task_number`,
      `colliding_task_status`, `overlapping_path`, `collision_scope`, or `corroborated_by`.
- [ ] Consumer visibility: the new defer produces a `defer_ledger` entry and a rendered
      predispatch-review class; an unknown `defer_reason` produces a loud warning plus a ledger
      entry rather than silent exclusion.
- [ ] `shellcheck` clean per `context/standards/shell-strict-mode.md` on every edited `.sh`.
- [ ] `bash .claude/scripts/tests/run-all.sh` green after deploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — v6 verdict schema, the
  recorded ruling and promotion criterion, `absent_file_scope` defer_reason,
  `absent_scope_advisory` and `cross_session_hazard` additive fields
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` — fixture coverage
  for both observed incidents plus non-regression and degradation cases
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — v5 -> v6 Version
  History entry with consumer table, updated field definitions
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — new case arm, loud default
  arm, advisory ledger capture
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — new defer class and
  two admitted-side selectors
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — absent-scope
  posture narrative
- `specs/165_admission_posture_for_absent_file_scope/summaries/01_admission-posture-absent-scope-summary.md`
  — execution summary (implement phase)

## Rollback/Contingency

Every phase is independently revertible and committed per-substep (except Phase 3's declared
`atomic-batch`), so the cheapest contingency is `git revert` of the offending phase commit — no
working-tree rollback needed. Phases 1-2 and 4 are additive-only: reverting them restores exactly
today's behavior. Phase 3 is the only decision-changing phase; reverting it leaves the ruling and
the advisory in place with absence non-blocking, which is itself a defensible (softer) end state
consistent with this plan's own recorded posture.

If the in-batch posture proves too strict in practice, the correct de-escalation is to gate the
new defer on `$inv_count` exceeding a threshold, or to reduce it to advisory-only by emitting
`absent_scope_advisory` on the in-batch branch as well — not to revert the header ruling, which
must record whatever posture is live.

If a rollback of uncommitted work becomes necessary (a phase abandoned mid-edit), take a snapshot
first per `context/contracts/recovery.md`'s rollback rung, using its documented invocation shape
including the out-of-scope override flag for the deliberate whole-tree case. Do not emit a bare
default-mode `git-snapshot.sh` as a routine start-of-phase checkpoint; a defensive checkpoint
before risky work uses `--no-revert`.

**Concurrency contingency**: if a sibling task commits to
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` while Phase 5 is in flight, do
not merge or overwrite. Stop, report the foreign commit, and re-plan Phase 5 against the new
content — the collision this task exists to prevent must not be committed by this task.
