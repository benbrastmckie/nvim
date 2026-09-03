# Implementation Plan: Instrument gate-out auto-repair reporting

- **Task**: 13 - Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/013_instrument_gate_out_auto_repair_reporting/reports/01_gate-out-repair-reporting.md
- **Artifacts**: plans/01_gate-out-repair-reporting.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta

## Overview

`validate-artifact.sh` already computes exact auto-repair, error, and warning counts and prints
them on stdout, but `skill_validate_task_artifacts` (`skill-base.sh`) throws the numbers away —
it inspects only the exit code and collapses every non-zero result into one generic non-blocking
`WARNING` string. `command-gate-out.sh`, the function's single call site, therefore has no
numeric signal at all, and an artifact rewritten in place by `--fix` leaves no record anywhere
that it was rewritten. This plan propagates the counts through the function via caller-visible
globals, gives `command-gate-out.sh` an always-on console report plus a durable
`specs/events.jsonl` record, adds the regression suite this function has never had, and
demonstrates both the repaired and the clean direction end to end. Done means: a task whose
artifact needed repair reports a nonzero repaired-field count and a task needing none reports
zero, both from the same code path, both proven by a committed test.

### Research Integration

The research report traced the call chain line-for-line and its findings are load-bearing here:

- `command-gate-out.sh` is the **only** invocation of `skill_validate_task_artifacts` anywhere in
  `agent-system/extensions/`, so the fix is fully containable in the two files the task names.
- `2>/dev/null` at the call site discards only *stderr*; `validate-artifact.sh` writes its counts
  through `echo` to *stdout*, so the numbers are already reaching the console and only need
  capturing.
- `validate-artifact.sh`'s terminal summary line has exactly three exit-code-discriminated shapes
  (`[FIXED]`/exit 2, `[PASS]`/exit 0, `[FAIL]`/exit 1), and is always the last line printed —
  making exit-code-anchored parsing of `tail -1` reliable.
- Exit codes 3/4/5 are *validation-could-not-run* states carrying no counts at all; a naive
  parser would record them as zero and hide a real failure behind an all-clear report.
- `skill-base.sh` already uses uppercase globals as a return channel for sourced functions
  (`TASK_DIR`, `ARTIFACT_PATH`, `SUBAGENT_STATUS`, …), and `command-gate-out.sh` sources
  `skill-base.sh` rather than subprocessing it — so this mechanism is directly available and
  needs no new IPC.
- `--fix`'s real blast radius is one mechanical case: inserting `- **Field**: TBD` placeholders
  for missing *metadata* fields. It never touches required sections, never edits existing prose.
