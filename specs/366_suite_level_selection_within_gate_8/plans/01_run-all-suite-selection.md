# Implementation Plan: Task #366

- **Task**: 366 - Suite-level selection within Gate 8: --filter/--only in run-all.sh plus the touched-file-to-suite mapping
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/366_suite_level_selection_within_gate_8/reports/01_suite-level-selection-mechanism.md
- **Artifacts**: plans/01_run-all-suite-selection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`run-all.sh` (the suite-discovery engine behind Gate 8 of `verify-deploy.sh`) today offers
`--quiet`, `--timings FILE`, `--jobs N|auto`, `--fail-on-new` and nothing else: a task touching
five files runs every discovered suite or none. This plan adds a strictly opt-in `--only
SUITE[,SUITE,...]` enumeration flag plus a durable, sourced-only mapping library
(`scripts/lib/suite-selection-lib.sh`) that turns touched source-store paths into a resolved suite
list, with an explicit fail-safe escalation to the full sweep for any touched file it cannot map.
Definition of done: a selected run's pass/fail set is a demonstrated strict subset of the full
run's, a no-flag run's output is byte-identical to today's, an unmapped touched file provably
escalates to the full sweep, and `verify-deploy.sh`'s own Gate 8 invocation still runs the full
sweep unchanged.

### Research Integration

Report `reports/01_suite-level-selection-mechanism.md` settles five things this plan builds on
directly:

- **Flag shape**: `--only SUITE[,SUITE]`, not `--filter PATTERN`. The mapping library emits an
  exact resolved basename list, never a human-typed pattern, so `--only-gate`'s
  validate-every-token-before-running-any discipline (`verify-deploy.sh:109-130`) is the right
  precedent. `--filter PATTERN` is explicitly declined-for-now and recorded as such (Phase 6).
- **Insertion point**: filter `SUITES` immediately after the self-exclusion block
  (`run-all.sh:239`, `SUITES=("${FILTERED_SUITES[@]}")`) and before `TOTAL_DISCOVERED`
  (`run-all.sh:241`). Everything downstream — the `SKIP`/`LOAD_SENSITIVE`/`SCHEDULE_POOL` split,
  the `TOTAL_ACCOUNTED` assertion (`run-all.sh:429`), `--timings`, and the EXPECTED/NEW
  classification — iterates whatever `SUITES` holds, so a pre-split narrowing keeps all of them
  self-consistent with zero duplicated logic and no second filtering site in the deliberately
  byte-identical sequential branch (`run-all.sh:283-285`) or the parallel branch
  (`run-all.sh:325`).
- **Mapping strategy**: strict basename pairing is reliable for `scripts/lint/*.sh` only (10/12);
  it misses the majority of `scripts/lib/*.sh` and flat `scripts/*.sh`, which are exercised
  many-to-one by differently named suites (`task-lookup-lib.sh` is referenced by 20 suites). A
  grep-based reference lookup — `inbound_callers` inverted: search every suite for the touched
  basename — raises coverage to 107 of 125 core scripts.
- **Fail-safe fixture**: the 18 core scripts with zero suite reference anywhere are the concrete,
  real-world fixture for the escalation test, not a synthetic placeholder.
- **`script-inventory.sh`'s `has_test` must not be reused verbatim**: it resolves test candidates
  against each candidate's own enclosing directory (`lib/tests/test-X.sh`), a path this corpus
  never uses, so it structurally under-reports `lib/` and `lint/` coverage. The new library
  implements its own lookup against the fixed `scripts/tests/` + flat `scripts/` locations
  `run-all.sh` itself already scans.

