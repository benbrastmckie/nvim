# Implementation Summary: Task #320

- **Task**: 320 - Run the orphaned .return-meta.json validator in the lifecycle, and give it the
  partial_progress checks it lacks
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T17:06:00Z
- **Completed**: 2026-10-02T19:35:00Z
- **Effort**: ~4.25 hours
- **Dependencies**: None
- **Artifacts**: plans/01_return-meta-producer-validation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`validate-return-meta.sh` existed, was tested, and was documented, but had zero coverage of the
one field that destroyed a live dispatch (`partial_progress`) and zero executing call sites
anywhere in the repo. This task closed both gaps additively: a new Check 6 inside the validator
(type-when-present plus conditional-presence, both `log_fail`), and a single warn-only probe in
`orchestrate-cycle-postflight.sh` gated strictly on `partial_progress`-specific validator output
rather than the validator's aggregate exit code. A `.return-meta.json` carrying
`"status": "researched"` alongside a bare-string `partial_progress` now produces a stderr
warning attributed to the writing agent plus a `RETURN_META_SCHEMA_VIOLATION` defect record,
while the dispatch completes and persists its status exactly as before — the opposite of the
originally observed harm (a complete, validated research report discarded by an unguarded `jq`
type error in `orchestrate-recover-outcome.sh`, already fixed separately in commit `27b6281fa`).

## What Changed

