# Implementation Plan: Task #320

- **Task**: 320 - Run the orphaned .return-meta.json validator in the lifecycle, and give it the
  partial_progress checks it lacks
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/320_return_meta_producer_side_validation/reports/01_producer_side_validation.md
- **Artifacts**: plans/01_return-meta-producer-validation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`validate-return-meta.sh` already exists, is tested, and is documented — but it has zero coverage
of the one field that destroyed a live dispatch (`partial_progress`) and zero executing call
sites anywhere in the repo. This plan closes both gaps additively: a new Check 6 inside the
validator (type-when-present plus conditional-presence, both `log_fail`), and a single
warn-only probe in `orchestrate-cycle-postflight.sh` that is gated on `partial_progress`-specific
validator output rather than the validator's aggregate exit code. Done means: a
`.return-meta.json` carrying `"status": "researched"` alongside a bare-string `partial_progress`
produces a stderr warning attributed to the writing agent plus a `RETURN_META_SCHEMA_VIOLATION`
defect record, while the dispatch completes and persists its status exactly as before.

**SOURCE STORE IS THE EDIT TARGET.** Every file below lives under
`agent-system/extensions/core/`; never hand-author under `.claude/**` (a disposable deploy
artifact — see `rules/source-store-deploy-boundary.md`). Phase 6 deploys the source-store changes
into `.claude/` so the runtime copies the postflight probe actually invokes are current.

### Research Integration

The research report settles three things this plan carries forward verbatim rather than
re-deriving:

1. **The integration point is `scripts/orchestrate-cycle-postflight.sh`, definitively — not
   `orchestrator-postflight.sh`**, which is confirmed orphaned with no live callers (its own
   header, `skill-git-workflow/SKILL.md`, and `skill-base.sh`'s inline comment all say so
   independently). There is exactly one candidate, closing the dispatch file's open question.
2. **The probe MUST gate on `partial_progress`-specific validator output, never on the
   validator's aggregate exit code.** Reacting to any `FAILED > 0` would re-fire Check 2 (status
   vocabulary) for every dispatch from an agent with an intentional non-canonical success
   vocabulary (`legal-analysis-agent`'s `"consulted"`, `slidev-assembly-agent`'s `"assembled"`,
   every `filetypes/*` vocabulary) — resurrecting the deliberately-deferred blocker recorded at
   `lint-agent-contracts.sh`'s Deferred Follow-Up items 1/2 and manufacturing continuous
   false-positive noise against agents behaving exactly as designed. This is the single most
   load-bearing constraint in the plan.
3. **The exact mechanics to copy already exist in the same file**: the "Advisory
   ARTIFACTS_SHAPE_MISMATCH probe" block supplies the advisory/unconditional posture, and the
   "RECOVERY_DECLINED" block supplies the `--dispatched-agent` attribution idiom plus the local
   `agent-system/extensions/*/agents/${agent_name}.md` glob that mirrors the recorder's own
   resolver. No new pattern is invented; an existing one is applied to a new script.

### Prior Plan Reference

No prior plan. This is artifact round 1 for this task.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, and `roadmap_flag` is not set — no
roadmap phases are added and no ROADMAP.md was consulted or modified.

## Goals & Non-Goals

**Goals**:
- `validate-return-meta.sh` enforces `partial_progress`'s two documented rules: it must be a JSON
  object with non-empty `stage` and `details` when present, and it must be absent unless `status`
  is `in_progress` or `partial`.
- The validator acquires its first executing lifecycle call site, in the one live per-task
  postflight body, warn-only.
- The warning is attributed to the agent that wrote the file, via the existing
  `--dispatched-agent` resolver, under a new `RETURN_META_SCHEMA_VIOLATION` Signal A class.
- The motivating bare-string fixture is a permanent regression test at both the unit level
  (validator) and the end-to-end level (postflight).
- The dispatch outcome is provably unaffected: `dispatch_status`, `recovered`, `have_outcome`,
  and every status-write/commit path are untouched by the new block.

**Non-Goals**:
- Softening the validator's own strict exit-code contract. Both new rules use `log_fail`; only
  the *caller's posture* is downgraded to warn-only, per the dispatch's explicit instruction.