Re-derived at plan-authoring time rather than carried from the report (per the Appendix's own
"re-run these, do not cite frozen numbers" instruction): 91 narrow suites under
`core/scripts/tests/`, 9 flat suites under `core/scripts/`, 100 core total; 52 of 91 narrow suites
match `grep -l '\$REPO_ROOT/\.claude'` (57.1%); 20 `lib/` files, 12 `lint/` files, 83 flat
non-test scripts; `manifest.json` carries 91 `"tests/test-…"` entries. The dispatch's "92 suites"
figure is stale in both directions and is not used anywhere below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch, so `specs/ROADMAP.md` was not loaded as roadmap
context. The dispatch text itself names four Settled decisions that bind this work and are
treated as hard constraints in Goals/Non-Goals below: decision 13 (`known-failures.txt` is
advisory and never changes which suites run — selection is a separate axis), decision 15 (a
coverage-reduced pass is not evidence doc-sync pins hold), decision 16 (`script-inventory.sh` is
another task's standing ground), decision 17 carve-out (b) (the `manifest.json` and
`verify-deploy.sh` file_scope exclusions).

## Goals & Non-Goals

**Goals**:

- Add `--only SUITE[,SUITE,...]` to `run-all.sh`: strictly additive, validate-all-tokens-first,
  exit 2 on any unknown token, byte-identical output when absent.
- Give the touched-file -> suite mapping a durable, single-implementation home at
  `scripts/lib/suite-selection-lib.sh` (sourced, never executed), so `run-all.sh` and any future
  caller consume one implementation.
- Make the mapping report what it cannot map, and escalate an unmapped touched file to the full
  sweep (fail-safe direction), proven by a test against the real zero-reference script set.
- Classify and surface, never silently drop, suites whose subject-under-test resolves to the
  deployed copy rather than the source-store copy.
- Produce a measured before/after wall-clock figure for a representative selected subset versus
  the full sweep, on the same host, with the host's concurrent-session load stated.

**Non-Goals**:

- Changing Gate 8's own invocation (`verify-deploy.sh:591`) or any default to a narrower sweep.
  Selection is opt-in at the call site; the full sweep still runs at the final gate.
- A `--filter PATTERN` flag (declined-for-now, recorded in Phase 6 rather than silently dropped).
- A `verify-deploy.sh` pass-through for the new flag (out of file_scope; recorded as a follow-up
  if Phase 3 finds it genuinely required).
- Fixing `script-inventory.sh`'s `has_test` directory-resolution bug (another task's declared
  ground per Settled decision 16; documented as a caveat, not patched here).
- Any planning-layer guidance about *when* an agent should use `--only` — that is the companion
  guidance task's scope. This task supplies the mechanism and the reference documentation of it.
- Extending the mapping beyond `agent-system/extensions/core` (the deployed-vs-source hazard is a
  core-only phenomenon: 0 of 19 suites in the other four extensions match).
- Weakening, skipping, or deleting any suite to make this land.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Selection silently runs zero suites on a typo and reads as green | H | M | Mirror `--only-gate`: validate every comma token against the discovered basename set before running any; unknown token -> exit 2 with the offending token named. Test case for it in Phase 4 |
| A selected subset pass is later treated as equivalent evidence to a full Gate 8 run | H | M | Echo Settled decision 15's "must not be presented as evidence" language verbatim in the library header, the `--only` help text, and the Phase 6 documentation |
| `--only` filtering placed in both the sequential and parallel branches, breaking the deliberately byte-identical sequential contract | H | L | Single filtering site before `TOTAL_DISCOVERED` (`run-all.sh:241`); Phase 4 asserts no-flag output is byte-identical and Phase 5 diffs both branches |
| `TOTAL_ACCOUNTED` (`run-all.sh:429`) left asserting against a pre-selection count | M | L | Narrow `SUITES` before `TOTAL_DISCOVERED` is computed, so the assertion compares like with like; Phase 4 includes a `--only` + `--jobs 2` case that exercises the assertion |
| Naive basename mapping selects a suite that exercises the deployed copy, not the edited source file | M | H | Classify resolution order per suite and surface it; never treat a deployed-first suite as proof the source edit is covered (Phase 2) |
| `-h/--help` output silently truncates because the header grew past the hardcoded `sed -n '2,117p'` range (`run-all.sh:146`) | M | H | Phase 3 updates the range and Phase 4 asserts the help text ends at the real last header line |
| Measured figures drift again between plan and implementation | L | M | Every count below carries a Scope Hypothesis with its re-derivation command; implementation re-runs them rather than quoting this plan |
| A sibling task edits a shared path mid-phase | M | M | Per the dispatch's concurrency note: re-read each file immediately before editing, stage only this task's own hunks (never a directory or glob `git add`), never run `git-snapshot.sh` in reverting mode |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Baseline measurement and settled-design record [COMPLETED]

