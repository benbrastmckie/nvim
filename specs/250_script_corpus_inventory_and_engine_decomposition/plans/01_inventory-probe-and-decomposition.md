# Implementation Plan: Task #250

- **Task**: 250 - Script-corpus inventory probe, then decompose orchestrate-cycle-plan.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: 199, 245, 249, 259, 265, 266 (all COMPLETED — re-verified in the research report); 272 is NOT a declared dependency but overlaps `orchestrate-cycle-plan.sh` and carries a pre-edit status re-check in Phase 4
- **Research Inputs**: specs/250_script_corpus_inventory_and_engine_decomposition/reports/01_script-corpus-inventory-probe-and-decomposition.md
- **Artifacts**: plans/01_inventory-probe-and-decomposition.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two-part task, exactly as the dispatch frames it: build a standing mechanical inventory probe
(`scripts/script-inventory.sh`) that ranks the non-test script corpus by evidence, then act on
that ranking by extracting cohesive concerns out of `orchestrate-cycle-plan.sh` into `scripts/lib/`
behaviour-preservingly. Phases 1-3 build, test, and register the probe. Phases 4-6 perform three
bounded extractions, each diffed against a `--dry-run` baseline captured before the first one.
Every phase ends in a diff; no phase's only artifact is prose.

All edits target the SOURCE STORE (`agent-system/extensions/core/`), never `.claude/**`
(`source-store-deploy-boundary.md`).

### Research Integration

The research report is the primary input and its corpus re-measurement is adopted: 194 non-test
`.sh` files / 71,337 lines; `orchestrate-cycle-plan.sh` at 3,026 lines (30.7% of a 9,844-line,
13-script engine); 17 libs / 3,310 lines. Its process findings are adopted wholesale: reuse
`check-extension-docs.sh` Rule Q by invocation rather than logic extraction; duplicate-block
detection has no precedent and must be scoped to bounded fixed-window hashing; the two 2026-10-02
`verify-deploy.sh` "ALSO OBSERVED" items are closed and must not be re-litigated; the run-all.sh
worked example is closed and its timing baseline (`scripts/tests/suite-cost-hints.txt`) is
consumed as probe input, never re-measured.

**One research finding is superseded by direct re-measurement during this planning pass, and the
plan is built on the corrected figures.** The report sized `orchestrate-cycle-plan.sh`'s functions
by line-delta between consecutive top-level `name() {` definitions. That proxy is not conservative
— it is wrong by up to 31x here, because the file is not a collection of large sibling functions.
Measured by brace-depth tracking:

```
 2264   762-3025  depth=0  orchestrate_cycle_plan_main   <- 74.8% of the file, ONE function
   98    655-752  depth=0  emit_and_exit
  100  2370-2469  depth=1  build_contended_manifest      (report claimed 657)
   65  2257-2321  depth=1  build_sibling_territory       (report claimed  93)
   26  2156-2181  depth=1  compose_focus
   20  2127-2146  depth=1  resolve_agent
   20   319-338   depth=0  usage
   19  2350-2368  depth=1  _paths_contend
   13  2243-2255  depth=1  _sibling_territory_classify_entry
   13  1554-1566  depth=1  is_terminal_status
    9  1585-1593  depth=1  task_has_forced_phase         (report claimed 358)
    9  1450-1458  depth=1  aux_fixed_agent               (report claimed 104)
    8  1943-1950  depth=1  task_is_build_heavy_implement (report claimed 177)
    6  2120-2125  depth=1  cycle_plan_dispatch_hash
   + 7 more helpers of 4-11 lines each
```

Consequences the plan is built on:

1. `orchestrate_cycle_plan_main()` spans lines 762-3025 and contains 13 nested helper functions
   defined at column 0 *inside its body*. The report's "flat script with sibling functions"
   reading, and its `}`-at-column-0 boundary assumption, are both incorrect.
2. The nested helpers are nested precisely because they **close over `main()`'s locals**. Moving
   one into `lib/` is not a cut-and-paste: every implicit closure must become an explicit
   parameter. That conversion is the real work and the real risk in Phases 4-6, not the line count.
3. The report's two headline extraction sizes are wrong: territory/contention is **197 lines of
   function body** (286 lines including its two contiguous banner-comment regions), not 784;
   task classification is **34 lines of function body** (~119 lines including its four disjoint
   banner regions), not 535. Extracting both yields ~13% of the file, not ~44%.