- Widening `orchestrate-recover-outcome.sh`'s success-outcome acceptance set, or changing Check
  2's enforcement posture anywhere — that is `lint-agent-contracts.sh`'s deferred item 2 and
  stays out of scope.
- Re-hardening the consumer side. `orchestrate-recover-outcome.sh` was already fixed in
  source-store commit `27b6281fa` (it consults `.partial_progress.phases_completed` only when
  that location is an object). Do not redo it.
- Widening task 270 (jq mutation-site null-safety audit). See "Relationship to open task 270"
  below.
- Adding a fourth Detection-point registry class. `RETURN_META_SCHEMA_VIOLATION` is classified by
  analogy to the existing Class (a); formalizing a fourth class waits for a second instance.

## Relationship to open task 270

Recorded explicitly here, in a `specs/**` artifact, as the dispatch instructed — and
deliberately **not** in any file outside `specs/**`, where
`rules/no-task-references-in-deliverables.md` forbids task-number citations.

This incident is a **read-site TYPE error** (an unguarded `jq` index into a field whose type was
never validated), not a mutation-site null error. Task 270 is scoped to a re-runnable
null-safety audit of jq *mutation* sites — a different failure class in a different direction, so
this incident is not covered by 270 as currently scoped, and this task does not widen it. The
consumer half of this concern is already landed (commit `27b6281fa`), so there is no live
consumer half to split off either. **If a future audit wants the read-site type-error class
handled systematically, widening task 270 is the cleaner home for it than carving a new task out
of this one.**

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Probe reacts to the validator's aggregate exit code, resurrecting the deferred status-vocabulary blocker and flooding non-canonical-vocabulary agents with false positives | H | M | Phase 4 gates strictly on output lines matching both a `[FAIL]` marker and the literal `partial_progress`; Phase 5 adds a negative test case proving a non-canonical status alone triggers nothing |
| `log_pass` lines from Check 6 also contain the word `partial_progress`, so a naive `grep -F partial_progress` fires on a *valid* file | H | H | Filter on `[FAIL]` **and** `partial_progress` together (e.g. `grep -E '\[FAIL\].*partial_progress'`); the `[FAIL]` token appears literally in the output even with ANSI color codes around it. Phase 5's valid-file case proves silence |
| Adding the 16th enum value to `system-defect-record.sh` without updating `system-defect-discrimination.md` leaves recorder and registry out of sync — the exact drift the doc warns against | M | M | Phase 2 bundles both edits as one phase; the phase does not close until the Signal A table, the named paragraph, and the registry row all exist |
| Recorder call fails and breaks the dispatch | H | L | `system-defect-record.sh`'s header mandates non-fatal invocation (`>/dev/null 2>&1 \|\| echo "Note: ..." >&2`); Phase 4 copies the sibling blocks' invocation verbatim |
| `orchestrate-cycle-postflight.sh` is in the declared `file_scope` of eight open tasks (184, 263, 273, 279, 284, 285, 304, 315) and two siblings (316, 321) dispatch this same cycle | M | M | Re-read the file immediately before editing; stage only this task's own hunks with an explicit file list (never `git add -A`, never a directory/glob pathspec); treat a foreign modification as a sibling's in-flight edit and STOP and report per `context/contracts/territory.md` |
| `system-defect-record.sh` is not runnable from the source store (deploy-root-guard), complicating a live end-to-end test | L | M | Phase 5 asserts the `[dry-run] would record ...` line for the recorder path and asserts the WARN notice plus outcome preservation on the live path, mirroring how sibling cases in the same suite already handle this |
| The validator's probe output changes if a future edit renumbers checks | L | L | Phase 1 appends Check 6 after Check 5 — no renumbering of existing checks' comments or log lines; check order has no effect on counters or exit code |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 (phase 3); 1, 2 (phase 4) |
| 3 | 5 | 4 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add the `partial_progress` check to the validator [COMPLETED]

**Goal**: `validate-return-meta.sh` enforces `partial_progress`'s type and conditional-presence
rules, failing (exit 1) on the motivating fixture.

**Tasks**:
- [x] Append a new `# ─── Check 6: partial_progress type and conditional presence ───` block *(completed)*
      immediately after the existing Check 5 (`metadata` required sub-fields) and before the
      `# ─── Summary ───` block. Do not renumber Checks 1-5.
