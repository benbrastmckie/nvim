# Research Report: Task #445

**Task**: 445 - Give verify-deploy.sh's Gate 8 an expected-versus-new failure distinction
**Started**: 2026-11-06T18:40:00Z
**Completed**: 2026-11-06T18:55:00Z
**Effort**: Small-to-medium (the producer-side mechanism already exists in full; the remaining
work is confined almost entirely to one gate function's branching logic)
**Dependencies**: None blocking. `state.json`'s recorded `dependencies: [414, 415]` are both
`completed`. The coordination constraint named in the dispatch (a separate gate-registry/gate-
framework refactor that "owns verify-deploy.sh and tests/run-all.sh") is task 411
(`refactor_verify_deploy_gate_framework`), which is **completed and archived**
(`specs/archive/411_refactor_verify_deploy_gate_framework/`). No sequencing edge is needed.
**Sources/Inputs**: Codebase read of `agent-system/extensions/core/scripts/verify-deploy.sh`,
`tests/run-all.sh`, `tests/known-failures.txt`, `lib/deploy-baseline-lib.sh`,
`lib/gate-verdict-extract-lib.sh`, `gate-registry.data`, `orchestrate-batch-gate.sh`,
`orchestrate-cycle-plan.sh`, `command-gate-out.sh`; `context/standards/shell-script-testing.md`;
`specs/state.json`; `specs/CHANGE_LOG.md`; `specs/TODO.md`.
**Artifacts**: This report.
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The producer side of this problem is already fully built and shipped.** `tests/run-all.sh`
  already has a committed `known-failures.txt` manifest (3 real rows today) and a working
  `--fail-on-new` flag: with it, run-all.sh exits 0 when every failure is a declared-EXPECTED
  one and exits 1 only when at least one failure classifies NEW. The tally line
  (`[run-all] N passed, M failed (E expected, X NEW), S skipped, T total`) and an unconditional
  end-of-run roster (annotated `(EXPECTED)`/`(NEW)` per suite) are both printed today, under
  `--quiet` and all. This was added by prior, unrelated work (git-blame: task "283" added the
  roster/manifest/tally; task "328" phase 14 added corpus-narrowing flags) — task 445 did not
  need to invent any of it.
- **Gate 8 (`gate8_run()` in verify-deploy.sh) simply never asked for it.** Its `run-all.sh`
  invocation passes only `--quiet --jobs "$GATE8_JOBS"`; it never passes `--fail-on-new`, so
  `run_all_status` is always the unfiltered "any failure at all" exit code, and Gate 8's
  `fail()`/`pass()` branch (and hence its FINDINGS_LIST population) collapses EXPECTED and NEW
  failures identically — exactly the defect the dispatch describes.
- **verify-deploy.sh already has the exact non-blocking-but-visible primitive this task needs**:
  `warn_advisory()`. It increments `CHECKS`, prints a `[WARN]` narrative line, and — critically —
  writes `WARN-FINDING <gate> ...` instead of `FINDING <gate> ...` when findings mode is on.
  `deploy_findings_snapshot()` (the single chokepoint every named consumer goes through) filters
  strictly on `grep '^FINDING '`, which does **not** match a `WARN-FINDING` line. This means the
  "don't skew the pre/post baseline diff" risk named in the dispatch has a ready-made, already-
  proven answer that requires **no change to `deploy-baseline-lib.sh` at all**.
- **Recommended design** (for the plan to adopt or refine): pass `--fail-on-new` to run-all.sh
  from `gate8_run()`; branch three ways on the result — clean pass (`pass()`), all-failures-
  expected (`warn_advisory()`, non-blocking, invisible to the FINDING channel), and any-NEW
  (`fail()`, unchanged behavior, same anchored `[FAIL] ` extraction as today). This changes only
  `verify-deploy.sh`; `tests/run-all.sh` and `lib/deploy-baseline-lib.sh` need no code changes
  under this design (though the plan should still re-verify both, per the dispatch's own
  instruction, since file_scope already names all three).
- Of the four named consumers, two (`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint
  and `command-gate-out.sh`'s pre/post pair) call `deploy_findings_snapshot` with `--skip-slow`,
  which makes Gate 8 **skip unconditionally on both sides** — they are structurally unaffected by
  this change. `orchestrate-batch-gate.sh`'s once-per-batch full-depth capture is the one
  consumer that actually exercises Gate 8 for real, and it is exactly the path the dispatch's
  measured evidence describes (an unattributable, perpetually-recurring known failure staying
  blocking). `verify-deploy.sh` itself (direct invocation by a human or an agent during phase
  verification) is the other real consumer, and is in fact the primary one the measured evidence
  names (the hand-written Reasoned Exclusions record).

## Context & Scope

Researched: the current Gate 8 implementation in `verify-deploy.sh`; `tests/run-all.sh`'s
existing expected/NEW accounting machinery (manifest format, classification logic, exit-code
semantics, tally/roster output shape); the anchored verdict-extraction library
(`gate-verdict-extract-lib.sh`); the `deploy_findings_snapshot`/`deploy_baseline_*` family in
`lib/deploy-baseline-lib.sh` and its four call sites named in the dispatch; the status of the
gate-registry refactor (task 411) that the dispatch's coordination constraint names; existing
fixture-test conventions for Gate 8 (`test-deploy-verify-wiring.sh`,
`test-verify-deploy-gate-selection.sh`) to scope what a new fixture test will need to avoid
self-recursion.

Not researched in depth (left for the plan): the exact fixture-test mechanics for the two
required VERIFICATION fixture runs (declared-expected-only, and genuinely-NEW), since building
them requires either a real-corpus rsync fixture (the pattern `test-verify-deploy-gate-selection.sh`
already uses) or a smaller synthetic harness — a plan-level design choice, not a research
question with one right answer.

## Findings

### Codebase Patterns

**Gate 8 today** (`agent-system/extensions/core/scripts/verify-deploy.sh`, `gate8_run()`,
~line 1138-1208):
```
run_all_output=$(cd "$TARGET" && bash ".../tests/run-all.sh" --quiet --jobs "$GATE8_JOBS" 2>&1)
run_all_status=$?
...
if [ "$run_all_status" -eq 0 ]; then
  pass "run-all.sh: all discovered suites passed"
else
  fail "run-all.sh reported failing or undiscoverable suites (exit $run_all_status)" ...
  if [ "$FINDINGS" = "true" ]; then
    while IFS= read -r run_all_line; do
      FINDINGS_LIST+=("FINDING gate8 $run_all_line")
    done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$run_all_output")
  fi
fi
```
No `--fail-on-new` is passed; `run_all_status` is the plain "any failure" exit code.

**`tests/run-all.sh`'s existing machinery** (already shipped, no change needed to build it):
- `tests/known-failures.txt`: advisory, optional, basename-keyed manifest,
  `basename|category|reason|owner` rows. Three real rows exist today:
  `test-run-all-parallel.sh` (intermittent), `test-gate-cache-equivalence.sh`
  (load-sensitive — this is the exact suite named in the dispatch's measured evidence), and
  `test-verify-deploy-context-budget.sh` (real-defect, deliberately still tracked as EXPECTED
  pending a separate fix).
- Classification (run-all.sh ~line 966-981): each failing suite's basename is looked up in
  `KNOWN_FAILURE_CATEGORY`; a hit -> `EXPECTED`, a miss -> `NEW`. A missing/absent manifest
  degrades every failure to `NEW` (documented explicit fallback — "missing file degrades to
  today's behavior").
- Tally line (~line 1003, printed unconditionally, not `--quiet`-suppressed):
  `[run-all] $PASS_COUNT passed, $FAIL_COUNT failed ($EXPECTED_COUNT expected, $NEW_COUNT NEW), $SKIP_COUNT skipped, $TOTAL_DISCOVERED total`
  — the exact line quoted in the dispatch's WHY section. The `N passed, M failed` PREFIX is
  byte-identical whether or not the manifest clause is appended, by explicit design, so no
  existing prefix-only consumer breaks.
- End-of-run roster (~line 988-995, also unconditional): one line per failing suite,
  `    <suite path> (EXPECTED)` or `(NEW)`, deliberately carrying **zero** occurrences of the
  literal token `[FAIL]` — the script's own header comment calls this out explicitly as a
  CRITICAL CONSTRAINT, because Gate 8 folds every anchored `[FAIL] ` line into a FINDING and a
  roster line containing `[FAIL]` would double-count.
- `--fail-on-new` flag (~line 1012-1020): `exit 1` only if `NEW_COUNT -gt 0`; otherwise `exit 0`.
  Opt-in; the flag's own header doc states the contract precisely, including the "missing
  manifest -> NEW always equals FAIL_COUNT -> --fail-on-new becomes equivalent to the default"
  degrade-safety clause.
- Per-suite `[FAIL] <suite path>` lines (the ones Gate 8's anchored extraction already consumes)
  are emitted inline during suite execution and are **not** annotated EXPECTED/NEW — only the
  roster and tally carry that annotation, and deliberately so (to protect the anchor contract).

**Anchored extraction contract** (`lib/gate-verdict-extract-lib.sh`,
`verify_deploy_extract_verdict_lines`): strips ANSI SGR, then `grep -E '^<token>[[:space:]]'`
(anchor-token-plus-space, line-initial) against the producer's captured output, printing the
remainder of each matched line. Gate 8 calls it with the literal token `'[FAIL]'`. Because the
roster/tally lines are deliberately `[FAIL]`-token-free, this anchor is unaffected by anything
`--fail-on-new` does to run-all.sh's output shape — the existing anchor keeps working exactly as
documented with zero change required to the library or to run-all.sh's `[FAIL] <path>` line.

**`warn_advisory()`** (verify-deploy.sh, ~line 699-716): byte-for-byte identical to `warn()`
(increments `CHECKS`, never `FAILURES`; prints `[WARN]`; appends to `GATE_DIRTY_LIST`
unconditionally) except that in findings mode it writes `WARN-FINDING <gate> ...` instead of
`FINDING <gate> ...`. Its header comment states its purpose directly: "Use this, never plain
`warn()`, for a notice that must NEVER escalate into the batch-blocking findings channel." Today
it has exactly one caller (gate16's routing-migration nudge); nothing in its contract restricts
it to that caller.

**`deploy_findings_snapshot()`** (`lib/deploy-baseline-lib.sh`, ~line 161-184): runs
`verify-deploy.sh --findings --quiet [args...]`, and regardless of exit code (never propagated)
extracts `grep '^FINDING ' | sort -u`. This grep is anchored on the literal prefix `FINDING `,
so a `WARN-FINDING ...` line is a non-match by construction (`W` != `F` at position 0) — confirmed
by direct read, not inference. This is the single chokepoint all four named consumers go through.

### Consumer Re-Verification (dispatch-named list)

- **`orchestrate-batch-gate.sh`** (once-per-batch full capture): calls `deploy_findings_snapshot`
  with **no** `--skip-slow`, so Gate 8 runs for real. This is the consumer whose documented
  behavior ("a finding attributable to NO task... stays blocking, never dropped") matches the
  dispatch's measured evidence exactly: today, a known-expected Gate 8 failure is never excluded
  from `first_findings`, survives the script's own flaky-reproduction confirm step (since a
  genuinely reproducible known failure *does* reproduce), fails self-attribution (it is not
  caused by any task's modified files), and stays blocking as a batch-level unattributed
  finding. Under the recommended design, an all-expected Gate 8 run never populates
  `FINDING gate8 ...` at all (the `warn_advisory()` branch), so `first_findings` is empty for
  Gate 8 and this consumer never reaches the "stays blocking" branch for that known failure.
  **Re-verification needed in the plan**: confirm with a live or fixture run that a mixed
  (1 expected + 1 real NEW) capture still produces exactly the NEW finding and not the expected
  one, so attribution still works correctly in the mixed case.
- **`orchestrate-cycle-plan.sh`** (inter-cycle redeploy checkpoint, ~line 1022/1090/1166): every
  `deploy_findings_snapshot` call here passes `--skip-slow`. Gate 8 is unconditionally `[SKIP]`
  under `--skip-slow` (checked first, before the source-store guard, in `gate8_run()`). The
  script's own comment at ~line 1242 states this explicitly: "gate 8 is deferred on both sides...
  a genuine disagreement between two equal-depth verdicts, not a slow-gate-vs-fast-gate depth
  mismatch." **This consumer is structurally unaffected by this task** — no re-verification
  beyond confirming the `[SKIP]` wording/behavior is unchanged.
- **`command-gate-out.sh`** (per-task postflight pre/post pair, ~line 235/258): same
  `--skip-slow` posture as above — Gate 8 deferred on both sides. **Structurally unaffected.**
- **`verify-deploy.sh` itself**: the direct-invocation path (a human or an agent running the full
  gate set as part of phase verification, exactly the scenario the dispatch's measured evidence
  describes — "the phase had to be closed [COMPLETED WITH EXCLUSIONS] with a hand-written
  Reasoned Exclusions record"). Under the recommended design, Gate 8's own `say`/`[PASS]`/`[WARN]`
  output distinguishes the all-expected case visibly and without flipping the overall exit code,
  removing the need for that hand-written record in the common case. This is arguably the
  **primary** consumer the dispatch's evidence is about, even though it isn't named in the
  dispatch's explicit consumer list (it names `deploy_findings_snapshot`'s callers specifically).
  The plan should treat this as in-scope re-verification too, since it is the most direct
  reading of "a gate verdict that its own child had already correctly characterized."

### Pre/Post Baseline Skew Risk (the dispatch's specific worry)

The dispatch asks explicitly whether "a pre/post baseline comparison cannot be skewed by the
expected set appearing in one capture and not the other." Under the recommended
(`warn_advisory()`) design:
- An all-expected Gate 8 outcome **never** writes a `FINDING gate8` line, in any capture — so it
  can never appear in one snapshot and not another; the skew scenario the dispatch worries about
  cannot occur for the all-expected case, by construction.
- A **mixed** outcome (one or more real NEW failures alongside a known-expected one) still goes
  through `fail()` and the existing, unfiltered `[FAIL]`-anchored extraction, which does **not**
  distinguish EXPECTED from NEW among the lines it folds into FINDINGS_LIST. This means a
  known-expected failure's name can still appear in `FINDINGS_LIST` whenever the run also
  contains a genuine NEW failure. This residual is **not newly introduced by this task** (it is
  today's existing behavior, unchanged) and the existing flaky-drop confirmation step in
  `orchestrate-batch-gate.sh` (and the confirm step in `orchestrate-cycle-plan.sh`) already
  exists specifically to catch a finding that reproduces inconsistently across two captures.
  Whether to additionally filter NEW-vs-EXPECTED out of the mixed-case FINDINGS_LIST is a genuine
  design question for the plan (see Decisions below) — doing so would require either a second,
  NEW-specific anchor emitted by run-all.sh (a `tests/run-all.sh` code change, which IS in this
  task's `file_scope`) or line-by-line cross-referencing of the roster block against the
  `[FAIL]`-anchored lines inside `gate8_run()` itself (no run-all.sh change, but a more fragile
  cross-reference). The dispatch's own hard requirement is narrower than "perfectly suppress the
  expected name in every case" — it requires (a) consuming the existing accounting rather than
  forking a parallel one, (b) preserving the anchor, and (c) keeping a NEW failure blocking. The
  recommended minimal design satisfies all three without touching the mixed-case residual; fully
  closing the residual is an available stretch goal, not a required one.

### External Resources

None consulted — this is a self-contained shell-script/gate-architecture question fully resolved
by direct codebase reading; no external documentation applies.

## Recommendations

1. **Adopt `--fail-on-new` + `warn_advisory()` three-way branch in `gate8_run()`** as the primary
   mechanism. Concretely: add `--fail-on-new` to the existing run-all.sh invocation; after
   capturing `run_all_status`, detect whether any failure occurred at all (e.g. a stable grep on
   the unconditional tally line's `$FAIL_COUNT` field, or on the roster header
   `[run-all] Failing suites (`) to distinguish "clean" from "all-expected" when
   `run_all_status -eq 0`; call `pass()` for clean, `warn_advisory()` (visible `[WARN]` narrative
   naming the known-expected failures, non-blocking, no `FINDING` line) for all-expected, and
   `fail()` exactly as today (same anchored `[FAIL]`-token extraction, unchanged) when
   `run_all_status -ne 0` (at least one NEW failure).
2. **State the chosen exit/output semantics explicitly in the plan**, per the dispatch's own
   requirement: recommend "Gate 8 exits non-blocking-but-visible (`[WARN]`, `CHECKS` incremented,
   `FAILURES` not incremented, no `FINDING` line) on an all-declared-expected run; exits
   blocking (`[FAIL]`, `FINDING` lines, unchanged from today) on any NEW failure." This is
   `warn_advisory()`'s exact contract, already proven by its one existing caller (gate16).
3. **This design requires zero code changes to `tests/run-all.sh` and `lib/deploy-baseline-lib.sh`**
   under the minimal form above — only `verify-deploy.sh`'s `gate8_run()` body changes. The
   dispatch's `file_scope` already includes all three files; the plan should still explicitly
   re-verify both unchanged files against both fixture shapes (as the dispatch's VERIFICATION
   section requires), even though no code edit is expected there, specifically to confirm the
   `WARN-FINDING`/`FINDING` separation holds end-to-end through `deploy_findings_snapshot`.
4. **Treat the mixed-failure residual (NEW failure list still possibly including the known-
   expected suite's name) as an explicit, named, accepted scope boundary** rather than silently
   leaving it unaddressed — state in the plan whether it is accepted as-is (consistent with the
   dispatch's literal required properties) or whether the plan elects the stretch-goal fix
   (filtering FINDINGS_LIST to NEW-only even in the mixed case, which would need a second anchor
   or a roster cross-reference and does touch `run-all.sh`).
5. **Fixture test design**: follow `test-verify-deploy-gate-selection.sh`'s established pattern
   (a real-copy rsync fixture of `agent-system/extensions/`, `--skip-slow` for every *other*
   gate-selection assertion in the same suite to avoid Gate 8 self-recursion, and `--only-gate 8`
   to isolate Gate 8's own real `run-all.sh` invocation for the two required fixture runs). The
   declared-expected fixture needs a fixture-local `known-failures.txt` row matching a
   deliberately-broken trivial fixture suite; the genuinely-NEW fixture needs the same broken
   suite with no matching manifest row (or a manifest absent entirely). Both fixture runs must
   assert both the exit-code/pass-vs-warn-vs-fail outcome AND (for the NEW case) that
   `--findings` output contains the expected `FINDING gate8` line, and (for the all-expected
   case) that it contains none.
6. **Non-vacuousness checks** (dispatch-required): for the all-expected assertion, deliberately
   remove the fixture's `known-failures.txt` row (or point at an empty manifest) and confirm the
   assertion flips to blocking; for the NEW assertion, add a matching manifest row for the same
   injected failure and confirm the assertion flips to non-blocking.

## Decisions

- **Task 411 (the gate-framework/registry refactor) is confirmed complete and archived** —
  the dispatch's coordination constraint is satisfied; no new `dependencies[]` edge is needed
  beyond the two (414, 415) already recorded, both of which are also `completed`. Task 445 is
  fully unblocked.
- **Gate 8 remains a self-contained registry-migrated function** (`gate8_run()`), consistent with
  `gate-registry.data`'s own documented design ("Each function body... UNMODIFIED original gate
  block... self-contained"). Editing `gate8_run()`'s body directly — rather than inventing a new
  generic registry-level pass/fail fold — is the sanctioned shape for this migrated tranche, not
  a regression against the registry's intent; the dispatch's "implement on top of the registry...
  adding a gate property rather than hand-patching an inlined per-gate block" instruction is
  satisfied by this being a change to the gate's own `invoke` function, which is exactly what the
  registry design already treats as the gate's unit of ownership.
- **The producer-side mechanism (`--fail-on-new`, `known-failures.txt`, the annotated
  roster/tally) is pre-existing and out of scope to rebuild.** The plan should cite it rather than
  re-derive it, per the dispatch's own "do not fork a second source of truth" requirement — it is
  already the single source of truth and task 445 only needs to make Gate 8 read it.

## Risks & Mitigations

- **Risk**: a future edit to `tests/run-all.sh`'s roster/tally line format could silently break
  Gate 8's new WARN-vs-FAIL branch detection (if it greps the tally line for `$FAIL_COUNT`).
  **Mitigation**: the plan should prefer detecting "any failure occurred" via the roster header's
  presence (`[run-all] Failing suites (`) rather than parsing the numeric tally, since the header
  line's existence is simpler to keep stable, and/or add a regression case to
  `test-deploy-verify-wiring.sh`'s existing anti-recursion suite asserting the tally-line/roster
  format stays parseable.
- **Risk**: the mixed-failure residual (Decisions/Findings above) could, in principle, still
  produce a known-expected name inside `FINDINGS_LIST` during a NEW-failure run, which a future
  consumer might misread as implicating the wrong task during attribution. **Mitigation**:
  explicit documentation in the plan (and in `shell-script-testing.md` or the gate's own header
  comment) of this residual as a known, accepted scope boundary, plus noting that existing
  self-attribution logic in `deploy-baseline-lib.sh` already tends to clear a known-expected
  failure as unattributable to the current batch's modified files in practice.
- **Risk**: `known-failures.txt` is advisory and can go stale (a row's suite starts passing, or a
  new real regression isn't added promptly) — not a defect this task introduces, but worth naming
  since Gate 8 will now trust the manifest more directly (an all-expected PASS/WARN depends on
  the manifest being accurate). **Mitigation**: none required by this task specifically — the
  manifest's own header already documents its advisory, human-maintained nature and the
  `needs-owner` convention for unassigned rows.

## Context Extension Recommendations

- **Topic**: `context/standards/shell-script-testing.md` documents `--fail-on-new` and
  `known-failures.txt` thoroughly from `tests/run-all.sh`'s side, but (as of this research) says
  nothing about Gate 8 consuming them.
- **Gap**: once this task lands, a reader of `shell-script-testing.md`'s existing
  "End-of-run failure roster and the known-failures baseline" section has no pointer to Gate 8's
  own `[WARN]`-vs-`[FAIL]` behavior.
- **Recommendation**: the plan's implementation should add a short cross-reference in that
  section (or in `verify-deploy.sh`'s own Gate 8 header comment, which already documents
  `VERIFY_DEPLOY_GATE8_JOBS` and the `specs/.gate-lock` bracket at length) stating that Gate 8
  passes `--fail-on-new` and treats an all-expected run as non-blocking.

## Appendix

- Search queries / investigation steps: direct `grep`/`sed` reads of `verify-deploy.sh`
  (`gate8_run`, `pass`/`fail`/`warn`/`warn_advisory` definitions, gate-registry sourcing header),
  `tests/run-all.sh` (header doc, classification block, roster/tally, `--fail-on-new` exit logic),
  `tests/known-failures.txt`, `lib/gate-verdict-extract-lib.sh`, `lib/deploy-baseline-lib.sh`
  (`deploy_findings_snapshot` and related functions' full bodies/headers),
  `orchestrate-batch-gate.sh`, `orchestrate-cycle-plan.sh`, `command-gate-out.sh` (grep for
  `deploy_findings_snapshot`/`gate8`/`verify-deploy.sh` usage); `git log -S "fail-on-new"` on
  run-all.sh; `specs/state.json` (task 445's own record: dependencies, file_scope, status) and
  task 411/414/415/418's status; `specs/CHANGE_LOG.md` entry for task 411.
- References: `agent-system/extensions/core/scripts/verify-deploy.sh`,
  `agent-system/extensions/core/scripts/tests/run-all.sh`,
  `agent-system/extensions/core/scripts/tests/known-failures.txt`,
  `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`,
  `agent-system/extensions/core/scripts/lib/gate-verdict-extract-lib.sh`,
  `agent-system/extensions/core/scripts/gate-registry.data`,
  `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/scripts/command-gate-out.sh`,
  `agent-system/extensions/core/context/standards/shell-script-testing.md`,
  `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`,
  `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh`,
  `specs/archive/411_refactor_verify_deploy_gate_framework/`.