**Goal**: Capture the full-sweep reference run (wall clock, host load, complete pass/fail set)
that acceptance items 1, 2 and 5 are later measured against, and re-derive every count this plan
asserts, before any source file is edited.

**Tasks**:
- [x] Record the host's concurrent-session load at measurement time (count of live agent sessions
      / `uptime` load average) — a wall-clock figure without its load condition is not a result,
      given the 2.8min-idle vs. 14min-loaded spread recorded in
      `context/standards/shell-script-testing.md`. *(completed: load average 3.99 -> 8.03 during
      the measurement window, ~42 concurrent claude-related processes; heavier than the
      previously recorded loaded baseline)*
- [x] Run the unmodified full sweep twice, capturing both: once `--jobs 1`, once `--jobs auto`,
      each with `--timings` to a scratchpad CSV. Save complete stdout/stderr for both as the
      byte-identical-output reference for acceptance item 5. *(completed: --jobs 1 = 1,276,085ms
      (~21.3min), --jobs auto = 670,581ms (~11.2min); both saved to scratchpad)*
- [x] Extract and save the full run's pass/fail/skip set (basename -> result) as the superset
      that acceptance item 2's strict-subset claim is checked against. *(completed: 120-row
      full-path,result baseline CSV saved to scratchpad)*
- [x] Re-derive the counts: narrow suite count, flat suite count, `grep -l '\$REPO_ROOT/\.claude'
      tests/*.sh` ratio, `lib/`/`lint/`/flat non-test script counts, `manifest.json`
      `"tests/test-…"` entry count. *(completed: 93 narrow/9 flat, 52/93 deployed-preferring,
      21 lib/12 lint/84 flat, 91 manifest entries -- drift from report figures recorded in
      summary)*
- [x] Re-derive the zero-reference script set (the fail-safe fixture population) with the
      Appendix's grep method, and record which of the report's 18 names still hold.
      *(completed: 19-script set, 17 of 18 original names still hold plus one new addition,
      lint-contract-compliance.sh)*
- [x] Record the settled design decisions in the scratchpad notes that Phases 2-3 implement:
      flag name `--only`, enumeration (not pattern), single filtering site, fail-safe = escalate
      to full sweep, resolution-order classification surfaced not blocking. *(completed)*

**Timing**: 0.75 hours of work (plus up to ~30 min unattended wall clock for the two full sweeps
on a loaded host — background them and poll per `context/patterns/bounded-build-waiter.md`:
hard timeout, writer liveness via `kill -0` on the captured PID, one waiter per log).

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts, as figures carried from
`reports/01_suite-level-selection-mechanism.md` and re-derived at plan-authoring time: 91 narrow +
9 flat = 100 core suites; 52/91 (57.1%) deployed-preferring; 20 `lib/`, 12 `lint/`, 83 flat
non-test scripts; 91 `manifest.json` test entries; 107/125 grep-reference coverage; an 18-script
zero-reference set. Confirm each by re-running the Appendix commands in
`reports/01_suite-level-selection-mechanism.md` (`ls tests/test-*.sh | wc -l`, `ls test-*.sh |
wc -l`, `grep -l '\$REPO_ROOT/\.claude' tests/*.sh | wc -l`, the per-basename reference grep) and
record any drift in the summary rather than carrying this plan's numbers forward.