- [x] Rule 1 (type-when-present): if `.partial_progress` is present and non-null, it must be a *(completed)*
      JSON object (`jq -r '.partial_progress | type'`). If it is an object, `.stage` and
      `.details` must both be present and non-empty strings — mirror Check 4's
      object-field-presence idiom for `artifacts[idx]`. Each violation is a `log_fail`.
- [x] Rule 2 (conditional presence): if `.partial_progress` is present and non-null, the file's *(completed)*
      `status` must be `in_progress` or `partial`. Any other status value makes the field's mere
      presence a `log_fail`, naming both the offending status and the required repair.
- [x] Emit a single `log_pass` when the field is absent-and-not-required, or *(completed)*
      present-and-well-formed-under-a-permitted-status, matching every sibling check's
      pass-logging convention. The pass message may name the field; the caller in Phase 4
      discriminates on the `[FAIL]` marker, not on the word alone.
- [x] Use `log_fail` (never `log_warn`) for both rules: the validator's exit-code contract stays *(completed)*
      STRICT per the dispatch's explicit instruction. The warn-only downgrade lives at the call
      site only.
- [x] Extend the `--help` "Validation rules:" block with two lines describing the new rules, *(completed)*
      matching the existing bullet style.
- [x] `--fix` is NOT extended. A bare-string `partial_progress` has no unambiguous object-shaped *(completed: deliberately excluded per plan)*
      repair (its `stage`/`details` split cannot be inferred from free prose), unlike the
      bare-string artifacts case. Add a one-line comment in the new block recording this
      deliberate exclusion so a future reader does not read it as an oversight.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the new block is a single additive insertion after
Check 5 that touches no existing check's logic, comments, or log strings. Confirm at
implementation time with `git diff --stat` on the file (one file, insertions only in the Check
5→Summary gap plus the `--help` block) and by running the existing
`scripts/tests/test-validate-return-meta.sh` suite green **before** Phase 3 adds any new case —
an existing-case regression means the insertion was not additive.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-return-meta.sh` - new Check 6 block after
  Check 5; two `--help` rule lines

**Verification**:
- `bash -n` and `shellcheck` clean on the edited script.
- `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` passes with no
  new failures (pre-existing cases only at this phase).
- Ad hoc: a scratch file with `{"status":"researched","partial_progress":"Research complete; ..."}`
  plus otherwise-valid fields exits 1 and prints two `[FAIL]` lines naming `partial_progress`.
- Ad hoc: the same file with `"status":"partial"` and
  `"partial_progress":{"stage":"x","details":"y"}` exits 0 with a `[PASS]` line.

---

### Phase 2: Register `RETURN_META_SCHEMA_VIOLATION` as a Signal A instance [COMPLETED]

**Goal**: the new defect class exists in the recorder's closed enum and in the discrimination
document that owns the vocabulary, so Phase 4's recorder call cannot exit 1 on an unknown class.

**Tasks**:
- [x] Add `RETURN_META_SCHEMA_VIOLATION` to `system-defect-record.sh`'s `case "$defect_class"` *(completed)*
      enum (the line-continued alternation block), to the `--defect-class CLASS   One of: ...`
      header/usage listing, and to the invalid-class error message.
- [x] Update every "fifteen"/"fifteen-value" wording in `system-defect-record.sh` to sixteen *(completed)*
      (header comment, the enum's own `# --- Validate ... closed, fifteen-value enum ---`
      comment, and the error string).
- [x] Add a Signal A table row in `context/patterns/system-defect-discrimination.md` following *(completed)*
      the existing row style: class name, a one-clause definition (a `.return-meta.json` field
      that violates its documented type or conditional-presence rule — concretely, a
      `partial_progress` that is not an object, or that is present under a status other than
      `in_progress`/`partial`), and the computing site
      (`orchestrate-cycle-postflight.sh`'s return-meta schema probe, detecting site
      `cycle-postflight-return-meta-schema`).
- [x] Add a named paragraph recording the explicit-decision rationale, following the shape used *(completed)*
      for `RECOVERY_DECLINED`/`AMBIENT_BINDING_MISMATCH`, per the document's own contract that
      "extending the Signal A vocabulary is an explicit decision, not a silent act". State the
      motivating harm (an unguarded read-site type error discarded a complete, validated research
      report) and the attribution choice (`--dispatched-agent`, never
      `skill-orchestrate/SKILL.md`).
