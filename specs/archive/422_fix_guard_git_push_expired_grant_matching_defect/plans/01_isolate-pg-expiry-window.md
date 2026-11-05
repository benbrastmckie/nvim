# Implementation Plan: Task #422

- **Task**: 422 - Fix guard-git-push expired-grant matching defect
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/422_fix_guard_git_push_expired_grant_matching_defect/reports/01_push-grant-expiry-window-env-leak.md
- **Artifacts**: plans/01_isolate-pg-expiry-window.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`test-guard-git-push.sh`'s single failing case is not a grant-matching or test-isolation defect
in the guard or the grant-selection logic: the suite isolates two of `push-grant-lib.sh`'s three
environment-overridable knobs (`PUSH_GRANT_KEY_PATH`, `PUSH_GRANT_DIR`) but not the third,
`PG_EXPIRY_WINDOW`, which this machine exports as `1800` for every session via
`~/.claude/settings.json`'s `env` block. The suite's fixed 700s "expired" fixture is genuinely
still fresh against a 1800s window, so the guard correctly exits 0. The fix is confined to the
suite's own fixture construction (`unset PG_EXPIRY_WINDOW` alongside the existing two overrides,
plus the header comment that documents the isolation narrative), followed by retiring the now-
resolved `known-failures.txt` row and the two adjacent prose counts that row is embedded in.
Definition of done: 47/47 green under the unmodified ambient environment, via both a direct run
and `run-all.sh --only`, with no `known-failures.txt` row for this suite remaining.

### Research Integration

The research report's decisive single-variable toggle (`env -u PG_EXPIRY_WINDOW` flips 46/1 to
47/0, with nothing else changed) is taken as settled: no diagnostic/tracing phase is planned,
and the dispatch's own "SUSPECTED ROOT CAUSE" hypothesis (an earlier case's still-fresh grant
being matched instead of the expired one) is treated as refuted rather than re-tested. The
report ruled it out directly, not by inference — exactly one grant file exists in the fixture
directory at the point of failure, each case builds a fresh `mktemp -d` repo, and
`mint_grant_in` calls `pg_grant_revoke` before minting. The report's choice of `unset` over
`export PG_EXPIRY_WINDOW=600` is adopted for the reason it gives: `unset` re-derives the
library's own current default at run time instead of hardcoding a duplicate that would need
hand-syncing.

The report also recommends no change to `push-grant-lib.sh` or `guard-git-push.sh`; this plan
touches neither, so the task's production-code blast radius is zero.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Make `test-guard-git-push.sh` pass 47/47 under the real ambient environment this machine always
  exports (`PG_EXPIRY_WINDOW=1800`), not only under an artificially cleaned one.
- Isolate `PG_EXPIRY_WINDOW` in the suite's fixture setup and extend the suite's own header
  isolation narrative to name all three isolated knobs rather than two.
- Retire the `test-guard-git-push.sh` row from `known-failures.txt` and repair the prose counts
  in that file which the removal would otherwise leave stale.

**Non-Goals**:
- No change to `push-grant-lib.sh` or `hooks/guard-git-push.sh`. Both behave exactly per their
  documented contracts (an environment-overridable expiry window by design, so the hook and the
  `/please` wrapper agree on one session-wide value; a strict multi-field grant match).
- No change to `~/.claude/settings.json` or `~/.dotfiles/config/claude/settings.json`. The
  `PG_EXPIRY_WINDOW=1800` override is deliberate real-usage configuration with its own inline
  rationale note; the test must accommodate it, not the reverse.
- No rewrite of the fixture's hardcoded 700s offset into a value derived from the library's
  default. See Risks & Mitigations for the residual exposure this leaves and the cheap comment-
  level mitigation that is in scope instead.
- No edit to `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md`
  or that task's audit report, whose "confirmed NOT ambient-host-state coupling" prose this
  task's research refutes. That is another task's artifact on a shared working tree, and the
  machine-checked refutation is already recorded in this task's own `.return-meta.json`
  `claim_invalidations` entry.