4. The file's actual bulk is `main()`'s ~1,972 lines of straight-line stage code across ~25
   banner-delimited sections. A third extraction is therefore added (Phase 6, the inter-cycle
   redeploy checkpoint region, lines 771-1250) so the reduction reaches ~29% and acceptance item 3
   ("materially smaller") is met on evidence rather than on the superseded figures.

One risk the report raised is already mitigated and does not need new coverage: Group 31 of
`test-orchestrate-cycle-plan.sh` (lines 4456+) asserts `build_contended_manifest`'s output file
content directly (`.contended[]` rows, counts, glob-vs-file pairs), and `git-commit-scoped.sh`'s
V5 refusal path is its documented consumer. The contended-manifest downstream contract is covered.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no ROADMAP.md consultation was performed.

## Goals & Non-Goals

**Goals**:
- A standing, mechanical, side-effect-free inventory probe over the non-test script corpus,
  reporting per script: line count, byte count, inbound caller count, test-coverage pairing,
  manifest `provides.scripts` registration, and duplicated-block participation — with a stable
  ranked ordering so future target selection is auditable.
- The probe registered in `manifest.json` `provides.scripts` and in
  `docs/reference/utility-scripts-inventory.md`, with its own test suite.
- Every zero-inbound-caller script either removed or justified.
- `orchestrate-cycle-plan.sh` materially smaller (target ~29%, 3,026 -> ~2,200) via three bounded,
  behaviour-preserving `lib/` extractions, each green against the existing suite as it lands.
- Byte-identical `--dry-run` JSON payload and human table versus a baseline captured before the
  first extraction.

**Non-Goals**:
- Any further work on `run-all.sh`, `test-verify-deploy-context-budget.sh`, or `verify-deploy.sh`.
  The worked example is closed (delivered 2026-09-26) and all three are correctly outside this
  task's file_scope. The `--jobs auto` ~103 s wall-clock floor belongs to the Gate 8 parallelism
  task, not here.
- Re-deriving the three refuted leads (static `grep sleep` sums, verify-deploy invocation counts,
  the gate-8 runtime share) or the two closed `verify-deploy.sh` findings.
- Decomposing the whole of `main()`'s ~1,972-line body. Phase 6 takes one cohesive region of it;
  the remainder is recorded as a follow-up recommendation, not attempted here.
- Editing `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`, or
  `orchestrate-cycle-postflight.sh` — each is another task's declared scope.
