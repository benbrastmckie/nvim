# Research Report: Reconcile books-observe.sh RUN record field reads

- **Task**: 346 - Reconcile books-observe.sh RUN record field reads
- **Started**: 2026-10-07T01:16:00Z
- **Completed**: 2026-10-07T01:43:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/books/scripts/books-observe.sh` (reader under fix, lines 406-449)
  - `agent-system/extensions/books/scripts/tests/test-books-observe.sh` (existing harness, Case 7)
  - `agent-system/extensions/books/context/project/books/standards/observation-record.md` (extension-side schema)
  - `/home/benjamin/Projects/Logos/Verification/books/schema/book-evidence-run-v1.md` (normative RUN schema, consumer repo)
  - `/home/benjamin/Projects/Logos/Verification/books/tool/evidence-run.sh` (sole writer of `runs.jsonl`)
  - `/home/benjamin/Projects/Logos/Verification/specs/books-evidence/runs.jsonl` (149 live lines, read directly)
  - `/home/benjamin/Projects/Logos/Verification/.claude/scripts/books-observe.sh` (deployed copy, confirms deploy path)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- All six field-name/type mismatches named in the dispatch are confirmed verbatim against the
  live schema and the live 149-line `runs.jsonl` (now grown from the 23 lines recorded at task
  creation). No new mismatches were found beyond the six named.
- Mismatch 1 (the `--argjson` numeric task filter versus the schema's string
  `caller_context.task`) is independently reproduced: every live record carries
  `"caller_context":{"task":"175", ...}` (string) or `{"task":null,...}`, never a bare number —
  confirming the filter has matched zero records on every run to date.
- The existing test fixture (`test-books-observe.sh` Case 7, line 326-327) itself encodes the
  bug rather than the schema: `"caller_context":{"task":47}` (number, not string) plus the wrong
  field/tier names (`outcome`, `vacuous`, `duration_seconds`, `layer_lint`). Because the fixture
  mirrors the reader's wrong expectations instead of the schema, the test currently passes by
  accident and would not catch any of the six mismatches even after they are "fixed" against the
  current fixture — the fixture itself must be rewritten, not merely re-run.
- A fail-loud mechanism is recommended (Decisions below): a `schema`-field check for unrecognized
  RUN-log lines, **plus** a permissive-vs-strict match-count sanity check that is the direct,
  retroactively-verified catch for mismatch 1's exact failure signature (a type-mismatch zeroing
  a filter silently). A `schema`-field check alone would not have caught mismatch 1, since every
  live line's `schema` value is already the expected `"book-evidence-run-v1"`.
- `observation-record.md`'s `certifier_outcomes` row needs a shape change (count-based, not
  per-item text) because the schema has no per-item `refusal`/`warning` text field, only
  `refusal_count`/`warning_count` integers. `verification_tiers`'s `tiers` row also independently
  misdescribes the tier vocabulary (underscored `lake_build`/`layer_lint`/`full_gate` where the
  schema and the sole writer both use hyphenated `lake-build`/`layer-lint`/`full-gate`) — a
  pre-existing documentation defect, orthogonal to the six mismatches, worth fixing in the same
  pass since the row is already being touched.

## Context & Scope

Scope is exactly the dispatch's six named mismatches in the `PROBE-DEPENDENT GROUPS` block of
`books-observe.sh` (lines 406-449), the fail-loud-versus-silent-degradation ruling, and the
`observation-record.md` amendment this may require. This report verifies each claim directly
against primary sources (the live schema document, the live sole-writer script, and the live
149-line log) rather than re-trusting the dispatch's own prose, and resolves the four open
"ALSO SETTLE" questions the dispatch leaves for research/plan. It does not implement anything —
no files under `agent-system/**` were modified during this phase.

## Findings

### The six mismatches, independently reproduced

All confirmed by reading `book-evidence-run-v1.md`'s Fields table and the live log directly
(`agent-system/extensions/books/scripts/books-observe.sh:408-448`):

1. **Task filter type mismatch** — `--argjson task "$task_number"` (line ~409) produces a JSON
   number; `select((.caller_context.task // null) == $task)` (line 410) compares it against the
   live records' string values. `grep -o '"caller_context":{[^}]*}' runs.jsonl | sort -u` returns
   exactly two shapes across all 149 lines: `{"task":"175","phase":"implement"}` and
   `{"task":null,"phase":null}` — never a bare number. The filter has matched zero records on
   every run, exactly as claimed.
2. **`.outcome` vs `outcome_class`** (line ~413, `outcomes: (group_by(.outcome) | ...)`) — the
   schema has no `outcome` field; the four-value vocabulary (`pass`/`fail`/`vacuous-pass`/
   `indeterminate`) lives under `outcome_class`. Confirmed: every live line carries
   `"outcome_class":"pass"`, never `outcome`.
3. **`.duration_seconds` vs `wall_seconds`** (line ~413, `total_seconds` sum) — confirmed: live
   lines carry `"wall_seconds":0.735` etc., no `duration_seconds` key anywhere in the log.
4. **`.certifier_class` does not exist** (line ~415) — confirmed absent from the schema and from
   every live line. The schema's certify-tier-only fields are `export_count`, `module_count`,
   `refusal_count`, `warning_count` (all present on every live certify-tier line).
5. **`.refusal`/`.warning`/`.detail` do not exist** (lines ~416-417) — confirmed: the schema
   defines only the integer counts, never per-item text. No live line carries any of these three
   keys.
6. **`.vacuous` does not exist; wrong sentinel order/separator** (line ~418,
   `select((.vacuous // false) == true or .outcome == "pass_vacuous")`) — confirmed: the schema's
   value is `"vacuous-pass"` (hyphen, noun-first), recorded under `outcome_class`, never a
   `vacuous` boolean. No live line currently has `outcome_class: "vacuous-pass"` (all 149 are
   `"pass"`), so this path has never fired in production, consistent with the dispatch's framing
   that it is correctness-by-inspection rather than observed-failure.

### The task-filter defect is the sole gate on every RUN-derived group

`mine_count="0"` (or empty) skips the entire `if [ "$mine_count" != "0" ]` body
(`books-observe.sh:432`), which is the only place `verification_tiers_json`,
`certifier_outcomes_json`, and the populated form of `vacuous_passes_json` are ever set. This
reproduces the dispatch's claim exactly: mismatches 2-6 are currently unreachable dead code —
fixing them without fixing mismatch 1 changes nothing observable.

### The existing test fixture encodes the bug, not the schema

`test-books-observe.sh:326-327` (Case 7, "VACUOUS PASS"):
```
{"tier":"layer_lint","outcome":"pass_vacuous","vacuous":true,"detail":"0 of 9 rules matched","caller_context":{"task":47},"duration_seconds":12}
{"tier":"lake_build","outcome":"pass","caller_context":{"task":48},"duration_seconds":30}
```
Every field name here (`outcome`, `vacuous`, `detail`, `duration_seconds`) is one of the six wrong
names, and `caller_context.task` is a bare JSON number (`47`), matching the script's current
(buggy) `--argjson` numeric comparison rather than the schema's string type. This is why Case 7
currently reports PASS: the fixture was built to satisfy the reader's wrong expectations, so it
never once exercised the schema-conformant shape. This is independent confirmation of the
dispatch's own diagnosis ("a test that only ever exercised the absent path cannot catch any of
the six mismatches") — it is worse than merely not testing the RUN-derived path; it actively
launders the bug as a passing test. Case 2 (line 163-168) is the genuine absent-log path and is
unaffected by this report's changes.

### `tier` vocabulary: a second, pre-existing doc defect in `observation-record.md`

`book-evidence-run-v1.md`'s "The `tier` vocabulary" section and the sole writer
(`books/tool/evidence-run.sh:35-36`, `--tier T ... lake-build, layer-lint, certify, check,
full-gate, recheck`) both use **hyphenated** tier names. `observation-record.md`'s
`verification_tiers` row instead lists `lake_build`, `layer_lint`, `certify`, `full_gate`,
`recheck` — **underscored**. This has no effect on `books-observe.sh` itself (`group_by(.tier)`
groups on whatever raw string is in the log, so the key in `tiers` will correctly come out
hyphenated once the other fixes land), but the standard's own prose is wrong and should be
corrected to hyphenated form in the same edit pass that touches this row for the mismatch-4/5
shape changes, since it is a one-line fix directly adjacent to work already planned.

### Deploy path confirmed

The deployed copy consumed by the consumer repo lives at
`/home/benjamin/Projects/Logos/Verification/.claude/scripts/books-observe.sh` (not under an
`extensions/books/scripts/` subpath in the deployed tree — flattened by the deploy process). Any
plan/implementation phase must redeploy to this exact path before the "verified against the
consumer repo's live log" acceptance criterion can be checked.

## Decisions

1. **Mismatch 1 fix is schema-faithful, not permissive.** Change `--argjson task "$task_number"`
   to `--arg task "$task_number"` and keep the equality filter as plain string comparison
   (`(.caller_context.task // null) == $task`). Do **not** add a dual-type comparison (e.g.
   `(.caller_context.task | tostring) == ($task | tostring)`) to the production filter itself —
   the schema fixes the field's type as "string or null"; a reader that silently accepts a
   numeric value would hide a future writer-side regression exactly as the dispatch warns. (The
   normalized/permissive form is still useful, but only as a *diagnostic* input to the fail-loud
   check below, never as the filter's own matching logic.)

2. **Mismatch 4** (`certifier_outcome_classes`) reads `.outcome_class` restricted to
   `tier == "certify"`, replacing the nonexistent `.certifier_class`. No shape change to the
   `certifier_outcomes.outcome_classes` object — it remains a `{value: count}` map, just sourced
   from the correct field.

3. **Mismatch 5** (`refusals`/`warnings`) becomes **count-based**, not list-based: sum
   `refusal_count` and `warning_count` across the task's certify-tier RUN-log entries (nulls
   excluded from the sum, per the schema's "certify-tier only; null for every other tier" rule;
   the group itself is omitted entirely when zero certify-tier entries matched, consistent with
   the existing omission discipline). This is a `certifier_outcomes` **shape change**:
   `refusals: []` / `warnings: []` (per-item text, which the schema cannot supply) become
   `refusal_count_total` / `warning_count_total` (integers). `observation-record.md`'s
   `certifier_outcomes` row must be amended to match.

4. **Mismatch 6** filter becomes `select(.outcome_class == "vacuous-pass")`, dropping the
   `.vacuous` boolean and the `pass_vacuous` token entirely. No shape change: the existing
   `{tier, detail, source}` entry shape is kept, with `detail` continuing to default to `""`
   (the schema carries no per-record human-readable detail string, so there is nothing new to
   populate it with — this was already the fallback behavior and needs no change).
   `outcome_class == "vacuous-pass"` is itself sufficient; the writer-side zero-count
   discriminator the schema describes is already baked into `outcome_class` by the writer, so the
   reader does not need to re-derive it.

5. **Fail-loud mechanism — two complementary, independently-justified checks, both loud and
   non-blocking (stderr warning only; exit code and OBSERVATION-record-writing behavior
   unchanged):**
   - **(i) Unrecognized `schema` value**: any RUN-log line whose `schema` field is not
     `"book-evidence-run-v1"` is excluded from aggregation and triggers one stderr warning
     naming the unrecognized value. This is the schema's own sanctioned compatibility hook (the
     "Versioning" section) and catches a future schema bump the reader has not been updated for.
   - **(ii) Permissive-vs-strict match-count divergence**: compute a second, diagnostic-only jq
     count using a normalized comparison (`(.caller_context.task | tostring? // "null") ==
     ($task | tostring)`) alongside the schema-faithful strict count from Decision 1. If the
     permissive count is nonzero while the strict count is zero, emit one stderr warning
     ("RUN log has entries whose caller_context.task matches under a type-insensitive compare but
     not the schema-faithful filter — possible writer-side type regression") and otherwise proceed
     exactly as the legitimately-absent case (write `"absent"`/omit, never blocking).
     **This is the mechanism retroactively verified against mismatch 1**: replaying the *original*
     buggy filter (numeric `$task` against the live string-valued log) against this diagnostic
     would have shown permissive-count > 0 and strict-count == 0 on every single run, immediately
     flagging the defect instead of 149 silent lines. Check (i) alone would **not** have caught
     mismatch 1 (every live line already carries the correct, recognized `schema` value) — this is
     exactly the dispatch's own admissibility test in clause (c), and check (i) alone fails it,
     which is why both checks are required rather than either alone.
   - Case (a) (missing file, or both counts legitimately zero) stays fully silent — no warning,
     consistent with "the probe genuinely has nothing to report."

6. **`observation-record.md` amendment is required** (not optional) for the `certifier_outcomes`
   row (Decision 3's shape change) and the `verification_tiers` row's tier-name spelling (hyphen,
   not underscore — the pre-existing doc defect found above). `verification_tiers`'s own internal
   shape (`{source, tiers: {...}}`) is unaffected by mismatches 2/3 (key renames inside the jq
   read only, no field added/removed at the OBSERVATION-record level).

## Recommendations

1. **Plan phase**: structure the implementation as (a) the six jq-expression fixes in
   `books-observe.sh` lines 408-449, applied together since mismatch 1 gates visibility of 2-6;
   (b) the fail-loud dual-check (Decision 5), landed as new code in the same
   `PROBE-DEPENDENT GROUPS` block, reading `$run_log` with `jq` twice (once for the recognized-
   schema aggregation, once for the diagnostic permissive/strict counts) or, more cheaply, folding
   both counts into the existing single `jq -c -s` call's output object so the shell side only
   branches on pre-computed numbers; (c) the `observation-record.md` amendment (Decision 3 + the
   hyphen fix); (d) the test-fixture rewrite below; (e) redeploy to
   `/home/benjamin/Projects/Logos/Verification/.claude/scripts/books-observe.sh` and verify against
   the live 149-line log.
2. **Test fixture rewrite** (`test-books-observe.sh`): replace Case 7's fixture
   (lines 320-345) with a schema-conformant line (`schema`, hyphenated `tier`, string
   `caller_context.task`, `outcome_class`, `wall_seconds`, the four certify-tier counts) and
   assert `verification_tiers`, `certifier_outcomes`, and the populated `vacuous_passes` array are
   all present and correctly shaped — not merely exit-code 0. Add a dedicated regression fixture
   that feeds a line with `caller_context.task` as a JSON **number** matching the task id and
   asserts (i) the RUN-derived groups stay absent/empty (the schema-faithful filter must not
   match it — this is what "pins the numeric-filter case" means: a reversion to `--argjson` would
   make this fixture start matching, which the assertion forbids) and (ii) the fail-loud
   permissive-vs-strict warning fires on stderr for that case. Add one more fixture for an
   unrecognized `schema` value (warning fires, line excluded, record still written) and confirm
   the pre-existing Case 2 (absent log) and a zero-match-but-schema-recognized case both stay
   silent.
3. Keep the `--backfill --all` path in mind during implementation: it calls `observe_run_core`
   once per task directory in a loop, so the fixed filter and the diagnostic counts must remain
   correctly scoped per-task-number inside that loop (already true structurally, since
   `task_number` is a function-local positional parameter — no change needed here, just confirm
   it in the implementation's own verification pass).
4. After redeploy, run `--backfill --all` (or the live single-task path) against the consumer
   repo's real 149-line log and confirm at least one books-topic task now shows a populated
   `verification_tiers`/`certifier_outcomes` rather than the groups being silently absent — this
   is the acceptance criterion's own "verified against the consumer repo's live log" clause and is
   the only way to confirm the fix in the repository the defect actually lives in.

## Risks & Mitigations

- **Risk**: the diagnostic permissive/strict check could itself become a second, drifting
  comparison to maintain. **Mitigation**: keep it strictly diagnostic (stderr-only, never feeding
  the actual filter or the written record), and co-locate it textually right next to the strict
  filter in the same jq program so the two cannot silently diverge in future edits without a
  reviewer seeing both at once.
- **Risk**: task 342 (on hold, same `context/project/books/**` glob territory as
  `observation-record.md`) lifts its hold mid-flight and both tasks land conflicting edits to the
  same file. **Mitigation**: already named and accepted in the dispatch as a deliberate,
  unsequenced carve-out (owner-blocked condition); this report adds no new mitigation beyond
  what the dispatch already states, since task 342's hold condition is outside this task's
  control.
- **Risk**: the consumer repo's live log could grow further between this research phase and the
  implementation/verification phase, changing the exact line count cited here (149 at research
  time, 23 at task-creation time). **Mitigation**: none needed — the fix is schema-shape-based,
  not line-count-based; the verification step should simply re-read whatever the current line
  count is at that time.

## Context Extension Recommendations

- **Topic**: `observation-record.md`'s tier-name spelling.
- **Gap**: the `verification_tiers` row lists underscored tier names
  (`lake_build`/`layer_lint`/`full_gate`) where both the normative RUN schema and its sole writer
  use hyphenated names (`lake-build`/`layer-lint`/`full-gate`). This predates this task and is
  unrelated to the six named mismatches, but sits in a row this task already amends.
- **Recommendation**: fix the spelling in the same edit that lands Decision 3's shape change,
  rather than opening a separate task for a one-line doc correction.

## Appendix

- Search queries / commands used: `grep -n "PROBE-DEPENDENT GROUPS" books-observe.sh`;
  `grep -o '"schema":"[^"]*"' runs.jsonl | sort -u`; `grep -o '"tier":"[^"]*"' runs.jsonl | sort
  -u`; `grep -o '"caller_context":{[^}]*}' runs.jsonl | sort -u`; `grep -n "tier" evidence-run.sh`.
- Live log size at research time: 149 lines (consumer repo), up from the 23 cited at task
  creation; all 149 lines are `tier: certify`, `schema: book-evidence-run-v1`,
  `convention_version` either `0.4.1` or `0.1.0-pre`.
- Deployed script path confirmed: `/home/benjamin/Projects/Logos/Verification/.claude/scripts/books-observe.sh`.