**Files to modify**:
- none planned — measurement only; raw outputs go to the session scratchpad, figures into the
  Phase 2 library header and the implementation summary

**Verification**:
- Two complete full-sweep transcripts exist, each with its `--timings` CSV and its stated host
  load condition.
- The recorded pass/fail/skip set covers every discovered suite (count matches the run's own
  tally line).
- Every count this plan asserts has been re-derived, with drift noted.

---

### Phase 2: `suite-selection-lib.sh` — the touched-file -> suite mapping [COMPLETED]

**Goal**: A sourced-only library that maps one or more touched source-store paths to either a
resolved suite-basename list or an explicit full-sweep sentinel, reports what it could not map,
and classifies each selected suite's subject-resolution order.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` modelled
      structurally on `scripts/lib/manifest-routing-lib.sh`: sourced never executed, documented
      contract header, basename-keyed data shape matching `tests/known-failures.txt` and
      `tests/suite-cost-hints.txt`. *(completed)*
- [x] Header must state, verbatim, that a selected-subset pass is not evidence that doc-sync pins
      hold (Settled decision 15's accepted trade-off), and must document the
      `has_test` caveat: this library deliberately does not call `script-inventory.sh`'s
      `has_test`, because that function resolves candidates against each subject's own enclosing
      directory (`lib/tests/test-X.sh`) rather than this corpus's fixed `scripts/tests/`.
      *(completed)*
- [x] Implement the mapping in three ordered strata, against the same two fixed locations
      `run-all.sh` scans (`scripts/tests/test-*.sh` and flat `scripts/test-*.sh`):
      (a) strict basename pairing for `lint/lint-*.sh` and flat `scripts/*.sh`
      (`NAME.sh` -> `test-NAME.sh`), plus the corpus's `lib/` suffix variant
      (`NAME-lib.sh`/`NAME.sh` -> `test-NAME-lib.sh`);
      (b) grep-based reference lookup for everything else — every suite that references the
      touched basename, many-to-one allowed;
      (c) zero hits in (a) and (b) -> the full-sweep sentinel. *(completed)*
- [x] Expose a small, documented API: one function taking N touched paths and emitting the
      resolved basename list on stdout; one that emits the full-sweep sentinel instead when any
      touched path is unmappable; a third reporting the unmapped paths by name. *(completed:
      suite_selection_select, suite_selection_unmapped, suite_selection_classify,
      suite_selection_select_annotated)*
- [x] Classify each selected suite's resolution order for the touched basename (source-only /
      source-first / deployed-first) and surface it as an advisory annotation. Classification is
      never selection-blocking: a deployed-first suite is still selected, and is still reported as
      deployed-first. *(completed: suite_selection_classify, comment-line-filtered textual
      heuristic documented as an approximation in the header)*
- [x] Decide and document the multi-path aggregation rule: the union of per-path selections,
      except that a single unmappable path escalates the whole call to the full sweep.
      *(completed)*
- [x] shellcheck clean per `context/standards/shell-strict-mode.md`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the three-strata mapping reaches ~107 of 125 core scripts and that
exactly the 18-script zero-reference set falls through to the sentinel. Confirm at implementation
time by driving the new function over all 125 core non-test `*.sh` paths and counting sentinel
returns; the sentinel set must equal the Phase 1 re-derived zero-reference set, and any difference
must be explained in the summary, not absorbed silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - new sourced-only library:
  contract header, three-strata mapping, full-sweep sentinel, unmapped-path reporting,
  resolution-order classification

**Verification**:
- `shellcheck` clean; sourcing the file has no side effects and executes nothing.
- Driving the mapping over all 125 core non-test scripts returns a suite list for the mapped
  population and the sentinel for exactly the zero-reference set.
- A known `lint/` file maps to its paired suite; `lib/task-lookup-lib.sh` maps to the full
  many-to-one suite set its basename appears in.
