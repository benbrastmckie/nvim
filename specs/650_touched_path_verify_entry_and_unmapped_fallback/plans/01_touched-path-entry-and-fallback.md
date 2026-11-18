# Implementation Plan: Task #650

- **Task**: 650 - Touched path verify entry and unmapped fallback
- **Status**: [IMPLEMENTING]
- **Effort**: 13 hours
- **Dependencies**: None (territory edges to 610, 599, 586, 579, 651; no blocking edge in either direction)
- **Research Inputs**: specs/650_touched_path_verify_entry_and_unmapped_fallback/reports/01_touched-path-entry-and-fallback.md
- **Artifacts**: plans/01_touched-path-entry-and-fallback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The narrowing machinery already ships in core and nothing calls it end to end. This plan adds the
missing caller (`verify-touched.sh`), a declarable resolver interface whose default backend is
`suite_selection_select` unchanged, and a classified per-path fallback that replaces the
`__FULL_SWEEP__` collapse with NO-SUITE-BY-CLASS / EXPLICIT MAP ROW / OWED-NOT-PAID outcomes plus
a convergence report. Nothing is added that competes with `run-all.sh`'s scheduler, its timing
format, or `suite-selection-lib.sh`'s selection engine: the new code is a wrapper, two checked-in
data files, a declaration reader, and one entry point.

Phases are ordered so the externally-consumed contracts land first (the declaration surface, then
the resolver interface shape), because two other records and one consumer repository are waiting
on exactly those shapes and nothing else in this plan is visible outside this repository.

### Premise Re-Validation (dispatch-flagged carried figures)

Each flagged line was checked against the research report and against live state; results stated
explicitly even where unchanged:

- **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/**"** — CONFIRMED unchanged.
  `.claude-extensions.json` is present at the repository root and `.claude/` is a deploy artifact;
  every `Files to modify` entry below is a source-store path and no deployed path is named.
- **Deliverable 1's claimed `run-all.sh` flags** — CONFIRMED unchanged by direct read:
  `--only`, `--jobs N|auto`, `--timings FILE`, `--class`, `--tag`, `--cost-class`, `--fail-on-new`
  all parse today.
- **Deliverable 2's `__FULL_SWEEP__` claim** — CONFIRMED, and re-measured live during this
  planning pass, which strengthened it. `suite_selection_select` over this plan's own Phase 1
  file list returns `__FULL_SWEEP__`, with `suite_selection_unmapped` naming the two new paths;
  the same holds for every phase of this plan that creates a new file. The escalation is
  union-wide: `agent-system/extensions/core/manifest.json` on its own resolves to 32 real suites
  (`test-manifest-scripts-sync.sh`, `test-script-inventory.sh`, `test-index-entries-schema.sh`
  among them), yet pairing it with one not-yet-existing path escalates the whole call to the
  sentinel. This plan's own authoring is therefore a live instance of the collapse deliverable 2
  exists to prevent.
- **Deliverable 2(a)/(c) class-list and fallback-set claims** — CONFIRMED as design intent only;
  neither data file exists yet (`scripts/tests/` holds `suite-classification.data` and
  `suite-cost-hints.txt`, no map or no-class file). Both are created here.
- **Deliverable 5's declaration claim** — CONFIRMED. `.claude-extensions.json`'s sibling-key
  surface exists and already carries two schemas (`derived_artifact_probes`,
  `coupled_generated_surfaces`); no third key exists yet.
- **Deliverable 6's resolver-interface text** — CONFIRMED against the live library: the public
  API is `suite_selection_select` / `_unmapped` / `_classify` / `_select_annotated` with
  `SUITE_SELECTION_FULL_SWEEP_SENTINEL="__FULL_SWEEP__"`, and it maps to shell-suite basenames
  only, exactly as the description states.
- **"A subset pass is never rendered as a full pass"** — CONFIRMED as already-honoured precedent:
  `verify-deploy.sh`'s `--gate8-touched` narrowed branch emits a deliberately distinct pass string
  ("narrowed by --gate8-touched -- NOT a full-battery pass") from the unnarrowed one. The new
  entry point adds a third distinct string rather than reusing either.
- **Coordination premise checked and found NOT as the research report left it**: the report
  advised reading whichever of 599/651 already had a plan or report on disk. Live check: 599, 651,
  610 and 579 are all `not_started` with no `reports/` or `plans/` directory at all. This plan is
  therefore the first to settle the declaration schema, so it defines the key and reserves the
  field names 599 and 651 will need, rather than adopting a shape from them.

### Authoring-Time Evidence: the Validator Inherits the Same Escalation

`validate-artifact.sh` accepts this plan (`[PASS]`) with six advisory warnings, one per phase that
names a suite in its `Tier Justification`. Each warning says the named suites are fabricated
because `suite_selection_select` returns `__FULL_SWEEP__` for that phase's touched paths. The
named suites are not fabricated: they are the measured per-path output for the existing files in
those lists (`manifest.json` resolves to `test-manifest-scripts-sync.sh` and
`test-script-inventory.sh` among 32 suites; `scripts/orchestrate-batch-gate.sh` resolves to
`test-orchestrate-batch-gate.sh` and two others). The warning fires because each list also
contains a path that does not exist yet, and one unresolvable path escalates the whole union to
the sentinel — the exact collapse deliverable 2 replaces.

The justifications below therefore state both measured facts: the union sentinel first, then the
per-path resolution the named suites come from. The advisory warnings are expected at
implementation time and are not a defect in this plan; they become a second, independent
acceptance signal once the Phase 2 resolver is in place, since a per-path resolver removes the
escalation that produces them.

### Research Integration

- The entry point mirrors `orchestrate-build-dispatch.sh`'s existing two-candidate
  deployed-mirror-first / source-store-fallback resolution rather than inventing a third copy; the
  resolution is factored into a library so the directive composer and a future `--gate8-touched`
  caller can share it.
- The preflight is modeled on `verify-deploy.sh`'s `gate0`: it sits structurally outside the
  selection it validates and so cannot be deselected by that selection.
- `--timings` output from a scoped run is diagnostic-only and is explicitly NOT an input to
  `suite-cost-hints.txt`, whose regeneration stays with `measure-gate-costs.sh --regen-hints`
  (its idle-guard and multi-run averaging cannot be satisfied by a scoped, single-sample,
  ambient-load run).
- The owed record is a durable file under the task's own `records/` directory, discharged by
  `orchestrate-batch-gate.sh`, which already runs the complete gate set exactly once per
  invocation and already iterates per-task for finding attribution.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- One callable entry point that turns "these are the files I touched" into a correct, parallel,
  timed, narrowed run with a verdict that cannot be mistaken for a full battery.
- A per-path classified unmapped outcome, never silent, with a durable owed record that only a
  complete unnarrowed run discharges.
- A resolver interface a non-shell consumer repository can implement against, with a conformance
  check that refuses a non-conforming backend before its output is trusted.
- One repository-level declaration surface shared with the project-sources and
  orchestration-close records, not a second one.

**Non-Goals**:
- No second selection engine, scheduler, or timing format; `suite_selection_select` stays the
  default backend unchanged.
- No pytest, Lean, or other language backend — consumer repositories own theirs.
- No change to `suite-cost-hints.txt`'s regeneration authority.
- No new blocking `verify-deploy.sh` gate for coverage convergence.
- No removal of the `__FULL_SWEEP__` sentinel from the library.

## Decisions Settled Here (with rejected alternatives)

1. **Entry-point name**: `verify-touched.sh`, matching the name both consumer repositories
   independently chose. *Rejected*: `scoped-verify.sh` — a new third name for the same shape
   would make the three repositories' prose diverge for no gain.
2. **`__FULL_SWEEP__` survives as an opt-in strict mode.** The sentinel stays in
   `suite-selection-lib.sh` unchanged, and the entry point exposes `--full-sweep` for a caller
   that genuinely wants today's behaviour. *Rejected*: retiring the sentinel — other callers
   (direct scripting, `verify-deploy.sh --gate8-touched`'s own fallback) depend on its existing
   contract, and this record's BINDING clause rules out a second selection engine.
3. **Declared backend composes with the default (union), not replaces it.** `"compose": "union"`
   is the default; `"replace"` is declarable. *Rejected*: replacement-only — a repository whose
   primary suite is pytest but which also ships a few core-authored shell suites would silently
   lose core's own basename coverage.
4. **Coverage report warns, never fails, and adds no gate.** `report-suite-coverage.sh` prints the
   unresolved roster and exits 0; `--strict` makes a nonzero count exit 1 for a caller that wants
   it. *Rejected*: registering it as a blocking gate — the map is expected to converge gradually
   and a blocking gate would refuse every commit until convergence completed, which is a
   reduction in throughput with no corresponding gain in what eventually runs.
5. **One declaration key, with field names reserved for the adjacent records.** A single
   `verification_scope` object carries `tree_roots`, `project_suite_roots` and `resolver`, and the
   documented schema reserves `project_gates` (the project-sources record's need) and
   `closing_gate` (the orchestration-close record's need) as FIELDS of that same object.
   *Rejected*: three sibling keys, one per record — the explicit "not a second declaration
   surface" constraint applies across records, not only within this one.
6. **Timings default is a `mktemp` path, always printed.** `--timings FILE` overrides it.
   *Rejected*: a default under `specs/.orchestration/` — that would add a new runtime artifact
   class to the tracking policy for a diagnostic nobody reads twice.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 599/651 later need a declaration shape this plan's `verification_scope` cannot express | M | M | Phase 1 reserves `project_gates` and `closing_gate` as named fields with documented intent, so those records add fields to one object rather than competing keys |
| The owed-record format cannot be cheaply consumed by the batch gate's existing per-task loop | H | L | Phase 3 fixes the record as plain per-path rows under the task directory the batch gate already iterates; Phase 6 implements the discharge against that exact shape in the same plan |
| The resolver interface is too loose for a real non-shell backend to conform without guessing | H | M | Phase 2 writes the conformance check and the published contract together, and the acceptance test is a deliberately non-conforming fixture backend being refused |
| A new script lands without its `manifest.json` row and never deploys | H | M | Every script-creating phase declares `manifest.json` in its own `Files to modify` and verifies with `run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh` |
| Narrowed selection deselects the suites that assert selection itself | M | H (mechanical) | Phase 7 states the authority rule once: those suites' verdict is authoritative only under the complete unfiltered run, with the entry point's preflight as the independent pre-selection guard |
| Editing indexed `context/**` files moves `index-entries.json` line counts | L | H (mechanical) | Declared in every context-editing phase; reconciled by the Phase 8 redeploy, which auto-repairs it (the detecting check is not commit-blocking in this repository) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 4 |
| 6 | 8 | 5, 6, 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Repository-level `verification_scope` declaration [COMPLETED]

**Goal**: One sibling key on `.claude-extensions.json` carrying this repository's verification
topology, with a reader library following the established fail-open-on-absence contract, and the
schema documented so the two adjacent records add fields rather than competing keys.

**Tasks**:
- [x] Write `scripts/lib/verification-scope-lib.sh`: load the `verification_scope` object with the
      precedent fail-open table (no file / no `jq` / key absent / malformed entry all yield empty,
      never a block), exposing accessors for `tree_roots`, `project_suite_roots` and `resolver`.
      *(completed)*
- [x] Model the loader on `derived-artifact-probe-lib.sh`'s `_derived_probe_load_entries_json`
      shape rather than writing a new JSON-reading idiom. *(completed)*
- [x] Default when undeclared: `tree_roots` is the single resolved repository root,
      `project_suite_roots` is empty, `resolver` is the default backend — i.e. today's behaviour.
      *(completed)*
- [x] Add the `scripts/lib/verification-scope-lib.sh` row to `manifest.json`'s `provides.scripts`.
      *(completed)*
- [x] Document the schema in `context/standards/repo-level-declarations.md`: the object's fields,
      the fail-open table, bash-glob matching semantics where relevant, the reserved
      `project_gates` / `closing_gate` field names with the record each is reserved for, and why
      this is one key rather than three. *(completed: no bash-glob matching applies -- tree_roots
      and project_suite_roots are plain directory paths, not globs)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's paths returns `__FULL_SWEEP__`
(the new library does not exist yet and `repo-level-declarations.md` maps to no suite), while
`manifest.json` alone resolves to `test-manifest-scripts-sync.sh` and `test-script-inventory.sh`
among others, so the covering check is those two suites under `run-all.sh --only` plus
`bash -n` and `lint/lint-shellcheck.sh` on the one new library.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/verification-scope-lib.sh` - new reader library
- `agent-system/extensions/core/manifest.json` - `provides.scripts` row for the new library
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - new schema section
- `agent-system/extensions/core/index-entries.json` - `line_count` for the edited context file goes stale (not commit-blocking here; reconciled by the Phase 8 redeploy)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/lib/verification-scope-lib.sh` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no new finding for the new file.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh --jobs auto` passes.
- Sourcing the library in a repository with no `verification_scope` key yields the documented defaults and prints nothing.

---

### Phase 2: Resolver interface, default backend, declared backend, conformance check [COMPLETED]

**Goal**: A resolver wrapper whose input is a touched-path set plus a tree root and whose output
is a selection token set plus a per-path unresolved list, with `suite_selection_select` as the
unchanged default backend, explicit map rows consulted for what basename resolution misses, an
invocable declared backend, and a conformance check that refuses a non-conforming backend.

**Tasks**:
- [x] Write `scripts/lib/suite-resolver-lib.sh` with the published output shape: `SELECT <token>`
      lines, `UNRESOLVED <path>` lines, nothing else on stdout; exit 0 = resolved (possibly to the
      empty set), exit 3 = this backend cannot resolve at all, exit 2 = usage/shape error. The
      empty-set and cannot-resolve cases are distinguishable by exit code, never by output alone.
      *(completed)*
- [x] Default backend: call `suite_selection_select` / `suite_selection_unmapped` per path, with
      no edit to `suite-selection-lib.sh` (the union-escalation sentinel is handled by the wrapper,
      which resolves per path and never escalates the whole call). *(completed: verified
      suite-selection-lib.sh untouched; Scope Hypothesis confirmed)*
- [x] Explicit-map pre-pass: for a path the default backend leaves unresolved, consult
      `scripts/tests/suite-selection-map.data` (TAB-separated `path_glob`, `suites`, `reason`) and
      emit its suites. This is the "adding a row is the normal repair" surface. *(completed)*
- [x] Create `scripts/tests/suite-selection-map.data` with its format header and the rows this
      plan's own authoring already demonstrates are needed (data files and new libraries under
      `scripts/lib/`). *(completed)*
- [x] Declared backend: invoke `verification_scope.resolver.command` as a command, feeding touched
      paths on stdin and the tree root as `$1`, reading its stdout under the same shape.
      *(completed)*
- [x] Composition: union with the default backend's selection by default; `"replace"` honoured
      when declared. Record both in the library header. *(completed)*
- [x] Conformance check `suite_resolver_conformance_check`: run the declared backend against a
      fixed probe input and refuse (loud, named, non-narrowing) on a malformed line, a stray
      stdout token, or an undocumented exit code. *(completed)*
- [x] Add both new files to `manifest.json`'s `provides.scripts` / data inventory as appropriate.
      *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's paths returns `__FULL_SWEEP__`
(both new paths are unmapped), so the covering check is `bash -n` plus
`lint/lint-shellcheck.sh` on the new library and the `manifest.json`-resolved
`test-manifest-scripts-sync.sh,test-script-inventory.sh` pair under `run-all.sh --only`, with a
hand-run conformance probe against a deliberately malformed fixture backend.

**Scope Hypothesis**: this phase asserts that NO edit to
`agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` is required, because per-path
calls to the existing functions avoid the union escalation. The implementer confirms this by
resolving a two-path set (one mapped, one unmapped) through the new wrapper and checking the
mapped path's suites still appear; if the existing functions cannot be driven per path without
modification, the needed change to `suite-selection-lib.sh` is minimal, justified in the phase's
own notes, and that file is added to this phase's `Files to modify` before the edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/suite-resolver-lib.sh` - new resolver wrapper, default backend, declared-backend invocation, conformance check
- `agent-system/extensions/core/scripts/tests/suite-selection-map.data` - new explicit map rows with a reason per row
- `agent-system/extensions/core/manifest.json` - inventory rows for both new files

**Verification**:
- A two-path probe (one path with a known suite, one not-yet-existing path) emits that path's real
  suites as `SELECT` lines and the other as `UNRESOLVED`, with exit 0 — no sentinel escalation.
- A map row added for the previously unresolved path moves it from `UNRESOLVED` to `SELECT`.
- A fixture backend emitting a malformed line is refused by `suite_resolver_conformance_check`
  with a named reason and a non-zero status, and no selection is trusted from it.
- A fixture backend that exits 3 is reported as cannot-resolve, distinct from one that exits 0 with
  no `SELECT` lines.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh --jobs auto` passes.

---

### Phase 3: Classified unmapped fallback and the owed record [COMPLETED]

**Goal**: Replace "unmapped means run everything now" with a per-path classified outcome:
NO-SUITE-BY-CLASS from checked-in class data, EXPLICIT MAP ROW already handled in Phase 2, and
OWED-NOT-PAID which runs a declared cheap fallback set now and writes a durable owed record.

**Tasks**:
- [x] Create `scripts/tests/suite-selection-noclass.data` (TAB-separated `path_glob`, `lints`,
      `reason`): path classes whose edits cannot change suite behaviour, each row naming the lints
      that do read those paths and a reason. Seed rows for the classes the description names
      (prose/guidance markdown, data files read only by a named lint). *(completed: two rows,
      each confirmed against the named lint's own live-corpus scan scope, not merely filename
      pairing -- agent-definition markdown via lint-agent-contracts.sh's four variants, and
      lint/collapsed-blocks/*.txt registry fixtures via lint-anchor-pointer-collapse.sh)*
- [x] Write `scripts/lib/unmapped-fallback-lib.sh`: classify each `UNRESOLVED` path from the
      Phase 2 resolver into (a) no-suite-by-class, (b) already-mapped (never reaches here), or
      (c) owed; emit a per-path line for each, never silent. *(completed)*
- [x] (c)'s fallback set is selected through `run-all.sh --cost-class free` (or a declared
      `--class`), never a hand-written suite list; the selecting invocation is recorded in the
      library header as the only sanctioned form. *(completed)*
- [x] Owed-record writer: append one row per owed path to
      `<task_dir>/records/full-sweep-owed.jsonl` (`path`, `reason`, `session_id`, `dispatch_seq`,
      `recorded_ts`, `discharged_ts: null`). Plain rows, inspectable, under the directory the
      batch gate already iterates. *(completed)*
- [x] Owed is never forgiven: the writer never deletes a row, and the only mutation it permits is
      Phase 6's discharge stamp. *(completed)*
- [x] Add both new files to `manifest.json`. *(completed)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's paths returns `__FULL_SWEEP__`
(both new paths are unmapped), so the covering check is `bash -n` plus
`lint/lint-shellcheck.sh` on the new library and `run-all.sh --only
test-manifest-scripts-sync.sh,test-script-inventory.sh`, together with a seeded three-outcome
probe run by hand against a temporary task directory.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/unmapped-fallback-lib.sh` - new classification and owed-record library
- `agent-system/extensions/core/scripts/tests/suite-selection-noclass.data` - new class data, reason per row
- `agent-system/extensions/core/manifest.json` - inventory rows for both new files

**Verification**:
- A seeded path matching a no-class row yields NO-SUITE-BY-CLASS naming the lints from that row,
  and runs no suite.
- A seeded path matching a map row yields the mapped suites (outcome (b), via Phase 2).
- A seeded path matching neither yields OWED-NOT-PAID, runs the `--cost-class`-selected fallback
  set, and appends exactly one row to `records/full-sweep-owed.jsonl` in a temporary task dir.
- Re-running the same classification does not duplicate or delete the existing owed row.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh --jobs auto` passes.

---

### Phase 4: `verify-touched.sh` entry point [COMPLETED]

**Goal**: The one command the deferral directive and the authoring contract can name: touched paths
in, preflight, resolve, narrowed parallel timed run out, with a verdict no reader can mistake for
a full battery.

**Tasks**:
- [x] Write `scripts/verify-touched.sh`. Default touched-path derivation: working-tree plus staged
      diff against a named base (`--base REF`, default the repository's own default branch);
      explicit `PATH...` arguments override. *(completed)*
- [x] Preflight, modeled on `verify-deploy.sh`'s `gate0` and running strictly before any
      resolution: the map and class data files parse, every suite basename any data row names
      exists on disk, the declared fallback set is non-empty, and a declared backend passes
      `suite_resolver_conformance_check`. Exit non-zero with a named finding on failure; this
      check sits outside the selection it validates and cannot be deselected by it. *(completed;
      verified with a malformed row, a row naming a nonexistent suite, and the live map data's
      own forward-referencing rows for Phase 8's not-yet-written suite)*
- [x] Dual-mode resolution: deployed mirror first, source store second, via the shared helper
      rather than a third inline candidate array; refuse loudly if neither resolves. *(completed
      with a scope decision: suite NAMES resolve once against this script's own co-located
      tree -- multiple declared roots are identical copies of the same corpus per deliverable 5's
      own framing -- and only the run-all.sh BINARY LOCATION is re-resolved dual-mode per root, in
      an inline two-candidate helper local to this script rather than a new shared library file,
      since no such file is declared in this phase's own Files-to-modify; recorded here rather
      than silently deviating)*
- [x] Multi-root: read `tree_roots` / `project_suite_roots` from `verification_scope`, or take
      `--tree-root`/`--root-set` parameters; never a hardcoded path. *(completed; `--root-set` is
      the same comma-separated-list parameter as `--tree-root`, not a second mechanism; verified
      with a second, non-existent root loudly skipped rather than silently ignored)*
- [x] On a resolved set: `run-all.sh --only <resolved> --jobs auto --timings <file>`. *(completed)*
- [x] On unresolved paths: the Phase 3 classified fallback, never a blind full sweep. *(completed)*
- [x] `--full-sweep`: opt-in strict mode that restores today's behaviour for a caller that wants it.
      *(completed)*
- [x] Output: the resolved suites, the unresolved paths with their classification, the owed record
      path when one was written, and a verdict string deliberately distinct from both the
      unnarrowed `run-all.sh` pass string and `--gate8-touched`'s narrowed pass string. *(completed;
      byte-distinctness confirmed by grep against both source files)*
- [x] Timings: `--timings FILE`, default `mktemp`, path always printed. Header states explicitly
      that this output is diagnostic-only and is NOT an input to `suite-cost-hints.txt`, whose
      regeneration stays with `measure-gate-costs.sh --regen-hints` — with the reason (idle-guard,
      multi-run averaging) so a later reader does not helpfully wire it in. *(completed)*
- [x] Add the script to `manifest.json`'s `provides.scripts`. *(completed)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over
`agent-system/extensions/core/scripts/verify-touched.sh` returns `__FULL_SWEEP__` (the path does
not exist yet), so the covering check is `bash -n` plus `lint/lint-shellcheck.sh` on the one new
script and `run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh`, with the
entry point's own behaviour exercised by a one-file-edit probe run by hand in this phase and
locked into a suite in Phase 8.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-touched.sh` - new entry point
- `agent-system/extensions/core/manifest.json` - `provides.scripts` row for the new script

**Verification**:
- Run on a one-file edit to a mapped source file: it executes a strict subset of the battery, the
  printed suite roster matches the resolver's `SELECT` output, and the verdict line says so.
- The verdict string is byte-distinct from both existing pass strings (grep both out of
  `run-all.sh` and `verify-deploy.sh` and confirm no collision).
- A seeded bad map row (a named suite that does not exist) makes the preflight fail before any
  suite runs.
- `--full-sweep` reproduces the unnarrowed behaviour and labels itself as such.
- The timings path is printed and the file contains the per-suite rows `run-all.sh` writes.
- Invoked from a consumer-style tree with only a deployed `.claude/` mirror, it resolves and runs;
  invoked from the source store, it resolves and runs.

---

### Phase 5: Coverage convergence report [COMPLETED]

**Goal**: A report listing every tree file that resolves to no suite, no map row and no class, so
the map can converge — advisory by default, strict on request, adding no gate.

**Tasks**:
- [x] Write `scripts/report-suite-coverage.sh`: enumerate the tree's tracked files (reusing
      `scripts/lib/git-corpus-enum-lib.sh` rather than a new walk), resolve each through the
      Phase 2 resolver and the Phase 3 classifier, and print the roster of files with no suite, no
      map row and no class, plus a count. *(completed: the Phase 3 classifier's NO-SUITE-BY-CLASS
      lookup logic is reused verbatim rather than calling `unmapped_fallback_classify` directly,
      because that function also WRITES a durable owed record for every OWED path -- correct for
      a real touched-path run, wrong for a whole-tree advisory scan, which would otherwise spam
      records/full-sweep-owed.jsonl for the entire unconverged backlog on every run; recorded in
      the script's own header)*
- [x] Exit 0 by default even on a nonzero count; `--strict` exits 1 on a nonzero count.
      *(completed and verified: default exit 0 on a 23-file unconverged scope, `--strict` exit 1
      on the same scope)*
- [x] Header records the decision and its rejected alternative: this is not registered as a
      blocking gate, because the map is expected to converge gradually and a blocking gate would
      refuse commits until convergence completed. *(completed)*
- [x] Add the script to `manifest.json`'s `provides.scripts`. *(completed)*

**Correction discovered during this phase's own verification**: `suite-selection-map.data`'s rows
(seeded in Phase 2) and the first `suite-selection-noclass.data` row were authored and partly
tested against CORE-EXTENSION-SCRIPTS-RELATIVE paths (e.g. `scripts/lib/suite-resolver-lib.sh`),
but `scripts/verify-touched.sh`'s real touched-path derivation (`git diff --name-only`) and this
phase's own `git_corpus_enum`-based enumeration both always produce REPO-ROOT-RELATIVE paths
(e.g. `agent-system/extensions/core/scripts/lib/suite-resolver-lib.sh`). Every `suite-selection-
map.data` row is fixed to the repo-root-relative form (both data files' headers now say so
explicitly); re-verified against the live, corrected data that the three Phase 1-3 libraries'
own files are no longer reported as unconverged.
- [ ] Add a pointer to the report from the standards text Phase 7 writes (the text itself is
      Phase 7's edit, not this phase's).

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over
`agent-system/extensions/core/scripts/report-suite-coverage.sh` returns `__FULL_SWEEP__` (the path
does not exist yet), so the covering check is `bash -n` plus `lint/lint-shellcheck.sh` on the one
new script and `run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh`.

**Scope Hypothesis**: this phase assumes `git-corpus-enum-lib.sh` already exposes a tracked-file
enumeration the report can consume without modification. The implementer confirms by reading that
library's public functions before writing the walk; if no suitable function exists, the
enumeration is written inline in this script (never by editing the shared library as an unplanned
edit) and the deviation is recorded in the phase notes.

**Files to modify**:
- `agent-system/extensions/core/scripts/report-suite-coverage.sh` - new coverage reporter
- `agent-system/extensions/core/manifest.json` - `provides.scripts` row for the new script

**Verification**:
- The report runs over this repository and prints a roster plus a count.
- Adding a map row for a listed path removes it from the next run's roster.
- Default run exits 0 with a nonzero count; `--strict` exits 1 on the same input.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-manifest-scripts-sync.sh,test-script-inventory.sh --jobs auto` passes.

---

### Phase 6: Owed-sweep discharge at the batch gate [COMPLETED]

**Goal**: The once-per-invocation complete gate run discharges owed records; an orchestration that
ends without discharging leaves them open and reports them.

**Tasks**:
- [x] In `scripts/orchestrate-batch-gate.sh`: after the complete unnarrowed `verify-deploy.sh` run
      succeeds, stamp `discharged_ts` on every open row in each iterated task's
      `records/full-sweep-owed.jsonl`, and record the count in the `batch_gate` key it already
      writes. *(completed; verified in isolation with gate_exit_code=0 discharging a seeded open
      row in task 650's own, temporary `records/` directory)*
- [x] A batch-gate run that did not happen, or that failed, discharges nothing — rows stay open.
      *(completed and verified: gate_exit_code=1 and --dry-run both leave the seeded row open and
      roster it)*
- [x] Add the open-owed count and roster to the `batch_gate` payload so the consolidated output can
      render it. *(completed: owed_discharged_count, owed_open_count, owed_open_roster)*
- [x] Update `context/patterns/orchestrate-batch-results-template.md` so an undischarged owed
      record is rendered in the consolidated output rather than only living in state. *(completed)*
- [x] Update `context/contracts/batch-gate-stage.md` to state the discharge obligation as part of
      the stage's contract. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` resolves
`scripts/orchestrate-batch-gate.sh` to `test-orchestrate-batch-gate.sh`,
`test-gate8-expected-new-distinction.sh` and `test-orchestrate-conclusion-roadmap.sh`, and
`context/contracts/batch-gate-stage.md` to `test-orchestrate-build-dispatch.sh`, so the covering
check is `run-all.sh --only test-orchestrate-batch-gate.sh,test-gate8-expected-new-distinction.sh,test-orchestrate-conclusion-roadmap.sh,test-orchestrate-build-dispatch.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - discharge open owed rows after a successful complete run; carry the count in `batch_gate`
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - render undischarged owed records
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - state the discharge obligation
- `agent-system/extensions/core/index-entries.json` - `line_count` for the two edited context files goes stale (not commit-blocking here; reconciled by the Phase 8 redeploy)

**Verification**:
- A seeded open owed row in a fixture task directory is stamped `discharged_ts` by a successful
  dry-run-less batch gate pass, and the `batch_gate` key records the count.
- The same row is left open when the batch gate's own run fails or does not fire.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-batch-gate.sh,test-gate8-expected-new-distinction.sh,test-orchestrate-conclusion-roadmap.sh,test-orchestrate-build-dispatch.sh --jobs auto` passes.

---

### Phase 7: Authority rule, backend contract, and the directive that names one command [COMPLETED]

**Goal**: State once where selection's own guard suites are authoritative, publish the backend
contract a consumer repository implements against, and rewrite the two prose surfaces so "narrow"
means one command instead of two raw invocations the agent must assemble.

**Tasks**:
- [x] In `context/standards/shell-script-testing.md`, alongside the existing suite-selection
      subsection: state the authority rule — `test-run-all-selection.sh` and the
      `test-*-gate-selection*.sh` suites' PASS is authoritative only under the complete, unfiltered
      run; the entry point's preflight is a second, independent, pre-selection guard for the
      mechanical defect class it can catch; neither requires forcing those suites into every
      scoped selection. *(completed: new "Selection's own guard suites" subsection)*
- [x] In the same file, publish the resolver backend contract: the output shape, the exit codes,
      how "cannot resolve" is reported distinctly from "resolved to nothing", the union/replace
      composition rule, and the conformance check that refuses a non-conforming backend before its
      output is trusted. Write it for a reader who will never see this repository's source.
      *(completed: new "The resolver backend contract" subsection)*
- [x] Point from there to `report-suite-coverage.sh` as the convergence surface. *(completed)*
- [x] Rewrite `context/formats/plan-format.md`'s Verification Tiers narrowing guidance to name
      `verify-touched.sh` as the single command, keeping the existing `--only` / `--only-gate`
      forms documented as what the entry point invokes underneath rather than as what an agent
      assembles by hand. Read the adjacent selector-aggregation prose before editing. *(completed;
      the adjacent selector-aggregation prose at "Decision and rejected alternative" / "Scope" /
      "Promotion criterion" -- validate-artifact.sh's Tier-Justification honesty check -- was read
      and is untouched; it governs a separate mechanical check, not this narrowing guidance)*
- [x] Rewrite `scripts/orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` directive text to
      name the resolved `verify-touched.sh` path (same two-candidate resolution the composer
      already performs, same degrade-to-prose branch when neither exists). *(completed)*
- [x] Update `scripts/tests/test-orchestrate-build-dispatch.sh` for the changed directive text.
      *(completed; 238/238 assertions pass, including every Batch Gate Deferral group)*
- [x] Coordinate by hand with the project-sources record before committing the directive edit:
      both records rewrite this directive and its suite. *(completed: checked live state -- task
      599 is `not_started` with no plan/report on disk, so there is nothing yet to coordinate
      against; this record's edit is the first to land)*

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Tier Justification**: the directive text this phase rewrites is composed into every
implement-phase dispatch and the authoring contract it rewrites governs every plan this system
produces — a cross-cutting surface no suite subset covers, and `suite_selection_select` over this
phase's four paths resolves to roughly 50 suites, which is the battery rather than a subset.

**Scope Hypothesis**: this phase asserts the directive rewrite is confined to
`orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` block (one `echo` sequence) and its one
suite. The implementer confirms by grepping for other composers of the same directive text before
editing; any second composer found is added to this phase's file list before the edit.
**Confirmed**: `grep -rl "Batch Gate Deferral" scripts/*.sh` names only
`orchestrate-build-dispatch.sh` (the composer) and `orchestrate-batch-gate.sh` (a pointer
reference in a header comment, not a second emitter of the directive text) — the Scope
Hypothesis holds; no second composer exists and no file was added.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - authority rule plus the published backend contract
- `agent-system/extensions/core/context/formats/plan-format.md` - narrowing guidance names one command
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - directive names the resolved entry point
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - assertions for the changed directive text
- `agent-system/extensions/core/index-entries.json` - `line_count` for the two edited context files goes stale (not commit-blocking here; reconciled by the Phase 8 redeploy)

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim` passes (complete gate set).
- A composed dispatch file for an implement phase names the resolved `verify-touched.sh` path, and
  the degrade branch still fires when neither candidate exists.
- No task-number reference and no record-versioning language lands in any edited
  `agent-system/**` file (gates 3 and 4).

---

### Phase 8: Coverage suite, registration, redeploy, and the complete gate set [NOT STARTED]

**Goal**: Lock the new entry point's behaviour into a suite whose own authority follows the Phase 7
rule, register everything, regenerate the deployed tree, and close on the complete gate set.

**Tasks**:
- [ ] Write `scripts/tests/test-verify-touched.sh` covering: a one-file-edit run executing a strict
      subset and saying so; the three fallback outcomes under seeded map/class data; an owed record
      surviving until a discharge run clears it; the preflight failing on a seeded bad map row; the
      resolver conformance check refusing a malformed fixture backend; `--full-sweep` restoring the
      unnarrowed behaviour.
- [ ] Follow the required structural model for a new suite (fixtures mutate sandbox copies, never
      the source store; explicit deployed/source-store subject resolution; non-vacuousness check on
      every axis).
- [ ] Add the suite's row to `scripts/tests/suite-classification.data` and its `manifest.json` row.
- [ ] Add map rows for the data files and libraries this plan created, so the next touched-path run
      over them resolves instead of escalating.
- [ ] Redeploy via `deploy-headless.sh`, which also reconciles `index-entries.json`'s line counts
      for every context file this plan edited.
- [ ] Run the complete gate set and record the result.

**Timing**: 2 hours

**Depends on**: 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-touched.sh` - new coverage suite
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for the new suite
- `agent-system/extensions/core/scripts/tests/suite-selection-map.data` - map rows for this plan's own new files
- `agent-system/extensions/core/manifest.json` - `provides.scripts` row for the new suite
- `agent-system/extensions/core/index-entries.json` - line counts reconciled by the redeploy
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-touched.sh --jobs auto` passes, and each axis is shown non-vacuous (it fails when its subject is broken).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh,test-gate8-suite-selection.sh,test-lint-unit-integration-boundary.sh --jobs auto` passes.
- `bash .claude/scripts/deploy-headless.sh` completes and the new scripts appear in the deployed tree.
- `bash .claude/scripts/verify-deploy.sh` passes the complete gate set — the full, unfiltered run whose verdict Phase 7's authority rule makes authoritative for the selection suites.
- `bash agent-system/extensions/core/scripts/report-suite-coverage.sh` runs and its roster no longer lists this plan's own new files.

---

## Testing & Validation

- [ ] The entry point run on a one-file edit executes a strict subset and says so, with a verdict
      string distinct from both existing pass strings.
- [ ] A seeded unmapped path yields each of outcomes (a), (b) and (c) under the matching data.
- [ ] An owed record survives until a batch gate run discharges it, and is reported while open.
- [ ] The preflight fails on a seeded bad map row, before any suite runs.
- [ ] A non-conforming declared backend is refused by the conformance check rather than silently
      narrowing wrongly.
- [ ] The coverage report runs, and a map row added for a listed path removes it.
- [ ] The complete gate set passes after redeploy.
- [ ] Scoped narrowing is used rather than the full aggregator while other sessions are live;
      the final complete run is the one exception and is taken deliberately.

## Artifacts & Outputs

- `scripts/verify-touched.sh` — the entry point.
- `scripts/report-suite-coverage.sh` — the convergence report.
- `scripts/lib/verification-scope-lib.sh`, `scripts/lib/suite-resolver-lib.sh`,
  `scripts/lib/unmapped-fallback-lib.sh` — declaration reader, resolver interface, fallback policy.
- `scripts/tests/suite-selection-map.data`, `scripts/tests/suite-selection-noclass.data` — the two
  checked-in data surfaces, reason per row.
- `scripts/tests/test-verify-touched.sh` — coverage.
- Published contracts in `context/standards/shell-script-testing.md` (authority rule, backend
  contract) and `context/standards/repo-level-declarations.md` (`verification_scope` schema).
- Rewritten narrowing guidance in `context/formats/plan-format.md` and in the
  `## Batch Gate Deferral` directive.

## Rollback/Contingency

Every phase is additive apart from Phases 6 and 7, which edit existing files. Before the first
edit to an existing file, take a non-reverting checkpoint
(`bash .claude/scripts/git-snapshot.sh 650 --no-revert`); the new scripts and data files can be
removed outright with their `manifest.json` rows, and the deployed tree is regenerated from the
source store, so reverting the source-store commits plus one redeploy restores the prior state.
If the declaration schema turns out to be wrong for the adjacent records, only Phase 1's schema
section and the reader's accessors change — every consumer reads through the reader, never the
JSON directly.