- A general clone-detection engine. Duplicate-block detection is bounded fixed-window hashing.
- Any `.claude/**` write, any `git push`, any PR.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nested helpers close over `main()`'s locals; extraction silently changes variable scoping and breaks behaviour without a test noticing | H | H | Each extraction phase enumerates the closed-over locals FIRST and converts them to explicit parameters (or a serialized JSON argument for associative arrays like `effective_group`); byte-identical `--dry-run` diff + full suite green after each phase, not only at the end |
| Duplicate-block detection has no precedent and consumes the whole Phase-2 budget | M | M | Bounded by contract: fixed 8-12 line normalized windows, report only windows recurring 3+ times or spanning 2+ files; sophistication explicitly deferred |
| Task 272 (`not_started`, declares `orchestrate-cycle-plan.sh` in its own file_scope) begins editing the file concurrently with Phases 4-6 | H | L | Phase 4 step 1 re-checks 272's status in `specs/state.json` immediately before the first edit and aborts/coordinates if it has moved off `not_started`; `specs/TODO.md` already records the do-not-batch constraint |
| A sibling task in this same cycle edits a file in this task's scope on the shared working tree | M | M | Territory contract: re-read every file immediately before editing, stage only this task's own hunks with an explicit file list, never a directory/glob `git add`, never reverting `git-snapshot.sh` |
| The redeploy-checkpoint region (Phase 6) proves too coupled to `main()`'s locals to extract whole | M | M | Declared fallback inside Phase 6: extract the leaf "Post-deploy reconcile pass" sub-region (1144-1250) alone, which still lands a diff and a lib; the phase never degrades to an analysis-only outcome |
| `run-all.sh` read through `tail`/`head` masks a red run | H | L | Acceptance explicitly forbids piping; read the summary line AND the exit code, both unpiped |
| Probe output not reproducible across runs (timestamps, `find` ordering, hash salt) | M | M | Sort all enumeration deterministically; keep any timestamp in a single top-level field excluded from the reproducibility diff, and assert that exclusion in the test suite |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is strictly serial by
construction: the probe must exist and be registered before its ranking can justify an
extraction target (the dispatch's "targets chosen by evidence, not by preference"), and each
extraction must be green before the next begins (the dispatch's "green after each extraction").

---

### Phase 1: Inventory probe core — enumeration, size, callers, test pairing [COMPLETED]

**Goal**: `scripts/script-inventory.sh` exists, emits one JSON document on stdout, takes no
side effects, and reports the four mechanically cheapest per-script facts. Its test suite covers
them against a fixture root.

**Tasks**:
- [x] Read `scripts/assess-repo-health.sh` (lines 1-100) and `scripts/measure-eager-context.sh`
      headers and adopt their convention verbatim: extensive header comment documenting
      enumeration, existence filter, and degenerate cases; `--root PATH` override; `--check`
      mode; `usage()` implemented as a `sed`-extract of the header block; `set -uo pipefail`;
      exit codes 0 / 1 (usage) / 2 (missing tool).
- [x] Implement enumeration: non-test `.sh` files under `<root>/agent-system/extensions/**`,
      excluding `/tests/` directories and flat `test-*.sh` basenames. Sort deterministically.
      Document the degenerate zero-candidate case (emit an empty `scripts` array and a `null`
      summary, never a crash).
- [x] Per script, report `path`, `lines`, `bytes`.
- [x] Per script, report `inbound_callers` (integer) and `inbound_caller_paths` (sorted array):
      a grep pass for the script's basename across skills, agents, commands, manifests, hooks,
      docs, and other scripts under `<root>`, with the probed file itself excluded. Document in
      the header that this is a textual-reference count and therefore an over-count (comments,
      heredocs, and fixture literals are indistinguishable from code to grep) — the lesson the
      dispatch's METHOD WARNING demands the probe honor. Zero callers is reported as a finding
      flag, not merely a zero.
- [x] Per script, report `has_test` (boolean) and `test_paths`: pairing by basename convention
      against `scripts/tests/test-<basename>` and flat `scripts/test-<basename>`.
- [x] Add `--root` default resolution matching `assess-repo-health.sh` (git toplevel, then
      script-relative fallback) and assert in the header that fixtures must pass `--root`.
- [x] Write `scripts/tests/test-script-inventory.sh` covering: enumeration excludes test files;
      line/byte counts correct for a fixture; caller counting excludes self and finds a
      cross-file reference; `has_test` true/false both demonstrated; zero-candidate degenerate
      root; `--root` missing-argument usage error exits 1; no file is written anywhere under the
      fixture root across a run (assert via a before/after `find`-based manifest).
- [x] Run the new suite directly (`bash scripts/tests/test-script-inventory.sh`) to green.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the probe's four core metrics can be implemented inside
one agent run against a 194-file / 71,337-line corpus. Confirm at implementation time by running
the probe over the real source store once the core metrics are in and checking it completes in
well under a minute; if the caller-count grep pass over ~300 files proves slow, reduce it to a
single `grep -rF -f <basename-list>` pass rather than per-script invocations before adding any
further metric.

**Files to modify**:
- `agent-system/extensions/core/scripts/script-inventory.sh` - new file: probe core
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - new file: its suite

**Verification**:
- `bash agent-system/extensions/core/scripts/script-inventory.sh --root <repo> | jq empty` succeeds
- `bash agent-system/extensions/core/scripts/tests/test-script-inventory.sh` exits 0 with every
  case passing (read the full output, unpiped)
- `bash -n` clean on both new files
- `git status --short` shows only the two new files before committing

---

### Phase 2: Probe completion — manifest drift, duplicate blocks, ranked ordering [COMPLETED]

**Goal**: the probe reports the remaining two required facts and emits a stable, auditable ranked
ordering, with test coverage for each.

**Tasks**:
- [x] Add `manifest_registered` (boolean) per script by REUSING `check-extension-docs.sh` Rule Q
      (`check_undeclared_scripts`, around lines 530-580) by invocation: run that script and parse
      its `FAIL: script file on disk NOT in provides.scripts: ...` lines, filtering to the probe's
      candidate set. Do NOT extract or reimplement Rule Q's logic — the dispatch says reuse, and
      the research report's rationale (that script is 1,516 lines and multi-purpose) stands. Record
      in the header that a non-zero exit from `check-extension-docs.sh` is expected and parsed, not
      treated as a probe failure.
- [x] Add duplicated-block detection across scripts, bounded exactly as scoped: normalize each
      line (strip comments, collapse whitespace), slide a fixed window (8-12 lines, the chosen
      size stated in the header with its rationale), hash each window, and report only windows
      occurring 3+ times or spanning 2+ files. Per script emit `duplicate_blocks` (count) and
      `duplicate_block_peers` (sorted array of co-occurring script paths). State in the header
      that this is deliberately not clone detection and that sophistication is deferred.
- [x] Add a stable ranked ordering: an explicit documented composite score (e.g. lines, with
      zero-caller and duplicate-block participation as documented modifiers) plus a deterministic
      tiebreak on path. Emit `rank` per script and a top-level `ranking` array. The scoring formula
      must be written out in the header so a future reader can audit a target choice against it.
- [x] Add `--check` mode semantics: print the per-script table and exit non-zero on a declared
      finding class (zero callers, or manifest drift), exit 0 otherwise — mirroring
      `measure-eager-context.sh --check`.
- [x] Extend `tests/test-script-inventory.sh`: manifest-registered true and false cases; a
      synthesized duplicated block detected across two fixture files; a below-threshold near-
      duplicate NOT reported; rank ordering stable across two runs on the same fixture;
      `--check` exit code 0 and non-zero both demonstrated.
- [x] Run the suite to green.

**Timing**: 2.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the duplicate-block detector is buildable in-budget with
no precedent in the repository (the research report confirmed zero hits for `jscpd`, `simhash`,
`duplicate.*block`, `dup.*detect`). Confirm at implementation time by timing the detector over the
full 194-file corpus before extending it; if a naive all-pairs comparison is too slow, keep the
hash-bucket approach and lower the window count rather than widening scope. If the detector
cannot be made both fast and non-noisy within the phase budget, ship it reporting only
cross-file windows (drop the within-file case) and say so in the header — never drop the item.

**Files to modify**:
- `agent-system/extensions/core/scripts/script-inventory.sh` - add manifest check, duplicate-block
  detection, ranked ordering, `--check` mode
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - add covering test groups

**Verification**:
- Probe run over the real source store emits valid JSON with a `ranking` array whose first entry
  is `orchestrate-cycle-plan.sh` (the expected evidence-based top target)
- Two consecutive runs over the same root produce identical output modulo the single documented
  timestamp field — diff them explicitly
- `bash agent-system/extensions/core/scripts/tests/test-script-inventory.sh` exits 0, all cases
  passing, output read unpiped
- `bash -n` clean on both files

---

### Phase 3: Register the probe; act on the zero-caller findings [COMPLETED]

**Goal**: the probe is a first-class, registered, documented repo-health probe, and its
zero-inbound-caller findings are dispositioned (removed or justified) rather than merely reported.

**Tasks**:
- [x] Add `script-inventory.sh` and `tests/test-script-inventory.sh` to
      `agent-system/extensions/core/manifest.json` `provides.scripts` (the array already carries
      204 entries including `tests/*.sh`, so both belong there). Re-read the file immediately
      before editing — siblings are live in this cycle.
- [x] Add a `docs/reference/utility-scripts-inventory.md` entry for `script-inventory.sh`
      alongside the `assess-repo-health.sh` (line ~10) and `measure-eager-context.sh` (line ~29)
      entries, following their one-paragraph format exactly: what it measures, source-store-not-
      deployed-tree note, `--check` semantics, and the deliberate over-count caveat on caller
      counts.
- [x] Run the probe over the real source store and capture its output to
      `specs/250_script_corpus_inventory_and_engine_decomposition/probe-baseline.json` for the
      record.
- [x] Verify reproducibility formally: two full runs, `diff` of the two outputs with the timestamp
      field filtered, must be empty (acceptance item 1).
- [x] Disposition every zero-inbound-caller script the probe names (acceptance item 2): for each,
      either delete it (only when it is genuinely unreferenced and not a documented entry point —
      and then also remove its `provides.scripts` entry and any test), or record a one-line
      justification. Justifications go in this task's implementation summary under `specs/**`;
      they must NOT be written into any deliverable file as task-numbered prose
      (`no-task-references-in-deliverables.md`). Expect most zero-caller hits to be legitimate
      standalone entry points (probes, migrations, user-invoked utilities) — say so per script
      rather than in aggregate.
- [x] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm the two
      new scripts raise no Rule E / Rule Q drift.
- [x] Run the full gate set for this phase (see Verification).

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the zero-caller set is small enough to disposition
individually in-budget. Confirm at implementation time by counting the zero-caller entries in the
probe's own output BEFORE starting the disposition pass; if the count exceeds ~15, disposition the
ranked top 15 in this phase, record the exact remaining count and their paths in the summary, and
state plainly that the remainder is deferred — do not silently narrow the acceptance criterion.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - register both new scripts in `provides.scripts`
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - add the probe entry
- (conditionally) any zero-caller script selected for deletion, plus its manifest entry and test

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` succeeds and both entries are present
- Two-run reproducibility diff is empty modulo the documented timestamp field
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no new drift
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green — read the summary line AND
  the exit code, and do NOT pipe through `tail`/`head`
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow` no worse than at task
  start (expected clean on the two now-closed 2026-10-02 items)

---

### Phase 4: Baseline capture, then extract the territory-contention concern [COMPLETED]

**Goal**: a pre-refactor `--dry-run` baseline is captured, and the four territory/contention
helpers move out of `main()` into `scripts/lib/territory-contention-lib.sh` with behaviour
byte-identical.

**Tasks**:
- [x] Re-check task 272's status in `specs/state.json` (`project_number==272`,
      `honest_session_liveness_concurrent_batches`). It declared `orchestrate-cycle-plan.sh` in
      its own file_scope and was `not_started` at plan time. If it has moved off `not_started`,
      STOP and report rather than editing the file. *(completed: still `not_started`, confirmed
      immediately before the first edit)*
- [x] Re-read `orchestrate-cycle-plan.sh` immediately before any edit (siblings are live on this
      shared tree) and re-confirm the 3,026-line figure and the function extents above.
      *(completed: 3026 confirmed via `wc -l`, and the four functions' line extents re-confirmed
      by direct read at 2243-2255, 2257-2321, 2350-2368, 2370-2469)*
- [x] Capture the baseline FIRST, before any edit: run a representative multi-task `--dry-run`
      invocation (`--state-file specs/state.json --dry-run <three task numbers>`, no `--session`
      — the script synthesizes a non-persisted identity under `--dry-run`) and save both the JSON
      payload and the human table to
      `specs/250_script_corpus_inventory_and_engine_decomposition/dry-run-baseline/`. Record
      `md5sum specs/state.json` before and after the baseline run and confirm it is unchanged.
      *(completed: tasks 22, 29, 170; md5 e894e8f1... unchanged)*
- [x] Record the pre-extraction `wc -l` of `orchestrate-cycle-plan.sh`. *(completed: 3026)*
- [x] Enumerate the locals each of the four helpers closes over on `main()` — measured at plan
      time as `effective_group` (an associative array), `session_id`, `new_cycle_count`,
      `CONTENDED_MANIFEST_DIR`, `PROJECT_ROOT`, plus the `lookup_project`/`task_lookup_*` and
      `scopes_overlap` helpers. Write the enumeration down before moving any code.
      *(completed, with a correction: `scopes_overlap` is NOT actually referenced anywhere in the
      extracted region -- confirmed by grep across the exact 2183-2469 span -- so it was never a
      real closed-over dependency, only a plan-time anticipation. Of the five named variables,
      only `effective_group` is a true function-local of `orchestrate_cycle_plan_main` (`declare
      -A` without `-g`, inside its body); `session_id` and `PROJECT_ROOT` are plain top-level
      script globals set before that function is even defined, and `new_cycle_count` /
      `CONTENDED_MANIFEST_DIR` are bare, non-`local` assignments inside its body, which bash
      treats as ordinary globals. See the deviation below.)*
- [x] Create `scripts/lib/territory-contention-lib.sh` holding
      `_sibling_territory_classify_entry` (13 lines), `build_sibling_territory` (65),
      `_paths_contend` (19), and `build_contended_manifest` (100). Convert every closed-over local
      into an explicit parameter; pass `effective_group` as a serialized JSON task-to-phase map
      rather than attempting to pass a bash associative array. The lib must source or complement
      `lib/file-scope-overlap.sh` (which owns `scopes_overlap`/`path_covered_by_scope`) rather
      than re-deriving its primitives.
      *(deviation: altered -- the parameter-conversion instruction was replaced with a verbatim,
      byte-for-byte relocation of the four functions' bodies (no parameter list added, no
      JSON-serialization of `effective_group` introduced), after confirming experimentally (two
      minimal fixtures, one with a scalar `local`, one with a `local -A` associative array) that
      bash scopes `local` DYNAMICALLY by call stack, not lexically by textual nesting -- a
      function `source`d from a separate file still sees a caller's locals when invoked from
      within that caller's own execution. This makes the verbatim move byte-identical BY
      CONSTRUCTION (the exact same code executes in the exact same scoping environment), which is
      strictly safer than hand-converting five call sites to explicit parameters and risking a
      silent behavior change in the conversion itself. The lib complements
      `lib/file-scope-overlap.sh` as instructed: `_paths_contend`'s containment check was NOT
      swapped for `scopes_overlap` (a different predicate -- Containment, not Overlap, per
      `context/patterns/file-footprint-overlap.md`'s own Non-Goals section -- swapping would be a
      semantic change the behaviour-preserving mandate forbids), and
      `_sibling_territory_classify_entry`'s glob-detection character class is the SAME
      transcription `file-scope-overlap.sh`'s own header already names as one of three existing
      bash copies of that test, not a new fourth copy.)*