- Each returned suite carries a resolution-order classification.

---

### Phase 3: `--only` flag in `run-all.sh` [COMPLETED]

**Goal**: A strictly additive, opt-in `--only SUITE[,SUITE,...]` flag with a single filtering
site that leaves every existing mechanism — `--jobs`, the nested guard,
`LOAD_SENSITIVE_BASENAMES`, `TOTAL_ACCOUNTED`, `known-failures.txt`, `--timings` — untouched.

**Tasks**:
- [x] Re-read `run-all.sh` immediately before editing (concurrency note: siblings dispatch this
      same cycle on this same tree). *(completed: line numbers unchanged, no sibling edit landed)*
- [x] Add `ONLY_SUITES=""` beside the existing `QUIET`/`TIMINGS_FILE`/`JOBS`/`FAIL_ON_NEW`
      defaults, and an `--only` case to the parse loop (`run-all.sh:127-144`) requiring a
      non-empty argument, exit 2 with a named error otherwise. *(completed)*
- [x] Filter `SUITES` at exactly one site: after the self-exclusion block
      (`SUITES=("${FILTERED_SUITES[@]}")`, `run-all.sh:239`) and before `TOTAL_DISCOVERED`
      (`run-all.sh:241`). Validate every comma token against the discovered basename set *before*
      narrowing — any unknown token exits 2 naming that token, mirroring `--only-gate`'s
      "a partially-valid list must refuse loudly, not silently run a subset"
      (`verify-deploy.sh:109-130`). Absent the flag, no filtering runs at all. *(completed;
      verified: single valid token, invalid token, mixed valid+invalid, empty argument all
      behave exactly as specified)*
- [x] Confirm no second filtering site is needed: the sequential branch (`run-all.sh:283`), the
      parallel branch (`run-all.sh:325`), `is_load_sensitive`, the `SKIP`/`LOAD_SENSITIVE`/`POOL`
      split, `TOTAL_ACCOUNTED` (`run-all.sh:429`), the timings writer and the EXPECTED/NEW
      classifier all iterate `SUITES` and inherit the narrowing for free. *(completed; verified
      with --only + --jobs 2 (parallel path + TOTAL_ACCOUNTED) and --only including a
      LOAD_SENSITIVE_BASENAMES member (confirmed still serialized ahead of the pool))*
- [x] Leave the nested-invocation guard (`run-all.sh:173`) and `JOBS_CAP=4` resolution
      (`run-all.sh:156-167`) semantically untouched: they govern job count, never suite
      membership. *(completed: untouched)*
- [x] Extend the header: usage line, an `--only` paragraph stating it is opt-in and that a
      selected pass is not evidence doc-sync pins hold, and a rejected-alternatives note
      recording `--filter PATTERN` as declined-for-now with its reason. *(completed)*
- [x] Update the `-h/--help` self-extraction range (`run-all.sh:146`, `sed -n '2,117p'`) to the
      header's new last line, so help output does not truncate mid-sentence. *(completed:
      updated to `sed -n '2,139p'`; verified -h output ends at the real last header line)*
- [x] Decide whether a `--only` selection that resolves to zero suites is an error: it is — the
      up-front token validation means zero can only arise from an empty argument, so it exits 2
      rather than falling into the existing zero-discovered harness-failure path. *(completed)*
- [x] shellcheck clean. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the flag needs exactly one filtering site and zero changes to the
sequential/parallel branches, and that the current help range is `sed -n '2,117p'` at
`run-all.sh:146`. Confirm by `grep -n` for the line numbers above immediately before editing (a
sibling may have shifted them) and by diffing a no-flag run's output against Phase 1's captured
reference transcript.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - `ONLY_SUITES` default, `--only` parse
  case with validate-all-tokens-first, single filtering site before `TOTAL_DISCOVERED`, header and
  `--help` range updates

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) — the complete gate set, run in full,
  not a hand-picked subset.
