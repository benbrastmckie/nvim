# Implementation Plan: Task #445

- **Task**: 445 - Give verify-deploy.sh's Gate 8 an expected-versus-new failure distinction
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None blocking. `state.json`'s recorded `dependencies: [414, 415]` are both
  `completed`; the dispatch's coordination constraint (the gate-registry/gate-framework refactor
  that owns `verify-deploy.sh` and `tests/run-all.sh`) is task 411, confirmed completed and
  archived at `specs/archive/411_refactor_verify_deploy_gate_framework/`. No sequencing edge is
  needed.
- **Research Inputs**: `specs/445_gate8_expected_vs_new_failure_distinction/reports/01_gate8-expected-new-distinction.md`
- **Artifacts**: plans/01_gate8-expected-new-distinction.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Gate 8 of `verify-deploy.sh` wraps `tests/run-all.sh` and collapses every non-zero child exit
into a single `fail()`, even though the child already classifies each failing suite as EXPECTED
(a row in the committed `tests/known-failures.txt` manifest) or NEW, and already ships an opt-in
`--fail-on-new` flag that exits 0 when every failure is EXPECTED. The entire fix is consumer-side:
pass `--fail-on-new`, then branch three ways instead of two — `pass()` on a clean run,
`warn_advisory()` on an all-expected run, `fail()` unchanged on any NEW failure. Done means Gate 8
no longer reports a blocking FAIL whose sole cause is the declared-expected set, a NEW failure
still blocks exactly as it does today, the anchored `[FAIL]`-token extraction is untouched, and
every consumer of the shared verdict has been re-verified against both fixture shapes.

### Research Integration

The research report's central finding reshaped the scope: the producer side of this problem is
already fully built. `tests/run-all.sh` ships `known-failures.txt` (3 real rows today), the
EXPECTED/NEW classification loop, the unconditional annotated roster
(`[run-all] Failing suites (N):` followed by `    <path> (EXPECTED|NEW)`), the annotated tally
line (`[run-all] 158 passed, 1 failed (1 expected, 0 NEW), 0 skipped, 159 total`), and the
`--fail-on-new` exit-code contract. `test-run-all-failure-reporting.sh` already regression-tests
all of it, including both `--fail-on-new` directions. Nothing in that machinery needs rebuilding
or re-deriving — which is exactly what the dispatch's "do not fork a second source of truth"
property demands.

The report also identified the already-proven non-blocking-but-visible primitive this task needs:
`warn_advisory()` in `verify-deploy.sh`. Planning independently verified its three relevant
properties by direct read: it increments `CHECKS` but never `FAILURES`; it writes
`WARN-FINDING <gate> ...` rather than `FINDING <gate> ...` in findings mode, which
`deploy_findings_snapshot()`'s strict `grep '^FINDING '` cannot match; and it appends to
`GATE_DIRTY_LIST`, which keeps the gate cache-write-ineligible. All three matter, and the third is
the reason a plain `pass()` is the wrong instrument (see Decisions).

