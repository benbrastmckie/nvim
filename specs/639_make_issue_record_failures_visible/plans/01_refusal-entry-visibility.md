# Implementation Plan: Task #639

- **Task**: 639 - Make issue-record.sh failures visible instead of silently losing the evidence entry
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/639_make_issue_record_failures_visible/reports/01_issue-record-failure-visibility.md
- **Artifacts**: plans/01_refusal-entry-visibility.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

`scripts/issue-record.sh` refuses an invocation carrying an unrecognized flag with
`error: unknown argument: ...` on stderr and `exit 1`, and the invocation form its own header
prescribes (`>/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2`) discards
that stderr before the caller's fallback note fires — so the intended evidence entry is dropped
with no signal distinguishable from any other refusal. This plan makes the dropped entry
*recoverable rather than merely announced*: on the unknown-flag path the script self-records a
refusal entry into the very `issues.jsonl` the conclusion stage already reads, carrying the
offending flag and the caller's own `--what-happened` prose verbatim, and exits with a new,
distinct code `2` that separates an argument-shaped refusal from every content-shaped one.
Definition of done: all five acceptance criteria in the task description hold, the full
`test-issue-record.sh` suite is green against the edited source-store copy, and the deployed tree
has been regenerated so a default-mode suite run is non-vacuous.

### Research Integration

The research report (`reports/01_issue-record-failure-visibility.md`) is integrated in full: its
call-site survey (every call site uses the fully-redirected non-fatal form; the only *hand-typed*
surface is the agent-facing template `orchestrate-build-dispatch.sh` renders), its confirmation
that no existing suite case exercises an argument-shaped failure, and its ranked assessment of
the three candidate fixes. This plan adopts its recommended candidate (2) — separate the
argument-shaped refusal by exit code and give it a signal the caller's redirection cannot reach
— with one deliberate substitution for the signal's destination, recorded under `## Decisions`.
Its candidate (1) (flag aliasing) and candidate (3) (contract-wide stderr unswallowing) are
declined, each with grounds under `## Decisions`.

**Premise re-validation (Carried-Figure Discipline).** Every trigger-class figure in the
description was re-checked against the live source store at plan time, independently of the
research report:

- **Confirmed, with drifted line numbers.** The defect is live. The parsing arm for `--session`
  is at `issue-record.sh:146` (description: 139); the `*)` unknown-argument arm that prints
  `error: unknown argument` and calls `usage()` is at line 148 (description: 141); the
  invocation-contract comment is at lines 59-62 (description: 52-55); the documented exit codes
  are at lines 64-67. `usage()` ends in `exit 1` at line 106. The agent-facing template is
  rendered at `orchestrate-build-dispatch.sh:922-926` (description: 578). All drift is from
  unrelated header-comment growth, exactly as the research report found — the mechanism itself is
  unchanged.
- **Confirmed unchanged in substance, re-enumerated rather than trusted.** The description's
  per-call-site line citations (`git-commit-phase.sh:268`, `orchestrate-cycle-plan.sh:1666`/`1691`,
  `orchestrate-cycle-postflight.sh:1042`…`1866`) have all drifted; the *claim* they support —
  every in-repo call site uses the fully-redirected non-fatal form — re-verified true.
- **Confirmed.** `issue-record.sh` has exactly one non-zero exit code today. Seventeen `exit 1`
  sites exist; exactly four of them are reachable refusals that this plan must make
  refusal-aware (line 106 in `usage()`, and lines 369, 374, 382 in the task-directory resolution
  block).
- **Confirmed.** `scripts/tests/test-issue-record.sh` (cases a–v, 600 lines) has no
  argument-shaped failure case; case (i) covers only a content-shaped one.
- **Confirmed, and it removes a step the description assumed.** The description states
  `issue-record.sh` "is NOT runnable from the source store … so deploy into a tree before
  exercising it". True of direct invocation, but `test-issue-record.sh` resolves its subject
  through `common_test_resolve_subject "…" "deploy-tree-first"`, which honours
  `CORE_TEST_SUBJECT_MODE=source-store` — so the edited source-store copy can be exercised in a
  scratch `.claude/scripts/` mirror with no deploy at all. A deploy is still scheduled (Phase 4),
  for a different reason: without it, a *default-mode* run of the suite resolves the stale
  deployed copy and the new cases fail.

### Prior Plan Reference

No prior plan. This is round 1 for this task.