- A no-flag run's stdout/stderr is byte-identical (`diff`) to Phase 1's captured reference.
- `--only <one known basename>` runs exactly that suite; `--only nope.sh` exits 2 naming
  `nope.sh`; `--only known.sh,nope.sh` exits 2 without running anything.
- `-h` output ends at the real last header line.
- `shellcheck` clean.

---

### Phase 4: Regression suite `test-run-all-selection.sh` plus manifest registration [NOT STARTED]

**Goal**: Mechanical proof — not inspection — of the fail-safe escalation, the strict-subset
property, no-flag byte-identity, and parity of every existing mechanism with and without
selection.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`, modelled on
      `tests/test-verify-deploy-gate-selection.sh`: source-store-only subject resolution (no
      deployed-path candidate for its own subject), so this suite cannot itself join the 52
      deployed-preferring population it reasons about.
- [ ] Case: fail-safe escalation. A touched file from the Phase 1 zero-reference set returns the
      full-sweep sentinel from `suite-selection-lib.sh` — the dangerous case must escalate, never
      select nothing (acceptance item 3).
- [ ] Case: mapping correctness. A `lint/` file maps to its paired suite; a shared `lib/` file
      maps to its full many-to-one suite set; each result carries a resolution-order
      classification.
- [ ] Case: invalid `--only` token. Exits 2, names the offending token, runs no suite — mirroring
      the gate-selection suite's own invalid-token case.
- [ ] Case: no-flag byte-identity. `--only`-free output matches a reference capture (acceptance
      item 5), asserted against a small synthetic fixture tree rather than the real 100-suite
      battery so the suite stays affordable.
- [ ] Case: mechanism parity on a synthetic fixture — `--jobs 1` vs `--jobs 2` with and without
      `--only`; `RUN_ALL_NESTED=1` still forces sequential under `--only`; a
      `LOAD_SENSITIVE_BASENAMES` member still runs alone and serially when selected;
      `TOTAL_ACCOUNTED` holds under selection; a `known-failures.txt` row still classifies
      EXPECTED/NEW identically; `--timings` emits one row per *selected* suite plus the aggregate
      (acceptance item 4).
- [ ] Register the new suite with a one-line addition to the `tests/test-*.sh` array in
      `agent-system/extensions/core/manifest.json` (Settled decision 17 carve-out (b): make the
      one-line addition, do not declare the manifest in file_scope). Re-read the array immediately
      before editing — six open tasks claim this file.
- [ ] Make the suite executable (`chmod +x`) — `run-all.sh`'s loud-skip discipline reports a
      non-executable suite as `[SKIP]`, which would make a new suite look benign rather than
      unrun.
- [ ] shellcheck clean.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts `manifest.json` currently carries 91 `"tests/test-…"` entries and
that the new file is the one-line addition. Confirm with `grep -c '"tests/test-' manifest.json`
immediately before and after the edit (expect exactly +1), and confirm the suite is discovered by
checking `run-all.sh`'s own discovered-count line grows by exactly one.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - new regression suite:
  fail-safe escalation, mapping correctness, invalid-token refusal, no-flag byte-identity,
  mechanism-parity cases
- `agent-system/extensions/core/manifest.json` - one-line registration in the `tests/test-*.sh`
  array (carve-out (b); not declared in file_scope)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` passes standalone.
- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) — the complete gate set; Gate 5's
  declared-vs-deployed parity is why the suite file and its manifest line land as one atomic
  batch.
- The full sweep's discovered-suite count is exactly Phase 1's count + 1, and the new suite
  reports PASS within it.
- `shellcheck` clean.

**Commit-mode rationale**: the new suite file and its `manifest.json` registration are one
pre-declared atomic batch because Gate 5 checks declared-vs-deployed manifest parity — either
half alone leaves the tree in an expected-red state. The batch is exactly these two files,
declared here in advance, not widened later.