- [x] Add the Detection-point registry row. Classify by analogy to **Class (a)** (loud-but- *(completed)*
      unactioned: loud via stderr, with the defect record as the unactioned tail until a future
      `/meta` habit reads it). Note in one clause that no existing class exactly fits "a detector
      wired to the recorder at creation time", and that formalizing a fourth class waits for a
      second such instance rather than being invented informally here.
- [x] Update the paragraph near the `RECOVERY_DECLINED` "A fifteenth instance" sentence only if *(completed: no change needed -- the ordinal phrasing names order, not a stale cardinality claim)*
      its wording would otherwise read as a stale count claim; do not rewrite its substance.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts exactly four count-bearing wording sites need updating
(three in `system-defect-record.sh`, one "fifteenth instance" sentence in the discrimination
doc) and that no other file in the repo asserts the enum's cardinality. Confirm at implementation
time with `grep -rn "fifteen\|15-value\|fifteen-value" agent-system/extensions/` and fix whatever
that returns — the enumerated four is a hypothesis from a pre-implementation grep, not a
guarantee.

**Files to modify**:
- `agent-system/extensions/core/scripts/system-defect-record.sh` - enum `case` alternation,
  `--defect-class` usage/help text, invalid-class error message, cardinality wording
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - Signal A
  table row, named rationale paragraph, Detection-point registry row

**Verification**:
- `bash -n` and `shellcheck` clean on `system-defect-record.sh`.
- `bash .claude/scripts/system-defect-record.sh --help` (deployed copy, after Phase 6's deploy;
  pre-deploy, read the usage block) lists the new class.
- Enumerated direct dependents build/behave: the deployed recorder rejects a bogus class with
  exit 1 and accepts `RETURN_META_SCHEMA_VIOLATION` past the enum gate.
- `grep -c RETURN_META_SCHEMA_VIOLATION` returns non-zero in both edited files.
- Final pass of `grep -rn "fifteen" agent-system/extensions/` returns no stale count.

---

### Phase 3: Regression fixtures in the validator test suite [COMPLETED]

**Goal**: the motivating bare-string fixture and the boundary cases around it are permanent unit
tests.

**Tasks**:
- [x] Add an output-assertion helper alongside the existing `assert_exit` (the suite currently *(completed)*
      asserts exit codes only and leaves the captured output in `$WORKDIR/${name}.out`) — e.g.
      `assert_output_contains <name> <substring>`, reading the `.out` file `assert_exit` already
      wrote. Keep it minimal and in the suite's existing `pass`/`fail` idiom.
- [x] Case: the motivating regression — `"status": "researched"` with *(completed)*
      `"partial_progress": "Research complete; report written; metadata finalized"` plus
      otherwise-valid `artifacts`/`metadata` — asserts exit 1 **and** that both failure messages
      fire (the type violation and the conditional-presence violation), since the dispatch calls
      this out as "two violations in one field".
- [x] Case: `"status": "partial"` with a well-formed object *(completed)*
      `{"stage": "...", "details": "..."}` — asserts exit 0.
- [x] Case: `"status": "in_progress"` with an object missing `details` — asserts exit 1 and the *(completed)*
      missing-sub-field message.
- [x] Case: `"status": "implemented"` with `partial_progress` entirely absent — asserts exit 0 *(completed)*
      (the ordinary path stays green).
- [x] Reuse the suite's existing `EXISTING_PATH` fixture and `FIXTURE_REPO` isolation contract; *(completed)*
      never point a fixture at a real numbered `specs/` task directory.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts four new cases plus one helper are sufficient coverage
for the two rules. Confirm at implementation time by checking each of the two rules has at least
one failing and one passing case, and that the suite's total pass count rises by the expected
amount with zero failures.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` - output-assertion
  helper plus four new cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` exits 0 with all
  cases passing, new and pre-existing.
- Temporarily reverting Phase 1's Check 6 makes exactly the new cases fail (a sanity check that
  the tests actually bind to the new logic) — revert the revert immediately; do not commit it.

---

### Phase 4: Wire the warn-only, output-gated probe into postflight [COMPLETED]