Planning extended the report's consumer list with two consumers the dispatch did not name and
confirmed both by direct read: the `--skip-unchanged` gate cache (gate 8 **is** listed in
`test-gate-cache-equivalence.sh`'s `CACHEABLE_GATES`), and the zero-check-under-filter branch
(a `--only-gate 8` selection that attests to nothing exits 2; `warn_advisory()`'s `CHECKS`
increment is what keeps the all-expected case out of that branch).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no roadmap consultation was performed and no
roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Gate 8 consumes `run-all.sh`'s existing `--fail-on-new` accounting rather than recomputing or
  re-parsing the EXPECTED/NEW classification itself.
- An all-declared-expected failing run produces a visible, trackable, non-blocking Gate 8 verdict.
- A NEW failure still fails Gate 8, with its `FINDING gate8 ...` lines produced by the unchanged
  anchored extraction helper.
- Both required fixture shapes exist as a committed regression suite, each with a non-vacuousness
  check.
- Every consumer of the shared Gate 8 verdict is re-verified, with the pre/post baseline-skew
  question answered explicitly.

**Non-Goals**:
- Rebuilding, extending, or re-deriving `known-failures.txt`, the classification loop, the
  roster/tally output, or the `--fail-on-new` flag. All exist and are already regression-tested.
- Adding, retiring, or re-triaging any `known-failures.txt` row. The manifest's current contents
  are an input to this task, not a target of it.
- Closing the mixed-failure residual (a NEW-failure run's `FINDINGS_LIST` can still include the
  known-expected suite's name). This is today's existing behavior, is unchanged by this task, and
  is recorded as a named, accepted scope boundary — see Decisions.
- A generic registry-level pass/fail fold, or a new `gate-registry.data` column. The registry's
  own documented design treats each gate's `invoke` function as the gate's unit of ownership.
- Any change to `--skip-slow`'s posture, Gate 8's `specs/.gate-lock` bracket, or
  `VERIFY_DEPLOY_GATE8_JOBS`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling task 418 (implement phase, same cycle) declares `verify-deploy.sh` and `__WHOLE_TREE__` in its own `file_scope` — the same primary edit target as Phase 1 and Phase 5 | H | M | Re-read `verify-deploy.sh` immediately before each edit; stage only this task's own hunks with an explicit file list, never a directory or glob add; treat a failure in a file outside this task's `file_scope` as possibly a sibling's in-flight edit. Already recorded in `issues.jsonl` so the implementer does not rediscover it cold |
| A future format change to `run-all.sh`'s roster header would break the clean-vs-all-expected discrimination | M | L | Detect on the roster header's PRESENCE (`[run-all] Failing suites (`), not on parsing the numeric tally; the degrade direction is safe (a missing header degrades an all-expected run to `PASS`, a visibility loss only — never a missed NEW failure, since `--fail-on-new` already guarantees NEW implies exit 1). Phase 3 adds a format-stability regression assertion |
| A hand-rolled `grep` on the captured output could reintroduce an unanchored or SGR-blind `[FAIL]` match, regressing the anchoring contract | H | L | The `fail()` branch's `verify_deploy_extract_verdict_lines '[FAIL]' ...` call is moved not at all and edited not at all. The new discrimination grep matches the roster header, which contains no bracketed `FAIL`/`VIOLATION` token, so it is outside `lint-verdict-extraction-anchoring.sh`'s candidate pattern by construction rather than by allowlist |
| Using `pass()` for the all-expected case would make gate 8 cache-write-eligible under `--skip-unchanged`, caching a warm PASS over a genuinely failing corpus | H | L (if `warn_advisory()` is used as planned) | `warn_advisory()` appends to `GATE_DIRTY_LIST`, preserving today's cache-invalidation behavior exactly. Phase 3 re-verifies this consumer explicitly |
| A new fixture suite that lets Gate 8 reach the real repository corpus would recurse into the suite that discovers it | H | L | The fixture target is a synthetic `mktemp` tree whose `agent-system/extensions/core/scripts/tests/` holds only a copied `run-all.sh` plus trivial synthetic suites (the exact pattern `test-run-all-failure-reporting.sh` already uses), and whose hand-built `.claude/scripts/` deliberately omits `task-lock.sh` so Gate 8 takes its fail-open no-mutex path instead of contending for the real `specs/.gate-lock` |
| `known-failures.txt` is advisory and can go stale, and Gate 8 will now trust it more directly | M | M | Out of scope to fix (the manifest's own header documents its advisory, human-maintained nature and the `needs-owner` convention). Named in the Phase 4 documentation so the new coupling is discoverable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 (phase 3), 1 (phase 4) |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Three-way verdict branch in `gate8_run()` [COMPLETED]

**Goal**: Gate 8 asks `run-all.sh` for its EXPECTED/NEW accounting and branches three ways on the
answer, with the NEW-failure path byte-identical to today's.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/verify-deploy.sh` immediately before editing
      (concurrent sibling claims this file — see Risks). *(completed: file was clean, no foreign commit/edit observed)*
- [x] Add `--fail-on-new` to the existing `run-all.sh` invocation inside `gate8_run()`, leaving
      `--quiet`, `--jobs "$GATE8_JOBS"`, the `cd "$TARGET"` wrapper, and the surrounding
      `specs/.gate-lock` acquire/release bracket untouched. *(completed)*
- [x] After the mutex release, compute an all-expected discriminator from the already-captured
      `$run_all_output`: a line-anchored match on the roster header `[run-all] Failing suites (`.
      Its presence alongside `run_all_status -eq 0` means "failures occurred, none of them NEW".
      Do not parse the numeric tally field. *(completed)*
- [x] Replace the two-way `if [ "$run_all_status" -eq 0 ]` branch with three:
      - `run_all_status -eq 0` and no roster header -> `pass "run-all.sh: all discovered suites passed"` (message unchanged).
      - `run_all_status -eq 0` and roster header present -> `warn_advisory` with a narrative that
        names the all-expected outcome and quotes the tally line, plus a remedy pointing at
        `tests/known-failures.txt` and a full `run-all.sh` re-run for detail.
      - `run_all_status -ne 0` -> the existing `fail()` call and the existing
        `verify_deploy_extract_verdict_lines '[FAIL]' "$run_all_output"` FINDINGS loop, both
        unmodified, including the exit-2 `VERIFY_DEPLOY_GATE8_JOBS` remedy clause. *(completed:
        fail() message and FINDINGS loop confirmed character-for-character unchanged by diff)*
- [x] Extend `gate8_run()`'s own header comment block with the chosen semantics: `--fail-on-new`
      is now passed; an all-expected run is non-blocking and emits `WARN-FINDING`, never `FINDING`;
      a NEW failure is unchanged; the roster-header discriminator and its safe degrade direction;
      and why `warn_advisory()` rather than `pass()` (the `GATE_DIRTY_LIST` cache-ineligibility and
      the `CHECKS` increment that keeps a `--only-gate 8` all-expected run out of the
      zero-check-under-filter exit-2 branch). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: Gate 8's verdict shape is consumed across files, so the one-hop dependent
set must be built, not just the edited file — covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh,test-gate-registry-resolution.sh,test-deploy-baseline-lib.sh,test-lint-verdict-extraction-anchoring.sh,test-lint-shellcheck.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - `gate8_run()`: add `--fail-on-new`, add the roster-header discriminator, split the verdict into three branches, extend the gate's header comment

**Verification**:
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` parses.
- The suite set named in Tier Justification passes via `run-all.sh --only`.
- `test-lint-verdict-extraction-anchoring.sh` passes, confirming no new unanchored or SGR-blind
  verdict grep was introduced.
- Direct read-back of the diff confirms the `fail()` branch's `fail()` call and its
  `verify_deploy_extract_verdict_lines '[FAIL]'` loop are character-for-character unchanged.

---

### Phase 2: Fixture regression suite for both required shapes [COMPLETED WITH EXCLUSIONS]

**Goal**: A committed suite that exercises Gate 8's real `run-all.sh` invocation against a
synthetic corpus in both required shapes — all-expected and genuinely-NEW — and asserts the
chosen semantics on each.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-gate8-expected-new-distinction.sh`,
      structurally modelled on `test-run-all-failure-reporting.sh` (the `common.sh` helpers,
      `common_test_workdir_init`, a synthetic `$WORKDIR` tree with `core/manifest.json` as `{}`
      and the REAL `run-all.sh` copied into the fixture's own `scripts/tests/`) combined with
      `test-verify-deploy-gate-selection.sh`'s fixture-target invocation pattern. *(completed)*
- [x] Build the fixture target so Gate 8 actually runs: `<fx>/agent-system/extensions/core/` with
      `manifest.json` and `scripts/tests/{run-all.sh, test-pass-*.sh, test-fail-*.sh}`, plus a
      hand-built `<fx>/.claude/scripts/` that deliberately omits `task-lock.sh` (gate0 requires
      `.claude/` to exist; Gate 8's missing-`task-lock.sh` path is fail-open and avoids contending
      for the real `specs/.gate-lock`). *(completed: confirmed via direct ad-hoc invocation that
      gate8_run() took the real-check branch, not the SKIP/deploy-consumer branch)*
- [x] Invoke the SOURCE-STORE `verify-deploy.sh` with `--only-gate 8 <fixture>` for every case, so
      no other gate runs and the real repository corpus is never reached (ANTI-RECURSION
      INVARIANT, as documented by `test-deploy-verify-wiring.sh` and
      `test-verify-deploy-gate-selection.sh`). *(completed)*
- [x] Case A (all-expected): a fixture-local `known-failures.txt` row matching the single
      deliberately-failing fixture suite. Assert exit 0, a `[WARN]` narrative on stderr, and —
      under `--findings` — a `WARN-FINDING gate8` line on stdout with zero `^FINDING gate8` lines.
      *(completed: 4/4 assertions pass)*
- [x] Case B (genuinely-NEW): the same broken fixture suite with no matching manifest row. Assert
      non-zero exit, a `[FAIL]` narrative, and at least one `^FINDING gate8` line naming the
      broken fixture suite. *(completed: 3/3 assertions pass)*
- [x] Case C (clean): all fixture suites passing, no roster header emitted. Assert exit 0 and a
      `[PASS]` narrative, confirming the all-expected branch did not swallow the clean case.
      *(completed: 3/3 assertions pass)*
- [x] Case D (mixed): two failing fixture suites, one manifest-listed and one not. Assert
      non-zero exit and at least one `^FINDING gate8` line — the behavior Phase 3 re-verifies for
      attribution. *(completed: 2/2 assertions pass)*
- [x] Register the suite: add `"tests/test-gate8-expected-new-distinction.sh"` to
      `agent-system/extensions/core/manifest.json`'s `provides.scripts` array in alphabetical
      position, and add its row to
      `agent-system/extensions/core/scripts/tests/suite-classification.data` as
      `integration` with `invokes:verify-deploy.sh,run-all.sh`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: A new suite plus its two registration rows has no surface beyond the
suite's own run and the three registration lints —
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate8-expected-new-distinction.sh,test-manifest-scripts-sync.sh,test-lint-unit-integration-boundary.sh,test-script-inventory.sh`.

**Scope Hypothesis**: This phase asserts the fixture needs exactly three files to make Gate 8 run
(`core/manifest.json`, a copied `run-all.sh`, a hand-built `.claude/` directory) and that no
`suite-selection-lib.sh` data row is required because resolution is content-derived. Confirm at
implementation time by running the new suite and reading its actual `[run-all] Mode:` line
(`source-store` is required; `deployed` means the fixture shape is wrong), and by confirming
`suite_selection_select agent-system/extensions/core/scripts/verify-deploy.sh` lists the new suite
without any data edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate8-expected-new-distinction.sh` - new regression suite, cases A-D
- `agent-system/extensions/core/manifest.json` - add the new suite to `provides.scripts`, alphabetically
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - add the new suite's `integration` row

**Verification**:
- The new suite exits 0 standalone — confirmed (12/12 case assertions pass).
- `test-manifest-scripts-sync.sh` and `test-script-inventory.sh` pass, confirming both
  registration rows landed correctly. `test-lint-unit-integration-boundary.sh` fails against the
  live corpus, but on 3 violations wholly unrelated to this phase's registration — see Reasoned
  Exclusions below.
- The new suite's own ad-hoc confirmation (a standalone `--only-gate 8` invocation against the
  same fixture shape, outside `--quiet`) shows gate8_run() took the real-check `[PASS]` branch,
  not the `[SKIP] ... deploy consumer` branch — proving the fixture is treated as source-store.
  `gate8_run()` always passes `--quiet` to the child `run-all.sh`, which suppresses its
  `[run-all] Mode:` header line, so that literal line is not observable through the gate; this
  real-check-vs-SKIP branch is gate8_run()'s own equivalent confirmation of the Scope
  Hypothesis's fixture-shape claim.
- `suite_selection_select agent-system/extensions/core/scripts/verify-deploy.sh` lists the new
  suite with no `suite-selection-lib.sh` data edit — confirmed by direct invocation.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `test-lint-unit-integration-boundary.sh`'s live-corpus check (named in this phase's own Verification Tier suite set) | The suite fails on 3 violations (`test-mcp-merge-target.sh`, `test-validate-artifact.sh`, `test-validate-no-python-state-write.sh`) that are pre-existing and wholly unrelated to this phase's own two registration edits (one `manifest.json` entry, one `suite-classification.data` row) — this phase's own new suite is not named in the violation list, and the registration-specific suites (`test-manifest-scripts-sync.sh`, `test-script-inventory.sh`) both pass independently, so registration is confirmed correct without this suite's cooperation. Out of scope: fixing those 3 pre-existing classification/boundary gaps belongs to whichever task introduced them, not to this task's Decisions/Non-Goals. | `git log --oneline -3` on each of the 3 named files shows they were last touched under unrelated, already-completed tasks (29, 360, 419) with a clean working tree (`git status --porcelain` empty for all three) and zero overlap with this phase's own `git diff --stat` (one line in `suite-classification.data`, one line in `manifest.json`, one new file). Re-run of `test-lint-unit-integration-boundary.sh` standalone after staging this phase's two registration edits reproduces the identical 3-violation set, confirming the registration itself introduced no new violation. |

This is tightly scoped to one suite's one check (never "the rest of the phase"), decided (the 3
named pre-existing gaps are out of scope for this task), documented with a stated reason, and
evidenced by git history plus a diff-scope comparison; nothing remains for a future dispatch of
this task to pick up — the exclusion is final, not a deferral.

---

### Phase 3: Consumer re-verification and the baseline-skew answer [COMPLETED]

**Goal**: Every consumer of the shared Gate 8 verdict is re-verified against both fixture shapes,
and the dispatch's pre/post baseline-skew question is answered with evidence rather than
inference.

**Tasks**:
- [x] `orchestrate-batch-gate.sh` (the one consumer that runs Gate 8 for real — no `--skip-slow`):
      confirm against Case A that `deploy_findings_snapshot` returns zero `gate8` rows, so the
      known-expected failure never reaches the unattributed-finding blocking branch; and against
      Case D (mixed) that exactly the NEW finding is returned and attribution still functions.
      *(completed: confirmed empirically via `deploy_findings_snapshot` against the fixtures.
      Note: "exactly the NEW finding" is read as "the NEW finding is present, attribution
      works" rather than "ONLY the NEW finding" — the accepted mixed-failure residual (this
      phase's own Decisions section) means the EXPECTED suite's line may also appear in a mixed
      run, and it does; the Testing & Validation section's wording — "the NEW finding reaches
      deploy_findings_snapshot" — matches the implemented and tested behavior)*
- [x] `orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint and `command-gate-out.sh`'s
      pre/post pair: confirm by read that every `deploy_findings_snapshot` call site still passes
      `--skip-slow`, under which Gate 8 is deferred on BOTH sides of the comparison, leaving both
      consumers structurally unaffected. Record this as the reason no behavioral test is owed for
      them, rather than leaving the omission unexplained. *(completed: confirmed by direct read —
      every call site in both files passes `--skip-slow`; see Research Integration/Decisions
      update below)*
- [x] `verify-deploy.sh`'s own direct-invocation path (the consumer the measured evidence actually
      names): confirm Case A's `[WARN]` narrative makes the all-expected outcome legible at the
      point where a phase closure would previously have needed a hand-written Reasoned Exclusions
      record. *(completed: confirmed via direct fixture invocation — the `[WARN]` narrative names
      the all-expected outcome and quotes the tally line)*
- [x] Pre/post baseline skew: establish by two captures over Case A that an all-expected outcome
      emits no `FINDING gate8` line in EITHER capture, so it cannot appear in one and not the
      other. State the conclusion as a construction argument plus the observed captures, not an
      assertion. *(completed: two successive `deploy_findings_snapshot` captures over the
      unchanged Case A fixture both show zero `gate8` rows — now a committed regression
      assertion, not just an ad hoc observation)*
- [x] `--skip-unchanged` gate cache (a consumer the dispatch does not name; gate 8 is in
      `CACHEABLE_GATES`): confirm Case A leaves gate 8 cache-write-INELIGIBLE via
      `warn_advisory()`'s `GATE_DIRTY_LIST` append, matching today's invalidation behavior exactly.
      *(completed: a second `--skip-unchanged` run against the unchanged Case A fixture still
      executes the real check — no `[SKIP-CACHED] gate8` line — confirmed empirically and as a
      committed assertion)*
- [x] Zero-check-under-filter (also unnamed in the dispatch): confirm `--only-gate 8` on Case A
      exits 0 with one check counted, not 2 ("the run attested to nothing"). *(completed: exit 0,
      `PASS -- 1 check(s), 0 failure(s)`, confirmed empirically and as a committed assertion)*
- [x] Re-verify the two files this design does NOT change — `tests/run-all.sh` and
      `lib/deploy-baseline-lib.sh` — against both fixture shapes, confirming the
      `WARN-FINDING`/`FINDING` separation holds end-to-end through `deploy_findings_snapshot` with
      no edit to either. *(completed: neither file's diff touches these paths; both suites named
      in the Tier Justification — `test-run-all-failure-reporting.sh`,
      `test-deploy-baseline-lib.sh` — pass unmodified in their own pre-existing assertions, plus
      this phase's own new consumer-level assertions)*
- [x] Add a roster-header format-stability assertion to
      `test-run-all-failure-reporting.sh` (the existing suite that already owns the roster and
      `--fail-on-new` contracts), so the discriminator Phase 1 relies on cannot silently change
      shape. *(completed: three assertions — prefix present default, prefix survives `--quiet`,
      prefix absent on an all-green run)*
- [x] Non-vacuousness, per case, each confirmed to bite: for Case A, remove the fixture's
      `known-failures.txt` row and confirm the assertion flips to blocking; for Case B, add a
      matching row and confirm it flips to non-blocking; for the Case C clean assertion, inject a
      failure and confirm the `[PASS]` assertion fails; for the baseline-skew assertion, force the
      all-expected branch through `fail()` and confirm a `FINDING gate8` line appears. *(completed,
      4/4 probes, all confirmed to bite. Implementation deviation from the literal "revert" verb:
      each probe builds its OWN independent fixture copy (`*-novac` suffix) rather than mutating
      and reverting the original Case A-D fixture in place — the original fixtures stay pristine
      for every other assertion in the suite, which achieves the same evidentiary purpose
      (confirming each assertion is sensitive to fixture content, not vacuously true) without a
      mutate/restore step that could leave a fixture dirty if interrupted mid-test. The
      "force the all-expected branch through fail()" baseline-skew probe is literally identical
      to the Case A non-vacuousness probe — both remove the manifest row and reclassify the
      failure as NEW, which IS forcing it through fail() — so one probe discharges both items;
      no separate probe was added)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: This phase's claims are about the consumer chain that reads Gate 8's
verdict across four scripts, so the enumerated dependents must actually run —
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-orchestrate-batch-gate.sh,test-gate-out-self-attribution.sh,test-run-all-failure-reporting.sh,test-gate8-expected-new-distinction.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` - add the roster-header format-stability assertion
- `agent-system/extensions/core/scripts/tests/test-gate8-expected-new-distinction.sh` - add the consumer-level assertions (snapshot filtering over Cases A and D, the two-capture skew check, the `--only-gate 8` check-count check)

**Verification**:
- The suite set named in Tier Justification passes — confirmed: 5/5 suites pass
  (`test-deploy-baseline-lib.sh`, `test-gate8-expected-new-distinction.sh` [22/22 assertions],
  `test-gate-out-self-attribution.sh`, `test-orchestrate-batch-gate.sh`,
  `test-run-all-failure-reporting.sh` [now with 3 new format-stability assertions]).
- Each non-vacuousness probe is recorded as observed-to-bite (4/4: Case A, Case B, Case C,
  Case D). Per the task check-off above, each probe uses its own independent fixture copy
  rather than a mutate-then-revert of the shared Case A-D fixtures — the original fixtures are
  never mutated, so there is no "reverted state" to separately re-run; every other assertion in
  the suite already re-runs against those untouched originals within the same suite execution.
- The three consumers confirmed by read (not by test) — `orchestrate-cycle-plan.sh`,
  `command-gate-out.sh`, and (for the attribution/cache/zero-check axes) `verify-deploy.sh`'s own
  unmodified `tests/run-all.sh`/`lib/deploy-baseline-lib.sh` — each carry a written reason above
  for why no behavioral test is owed for the `--skip-slow`-deferred pair.

---

### Phase 4: Documentation convergence [COMPLETED]

**Goal**: A reader of the existing known-failures documentation can discover Gate 8's new
`[WARN]`-versus-`[FAIL]` behavior, and the accepted scope boundary is recorded rather than left
implicit.

**Tasks**:
- [x] Extend `context/standards/shell-script-testing.md`'s existing
      `### End-of-run failure roster and the known-failures baseline` section with a short
      consumer-side paragraph: Gate 8 passes `--fail-on-new`, an all-expected run is non-blocking
      and `WARN-FINDING`-channelled, a NEW failure is unchanged, and the manifest's accuracy is
      now load-bearing for that distinction. *(completed: added the "Consumer side: verify-deploy.sh's
      Gate 8" paragraph. Written as a current-design statement without before/after or
      previously/no-longer framing, per no-record-versioning-in-deliverables.md -- confirmed 0
      BLOCKING via check-record-versioning.sh)*
- [x] Record the mixed-failure residual there (or in the gate's header comment, whichever reads
      better alongside the surrounding material) as a named, accepted scope boundary: in a run
      containing at least one NEW failure, the `[FAIL]`-anchored extraction still folds every
      failing suite's line into `FINDINGS_LIST`, expected ones included. State why this is
      acceptable (it is today's unchanged behavior, and the existing flaky-reproduction confirm
      steps in `orchestrate-batch-gate.sh` and `orchestrate-cycle-plan.sh` already exist to catch
      an inconsistently-reproducing finding) and what closing it would cost (a second NEW-specific
      anchor emitted by `run-all.sh`, or a roster cross-reference inside `gate8_run()`).
      *(completed: added the "Accepted scope boundary: the mixed-failure residual" paragraph)*
- [x] Point at `tests/known-failures.txt` as the single source of truth for the row list; do not
      restate any row's contents in prose. *(completed: no row basename, category, reason, or
      owner text was copied into the new prose)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The edit is confined to markdown prose with no executable surface, and
`suite_selection_select` returns `__FULL_SWEEP__` for this path, so no suite covers it — the
honest check is the `prose` tier's diff read-through plus
`bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>`
(doc-lint and task-reference lint, with the repository root as `TARGET` so both gates run rather
than SKIP).

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - consumer-side paragraph in the existing known-failures section; the accepted-residual record

**Verification**:
- Diff read-through confirms every changed hunk is prose inside the named section.
- `--only-gate 3,4 <repo_root>` (deployed `.claude/scripts/verify-deploy.sh`) was run against the
  repository root. Gate 4 (task-reference lint) passes clean. Gate 3 (doc-lint) surfaces 3
  deployed-vs-source drift findings and 1 never-deployed advisory, all exclusively naming the
  files Phases 1-3 already edited and committed in the source store
  (`scripts/verify-deploy.sh`, `scripts/tests/test-run-all-failure-reporting.sh`,
  `scripts/tests/suite-classification.data`, the new
  `scripts/tests/test-gate8-expected-new-distinction.sh`) -- this is the expected, self-resolving
  state of a multi-phase source-store task before its own Phase 5 redeploy, not a defect in this
  phase's documentation edit. Confirmed by running `check-task-references.sh` and
  `check-record-versioning.sh` directly against the edited doc file: 0 unexempted task-reference
  occurrences, 0 BLOCKING record-versioning occurrences (8 pre-existing ADVISORY hits elsewhere
  in the file, none inside the new paragraphs).
- An index-entries.json `line_count` mismatch for `shell-script-testing.md` (introduced by this
  phase's own edit growing the file) was discovered via the same gate-3 run and repaired via
  `bash .claude/scripts/generate-context-line-counts.sh --write` against the deployed tree,
  writing the corrected count back into the source store's
  `agent-system/extensions/core/index-entries.json` -- re-run confirmed the mismatch is gone.
- No `known-failures.txt` row contents were copied into prose.

---

### Phase 5: Redeploy and full gate set [NOT STARTED]

**Goal**: The source-store changes are deployed into the `.claude/` tree and the complete gate set
is run green against the repository root.

**Tasks**:
- [ ] Re-read every file this task touched immediately before the redeploy (concurrent sibling
      claims `verify-deploy.sh` and `__WHOLE_TREE__` — see Risks); if a foreign commit or foreign
      uncommitted modification is observed, STOP and report rather than proceeding.
- [ ] Run `bash agent-system/deploy-headless.sh` to regenerate the deployed `.claude/` tree from
      the source store.
- [ ] Run the complete gate set with an explicit source-store TARGET:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh <repo_root>` (no `--skip-slow`,
      no `--only-gate`, no `--skip-unchanged`), so all gates including Gate 8 itself run at full
      depth against the deployed tree.
- [ ] Confirm the run's own Gate 8 line reports the expected real-world outcome for this
      repository today: a `[WARN]` all-expected verdict naming the manifest-listed suites rather
      than a `[FAIL]` — the measured evidence's exact scenario, now self-explaining.
- [ ] Stage and commit only this task's own files, by explicit file list, never a directory or
      glob pathspec.

**Timing**: 0.5 hours (plus full-gate wall clock, which is load-dependent)

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree, an implicit scope claim over that whole tree; the regenerated tree itself is a deploy artifact, never hand-authored, so no real `.claude/` path is declared here

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh <repo_root>` — the complete gate
  set, every gate, explicit source-store TARGET, no narrowing flag of any kind.
- Gate 8's own line in that run is either `[PASS]` or the new `[WARN]` all-expected verdict; a
  `[FAIL]` there means a NEW failure exists and must be resolved, not excluded.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` standalone, read for its tally
  line: `(E expected, 0 NEW)` is the required shape; any non-zero NEW count blocks completion.
- Deploy freshness gates confirm the deployed `.claude/` copy of `verify-deploy.sh` matches the
  source store.

## Testing & Validation

- [ ] Case A (all-expected): Gate 8 exits 0, emits `[WARN]`, emits a `WARN-FINDING gate8` line,
      and emits zero `^FINDING gate8` lines.
- [ ] Case B (genuinely-NEW): Gate 8 fails and emits at least one `^FINDING gate8` line naming the
      new failure.
- [ ] Case C (clean): Gate 8 passes, with no roster header and no WARN.
- [ ] Case D (mixed): Gate 8 fails and the NEW finding reaches `deploy_findings_snapshot`.
- [ ] Non-vacuousness probe per assertion, each observed to bite, then reverted and re-run green.
- [ ] `deploy_findings_snapshot` over Case A returns zero `gate8` rows in two successive captures.
- [ ] `--only-gate 8` over Case A counts one check (not the zero-check-under-filter exit 2).
- [ ] Gate 8 stays cache-write-ineligible on Case A under `--skip-unchanged`.
- [ ] `test-lint-verdict-extraction-anchoring.sh` passes.
- [ ] `test-manifest-scripts-sync.sh`, `test-lint-unit-integration-boundary.sh`, and
      `test-script-inventory.sh` pass with the new suite registered.
- [ ] The complete gate set passes against the repository root after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate8_run()`'s three-way verdict
  branch and its documented semantics.
- `agent-system/extensions/core/scripts/tests/test-gate8-expected-new-distinction.sh` — new
  regression suite (Cases A-D plus the consumer-level assertions).
- `agent-system/extensions/core/manifest.json` — new suite registered in `provides.scripts`.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — new suite's
  `integration` row.
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` — roster-header
  format-stability assertion.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — consumer-side
  documentation and the accepted-residual record.
- Regenerated deployed `.claude/` tree.

## Decisions

**Chosen semantics for an all-declared-expected failing run** (the dispatch requires this stated
explicitly and justified against the consumers): **Gate 8 exits zero** — `warn_advisory()`
increments `CHECKS` and never `FAILURES`, so `verify-deploy.sh`'s own aggregate verdict is
unaffected by an all-expected Gate 8 — **and the outcome stays distinguishable on three
independent channels**:

1. A `[WARN]` narrative on stderr naming the all-expected outcome and quoting `run-all.sh`'s own
   tally line. This is what the direct-invocation consumer (a human or agent running the gate set
   during phase verification) reads, and it is the channel that removes the need for a
   hand-written Reasoned Exclusions record.
2. A `WARN-FINDING gate8 ...` line on stdout under `--findings`. Machine-readable, and
   deliberately invisible to `deploy_findings_snapshot()`'s strict `grep '^FINDING '`, so a
   consumer that chokepoints there sees nothing while a consumer that wants the signal can read
   the `WARN-FINDING` channel.
3. A `GATE_DIRTY_LIST` append, which keeps gate 8 cache-write-ineligible under `--skip-unchanged`.

Justification against each consumer: `orchestrate-batch-gate.sh` is the one consumer that runs
Gate 8 at full depth, and is exactly the path the measured evidence describes — under this
semantics an all-expected run contributes no `FINDING gate8` row, so it can never become a
batch-blocking unattributed finding, while a NEW failure still does, unchanged.
`orchestrate-cycle-plan.sh` and `command-gate-out.sh` both pass `--skip-slow` at every call site,
under which Gate 8 is deferred on both sides of their pre/post comparison, so neither sees any
change. `verify-deploy.sh`'s own exit code is unchanged for a clean run and for a NEW failure, and
newly zero for an all-expected run — which is the entire point, and is safe because the child has
already certified no failure is NEW. The pre/post skew the dispatch asks about cannot occur for
the all-expected case by construction: that case emits no `FINDING gate8` line in ANY capture, so
there is no row that could appear in one snapshot and not the other.

**Rejected alternative — exit non-zero with a distinguishable status.** Keeping Gate 8 blocking
while varying its output shape would require every downstream consumer to learn a new status
vocabulary to avoid blocking, which is precisely the hand re-derivation cost this task exists to
remove. `warn_advisory()` already encodes "visible and trackable but never batch-blocking" and is
proven by its existing caller.

**Rejected alternative — `pass()` for the all-expected case.** It would not increment
`GATE_DIRTY_LIST`, making gate 8 cache-write-eligible under `--skip-unchanged` and caching a warm
PASS over a corpus that genuinely has failing suites. `warn_advisory()` preserves today's
invalidation behavior exactly.

**Rejected alternative — re-deriving the EXPECTED/NEW classification inside `gate8_run()`** (by
reading `known-failures.txt` directly, or by parsing the roster's `(EXPECTED)`/`(NEW)`
annotations). This forks a second source of truth, which the dispatch forbids outright. Gate 8
asks `run-all.sh` the question via `--fail-on-new` and reads only its exit code; the roster header
is consulted solely to tell "zero failures" apart from "zero NEW failures", a distinction the exit
code alone cannot express.

**Discriminator choice and its degrade direction.** Clean versus all-expected is discriminated by
the PRESENCE of `run-all.sh`'s roster header, not by parsing the numeric tally, because a header's
existence is the more stable contract. The degrade direction is deliberately safe: if that header
ever disappeared, an all-expected run would be reported as `PASS` — a visibility loss, never a
missed NEW failure, since `--fail-on-new` independently guarantees that any NEW failure produces a
non-zero exit and therefore the `fail()` branch.

**Mixed-failure residual, accepted as a named scope boundary.** In a run containing at least one
NEW failure, the unchanged `[FAIL]`-anchored extraction folds every failing suite's line into
`FINDINGS_LIST`, expected ones included. This is today's behavior, is unchanged by this task, and
satisfies the dispatch's three literal required properties. Closing it would need either a second
NEW-specific anchor emitted by `run-all.sh` or a roster cross-reference inside `gate8_run()`;
Phase 4 records the residual and that cost rather than leaving it implicit.

**Editing `gate8_run()`'s body is the registry-sanctioned shape.** `gate-registry.data`'s own
header documents each gate's `invoke` function as self-contained and as the gate's unit of
ownership — the executor does nothing but look it up and call it. A change to that function is
therefore a change to the gate's declared unit, which satisfies the dispatch's "adding a gate
property rather than hand-patching an inlined per-gate block" instruction; no new registry column
is warranted for a verdict rule that only one gate has.

## Rollback/Contingency

Every phase's edits are confined to tracked files under `agent-system/extensions/core/**` plus the
regenerated `.claude/` tree, and each phase commits its own green sub-steps, so reverting is a
per-commit revert rather than a working-tree discard.

- Phases 1-4: `git revert` the phase's own commit(s), then redeploy. Gate 8 returns to its
  two-way branch and the previously-passing gate set is restored.
- Phase 5: if the full gate set reveals a NEW failure, fix forward — correct the source. Never
  discard uncommitted changes to reach a passing gate (see `.claude/rules/error-handling.md`).
- If a genuine rollback of uncommitted work becomes necessary, take a durable checkpoint first per
  `context/contracts/recovery.md`'s rollback rung, using its documented invocation shape including
  the out-of-scope override flag where the redeploy's whole-tree footprint requires it. A routine
  defensive checkpoint before risky work uses the non-reverting `--no-revert` form instead.
- Contingency if the concurrent sibling's `verify-deploy.sh` work collides: stop, report the
  foreign change, and re-plan the Phase 1 hunk against the sibling's landed version rather than
  overwriting it.