---

### Phase 5: Acceptance measurement and equivalence proof [NOT STARTED]

**Goal**: Discharge acceptance items 1, 2, 4, 5, 6 and 7 with measured evidence against the real
battery, not against the synthetic fixture Phase 4 uses.

**Tasks**:
- [ ] Pick a representative touched-file set (a realistic five-file task shape spanning `lib/`,
      `lint/` and flat `scripts/`), resolve it through `suite-selection-lib.sh`, and run
      `run-all.sh --only <resolved list>` on the real battery.
- [ ] Measure wall clock for that selected run and for the full sweep on the **same host**, and
      state the host's concurrent-session load for both. Record both `--jobs 1` and `--jobs auto`
      if the load condition permits (acceptance item 1).
- [ ] Prove the strict-subset property: the selected run's pass/fail set is a subset of Phase 1's
      full-run set, and no suite reports differently under selection than without it (acceptance
      item 2). A differing result is a blocker, not a note.
- [ ] Prove no-flag byte-identity on the real battery: `diff` a fresh no-flag run against Phase
      1's reference transcript, modulo recorded nondeterministic fields (timing values, temp
      paths) enumerated explicitly (acceptance item 5).
- [ ] Confirm mechanism parity on the real battery for `--jobs`, the nested guard,
      `LOAD_SENSITIVE_BASENAMES` serialization, `TOTAL_ACCOUNTED`, `known-failures.txt`
      classification and `--timings` (acceptance item 4).
- [ ] Confirm the whole `scripts/tests/` battery still passes and that no suite was weakened,
      skipped, or deleted to get there (acceptance item 6).
- [ ] `shellcheck` clean across all three touched shell files (acceptance item 7).
- [ ] Record every figure with its load condition in the implementation summary — a figure
      without its load condition is not a result.

**Timing**: 1.25 hours of work (plus unattended wall clock for the real-battery runs; background
and poll per `context/patterns/bounded-build-waiter.md`).

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts a selected subset will be materially cheaper than the full sweep.
That is the task's premise, not a measured fact, until this phase measures it: confirm with the
two same-host runs above and report the actual ratio, including the case where a shared `lib/`
file's many-to-one mapping selects so many suites that the saving is small — that outcome is a
legitimate finding to record, not a failure to hide.

**Files to modify**:
- none planned — measurement and proof only; any defect this phase surfaces is fixed in the
  owning phase's file and re-verified

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) — complete gate set, green.
- A before/after wall-clock pair exists for the same host, each with its stated load condition.
- The selected run's result set is a demonstrated strict subset of the full run's, with zero
  suites reporting differently.
- `shellcheck` clean on `run-all.sh`, `suite-selection-lib.sh`, `test-run-all-selection.sh`.

---

### Phase 6: Document the mechanism and record the declined alternatives [NOT STARTED]

