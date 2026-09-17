# Implementation Plan: Task #206

- **Task**: 206 - fix_test_fixtures_missing_task_lookup_lib
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/206_fix_test_fixtures_missing_task_lookup_lib/reports/01_fixture-missing-task-lookup-lib.md
- **Artifacts**: plans/01_fix-red-fixture-and-lint-predicate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, context/standards/shell-strict-mode.md, .claude/rules/source-store-deploy-boundary.md
- **Type**: general
- **Lean Intent**: false

## Overview

Two core shell suites are red on master, both with confirmed, experimentally-verified root causes.
`test-postflight-deploy-gate.sh` builds a minimal fixture script tree from an explicit
`REQUIRED_LIBS` list that omits `lib/task-lookup-lib.sh`, which `task-lock.sh` sources
unconditionally — 7 of 19 cases fail. `lint-json-channel-discipline.sh`'s `check_emit_perline()`
exclusion pipeline does not recognise a `> "$var"` file redirect, so a correctly-redirected temp-file
write in `orchestrate-triage-classify.sh` is counted as an unredirected stdout write; that false
match pushes the candidate count to 2, which also defeats the "exactly one surviving match is the
legitimate final emit" short-circuit and drags the file's genuine final emit into the violation
list. Both fixes are one-line, both were confirmed experimentally during research. The task closes
with a defensive audit fix in two further fixtures carrying the same latent missing-lib gap, a new
permanent regression fixture case for the lint, and full source-store + redeployed verification.

**Definition of done**: `test-postflight-deploy-gate.sh` and `test-lint-json-channel-discipline.sh`
pass from the source store and from the redeployed `.claude/` copy; the real-corpus lint run reports
0 violations; the audit result, the suite (2) decision, and the new lint fixture case are all
recorded; every touched shell file is shellcheck clean.

**All edits target the source store** (`agent-system/extensions/core/**`). `.claude/**` is a
disposable deploy artifact and is only ever regenerated, never hand-edited.

### Research Integration

The research report supplies every root cause and a verified fix for each:

- Suite (1): adding `task-lookup-lib.sh` to `REQUIRED_LIBS` alone takes the suite from 12/19 to
  19/19. `task-lookup-lib.sh` sources nothing further, so no transitive libs are needed.
- Suite (2): the recommended decision is **fix the predicate**, not allowlist and not change
  `orchestrate-triage-classify.sh`. The verified patch appends one exclusion stage,
  `grep -vE '>[[:space:]]*"?\$\{?[A-Za-z_]'`, to `check_emit_perline()`'s existing pipeline. It
  clears the real corpus (179 files, 0 violations, down from 2) while leaving the existing
  "two genuine violations" and "one legitimate emit" fixture cases unchanged.
- Item (d) audit: 22 candidate suites classified into five buckets; two genuine but currently
  dormant gaps found (`test-handoff-dispatch-identity.sh`, `test-git-commit-scoped.sh`), both
  fixable with the same one-line addition.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context supplied for this dispatch.

## Goals & Non-Goals

**Goals**:
- `test-postflight-deploy-gate.sh` green (19/19) from source store and from the redeployed copy.
- `test-lint-json-channel-discipline.sh` green from source store and from the redeployed copy,
  with a new permanent case covering the `> "$var"` redirect shape.
- `lint-json-channel-discipline.sh` real-corpus run: 0 violations, with genuine unredirected
  stdout writes still caught.
- The two dormant audit-gap fixtures closed defensively; the full audit result recorded in the
  implementation summary.
- The suite (2) decision (fix predicate vs. allowlist vs. change code) recorded with rationale.
- shellcheck clean per `context/standards/shell-strict-mode.md` for every shell file touched.

**Non-Goals**:
- Suite (3) `test-gate-out-repair-reporting.sh` — withdrawn by the dispatch addendum, confirmed
  green (19/0) by research. Not touched.
- Changing `orchestrate-triage-classify.sh` — the write at line 225 is correct as written
  (it must land in a file for `--slurpfile`).