- [x] Replace the two contiguous regions in `orchestrate-cycle-plan.sh` (lines ~2183-2321 and
      ~2323-2469, ~286 lines including their banner comment blocks) with a `source` of the new lib
      plus the adjusted call sites. Keep the banner comments that explain WHY (the isolation-posture
      decision record) with the code, in the lib.
      *(completed: 287 lines removed and replaced with a 6-line pointer comment; no call site
      needed to change, since the function names are unchanged and now resolve via the sourced
      lib)*
- [x] Register `lib/territory-contention-lib.sh` in `manifest.json` `provides.scripts`.
- [x] Verify green and byte-identical before committing (see Verification).

**Timing**: 2.5 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts 197 lines of function body across four helpers (286 lines
of contiguous region) is extractable in one agent run, and that the closed-over-local set is the
six items enumerated above. Confirm at implementation time by re-deriving the closed-over set
mechanically from the moved text before editing the call sites; if it is materially larger than
six, extract `build_contended_manifest` + `_paths_contend` alone in this phase (the pair Group 31
already covers end to end) and move `build_sibling_territory` +
`_sibling_territory_classify_entry` into Phase 5.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh` - new file: the four helpers
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - remove the two regions, source the lib, adjust call sites
- `agent-system/extensions/core/manifest.json` - register the new lib

**Verification**:
- `--dry-run` JSON payload and human table byte-identical to the captured baseline for the same
  representative multi-task invocation — `diff` both explicitly, do not eyeball
- `md5sum specs/state.json` unchanged across the `--dry-run` call
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` green, with
  Group 31 (contended-path manifest producer, lines 4456+) passing specifically
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green — summary line AND exit code,
  unpiped