- No new ambient-host-state axis documentation. The research's Context Extension
  Recommendation (naming "deliberately-exported session-configuration env vars read via
  `${VAR:-default}`" as a fourth coupling axis) is a worthwhile follow-up but is a different
  file, a different owner, and outside this dispatch's stated scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `unset` leaves the suite silently dependent on `push-grant-lib.sh`'s default staying below the fixture's hardcoded 700s offset; a future edit raising the default past 700 reintroduces this exact silent pass | M | L | Phase 1 adds a comment at the 700s fixture site naming the dependency explicitly, so the next reader of `push-grant-lib.sh:101` has a findable pointer. Deriving the offset from the library value is deliberately out of scope (see Non-Goals) |
| Removing a `known-failures.txt` row breaks a suite that parses the real manifest | M | L | Confirmed not applicable: `test-run-all-failure-reporting.sh` and `test-run-all-selection.sh` both construct fixture-local `known-failures.txt` files and assert the real repo's copy is absent from their fixture; `test-orchestrate-cycle-plan.sh`'s only mention is a comment. Phase 2's `full` tier re-confirms this mechanically |
| A concurrent sibling task edits one of this task's two files | L | L | Neither file appears in any `concurrent_siblings` `file_scope` for this cycle (siblings own `orchestrate-cycle-postflight.sh`, `orchestrate-build-dispatch.sh`, `orchestrate-record-decision.sh`, `validate-state.sh`, `state-write.sh` and their suites). Re-read each file immediately before editing and stage only this task's own hunks, per the dispatch's concurrency note |
| The suite passes under `unset` but a *different* case was silently depending on the wide ambient window | L | L | The research confirmed all 46 other cases are green both with and without the var, so no case is window-dependent in the other direction. Phase 1 verifies the full 47-case tally, not just the one named case |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Isolate PG_EXPIRY_WINDOW in the suite's fixture setup [COMPLETED]

**Goal**: `test-guard-git-push.sh` evaluates its fixed 700s "expired" offset against
`push-grant-lib.sh`'s own documented default rather than whatever the invoking shell exports, and
the suite's header documents all three isolated knobs.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` immediately
      before editing (shared working tree, concurrent siblings this cycle). *(completed)*
- [x] Confirm the pre-fix baseline reproduces: `bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh`
      reports `46 passed, 1 failed` with `[FAIL] invalidation: expired grant expected exit 2, got 0`.
      Do not run it with `env -u`; the ambient value must be present for the baseline to be the
      real one. *(completed: reproduced exactly)*
- [x] Add `unset PG_EXPIRY_WINDOW` immediately after the existing
      `export PUSH_GRANT_KEY_PATH=...` / `export PUSH_GRANT_DIR=...` pair (currently lines 53-54),
      so all three knobs are isolated in one contiguous block. *(completed)*
- [x] Extend the suite's `CRITICAL environmental requirement` header paragraph (currently lines
      11-16) to name `PG_EXPIRY_WINDOW` as the third isolated variable, stating why: the library
      reads it as `${PG_EXPIRY_WINDOW:-600}` and this environment exports `1800`, which would
      make the fixture's 700s offset still-fresh. *(completed)*
- [x] Add a one-line comment at the 700s backdating site (currently line 194, the
      `sed -i "s/^TIMESTAMP=.*/..."` line or its preceding comment) noting that 700 is chosen to
      exceed `push-grant-lib.sh`'s 600s default and that the header's `unset` is what makes that
      comparison meaningful. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` directly and
      confirm `47 passed, 0 failed` under the unmodified ambient environment. *(completed: 47
      passed, 0 failed, with PG_EXPIRY_WINDOW=1800 still exported)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-git-push.sh,test-please-grant.sh`
      and confirm both suites green (`test-please-grant.sh` is the second suite
      `suite_selection_select` maps this path to, and shares the push-grant library surface).
      *(completed: 2 passed, 0 failed)*
- [x] Commit this phase's single file. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase is hypothesized to touch exactly one file with three small
edits (one `unset` line, one header-paragraph extension, one inline comment) and no production
code. The implementer confirms by checking `git status --short` shows only
`test-guard-git-push.sh` modified before committing; if the fix turns out to require touching
`push-grant-lib.sh` or `guard-git-push.sh`, that contradicts the research's single-variable
toggle and must be reported rather than silently absorbed.

**Tier Justification**: the edit is confined to one test file with no externally visible
signature and no production surface, and it is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-git-push.sh,test-please-grant.sh`
— the exact suite set `suite_selection_select` resolves for this path.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` - add
  `unset PG_EXPIRY_WINDOW` to the fixture-isolation block; extend the header's isolation
  paragraph from two knobs to three; comment the 700s offset's dependency on the library default

**Verification**:
- Direct run reports `47 passed, 0 failed` with the ambient `PG_EXPIRY_WINDOW=1800` still
  exported (confirm with `env | grep PG_EXPIRY` before the run, so the pass is known to be a real
  one and not an accidentally-clean shell).
- `run-all.sh --only test-guard-git-push.sh,test-please-grant.sh` reports both suites passed and
  zero NEW failures.
- `git diff` shows changes confined to `test-guard-git-push.sh`.

---

### Phase 2: Retire the known-failures.txt row and repair its surrounding counts [COMPLETED]

