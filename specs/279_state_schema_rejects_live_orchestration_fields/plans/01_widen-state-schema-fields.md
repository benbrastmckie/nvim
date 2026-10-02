# Implementation Plan: Task #279

- **Task**: 279 - Reconcile state-schema.json with the live fields the orchestrator reads: rule per field (widen, migrate, or retire), and fix the blockers reader/comment contradiction
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: None (coordinates with tasks 269 and 271 on shared files — see Risks)
- **Research Inputs**: specs/279_state_schema_rejects_live_orchestration_fields/reports/01_state-schema-field-ruling.md
- **Artifacts**: plans/01_widen-state-schema-fields.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase has already produced the substantive ruling: five of the eight disputed fields
are WIDEN (`active_goal` top-level; `blockers`, `previous_status`, `resume_phase`, `researched` at
entry level) and three top-level fields are RETIRE (`artifacts`, `metadata`, `last_updated`), each
with a named writer/reader or an explicit no-information-loss argument. This plan therefore does
not re-litigate the ruling — it applies it, in the order the dependencies force: the schema and the
validator's hand-copied known-field arrays must move together in one phase (there is no drift test
for the pair), then the posture change, the reader/comment correction, and the migration tool can
proceed in parallel, with documentation and the full acceptance sweep closing.

Two things the plan adds beyond the research report. First, the schema/validator pair is **already
drifted today**, independently of this task: `research_questions` is modelled in
`state-schema.json`'s `definitions.projectEntry` but absent from `validate-state.sh`'s
`KNOWN_ENTRY_FIELDS`, so any repo whose planner has returned a `needs_research` verdict would hit
the same unexplained FAIL. It is latent here (this repo has zero carriers) but it is the identical
defect class, so Phase 1 closes it and Phase 3's new drift test pins it shut. Second, the promotion
criterion the research deliberately left open is set concretely in Phase 2 rather than left as an
open-ended loosening.

### Research Integration

Every ruling, type choice, and citation below comes from the research report and was spot-verified
against the source store while building this plan:

- The five WIDEN / three RETIRE split, and the per-field writer/reader evidence, are taken verbatim
  from the report's Decisions section (items 1-8).
- `blockers` normalizes to **array of strings** (report Decision 5): a strict superset of the
  scalar shape three of four live consumer entries use, already used by the fourth, and it lets the
  `orchestrate-cycle-postflight.sh` reader be fixed rather than deleted.
- The postflight contradiction resolves **in the reader's favour** — the reader at `:1273` is
  load-bearing, the sibling comment at `:1276-1277` ("never written by any script") is the party
  that is factually wrong. Re-verified in place while planning.
- `previous_status` has a live **writer** the dispatch had not found: `/spawn`'s preflight status
  update (`skills/skill-spawn/SKILL.md:85-111`). `active_goal` likewise has a live writer in
  `commands/review.md:790-838`. Both are markdown-embedded `state-write.sh` calls, which is why a
  `*.sh`-only grep missed them.
- The advisory-first posture has an in-script precedent: Checks 8-11 of `validate-state.sh` are
  already WARN-by-default with a `--strict` promotion and a written PROMOTION CRITERION comment
  block. Phase 2 copies that shape rather than inventing one.
- Verified while planning: `state-schema.json` sets `additionalProperties: false` at both the top
  level and on `definitions.projectEntry`; top-level properties count 10, `projectEntry` properties
  count 21; `validate-state.sh`'s `KNOWN_TOP_LEVEL_FIELDS` (10 entries) matches the schema, while
  `KNOWN_ENTRY_FIELDS` carries only 20 of the 21.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:

- Apply the eight-field ruling to `context/schemas/state-schema.json` and to
  `scripts/validate-state.sh`'s two hand-maintained known-field arrays, in lockstep.
- Resolve the `orchestrate-cycle-postflight.sh` reader-vs-comment contradiction in the reader's
  favour, and settle `blockers` on one shape (array of strings) with a transitional dual-shape
  tolerant reader.
- Move `validate-state.sh` Checks 3 and 4 to an advisory-first posture (WARN by default, `--strict`
  enforcing) with a concrete, written promotion criterion.
- Ship a runnable, idempotent migration script a consumer repo owner can invoke themselves, which
  prints every value it drops as the written no-loss record.
- Record every widened field's writer and reader, and every retired field's last known value, in
  `context/reference/state-management-schema.md`, so the no-information-loss constraint is
  satisfied inside the deliverable and not only inside `specs/`.