### Roadmap Alignment

This dispatch carried no `roadmap_path` and no `roadmap_flag`; no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- An invocation naming a flag `issue-record.sh` does not recognize produces a diagnostic
  attributable to that specific flag, through a channel the prescribed `>/dev/null 2>&1`
  redirection cannot reach, with no call site's invocation text changed (criterion 1).
- The caller's own exit status is still unaffected by any recording failure, argument-shaped or
  not (criterion 2).
- A distinct exit code separates an argument-shaped refusal (the caller's invocation does not
  match this script's interface) from every content-shaped one (the caller's intended content was
  itself invalid).
- A regression case covers the mistyped-flag path under the exact documented redirected form
  (criterion 3).
- `issue-record.sh`'s own header contract and `context/formats/issue-log.md` both describe the
  implemented behaviour (criterion 4).
- The full `test-issue-record.sh` suite passes (criterion 5), and passes in default (deployed)
  subject-resolution mode too, not only against the source store.

**Non-Goals**:

- Aliasing `--session-id` to `--session`, or any other specific misspelling. See `## Decisions`.
- Changing the prescribed invocation form at the ~20 programmatic call sites, or the
  `>/dev/null 2>&1` shape in `git-commit-phase.sh`, `orchestrate-cycle-plan.sh`, or
  `orchestrate-cycle-postflight.sh`. Those three files are in this task's declared `file_scope`
  but are deliberately left unedited. See `## Decisions`.
- Making the conclusion stage, postflight, or any other reader treat a refusal entry specially.
  The refusal entry is an ordinary `issues.jsonl` line, read by the existing consumer with no
  consumer change; `scripts/orchestrate-conclusion-aggregate.sh` is untouched.
- Changing the "refuses with nothing written" guarantee for any refusal class other than the
  unknown-flag one.
