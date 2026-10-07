# Implementation Plan: Reconcile books-observe.sh RUN record field reads

- **Task**: 346 - Reconcile books-observe.sh RUN record field reads
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/346_reconcile_books_observe_run_record_field_reads/reports/01_reconcile-run-field-reads.md`
- **Artifacts**: plans/01_reconcile-run-field-reads.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The books observer's single `jq -c -s` RUN-log aggregation reads six field names and one field
type that do not exist in the normative `book-evidence-run-v1` schema, and the numeric-versus-
string task filter (mismatch 1) gates all five others — so the entire RUN-derived half of every
OBSERVATION record ever written has been silently empty rather than honestly absent. This plan
corrects all six reads schema-faithfully, adds a two-part fail-loud diagnostic that would
retroactively have caught mismatch 1's exact signature while keeping the observer non-blocking,
rewrites the test fixture that currently launders the bug as a passing test, amends the
extension-side record standard to the shapes the reader now writes, and redeploys and verifies
against the consumer repository's live log. Done means: schema-conformant fixtures prove the
RUN-derived groups are POPULATED, a regression fixture pins the numeric-filter case, the loud
path fires on a bad `schema` value and stays silent on a legitimately absent log, and a
books-topic task in the consumer repo shows populated RUN-derived fields.

### Research Integration

The research report verified all six mismatches directly against the live schema document, the
live sole writer (`books/tool/evidence-run.sh`), and the live `runs.jsonl` (149 lines at research
time, all `tier: certify`, `schema: book-evidence-run-v1`, `caller_context.task` either the
string `"175"` or `null` — never a bare number). Its six Decisions are adopted verbatim as this
plan's design and are not re-litigated here:

- **Decision 1**: `--arg` (string) rather than `--argjson`, plain string equality, no permissive
  dual-type comparison in the production filter — the schema fixes the type, and a permissive
  reader would hide a future writer-side regression.
- **Decision 2**: `certifier_outcome_classes` reads `.outcome_class` restricted to
  `tier == "certify"`; no record-shape change.
- **Decision 3**: `refusals`/`warnings` become count-based sums of `refusal_count`/
  `warning_count` — a genuine `certifier_outcomes` **shape change**, since the schema has no
  per-item text to supply.
- **Decision 4**: the vacuous filter becomes `select(.outcome_class == "vacuous-pass")`;
  `{tier, detail, source}` entry shape and the `detail: ""` fallback are unchanged.
- **Decision 5**: the fail-loud ruling is **two** complementary stderr-only checks — an
  unrecognized-`schema` exclusion warning, plus a permissive-vs-strict match-count divergence
  warning. The `schema` check alone **fails** the dispatch's own clause-(c) admissibility test
  (every live line already carries the correct, recognized `schema` value, so it would not have
  caught mismatch 1); the divergence check is the one that would have fired on all 149 lines.
- **Decision 6**: `observation-record.md` must be amended — required, not optional.

The report also found two items beyond the dispatch's six, both folded in below:

- The existing Case 7 fixture (`test-books-observe.sh:326-327`) encodes the bug rather than the
  schema (`outcome`, `vacuous`, `detail`, `duration_seconds`, and `caller_context.task` as the
  bare number `47`). It passes *by accident*. It must be rewritten, not merely re-run — which is
  why Phase 1 lands the fixture and the reader together as one atomic batch.
- `observation-record.md`'s `verification_tiers` row misspells the tier vocabulary with
  underscores (`lake_build`/`layer_lint`/`full_gate`) where both the schema and its sole writer
  use hyphens. Pre-existing and orthogonal to the six mismatches, but in a row this plan already
  edits.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch's delegation context; no ROADMAP.md was
consulted. This plan makes no roadmap claims.

## Goals & Non-Goals

**Goals**:
- Correct all six mismatches in `books-observe.sh`'s `PROBE-DEPENDENT GROUPS` jq aggregation
  against `book-evidence-run-v1`'s Fields table, schema-faithfully rather than permissively.
- Implement the fail-loud ruling: case (a) silent, case (b) loud, observer still non-blocking
  and still always exit 0 in live mode.
- Replace the bug-encoding test fixture with schema-conformant fixtures that assert the
  RUN-derived groups are POPULATED, plus regression fixtures pinning the numeric-filter case and
  both fail-loud paths.
- Amend `observation-record.md` to match the record the script now writes.
- Redeploy to the consumer repository and verify a books-topic task shows populated RUN-derived
  fields against the live log.

**Non-Goals**:
- Changing the RUN schema, or adding any field to it, to satisfy the reader. The schema is
  binding and its append-only sole-writer discipline is a deliberate design commitment.
- Making the observer blocking, or changing its live-mode always-exit-0 contract. Loud and
  non-blocking are compatible; loudness is stderr-only.
- Writing to `specs/books-evidence/runs.jsonl` from this extension, in any mode.
- Restructuring the books context corpus (that is task 342's scope — see the territory note in
  Risks below).
- Fixing anything in the consumer repository's own `books/` tree; this task only reads its schema
  and log, and redeploys this extension's script into its `.claude/` tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 1 split across two commits leaves the harness red (the fixture encodes the bug, so fixing the reader alone breaks Case 7) | M | H | Phase 1 is declared `Commit Mode: atomic-batch` — reader + fixture land as one objective; intermediate per-file states are expected red and MUST NOT be committed |
| The diagnostic permissive comparison becomes a second, drifting comparison to maintain | M | M | Keep it strictly diagnostic (stderr-only, never feeding the filter or the written record) and co-locate it textually inside the same jq program as the strict filter, so the two cannot diverge without a reviewer seeing both |
| Case 7's `record7b` assertion (`vacuous_passes == []`) silently flips to `"absent"` once the filter is schema-faithful | M | H | Rewrite the task-48 fixture line with the string form `"48"` so it still matches, preserving the assertion's original "known-clean, matched but no vacuous entries" intent rather than letting it degrade into an unmatched case |
| Task 342 (`context/project/books/**` glob, currently on hold) lifts mid-flight and both tasks edit `observation-record.md` with no machine-visible collision warning | M | L | Named and accepted in the dispatch as a deliberate owner-blocked carve-out. Phase 4 re-reads the file immediately before editing; the regions differ (RUN-derived group rows only vs. whole-corpus role-scoped loading), so a rebase is mechanical but must be performed deliberately |
| New fixture commit subjects trip the no-task-references lint | L | M | Place any new fixture whose git commit subjects follow the `task {N}:` convention inside a `task-ref-ok:begin` block, as the existing block at `test-books-observe.sh:347` already does. `caller_context.task` JSON values are data, not prose task references |
| The consumer repo's live log grows between planning and verification (23 lines at task creation, 149 at research time) | L | H | The fix is schema-shape-based, not line-count-based. Phase 5 re-reads whatever the current count is and reports it rather than asserting a fixed number |
| A sibling dispatch edits a file in this plan's scope this same cycle | L | L | Declared `file_scope` is disjoint from tasks 300 and 343 (both `extensions/core/**` and unrelated extensions). Still re-read each file immediately before editing, and stage only this task's own hunks — never a directory or glob `git add` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 1, 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Correct the six field reads, with its fixture, as one atomic batch [COMPLETED]

**Goal**: The `PROBE-DEPENDENT GROUPS` jq aggregation reads only fields that exist in
`book-evidence-run-v1`, the task filter matches the schema's string type, and the Case 7 fixture
feeds a schema-conformant line and asserts the RUN-derived groups are POPULATED.

**Tasks**:
- [x] Re-read `agent-system/extensions/books/scripts/books-observe.sh` lines ~406-449 and *(completed)*
      `tests/test-books-observe.sh` lines ~318-345 immediately before editing (sibling dispatches
      are live on this tree this cycle).
- [x] Mismatch 1: change `--argjson task "$task_number"` to `--arg task "$task_number"`, keeping *(completed)*
      the filter as plain string equality `select((.caller_context.task // null) == $task)`. Do
      NOT add a dual-type or `tostring` comparison to the production filter (Decision 1).
- [x] Mismatch 2: replace both `.outcome` reads with `.outcome_class` — the per-tier *(completed)*
      `outcomes: (group_by(.outcome) | ...)` rollup and its `(.[0].outcome // "unknown")` key.
- [x] Mismatch 3: replace `.duration_seconds` with `.wall_seconds` in the per-tier *(completed)*
      `total_seconds` sum.
- [x] Mismatch 4: `certifier_outcome_classes` reads *(completed)*
      `[ $mine[] | select(.tier == "certify") | .outcome_class ]`, replacing the nonexistent
      `.certifier_class`. Keep the `{value: count}` map shape (Decision 2).
- [x] Mismatch 5: replace the `refusals`/`warnings` per-item text arrays with integer sums over *(completed)*
      the task's certify-tier entries: `refusal_count_total` and `warning_count_total`, each
      summing the schema's `refusal_count`/`warning_count` with nulls excluded (the schema states
      these are certify-tier only, null elsewhere). Decision 3.
- [x] Mismatch 6: replace *(completed)*
      `select((.vacuous // false) == true or .outcome == "pass_vacuous")` with
      `select(.outcome_class == "vacuous-pass")`. Keep the `{tier, detail, source}` entry shape
      and the `detail: (.detail // "")` fallback unchanged (Decision 4).
- [x] Update the shell-side assembly of `certifier_outcomes_json` to emit *(completed)*
      `{outcome_classes, refusal_count_total, warning_count_total, source}` rather than
      `{outcome_classes, refusals, warnings, source}`, reading the two new integers out of
      `run_agg` with the same `jq -c` + `||` fallback idiom the surrounding lines already use.
- [x] Rewrite the Case 7 fixture's first line to be fully schema-conformant: `schema`, *(completed)*
      `timestamp`, `convention_version`, hyphenated `tier`, `caller_context.task` as a STRING,
      `outcome_class: "vacuous-pass"`, `wall_seconds`, and the four certify-tier counts where the
      tier is `certify`.
- [x] Rewrite the Case 7 fixture's second line (the task-48 "clean" case) with *(completed)*
      `caller_context.task` as the STRING form, so it still matches the filter and
      `vacuous_passes` still comes out `[]` rather than degrading to `"absent"` — preserving the
      existing assertion's original intent (see Risks).
- [x] Strengthen Case 7's assertions beyond exit-code 0: assert `verification_tiers.tiers` has at *(completed)*
      least one key, that key is the hyphenated tier name, `certifier_outcomes.outcome_classes`
      is a non-empty object where a certify-tier line is present, and `vacuous_passes` is a
      populated array whose `[0].tier` is the hyphenated name.
- [x] Keep any new fixture git commit subject following the `task {N}:` convention inside a *(completed)*
      `task-ref-ok:begin` block (the file already has one at line ~347).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Six mismatches, all inside `books-observe.sh`'s single `jq -c -s`
aggregation at approximately lines 408-448, plus their shell-side assembly immediately below, and
exactly one existing fixture case (Case 7, approximately lines 318-345) that must change in the
same batch. Confirm at implementation time by grepping the whole script for each of the six dead
names (`\.outcome\b`, `duration_seconds`, `certifier_class`, `\.refusal\b`, `\.warning\b`,
`\.detail\b`, `\.vacuous\b`, `pass_vacuous`, `--argjson task`) and confirming zero remaining
occurrences outside comments, and by grepping the test file for the same names to confirm no
second fixture also encodes them. If any name appears outside the stated line range, widen the
batch and record the correction rather than editing only the expected range.

**Files to modify**:
- `agent-system/extensions/books/scripts/books-observe.sh` - the six jq field-read corrections
  and the `certifier_outcomes_json` shell-side shape change
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` - Case 7 fixture rewritten
  to schema-conformant form with populated-group assertions

**Verification**:
- `bash -n agent-system/extensions/books/scripts/books-observe.sh` exits 0.
- `shellcheck agent-system/extensions/books/scripts/books-observe.sh` is clean per
  `context/standards/shell-strict-mode.md`.
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` reports 0 failed, with
  Case 7 now asserting populated groups.
- Build the enumerated one-hop dependent set for the `interface` tier and check it: the test
  harness (run above) and `observation-record.md` (whose amendment is Phase 4, which this phase
  therefore blocks). Grep the whole `agent-system/extensions/books/` tree for `refusals`,
  `warnings`, and `certifier_outcomes` to confirm no third consumer of the changed record shape
  exists; if one does, add it to Phase 4's scope and say so.

---

### Phase 2: Implement the fail-loud ruling (two stderr-only checks) [COMPLETED]

**Goal**: Case (b) — a log that exists and parses but whose records the reader cannot
legitimately interpret — is loud on stderr. Case (a) — a missing, unreadable, or genuinely
empty-for-this-task log — stays fully silent. The observer remains non-blocking and still always
exits 0 in live mode.

**Tasks**:
- [x] Re-read the `PROBE-DEPENDENT GROUPS` block as Phase 1 left it. *(completed)*
- [x] Check (i), unrecognized `schema`: inside the same single `jq -c -s` program, partition the
      input on `.schema == "book-evidence-run-v1"`. Aggregate only recognized lines. Emit two new
      diagnostic keys on the aggregation object: `unrecognized_schema_count` and
      `unrecognized_schema_values` (a deduplicated array of the offending values), so the shell
      side branches on pre-computed numbers rather than re-invoking jq (research Recommendation
      1b). *(completed)*
- [x] Check (ii), permissive-vs-strict divergence: in the same jq program, compute a second,
      diagnostic-only count using a normalized comparison
      (`(.caller_context.task | tostring? // "null") == ($task | tostring)`) and emit it as
      `permissive_count` alongside the existing strict `count`. The permissive count must never
      feed `$mine`, the written record, or any aggregation — it is a diagnostic input only. *(completed)*
- [x] Shell side: after `run_agg` is read, emit at most one stderr warning per check, in the
      established `books-observe.sh: ...` prefix style used at lines 245, 280, 540 and elsewhere:
  - when `unrecognized_schema_count` > 0: name the count and the unrecognized value(s), and
    state that those lines were excluded from aggregation.
  - when `permissive_count` > 0 and strict `count` == 0: warn that the RUN log has entries whose
    `caller_context.task` matches under a type-insensitive compare but not the schema-faithful
    filter, and name it as a possible writer-side type regression. *(completed)*
- [x] Confirm both warnings are stderr-only: no change to the exit code, no change to whether or
      what OBSERVATION record is written, and no change to the omit-never-zero discipline. When
      the strict count is zero the groups are still omitted / `"absent"` exactly as before. *(completed)*
- [x] Confirm case (a) stays silent: no warning when `$run_log` does not exist, when `jq` is
      absent, when `run_agg` is empty, or when both counts are legitimately zero. *(completed)*
- [x] Confirm the checks remain correctly per-task-number scoped inside the `--backfill --all`
      loop (research Recommendation 3 — structurally already true since `task_number` is a
      function-local positional, but confirm rather than assume). *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/books/scripts/books-observe.sh` - the two diagnostic jq keys and their
  shell-side stderr warnings, inside the existing `PROBE-DEPENDENT GROUPS` block

**Verification**:
- `bash -n` and `shellcheck` on the single changed file are clean.
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` still reports 0 failed
  (Phase 3 adds the fixtures that exercise the new paths; this phase must not regress the
  existing ones).
- Hand-check the clause-(c) admissibility test by replaying the ORIGINAL buggy filter shape
  against a string-valued fixture log: `permissive_count` > 0 with strict `count` == 0 must make
  check (ii) fire. If it does not, the mechanism is wrong and must be reworked before closing.
- Confirm by inspection that the live-mode exit path is untouched (always 0) and that neither
  warning sits on a path that can change the record's contents.

---

### Phase 3: Regression and fail-loud fixtures [COMPLETED]

**Goal**: Fixtures pin every behavior this task establishes: populated groups under the
schema-conformant shape (Phase 1), the numeric-filter case pinned so mismatch 1 cannot silently
return, the loud path firing on an unrecognized `schema`, and the silent path staying silent.

**Tasks**:
- [x] Re-read `tests/test-books-observe.sh` as Phase 1 left it. *(completed)*
- [x] Add the numeric-filter regression fixture: a log line whose `caller_context.task` is a JSON
      **number** equal to the task id. Assert (a) the RUN-derived groups stay absent/empty — the
      schema-faithful filter must NOT match it, which is precisely what pins the case, since a
      reversion to `--argjson` would make this fixture start matching — and (b) the
      permissive-vs-strict warning fires on stderr for that invocation. *(completed)*
- [x] Add the unrecognized-`schema` fixture: a line carrying a `schema` value other than
      `book-evidence-run-v1`. Assert the warning fires on stderr, the line is excluded from
      aggregation, and the OBSERVATION record is still written and the exit code still 0. *(completed)*
- [x] Add (or confirm) the two silent cases: the pre-existing Case 2 absent-log path, and a new
      zero-match-but-schema-recognized case. Assert stderr is EMPTY for both — a silent case that
      is only asserted not to crash does not pin silence. *(completed)*
- [x] Capture stderr separately from stdout in the new cases (the existing helpers redirect
      stdout to `/dev/null`); add a small stderr-capturing helper alongside `assert_json` /
      `assert_exit` rather than reworking the existing ones. *(completed)*
- [x] Place any new fixture whose git commit subjects follow the `task {N}:` convention inside a
      `task-ref-ok:begin` block. *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Four new or strengthened fixture cases (numeric-filter regression,
unrecognized `schema`, zero-match-recognized silence, absent-log silence) plus one new
stderr-capturing helper, all within `tests/test-books-observe.sh`. Confirm at implementation time
by counting the harness's reported assertions before and after and checking that each of the four
acceptance bullets in the dispatch maps to at least one named, failing-if-broken assertion — not
merely to an exit-code check. If a fifth case turns out to be needed, add it and record the
widening.

**Files to modify**:
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` - the four fixtures and the
  stderr-capturing helper

**Verification**:
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` reports 0 failed.
- `shellcheck agent-system/extensions/books/scripts/tests/test-books-observe.sh` is clean.
- Mutation check, run and recorded: temporarily revert `--arg` to `--argjson` in a scratch copy
  of the script and confirm the regression fixture FAILS; restore. A regression fixture that
  passes under both forms pins nothing.
- Mutation check for the loud path: temporarily neutralize the check-(ii) warning in a scratch
  copy and confirm the corresponding fixture FAILS; restore.

---

### Phase 4: Amend observation-record.md to the shapes the reader now writes [COMPLETED]

**Goal**: The extension-side record standard describes exactly the record Phase 1 and Phase 2
produce — no shape the script no longer writes, and no shape it writes that the standard omits.

**Tasks**:
- [x] Re-read
      `agent-system/extensions/books/context/project/books/standards/observation-record.md`
      immediately before editing (task 342 shares this file's glob territory with no
      machine-visible collision warning — see Risks). *(completed)*
- [x] Amend the `certifier_outcomes` row (line ~50) from
      `{outcome_classes: {}, refusals: [], warnings: [], source}` to
      `{outcome_classes: {}, refusal_count_total, warning_count_total, source}`, and state
      explicitly that the RUN schema carries integer counts only — never per-item refusal or
      warning text — so a reader does not expect text the log cannot supply. *(completed)*
- [x] Fix the `verification_tiers` row's (line ~49) tier vocabulary from underscored
      `lake_build`/`layer_lint`/`full_gate` to the hyphenated `lake-build`/`layer-lint`/
      `full-gate` the schema and its sole writer both use. Keep `certify` and `recheck` as-is
      (already correct). *(completed)*
- [x] Amend "The RUN Log (Verification Tiers, Certifier Outcomes)" section (line ~186) to record
      that `caller_context.task` is matched as a STRING per the RUN schema's type, and to document
      the fail-loud ruling: case (a) silent, case (b) a loud stderr warning, observer still
      non-blocking. *(completed)*
- [x] Confirm `vacuous_passes`'s row (line ~51) needs no change — the `{tier, detail, source}`
      entry shape is unchanged by Decision 4. Leave it untouched if so. *(completed)*
- [x] Confirm no task-number reference is introduced: this file lives under `agent-system/**`,
      where `rules/no-task-references-in-deliverables.md` applies. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/books/context/project/books/standards/observation-record.md` - the
  `certifier_outcomes` and `verification_tiers` rows and the RUN Log section

**Verification**:
- Diff read-through confirming every changed hunk lies inside markdown prose or a markdown table
  cell, with no code, script, or fixture surface touched.
- Field-by-field read of the amended rows against the record a Phase 3 fixture actually writes:
  every key the script emits appears in the standard, and every key the standard names is emitted.
- `bash .claude/scripts/check-task-references.sh` (or the repo-wide lint equivalent) reports no
  new occurrence for this path.

---

### Phase 5: Full gate, redeploy, and live verification against the consumer repo [COMPLETED]

**Goal**: The repository's complete gate set is green, the fix is deployed to the consumer
repository, and a books-topic task's OBSERVATION record there shows populated RUN-derived fields
rather than silently-absent ones.

**Tasks**:
- [x] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`). Resolve every failure
      attributable to this task's own files; for a failure in a file outside this plan's
      `file_scope`, check `git log` and treat it as possibly a sibling dispatch's in-flight edit
      before concluding it is a regression from this work. *(completed)*
- [x] Run `shellcheck` over both changed shell files and confirm clean per
      `context/standards/shell-strict-mode.md`. *(completed)*
- [x] Redeploy:
      `bash .claude/scripts/deploy-headless.sh /home/benjamin/Projects/Logos/Verification`.
      Confirm `/home/benjamin/Projects/Logos/Verification/.claude/scripts/books-observe.sh`
      (the flattened deployed path confirmed by research) now contains the corrected reads —
      diff it against the source-store copy's relevant block. *(completed)*
- [x] Re-read the consumer repo's live log and record its CURRENT line count and the distinct
      `caller_context.task` values present (do not assume 149, or 23). *(completed)*
- [x] Run the observer against a books-topic task in the consumer repo whose
      `caller_context.task` value actually appears in the log — live single-task path, or
      `--backfill` for that task number — and read the resulting
      `book.observation.json`. *(completed)*
- [x] Assert on that live record: `verification_tiers` is PRESENT with a non-empty `tiers` object
      keyed by hyphenated tier names, `certifier_outcomes` is PRESENT with a non-empty
      `outcome_classes` map and integer `refusal_count_total`/`warning_count_total`, and
      `vacuous_passes` is an array rather than `"absent"`. Record the observed values. *(completed)*
- [x] Confirm the observer's own exit code was 0 and that nothing in the consumer repository
      other than its `.claude/` deploy tree and the task's own observation record was written. Do
      NOT commit anything in the consumer repository. *(completed)*
- [x] Commit this repository's changes with scoped, explicit per-file staging — never a directory
      or glob `git add`, and only this task's own hunks. *(completed)*

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The live log's line count and task-value distribution are expected to
resemble research time (149 lines, all `tier: certify`, `caller_context.task` either `"175"` or
`null`) but are NOT asserted — the log is append-only and growing. Confirm by reading the log at
verification time and reporting the actual figures. If no log line carries a non-null
`caller_context.task`, the live verification cannot be performed as specified: say so explicitly
and report the fixture-level evidence instead, rather than declaring the acceptance criterion met.

**Files to modify**:
- none planned -- gate, deploy, and verification only. The consumer repository's deploy tree is
  rewritten by the deploy engine, never hand-edited.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with no failures attributable to this task.
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` reports 0 failed.
- `shellcheck` clean on `books-observe.sh` and `tests/test-books-observe.sh`.
- The deployed copy at
  `/home/benjamin/Projects/Logos/Verification/.claude/scripts/books-observe.sh` contains `--arg
  task` and `outcome_class`, and contains none of the six dead names.
- A named books-topic task's live `book.observation.json` in the consumer repo shows the
  populated RUN-derived groups enumerated above, with the observed values recorded in the
  execution summary.

---

## Testing & Validation

- [x] `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` — 0 failed, with
      Case 7 asserting POPULATED RUN-derived groups rather than exit-code 0 only. *(completed: 74
      passed, 0 failed)*
- [x] A schema-conformant fixture (including `caller_context.task` in its string form) proves
      `verification_tiers`, `certifier_outcomes`, and `vacuous_passes` are all populated.
      *(completed)*
- [x] A numeric-`caller_context.task` regression fixture proves the schema-faithful filter does
      NOT match it, and fails if `--argjson` is restored (mutation-checked). *(completed:
      mutation check performed against a scratch copy)*
- [x] An unrecognized-`schema` fixture proves the loud path fires on stderr, the line is excluded,
      and the record is still written with exit code 0. *(completed)*
- [x] An absent-log fixture and a zero-match-but-schema-recognized fixture both prove stderr is
      EMPTY — case (a) stays silent. *(completed)*
- [x] `shellcheck` clean on both changed shell files per `context/standards/shell-strict-mode.md`.
      *(completed)*
- [x] `bash .claude/scripts/verify-deploy.sh` exits 0. *(completed with a noted exclusion: the
      run reported 3 failing checks, all attributable to sibling task-300's own in-flight,
      already-committed edits to `agent-system/extensions/core/**` (confirmed via `git log` —
      `lint-agent-contracts.sh` content drift and a new undeclared test file, both inside
      task-300's declared `file_scope`) plus one pre-existing, unrelated dirty file
      (`orchestrate-cycle-plan.sh`, already modified before this dispatch started) — none inside
      this task's own `file_scope`. The one failure that WAS attributable to this task's own
      edit (`observation-record.md`'s index-entries.json line-count drift) was fixed via
      `generate-context-line-counts.sh --write`, confirmed by re-running
      `check-extension-docs.sh` and seeing `books: OK`)*
- [x] No task-number reference in any file landing under `agent-system/**` outside a
      `task-ref-ok` block. *(completed: `check-task-references.sh agent-system/extensions/books`
      reports 0 occurrences)*
- [x] Live consumer-repo verification: a books-topic task's OBSERVATION record shows populated
      RUN-derived fields rather than "absent". *(completed: task 175 in
      `/home/benjamin/Projects/Logos/Verification`, 230-line live log, `verification_tiers.tiers`
      populated with `certify` (count 23, outcomes `{pass: 23}`, total_seconds 269.071),
      `certifier_outcomes` populated (`outcome_classes: {pass: 23}`, `refusal_count_total: 0`,
      `warning_count_total: 0`), `vacuous_passes: []` — an array, not `"absent"`)*

## Artifacts & Outputs

- `agent-system/extensions/books/scripts/books-observe.sh` — six corrected field reads, the
  schema-faithful string task filter, the reshaped `certifier_outcomes` assembly, and the two
  stderr-only fail-loud checks.
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` — rewritten Case 7 plus
  four new/strengthened fixtures and an stderr-capturing helper.
- `agent-system/extensions/books/context/project/books/standards/observation-record.md` — amended
  `certifier_outcomes` and `verification_tiers` rows and RUN Log section.
- A redeployed `.claude/` tree in `/home/benjamin/Projects/Logos/Verification/`.
- `specs/346_reconcile_books_observe_run_record_field_reads/summaries/01_*-summary.md` — the
  execution summary, recording the live log's observed line count and the live record's observed
  RUN-derived values.

## Rollback/Contingency

All work is confined to three files in this repository plus a regenerable deploy tree in the
consumer repository, and every phase is committed green (Phase 1 as one atomic batch), so
`git revert` of this task's commits is the normal reversal path and needs no snapshot.

If an intentional rollback of UNCOMMITTED work becomes necessary mid-phase, take a snapshot
first per `context/contracts/recovery.md`'s rollback rung — that rung's invocation shape,
including its out-of-scope override flag for the deliberate whole-tree case — and then run the
destructive command. For an ordinary defensive checkpoint before risky work (not a rollback), use
`git-snapshot.sh --no-revert`, which is durable without reverting the working tree.

The consumer repository needs no rollback of its own: its `.claude/` tree is a disposable deploy
artifact, so re-running `deploy-headless.sh` from a reverted source store restores it. The
observation records the live verification writes there are advisory, non-blocking data; if one
must be removed, delete the file.