- Pin the ruling with validator tests, including a new schema-to-validator drift assertion so this
  class of failure cannot recur silently.

**Non-Goals**:

- `parent_task` — owned by task 271's work item (1). Not touched here.
- Any write to `~/Projects/BimodalLogic`. That repo is the evidence, not the edit target; running
  the migration there is its owner's separate action.
- Redesigning the resume mechanism. `resume_phase` is admitted to the schema as legacy/secondary to
  the live `continuation_context` mechanism; reconciling the two is a separate concern.
- Any hand-authored edit under `.claude/**` (disposable deploy artifact) — the source store under
  `agent-system/extensions/core/` is the sole edit target.
- Changing `additionalProperties: false` in the JSON Schema file itself. Draft-07 has no "warn"
  severity; the advisory split lives in the validator, and Phase 6 documents that divergence so a
  future reader does not "fix" it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Task 269 is dispatched this same cycle onto `validate-state.sh` AND `test-validate-state.sh`** — direct two-file overlap with Phases 1, 2, 3 | H | H | Re-read both files immediately before every edit; stage only this task's own hunks with an explicit file list (never a directory or glob `git add`); if 269's one-line null-safety fix is already present, build on it rather than reverting it. Never run `git-snapshot.sh` in reverting default mode. |
| Task 271 also declares `state-schema.json` (and `validate-state.sh`) and will add `parent_task` to `definitions.projectEntry` | M | M | If 271 lands first, re-derive the widening against the already-declared `parent_task` shape instead of the shape recorded here; the five added properties are additive and do not conflict. |
| `orchestrate-cycle-postflight.sh` overlaps tasks 184, 263, 273 and the `nothing_to_land` task | M | M | Phase 4's edit is ~30 lines around `:1265-1285`, far from the worktree-landing block near `:836`. Re-read the file before editing; if a foreign uncommitted modification or foreign commit is visible, STOP and report rather than proceeding. |
| Retiring three top-level fields reads as data destruction to a future auditor who never finds the research report | M | M | The last known values are written in **two** independent places: the migration script's own stdout at run time (Phase 5) and a "Retired Top-Level Fields" subsection in `state-management-schema.md` (Phase 6). |
| The retired-`artifacts` record quotes a legacy consumer path containing a task-number-shaped directory name, which `validate-no-task-references.sh` may block | L | M | Record the value as quoted data. If the write-time gate blocks it, apply the documented `task-ref-ok` marker with an explicit reason (quoted legacy data value, not a task citation) per `context/standards/task-reference-exemptions.md`. |
| Moving Checks 3/4 to WARN is mistaken for loosening validation everywhere | M | L | Scope the change to Checks 3/4 only; leave `--strict` a hard-fail opt-in unchanged; write the promotion criterion down in Check 10's own comment style (Phase 2). |
| The transitional dual-shape `blockers` reader outlives the migration and silently permits new scalar values forever | M | M | Phase 3 adds a fixture pair: scalar-string `blockers` accepted in default mode, and a `--strict` case that makes the transitional tolerance test-visible rather than invisible. |
| Widening `resume_phase`/`researched` with no live reader looks like modelling dead fields | L | M | The per-field no-loss rationale is written into the schema `description` and the reference doc, so a future removal proposal has a concrete bar to clear. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4, 5 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 6 | 1, 2, 4, 5 |
| 5 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Note that Phases 1, 2 and 3 all touch
`validate-state.sh` or `test-validate-state.sh`, which task 269 also owns this cycle — the
serialization above is within this task; the cross-task discipline is in Risks.

---

### Phase 1: Apply the ruling to the schema and the validator's known-field arrays [COMPLETED]