- Promoting `index-entries.json`'s Rule R `line_count` check from advisory to blocking, or any
  other change to `check-extension-docs.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A refusal entry is written where the script previously wrote nothing, so an existing "writes nothing" assertion regresses | M | L | Refusal mode is entered *only* on the unknown-flag path; every other refusal keeps its current write-nothing/exit-1 behaviour byte for byte. Phase 2 re-runs cases (a)–(v) unchanged as the control. |
| A second, content-shaped error on the same invocation (malformed `--tags-json`, non-integer `--dispatch-seq`) refuses before the refusal entry can be appended | M | M | In refusal mode the script discards every optional field it does not need for the refusal entry (including the caller's raw `--tags-json`, preserved only as a JSON *string* inside `tags`), so no content-shaped validation can fire on that path. Phase 2 case (y) covers it. |
| The offending flag precedes `--task-dir`/`--task`, so no task directory resolves and no entry can be appended | L | M | Unavoidable by construction, and documented as a stated residual: that case still exits 2 (argument-shaped) with stderr only. The cited `275` scenario (`--session-id` after `--task-dir`) is covered. |
| New suite cases fail in default subject-resolution mode until the deployed tree is regenerated | H | H | Phase 4 regenerates the deployed tree and re-runs the suite in default mode as its own verification. Phases 1-2 use `CORE_TEST_SUBJECT_MODE=source-store` explicitly and never claim a default-mode green. |
| `verify-touched.sh` run before the redeploy reports a vacuous green (its suites resolve the stale deployed copy) | M | H | No phase before Phase 4 names `verify-touched.sh` as its covering check; Phases 1-3 name the specific suite invocation that actually exercises the edited source. Phase 4 runs `verify-touched.sh` only *after* the redeploy. |
| The added template line in `orchestrate-build-dispatch.sh` becomes a new per-cycle-varying line and silently inerts the IDENTICAL DISPATCH HALT (the failure mode that file's own FORWARD-POINTER comment at lines 911-921 records) | H | L | The added line is static text with no `${...}` interpolation. Phase 3 verifies this by grep and leaves `cycle_plan_dispatch_hash()`'s strip pattern untouched. |
| Editing `context/formats/issue-log.md` drifts `index-entries.json`'s `line_count` for that entry | L | H | Phase 3 declares `index-entries.json` in its own `Files to modify` and regenerates it in the same phase. (`check-extension-docs.sh` Rule R is advisory by default — `INDEX_TRUTH_GATE_MODE` — so this is a declaration-and-regenerate obligation, not a gate unblock.) |
| Concurrent siblings this cycle (693 implement with `__WHOLE_TREE__`; 697, 645 plan) touch a file this task owns | M | L | 697 and 645 declare only unrelated test files; 693's `__WHOLE_TREE__` could in principle reach anything. Re-read each target file immediately before editing, stage only this task's own hunks with an explicit file list, never a directory or glob add, and never run `git-snapshot.sh` in its reverting default mode. |
| The migration-provenance territory list in the task description (20 overlapping records) is acted on as live contention | L | L | Superseded: research checked all of them against `specs/state.json` and every one is `completed`. Do not serialize against them. |

## Decisions

- **Chosen fix: the research report's candidate (2), with the refusal entry written into
  `issues.jsonl` itself rather than into a sibling breadcrumb file.** The task description
  sanctions "a breadcrumb written beside the task's `issues.jsonl`"; this plan writes a
  schema-valid refusal *entry* into `issues.jsonl` instead, for three grounds. (a) It answers the
  description's own statement of harm directly — "an empty `issues.jsonl` is indistinguishable
  from a dispatch that genuinely had nothing to record" — by making the refusal visible in the
  exact file that indistinguishability was measured on. (b) It is read by an existing consumer
  (`scripts/orchestrate-conclusion-aggregate.sh`) with no consumer change, where a breadcrumb
  file would be a new artifact nothing reads — relocating the silence rather than ending it.
  (c) It introduces no new task-directory runtime file, so it needs no entry in
  `context/standards/orchestrator-runtime-files.md`'s registry or its gitignore block (a file
  outside this task's declared `file_scope`) and no change to
  `scripts/tests/test-runtime-file-tracking.sh` (a file a concurrent sibling declares). The
  entry preserves the caller's own `--what-happened` prose, so the evidence is recovered, not
  merely reported lost.
- **Declined: candidate (1), accepting both flag spellings.** It fixes one historically-observed
  typo and leaves every other mistyped flag exactly as silent, against the description's explicit
  framing ("THE DEFECT IS THE SILENCE, NOT THE FLAG NAME"). It also trades a visible error for
  silent acceptance of a flag name no contract documents, which makes the *next* divergence
  harder to see rather than easier.
- **Declined: candidate (3), revising the prescribed invocation form so stderr survives.** It
  would propagate across ~20 call sites in three scripts plus `context/formats/issue-log.md`,
  `scripts/issue-record.sh`'s header, and `context/contracts/phase-closure.md:225` — the last of
  which is outside this task's declared `file_scope`, so a complete rollout would require a scope
  extension and a partial one would reintroduce precisely the inconsistency criterion (4) exists
  to prevent. It would also surface the deliberate `--class` leniency warnings on every
  *successful* programmatic recording, in every orchestrate run.
- **Adopted from candidate (3) at the one surface where it costs nothing: a discoverability
  pointer, not a redirection change.** The one hand-typed surface research identified is the
  agent-facing template `orchestrate-build-dispatch.sh` renders. Phase 3 adds one static sentence
  there telling an agent whose fallback note fires to look for a refusal entry in the task's own
  `issues.jsonl`. The redirection in the rendered template is left as `>/dev/null 2>&1`.
- **Exit code `2` means exactly one thing: "the invocation named a flag this script does not
  recognize."** It is emitted whether or not the refusal entry was successfully appended, so the
  code is a reliable discriminator for the regression test and for any future caller, while the
  appended entry — not the exit code — is what survives the caller's output redirection.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Refusal Mode, Exit Code 2, and the Self-Recorded Refusal Entry [NOT STARTED]

**Goal**: `issue-record.sh` responds to an unrecognized flag by appending one schema-valid
refusal entry to the resolved task's `issues.jsonl` (naming the offending flag and preserving the
caller's own `--what-happened` prose) and exiting `2`, with every other refusal class unchanged,
and with the script's own header contract updated to match.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/issue-record.sh` immediately before editing
      (concurrent-sibling discipline) and re-confirm the four refusal sites the Scope Hypothesis
      names via `grep -n 'exit 1' agent-system/extensions/core/scripts/issue-record.sh`.
- [ ] Replace the `*)` arm of the parse loop (line 148) so it records the offending token in a new
      `unknown_arg` variable, prints the existing `error: unknown argument: $1` line to stderr,
      and stops parsing (`break`) instead of calling `usage()`. Leave the `-h|--help` arm exactly
      as it is — a usage request is not a dropped entry and keeps exit 1.