- `agent-system/extensions/core/scripts/validate-return-meta.sh` — new Check 6
  (`partial_progress` type-when-present + conditional-presence, both `log_fail`), two new
  `--help` "Validation rules:" lines. `--fix` deliberately not extended (no unambiguous
  object-shaped repair for a bare string).
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` — new
  `assert_output_contains` helper, four new cases (the motivating bare-string regression
  asserting both failure messages fire, a well-formed-object pass, a missing-`details` failure,
  and an absent-field pass). 21/21 passing (14 pre-existing + 7 new assertions).
- `agent-system/extensions/core/scripts/system-defect-record.sh` — `RETURN_META_SCHEMA_VIOLATION`
  added to the closed enum (fifteen → sixteen values): the `case` alternation, the
  `--defect-class` usage/help listing, and the invalid-class error message, with all "fifteen"
  wording updated to "sixteen".
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — new Signal A
  table row, a named "sixteenth instance" rationale paragraph (modeled on the `RECOVERY_DECLINED`
  paragraph immediately above it), and a Detection-point registry row classified by analogy to
  Class (a) with an explicit note that no existing class exactly fits "a detector wired to the
  recorder at creation time" — formalizing a fourth class is deferred to a second instance.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — new WORK (l) probe,
  inserted right after `notice_prefix`/`attributed_path`/`detecting_site_prefix` are set and
  before the WORK (a.0) stray-handoff sweep. Runs `validate-return-meta.sh` once against the
  dispatch's own `.return-meta.json`, filters to lines matching both `[FAIL]` and
  `partial_progress` (never the validator's aggregate exit code), warns on stderr naming the
  agent, and — when live — records `RETURN_META_SCHEMA_VIOLATION` via `system-defect-record.sh`
  with `--dispatched-agent` attribution plus the matching `detected_defects[]` row. Touches
  nothing else: `dispatch_status`, `recovered`, `have_outcome`, and every status-write/commit
  path are unaffected by construction (verified by grep: zero matches for those three names
  inside the new block). Header comment extended with a new `(l)` work-item description.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — added
  `validate-return-meta.sh` and its `return-meta-artifacts-lib.sh` dependency to the sandbox's
  `require_file`/`setup_sandbox` copy lists, plus four new end-to-end cases (950: positive, WARN
  + record + dispatch still completes/status persists; 951: `--dry-run` variant asserting the
  `[dry-run] would record` line; 952: the noise-guard negative case, a non-canonical status with
  no `partial_progress` produces zero probe output; 953: a fully well-formed file produces zero
  probe output). 153/153 passing (142 pre-existing + 11 new assertions).
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — annotated the
  `validate-return-meta.sh` entry: it now also runs automatically, warn-only, at orchestrate
  cycle postflight (in addition to remaining hand-runnable for its other checks), with the
  inclusion-criterion tension recorded explicitly (decision: keep the entry — it remains the only
  reference documentation for the hand-run-only `--fix` mode).
- Deployed `.claude/` copies of all five edited scripts/docs — verified byte-identical to the
  source store via `diff`.

## Decisions

- Both new validator rules use `log_fail`, never `log_warn`: the validator's own exit-code
  contract stays STRICT. The warn-only posture lives entirely at the postflight call site, per
  the dispatch's explicit instruction.
- The postflight probe filters on lines matching both `[FAIL]` and `partial_progress` together
  (`grep -E '\[FAIL\].*partial_progress'`), never on the validator's aggregate exit code. Verified
  by two falsifiability experiments (reverted, not committed): removing the probe block flips the
  positive/dry-run cases red with everything else staying green; switching the probe to gate on
  the aggregate exit code flips the noise-guard case red (plus three incidental false positives
  on pre-existing status-vocabulary-only fixtures), confirming the filter is load-bearing.
- `RETURN_META_SCHEMA_VIOLATION` is classified by analogy to Class (a) in the discrimination
  document, with an explicit note that no existing class exactly fits a detector wired to the
  recorder at creation time (vs. a pre-existing banner later gaining a recorder call) —
  formalizing a fourth class is deferred rather than invented informally here.
- `--fix` is not extended to `partial_progress`: a bare-string value has no unambiguous
  object-shaped repair (the `stage`/`details` split cannot be inferred from free prose), unlike
  the bare-string `artifacts` case, which has a mechanical path-segment inference.

## Plan Deviations

- Deploy-time observation, not a plan deviation in substance: `bash .claude/scripts/deploy-headless.sh`
  reported `verify-deploy FAIL -- 1 of 33 check(s) failed`, naming
  `scripts/tests/test-lean-mcp-preflight-check.sh` as differing from source. Investigated and
  confirmed this is sibling task 321's in-flight, uncommitted edit to a file in its own declared
  `file_scope` (mtime analysis: the deployed copy's mtime predates the source edit's mtime by 84
  seconds — this task's deploy ran, then task 321 edited the file afterward). All five of this
  task's own edited files were verified byte-identical between the source store and `.claude/`.
  Reported to the team lead; not fixed or re-deployed over, per the territory contract's
  STOP-and-report guidance for a sibling's in-flight work on a shared tree.

## Relationship to Open Task 270

Recorded here per the dispatch's explicit instruction (this is a `specs/**` artifact, where
task-number citations are permitted). Task 270 is "Re-runnable null-safety audit of jq mutation
sites across core scripts". This incident is a **read-site TYPE error** (an unguarded `jq` index
into a field whose type was never validated), not a mutation-site null error — a different
failure class in a different direction, so it is not covered by 270 as scoped, and this task does
not widen it. The consumer half of this concern was already landed separately (source-store
commit `27b6281fa`), so there is no live consumer half to split off either. If a future audit
wants the read-site type-error class handled systematically, widening task 270 is the cleaner
home for it than carving a new task out of this one.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on all three edited scripts)
- Tests: `test-validate-return-meta.sh` 21/21 passing; `test-orchestrate-cycle-postflight.sh`
  153/153 passing (including the unchanged `--dry-run` mutates-nothing invariant)
- `shellcheck`: zero new findings on all three edited scripts (1, 3, and 12 pre-existing
  info-level findings respectively, identical to each script's pre-edit baseline)
- `bash .claude/scripts/check-task-references.sh`: 0 unexempted occurrences
- Files verified: Yes — all five edited source-store files confirmed byte-identical to their
  deployed `.claude/` copies via `diff`
- Acceptance criterion (end to end): verified via Case 950 — a `.return-meta.json` with
  `"status": "researched"` and a bare-string `partial_progress` produces the stderr warning,
  the `RETURN_META_SCHEMA_VIOLATION` record attributed to the dispatched agent, and the dispatch
  still completes with its status persisted
- Noise guard (end to end): verified via Case 952 — a non-canonical status with no
  `partial_progress` produces zero probe output

## Impacts

- A future producer-side `partial_progress` schema violation (wrong type, or present under a
  disallowed status) is now caught and warned on at write time instead of silently corrupting a
  downstream consumer's `jq` read.
- `validate-return-meta.sh` is no longer an orphaned utility: it has its first executing lifecycle
  call site, exercised on every `/orchestrate` dispatch's own `.return-meta.json`.
- The Signal A defect-class vocabulary grows from fifteen to sixteen values; any future reader of
  `system-defect-discrimination.md` or `system-defect-record.sh` sees the new class and its
  rationale recorded explicitly, not silently.

## Follow-ups

- None required for this task's own scope. Widening task 270 to cover the read-site type-error
  class systematically (beyond this one instance) is named as a follow-on candidate, not decided
  here.

## References

- Plan: `specs/320_return_meta_producer_side_validation/plans/01_return-meta-producer-validation.md`
- Research report: `specs/320_return_meta_producer_side_validation/reports/01_producer_side_validation.md`
- Progress files: `specs/320_return_meta_producer_side_validation/progress/phase-{1..6}-progress.json`