**Goal**: the validator runs once per dispatch at postflight, warns on `partial_progress`
violations attributed to the writing agent, and changes no dispatch outcome.

**Tasks**:
- [x] **Re-read `orchestrate-cycle-postflight.sh` immediately before editing.** It is in the *(completed)*
      declared `file_scope` of eight open tasks and two siblings dispatch this same cycle on this
      shared tree.
- [x] Insert the probe block right after `notice_prefix`/`attributed_path`/`detecting_site_prefix` *(completed)*
      are set and before the WORK (a.0) stray-handoff sweep, so it runs once, early, and
      unconditionally — not duplicated inside the handoff-present and handoff-absent branches.
      `agent_name` is already in scope from argument parsing well before this point.
- [x] Guard on `[ -f "${TASK_DIR}/.return-meta.json" ]` first. A dispatch that wrote nothing at *(completed)*
      all is a separate case already handled elsewhere in this script; this probe must be silent
      for it.
- [x] Capture combined output non-fatally: *(completed)*
      `rm_validate_output=$(bash "${SCRIPT_DIR}/validate-return-meta.sh" "$rm_meta_file" 2>&1 || true)`.
      The `|| true` is mandatory under `set -e`: the validator exits 1 on any failure, including
      the status-vocabulary failures this probe must ignore.
- [x] **Filter to `partial_progress` failures only** — match lines carrying both a `[FAIL]` *(completed)*
      marker and the literal `partial_progress` (e.g. `grep -E '\[FAIL\].*partial_progress'`).
      Never branch on the validator's exit code. Add an inline comment stating *why*: an
      aggregate-exit-code trigger would re-fire Check 2 for agents with intentional
      non-canonical success vocabularies, resurrecting the deferred blocker recorded at
      `lint-agent-contracts.sh`'s Deferred Follow-Up items 1/2.
- [x] On a non-empty filtered set, log one `WARN:`-prefixed `$notice_prefix` notice to stderr *(completed)*
      naming the writing agent and the offending detail, and stating explicitly that the dispatch
      still completes — matching the wording convention of every sibling advisory block.
- [x] When `is_live`: call `system-defect-record.sh` with *(completed)*
      `--defect-class RETURN_META_SCHEMA_VIOLATION`,
      `--detecting-site "${detecting_site_prefix}:cycle-postflight-return-meta-schema"`,
      `--task "$task_number" --session "$session_id"`, the filtered detail as `--message`, and
      `--dispatched-agent "$agent_name"`. Invoke non-fatally
      (`2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2`), copying the
      RECOVERY_DECLINED block's invocation verbatim.
- [x] Append the matching `detected_defects[]` row via *(completed)*
      `skill_orchestrate_append_detected_defect`, resolving the attributed path with the same
      local `"$PROJECT_ROOT"/agent-system/extensions/*/agents/"${agent_name}.md"` nullglob the
      RECOVERY_DECLINED block uses, falling back to `$attributed_path` when unresolved.
- [x] When not `is_live`: log the `[dry-run] would record RETURN_META_SCHEMA_VIOLATION ... — no *(completed)*
      write performed.` line, matching every sibling block's dry-run contract.
- [x] Use a probe-local variable name (e.g. `rm_meta_file`) rather than reusing `meta_file`, *(completed)*
      which is computed later in the absent-handoff branch — do not disturb that hoisting.
- [x] Touch nothing else: `dispatch_status`, `recovered`, `have_outcome`, and every *(completed)*
      status-write/commit path stay untouched, so the Acceptance criterion holds by construction
      rather than by special-casing.
- [x] Extend the script's header comment block with a one-line description of the new probe, *(completed)*
      matching how the existing probes are listed there.

**Timing**: 1.0 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts (a) one insertion point suffices — because
`orchestrate-cycle-postflight.sh` is the only live per-task postflight body for both engines, and
`orchestrator-postflight.sh` is orphaned; and (b) `agent_name` is in scope at that point. Confirm
both at implementation time: re-run
`grep -rn "orchestrate-cycle-postflight.sh\|orchestrator-postflight.sh" agent-system/extensions --include=*.sh --include=*.md`
to re-establish that only the cycle script has live callers, and confirm `agent_name`'s
assignment precedes the chosen insertion line in the current file (it may have moved — eight
tasks declare this file).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - new warn-only
  return-meta schema probe plus a header-comment line