- `wc -l orchestrate-cycle-plan.sh` materially reduced versus the recorded pre-extraction figure
- No test weakened, skipped, or deleted — `git diff` on the suite shows additions only

---

### Phase 5: Extract the task-classification concern [COMPLETED]

**Goal**: the classification helpers and their sections move into
`scripts/lib/task-classification-lib.sh`, behaviour byte-identical.

**Tasks**:
- [x] Re-read `orchestrate-cycle-plan.sh` immediately before editing; re-confirm line numbers
      shifted by Phase 4. *(completed: re-grepped all four call sites after Phase 4's edit;
      is_terminal_status 1558, in_json_array 1575, task_has_forced_phase 1589,
      task_is_build_heavy_implement 1947 — all shifted -4 lines from the pre-Phase-4 figures)*
- [x] Create `scripts/lib/task-classification-lib.sh` holding `is_terminal_status` (13 lines),
      `in_json_array` (4), `task_has_forced_phase` (9), and `task_is_build_heavy_implement` (8) —
      34 lines of function body across four disjoint regions (~119 lines with their banner
      comments and the build-heavy `task_type` membership array at ~1919-1951).
      *(completed, with a size correction: the actual disjoint-region total measured by precise
      line extraction is 67 lines (13+4+18+32), not ~119 — the ~119 estimate over-counted;
      corrected in the lib's own header)*
- [x] State plainly in the lib header that this is a small extraction: the honest size is ~119
      lines, not the 535 an earlier line-delta estimate suggested. The lib's value is cohesion and
      testability, not line count. *(completed, using the re-measured 67-line figure)*
- [x] Convert closed-over locals to explicit parameters: `canonical_force_phases_json` and the
      `mt_get_json` accessor are the two `task_has_forced_phase` reads directly. Move the
      build-heavy `task_type` family array into the lib as its single declaration site and single
      reader, preserving the existing "single array, single reader" comment contract.
      *(deviation: altered — same rationale as Phase 4: `canonical_force_phases_json` and
      `mt_get_json` are both plain top-level script globals (set/defined before
      `orchestrate_cycle_plan_main()` is even defined), so no parameter-conversion was needed or
      performed; the four blocks moved verbatim, byte-identical by construction via bash's dynamic
      `local` scoping. The "single array, single reader" contract IS preserved: confirmed via grep
      that `BUILD_HEAVY_TASK_TYPES` has exactly one declaration (in the lib) and exactly one
      reader (`task_is_build_heavy_implement`, also in the lib), and
      `task_is_build_heavy_implement` itself has exactly one call site, in
      orchestrate-cycle-plan.sh's bucketing loop.)*
- [x] Replace the four regions in `orchestrate-cycle-plan.sh` with a `source` of the new lib plus
      adjusted call sites. *(completed: no call site needed adjustment, since function/array names
      are unchanged and now resolve via the sourced lib; each of the four regions replaced with a
      1-4 line pointer comment)*
- [x] Register `lib/task-classification-lib.sh` in `manifest.json` `provides.scripts`.
- [x] Verify green and byte-identical before committing.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the four helpers total 34 lines of body / ~119 lines of
region, and that the build-heavy `task_type` array has exactly one declaration site and one
reader. Confirm at implementation time by grepping for every call site of all four functions and
for the array's name before moving anything; a second reader of the array would change the
extraction shape and must be handled explicitly rather than assumed away.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` - new file: the four helpers plus the build-heavy family array
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - remove the four regions, source the lib, adjust call sites
- `agent-system/extensions/core/manifest.json` - register the new lib

**Verification**:
- `--dry-run` JSON payload and human table byte-identical to the Phase-4 baseline — `diff` both
- `md5sum specs/state.json` unchanged across the `--dry-run` call
- `test-orchestrate-cycle-plan.sh` green, with Groups 1 (eligibility), 2 (forced phases), and 8
  (cycle budget) passing specifically — these exercise the moved predicates
- `run-all.sh` green — summary line AND exit code, unpiped
- No test weakened, skipped, or deleted

---

### Phase 6: Extract the inter-cycle redeploy checkpoint; close the acceptance sweep [NOT STARTED]

**Goal**: the largest cohesive region of `main()`'s straight-line body moves into
`scripts/lib/redeploy-checkpoint-lib.sh`, and the full acceptance set is demonstrated.

**Tasks**:
- [ ] Re-read `orchestrate-cycle-plan.sh`; re-confirm the region boundaries after Phases 4-5.
- [ ] Enumerate every local the region at ~771-1250 reads and writes on `main()` before moving any
      code. Measured at plan time: 480 lines total, 183 non-comment/non-blank, spanning the
      "(k, part 2) Inter-cycle redeploy checkpoint" and "Post-deploy reconcile pass" banners, and
      already delegating to `lib/deploy-baseline-lib.sh` and `lib/deploy-ledger-lib.sh`.
- [ ] Create `scripts/lib/redeploy-checkpoint-lib.sh` holding the checkpoint and reconcile logic
      as named functions with explicit parameters. Note in its header that this region performs
      real side effects (`deploy-headless.sh`, `verify-deploy.sh --skip-slow`) and is therefore
      never reached under `--dry-run` — the lib must preserve that gating, not relocate it.
- [ ] Replace the region in `orchestrate-cycle-plan.sh` with a `source` plus the call sites.
- [ ] Register `lib/redeploy-checkpoint-lib.sh` in `manifest.json` `provides.scripts`.
- [ ] **Declared fallback** (use only if the enumerated closed-over-local set makes the whole
      region unsafe to move in one run): extract the leaf "Post-deploy reconcile pass" sub-region
      (~1144-1250, ~107 lines) alone into the same lib, land it green, and record the deferred
      remainder explicitly in the summary. This phase must land a lib and a diff either way — an
      analysis-only outcome is out of contract.
- [ ] Record the final `wc -l` of `orchestrate-cycle-plan.sh` and state the reduction as a measured
      ratio against the Phase-4 pre-extraction figure.
- [ ] Record, as a follow-up recommendation in the summary (not as work attempted here), that
      `main()`'s remaining straight-line stage body is the bulk of what is left and warrants its
      own task.
- [ ] Run the complete acceptance sweep.

**Timing**: 2.5 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the ~771-1250 region is one cohesive, extractable concern
of 480 lines / 183 code lines. Confirm at implementation time by enumerating its closed-over
locals mechanically before editing; the declared fallback above is the response if that enumeration
shows the region is not cleanly separable. Also confirm the region's line numbers have shifted as
expected by Phases 4-5 rather than assuming the plan-time figures still hold.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` - new file: checkpoint and reconcile logic
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - remove the region, source the lib, adjust call sites
- `agent-system/extensions/core/manifest.json` - register the new lib

**Verification**:
- `--dry-run` JSON payload and human table byte-identical to the Phase-4 baseline (acceptance 4) —
  `diff` both explicitly
- `md5sum specs/state.json` unchanged across the `--dry-run` call
- `test-orchestrate-cycle-plan.sh` green, including Group 6 (dry-run no-mutation) and Groups 4/5
  (lock refusal + session-id invariant, the LIVE path)
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green (acceptance 5) — read the
  summary line AND the exit code, and do NOT pipe through `tail`/`head`
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow` no worse than at task
  start (acceptance 6)
- `bash agent-system/extensions/core/scripts/script-inventory.sh --check` runs clean and its
  ranking reflects the now-smaller `orchestrate-cycle-plan.sh` (acceptance 1 re-confirmed)
- `wc -l` reduction stated as a measured ratio (acceptance 3)
- No test weakened, skipped, or deleted anywhere in the task

---

## Testing & Validation

- [ ] `tests/test-script-inventory.sh` green, covering every probe metric including both branches
      of `has_test`, `manifest_registered`, `--check`'s exit codes, the zero-candidate degenerate
      root, and the no-side-effects assertion
- [ ] Probe output reproducible across two consecutive runs modulo one documented timestamp field
- [ ] `test-orchestrate-cycle-plan.sh` green after EACH extraction, not only at the end
- [ ] `--dry-run` JSON payload and human table byte-identical to the pre-refactor baseline after
      each extraction
- [ ] `md5sum specs/state.json` unchanged across every `--dry-run` invocation
- [ ] `run-all.sh` green, read unpiped (summary line AND exit code)
- [ ] `verify-deploy.sh --skip-slow` no worse than at task start
- [ ] `check-extension-docs.sh` reports no new Rule E / Rule Q drift for any new script or lib
- [ ] `bash -n` clean on every new and modified `.sh` file
- [ ] Every zero-inbound-caller script removed or individually justified
- [ ] No test weakened, skipped, or deleted at any point

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/script-inventory.sh` (new, standing probe)
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` (new)
- `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh` (new)
- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` (new)
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` (new; added to file_scope
  at plan time per the dispatch's SCOPE DISCIPLINE instruction, harvested from this plan's
  "Files to modify" fields)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (reduced ~3,026 -> ~2,200)
- `agent-system/extensions/core/manifest.json` (five new `provides.scripts` entries)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (probe entry)
- `specs/250_script_corpus_inventory_and_engine_decomposition/probe-baseline.json`
- `specs/250_script_corpus_inventory_and_engine_decomposition/dry-run-baseline/` (JSON payload +
  human table, captured before the first extraction)
- Implementation summary under `specs/250_script_corpus_inventory_and_engine_decomposition/summaries/`

## Rollback/Contingency

- Each phase commits only when green, so rollback granularity is one phase. Revert the phase's
  commits with an explicit file list; never a directory or glob `git add`/`checkout`.
- Before any intentional rollback that discards uncommitted work, run
  `bash .claude/scripts/git-snapshot.sh 250` first. For an ordinary defensive checkpoint before a
  risky extraction, use `bash .claude/scripts/git-snapshot.sh 250 --no-revert` — never the bare
  reverting default as a routine checkpoint.
- The extractions (Phases 4-6) are independent of each other and of the probe (Phases 1-3): any
  one can be reverted without disturbing the others, because each replaces a disjoint region and
  is verified byte-identical against the same single baseline.
- If an extraction cannot be made byte-identical, revert that phase and record the specific
  divergence in the summary rather than accepting a behaviour change — the dispatch's
  behaviour-preserving requirement is not negotiable against convenience.
- Phases 1-3 are additive (new files plus two registration edits); reverting them removes the
  probe without touching the engine.