- [ ] Immediately after the parse loop, when `unknown_arg` is non-empty, enter refusal mode:
      force `kind_arg=issue`, `class_arg="knowledge-capture gap"` (a seed class whose gloss is
      precisely "a durable knowledge-capture step … produced nothing", and one already precedented
      as emitted by a mechanical writer), `severity_arg=minor`; synthesize `what_happened_arg` as
      generated prose naming the offending flag and quoting the caller's own `--what-happened`
      value verbatim when one was parsed (and saying explicitly that none was, when not); and
      clear every remaining optional field (`evidence_path`, `cost_value`, `cost_unit`,
      `resolution`, `suggested_channel`, and the caller's raw `--tags-json`, which is retained
      only as a JSON *string* for the refusal tags). Keep `--task-dir`/`--task`, `--phase`, and
      `--session`; clear `--dispatch-seq` unless it is already a bare integer. This ordering is
      what makes every downstream validation pass on the refusal path without reordering a single
      existing validation block.
- [ ] Build the refusal entry's `tags` as `{"issue_record_refusal": {...}}` carrying at least the
      offending flag and the raw `--tags-json` string when one was given — the open `tags` seam
      `context/formats/issue-log.md` documents, requiring no schema change.
- [ ] Make the four refusal sites refusal-aware so an argument-shaped refusal never exits 1:
      `usage()`'s own `exit 1` (line 106) and the three inline `exit 1` sites in the
      task-directory resolution block (lines 369, 374, 382). A small helper that exits 2 when
      `unknown_arg` is set and 1 otherwise is sufficient; do not convert the content-shaped
      validation sites.
- [ ] At the append site, keep the existing `jq -c -n` build and the `flock`-guarded append
      unchanged, then branch after the append: in refusal mode, print nothing to stdout (the
      stdout-is-the-entry_id contract is for success only), emit a stderr line naming the
      offending flag and the appended `entry_id`, and `exit 2`.
- [ ] Leave `central_log_promote` on its existing unconditional, best-effort path — a refusal
      entry is `kind: issue` and is promoted like any other; do not special-case it.
- [ ] Update the header block in the same file: the invocation-contract comment (lines 59-62) to
      state that an argument-shaped refusal self-records rather than vanishing under the
      prescribed redirection, and the exit-code block (lines 64-67) to document `2` alongside
      `0`/`1`, including the stated residual (a mistyped task-resolution flag resolves no task
      directory, so it exits 2 with stderr only and appends nothing). Add the new code to
      `usage()`'s own "Exit codes:" line too.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-issue-record.sh` is the only check that exercises the edited source-store copy before a redeploy (the fifteen further suites `suite_selection_select` resolves for this path — `test-central-log-lib.sh`, `test-dispatch-metrics.sh`, `test-git-commit-phase.sh`, `test-git-commit-scoped.sh`, `test-orchestrate-batch-admit.sh`, `test-orchestrate-build-dispatch.sh`, `test-orchestrate-conclusion-aggregate.sh`, `test-orchestrate-conclusion-roadmap.sh`, `test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`, `test-postflight-sapience-notes.sh`, `test-redeploy-remedy-lib.sh`, `test-run-task-observers.sh`, `test-sapience-capture.sh`, `test-scope-excursion-record-lib.sh` — resolve this script deploy-tree-first and so would validate the stale deployed copy, and are discharged by Phase 4's post-redeploy `verify-touched.sh` run instead).

**Scope Hypothesis**: this phase's edit is confined to `issue-record.sh`, and exactly four of its
seventeen `exit 1` sites need to become refusal-aware (line 106 in `usage()`; lines 369, 374, 382
in the task-directory resolution block). Confirm at implementation time with
`grep -n 'exit 1' agent-system/extensions/core/scripts/issue-record.sh` before editing; if the
reachable-refusal set is larger, make every member refusal-aware and record the corrected count
in the phase's verification notes.

**Files to modify**:
- `agent-system/extensions/core/scripts/issue-record.sh` - refusal-mode plumbing, forced refusal-entry field values, refusal-aware exits (code 2), post-append refusal branch, header invocation-contract and exit-code documentation