**Verification**:
- `bash -n` and `shellcheck` clean on the edited script.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes
  with no new failures (pre-existing cases only at this phase) — this is the full-tier gate for
  the orchestration critical path.
- The `--dry-run` mutates-nothing invariant case in that suite still passes.
- Manual read-through of the diff confirms zero assignments to `dispatch_status`, `recovered`, or
  `have_outcome` inside the new block.

---

### Phase 5: End-to-end acceptance test for the probe [NOT STARTED]

**Goal**: the dispatch's Acceptance criterion is a test, not a claim — including the negative
case that protects against the aggregate-exit-code regression.

**Tasks**:
- [ ] Add a `run_sut` case mirroring an existing research-phase fixture, whose
      `.return-meta.json` carries `"status": "researched"` plus the bare-string
      `"partial_progress"`. Assert: the `WARN:` notice appears on stderr naming the agent; the
      dispatch still completes; the task's status is still persisted (the exact opposite of the
      observed harm).
- [ ] Add a `--dry-run` variant of that case asserting the
      `[dry-run] would record RETURN_META_SCHEMA_VIOLATION` line, which exercises the recorder
      path without needing the recorder to run (`system-defect-record.sh` refuses to run from
      the source store under deploy-root-guard). Follow whichever idiom sibling cases in the same
      suite already use for recorder-adjacent assertions.
- [ ] **Negative case (the noise guard)**: a `.return-meta.json` with a non-canonical but
      intentional status value and NO `partial_progress` field asserts that **no** `WARN:` notice
      and **no** `RETURN_META_SCHEMA_VIOLATION` record/dry-run line is produced by the new probe.
      This is the test that would catch a future refactor regressing the probe onto the
      validator's aggregate exit code.
- [ ] Negative case: a fully well-formed `.return-meta.json` produces no probe output at all.
- [ ] Reuse the suite's existing fixture-numbering convention and scratch-repo isolation; pick an
      unused candidate number.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts four cases (two positive, two negative) cover the
Acceptance criterion plus the noise-regression guard. Confirm at implementation time that the
positive case fails if Phase 4's block is temporarily commented out, and that the first negative
case fails if the probe is switched to branch on the validator's exit code — the two
falsifiability checks that prove the cases bind to the intended behavior. Revert both
experiments; commit neither.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - four new
  cases around the return-meta schema probe

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0
  with all cases passing, new and pre-existing.
- Both falsifiability experiments above behave as predicted before being reverted.

---

### Phase 6: Inventory note, deploy, and the full gate set [NOT STARTED]

**Goal**: the docs stop describing the validator as a hand-run-only utility, the deploy tree
carries the new runtime behavior, and the whole gate set is green.

**Tasks**:
- [ ] Update the `validate-return-meta.sh` entry in
      `docs/reference/utility-scripts-inventory.md` with a clause noting it now also runs
      automatically, warn-only, at orchestrate cycle postflight for the dispatch's own
      `.return-meta.json`, in addition to remaining hand-runnable.
- [ ] Record the inclusion-criterion tension in that same entry in one clause: the inventory's
      stated scope is scripts "not invoked as part of the normal
      research/plan/implement/postflight lifecycle", which this script now partly is. **Decision:
      keep the entry** — it remains a standalone hand-run utility with a `--fix` mode that no
      lifecycle call site exercises, and annotating is the minimal, lowest-risk edit; removing it
      would lose the only reference documentation for the `--fix` mode. State the decision, not
      just the fact.
- [ ] **No task-number citations in any file outside `specs/**`.** The task-270 relationship is
      recorded in this plan and belongs in the implementation summary — never in the inventory,
      the discrimination doc, or any script comment, where
      `rules/no-task-references-in-deliverables.md` forbids it and a blocking write-time hook
      enforces it.
- [ ] Deploy the source-store changes: `bash .claude/scripts/deploy-headless.sh`. The postflight
      probe invokes `${SCRIPT_DIR}/validate-return-meta.sh` and
      `${SCRIPT_DIR}/system-defect-record.sh` from the deployed `.claude/scripts/` tree, so
      without this step the new behavior is inert at runtime.
