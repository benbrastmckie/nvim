# Implementation Plan: Task #258

- **Task**: 258 - Stop recording a declined return-meta recovery as HANDOFF_STALE_OR_ABSENT against skill-orchestrate
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: Task 257 (return-meta status vocabulary library) — CONFIRMED COMPLETE; `scripts/lib/return-meta-status-vocabulary.sh` exists on disk and is reusable today
- **Research Inputs**: specs/258_fix_postflight_recovery_decline_attribution/reports/01_recovery-decline-attribution.md
- **Artifacts**: plans/01_recovery-decline-attribution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-postflight.sh`'s WORK (d) branch records `HANDOFF_STALE_OR_ABSENT` against
`skill-orchestrate/SKILL.md` for every dispatch that wrote no handoff *and* whose return-meta
recovery declined — regardless of *why* recovery declined. For a research dispatch (whose agent
is contractually forbidden to write a handoff) with an out-of-vocabulary `.return-meta.json`
status, both the class and the attribution are wrong, and the message ("Skill did not write
orchestrator handoff") is actively false.

The fix reads `recover_json`'s `.reason` field — already present, never read here — to split the
branch into two shapes: **nothing usable was produced** (`META_MISSING`, `META_STALE`,
`META_UNPARSEABLE`, and the `.return-meta.json`-absent fall-through), which keeps
`HANDOFF_STALE_OR_ABSENT` attributed to the orchestrator unchanged; and **the agent wrote a
terminal marker the orchestrator could not accept** (`STATUS_IN_PROGRESS`, `STATUS_NOT_SUCCESS`,
`META_DISPATCH_SEQ_MISMATCH`), which gets a new `RECOVERY_DECLINED` class, a message built from
the already-extracted status vocabulary library, and attribution to the dispatched agent's own
source-store file via `system-defect-record.sh`'s existing `--dispatched-agent` resolver.

Research corrected two of the dispatch's own premises, and this plan is built on the corrections:
an agent-name → file resolver **already exists**, and the field to read is `.reason`, not
`.evidence_reason`. Planning turned up a third, load-bearing fact the research did not: the
fixture suite this task must not break is **already red**.

### Research Integration

Findings carried directly into the phase structure:

- **`.reason` is the discriminating field.** `evidence_reason` is hardcoded to `"NONE"` on every
  `recovered=false` emit path; `.reason` carries
  `META_MISSING|META_STALE|META_UNPARSEABLE|META_DISPATCH_SEQ_MISMATCH|STATUS_IN_PROGRESS|STATUS_NOT_SUCCESS|USAGE`.
  Phase 3 adds the `.reason` read and hoists the existing `.status` read above the record call
  (it currently sits ~20 lines *below* it, so it is not in scope where the message is built).
- **No resolver needs to be built.** `system-defect-record.sh` already accepts
  `--dispatched-agent NAME` and globs `agent-system/extensions/*/agents/NAME.md`, refusing with
  exit 3 if unresolvable. The only new glue is a 4-line local copy of the same glob for
  `skill_orchestrate_append_detected_defect`'s positional `attributed_path` argument, which has
  no resolver of its own. Verified: `--attributed-path` takes precedence over
  `--dispatched-agent` when both are passed, so the corrected record must pass **only**
  `--dispatched-agent`.
- **The vocabulary library is already the single source of truth**, exposing
  `RETURN_META_FORBIDDEN_STATUS_MESSAGE` (byte-identical to `validate-return-meta.sh:183`),
  `RETURN_META_SUCCESS_STATUSES`, and `is_return_meta_status`. Phase 3 sources it rather than
  invoking `validate-return-meta.sh` as a subprocess or hand-rolling a second message.
- **The enum has room.** Task 259 was contemplated as a collision risk but never added
  `PHASE_ACCOUNTING_MISMATCH`; the `case` arm still holds exactly the fourteen documented values.
- **Line numbers have drifted** from the dispatch's citations (`:591-612` → the branch now spans
  roughly 595-634). Every phase below locates by anchor text, never by line number.

### Planning-Stage Finding: the fixture suite is already red

Not in the research report; established during planning and **verified by execution**, because
the dispatch's "DO NOT BREAK IT" instruction cannot be honored against a baseline that is already
broken:

```
$ bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh
Results: 76 passed, 34 failed
```

Cause, isolated: task 257 made `return-meta-status-vocabulary.sh` a **hard** dependency of
`orchestrate-recover-outcome.sh` (missing → `exit 2`), but never added it to this suite's
`setup_sandbox` copy list. Every fixture that expects a successful recovery therefore gets
`recover_exit=2` → `recovered=false` → falls through into **the very WORK (d) branch this task
fixes**, and records a spurious `HANDOFF_STALE_OR_ABSENT`. Confirmed in isolation:

```
--- WITHOUT lib ---  ERROR: shared library return-meta-status-vocabulary.sh not found ... exit=2
--- WITH lib ---     {"recovered":true,"status":"researched","reason":"NONE",...} exit=0
```

Adding the lib to the two copy lists was applied to a scratch copy of the suite and run:
**110 passed, 0 failed**. This is Phase 1 — a two-line, already-proven change that must land
before any behavior edit, or fixtures (A) and (C) cannot serve as the regression guard the
dispatch designates them as.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:

- Restore the `test-orchestrate-cycle-postflight.sh` suite to green so fixtures (A) and (C)
  function as the designated regression guard.
- Discriminate the WORK (d) absent-handoff branch on `recover_json`'s `.reason`, preserving the
  existing record verbatim for the "nothing usable produced" reasons.
- For the status-shaped reasons, emit a defect whose class, attribution, and message name the
  real fault: the dispatched agent and the status it actually wrote.
- Attribute those records to the dispatched agent's own source-store file, in both the
  `events.jsonl` record and the loop-guard `detected_defects[]` row.
- Keep the branch a live signal — every path that records today still records something.

**Non-Goals**:

- Flipping `--handoff-expected false` for research dispatches. Verified: the `else` arm prints
  "handoff not expected for this dispatch; no defect recorded" and records nothing, silencing the
  branch wholesale and discarding the genuine `META_MISSING` signal. The dispatch is explicit
  that naming the fault is preferred over silencing it.
- Fixing the other five sites that share the `attributed_path` constant (see the attribution
  boundary section below).
- Changing `orchestrate-recover-outcome.sh`'s decline logic, its `reason` vocabulary, or the
  3-value success subset. This task changes how a decline is *reported*, never when one happens.
- Touching the stale-mtime or dispatch_seq-mismatch **recording sites**, which fire earlier and
  unconditionally, before this branch is reachable.

## Attribution Boundary (argued, per the dispatch's explicit requirement)

`attributed_path` is one script-wide constant (`orchestrate-cycle-postflight.sh:328`,
`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`) reused by **six** record sites.
Research enumerated all six — two more than the dispatch named. This task changes exactly one:

| # | Site (anchor) | Class | Changed? | Why |
|---|---|---|---|---|
| 1 | stray-handoff sweep (~:370) | `HANDOFF_MISLOCATED` | **No** | A handoff written to the wrong place is genuinely about handoff-writing mechanics, which the orchestrator skill owns. Attribution is correct as-is. |
| 2 | stale-handoff gate (~:401) | `HANDOFF_STALE_OR_ABSENT` | **No** | Fires unconditionally *before* this branch is reachable. The dispatch's "DO NOT DISTURB THE STALE-MTIME PATH" applies verbatim; 9 of the 10 observed records in the consumer repo are this shape and are correct. |
| 3 | dispatch_seq-mismatch gate (~:427) | `HANDOFF_STALE_OR_ABSENT` | **No** | Same: fires earlier and unconditionally, outside this branch. |
| 4 | recovered-path (~:558) | `ARTIFACTS_SHAPE_MISMATCH` | **No** | Genuinely the same misattribution shape — an agent-side artifacts defect blamed on the orchestrator. Deliberately left: it sits on the `recovered=true` path, a different precondition with different data in scope, and fixing it is a distinct change with its own regression surface. Named here so the omission is a decision, not an oversight. |
| 5 | Tier C (~:899) | `OFF_SCHEMA_STATUS` | **No** | Fires on the `have_outcome=true` / handoff-present path. Structurally separate branch; same argument as #4. |
| 6 | **WORK (d) absent-handoff (~:621)** | `HANDOFF_STALE_OR_ABSENT` | **YES** | The observed incident. This is the task's whole subject. |

The boundary is drawn at *this branch*, not at *this misattribution pattern*. Sites 4 and 5 carry
the same complaint and are legitimate follow-up work; a completed predecessor task recorded the
same complaint for site 2's sub-case and chose documentation over a fix, so the pattern of
scoping these one branch at a time is established. Widening to sites 4/5 here would put three
independently-reachable branches in one change with one shared regression suite, against a
baseline this plan is already having to repair.

## Decision: add `RECOVERY_DECLINED` rather than reuse `HANDOFF_STALE_OR_ABSENT`

The dispatch leaves this open ("Weigh the addition against enum growth for its own sake") and the
research report explicitly declines to pre-decide it. Decided here: **add one new class.**

**For:**

- `system-defect-discrimination.md` defines `HANDOFF_STALE_OR_ABSENT` as "a handoff whose mtime
  predates the dispatch window (or is otherwise absent when expected), as detected by the
  stale-handoff gate." That is handoff-shaped. A `.return-meta.json` carrying `status: completed`
  is status-shaped, and the class name would stay wrong even with a corrected message.
- Consumers filter `events.jsonl` by `defect_class`. Keeping one class while changing
  `attributed_source_path` per-row produces a class whose rows have two different owners —
  strictly worse for aggregation than either the status quo or a split.
- The two shapes now warrant genuinely different *remedies*: one points at a dead or
  context-exhausted agent; the other points at a specific line in a specific agent contract.
- Cost is bounded and pre-scouted: two files, both named in the dispatch's own FILE SCOPE NOTE,
  with the enum verified collision-free.

**Against (acknowledged):** it is the more expensive option, and enum growth is a real cost the
dispatch asks to weigh. Mitigated by adding exactly one value, not two.

**Name**: `RECOVERY_DECLINED`, not `STATUS_VOCABULARY_VIOLATION`. The branch must also cover
`STATUS_IN_PROGRESS`, and `in_progress` **is** a valid member of the 8-value enum — it is a
non-terminal marker, not a vocabulary violation. `RECOVERY_DECLINED` is accurate for every reason
routed to it; the narrower name would be false for sub-case (ii).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Regressing fixture (A)/(C), which the dispatch forbids | H | M | Phase 1 restores a verified-green baseline first; Phase 4 re-asserts both fixtures explicitly and Phase 5 gates on 0 failures. `META_MISSING` is routed to the unchanged arm by construction. |
| `--dispatched-agent` silently ignored because `--attributed-path` is also passed | H | M | Verified precedence: `if [ -n "$attributed_path_arg" ]` wins. Phase 3 passes only `--dispatched-agent` on the new path; Phase 4 asserts the resolved path in the row, which fails loudly if precedence bites. |
| New fixture cannot assert corrected attribution — the sandbox has no `agent-system/` tree, so both the recorder's glob and the local glob fail to resolve | M | H | Phase 4 creates a stub `$WORKDIR/agent-system/extensions/core/agents/general-research-agent.md`. Verified that `PROJECT_ROOT` resolves to `$WORKDIR`, so the existing glob matches it. |
| Line-number drift from the dispatch's stale citations | M | H | Every phase locates by anchor text (`# ─── WORK (d):`, `ERROR: Skill did not write orchestrator handoff`, the `case "$defect_class" in` arm), never by line number. |
| Sourcing the vocab lib hard-fails `orchestrate-cycle-postflight.sh` wherever the lib is absent — the exact failure mode Phase 1 is repairing | H | M | Mirror `orchestrate-recover-outcome.sh`'s dual-candidate resolution exactly. Phase 1 lands the sandbox copy first, so Phase 3's sourcing has a resolvable lib in every context the suite exercises. |
| Enum collision with the sibling phase-accounting task | L | L | Verified: the enum still holds exactly fourteen values; `PHASE_ACCOUNTING_MISMATCH` was never added. Admission control prevents co-dispatch regardless. Do not add a `dependencies[]` edge — it would exempt the pair from the collision scan for no gain. |
| Self-modifying task: the running `/orchestrate` cycle executes the deployed `.claude/` copy of the script being edited | M | M | Edits land in the source store only. The suite runs against the source store directly, so verification never depends on a deploy. Flagged for the deploy step, not resolved here. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | — |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(the test suite vs. the recorder + pattern doc) and have no ordering constraint between them.

---

### Phase 1: Restore the fixture suite to green [NOT STARTED]

**Goal**: Make `test-orchestrate-cycle-postflight.sh` pass at baseline so fixtures (A) and (C)
can serve as this task's regression guard. Pure repair of a predecessor's omission; no behavior
change to any production script.

**Tasks**:
- [ ] Add `return-meta-status-vocabulary.sh` to the `require_file` preflight loop over
      `$CORE_DIR/lib/` near the top of the suite
- [ ] Add the same filename to the `setup_sandbox` copy loop that populates
      `$WORKDIR/.claude/scripts/lib/`
- [ ] Run the full suite and confirm 0 failures
- [ ] Add a one-line comment at the copy loop naming why this lib is mandatory
      (`orchestrate-recover-outcome.sh` hard-fails with exit 2 without it), so the next
      lib-extraction does not silently reintroduce the same breakage

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The hypothesis is that one missing lib is the *sole* cause of all 34
failures and that adding it to both lists is the complete fix. **Already confirmed** during
planning: a scratch copy of the suite with exactly this two-site change ran 110 passed / 0
failed. The implementer should still re-run rather than assume, since Phase 1 runs against
the real file.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — add the lib
  to the `require_file` list and the `setup_sandbox` copy list (two sites, same filename)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` reports
  `Results: 110 passed, 0 failed` (exit 0)
- `git diff` shows changes confined to that one file, and only to the two loops

---

### Phase 2: Add `RECOVERY_DECLINED` to the closed enum and the pattern registry [NOT STARTED]

**Goal**: Make the new class accepted by the recorder and documented in the contract that the
recorder's own error message points readers at.

**Tasks**:
- [ ] Add `RECOVERY_DECLINED` to `system-defect-record.sh`'s `case "$defect_class" in` arm
- [ ] Update the validation error message and the usage/header text from "fourteen" to "fifteen"
      (grep the whole file — the count appears in more than one place)
- [ ] Add a Signal A table row in `system-defect-discrimination.md` defining the class: a
      dispatch whose `.return-meta.json` exists and was read but whose status could not be
      accepted as a terminal outcome, distinguished from `HANDOFF_STALE_OR_ABSENT` (which remains
      handoff-shaped)
- [ ] Add the corresponding detection-point registry row naming
      `cycle-postflight-recovery-declined` as the detecting site
- [ ] Update any count-of-classes wording in the pattern doc that says fourteen
- [ ] Take the research report's free suggestion: add a one-line pointer from the Signal B /
      attribution discussion to `system-defect-record.sh`'s `--dispatched-agent` resolver, so the
      next reader does not conclude (as this dispatch did) that no resolver exists

**Timing**: 0.7 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: Hypothesis — the enum is a single `case` arm and the literal "fourteen"
appears in a small, enumerable set of places across the two files. Confirm by
`grep -rn 'fourteen\|FOURTEEN' agent-system/extensions/core/scripts/system-defect-record.sh
agent-system/extensions/core/context/patterns/system-defect-discrimination.md` before editing,
and re-grep after to prove none survives.

**Files to modify**:
- `agent-system/extensions/core/scripts/system-defect-record.sh` — enum `case` arm, error
  message, header/usage counts
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — Signal A row,
  detection-point registry row, count wording, `--dispatched-agent` pointer

**Verification**:
- `bash agent-system/extensions/core/scripts/system-defect-record.sh --defect-class RECOVERY_DECLINED
  --detecting-site probe --dispatched-agent general-research-agent --dry-run` (or the
  equivalent no-write invocation) is accepted rather than exiting 1
- The same call with a bogus class still exits 1 with the updated message
- No occurrence of "fourteen" remains in either file

---

### Phase 3: Discriminate the WORK (d) branch on `.reason` [NOT STARTED]

**Goal**: Split the absent-handoff record into the two shapes, emitting a correctly-classed,
correctly-attributed, correctly-worded record for the status-shaped reasons while leaving the
existing record byte-identical for the rest.

**Tasks**:
- [ ] Source `lib/return-meta-status-vocabulary.sh` near the top of
      `orchestrate-cycle-postflight.sh`, copying `orchestrate-recover-outcome.sh`'s
      dual-candidate (`.claude/scripts/lib/` then
      `agent-system/extensions/core/scripts/lib/`) resolution and its hard-fail-with-exit-2
      behavior verbatim
- [ ] Inside WORK (d), read `decline_reason` from `recover_json` via `jq -r '.reason // "NONE"'`,
      guarded the same way the neighboring reads are
- [ ] Hoist the `recover_json_for_status` / `out_recovered_reported_status` read from below the
      record block to above it, leaving its existing NOTE comment attached (it documents a real
      parameter-expansion landmine). Do not duplicate the read — the later consumer reuses the
      same variable
- [ ] Add the 4-line local agent-path glob mirroring `system-defect-record.sh`'s resolver, using
      the already-computed `PROJECT_ROOT`, with `${attributed_path}` as the fallback when the
      glob does not resolve
- [ ] Split the `if [ "$handoff_expected" = "true" ]` body on `decline_reason`:
      `STATUS_IN_PROGRESS|STATUS_NOT_SUCCESS|META_DISPATCH_SEQ_MISMATCH` → the new arm; every
      other value (including `NONE` and the `USAGE`/exit-2 fall-through) → the existing arm,
      unchanged
- [ ] In the new arm, build the message from the library: when the reported status equals
      `$RETURN_META_FORBIDDEN_STATUS`, append `$RETURN_META_FORBIDDEN_STATUS_MESSAGE` verbatim;
      otherwise name the reported status and the accepted
      `${RETURN_META_SUCCESS_STATUSES[*]}` set. Phrase `STATUS_IN_PROGRESS` as a terminal write
      that never happened, not as a vocabulary violation
- [ ] Replace the stderr ERROR line on the new arm — "Skill did not write orchestrator handoff"
      is false when a `.return-meta.json` exists and was read
- [ ] Call `system-defect-record.sh` with `--defect-class RECOVERY_DECLINED`, detecting site
      `${detecting_site_prefix}:cycle-postflight-recovery-declined`, and **only**
      `--dispatched-agent "$agent_name"` — never also `--attributed-path`, which takes precedence
      and would silently defeat the fix
- [ ] Pass the locally-resolved agent path to `skill_orchestrate_append_detected_defect`'s 4th
      positional argument
- [ ] Add a `[dry-run] would record RECOVERY_DECLINED` line matching the existing dry-run idiom
- [ ] Confirm `have_outcome` stays `false` and the verdict remains `failed` on the new arm — this
      is a corrected diagnostic, not a silencing

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: Hypothesis — the change is confined to one file and one branch, with the
three-way reason routing above as the complete set. Confirm by re-locating the branch via
`grep -n 'WORK (d)'` and `grep -n 'Skill did not write orchestrator handoff'` before editing
(the dispatch's `:591-612` citation is stale), and by confirming `git diff --stat` touches
exactly one file for this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — lib sourcing block,
  and the WORK (d) absent-handoff branch only

**Verification**:
- `bash -n` parses clean; `shellcheck` introduces no new findings versus the pre-edit baseline
- The full postflight suite still reports 0 failures (fixtures A/B/C unchanged at this point,
  before Phase 4 adds any new fixture)
- A manual `--dry-run` postflight over a scratch task dir holding a fresh
  `.return-meta.json` with `"status":"completed"` prints a `would record RECOVERY_DECLINED` line,
  not `would record HANDOFF_STALE_OR_ABSENT`
- `git diff` shows the stale-handoff gate, the dispatch_seq-mismatch gate, the stray-handoff
  sweep, the recovered-path `ARTIFACTS_SHAPE_MISMATCH` site, and the Tier C site all untouched

---

### Phase 4: Extend the fixture suite across all three sub-cases [NOT STARTED]

**Goal**: Pin the new behavior and prove the old behavior survives, in the existing suite rather
than a parallel one.

**Tasks**:
- [ ] Add a sandbox helper that stubs an agent file at
      `$WORKDIR/agent-system/extensions/core/agents/<name>.md` so both the recorder's glob and
      the new local glob resolve inside the fixture tree
- [ ] Add the sub-case (iii) fixture: research phase, `--agent general-research-agent`, no
      handoff, a `.return-meta.json` with a fresh mtime, matching `dispatch_seq`, and
      `"status":"completed"`. Assert: exactly one `RECOVERY_DECLINED` row and **zero**
      `HANDOFF_STALE_OR_ABSENT` rows; `attributed_source_path` is the agent's own file, not
      `skill-orchestrate/SKILL.md`; the stderr message names the status and no longer claims the
      skill failed to write a handoff; `verdict=failed`; task status never advances
- [ ] Add the sub-case (ii) fixture: same shape with `"status":"in_progress"`. Assert the same
      class and attribution, with the terminal-write-never-happened wording
- [ ] Add explicit assertions to the sub-case (i) path that fixtures (A) and (C) still record
      exactly one `HANDOFF_STALE_OR_ABSENT` attributed to `skill-orchestrate/SKILL.md` and zero
      `RECOVERY_DECLINED` rows — the dispatch's (b) arm, made an assertion rather than an
      assumption
- [ ] Confirm the genuinely-stale-handoff fixture (the dispatch's (c) arm) still records
      `HANDOFF_STALE_OR_ABSENT` from its own earlier, unconditional gate; add the assertion if
      the existing acceptance case does not already make it
- [ ] Do not weaken fixture (A) in any way to accommodate the change

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: local

**Scope Hypothesis**: Hypothesis — two new fixtures plus assertions added to existing ones cover
the dispatch's VERIFICATION arms (a), (b), and (c), with `META_DISPATCH_SEQ_MISMATCH` already
probed directly elsewhere in the suite and not needing a new postflight fixture. Confirm by
mapping each of the three named arms to a specific `pass`/`fail` assertion line before declaring
the phase done; if an arm has no assertion, add one.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new
  fixtures and added assertions on existing fixtures

**Verification**:
- The full suite passes with 0 failures and a pass count strictly greater than Phase 1's 110
- Temporarily reverting Phase 3's edit makes the new fixtures fail (they genuinely test the
  change, not tautologies) — revert the revert immediately after

---

### Phase 5: Full regression gate and boundary confirmation [NOT STARTED]

**Goal**: Confirm the change is complete, confined, and leaves every untouched path intact.

**Tasks**:
- [ ] Run the full postflight suite; require 0 failures
- [ ] Run `test-orchestrate-cycle-plan.sh` and the recover-outcome suite if one exists, to catch
      collateral damage from the new lib sourcing
- [ ] Run `lint-agent-contracts.sh` and any defect-class or contract lint that reads the enum or
      the pattern doc
- [ ] Review `git diff` against the Attribution Boundary table above: confirm exactly one record
      site changed and the other five are byte-identical
- [ ] Confirm every edited path is under `agent-system/extensions/**` and nothing was written
      under `.claude/**`
- [ ] Confirm no task-number reference leaked into any deliverable outside `specs/**`

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: Hypothesis -- the complete change spans exactly four files (the postflight
script, the recorder, the pattern doc, and the test suite) and exactly one of the six record
sites. Confirm against `git diff --stat` for the whole task range and against the Attribution
Boundary table, rather than asserting it; if a fifth file was touched, account for it explicitly
before closing the phase.

**Files to modify**:
- None (verification only)

**Verification**:
- All suites exit 0
- `git diff --stat` lists exactly the four files this plan names, and no `.claude/**` path
- The five unchanged record sites are confirmed untouched by direct diff inspection

---

## Testing & Validation

- [ ] `test-orchestrate-cycle-postflight.sh` passes with 0 failures (baseline restored in Phase 1,
      maintained through Phase 5)
- [ ] Sub-case (iii), `STATUS_NOT_SUCCESS`: records `RECOVERY_DECLINED` attributed to the
      dispatched agent's own file, with a status-naming message
- [ ] Sub-case (ii), `STATUS_IN_PROGRESS`: same class and attribution, terminal-write wording
- [ ] Sub-case (i), `META_MISSING`: fixtures (A) and (C) record exactly one
      `HANDOFF_STALE_OR_ABSENT` attributed to `skill-orchestrate/SKILL.md`, unchanged
- [ ] The genuinely-stale-handoff path records `HANDOFF_STALE_OR_ABSENT` from its own earlier
      gate, unchanged
- [ ] `--handoff-expected false` still records zero defects (fixture (B) unchanged)
- [ ] `verdict=failed` is preserved on every arm — nothing was silenced
- [ ] `system-defect-record.sh` accepts `RECOVERY_DECLINED` and still rejects unknown classes
- [ ] All edits confined to `agent-system/extensions/**`

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — baseline
  repair plus new fixtures
- `agent-system/extensions/core/scripts/system-defect-record.sh` — fifteenth enum value
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — new class
  definition, registry row, `--dispatched-agent` pointer
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — lib sourcing and the
  discriminated WORK (d) branch
- `specs/258_fix_postflight_recovery_decline_attribution/summaries/01_*.md` — execution summary

## Rollback/Contingency

Each phase is an independent commit, so rollback is per-phase `git revert`.

- **Phase 1 is independently valuable** and should be kept even if the rest is abandoned: it
  repairs a predecessor's regression that currently masks real signal in every fixture.
- **If Phase 2's enum addition proves contentious**, the fallback is the reuse option argued
  against above: keep `HANDOFF_STALE_OR_ABSENT` and land only Phase 3's corrected message and
  attribution. This is a strictly smaller change to Phase 3's new arm (one string constant) and
  requires no revert of Phases 1, 4, or 5 beyond the asserted class name.
- **If Phase 3's lib sourcing destabilizes any caller**, the fallback is to inline the two needed
  constants at the call site with an explicit comment pointing at the library as the source of
  truth — accepting a documented duplication rather than a hard dependency. Prefer the library;
  this is a contingency, not a first choice.
- No phase writes to `events.jsonl` or any durable defect store outside the test sandbox; the
  `--dry-run` mode is available throughout for no-write checking.