- `skill_validate_task_artifacts` has zero test coverage today (confirmed by
  `test-skill-base-lifecycle.sh`'s own uncovered-residuals footer).

Two open items the research left for this plan are resolved below under Decisions.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the dispatch context and no roadmap phases are required.

## Decisions

**D-A: `--fix` remains in-place-mutating on the gate-out path.** (Resolves WORK item 3.)

Reasoning, on the merits rather than by default:

- The mutation is narrow, mechanical, and self-flagging. Verified against
  `validate-artifact.sh`'s fix block: it inserts a literal `- **Field**: TBD` line for a missing
  metadata field, anchored after the last existing metadata line, and does nothing else. It never
  fabricates prose and never touches required sections. `TBD` cannot masquerade as real content,
  so the mutation does not manufacture a false appearance of completeness.
- Every artifact under `specs/` is git-tracked, so the mutation's *content* was always auditable
  via `git diff`. What was genuinely missing is the task's own framing — "nothing anywhere
  recording that it was" — a record that a repair happened at all. That is a reporting gap, and
  reporting is what closes it.
- Disabling `--fix` here would convert every trivial missing-metadata-field omission into a hard
  stop requiring manual intervention in an otherwise-automated lifecycle step, a real ergonomics
  regression the acceptance criterion does not ask for.
- Residual risk carried forward explicitly: `validate-artifact.sh` conflates "fixed and now
  clean" with "fixed a field but a required *section* is still missing" — both exit 2. The report
  therefore surfaces the errors-remaining count *alongside* the fix count, so the second case is
  visible rather than reintroducing a narrower silence one field over.

**D-B: parse `validate-artifact.sh`'s existing summary line; do not modify that script.**
(Resolves the research's open D4 scope fork.)

Parsing stays inside the task's declared `file_scope` and touches a file with many consumers
zero times. The fragility the alternative was meant to remove is instead removed by pinning:
Phase 4 adds a regression test asserting all three summary-line shapes verbatim, so a future
wording change to `validate-artifact.sh` fails loudly in this suite rather than silently
degrading the counts to zero. That yields the same loud-on-drift guarantee at no blast radius.

**D-C: the report is both console and durable.** A stdout line alone is ephemeral in an
automated pipeline, and the stated hazard is precisely unrecorded mutation across automated runs.
Phase 3 therefore also emits one `specs/events.jsonl` row via the existing
`_events_append_observable` wrapper, mirroring the pattern `skill_validate_artifact` already
uses. This is additive and does not alter the console surface.

## Goals & Non-Goals

**Goals**:

- `skill_validate_task_artifacts` aggregates fix/error/warning counts across every artifact it
  sweeps and exposes them to its caller instead of discarding them.
- `command-gate-out.sh` prints an always-on report line naming all three counts, plus the paths
  of any auto-repaired artifacts.
- The same counts land in `specs/events.jsonl` as one durable, queryable row.
- Exit codes 3/4/5 (validation could not run) are never silently reported as zero.
- Both acceptance directions — nonzero repaired-field count, and zero — are demonstrated by a
  committed, fixture-driven regression test, not by manual inspection alone.
- The `--fix` decision (D-A) and its reasoning are recorded durably in the code, not only here.

**Non-Goals**:

- Modifying `validate-artifact.sh` (see D-B).
- Fixing the identical discard pattern in the sibling `skill_validate_artifact` (singular). It is
  off `command-gate-out.sh`'s path and outside this task's `file_scope`; Phase 6 files a durable
  follow-up note instead.
- Changing `--fix`'s blocking posture. Artifact validation stays non-blocking; the function
  continues to `return 0` unconditionally.
- Changing what `--fix` mutates, or adding new auto-repair capabilities.
- Any machine-readable JSON export of the counts beyond the events row.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Summary-line wording in `validate-artifact.sh` changes later, silently zeroing the counts | H | M | Phase 4 pins all three summary-line shapes in a regression test; drift fails loudly. Parsing is exit-code-anchored first, using message text only to extract numbers within an already-known shape |
| Exit 3/4/5 parsed as zero, hiding a validation-could-not-run state behind an all-clear report | H | M | The `case` default branch counts these as one error explicitly; Phase 4 covers a nonexistent-file case asserting a nonzero error count |
| `command-gate-out.sh` runs under `set -e`; a non-zero `validate-artifact.sh` exit could abort the gate | H | L | Capture via `out=$(...) || rc=$?`, which is `set -e`-safe; the function keeps its unconditional `return 0`. Phase 4 asserts gate-out still exits 0 on a repair |
| Stale globals leak across invocations, reporting a previous task's counts | M | L | All four globals are reset unconditionally at function entry, before any loop |
| Editing `.claude/**` instead of the source store, silently wiped on next deploy | H | L | Every phase edits `agent-system/extensions/core/**` only; Phase 5 deploys and verifies the deployed copy matches |
| New test suite fails to be picked up by the runner | M | L | `run-all.sh` glob-discovers `agent-system/extensions/*/scripts/tests/test-*.sh`; Phase 4 confirms discovery by running the runner, not just the file |
| Test suite mutates the real `specs/` tree or `state.json` | H | L | Follow `test-skill-base-lifecycle.sh`'s isolation contract: `mktemp -d` fixture repo, EXIT-trap cleanup, and a pre/post `specs/` status baseline assertion |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 6 | 3 |
| 5 | 5 | 4, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Propagate counts through skill_validate_task_artifacts [COMPLETED]

- **Goal:** `skill_validate_task_artifacts` captures each `validate-artifact.sh` invocation's
  stdout, parses its terminal summary line under exit-code discrimination, and aggregates the
  results into caller-visible globals — while preserving today's console output verbatim.

- **Tasks:**
  - [x] In `agent-system/extensions/core/scripts/skill-base.sh`, rewrite the body of
        `skill_validate_task_artifacts` to reset `SKILL_VALIDATE_FIXES`,
        `SKILL_VALIDATE_ERRORS`, `SKILL_VALIDATE_WARNINGS`, and `SKILL_VALIDATE_FIXED_FILES` at
        function entry (unconditionally, before the sweep loop) so no caller can read a stale
        value from a prior invocation.
  - [x] Replace the bare `if ! bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix
        2>/dev/null; then` invocation with a `set -e`-safe capture:
        `rc=0; out=$(bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null) || rc=$?`
        followed by `echo "$out"`, so the human-visible console log is byte-identical to today's.
  - [x] Parse `printf '%s\n' "$out" | tail -1` under a `case "$rc"` with four branches:
        `0` extracts the warning count; `1` extracts errors and warnings; `2` extracts the
        `[FIXED] N` fix count plus errors and warnings; the `*` default (exit 3/4/5,
        validation-could-not-run) sets one error explicitly and never falls through to zero.
  - [x] Default every extracted value with `${var:-0}` before arithmetic, then accumulate into
        the three aggregate globals.
  - [x] Append each file whose fix count is greater than zero to `SKILL_VALIDATE_FIXED_FILES` as
        a comma-joined path list.
  - [x] Enrich the existing non-blocking `WARNING` line with the per-file numbers
        (`N fixed, E error(s), W warning(s)`) instead of the current numberless string; keep it
        on stderr and keep it non-blocking.
  - [x] Keep the unconditional `return 0` — this function stays non-blocking.
  - [x] Add a comment block above the function recording D-A (why `--fix` stays in-place-mutating
        on this path) and D-B (why the summary line is parsed rather than
        `validate-artifact.sh` modified), so the reasoning is durable in the code and not only in
        this plan. Reference the research report by path, not by task number.
  - [x] Extend the function's existing header comment to document the four globals as its return
        channel, matching how `skill_preflight_update`'s globals are documented.

- **Timing:** 0.75 hours

- **Depends on:** none

- **Verification Tier:** interface

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase assumes `command-gate-out.sh` is the sole caller of
  `skill_validate_task_artifacts`, so adding globals breaks no other consumer. Confirm at
  implementation time with
  `grep -rn "skill_validate_task_artifacts" agent-system/extensions/ --include="*.sh" --include="*.md"`
  and verify every hit other than the definition and `command-gate-out.sh`'s invocation is a
  comment or documentation reference. If a second live caller exists, stop and re-scope — the
  new globals become a shared contract rather than a two-file one.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/skill-base.sh` — rewrite
    `skill_validate_task_artifacts` body, extend its header comment, add the decision comment
    block.

- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/skill-base.sh` parses clean.
  - Source the file in a scratch shell and confirm the four globals are set after a call against
    a temporary fixture directory containing one deliberately field-incomplete plan artifact
    (nonzero `SKILL_VALIDATE_FIXES`) and again against one valid artifact (zero).
  - Console output for an unchanged artifact is byte-identical to the pre-change output
    (`diff` of captured stdout before and after).

---

### Phase 2: Add the gate-out console report surface [COMPLETED]

- **Goal:** `command-gate-out.sh` prints an always-on report line — for the repaired *and* the
  clean case — immediately after the validation sweep, plus the repaired file paths when any
  exist.

- **Tasks:**
  - [x] In `agent-system/extensions/core/scripts/command-gate-out.sh`, extend the existing
        `if [ -d "$task_dir" ]; then skill_validate_task_artifacts "$task_dir"; fi` block to
        print, immediately after the call, a single always-on line of the form
        `[gate-out] Artifact validation for task N: F field(s) auto-repaired, E error(s), W warning(s) remaining.`
        using `${SKILL_VALIDATE_*:-0}` defaults.
  - [x] Emit a second line naming `${SKILL_VALIDATE_FIXED_FILES}` only when the fix count is
        greater than zero.
  - [x] Match the existing `[gate-out] ` prefix convention already used elsewhere in this file so
        the new line is greppable alongside the current announcements.
  - [x] Confirm the added lines are `set -e`-safe (no bare non-zero command in the block) — the
        script runs under `set -e` from its top.
  - [x] Update the block's `# Non-blocking artifact validation (link repair)` comment to state
        that the sweep is now instrumented and reports unconditionally.

- **Timing:** 0.5 hours

- **Depends on:** 1

- **Verification Tier:** local

- **Commit Mode:** per-substep

- **Files to modify:**
  - `agent-system/extensions/core/scripts/command-gate-out.sh` — report lines and comment update
    at the `skill_validate_task_artifacts` call site.

- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/command-gate-out.sh` parses clean.
  - Run the script against a scratch fixture task directory holding one repairable artifact and
    confirm stdout contains the report line with a nonzero fix count.
  - Repeat against a directory of valid artifacts and confirm the same line appears with zero.
  - Confirm the script's exit code is unchanged in both cases.

---

### Phase 3: Emit a durable events.jsonl record of the counts [COMPLETED]

- **Goal:** the same aggregate counts land as one row in `specs/events.jsonl`, so the record
  survives past a console scrollback in automated runs (D-C).

- **Tasks:**
  - [x] In `command-gate-out.sh`, after the report lines from Phase 2, call
        `_events_append_observable ".claude/scripts/events-append.sh"` with
        `--event-type artifact_auto_repair`, `--task "$task_number"`,
        `--session "$session_id"`, `--checkpoint gate_out`, a one-line `--message`, and
        `--detail-json` carrying the fix/error/warning counts and the repaired file list.
  - [x] Discriminate `--category`: `deviation` when the fix count or the error count is greater
        than zero, `milestone` otherwise — mirroring the status-discriminated category logic
        already in `skill_validate_artifact`.
  - [x] Build the `--detail-json` payload with `jq -c -n` and `--arg`/`--argjson`, never string
        concatenation, so a path containing a quote cannot produce malformed JSON.
  - [x] Confirm the call goes through `_events_append_observable` (already in scope via the
        sourced `skill-base.sh`) rather than invoking `events-append.sh` directly, so a missing
        or failing helper stays non-blocking and self-reporting.

- **Timing:** 0.5 hours

- **Depends on:** 2

- **Verification Tier:** local

- **Commit Mode:** per-substep

- **Files to modify:**
  - `agent-system/extensions/core/scripts/command-gate-out.sh` — events emission after the
    report lines.

- **Verification:**
  - `bash -n` parses clean.
  - Against an isolated fixture repo, run the gate-out block and confirm exactly one new
    `events.jsonl` line whose `event_type` is `artifact_auto_repair` and whose `detail` object
    carries the expected counts (`jq` assertion).
  - Confirm `category` is `deviation` for the repaired fixture and `milestone` for the clean one.
  - Confirm gate-out still exits 0 when `events-append.sh` is absent (rename it in the fixture
    and re-run).

---

### Phase 4: Fixture-driven regression suite, both directions [NOT STARTED]

- **Goal:** a new committed test suite proves the nonzero and the zero direction from the same
  code path, pins the three `validate-artifact.sh` summary-line shapes, and covers the
  validation-could-not-run branch — closing the zero-coverage gap this function has today.

- **Tasks:**
  - [ ] Create `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`,
        modeled structurally on `test-skill-base-lifecycle.sh`: `mktemp -d` workdir with an
        EXIT-trap cleanup, deploy-tree-first / source-store-fallback candidate resolution,
        `pass()`/`fail()`/`info()` helpers with integer counters, exit 0 all-pass / 1 any-fail /
        2 environment error.
  - [ ] Adopt that suite's isolation contract verbatim: build an isolated fixture repo under the
        workdir, `cd` into it before exercising anything that uses the bare relative
        `.claude/scripts/...` paths, and assert a pre/post `git status --porcelain specs/`
        baseline so the real `specs/` tree is provably untouched.
  - [ ] Case: **repaired direction** — a plan artifact missing a required metadata field produces
        `SKILL_VALIDATE_FIXES` greater than zero and a gate-out report line naming that nonzero
        count.
  - [ ] Case: **clean direction** — a fully valid artifact produces zero fixes and a report line
        naming zero. Assert the line is *present*, not merely that no error occurred; a report
        that only appears on repair fails the acceptance criterion.
  - [ ] Case: **multi-file aggregation** — two repairable artifacts across two subdirectories sum
        correctly and both paths appear in `SKILL_VALIDATE_FIXED_FILES`.
  - [ ] Case: **errors-remaining alongside fixes** — an artifact that gets a metadata field fixed
        while a required *section* is still missing reports nonzero fixes *and* nonzero errors,
        pinning the exit-2 conflation named in D-A's residual-risk bullet.
  - [ ] Case: **validation could not run** — a type or path that drives exit 3/4/5 yields a
        nonzero error count, never a silent zero.
  - [ ] Case: **no stale globals** — a call over a repairable fixture followed by a call over a
        clean fixture reports zero on the second call.
  - [ ] Case: **summary-line format pinning** — assert `validate-artifact.sh`'s three terminal
        shapes match their expected patterns (`^\[FIXED\] [0-9]+ field\(s\) auto-repaired`,
        `^\[PASS\] `, `^\[FAIL\] [0-9]+ error`), so a future wording change fails here loudly
        rather than degrading counts to zero (D-B's mitigation).
  - [ ] Case: **events row** — the repaired direction appends exactly one
        `artifact_auto_repair` row with the matching counts in its `detail` object.
  - [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and confirm the new
        suite is glob-discovered and passes alongside the existing suites.
  - [ ] Update `test-skill-base-lifecycle.sh`'s "Residual (uncovered)" footer to remove
        `skill_validate_task_artifacts`, which is no longer uncovered, and to point at the new
        suite.

- **Timing:** 1.5 hours

- **Depends on:** 3

- **Verification Tier:** full

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase asserts eight test cases in one new file plus a one-line
  footer edit to `test-skill-base-lifecycle.sh`. Confirm at implementation time by running
  `run-all.sh` and reading its per-suite result table: the new suite must appear, and the total
  suite count must increase by exactly one. If a fixture cannot be constructed for a listed case
  (most likely the exit-3/4/5 branch, whose triggers are environmental), record it as a reasoned
  exclusion with evidence rather than silently dropping it.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` — new suite.
  - `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — residuals footer
    correction only.

- **Verification:**
  - The new suite exits 0 standalone.
  - `run-all.sh` exits 0 with the new suite listed.
  - Temporarily reverting Phase 1's parsing (in a scratch copy, not committed) makes the new
    suite fail — proving the tests actually exercise the new code rather than passing vacuously.
  - `git status --porcelain specs/` is unchanged after a full suite run.

---

### Phase 5: Deploy and demonstrate both directions live [NOT STARTED]

- **Goal:** the source-store changes are deployed into `.claude/`, and both acceptance directions
  are demonstrated against a real gate-out invocation, not only against test fixtures.

- **Tasks:**
  - [ ] Run `bash .claude/scripts/deploy-headless.sh` so the edited
        `agent-system/extensions/core/**` files land in `.claude/scripts/`.
  - [ ] Run `bash .claude/scripts/verify-deploy.sh --findings` and confirm no new findings
        relative to the pre-change baseline (capture the baseline before deploying).
  - [ ] Confirm the deployed `.claude/scripts/skill-base.sh` and
        `.claude/scripts/command-gate-out.sh` byte-match their source-store originals for the
        changed regions (`diff` the two pairs).
  - [ ] **Demonstration A (nonzero):** against a scratch task directory containing an artifact
        with a deliberately removed metadata field, invoke `command-gate-out.sh` and capture the
        report line showing a nonzero repaired-field count. Record the verbatim line.
  - [ ] **Demonstration B (zero):** against a scratch task directory of valid artifacts, invoke
        `command-gate-out.sh` and capture the report line showing zero. Record the verbatim line.
  - [ ] Confirm each demonstration appended the expected `artifact_auto_repair` row, and remove
        any scratch rows the demonstration wrote to the real `specs/events.jsonl` if the
        demonstration was not fully isolated.
  - [ ] Confirm the scratch directories are removed and `git status` shows no stray fixture
        files.
  - [ ] Capture both verbatim report lines for the implementation summary — they are the
        evidence the acceptance criterion demands.

- **Timing:** 0.75 hours

- **Depends on:** 4, 6

- **Verification Tier:** full

- **Commit Mode:** per-substep

- **Files to modify:**
  - None in the source store. This phase deploys and demonstrates; `.claude/**` is written only
    by `deploy-headless.sh`, which is the sanctioned deploy process and not a boundary
    violation.

- **Verification:**
  - `verify-deploy.sh --findings` introduces no new findings.
  - Both demonstration lines are captured verbatim, one with a nonzero count and one with zero.
  - `git status --porcelain` shows no untracked fixture residue.

---

### Phase 6: Document the instrumented sweep and file the sibling follow-up [NOT STARTED]

- **Goal:** the lifecycle documentation reflects that Stage 6a's directory sweep is now
  instrumented, and the identical unfixed defect in the sibling `skill_validate_artifact` is
  recorded durably instead of being rediscovered from scratch later.

- **Tasks:**
  - [ ] Update the Stage 6a row in
        `agent-system/extensions/core/context/patterns/skill-lifecycle.md` to state that
        `skill_validate_task_artifacts` now reports aggregate fix/error/warning counts through
        caller-visible globals, naming the four global names.
  - [ ] Add a short subsection to the same file (or the nearest appropriate context file)
        recording D-A: `--fix` remains in-place-mutating on the gate-out path, with the
        one-paragraph reasoning, so the decision is discoverable by a future reader who does not
        have this plan open.
  - [ ] Record the known, deliberately-out-of-scope gap: `skill_validate_artifact` (singular,
        used by ordinary per-command postflight) has the same discard-the-counts pattern and can
        adopt this task's aggregation approach directly. Reference the pattern by file and
        function name.
  - [ ] Verify no task-number references appear in any file touched outside `specs/**` — cite
        the research report by path where provenance is needed.
  - [ ] Run `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) over
        the changed files and confirm it passes.

- **Timing:** 0.5 hours

- **Depends on:** 3

- **Verification Tier:** prose

- **Commit Mode:** per-substep

- **Files to modify:**
  - `agent-system/extensions/core/context/patterns/skill-lifecycle.md` — Stage 6a row, D-A
    record, and the sibling-gap note.

- **Verification:**
  - The Stage 6a row names all four globals.
  - The task-reference lint passes over every changed non-`specs/` file.
  - No emoji introduced (per the repository's character-encoding policy).

---

## Testing & Validation

- [ ] `bash -n` passes on `skill-base.sh` and `command-gate-out.sh`.
- [ ] `test-gate-out-repair-reporting.sh` exits 0 standalone.
- [ ] `run-all.sh` exits 0 with the new suite discovered and the total suite count up by one.
- [ ] Reverting the Phase 1 parsing in a scratch copy makes the new suite fail (non-vacuous
      tests).
- [ ] The nonzero direction produces a report line with a fix count greater than zero.
- [ ] The zero direction produces a report line reading zero — present, not omitted.
- [ ] Exit 3/4/5 produces a nonzero error count, never a silent zero.
- [ ] A repaired-plus-still-erroring artifact reports nonzero fixes *and* nonzero errors in the
      same line.
- [ ] A second call after a repairing call reports zero (no stale globals).
- [ ] Exactly one `artifact_auto_repair` events row per gate-out run, with matching counts.
- [ ] `command-gate-out.sh`'s exit code is unchanged in every case.
- [ ] Console output for an unrepaired artifact is byte-identical to the pre-change output.
- [ ] `verify-deploy.sh --findings` introduces no new findings after deployment.
- [ ] `git status --porcelain specs/` is unchanged by a full test run.
- [ ] The task-reference lint passes on all changed non-`specs/` files.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` — instrumented
  `skill_validate_task_artifacts` with four caller-visible count globals and the recorded D-A/D-B
  reasoning.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — always-on console report line,
  repaired-paths line, and durable `artifact_auto_repair` events emission.
- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` — new
  fixture-driven regression suite covering both acceptance directions.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — residuals footer
  corrected.
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` — Stage 6a documentation,
  D-A record, sibling-gap note.
- `specs/013_instrument_gate_out_auto_repair_reporting/summaries/01_gate-out-repair-reporting-summary.md`
  — implementation summary carrying both verbatim demonstration lines as acceptance evidence.

## Rollback/Contingency

All changes are confined to five files in the source store plus one regenerated deploy tree, with
no schema, state, or data migration.

- **Per-phase rollback:** each phase is a separate commit; `git revert` of that commit restores
  the prior behavior. Reverting Phase 1 alone would leave Phase 2's report line reading zeros via
  its `:-0` defaults rather than erroring, so revert Phases 1-3 together if reverting at all.
- **Deploy rollback:** re-run `bash .claude/scripts/deploy-headless.sh` after the revert to
  restore `.claude/` from the reverted source store. Never hand-edit `.claude/**` to undo a
  change.
- **Contingency if summary-line parsing proves unworkable** (for instance, a wording shape the
  three-branch `case` cannot cover): fall back to the research's D4 alternative — add one stable,
  additive machine-readable line to `validate-artifact.sh` and parse that instead. This widens
  `file_scope` by one file; record the deviation and its reasoning in the implementation summary
  rather than making the change silently.
- **Contingency if the events emission destabilizes gate-out:** Phase 3 is independently
  revertible; the console report from Phase 2 satisfies the acceptance criterion on its own, so
  dropping the events row degrades durability without failing acceptance.