**Verification**:
- `bash -n agent-system/extensions/core/scripts/issue-record.sh` parses clean.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-issue-record.sh` exits 0 with every existing case (a)–(v) still passing — case (i) in particular, the existing control for "non-fatal under redirection".
- A one-off manual exercise against a throwaway scratch tree built the same way the suite's
  `build_scratch` does (never a live task's `issues.jsonl` — `issue-log.md` forbids that
  explicitly): invoking with `--task-dir <scratch task> … --session-id sess_x` exits 2, appends
  exactly one line whose `tags.issue_record_refusal` names `--session-id` and whose
  `what_happened` contains the caller's own prose, and prints nothing on stdout.
- The same invocation wrapped in the documented form
  (`… >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2`) leaves the
  caller's exit status 0.

---

### Phase 2: Regression Cases for the Argument-Shaped Refusal [NOT STARTED]

**Goal**: `test-issue-record.sh` proves mechanically that a mistyped flag under the documented
redirected form is non-fatal to the caller *and* leaves an attributable record, and that the new
exit code is distinct from the content-shaped one.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-issue-record.sh` immediately
      before editing, and append new cases after case (v) without modifying any existing case.
- [ ] Case (w) — mistyped flag under the documented non-fatal form (criteria 1-3): invoke
      `run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" … --session-id sess_x` wrapped
      in the exact documented form; assert the caller's exit stays 0, that `issues.jsonl` gained
      exactly one line, that the line's `tags.issue_record_refusal` names `--session-id`, and
      that its `what_happened` carries the caller's own prose.
- [ ] Case (x) — exit-code discrimination: the same mistyped-flag invocation called directly
      exits exactly 2, while a content-shaped refusal (reuse case (i)'s nonexistent `--task-dir`,
      or an invalid `--severity`) still exits exactly 1 and still writes nothing.
- [ ] Case (y) — refusal mode is not derailed by an unrelated optional-field error: a mistyped
      flag given alongside a malformed `--tags-json` (or a non-integer `--dispatch-seq`) parsed
      *before* it still appends exactly one refusal entry and still exits 2.
- [ ] Case (z) — stated residual: a mistyped flag that prevents task resolution (e.g.
      `--task-dirr <path>` as the only task-resolution attempt) exits 2, appends nothing, and
      still leaves a documented-form caller at exit 0.
- [ ] Keep every assertion inside the per-case scratch tree; write nothing to a live task's
      `issues.jsonl`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-issue-record.sh` is both the edited file and its own covering check (the seven further suites `suite_selection_select` resolves for this path — `test-central-log-lib.sh`, `test-dispatch-metrics.sh`, `test-orchestrate-conclusion-aggregate.sh`, `test-redeploy-remedy-lib.sh`, `test-run-task-observers.sh`, `test-sapience-capture.sh`, `test-scope-excursion-record-lib.sh` — cannot pass against the stale deployed `issue-record.sh` these new cases exercise, so they are discharged by Phase 4's post-redeploy `verify-touched.sh` run instead).

**Scope Hypothesis**: four new cases (w, x, y, z) are added and zero existing cases are modified,
so the suite's passing count rises by exactly four. Confirm by comparing the `=== Results: N
passed` line against a pre-edit baseline run captured before the first edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` - four appended cases (w) mistyped flag under the documented form, (x) exit-code discrimination 2 vs 1, (y) refusal mode under a concurrent optional-field error, (z) unresolvable-task-directory residual

**Verification**:
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-issue-record.sh` exits 0, and its `=== Results:` line shows exactly four more passes than the pre-edit baseline with zero failures.
- Each new case is confirmed to fail against the pre-Phase-1 behaviour (temporarily point
  `CORE_TEST_SUBJECT_MODE` at the deployed, still-stale copy, or stash the Phase 1 edit in a
  scratch copy) — a case that passes either way is a vacuous pass, not a regression test.

---

### Phase 3: Documentation Parity and the Agent-Facing Discoverability Pointer [NOT STARTED]

**Goal**: `context/formats/issue-log.md` and the rendered agent-facing invocation template agree
with the implemented behaviour, and the index entry's derived `line_count` is regenerated in the
same change that moves it.

**Tasks**:

- [ ] Re-read each target file immediately before editing.
- [ ] In `context/formats/issue-log.md`'s "CAPTURE ONLY — A Hard Boundary" section, extend the
      "**Recording is always non-fatal.**" bullet (lines 57-59) to state that an argument-shaped
      refusal (an unrecognized flag) is self-recorded as an ordinary entry carrying
      `tags.issue_record_refusal`, and that the caller's exit status is still unaffected.
- [ ] Add a short subsection documenting the refusal entry's shape — `kind: issue`,
      `class: knowledge-capture gap`, `severity: minor`, the `tags.issue_record_refusal` keys —
      and exit code `2`, cross-referencing "The `tags` Seam" rather than duplicating it. State the
      residual (a mistyped task-resolution flag appends nothing and exits 2 with stderr only).
- [ ] Note in that subsection that a refusal entry is an ordinary line to every reader: the
      conclusion stage's `group_by(.class)` read-side grouping handles it with no consumer change,
      and nothing special-cases it.
- [ ] In `scripts/orchestrate-build-dispatch.sh`'s rendered `## Issue Log` block, add one static
      sentence after the invocation template (after the line ending
      `"Note: issue recording failed (non-fatal)\" >&2"`, before the `kind: win` paragraph)
      telling an agent whose fallback note fires to look in the task's own `issues.jsonl` for a
      refusal entry naming the mistyped flag, and to re-run with corrected flags. Leave the
      template's own `>/dev/null 2>&1` redirection unchanged.