- Making `task-lock.sh`'s `source` of `task-lookup-lib.sh` optional or guarded — it is a critical
  path and the dispatch forbids silently softening it.
- Converting any fixture from an explicit lib list to a wholesale `lib/*.sh` copy.
- Broad isolation of shell suites from host state — that is the separate downstream task
  (`isolate_shell_suites_from_host_state`) this work must land cleanly underneath.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new lint exclusion regex over-suppresses a genuine unredirected write | H | L | Phase 3 makes the existing "two genuine violations" case and the "one legitimate emit" negative control permanent regression gates and re-runs them after the predicate change; the regex is scoped to variable-named redirect targets only, not every `>` |
| Fixture edits collide with the downstream `isolate_shell_suites_from_host_state` task | M | M | Every fixture change is a single-token addition to an existing array/loop list — no restructuring, no style change, minimal diff surface |
| Two audit-gap files sit outside the task's declared `file_scope` | L | H | `file_scope` is descriptive, not filesystem-validated (`.claude/rules/state-management.md`); Phase 4 records the deviation explicitly and extends `file_scope` in `specs/state.json` rather than silently exceeding it |
| The redeploy step overwrites unrelated working-tree state under `.claude/` | M | L | `.claude/` is gitignored and regenerated by design; use the non-destructive default `deploy-headless.sh` mode, never `--wipe` |
| Audit finds more gaps than the two research predicted | M | L | Phase 4 carries a Scope Hypothesis: re-run the audit grep before editing and record the actual count, fixing whatever is found rather than only the two predicted |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 4 | -- |
| 2 | 3 | 2 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Restore the missing fixture lib in the deploy-gate suite [COMPLETED]

**Goal**: `test-postflight-deploy-gate.sh` passes 19/19 from the source store.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` and
      record the red baseline (expected 12 passed / 7 failed). *(completed: confirmed 12 passed, 7 failed on master)*
- [x] Add `task-lookup-lib.sh` to the `REQUIRED_LIBS` array
      (`agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh:85`), keeping the
      explicit-list style — the existing `build_fixture_repo()` copy loop already consumes the same
      array, so no second edit site is needed. *(completed)*
- [x] Re-run the suite and confirm 19 passed / 0 failed, with none of the previously-passing
      cases regressing. *(completed: 19 passed, 0 failed)*
- [x] Confirm no further transitive libs are required by running, not by assumption (research
      found `task-lookup-lib.sh` sources nothing, but the run is the evidence). *(completed: single-token addition alone reached 19/0, confirming no transitive libs needed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the hypothesis is that exactly ONE lib name is missing and no transitive
additions are needed. Confirm at implementation time by re-running the suite after the single-token
addition and requiring 19/19; if any case still fails, read its error output for the next missing
lib rather than adding names speculatively.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` - add
  `task-lookup-lib.sh` to `REQUIRED_LIBS`

**Verification**:
- Suite reports 19 passed, 0 failed.
- `git diff` on the file shows a single-token addition and nothing else.

---

### Phase 2: Fix the lint predicate's variable-named redirect false positive [COMPLETED]

**Goal**: `check_emit_perline()` no longer treats a `> "$var"` file redirect as an unredirected
stdout write; the real corpus runs clean.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` and
      record the red baseline (expected ~178 files, 2 violations, both in
      `orchestrate-triage-classify.sh`). *(completed: confirmed 178 files, 2 violations)*
- [x] Append the exclusion stage `| grep -vE '>[[:space:]]*"?\$\{?[A-Za-z_]'` to the existing
      `grep -v '>&2' | grep -v '>&3' | grep -v '\$(' | grep -v '^\s*[0-9]*:\s*#'` pipeline inside
      `check_emit_perline()` (`agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh`).
      Keep the exclusion scoped to variable-named redirect targets; do not broaden it to every `>`.
      *(completed)*
- [x] Add a short comment above the new stage explaining what it excludes and why (a redirect to a
      `mktemp`-held path is a file write, not a stdout write). *(completed)*
- [x] Re-run the real corpus and confirm 0 violations — including that line 527's genuine final
      emit is now cleared by the pre-existing "exactly one surviving match" branch rather than by
      any new special case. *(completed: 178 files, 0 violations)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh`
      and confirm the two previously-failing cases now pass and no other case regresses.
      *(completed: 11 passed, 0 failed; required a non-destructive `deploy-headless.sh` redeploy
      first, since the suite's `resolve_candidate` is deploy-tree-first and was otherwise
      re-testing the stale deployed copy — see progress file `approaches_tried`)*