**Goal**: The five WIDEN fields are modelled in `state-schema.json` and accepted by
`validate-state.sh`, the three RETIRE fields remain unmodelled deliberately, and the pre-existing
`research_questions` drift between the two files is closed. Both files move in one phase because
there is no drift test protecting the pair (Phase 3 adds one).

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/schemas/state-schema.json` and
      `agent-system/extensions/core/scripts/validate-state.sh` immediately before editing (task 269
      may have already modified the validator this cycle). *(completed)*
- [x] Add to `properties` (top level): `active_goal`, `type: ["string", "null"]`, description naming
      `commands/review.md`'s goal-selection step as the live writer. *(deviation: altered — already
      present in the schema and validator, settled by hand 2026-09-30 per the two-field note in the
      dispatch; re-verified in place, `type: "string"` not `["string","null"]`, left as-is)*
- [x] Add to `definitions.projectEntry.properties`:
  - [x] `blockers`: `{"type": "array", "items": {"type": "string"}}`, description naming the
        free-text human/session-authored convention (no canonical script writer) and the reader at
        `scripts/orchestrate-cycle-postflight.sh`'s blocked-verdict branch. *(completed)*
  - [x] `previous_status`: `{"$ref": "#/definitions/taskStatus"}`, description naming `/spawn`'s
        preflight update as writer and `orchestrate-triage-classify.sh`'s blocked-task discharge
        routing as reader; mark explicitly load-bearing, not bookkeeping. *(completed)*
  - [x] `resume_phase`: `{"type": "integer", "minimum": 1}`, description marking it legacy/secondary
        to the live `continuation_context` resume mechanism, retained for no-information-loss.
        *(completed)*
  - [x] `researched`: `{"type": "string"}`, description stating it is an **ISO8601 phase-completion
        timestamp**, explicitly disambiguated from the `status: "researched"` enum value, and noting
        it has no current writer or reader and is retained because `last_updated` overwrites.
        *(completed)*
- [x] Add the same five names to `validate-state.sh`'s `KNOWN_TOP_LEVEL_FIELDS` (1 name) and
      `KNOWN_ENTRY_FIELDS` (4 names). *(deviation: altered — `active_goal` was already present in
      `KNOWN_TOP_LEVEL_FIELDS`; only the 4 entry names were newly added)*
- [x] Add the missing `research_questions` to `KNOWN_ENTRY_FIELDS` — pre-existing drift, modelled in
      the schema since the research-questions feature landed but never mirrored into the validator.
      *(completed)*
- [x] Deliberately do NOT add `artifacts`, `metadata`, or top-level `last_updated`; add a short
      comment above `KNOWN_TOP_LEVEL_FIELDS` naming those three as ruled-retired so a future editor
      does not "helpfully" re-admit them. *(completed)*
- [x] Confirm `additionalProperties: false` is left in place at both levels (unchanged by design).
      *(completed — verified via `jq` after edit: both still `false`)*
- [x] Commit (schema + validator together, explicit two-file `git add`). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly **2 files**, **6 new names** in the validator
arrays (5 ruled + 1 drift fix), **1 new top-level schema property** and **4 new `projectEntry`
properties**, against a verified pre-edit baseline of 10 top-level / 21 entry schema properties and
10 / 20 validator names. Confirm at implementation time with
`jq -r '.properties | keys | length' …` and `jq -r '.definitions.projectEntry.properties | keys | length' …`
before and after, and by diffing the two validator arrays against the corresponding `jq` key lists.
If the baseline counts differ (task 271 landed first), re-derive rather than assuming these numbers.

**Files to modify**:

- `agent-system/extensions/core/context/schemas/state-schema.json` - add 1 top-level and 4
  `projectEntry` properties with descriptions carrying writer/reader provenance
- `agent-system/extensions/core/scripts/validate-state.sh` - add 6 names across the two
  known-field arrays; add the ruled-retired comment

**Verification**:

- `jq empty` on the schema passes; the new key lists match the intended sets exactly.
- A local fixture `state.json` carrying all five widened fields (with `blockers` as an array and
  `previous_status` as a valid enum value) produces zero Check 3/Check 4 FAIL lines.
- A fixture carrying `research_questions` on an entry produces no Check 4 FAIL (regression proof for
  the drift fix).
- `bash .claude/scripts/validate-state.sh` on this repo's own `specs/state.json` still reports
  0 failures.
- `shellcheck` clean on `validate-state.sh` per `context/standards/shell-strict-mode.md`.

---

### Phase 2: Move Checks 3 and 4 to an advisory-first posture [COMPLETED]

**Goal**: An unknown top-level or entry field WARNs by default and FAILs only under `--strict`, so
schema drift produces actionable advisory signal instead of an instant unexplained RED gate — with a
concrete promotion criterion recorded, not an open-ended loosening.

**Tasks**:

- [x] Re-read `validate-state.sh` (Phase 1 and possibly task 269 have both touched it). *(completed)*
- [x] Change Check 3's unknown-field loop from `log_fail` to `log_warn`, and Check 4's likewise.
      *(completed)*
- [x] Extend each WARN message so it names the actionable next step (model the field in
      `state-schema.json` and mirror it into the matching known-field array, or run the migration
      shipped in Phase 5), rather than only reporting the field name. *(completed)*
- [x] Add a PROMOTION CRITERION comment block to each check in the exact style of Check 10's
      existing block, recording the concrete bar: **promote Checks 3 and 4 back to FAIL once (i) the
      Phase 5 migration has been run in every consumer repo the maintainer runs `validate-state.sh`
      in, and (ii) two consecutive schema additions have landed with their validator known-field
      counterpart in the same commit** — i.e. once the drift test from Phase 3 has demonstrably held
      the pair in sync twice. Until both hold, unknown fields stay advisory. *(completed)*
- [x] Update `validate-state.sh`'s header comment block (the `--strict` paragraph and the per-check
      summary) so Checks 3 and 4 are listed among the WARN-level checks `--strict` promotes,
      alongside 8-11. *(completed; exact line numbers had shifted from the plan's 28-39/95-120
      estimate, re-located by content as instructed)*
- [x] Verify no existing caller passes `--strict` so no caller's behaviour changes silently; record
      that re-check in the commit message. *(completed — grep -rn 'validate-state.sh'
      agent-system/extensions/core | grep -- --strict returns nothing outside the script's own
      header comment)*
- [x] Commit. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts **1 file** and **exactly 2 checks** changed in severity, with **0**
callers affected because none passes `--strict`. Confirm the caller claim at implementation time by
grepping every invocation of `validate-state.sh` across `agent-system/extensions/core/` for
`--strict` rather than trusting the script's own header.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - Checks 3/4 severity, message text,
  two PROMOTION CRITERION blocks, header comment updates

**Verification**:

- A fixture carrying a genuinely unknown field exits **0** with a WARN line in default mode, and
  exits **1** with that warning promoted under `--strict`.
- The WARN message names the field and the remediation.
- Summary counters move from the `Failed` to the `Warnings` column for that fixture.
- `shellcheck` clean.

---

### Phase 3: Validator test coverage pinning the ruling, plus a schema-to-validator drift test [COMPLETED]

**Goal**: A future schema edit cannot silently re-reject a modelled field, and cannot re-introduce
the `research_questions`-class drift, because the test suite asserts both the ruling and the
schema/validator pair's agreement.

**Tasks**:

- [x] Re-read `test-validate-state.sh` (task 269 also owns this file this cycle). *(completed)*
- [x] Add a positive fixture carrying all five widened fields with realistic values — `active_goal`
      a goal string, `blockers` an array of strings, `previous_status` a valid `taskStatus` enum
      value written the way `/spawn` writes it, `resume_phase` an integer, `researched` an ISO8601
      timestamp — asserting exit 0 with no Check 3/Check 4 finding of any severity. *(completed)*
- [x] Add a fixture carrying a legacy **scalar-string** `blockers` value, asserting it is accepted
      in default mode (transitional tolerance) — this is the test that makes the tolerance visible
      and gives its eventual removal a named signal. *(completed)*
- [x] Add a fixture carrying `research_questions` on an entry, asserting no Check 4 finding
      (regression guard for the Phase 1 drift fix). *(completed)*
- [x] Add a negative fixture asserting the three retired top-level fields (`artifacts`, `metadata`,
      top-level `last_updated`) still produce an **unknown-field WARN** (not silence, and not FAIL)
      — the guard against re-admitting them as "known". *(completed; also added a --strict
      companion proving the WARN promotes to exit-blocking)*
- [x] Add the **drift test**: enumerate `state-schema.json`'s top-level `properties` keys and
      `definitions.projectEntry.properties` keys with `jq`, extract `KNOWN_TOP_LEVEL_FIELDS` and
      `KNOWN_ENTRY_FIELDS` from `validate-state.sh`, and assert set equality in both directions,
      reporting each offending name. Model it on `test-status-vocabulary.sh`'s existing drift
      assertion for the status enum, which is the in-repo precedent for exactly this pattern.
      *(completed)*
- [x] Follow the suite's existing source-store-first validator-resolution precedent (grep the
      candidate for the new check identifiers before trusting it) so a stale deployed copy cannot
      produce a false green. *(completed — WIDEN_VALIDATOR greps for "resume_phase" and the Check 3
      advisory WARN message text)*
- [x] Run the full suite; confirm all pre-existing cases still pass. *(completed — 35 passed, 0
      failed; one PRE-EXISTING fixture, "stray top-level field -> nonzero exit", asserted Check 3's
      now-superseded hard-FAIL behavior from before Phase 2's posture change landed. Updated it to
      assert the new default-mode WARN + exit 0, with a new companion case asserting the original
      nonzero-exit expectation still holds under `--strict`, preserving the fixture's original
      detection intent)*
- [x] Sanity-checked the drift test by temporarily removing `blockers` from `KNOWN_ENTRY_FIELDS`:
      the test correctly FAILed and named `blockers` as the offending field; restored afterward and
      the suite returned to 35/35 passing. *(completed; this step was implicit in the Verification
      section below, called out here for traceability)*
- [x] Commit. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts **1 file** and **5 new fixtures/cases** added on top of the suite's
existing cases (positive fixture plus four seeded-defect fixtures plus the D5/Check 8-11 groups).
Confirm the pre-edit case count by running the suite and reading its PASSED total before adding
anything, rather than assuming the count recorded here.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - five new cases including
  the schema-to-validator drift assertion

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with every new
  case reporting PASS and no pre-existing case regressing.
- Sanity-check the drift test by temporarily removing one name from `KNOWN_ENTRY_FIELDS` and
  confirming the test FAILs and names that field; restore it.
- `shellcheck` clean.

---

### Phase 4: Resolve the postflight blockers reader-vs-comment contradiction [COMPLETED]

**Goal**: The blocked-verdict branch renders an array-shaped `blockers` value correctly instead of
emitting raw JSON, and the sibling branch's comment no longer asserts a falsehood about the field.

**Tasks**:

- [x] Re-read `orchestrate-cycle-postflight.sh` around lines 1255-1295 — four other active tasks
      declare this file. *(completed; lines had shifted slightly to ~1302-1330, re-located by
      content)*
- [x] Fix the reader in the `verdict == "blocked"` branch so it tolerates both shapes through the
      migration window and converges on array-only afterwards:
      `(.blockers // ["Unspecified blocker"]) | if type == "array" then join("; ") else . end`.
      *(completed; verified standalone against scalar-string, array, and absent inputs — all three
      render correctly with no raw JSON)*
- [x] Correct the `else`-branch comment: delete the false claim that
      `.active_projects[].blockers` is never written by any script. Replace it with the accurate
      statement — the field is a free-text, human/session-authored annotation with no canonical
      script writer, it **is** populated in practice, and it is consumed by the `verdict ==
      "blocked"` branch immediately above; the `partial + blockers[]` branch derives its description
      from the handoff's own object-shaped `blockers[]` array, which is a different document and a
      different field, and that distinction is why this branch does not read the entry field.
      *(completed)*
- [x] Leave the `partial_with_blockers` handoff-derived logic itself unchanged — only its comment
      was wrong. *(completed — logic untouched, confirmed by diff)*
- [x] Add a one-line pointer near `orchestrate-triage-classify.sh`'s `previous_status` read
      confirming the field is now modelled in `state-schema.json` (no behavioural change; this file
      is declared in `file_scope` for exactly this provenance note). *(completed; full
      test-orchestrate-triage-classify.sh suite re-run, 60/60 passed, no regression)*
- [x] Commit (explicit two-file list). *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts the edit is confined to **~30 lines around `:1265-1285`** of
`orchestrate-cycle-postflight.sh` plus **one comment line** in `orchestrate-triage-classify.sh`,
and that the `:1273` reader and `:1276-1277` comment are still at approximately those lines.
Re-locate both by content (`Unspecified blocker`, `never written by any script`) rather than by line
number, since four sibling tasks may have shifted them.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - reader shape fix and
  comment correction in the blocked/partial aux-signal block
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - one provenance comment at
  the `previous_status` read

**Verification**:

- Extract the corrected jq expression and run it standalone against three inputs: a scalar-string
  `blockers`, an array-of-strings `blockers`, and an absent `blockers` — confirming a plain string,
  a `"; "`-joined string, and `"Unspecified blocker"` respectively, with no raw JSON in any case.
- `grep` confirms the false "never written by any script" sentence is gone and no other copy of it
  exists in the file.
- `shellcheck` clean on both scripts.

---

### Phase 5: Ship the consumer-runnable legacy-field migration [COMPLETED]

**Goal**: A consumer repo owner can run one idempotent script against their own `specs/state.json`
that retires the three dead top-level fields and normalizes `blockers` to arrays, printing every
value it drops so the no-information-loss constraint holds at run time and not only in this task's
artifacts.

**Tasks**:

- [x] Create `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh`, modelled
      structurally on the existing `migrate-directory-padding.sh` (same `--dry-run` flag, `set
      -euo pipefail`, colour helpers, argument loop) so it reads as a sibling of the migration
      precedent already in the tree. *(completed)*
- [x] Flags: `--dry-run` (preview, default off), `--state-file PATH` (default `specs/state.json`),
      `--help`. *(completed)*
- [x] Step 1 — retire: if present, print each of top-level `artifacts`, `metadata`, `last_updated`
      with its **full current value** to stdout under an explicit "recording dropped value before
      removal" heading, then delete the key. *(completed)*
- [x] Step 2 — normalize: for every `active_projects[]` entry whose `blockers` is a string, print
      the before/after and wrap it in a single-element array. Leave already-array values untouched.
      *(completed)*
- [x] Write exclusively through the deployed `scripts/state-write.sh`, matching the discipline
      `validate-state.sh --fix` already follows; never write `state.json` with a raw
      `jq > tmp && mv`. *(completed — same candidate-resolution discipline copied verbatim)*
- [x] Make it idempotent: a second run reports "nothing to migrate" and exits 0 without writing.
      *(completed and verified against both a synthetic fixture and the real consumer snapshot)*
- [x] Refuse to touch `specs/archive/state.json` (explicitly out of this schema's scope per the
      schema's own header note) and refuse any path outside the repo it is invoked in; fail loudly
      rather than silently skipping. *(completed and verified — both refusals tested directly,
      exit 2 with a named reason in each case)*
- [x] Print a closing summary naming what was preserved and where (the dropped values are in this
      run's own stdout; advise capturing it). *(completed)*
- [x] Smoke-test against a **copy** of the consumer repo's `specs/state.json` placed in the
      scratchpad directory — never against `~/Projects/BimodalLogic` itself. *(completed — a
      synthetic fixture first, then the real BimodalLogic snapshot copied into a scratchpad
      fake-deployed-tree fixture; dry-run matched the real run exactly: 3 top-level fields
      dropped, 3 blockers entries normalized (298, 257, 428), 481's existing array untouched;
      post-migration validate-state.sh showed zero findings for the eight in-scope fields, only
      `parent_task` (owned elsewhere) remaining; confirmed via `git status` that
      `~/Projects/BimodalLogic` itself was never written to by this script)*
- [x] `chmod +x`; commit. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts **1 new file** and that against the consumer snapshot the script will
drop **exactly 3** top-level keys and normalize **exactly 3** scalar `blockers` values (entries 298,
257, 428), leaving entry 481's array untouched. Confirm by running `--dry-run` against the
scratchpad copy and comparing its reported counts to these numbers before running for real; if they
differ, the consumer snapshot has moved since research and the report's field inventory must be
re-derived.

**Files to modify**:

- `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` - new migration script
  (note: not currently in the task's declared `file_scope`, which is descriptive and will be
  harvested at plan postflight)

**Verification**:

- `--dry-run` against the scratchpad copy of the consumer state prints all three dropped values in
  full and the three `blockers` normalizations, and writes nothing (`diff` before/after is empty).
- A real run against that copy leaves it passing `validate-state.sh` with zero unknown-field
  findings for the three retired fields.
- A second run on the already-migrated copy reports nothing to migrate and exits 0.
- `git status` confirms nothing under `~/Projects/BimodalLogic` was touched.
- `shellcheck` clean; `--help` works.

---

### Phase 6: Document the ruling, the retired values, and the posture divergence [COMPLETED]

**Goal**: `state-management-schema.md` carries every widened field with its writer and reader named,
every retired field with its last known value, and an explicit note that the JSON Schema keeps
`additionalProperties: false` while enforcement severity lives in the validator.

**Tasks**:

- [x] Add the one new top-level field to the **Top-Level Fields** table: `active_goal`, with
      `commands/review.md`'s goal-selection step named as writer, in the existing
      "Documented-optional, confirmed live" annotation style. *(deviation: altered — already
      present in the table, settled by hand 2026-09-30 alongside `deployment_versions`; verified in
      place, no edit needed)*
- [x] Add the four new entry fields to the **Project Entry Fields** table: `blockers` (array of
      strings; free-text annotation, no canonical script writer, read by
      `orchestrate-cycle-postflight.sh`'s blocked-verdict branch), `previous_status` (status enum;
      written by `/spawn`, read by `orchestrate-triage-classify.sh`'s discharge routing — marked
      load-bearing), `resume_phase` (integer; legacy, secondary to `continuation_context`),
      `researched` (ISO8601 timestamp, explicitly not a boolean and not the `status` enum value; no
      current writer or reader, retained because `last_updated` overwrites). *(completed)*
- [x] Add a new **Retired Top-Level Fields** subsection recording, for each of `artifacts`,
      `metadata` and top-level `last_updated`: why it was retired (no agent-system writer, no
      reader, pre-schema generator-era bookkeeping), its **last known value** as quoted data, and
      the migration script's name as the tool that removes it. This subsection is the durable
      written record the hard constraint requires. Use no task-number references; if the quoted
      legacy `artifacts` path trips the write-time task-reference gate, apply the documented
      `task-ref-ok` marker with a reason. *(completed; the write-time gate did not block the
      directory-name substring itself, but a `task-ref-ok` marker was applied defensively anyway
      since the row's own prose separately mentions "a reused task number")*
- [x] Add an **Unknown-field enforcement posture** note stating that the schema retains
      `additionalProperties: false` at both levels because draft-07 has no warn severity, and that
      the advisory/strict split is implemented in `validate-state.sh` Checks 3/4 — so the schema and
      the validator disagreeing on *severity* is deliberate, while disagreeing on the *field set* is
      a defect the new drift test catches. *(completed)*
- [x] Add a one-line provenance note beside the stale `state-write.sh` snippets that mint
      `resume_phase` and `researched` in `context/patterns/inline-status-update.md` and
      `context/patterns/jq-escaping-workarounds.md`, stating that no currently-live skill executes
      them (`skill-status-sync`'s `postflight_update` sets only `status` and `last_updated`), so a
      future reader does not treat the snippets as the live write path. *(completed — three notes
      added: inline-status-update.md's `researched` site and `resume_phase` site, and
      jq-escaping-workarounds.md's Research Postflight template)*
- [x] Mark `context/processes/implementation-workflow.md` as superseded at its head — it is
      referenced by nothing in the source store and its `resume_phase` postflight pattern is not what
      the live continuation mechanism does. *(completed; re-verified the zero-live-reference claim
      via grep before marking)*
- [ ] Commit.

**Timing**: 1.25 hours

**Depends on**: 1, 2, 4, 5

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts **5 files** and **2 new subsections** plus **5 table rows**. Confirm
the two pattern files actually still contain the `resume_phase` / `researched` snippets at
implementation time (the research located them at `inline-status-update.md:171` and `:88`, and
`jq-escaping-workarounds.md:75,100,120,254`) rather than trusting those line numbers.

**Files to modify**:

- `agent-system/extensions/core/context/reference/state-management-schema.md` - 5 table rows, a
  Retired Top-Level Fields subsection, an enforcement-posture note
- `agent-system/extensions/core/context/patterns/inline-status-update.md` - provenance note on the
  stale snippet
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` - provenance note on
  the Research Postflight template's field list
- `agent-system/extensions/core/context/processes/implementation-workflow.md` - superseded marker
- `agent-system/extensions/core/context/schemas/state-schema.json` - only if a description needs
  wording alignment with the reference doc; otherwise untouched

**Verification**:

- Every one of the five widened fields appears in the reference doc's tables with a named writer (or
  an explicit "no current writer" with its retention reason) and a named reader (or explicit none).
- Each of the three retired fields has its last known value recorded verbatim.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) reports no new
  task-number reference outside `specs/**`.
- Diff read-through confirms every changed hunk is prose, a table row, or a comment — no executable
  line altered.

---

### Phase 7: Full gate sweep and acceptance verification [NOT STARTED]

**Goal**: All nine consumer-repo validate-state.sh failures are demonstrably explained and resolved
by what this task shipped, every gate is green, and nothing was written to the consumer repo.

**Tasks**:

- [ ] Copy `~/Projects/BimodalLogic/specs/state.json` into the scratchpad directory (read-only
      source; never write back).
- [ ] Run the source-store `validate-state.sh` against the unmigrated copy; confirm the four
      unknown-top-level and four unknown-entry findings (excluding `parent_task`, owned by 271) are
      now **WARN, not FAIL**, and that `parent_task` remains the only unknown-field finding this task
      does not address — record that exclusion explicitly.
- [ ] Run `migrate-state-legacy-fields.sh` against the copy; re-run the validator; confirm the eight
      in-scope findings are gone entirely and the summary shows zero failures attributable to them.
- [ ] Walk the nine-failure list from the research report's Appendix and write, per field, which of
      widen/migrate/retire resolved it and where the record lives — this is the acceptance
      criterion's "all nine explained" clause.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` — full pass.
- [ ] Run `shellcheck` on all four touched/created scripts per
      `context/standards/shell-strict-mode.md`.
- [ ] Run `bash .claude/scripts/validate-state.sh` against this repo's own `specs/state.json` — no
      new findings.
- [ ] Confirm `git status` in `~/Projects/BimodalLogic` is unchanged from the start of the task.
- [ ] Confirm no file under `.claude/**` was hand-edited (`git status` on the deploy tree).
- [ ] Note in the summary that re-deploying the source store to `.claude/` is the loader's action,
      not this task's.
- [ ] Final commit.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts **9 consumer failures**, of which **8** are in scope here and **1**
(`parent_task`) is owned elsewhere, and **4** scripts to shellcheck. Confirm the failure count by
re-running the validator against the fresh scratchpad copy rather than trusting the research
report's Appendix, since the consumer snapshot may have moved.

**Files to modify**:

- none planned (verification phase; any fix it surfaces is applied in the owning phase's file)

**Verification**:

- Complete repository gate set green: `test-validate-state.sh`, `shellcheck` on all four scripts,
  `validate-state.sh` on this repo, and the task-reference lint.
- The nine-failure walkthrough is written out with a named resolution and record location for each.
- Both no-write invariants hold: consumer repo untouched, `.claude/**` not hand-edited.

---

## Testing & Validation

- [ ] `agent-system/extensions/core/scripts/tests/test-validate-state.sh` passes, including the five
      new cases and the schema-to-validator drift assertion.
- [ ] The drift assertion demonstrably fails when a known-field name is removed (negative control
      run and restored).
- [ ] All five widened fields validate with realistic values; both `blockers` shapes are accepted in
      default mode.
- [ ] The three retired top-level fields produce an unknown-field WARN (not silence, not FAIL).
- [ ] An unknown field WARNs in default mode and FAILs under `--strict`.
- [ ] The corrected postflight jq expression renders scalar, array, and absent `blockers` correctly,
      with no raw JSON.
- [ ] The migration script is idempotent, prints every dropped value, and is a no-op on a second run.
- [ ] `shellcheck` clean on `validate-state.sh`, `orchestrate-cycle-postflight.sh`,
      `orchestrate-triage-classify.sh`, `test-validate-state.sh`, and
      `migrate-state-legacy-fields.sh`.
- [ ] No task-number references introduced outside `specs/**`.
- [ ] `~/Projects/BimodalLogic` working tree unchanged; no hand-authored file under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/schemas/state-schema.json` — 1 top-level + 4 entry
  properties added, with writer/reader provenance in each description
- `agent-system/extensions/core/scripts/validate-state.sh` — 6 known-field names added, Checks 3/4
  advisory-first with written promotion criteria, header updated
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — 5 new cases including the
  schema-to-validator drift test
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — corrected `blockers`
  reader and corrected comment
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — provenance comment
- `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` — **new**, consumer-runnable
  idempotent migration
- `agent-system/extensions/core/context/reference/state-management-schema.md` — widened-field rows,
  Retired Top-Level Fields record, enforcement-posture note
- `agent-system/extensions/core/context/patterns/inline-status-update.md`,
  `context/patterns/jq-escaping-workarounds.md`,
  `context/processes/implementation-workflow.md` — provenance / superseded notes
- Task summary recording the nine-failure walkthrough

## Rollback/Contingency

Every phase commits independently, so rollback is per-phase `git revert` of that phase's commit —
no cross-phase coupling requires an all-or-nothing revert. The riskiest reversal is Phase 2 (the
severity change), which is a self-contained two-check edit in one file and reverts cleanly on its
own, restoring hard-FAIL behaviour without disturbing the Phase 1 widening.

Nothing in this task mutates any consumer repo, so there is no external state to unwind: the
migration script only ever runs where its operator invokes it. If a phase must be abandoned
mid-flight, take a non-reverting checkpoint with `bash .claude/scripts/git-snapshot.sh 279
--no-revert` before stopping, and mark the phase `[PARTIAL]` rather than leaving a half-applied
edit committed.

Because three sibling tasks touch `validate-state.sh`, `test-validate-state.sh` and
`orchestrate-cycle-postflight.sh` this same cycle, a revert must be a targeted revert of this task's
own hunks — never a whole-file checkout, which would discard a sibling's concurrent work.