- [ ] Regenerate the derived index `line_count` for the edited context file:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`,
      then review the diff to confirm only `line_count` values changed.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` covers the only non-prose edit here and resolves `orchestrate-build-dispatch.sh` from the source store by hard requirement (`mode=source-store`), so it validates the edited copy without a deploy, while the fourteen further suites `suite_selection_select` resolves for this phase's paths — among them the deployed-vs-source comparators `test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, `test-roadmap-command-registration.sh`, `test-force-phases.sh`, `test-orchestrate-build-aux-dispatch.sh`, `test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`, `test-orchestrate-record-decision.sh`, `test-orchestrate-recover-message-findings.sh`, `test-orchestrate-unwind-dispatch.sh`, `test-routing-resolution.sh` — would read a deployed tree this phase has deliberately not yet regenerated and are discharged by Phase 4's post-redeploy `verify-touched.sh` run instead.

**Scope Hypothesis**: the template addition is one static line containing no `${...}`
interpolation, so `cycle_plan_dispatch_hash()`'s per-cycle-varying strip pattern needs no change
(the failure mode that function's FORWARD-POINTER comment at `orchestrate-build-dispatch.sh:911-921`
records). Confirm with `grep -n '\${' ` over the added hunk before committing; if the added text
does carry interpolation, extend the strip pattern in this same phase and add the matching
`test-orchestrate-cycle-plan.sh` Group 27 fixture rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/context/formats/issue-log.md` - non-fatal bullet extended; new subsection documenting the refusal entry's shape, exit code 2, and the stated residual
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - one static sentence in the rendered `## Issue Log` block pointing a dispatched agent at the refusal entry
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` for the `formats/issue-log.md` entry (derived from the edit above; `check-extension-docs.sh` Rule R)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0 (its `## Issue Log` assertions are `assert_contains`, so an added line is compatible by construction — confirm, do not assume).
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` exits 0, Group 27 Case F included.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh` (check mode) reports no drift.
- `grep -n '\${' ` over the added template hunk returns nothing.
- The three declined call-site files (`git-commit-phase.sh`, `orchestrate-cycle-plan.sh`,
  `orchestrate-cycle-postflight.sh`) are confirmed unmodified (`git status --short`) — their
  presence in `file_scope` is deliberate reservation, not an edit obligation.

---

### Phase 4: Redeploy and Default-Mode Verification [NOT STARTED]

**Goal**: the deployed tree matches the edited source store, so the suite and every narrowed gate
run is non-vacuous in its default subject-resolution mode, and the task's full gate obligation is
discharged or explicitly deferred.

**Tasks**:

- [ ] Confirm Phases 1-3 are committed and `git status --short` shows no unexpected foreign
      modification (concurrent-sibling discipline: a foreign commit or in-flight edit is reported,
      not dismissed).
- [ ] Regenerate the deployed tree: `bash .claude/scripts/deploy-headless.sh`. This also re-runs
      `generate-context-line-counts.sh --write` automatically, idempotently with Phase 3.
- [ ] Re-run `bash .claude/scripts/tests/test-issue-record.sh` in default (deploy-tree-first)
      subject mode — with no `CORE_TEST_SUBJECT_MODE` set — and confirm all cases including the
      four new ones pass against the deployed copy. This is the acceptance-criterion-5 run.