- [x] Write the suite (2) decision into the implementation notes for the summary: predicate fixed
      (not allowlisted, not a code change), with the three-part rationale — the write at line 225
      is correct as written, an allowlist entry is narrower than the defect class, and the
      predicate fix is the general fix. *(completed: see progress file phase-2 notes.suite_2_decision)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` - one added
  exclusion stage plus an explanatory comment in `check_emit_perline()`

**Verification**:
- Real-corpus run: 0 violations (down from 2), file count unchanged or higher.
- `test-lint-json-channel-discipline.sh` passes all cases.
- `orchestrate-triage-classify.sh` is unmodified (`git diff --stat` shows it absent).

---

### Phase 3: Add permanent regression coverage for the redirect shape [NOT STARTED]

**Goal**: the false positive cannot silently return, and genuine unredirected writes remain caught.

**Tasks**:
- [ ] Add a new EMIT per-line case to
      `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh`, built in
      the same style as the existing EMIT case 2 / EMIT negative control: a synthetic file named
      `orchestrate-triage-classify.sh` containing one `printf ... > "$var"` redirected write plus
      exactly one legitimate final unredirected emit. Assert a clean pass (0 violations, zero exit).
- [ ] Verify the new case FAILS against the pre-fix predicate (stash or temporarily revert the
      Phase 2 edit, run, confirm it reports violations, restore) — a regression test that cannot
      fail on the old code is not a regression test.
- [ ] Re-run the whole suite and confirm the existing EMIT case 2 (two genuine unredirected writes
      flagged) and both negative controls still behave exactly as before.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` - one new
  EMIT per-line fixture case

**Verification**:
- Suite passes with the new case included, and the new case is demonstrated to fail against the
  pre-fix predicate.
- Case count in the suite's summary line increases by exactly the number of assertions added.

---

### Phase 4: Close the two dormant audit-gap fixtures and record the audit [NOT STARTED]

**Goal**: every fixture under `core/scripts/tests/` that copies `task-lock.sh`, `skill-base.sh`, or
`update-task-status.sh` via an explicit lib list carries `task-lookup-lib.sh`; the audit result is
written down.

**Tasks**:
- [ ] Re-run the audit sweep over `agent-system/extensions/core/scripts/tests/`: list every suite
      referencing `task-lock.sh`, `skill-base.sh`, or `update-task-status.sh`, and classify each as
      wholesale-copy / explicit-list-already-complete / no-fixture-copy / static-analysis-only /
      genuine-gap. Use a multi-line-tolerant grep — the research report notes several lib lists span
      continuation lines and are missed by a naive single-line grep.
- [ ] Add `task-lookup-lib.sh` to BOTH explicit lib loops in
      `test-handoff-dispatch-identity.sh` (the `require_file` preflight loop and the
      `setup_sandbox()` copy loop — they must stay in sync).
- [ ] Add `lib/task-lookup-lib.sh` to `REQUIRED_SCRIPTS` in `test-git-commit-scoped.sh`, and check
      the `chmod +x` skip-guard that currently keys off `lib/common.sh` so the new lib entry gets
      the same non-executable treatment.
- [ ] Re-run both suites and confirm they remain green (they are dormant gaps, so the expected
      result is unchanged-green, not red-to-green).
- [ ] Record the audit result — suites checked, bucket classification, gaps found, fixes made — in
      notes for the implementation summary.
- [ ] Extend `file_scope` for this task in `specs/state.json` to include
      `test-handoff-dispatch-identity.sh` and `test-git-commit-scoped.sh` (append only; do not
      replace the array), and note the deviation in the summary.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: research asserts 22 candidate suites with exactly 2 remaining genuine gaps