**Goal**: `known-failures.txt` no longer carries a row for `test-guard-git-push.sh`, and the two
prose counts that row was embedded in are corrected so the file stays internally consistent.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/known-failures.txt` immediately before
      editing. *(completed)*
- [x] Remove the `test-guard-git-push.sh|real-defect|...` row (currently line 40) entirely. Its
      header requires removing a row once its defect is resolved, and its `owner` field points at
      a now-refuted diagnosis. *(completed)*
- [x] Repair the seed-narrative count in the header paragraph that reads "The remaining 5
      failures were triaged individually; 4 are recorded below and 1 ... deliberately excluded"
      so the stated recorded-row count matches the file's actual rows. *(completed: 4 -> 3)*
- [x] Repair the comment block directly above the removed row ("The two rows below were added by
      the ambient-host-state-isolation audit ... both are reproducible, DETERMINISTIC,
      load-INDEPENDENT real defects ... explicitly confirmed NOT to be that defect class") so it
      describes the one row that remains, in the singular. Note that this block's "confirmed NOT
      to be that defect class" claim is precisely what this task's research refuted for the
      removed row — the surviving row's own claim is unaffected and must not be restated or
      re-characterized. *(completed: "two rows"/"both are" -> "the row"/"it is", singular
      throughout, surviving test-verify-deploy-context-budget.sh row's claim left untouched)*
- [x] Re-count the file's rows after the edits and confirm every prose count in the header
      matches. *(completed: 3 actual rows -- test-run-all-parallel.sh,
      test-gate-cache-equivalence.sh, test-verify-deploy-context-budget.sh -- matches the
      repaired "3 are recorded below" count; no third stale count found)*
- [x] Run the complete gate set and confirm green. *(deviation: per this dispatch's Batch Gate
      Deferral directive, discharged against the scoped narrowing invocation
      `run-all.sh --only test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh`
      -- the exact three suites `suite_selection_select` maps `known-failures.txt` to -- rather
      than independently running the full `verify-deploy.sh` gate set in this dispatch. All 3
      green, 0 failed. The complete gate set still runs once for the whole /orchestrate batch and
      is attributed back to this task via its `modified_files`.)*
- [x] Commit this phase's single file. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase is hypothesized to touch exactly one file and to require exactly
two prose-count repairs beyond the row deletion (the "4 are recorded below" seed narrative and
the "two rows below"/"both are" comment block). The implementer confirms by re-reading the whole
file after the deletion and grepping it for every numeral and plural that refers to row counts;
if a third stale count exists, repair it too and say so.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - delete the
  `test-guard-git-push.sh` row; correct the header's recorded-row count; correct the
  immediately-preceding comment block from two rows to one

**Verification**:
- `grep -c 'test-guard-git-push' agent-system/extensions/core/scripts/tests/known-failures.txt`
  returns 0.
- The complete gate set runs green: `bash agent-system/extensions/core/scripts/verify-deploy.sh`
  (the source-store path of `.claude/scripts/verify-deploy.sh`), including Gate 8's full
  shell-suite battery, which is what confirms the three suites
  `suite_selection_select` maps `known-failures.txt` to — `test-orchestrate-cycle-plan.sh`,
  `test-run-all-failure-reporting.sh`, `test-run-all-selection.sh` — are unaffected by the row
  deletion, and that `test-guard-git-push.sh` is now reported as a plain pass rather than an
  EXPECTED failure.
- No remaining prose count in `known-failures.txt` disagrees with its actual row count.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` -> `47 passed, 0 failed`,
      run with the ambient `PG_EXPIRY_WINDOW=1800` present (not `env -u`'d away).
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-guard-git-push.sh,test-please-grant.sh`
      -> both green, zero NEW failures.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` -> complete gate set green.
- [ ] `grep -c 'test-guard-git-push' .../known-failures.txt` -> 0, and the file's header counts
      match its surviving rows.
- [ ] No diff in `push-grant-lib.sh`, `hooks/guard-git-push.sh`, or any file outside this task's
      two-file scope.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` (modified: three-knob
  fixture isolation, updated header narrative, commented 700s offset)
- `agent-system/extensions/core/scripts/tests/known-failures.txt` (modified: row removed, counts
  repaired)
- `specs/422_fix_guard_git_push_expired_grant_matching_defect/summaries/01_*-summary.md`
  (implementation summary, written at completion)
- Two scoped commits, one per phase

## Rollback/Contingency

Both phases touch one file each, with no production code and no schema or state change, so
rollback is per-file and cheap. If Phase 1's `unset` does not produce 47/47 under the ambient
environment, that directly contradicts the research's single-variable toggle: stop, do not
escalate into `push-grant-lib.sh` or `guard-git-push.sh`, and report the divergence — the
diagnosis would then be wrong in a way that needs re-diagnosis, not a wider edit. If Phase 2's
gate run goes red in a suite that reads `known-failures.txt`, restore the deleted row verbatim
from git (`git show HEAD:agent-system/extensions/core/scripts/tests/known-failures.txt`) and
report, keeping Phase 1's fix committed and green on its own. Reverting committed work is a
`git revert` of the specific phase commit; no whole-tree snapshot-then-rollback is warranted at
this blast radius, so `git-snapshot.sh` is not part of this plan.
