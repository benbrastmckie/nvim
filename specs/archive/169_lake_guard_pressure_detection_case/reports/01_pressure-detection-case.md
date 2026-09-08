# Research Report: Task #169

- **Task**: 169 - Add a positive-direction memory-pressure case to test-lake-build-guard.sh
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T00:30:00Z
- **Effort**: Small (single new case + one mutation check, no production-script changes)
- **Dependencies**: None (build on already-landed commit `878043472`)
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (suite under extension, 27/27 passing at time of research)
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` (script under test)
  - `agent-system/extensions/core/context/standards/shell-script-testing.md` (suite conventions: fixture, mutation-check, loud-skip)
  - `agent-system/extensions/core/manifest.json` (confirms the test file is already registered; no manifest change needed)
- **Artifacts**:
  - This report: `specs/169_lake_guard_pressure_detection_case/reports/01_pressure-detection-case.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- The guard's pressure logic, exact return code, and exact reason strings are all in
  `agent-system/extensions/core/scripts/lake-build-guard.sh`, `check_memory_pressure()`
  (lines 456-499) and `cmd_preflight()` (lines 606-615). These are the values the new
  case must assert against — do not hardcode paraphrases.
- `preflight` mode exits `11` on pressure (`cmd_preflight`, line 613) and writes
  `"lake-build-guard: memory pressure detected:"` plus one `  - {reason}` line per
  triggered reason to stderr (lines 608-612); it exits `0` silently otherwise.
- Two independent meminfo-derived reasons exist, each governed by its own named
  threshold constant (lines 183-184):
  - `MEM_AVAILABLE_RATIO_THRESHOLD=10` — pressure when `MemAvailable*100/MemTotal < 10`.
    Reason string: `"MemAvailable/MemTotal = ${avail_ratio}% is below threshold ${MEM_AVAILABLE_RATIO_THRESHOLD}%"`.
  - `SWAP_USED_RATIO_THRESHOLD=50` — pressure when `(SwapTotal-SwapFree)*100/SwapTotal > 50`.
    Reason string: `"swap-in-use = ${swap_used_ratio}% of SwapTotal exceeds threshold ${SWAP_USED_RATIO_THRESHOLD}%"`.
  - There are also two PSI-derived reasons (`PSI_SOME_AVG10_THRESHOLD=10.0`,
    `PSI_FULL_AVG10_THRESHOLD=5.0`), but the dispatch's reference behavior (rc=11 with
    BOTH the MemAvailable reason and the swap-in-use reason, and only those two) is
    reached by leaving `LAKE_BUILD_GUARD_PSI_PATH` at the suite-wide clean fixture and
    overriding only `LAKE_BUILD_GUARD_MEMINFO_PATH` locally — the PSI path does not need
    to participate in this case's assertion.
- Case 11 (lines 393-406) is the exact local-override idiom to copy: it overrides
  `LAKE_BUILD_GUARD_PSI_PATH` as a one-shot prefix on a single `run_guard` invocation,
  never touching the suite-wide `export`s set near the top of the file (lines 96-97).
  The new case should override `LAKE_BUILD_GUARD_MEMINFO_PATH` the same way.
- The suite already has a mutation-testing section (lines 583-728, Mutations A-E) that
  builds a `sed`-patched copy of the guard into `$MUTANT_DIR` and asserts the mutant
  fails the case it targets. This is the established, scripted mechanism for
  demonstrating non-vacuousness — a new Mutation F that neuters `check_memory_pressure()`
  (return 1 unconditionally) and reruns it against the new case's pressured fixture is
  the idiomatic way to satisfy the acceptance criterion "temporarily neutering pressure
  detection ... makes the new case -- and only the new case -- fail," and gives a
  reusable, re-runnable proof rather than a one-off manual demonstration.
- Baseline confirmed by running the suite now: `Passed: 27 / Failed: 0` (matches the
  dispatch's "previously 27/27"). Adding one new numbered case plus one new mutation
  check raises this to 28 (one pass) or 29 if the mutation is also counted as a
  pass/fail case — see Recommendations for exact accounting.

## Context & Scope

Task 169 asks for exactly one new test case in
`agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`: a positive-direction
assertion that the guard's memory-pressure detector actually fires when fed a pressured
fixture, closing the gap left by commit `878043472`'s suite-wide clean-fixture default (which
made every case default to an *unpressured* environment, so a regression that disabled
detection entirely would still show 27/27 green).

