# Research Report: Task #352

**Task**: 352 - validate-artifact.sh fixes counters do not accumulate
**Started**: 2026-10-07T00:00:00Z
**Completed**: 2026-10-07T00:00:00Z
**Effort**: 2h
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/{validate-artifact.sh,skill-base.sh,command-gate-out.sh,tests/test-gate-out-repair-reporting.sh,tests/known-failures.txt}), `git log`/`git show` provenance, live suite execution, isolated manual repros under a scratch directory
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The defect as described in the dispatch and in `known-failures.txt` no longer exists.**
  `SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES` (and their siblings `SKILL_VALIDATE_ERRORS`/
  `SKILL_VALIDATE_WARNINGS`) in `skill-base.sh`'s `skill_validate_task_artifacts()` already
  accumulate correctly across a multi-file sweep and already reset unconditionally at function
  entry on every call. Both properties were added in commit `d6934a269` ("task 13 phase 1.1:
  propagate validate-artifact.sh counts through skill_validate_task_artifacts", 2026-09-03) and
  are exercised and currently PASSING by Case 3 (accumulation, N=2 files -> `SKILL_VALIDATE_FIXES=2`)
  and Case 6 (reset, a repairing call followed by a clean call reports all-zero) of
  `test-gate-out-repair-reporting.sh`.
- **The one assertion that actually fails today (confirmed by live execution: 18/19 pass, 1 fails) is Case 1**, not Cases 4/6 as `known-failures.txt`'s row claims. Case 1 fails because its
  fixture (`write_repairable_plan`, which omits the plan's `**Status**` metadata field entirely)
  now triggers a *second*, unrelated defect class that did not exist when Case 1 was authored:
  a later-added plan-level Status-line bracket-grammar check (commit `5abc55db8`, "task 136 phase
  4: shared plan-status-line grammar library and validator wiring", 2026-09-29) flags the
  generic `--fix`-inserted `- **Status**: TBD` placeholder as grammar-non-conformant, producing
  one real, intentional, by-design remaining error. Case 1's assertion (`0 error(s)` in the
  gate-out report line) predates that check and was never updated.
- **`known-failures.txt`'s row is itself stale/mis-diagnosed, not merely under-owned.** It was
  seeded on 2026-09-30 (commit `0f1b721a4`) — *after* both the real fix (Sep 3) and the Status-line
  grammar check that introduced the current failure (Sep 29) — but its reason text describes the
  pre-Sep-3 symptom shape (`fixes=0 errors=1`, "cases 4 and 6 fail"), which does not match the
  live output (`fixes=1 errors=1`, Case 1 fails, Cases 4/6 pass). The row was written by reading
  stale context (most likely the original task-13 defect description) rather than by re-running
  the suite and reading which assertion actually failed.
- **Boundary**: the defect is confined to the interaction between two features inside
  `validate-artifact.sh` (generic metadata-placeholder `--fix` + the plan-level Status-line
  grammar check) as surfaced through a stale test fixture in
  `test-gate-out-repair-reporting.sh`. There is no defect in `skill-base.sh`'s aggregation logic
  or in `command-gate-out.sh`'s reporting logic — both are verified correct by Cases 3, 4, 6, 7, 8
  all currently passing.
- **Recommended fix**: change `write_repairable_plan`'s omitted field from `**Status**` to a field
  with no secondary grammar check (`**Effort**` verified to work by direct repro below), so Case
  1 regains its original intent (a pure single-field repair with zero remaining errors) without
  touching any production code. No change to `skill-base.sh`, `command-gate-out.sh`, or the
  counters/accumulation/reset logic in `validate-artifact.sh` is needed or justified.

## Context & Scope

The dispatch's GOAL framing asserts `validate-artifact.sh`'s repair-reporting globals
(`SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES`) "fail to accumulate when they should, and
... persist when they should be cleared," citing `known-failures.txt`'s
`test-gate-out-repair-reporting.sh` row (category `real-defect`, owner `needs-owner`) and a
"re-confirmed red on 2026-10-06: 18 of 19 assertions pass, 1 fails" note. This research
re-verified that claim against the live suite and the live code before accepting the framing, per
the dispatch's own instruction to "confirm by reading whether the defect lives in
validate-artifact.sh alone or also in skill-base.sh / command-gate-out.sh ... Establish the real
boundary before editing."

Scope covered: `agent-system/extensions/core/scripts/validate-artifact.sh`,
`agent-system/extensions/core/scripts/skill-base.sh` (the `skill_validate_task_artifacts`
function and its header comment), `agent-system/extensions/core/scripts/command-gate-out.sh` (the
reporting call site), `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`
(all 8 cases / 19 assertions), and `agent-system/extensions/core/scripts/tests/known-failures.txt`.
Git provenance (`git log -p`, `git show --stat`) was used to date the relevant commits and
establish ordering. Several isolated manual repros (scratch `mktemp -d` fixtures, never the real
`specs/` tree) were run directly against `validate-artifact.sh --fix` to confirm the mechanism.

Out of scope for this report: shellcheck pass and the actual fixture edit / known-failures.txt row
disposition (both are implementation-phase work, flagged as recommendations below).

## Findings

### Codebase Patterns

**1. The counters already accumulate and already reset — this is proven, not inferred.**
`skill_validate_task_artifacts()` in `skill-base.sh` (lines ~772–852):
- Unconditionally resets all four globals at function entry (lines 777–780), before the sweep
  loop, with a header comment explicitly documenting this as the hazard mitigation: "Unconditional
  reset -- before the loop, always, so a caller can never observe a stale value from a previous
  invocation."
- Accumulates via `+=`-equivalent arithmetic (`SKILL_VALIDATE_FIXES=$((SKILL_VALIDATE_FIXES +
  ${file_fixes:-0}))`, line 843, and the same pattern for errors/warnings at lines 844–845) inside
  the per-file loop across all three subdirectories (`reports:report plans:plan
  summaries:summary`).
- This exact pair of properties is what Case 3 (accumulation) and Case 6 (reset) pin, and both
  currently PASS:
  ```
  [PASS] Case 3: two repairable artifacts across the sweep sum to SKILL_VALIDATE_FIXES=2
  [PASS] Case 3: SKILL_VALIDATE_FIXED_FILES names both repaired paths
  [PASS] Case 6: a clean call after a repairing call reports all-zero globals (no stale carryover)
  ```

**2. Git provenance dates the fix to before the known-failures row was even written.**
```
d6934a269  2026-09-03  task 13 phase 1.1: propagate validate-artifact.sh counts through
                       skill_validate_task_artifacts        <- adds reset + accumulation
acb984656  2026-09-03  task 13 phase 4: fixture-driven regression suite, both directions
                                                              <- test-gate-out-repair-reporting.sh authored (same day, presumably green)
5abc55db8  2026-09-29  task 136 phase 4: shared plan-status-line grammar library and
                       validator wiring                      <- adds the Status-line bracket check
                                                                 that later breaks Case 1
0f1b721a4  2026-09-30  task 283 phase 4: committed known-failing baseline manifest
                                                              <- known-failures.txt first created,
                                                                 already describing the (by-then-
                                                                 fixed) pre-09-03 symptom shape
```
The known-failures row was seeded nearly a month after the fix it claims is still outstanding,
and one day after the actually-responsible commit (136) landed. This is strong evidence the row's
text was copied from stale prior context (most plausibly task 13's own original defect writeup)
rather than produced by re-running the suite and reading its current output.

**3. Live suite output contradicts the known-failures row's own symptom description.**
Running `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`
produces **18 passed, 1 failed** (matching the dispatch's "18 of 19... 1 fails" count), but the
failing assertion is Case 1, not Cases 4/6:
```
[FAIL] Case 1: report line did not name a nonzero repaired-field count. Output:
...
[FIXED] 1 field(s) auto-repaired, 1 error(s), 0 warning(s) remaining
...
[gate-out] Artifact validation for task 1: 1 field(s) auto-repaired, 1 error(s), 0 warning(s) remaining.
```
This is `fixes=1 errors=1`, not the row's claimed `fixes=0 errors=1`. Case 4 and Case 6 both PASS
in the same run:
```
[PASS] Case 4: fixes=1 AND errors=8 both nonzero in the same sweep
[PASS] Case 6: a clean call after a repairing call reports all-zero globals (no stale carryover)
```
The "18/19, 1 fails" headline count in the dispatch's provenance note is real and was presumably
observed directly — but whoever recorded "re-confirmed red" evidently trusted the existing row's
*description* of which case/shape was failing rather than re-reading the actual failing
assertion's own text, which names Case 1 and a `fixes=1 errors=1` shape in its `[FAIL]` line.

**4. Root mechanism of the real, current Case 1 failure — isolated and reproduced directly.**
`write_repairable_plan` (the Case 1/3/6/7 fixture) omits the plan's `**Status**` metadata field
entirely. `validate-artifact.sh --fix`'s generic placeholder-insertion logic (lines 144–184) fixes
*any* missing metadata field the same way: it inserts a literal `- **Field**: TBD` line, with no
field-specific awareness. Separately, the plan-type branch (lines 249–265, added by commit
`5abc55db8`) runs a dedicated grammar check (`plan_status_classify`, from the newer
`scripts/lib/plan-status-line.sh` library) against whatever `**Status**` line exists *after* the
fix has already run and mutated the file on disk. `TBD` is not a `[STATUS]`-bracketed value, so
this check correctly flags it as a new error. Direct manual repro confirms this exactly:
```
$ bash validate-artifact.sh <plan missing Status field> plan --fix
  [ERROR] Missing metadata field: **Status**:
  [FIXED] Inserted placeholder: - **Status**: TBD
  [ERROR] plan-level Status line has no [STATUS] bracket pair (line 10)
[FIXED] 1 field(s) auto-repaired, 1 error(s), 0 warning(s) remaining
```
This is validate-artifact.sh's own header comment's documented, intentional design: the comment
block at the top of the file (lines 14–28) explicitly states the Status-line grammar check
deliberately does **not** participate in `--fix`, because "two of the three malformed shapes are
unrepairable by any general rule" — and a wholly-absent Status line (shape M1 in that same
comment) is one of the two. A missing Status field being auto-"fixed" to a still-non-conformant
placeholder, and surfacing as a remaining error, is working as designed, not a bug.

**5. Confirmed fix candidate: swap the omitted field.** Using `**Effort**` instead of
`**Status**` as the omitted field (with `**Status**: [NOT STARTED]` present and well-formed)
reproduces the originally-intended Case 1 shape exactly:
```
$ bash validate-artifact.sh <plan missing Effort field, Status present/valid> plan --fix
  [ERROR] Missing metadata field: **Effort**:
  [FIXED] Inserted placeholder: - **Effort**: TBD
[FIXED] 1 field(s) auto-repaired, 0 error(s), 0 warning(s) remaining
```
This is a one-field fixture edit, confined to `test-gate-out-repair-reporting.sh`'s
`write_repairable_plan` helper. It does not touch `validate-artifact.sh`, `skill-base.sh`, or
`command-gate-out.sh`, since none of those three contain an actual defect (Finding 1 above).
Cases 3/6/7 (which also call `write_repairable_plan`) do not assert on `errors` at all — only on
`SKILL_VALIDATE_FIXES` magnitude, `SKILL_VALIDATE_FIXED_FILES` contents, and the `[FIXED]` prefix
shape — so they are unaffected by this fixture change and continue to pass.

**6. Sibling-global sweep (per the dispatch's "ALSO SETTLE" instruction): no other gap found.**
`skill-base.sh`'s other caller-visible uppercase globals using the same convention
(`SKILL_HOOK_LAST_RC`, `SKILL_HOOK_LAST_STATUS`, `SKILL_HOOK_LAST_NAME`, `SKILL_HOOK_LAST_PATH` in
`skill_run_extension_hook`) are *also* unconditionally reset at function entry (lines 206–209),
matching the same discipline as the `SKILL_VALIDATE_*` globals. `TASK_DIR`/`ARTIFACT_PATH`/etc.
(set in `skill_preflight_init` et al.) are one-shot computed assignments, not `+=`-style
accumulators, so they carry no analogous cross-call hazard. A targeted grep for every
`+=`/`$((VAR + ...))`-style accumulator in `skill-base.sh` turned up only the three
`SKILL_VALIDATE_{FIXES,ERRORS,WARNINGS}` arithmetic accumulations and the string-concatenation
accumulator for `SKILL_VALIDATE_FIXED_FILES` — all already reset at entry. No sibling gap exists
today.

### External Resources

Not applicable — this is a pure codebase/provenance investigation; no external documentation was
needed.

## Decisions

- **Reject the dispatch's literal framing that the counters "fail to accumulate" / "persist when
  they should be cleared."** Both properties are already correct, already fixed (2026-09-03), and
  already pinned green by Cases 3 and 6. Re-implementing or re-pinning them would be redundant
  work against a non-bug.
- **The real, currently-failing defect is Case 1's stale fixture**, broken by a later, unrelated
  feature (the plan-level Status-line grammar check, 2026-09-29) interacting with
  `validate-artifact.sh`'s pre-existing, intentionally-generic `--fix` placeholder mechanism. This
  is the one change needed to reach 19/19.
- **Boundary determination**: confined entirely to `validate-artifact.sh`'s (correct, by-design)
  behavior as exercised through a stale fixture in `test-gate-out-repair-reporting.sh`. No defect
  exists in `skill-base.sh` or `command-gate-out.sh` — both verified correct via their own passing
  cases.
- **Decline the structural "return values instead of globals" change** (one of the dispatch's
  "ALSO SETTLE" options). Reasoning: (a) there is no live bug motivating it — the globals are
  already safe because of the entry-point reset discipline; (b) it would be inconsistent with
  every other caller-visible state channel this same file already uses
  (`TASK_DIR`/`ARTIFACT_PATH`/`SUBAGENT_STATUS`/`SKILL_HOOK_LAST_*` are all globals, never return
  values, per `skill-base.sh`'s own established convention, also noted in its header comment for
  this very function); (c) Bash function "return values" are exit codes only — conveying four
  pieces of structured data (3 counts + a comma-joined path list) back to a caller would require
  either the same global-variable channel or stdout parsing, and global-plus-reset is the
  less fragile of those two, and the one every other similar case in this file already uses.
- **Cases 4 and 6 assert the right thing and are not stale.** Verified directly: both pin a real,
  independent property (fix+error coexistence for Case 4; cross-call reset for Case 6) that is
  distinct from Case 1's single-clean-repair property, and both would still fail if either half of
  the accumulate/reset fix were reverted (Case 3/6 exercise accumulation and reset directly against
  the sourced function; reverting either the reset line or the `+=` arithmetic in
  `skill_validate_task_artifacts` would immediately fail Case 3 or Case 6 respectively — confirmed
  by code inspection of exactly which lines each case's assertion depends on).

## Recommendations

1. **Fix** (not re-implement): in `test-gate-out-repair-reporting.sh`'s `write_repairable_plan`
   helper, change the omitted metadata field from `**Status**` to `**Effort**`, and add a present,
   well-formed `**Status**: [NOT STARTED]` line. This is the minimal edit that restores Case 1's
   originally-intended "clean single-field repair" shape (`fixes=1 errors=0`) without touching any
   production script. Re-run the full suite after the edit to confirm 19/19 (Cases 3/6/7, which
   share this fixture, are expected to remain green per Finding 5's analysis — re-verify rather
   than assume).
2. **Do not modify** `validate-artifact.sh`'s Status-line grammar check or its generic `--fix`
   placeholder logic — both are working as designed (Finding 4), and `write_repair_plus_errors_plan`
   (Case 4) already exists specifically to pin the "fix and remaining-error coexist" shape that a
   missing-Status-field repair legitimately produces.
3. **Do not modify** `skill-base.sh`'s `skill_validate_task_artifacts` accumulation/reset logic or
   `command-gate-out.sh`'s reporting call site — both verified correct.
4. **Close out `known-failures.txt`'s row** per the dispatch's REVISION instructions: once the
   fixture fix lands and the suite is green under `tests/run-all.sh`, **delete** the
   `test-gate-out-repair-reporting.sh` row outright (the "ON FIX" branch) — do not convert it to a
   formal acceptance, since the live behavior the row originally flagged turned out not to be a
   real defect in the area it named, and the actual stale-fixture defect is now fixed, not
   accepted-as-correct-behavior-we-tolerate.
5. **Consider** (optional, not required by acceptance) adding a one-line comment next to
   `write_repair_plus_errors_plan`/Case 4 cross-referencing *why* a missing-Status-field repair
   necessarily leaves a remaining error (the Status-line grammar check's bracket requirement), so
   a future maintainer modifying either fixture does not reintroduce this exact mis-triage.
6. **Process note for the plan/implementation phase**: when a `known-failures.txt` row's
   described symptom shape does not literally match the suite's live `[FAIL]` output, re-diagnose
   from the live output before trusting the row — this task is itself an instance of that
   lesson, and the lesson generalizes to every future `needs-owner` row triage.

## Context Extension Recommendations

- **Topic**: known-failures.txt triage discipline.
- **Gap**: no existing standards doc states "when claiming a row, re-run the suite and match the
  live `[FAIL]` text against the row's description before accepting it as still accurate" as an
  explicit step. `context/standards/shell-script-testing.md` documents the manifest format and
  points to `known-failures.txt` as the single source of truth for *which* suites are
  known-failing, but says nothing about re-validating a row's *reason text* against current
  behavior before treating it as the task's scope.
- **Recommendation**: add a short subsection to `context/standards/shell-script-testing.md` (or a
  sibling triage-process doc) codifying this re-diagnosis step, citing this task as the worked
  example of why it matters (a row seeded weeks after its claimed defect was fixed, describing a
  symptom shape that no longer occurs).

## Appendix

- Commands run: `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`
  (full live run); `git log --oneline -- skill-base.sh`; `git log -p --follow -- skill-base.sh`
  (grepped for `SKILL_VALIDATE_FIXES=0` / accumulation lines); `git show --stat
  d6934a269 5abc55db8`; `git log -p -1 0f1b721a4 -- known-failures.txt`; direct manual
  `validate-artifact.sh ... plan --fix` repros against scratch `mktemp -d` fixtures (missing
  Status field only, and missing Effort field with Status present/valid).
- Key files read in full: `agent-system/extensions/core/scripts/validate-artifact.sh` (347
  lines), the `skill_validate_task_artifacts` function and its header comment in `skill-base.sh`
  (lines ~700–852), the reporting block in `command-gate-out.sh` (lines ~267–310), and
  `test-gate-out-repair-reporting.sh` in full (526 lines, all 8 cases).
- Commit references: `d6934a269` (2026-09-03, adds reset+accumulation),
  `acb9846565e59fbf9a1d1e4558869128008ad716` (2026-09-03, authors the regression suite),
  `5abc55db86f1ac1f9124390e74856d702884b5e0` (2026-09-29, adds the Status-line grammar check that
  later breaks Case 1), `0f1b721a4c9e9fa5e866535adf524a6494ce3ea6` (2026-09-30, seeds
  `known-failures.txt` with the now-stale description).