beyond the Phase 1 target. Confirm at implementation time by re-running the audit sweep and
recording the actual counts; if the sweep finds additional gaps, fix them too (item (d) instructs
fixing any gap found) and report the revised count rather than deferring to the hypothesis.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - add
  `task-lookup-lib.sh` to both explicit lib loops
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add
  `lib/task-lookup-lib.sh` to `REQUIRED_SCRIPTS` (+ `chmod +x` skip-guard)
- `specs/state.json` - append the two files to this task's `file_scope`

**Verification**:
- Both audit-gap suites still pass after the edit.
- The audit sweep output is captured for the summary.
- `jq` read-back of `specs/state.json` shows the extended `file_scope` and an otherwise-unchanged
  task entry.

---

### Phase 5: Full gate — shellcheck, redeploy, re-run from the deployed copy [NOT STARTED]

**Goal**: satisfy the acceptance criteria end to end.

**Tasks**:
- [ ] Run `shellcheck` on every shell file touched by Phases 1-4 and confirm clean per
      `context/standards/shell-strict-mode.md`.
- [ ] Run the full core suite set (`agent-system/extensions/core/scripts/tests/run-all.sh`) from the
      source store and confirm no suite regressed relative to the pre-change baseline.
- [ ] Redeploy with the non-destructive default mode:
      `bash .claude/scripts/deploy-headless.sh` (never `--wipe`).
- [ ] Re-run `test-postflight-deploy-gate.sh` and `test-lint-json-channel-discipline.sh` from the
      deployed `.claude/scripts/tests/` copy and confirm both green there too.
- [ ] Run `lint-json-channel-discipline.sh` from the deployed copy and confirm 0 violations.
- [ ] Confirm `git status` shows no hand-edits under `.claude/**` (the only `.claude/` changes are
      the regenerated deploy output, which is gitignored).

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- None (verification only; `.claude/**` is regenerated, never hand-edited)

**Verification**:
- shellcheck exits 0 for each touched file.
- `run-all.sh` shows no new failures.
- Both target suites green from both the source store and the deployed copy.

## Testing & Validation

- [ ] `test-postflight-deploy-gate.sh`: 19 passed, 0 failed (source store and deployed copy)
- [ ] `test-lint-json-channel-discipline.sh`: all cases pass, including the new `> "$var"` case
      (source store and deployed copy)
- [ ] `lint-json-channel-discipline.sh` real corpus: 0 violations
- [ ] New lint fixture case demonstrated to fail against the pre-fix predicate
- [ ] `test-handoff-dispatch-identity.sh` and `test-git-commit-scoped.sh` still green after the
      defensive lib additions
- [ ] `run-all.sh` over all core suites: no regression versus baseline
- [ ] shellcheck clean for every touched shell file
- [ ] No assertion weakened or deleted anywhere in the diff
- [ ] `task-lock.sh`'s unconditional `source` of `task-lookup-lib.sh` unchanged

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` (modified)
- `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (modified)
- `specs/state.json` (`file_scope` extended)
- `specs/206_fix_test_fixtures_missing_task_lookup_lib/summaries/01_*-summary.md` — must record the
  suite (2) decision and rationale, the full item (d) audit result (suites checked, buckets, gaps
  found, fixes made), and the `file_scope` deviation

## Rollback/Contingency

Every change is a small, isolated edit to a single file, and each phase is independently
committable, so the ordinary contingency is to revert the one offending commit with
`git revert <sha>` and re-run the affected suite — no working-tree-discarding operation is needed.

If a phase must be abandoned mid-edit and the working tree has to be restored, that is a genuine
rollback: take the snapshot first per `context/contracts/recovery.md`'s rollback rung (including
its out-of-scope override flag when the dirty tree reaches beyond this task's `file_scope`), then
perform the revert. Do not emit a bare default-mode `git-snapshot.sh` as a routine start-of-phase
checkpoint; a defensive, non-reverting checkpoint before risky work uses `--no-revert`.

`.claude/**` needs no rollback plan — it is gitignored and fully regenerated by
`deploy-headless.sh` from the source store.