**Goal**: Make the new flag and library discoverable from the standard that already narrates
`--jobs`, `--timings`, `--only-gate` and the known-failures contract, and leave a durable record
of what was deliberately not built.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/shell-script-testing.md`
      immediately before editing. This is this task's one contended path: another task owns it and
      depends on this one, so this edit lands first and must stay narrow — add to it, do not
      restructure it.
- [ ] Document `--only SUITE[,SUITE]` alongside the existing `--jobs`/`--timings`/`--only-gate`
      narrative: the flag's shape, its validate-all-tokens-first refusal discipline, that it is
      strictly opt-in, and that the full sweep still runs at the final gate.
- [ ] Document `scripts/lib/suite-selection-lib.sh` as the single home of the touched-file -> suite
      mapping, with its three strata, its full-sweep sentinel, and its resolution-order
      annotation.
- [ ] State the honesty constraint explicitly: a selected-subset pass is not evidence that
      doc-sync pins hold, the same already-accepted trade-off Settled decision 15 records for
      `--skip-slow`. Note that selection is a separate axis from `known-failures.txt` (Settled
      decision 13: the manifest is advisory and never changes which suites run).
- [ ] Record the measured before/after figures with their load conditions, and update the
      re-derived suite-population counts if they differ from what the standard currently records.
- [ ] Record the declined alternatives so they are not silently dropped or re-proposed:
      `--filter PATTERN` (no concrete interactive caller identified; the library emits exact
      lists, not patterns) and a `verify-deploy.sh` pass-through (not required — Gate 8 keeps the
      full sweep by design; log it as a follow-up if Phase 3 found otherwise).
- [ ] Note the `script-inventory.sh` `has_test` directory-resolution caveat as a pointer only,
      flagged as another task's ground per Settled decision 16 — do not patch it here.
- [ ] Cite file and line throughout (durable anchors), never a task number, per the deliverable
      rule.

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: not applicable — this phase asserts no counts of its own; every figure it
records is one Phase 1 or Phase 5 measured, carried with its load condition attached.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - `--only` and
  `suite-selection-lib.sh` documentation, measured figures with load conditions, declined
  alternatives, honesty constraint

**Verification**:
- Diff read-through confirms every changed hunk is prose inside this one file, with no structural
  reorganization of sections another task owns.
- Every file:line anchor cited resolves to the stated content; no task-number reference appears
  anywhere in the added text.
- `bash .claude/scripts/verify-deploy.sh` still green (the documentation gates read this file).

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` passes
      standalone and within the full battery.
- [ ] The full `scripts/tests/` battery passes; no suite weakened, skipped, or deleted.
- [ ] `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`) green — complete gate set,
      including Gate 8's own unchanged full sweep.
- [ ] `shellcheck` clean on `run-all.sh`, `suite-selection-lib.sh`,
      `test-run-all-selection.sh` per `context/standards/shell-strict-mode.md`.
- [ ] No-flag `run-all.sh` output byte-identical to the Phase 1 reference capture.
- [ ] Selected-run result set a demonstrated strict subset of the full-run set, zero suites
      reporting differently.
- [ ] An unmapped touched file escalates to the full sweep, proven by a test case.
- [ ] Before/after wall-clock figures recorded with their host load conditions.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/run-all.sh` (`--only` flag)
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` (new)
- `agent-system/extensions/core/manifest.json` (one-line test registration)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (documentation)
- `specs/366_suite_level_selection_within_gate_8/summaries/01_*-summary.md` (measured figures with
  load conditions, drift from this plan's counts, declined alternatives and any follow-ups)

## Rollback/Contingency

Every phase commits per-substep (Phase 4 as one pre-declared atomic batch), so rollback is a
revert of the owning phase's commits — the three new/changed shell files and the manifest line are
independent of each other and nothing else in the tree depends on them yet.

Because selection is strictly opt-in and `verify-deploy.sh:591` keeps invoking the full sweep
unchanged, a partial landing is safe: `suite-selection-lib.sh` present without `--only` is inert
(sourced, no caller), and `--only` present but unused changes no default. There is therefore no
scenario in this task requiring a working-tree-discarding rollback. Should one nonetheless arise
(for example a `run-all.sh` edit that breaks discovery), follow
`context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape,
including its out-of-scope override flag — never a bare precautionary `git-snapshot.sh` in its
default reverting mode. The ordinary defensive checkpoint before a risky `run-all.sh` edit is
`bash .claude/scripts/git-snapshot.sh --no-revert 366`, which is durable without reverting the
working tree.

Contingency if Phase 5's measurement shows a selected subset is not materially cheaper for the
representative touched-file set (for example because a shared `lib/` file's many-to-one mapping
selects most of the battery): land the mechanism anyway — it is correct, opt-in, and the
guidance-half task depends on its existence — and record the measured ratio plus the
many-to-one-mapping limitation as the honest result, rather than tuning the mapping to produce a
flattering figure.