- [ ] Exercise the deployed script once by hand against a throwaway scratch task directory
      (never a live task's `issues.jsonl`) to confirm the end-to-end behaviour the description's
      criterion 1 names: the documented invocation form, a mistyped flag, a visible refusal entry.
- [ ] Run the scoped touched-path check over this task's own touched paths and record its verdict
      in the phase's verification notes, together with the explicit deferral of the complete gate
      set to the orchestration close.

**Timing**: 45 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration (`deploy-headless.sh`); the deployed `.claude/**` tree is gitignored and is never named directly
- `agent-system/extensions/core/index-entries.json` - possible idempotent `line_count` rewrite by the deploy's own pre-deploy regeneration step

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` completes without error.
- `bash .claude/scripts/tests/test-issue-record.sh` (no `CORE_TEST_SUBJECT_MODE`) exits 0 with zero failures — criterion 5, against the deployed copy.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/core/scripts/issue-record.sh agent-system/extensions/core/scripts/tests/test-issue-record.sh agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh agent-system/extensions/core/context/formats/issue-log.md` reports a green narrowed verdict, run *after* the redeploy so it is not vacuous.
- Under `/orchestrate`, the complete gate set (`bash .claude/scripts/verify-deploy.sh`) is explicitly deferred to the orchestration close's once-per-invocation batch gate stage, and that deferral is recorded in this phase's verification notes rather than discharged independently here. A standalone, non-orchestrated run of this plan runs the complete set directly instead.

## Testing & Validation

- [ ] Criterion 1: a deliberately mistyped flag, invoked in the exact documented form, leaves an
      attributable record — `tags.issue_record_refusal` naming the flag — in the task's own
      `issues.jsonl` (Phase 2 case (w); Phase 4 hand-exercise against the deployed copy).
- [ ] Criterion 2: the caller's exit status is still 0 under the documented form for every
      refusal class, argument-shaped or content-shaped (Phase 2 cases (w), (z); existing case (i)
      unchanged).
- [ ] Criterion 3: `test-issue-record.sh` carries a regression case covering the mistyped-flag
      path under output redirection (Phase 2 case (w)), proven non-vacuous by failing against
      pre-Phase-1 behaviour.
- [ ] Criterion 4: `issue-record.sh`'s header invocation-contract comment and exit-code block
      (Phase 1) and `context/formats/issue-log.md` (Phase 3) both describe the implemented
      behaviour, including the stated residual.
- [ ] Criterion 5: the full `test-issue-record.sh` suite passes — in source-store subject mode
      (Phases 1-2) and in default deployed mode after the redeploy (Phase 4).
- [ ] No regression in the suites that resolve `orchestrate-build-dispatch.sh`:
      `test-orchestrate-build-dispatch.sh` and `test-orchestrate-cycle-plan.sh` (Phase 3).
- [ ] `generate-context-line-counts.sh` check mode reports no `line_count` drift (Phase 3).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/issue-record.sh` — refusal mode, exit code 2,
  self-recorded refusal entry, updated header contract.
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` — four new regression cases.
- `agent-system/extensions/core/context/formats/issue-log.md` — refusal-entry documentation.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — one static
  discoverability sentence in the rendered `## Issue Log` block.
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count`.
- A regenerated deployed `.claude/**` tree (gitignored, not a committed artifact).
- `specs/639_make_issue_record_failures_visible/summaries/01_*-summary.md` at completion.

## Rollback/Contingency

Each phase commits independently, so the cheapest contingency is a forward fix on the single file
that phase touched. If a genuine rollback of uncommitted work is required, follow
`context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
(including its out-of-scope override flag) before any destructive git command — never a bare
precautionary `git-snapshot.sh`; an ordinary defensive checkpoint before risky work uses
`--no-revert`, which is durable without reverting the working tree.

Phase-specific contingencies:

- Phase 1 abandoned or reverted: no other phase has landed yet; the file returns to a single
  exit-code script and nothing else in the repo has been told otherwise.
- Phase 2 or 3 reverted while Phase 1 stands: the mechanism is live but undocumented/untested.
  Either complete the reverted phase or revert Phase 1 as well — do not leave criterion 4
  (documentation parity) failing, since a header contract that describes unimplemented behaviour
  is the exact class of defect this task exists to remove.
- Phase 4's redeploy is itself the remedy for a stale deployed tree, not a change to roll back:
  `.claude/**` is gitignored and fully regenerable from the source store, so re-running
  `deploy-headless.sh` is always available and idempotent.