Explicitly out of scope (per the dispatch's CONSTRAINTS section):
- Any edit to `lake-build-guard.sh`'s pressure logic or its threshold constants
  (`MEM_AVAILABLE_RATIO_THRESHOLD`, `SWAP_USED_RATIO_THRESHOLD`, or the PSI thresholds).
- Any edit outside `agent-system/extensions/core/**` (the `.claude/**` tree is a disposable
  deploy artifact — see `.claude/rules/source-store-deploy-boundary.md`).
- Reverting or redoing the suite-wide clean-fixture isolation from `878043472` — that fix is
  correct and already landed.

## Findings

### The exact values to assert (read from the script under test, not paraphrased)

From `agent-system/extensions/core/scripts/lake-build-guard.sh`:

```
170: LAKE_BUILD_GUARD_PSI_PATH="${LAKE_BUILD_GUARD_PSI_PATH:-/proc/pressure/memory}"
171: LAKE_BUILD_GUARD_MEMINFO_PATH="${LAKE_BUILD_GUARD_MEMINFO_PATH:-/proc/meminfo}"
...
181: PSI_SOME_AVG10_THRESHOLD="10.0"
182: PSI_FULL_AVG10_THRESHOLD="5.0"
183: MEM_AVAILABLE_RATIO_THRESHOLD=10   # percent of MemTotal; below this is "pressure"
184: SWAP_USED_RATIO_THRESHOLD=50       # percent of SwapTotal in use; above this is "pressure"
```

`check_memory_pressure()` (lines 456-499) builds `PRESSURE_REASONS` as an array; the two
meminfo-derived checks are:

```
489: if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ] 2>/dev/null; then
490:   local avail_ratio=$(( mem_avail * 100 / mem_total ))
491:   if [ "$avail_ratio" -lt "$MEM_AVAILABLE_RATIO_THRESHOLD" ]; then
492:     PRESSURE_REASONS+=("MemAvailable/MemTotal = ${avail_ratio}% is below threshold ${MEM_AVAILABLE_RATIO_THRESHOLD}%")
...
495: if [ -n "$swap_total" ] && [ "$swap_total" -gt 0 ] 2>/dev/null && [ -n "$swap_free" ]; then
496:   local swap_used_ratio=$(( (swap_total - swap_free) * 100 / swap_total ))
497:   if [ "$swap_used_ratio" -gt "$SWAP_USED_RATIO_THRESHOLD" ]; then
498:     PRESSURE_REASONS+=("swap-in-use = ${swap_used_ratio}% of SwapTotal exceeds threshold ${SWAP_USED_RATIO_THRESHOLD}%")
```

`cmd_preflight()` (lines 606-615):

```
606: cmd_preflight() {
607:   if check_memory_pressure; then
608:     echo "lake-build-guard: memory pressure detected:" >&2
609:     local r
610:     for r in "${PRESSURE_REASONS[@]}"; do
611:       printf '  - %s\n' "$r" >&2
612:     done
613:     exit 11
614:   fi
615:   exit 0
616: }
```

So the reference behavior named in the dispatch ("preflight rc=11 reporting BOTH the
MemAvailable reason and the swap-in-use reason") is produced precisely when a meminfo fixture
makes both `avail_ratio < MEM_AVAILABLE_RATIO_THRESHOLD` and
`swap_used_ratio > SWAP_USED_RATIO_THRESHOLD` true, while the PSI signal stays clean (so no PSI
reason is added and the assertion's "BOTH, and only those two" shape holds exactly). Leaving
`LAKE_BUILD_GUARD_PSI_PATH` unset for the new case (i.e. inheriting the suite-wide
`PSI_FIXTURE_CLEAN` export from lines 84-90) achieves this without the case needing to touch
the PSI path at all.

### The local-override idiom to copy (Case 11)

`agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` lines 393-406:

```
393: # =====================================================================================
394: # Case 11: PSI degradation -- LAKE_BUILD_GUARD_PSI_PATH pointed at a nonexistent file
395: # =====================================================================================
396: CASE11_ROOT="$WORKDIR/case11"
397: build_fixture "$CASE11_ROOT"
398:
399: CASE11_RC=0
400: LAKE_BUILD_GUARD_PSI_PATH="$WORKDIR/does-not-exist-psi" \
401:   run_guard "$CASE11_ROOT" preflight > /dev/null 2>&1 || CASE11_RC=$?
402:
403: if [ "$CASE11_RC" = "0" ]; then
404:   pass "case 11: ..."
405: else
406:   fail "case 11: ..."
407: fi
```

`run_guard()` (lines 162-166) is `PATH="$root/bin:$PATH" "$GUARD" "$mode" --dir "$root" "$@"`.
The env-var prefix on the invocation line (`LAKE_BUILD_GUARD_PSI_PATH="..." run_guard ...`) is a
one-shot override scoped to that single command — it does not mutate the suite-wide `export`s
set at lines 96-97 (`export LAKE_BUILD_GUARD_PSI_PATH=...` / `export
LAKE_BUILD_GUARD_MEMINFO_PATH=...`), which is exactly the constraint the dispatch calls out.
The new case follows the identical shape but overrides `LAKE_BUILD_GUARD_MEMINFO_PATH` with a
pressured fixture instead of `LAKE_BUILD_GUARD_PSI_PATH` with a missing one. Case 11 discards
both stdout and stderr (`> /dev/null 2>&1`); the new case needs the stderr content too (to check
for both reason substrings), so it should instead redirect stderr to a workdir file the way
Case 10 does (lines 382-383: `2>"$WORKDIR/c10.err"` then `CASE10_ERR="$(cat "$WORKDIR/c10.err")"`).

### Existing clean fixture format to mirror

Lines 78-90 (already in the file, suite-wide default — do not touch):

```
78: cat > "$PSI_FIXTURE_CLEAN" <<'PSI_EOF'
79: some avg10=0.00 avg60=0.00 avg300=0.00 total=0
80: full avg10=0.00 avg60=0.00 avg300=0.00 total=0
81: PSI_EOF
82:
83: # MemAvailable = 50% of MemTotal (threshold is "below 10% is pressure"); SwapFree = SwapTotal, so
84: # swap-in-use is 0% (threshold is "above 50% is pressure"). Comfortably clean on both signals.
85: cat > "$MEMINFO_FIXTURE_CLEAN" <<'MEMINFO_EOF'
86: MemTotal:       32000000 kB
87: MemFree:        16000000 kB
88: MemAvailable:   16000000 kB
89: SwapTotal:      32000000 kB
90: SwapFree:       32000000 kB
91: MEMINFO_EOF
```

The new pressured fixture is the mirror image, written into a new file alongside these two
(e.g. `MEMINFO_FIXTURE_PRESSURED="$WORKDIR/fixture-meminfo-pressured"`), placed near the new
case (not up at the top with the suite-wide clean fixtures, since it is a local override, not a
suite default).

### Deriving pressured values from the guard's own thresholds (per the CONSTRAINTS)

The dispatch requires the pressured values be derived from the guard's own thresholds so the
case survives a deliberate retune. The two threshold constants are declared as simple
`NAME=integer` assignments at fixed, greppable lines (183-184), so the test can read them at
run time with e.g.:

```bash
MEM_THRESH="$(grep -oE '^MEM_AVAILABLE_RATIO_THRESHOLD=[0-9]+' "$GUARD" | cut -d= -f2)"
SWAP_THRESH="$(grep -oE '^SWAP_USED_RATIO_THRESHOLD=[0-9]+' "$GUARD" | cut -d= -f2)"
```

This mirrors the existing precedent in the same file for grep-extracting facts from `$GUARD`
rather than hardcoding them (case 12's absolute-path/byte-literal greps at lines 412-424, and
case 13's `LEAN_NUM_THREADS` assignment/export/comment greps at lines 430-433) — reading
constants out of the script under test via `grep` is an established idiom in this suite, not a
new pattern.

To avoid integer-rounding mismatches between the fixture-construction arithmetic and the
guard's own `$(( ... ))` truncating-division arithmetic, use `MemTotal`/`SwapTotal` values that
are exact multiples of 100 (e.g. `100000000`), so `ratio_target * total / 100 * 100 / total`
round-trips to exactly `ratio_target` with no remainder. A safe, threshold-relative construction
that stays valid for any reasonable retuned threshold value:

- `avail_ratio_target = MEM_THRESH / 2` (integer division; strictly less than `MEM_THRESH` for
  any `MEM_THRESH >= 2`, comfortably below the "pressure" boundary).
- `swap_used_ratio_target = (SWAP_THRESH + 100) / 2` (integer division; strictly greater than
  `SWAP_THRESH` for any `SWAP_THRESH < 100`, comfortably above the boundary).
- `MemAvailable = MemTotal * avail_ratio_target / 100`; `MemFree` can equal `MemAvailable` (the
  guard never reads `MemFree` in `check_memory_pressure()` — confirmed at lines 481-499, only
  `MemTotal`/`MemAvailable`/`SwapTotal`/`SwapFree` are read).
- `SwapFree = SwapTotal * (100 - swap_used_ratio_target) / 100`.

This produces both reasons deterministically without hardcoding the current `10`/`50` values
directly into the fixture math (only the *derivation formula* is hardcoded, which is what the
"stays correct if a threshold is later retuned" requirement asks for).

### Non-vacuousness: the suite's existing mutation-check mechanism

Lines 583-728 already establish a scripted mutation-check pattern for exactly this kind of
non-vacuousness demonstration, per `context/standards/shell-script-testing.md`'s "Mutation
checks for regex-shaped fixes" section. Five mutations (A-E) already exist, each following the
same shape:

```bash
MUTANT_X="$MUTANT_DIR/some-name.sh"
sed 's/<pattern in $GUARD>/<neutered replacement>/' "$GUARD" > "$MUTANT_X"
chmod +x "$MUTANT_X"
# ... invoke $MUTANT_X against a fresh fixture, assert the previously-passing case's
#     assertion now fails (pass()/fail() on the OPPOSITE outcome) ...
```

Mutation B (lines 620-648) is the closest structural precedent: it neuters `have_flock()` via
`sed 's/^have_flock() {/have_flock() { return 1; } ; _disabled_have_flock() {/'`. The same
`sed` shape applied to `check_memory_pressure()` — `sed 's/^check_memory_pressure() {/check_memory_pressure() { PRESSURE_REASONS=(); return 1; } ; _disabled_check_memory_pressure() {/'`
— produces a mutant guard that always reports "no pressure" regardless of fixture content. This
is the ready-made mechanism for the acceptance criterion's non-vacuousness demonstration: run
the mutant against the new case's pressured fixture and confirm `preflight` now exits `0`
(where the unmutated guard exits `11`), i.e. the new case's assertion is what catches the
regression. Because this mutant only touches `check_memory_pressure()`, and no other case in
the suite drives `check_memory_pressure()` into the pressured branch (cases 1, 3, and 11 are
all clean-path or PSI-fallback cases per the suite's own header comment at lines 69-76: "No case
in this suite asserts that pressure IS detected"), running the full suite against this mutant
should turn ONLY the new case red — which is precisely the "the new case -- and only the new
case -- fail" acceptance bar. This full-suite run against the mutant is the recommended way to
produce the acceptance criterion's required demonstration, and its output/log excerpt is what
belongs in the implementation summary as evidence (the dispatch says "do not commit the
neutered guard" — the scripted mutant lives only in the suite's own `$MUTANT_DIR` scratch
space at run time, which is already the pattern Mutations A-E use; nothing outside the mktemp
workdir is ever written).

### Case/summary count accounting

Confirmed by running the suite now (`bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`): `Passed: 27` / `Failed: 0`, matching the dispatch's stated baseline. The
file's own header comment (line 5: "Covers 21 acceptance-mapped cases") only counts the
21 numbered `pass()`/`fail()` cases; the remaining 6 passes come from the 5 scripted mutations
(A-E) plus one further internal assertion inside the mutation block (Mutation D's two related
scoped-build sub-assertions collapse to a single `pass`/`fail` call, and Mutation E similarly —
worth reconciling exactly in the plan/implementation phase, but not load-bearing for this task).
Adding one new numbered case (22) plus one new scripted mutation (F) is expected to raise the
total to 29 passes (27 + 1 case + 1 mutation), not the dispatch's stated "28 or more" exactly —
the dispatch's "28/28 or more" phrasing already anticipates this is a floor, not an exact
target ("expect 28/28 or more"). The plan should verify the exact final count empirically after
implementation rather than pre-committing to a specific number in the plan text.

### The suite's own header comment will need small updates

Not required by the dispatch's ACCEPTANCE section, but worth flagging for the plan: the header
comment block (lines 4-5, "Covers 21 acceptance-mapped cases... (the original 13 plus 8 added
for the truthful-success fixes...)") and the comment at lines 69-76 ("No case in this suite
asserts that pressure IS detected. Any future case that wants to test the positive direction
must override these two variables locally...") both describe the current gap this task closes.
The plan should decide whether to update these comments to reflect the new case 22 (recommended
for documentation accuracy — the second comment in particular becomes stale/inaccurate the
moment the new case exists), though this is a documentation-quality nicety, not a hard
acceptance requirement.

## Decisions

- The new case reuses `run_guard()` and the existing `WORKDIR` mktemp scratch space; no new
  helper functions are needed.
- The new case overrides only `LAKE_BUILD_GUARD_MEMINFO_PATH` locally (per-invocation env-var
  prefix), leaving `LAKE_BUILD_GUARD_PSI_PATH` at its suite-wide clean-fixture default — this is
  sufficient to reproduce the reference behavior (rc=11, both the MemAvailable and swap-in-use
  reasons, no PSI reason) and keeps the case minimal.
- Threshold values (`MEM_AVAILABLE_RATIO_THRESHOLD`, `SWAP_USED_RATIO_THRESHOLD`) must be read
  from `$GUARD` via `grep`/`cut` at test-run time, not hardcoded as `10`/`50` literals, per the
  CONSTRAINTS section and to survive a future deliberate retune.
- Non-vacuousness should be demonstrated via a new scripted Mutation F (neutering
  `check_memory_pressure()` to always return "no pressure"), following the existing Mutation
  A-E pattern, run against a fresh fixture root — not merely asserted by hand during
  implementation and then discarded. The full-suite run against this mutant (showing only the
  new case goes red) is the artifact to excerpt into the implementation summary.
- No changes to `lake-build-guard.sh` itself. No changes to any file outside
  `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` are required to satisfy
  the dispatch (the manifest.json entry for this test file already exists; no registration
  change is needed).

## Risks & Mitigations

- **Risk**: Off-by-one/rounding mismatch between the fixture's constructed ratios and the
  guard's own integer-truncating `$(( ))` arithmetic could make the fixture land exactly at a
  threshold boundary instead of clearly past it. **Mitigation**: use `MemTotal`/`SwapTotal`
  values that are exact multiples of 100 so the ratio arithmetic is exact with no remainder (see
  Findings above), and derive the target ratios via `THRESH/2` and `(THRESH+100)/2` so there is
  always a comfortable margin away from the boundary, not an exact-threshold edge case.
- **Risk**: If the new fixture accidentally also perturbs the PSI signal (e.g. by reusing
  `PSI_FIXTURE_CLEAN`'s path incorrectly or overriding `LAKE_BUILD_GUARD_PSI_PATH` to something
  unreadable), a third "PSI path unavailable" verbose-only stderr line could appear, but this is
  harmless — it is gated behind `${VERBOSE:-false}` (line 476-478) and `preflight` mode never
  sets `--verbose`, so it does not appear in this case's output regardless.
- **Risk**: Mutation F's `sed` pattern silently not matching (e.g. if a future edit
  reformats `check_memory_pressure() {`) would make the mutation step a false-negative
  no-op. **Mitigation**: follow the existing precedent (Mutations A-E all handle this by
  asserting the OPPOSITE of the expected outcome and reporting "inconclusive (sed pattern did
  not match), recorded rather than silently skipped" in the `fail()` message — see lines
  613-616, 645-648, 669-672, 709-711, 726-728) rather than assuming the `sed` always succeeds.
- **Risk**: Running the suite on a host that is itself under real memory/swap pressure could, in
  principle, interact with the new case if any code path outside the local override leaks
  ambient state. **Mitigation**: this is exactly why the suite-wide clean-fixture isolation from
  `878043472` exists, and the new case's local override only ever points
  `LAKE_BUILD_GUARD_MEMINFO_PATH` at a synthetic file — the guard never reads `/proc/meminfo`
  directly once this env var is set at all (default only applies when the var is completely
  unset, which the suite-wide `export` at line 97 already prevents). The dispatch's third
  acceptance bullet ("the suite still passes on a host that is actively swapping above the
  guard's own threshold") is therefore satisfied by construction, not by anything new the plan
  needs to add.

## Context Extension Recommendations

None — this is a `meta` task confined to a single existing test file; no new context
documentation gap was identified. `context/standards/shell-script-testing.md`'s mutation-check
and fixture conventions already fully cover the pattern this task needs.

## Appendix

- Search queries used: `grep -n "Case 11\|case 11\|does-not-exist-psi\|preflight"`,
  `grep -n "PSI\|MEMINFO\|MemAvailable\|SwapFree\|SwapTotal\|THRESHOLD\|preflight\|exit 11\|pressure\|reason"` against both files; `grep -n "^# Case\|^# ===\|MUTANT_"` to map the full
  case/mutation structure; direct `Read`/`sed -n` of `check_memory_pressure()`, `cmd_preflight()`,
  and the mutation section; a live run of the suite to confirm the 27/27 baseline.
- Key line references: `lake-build-guard.sh` lines 170-184 (env vars + thresholds), 449-499
  (`check_memory_pressure`), 606-615 (`cmd_preflight`); `test-lake-build-guard.sh` lines 78-97
  (suite-wide clean fixtures + exports), 162-166 (`run_guard`), 393-406 (Case 11, the idiom to
  copy), 583-728 (Mutations A-E, the non-vacuousness mechanism to extend with Mutation F).