- [ ] Confirm the deployed copies carry the changes (`grep partial_progress
      .claude/scripts/validate-return-meta.sh`; `grep RETURN_META_SCHEMA_VIOLATION
      .claude/scripts/system-defect-record.sh .claude/scripts/orchestrate-cycle-postflight.sh`).
- [ ] Run the full gate set and record the results in the implementation summary.

**Timing**: 0.5 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the relevant gate set is `shellcheck` over the three
edited scripts plus the two named test suites plus the deployed-copy greps. Confirm at
implementation time by also running whatever repo-wide lint the task's own gate convention
requires (`check-task-references.sh` in particular, given the no-task-references constraint
above) rather than treating the enumerated three as exhaustive.

**Files to modify**:
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - annotate the
  `validate-return-meta.sh` entry with its live postflight call site and the recorded
  inclusion-criterion decision

**Verification**:
- `shellcheck` clean on `validate-return-meta.sh`, `system-defect-record.sh`, and
  `orchestrate-cycle-postflight.sh`.
- Both test suites green: `test-validate-return-meta.sh` and
  `test-orchestrate-cycle-postflight.sh`.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence (no task number
  leaked into a non-`specs/**` file).
- Deploy completed and the deployed-copy greps above all hit.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` — all cases
      pass, including the four new `partial_progress` cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` —
      all cases pass, including the two positive and two negative probe cases and the unchanged
      `--dry-run` mutates-nothing invariant.
- [ ] `shellcheck` and `bash -n` clean on all three edited shell scripts.
- [ ] **Acceptance criterion, verified end to end**: a `.return-meta.json` with
      `"status": "researched"` and a bare-string `partial_progress` produces a stderr warning
      attributed to the writing agent plus a `RETURN_META_SCHEMA_VIOLATION` record, and the
      dispatch completes and persists its status.
- [ ] **Noise guard, verified end to end**: a dispatch whose `.return-meta.json` carries an
      intentional non-canonical status and no `partial_progress` produces no probe output.
- [ ] `bash .claude/scripts/check-task-references.sh` — no task-number citation outside
      `specs/**`.
- [ ] Deployed `.claude/` copies carry all three script changes.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-return-meta.sh` — Check 6 (`partial_progress`
  type + conditional presence), `--help` rules
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` — output-assertion
  helper + four cases
- `agent-system/extensions/core/scripts/system-defect-record.sh` —
  `RETURN_META_SCHEMA_VIOLATION` in the closed enum (15 → 16), usage text, error message
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — Signal A
  row, named rationale paragraph, Detection-point registry row (Class (a) by analogy)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — warn-only,
  `partial_progress`-output-gated probe with `--dispatched-agent` attribution
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — four
  end-to-end cases
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — annotated entry
- `specs/320_return_meta_producer_side_validation/summaries/01_*-summary.md` — implementation
  summary, which must state the task-270 relationship explicitly
- Deployed `.claude/` copies of the three edited scripts

## Rollback/Contingency

All six phases are additive and independently revertable; nothing here deletes or rewrites
existing logic, so a partial landing degrades to "the gap is still open", never to a broken
lifecycle.

- **Per-phase**: each phase is its own commit (per-substep commit mode throughout). Revert the
  single offending commit with `git revert <sha>`; no snapshot-then-rollback of uncommitted work
  is required or appropriate.
- **If the probe proves noisy in practice** (the primary live risk): revert Phase 4's commit
  alone. Phases 1-3 remain valuable on their own — the validator keeps its new checks and stays
  hand-runnable — and the enum addition in Phase 2 is inert without a call site.
- **If the deploy in Phase 6 misbehaves**: re-run `bash .claude/scripts/deploy-headless.sh`.
  `.claude/` is a disposable, regenerable artifact; never hand-repair it.
- **If an uncommitted working tree must be discarded** (not expected for this task): take a
  durable, non-reverting checkpoint first per `context/patterns/checkpoint-before-overflow.md`,
  and use the rollback-rung invocation shape in `context/contracts/recovery.md` — never a bare
  precautionary `git-snapshot.sh` in its default reverting mode.
- **Concurrency**: two siblings (316, 321) and eight scope-declaring tasks share this tree.
  Commit only this task's own hunks with explicit file lists. On observing a foreign commit or
  modification, STOP and report after checking `git log` — do not revert another writer's work.
