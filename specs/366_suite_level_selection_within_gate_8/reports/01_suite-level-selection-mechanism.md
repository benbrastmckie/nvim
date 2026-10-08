# Research Report: Task #366

**Task**: 366 - Suite-level selection within Gate 8: --filter/--only in run-all.sh plus the touched-file-to-suite mapping
**Started**: 2026-10-08T06:02:00Z
**Completed**: 2026-10-08T06:24:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/**, scripts/tests/**, manifest.json, ROADMAP.md, shell-script-testing.md, plan-format.md), live measurement scripts run against the source-store tree
**Artifacts**: - specs/366_suite_level_selection_within_gate_8/reports/01_suite-level-selection-mechanism.md
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- The gap is confirmed exactly as described: `run-all.sh`'s flag surface is `--quiet`,
  `--timings FILE`, `--jobs N|auto`, `--fail-on-new` only — zero matches for `--filter`/`--only`
  (grep-verified). `verify-deploy.sh --only-gate` is the only naming precedent in the codebase for
  this shape of flag; no `--filter`-style flag exists anywhere in the corpus to match against.
- The suite population has grown since the dispatch text's figures were recorded: **100** suite
  files exist today under `agent-system/extensions/core/scripts/{tests/,}test-*.sh` (91 narrow +
  9 flat), not 92, and `run-all.sh`'s own cross-extension discovery (it scans every
  `agent-system/extensions/*/` directory, not just core) finds **119** total across five
  extensions (core 100, books 4, lean 6, literature 7, typst 2). This task's own file_scope is
  core-only, and the deployed-vs-source hazard below is **exclusively a core phenomenon** (zero
  hits in the other four extensions), so scoping the mapping to core is sound.
- **Re-measured deployed-vs-source ratio**, using the exact `grep -l '\$REPO_ROOT/\.claude' *.sh`
  methodology the prior Gate-8-parallelization measurement used (recovered from
  `specs/archive/262_.../plans/01_redeploy-checkpoint-cost-reduction.md:137` and
  `batch-orchestration-guardrails.md:635`): **52 of 91** files in `scripts/tests/` match today
  (57.1%), closely tracking the prior **41 of 73** (56.2%). Scoped to all of core's 100 suites it
  is 52/100 (52%). The ratio is stable across the suite count's growth, which is itself useful
  evidence that this is a structural property of the corpus, not a one-off count.
- The naming-convention mapping the dispatch cites (`guard-destructive-git.sh <->
  test-guard-destructive-git.sh`, `lint-NAME.sh <-> test-lint-NAME.sh`) holds well for
  `scripts/lint/*.sh` (10/12 clean) but **breaks down for `scripts/lib/*.sh` and most flat
  `scripts/*.sh`**: only 7/20 lib files and 34/83 flat scripts match a strict basename pairing.
  The remainder are exercised by suites with non-matching names, often **many suites per shared
  lib file** (e.g. `task-lookup-lib.sh` is referenced by 20 different suites). A purely
  filename-convention mapping would therefore escalate to the fail-safe full sweep far more often
  than the touched-file set actually warrants.
- A **working reference-based mapping already exists and should be reused, not reinvented**:
  `script-inventory.sh`'s `has_test` field is the declared mechanical mapping precedent, and a
  grep-based (not filename-convention-based) extension of its own `inbound_callers` logic,
  inverted (grep every suite for the touched basename), finds a mapped suite for **107 of 125**
  core scripts (85.6%). The remaining **18 scripts have zero reference in any suite** — this is
  the concrete, measured "genuinely unmapped" population the fail-safe test (acceptance item 3)
  should exercise.
- `script-inventory.sh`'s own `has_test` implementation has an undocumented bug relevant to this
  task: it resolves nested/flat test candidates relative to **the candidate's own enclosing
  directory** (e.g. `lib/tests/test-X.sh`, `lib/test-X.sh`), which never matches this corpus's
  actual convention of `scripts/tests/test-X.sh` one level up from `scripts/lib/` or
  `scripts/lint/`. Its own header already documents the basename-suffix caveat
  (`lib/common.sh` <-> `test-common-lib.sh`) but not this directory-level miss. `has_test` should
  not be reused verbatim for `lib/`/`lint/` candidates without fixing or bypassing this.
- The deployed-vs-source hazard is real but is **already a decided, accepted trade-off**, not an
  open design question this task must solve: Settled decision 15 already accepts Gate 8's reduced
  deployed-tree coverage under `--skip-slow`, and the dispatch itself states a selected-subset
  pass "must not be presented as" evidence doc-sync pins hold — the same caveat, generalized. The
  recommended resolution is **transparency, not exclusion**: classify each mapped suite's
  subject-resolution order and surface (never silently drop) suites whose only candidate is
  deployed-first, rather than trying to force every mapped suite into a source-reliable shape.

## Context & Scope

This is the MECHANISM half of a two-task batch (task 368 is the GUIDANCE half and depends on this
one). The scope is: (1) a subset-selection flag on `scripts/tests/run-all.sh`; (2) a durable
touched-file -> suite mapping library (`scripts/lib/suite-selection-lib.sh`, the declared
candidate home); (3) a proven fail-safe path for unmappable touched files. `manifest.json`'s
one-line test registration and `verify-deploy.sh` are explicitly out of file_scope (Settled
decision 17 carve-out (b)); Gate 8's own full-sweep invocation at `verify-deploy.sh:591` must stay
unchanged and selection must be strictly opt-in. No web research was needed or performed — this is
entirely a codebase-measurement task, and the measurements below are the deliverable.

## Findings

### Codebase Patterns

**`run-all.sh`'s existing flag surface and composability constraints** (confirmed by direct
reading, `agent-system/extensions/core/scripts/tests/run-all.sh`):
- Flags today: `--quiet`, `--timings FILE`, `--jobs N|auto` (capped at 4, `JOBS_CAP=4`),
  `--fail-on-new`. No `--filter`/`--only` anywhere (`grep -c -- '--filter\|--only' run-all.sh`
  returns zero outside this task's own future addition).
- The nested-invocation guard (`RUN_ALL_NESTED=1`, line ~173) forces `--jobs 1` when `run-all.sh`
  is invoked from inside another `run-all.sh`'s own suite (e.g. a suite that shells out to
  `verify-deploy.sh`, whose Gate 8 is `run-all.sh` itself). A selection flag must not interact with
  this guard's semantics — it governs job count, not suite membership.
- The sequential path (`--jobs 1`, lines ~283-325) and parallel path (`--jobs >1`, lines ~325-500)
  are two separate code branches, deliberately kept apart so the sequential path's byte-identical
  contract is trivially true by inspection. A selection flag's suite-list filtering must happen
  **before** `SUITES=()` is split into `SKIP_INDICES`/`LOAD_SENSITIVE_INDICES`/`SCHEDULE_POOL`, so
  both paths see an already-narrowed `SUITES` array and need no duplicated filtering logic.
- `LOAD_SENSITIVE_BASENAMES` (5 suites) always runs serially before the parallel pool regardless of
  `--jobs`; `TOTAL_ACCOUNTED` (line ~429) asserts every discovered suite lands in exactly one of
  SKIP/LOAD_SENSITIVE/POOL. A selection flag narrowing `SUITES` before this point keeps
  `TOTAL_ACCOUNTED` self-consistent for free — the accounting is against whatever `SUITES` ends up
  holding, not against a fixed expected count.
- `known-failures.txt` classification (EXPECTED/NEW) and `--timings` both iterate whatever
  `SUITES` was discovered/selected — no changes needed there either, confirming Settled decision
  13's framing that selection is a separate axis from the known-failures manifest.
- **Precedent for the flag's shape**: `verify-deploy.sh --only-gate N[,M,...]` (lines ~79-130)
  validates every comma-separated token as an integer in a bounded range *before accepting any of
  them* ("a partially-valid list must refuse loudly, not silently run a subset") and is
  additive-only (absent, `GATES_FILTER` is empty and every gate runs — byte-identical to before
  the flag existed). This is the only naming/validation precedent in the corpus for this exact
  shape of flag; no `--filter PATTERN` precedent exists anywhere to compare against.

**Suite-population counts** (measured live, 2026-10-08):
| Location | Count |
|---|---|
| `core/scripts/tests/test-*.sh` (narrow, excl. `run-all.sh`) | 91 |
| `core/scripts/test-*.sh` (flat) | 9 |
| **Core total** | **100** |
| `books`, `lean`, `literature`, `typst` combined | 19 |
| **Grand total `run-all.sh` would discover** | **119** |

The dispatch's own "92 suites" figure (and `manifest.json`'s "92 entries") is lower than today's
100-in-core / 119-overall count — the corpus has grown since that figure was recorded, consistent
with the dispatch's own instruction to re-measure rather than carry old figures forward.

**Deployed-vs-source subject resolution — re-measured.** The original 41-of-73 figure's exact
method was recovered from `specs/archive/262_reduce_redundant_verify_deploy_passes/plans/
01_redeploy-checkpoint-cost-reduction.md:62`: `grep -l '\$REPO_ROOT/\.claude' *.sh | wc -l`. Running
the identical command today:
- `scripts/tests/` (91 files, matching the original measurement's directory scope most closely):
  **52/91 = 57.1%** (was 41/73 = 56.2%).
- All of core (100 files, tests/ + flat): **52/100 = 52%**.
- Other four extensions with suites (books, lean, literature, typst — 19 files): **0/19** — this
  hazard is a core-only phenomenon.

Manual inspection of several matching files shows the methodology is coarser than "prefers
deployed" implies: a file is flagged by this grep if it contains the literal substring **anywhere**,
including inside a candidate array that is **not** the first-tried entry. `test-validate-state.sh`
is the clearest example — its top-level `VALIDATOR_CANDIDATES` array lists the deployed path
first, but four later, newer candidate arrays in the same file
(`D5_VALIDATOR_CANDIDATES`/`FS_VALIDATOR_CANDIDATES`/`SCOPE_VALIDATOR_CANDIDATES`/
`WIDEN_VALIDATOR_CANDIDATES`) all list the **source-store** sibling first, with the deployed path
only as a fallback. The binary per-file "prefers deployed" framing is therefore a conservative
over-count at the level of individual assertions, even though it is the correct, exact
replication of the methodology the prior task used and therefore the right comparison point for
re-measurement. The resolution-order granularity that actually matters for this task's mapping is
**per candidate array**, not per file — see Recommendations.

**The naming-convention mapping's real coverage.** Measured against core's 125 non-test `*.sh`
files (83 flat, 20 `lib/`, 12 `lint/`, 10 `deprecated/`):
| Directory | Files | Strict basename match (`tests/test-<base>` or flat `test-<base>`) |
|---|---|---|
| `lint/` | 12 | 10 (83%) |
| flat `scripts/*.sh` | 83 | 34 (41%) |
| `lib/*.sh` | 20 | 7 (35%, using the `test-<base>.sh` **or** `test-<base>-lib.sh` suffix the corpus actually uses) |

`lint/` strongly supports the dispatch's claimed convention. `lib/` and flat `scripts/` do not: the
majority of misses are **not** actually untested — they are exercised by suites with differently
named, often many-to-one, references. For example `task-lookup-lib.sh` is referenced by 20
different suites (`test-orchestrate-churn.sh`, `test-git-commit-scoped.sh`,
`test-phase-heartbeat.sh`, `test-dispatch-metrics.sh`, ... ), and `file-scope-overlap.sh` by 10. A
grep-based reference search (inverting `script-inventory.sh`'s own `inbound_callers` idea: search
every suite file for the touched basename, rather than searching every source file for a caller)
closes almost all of this gap: **107 of 125** core scripts (85.6%) have at least one suite
referencing their basename somewhere. The **18 with zero reference anywhere** are:
`audit-deletion-references.sh`, `claude-cleanup.sh`, `events-query.sh`, `export-to-markdown.sh`,
`generate-context-line-counts.sh`, `install-aliases.sh`, `install-extension.sh`,
`install-systemd-timer.sh`, `issue-grouping.sh`, `measure-eager-surface.sh`,
`memory-harvest.sh`, `migrate-directory-padding.sh`, `migrate-state-legacy-fields.sh`,
`reconcile-artifacts.sh`, `tier-selection.sh`, `uninstall-extension.sh`,
`validate-context-index.sh`, `validate-index.sh`. This is the concrete population the fail-safe
test (acceptance item 3) should use as its fixture — a touch to any one of these 18 should
demonstrably escalate to the full sweep.

**`script-inventory.sh` is an existing, reusable foundation, not a clean drop-in.** Its `has_test`
field (lines ~416-430) already implements the filename-convention pairing this task's item (2)
asks for, and its own header (lines ~112-116) already documents the basename-suffix caveat
(`lib/common.sh` tested by `test-common-lib.sh`, not `test-common.sh`). What its header does
**not** document: `has_test`'s `nested_test`/`flat_test` candidates are built from `dir`, the
**candidate's own dirname** (e.g. `scripts/lib` or `scripts/lint`), so it checks
`scripts/lib/tests/test-X.sh` and `scripts/lib/test-X.sh` — neither of which can ever exist, since
this corpus's actual convention places all tests one level up, in `scripts/tests/`, regardless of
whether the subject lives in `scripts/`, `scripts/lib/`, or `scripts/lint/`. This directory-level
mismatch, not just the basename-suffix one, is why `has_test` under-reports lib/lint coverage more
severely than its own header admits (ROADMAP's "Unfiled observations" section already flags
`has_test` as under-reporting generally, for a different, related reason — the `inbound_callers`
field's own vacuous-manifest-reference issue — but not this specific directory bug).
`scripts/lib/manifest-routing-lib.sh` is the best structural precedent for the new
`suite-selection-lib.sh`: "sourced (never executed)", single source of truth, documented contract
header, basename-keyed data shape matching `known-failures.txt`/`suite-cost-hints.txt`'s own
convention.

**Reference test-authoring precedent.** `test-verify-deploy-gate-selection.sh` is the
`shell-script-testing.md`-cited reference example for testing a selection flag, and it is
deliberately written to invoke **only** the source-store copy of its subject
(`$CORE_DIR/verify-deploy.sh`), never a deployed-path candidate — explicitly to sidestep the
deployed-vs-source hazard for the flag's own test. The new suite-selection test suite should follow
this same shape: no deployed-path candidate for its own subject, so it cannot itself become one of
the 52 deployed-preferring suites this task is trying to reason about.

### External Resources

None consulted — this is a pure codebase-measurement task with no external library, API, or
tutorial dependency. All findings above are derived from direct reading and live measurement
against this repository's own source-store tree.

## Decisions

- **Scope the mapping to `agent-system/extensions/core` only.** The deployed-vs-source hazard,
  the naming-convention gaps, and the file_scope are all core-specific; the other four
  extensions with suites show none of this hazard and are out of this task's file_scope.
- **Treat `script-inventory.sh`'s `has_test` as a starting reference, not a reusable function as-is.**
  Its directory-resolution bug (checking `<subject-dir>/tests/` instead of the fixed
  `scripts/tests/`) makes it unsuitable to call directly for `lib/`/`lint/` candidates without a
  fix. `suite-selection-lib.sh` should implement its own basename-keyed lookup against the single,
  fixed `scripts/tests/` + flat `scripts/` locations `run-all.sh` itself already scans, rather than
  depending on `has_test`'s per-candidate-directory logic.
- **The fail-safe direction is escalation to the full sweep, per the dispatch's own house
  direction**, and the 18-script zero-reference set identified above is the concrete fixture for
  proving it, rather than a synthetic placeholder file with no real-world analog.
- **The deployed-vs-source hazard is resolved by transparency/classification, not by exclusion or
  by forcing a redeploy.** Settled decision 15 and the dispatch's own "must not be presented as
  evidence" language already establish that reduced deployed-tree coverage is an accepted,
  pre-existing property of Gate 8 (true even on a full, unselected run, for these same 52 suites).
  Selection does not need to invent a stronger guarantee than the full sweep already provides;
  it needs to avoid **silently** relying on a stale deployed copy where the full sweep's own prior
  acceptance (`--skip-slow`'s documented trade-off) already covers the same honesty requirement.

## Recommendations

1. **Flag surface: adopt `--only SUITE[,SUITE,...]`, not `--filter PATTERN`.** The mapping library
   produces an exact, resolved list of suite basenames (or the full-sweep sentinel) — never a
   pattern a human would hand-type — so an enumeration flag matching `--only-gate`'s exact
   validate-all-before-running-any semantics is the correct fit. A `--filter PATTERN` flag is not
   demanded by any named caller in this task and would be speculative scope; defer it unless a
   concrete interactive use case is identified (note this explicitly as declined-for-now in
   whatever plan follows, so it is not silently dropped without a record).
2. **Filter `SUITES` immediately after discovery, before the SKIP/LOAD_SENSITIVE/POOL split**, so
   `TOTAL_ACCOUNTED`, `--timings`, and the EXPECTED/NEW classification all operate over the
   already-narrowed array with zero duplicated logic. Validate every `--only` token against the
   discovered `SUITES` basenames up front (unknown token -> exit 2, mirroring `--only-gate`'s
   "refuse loudly" discipline) rather than silently matching nothing.
3. **Build `suite-selection-lib.sh` as a basename-keyed, sourced-only library** (mirroring
   `manifest-routing-lib.sh`'s structural precedent and `known-failures.txt`/
   `suite-cost-hints.txt`'s data-shape precedent), exposing a function that takes one or more
   touched-file paths and returns either a resolved suite-basename list or an explicit
   full-sweep sentinel. Internally: (a) strict basename pairing for `lint/lint-*.sh` (reliable,
   83% clean); (b) grep-based reference lookup (inverting `inbound_callers`) for everything else,
   since basename pairing alone misses the majority of `lib/` and flat `scripts/` coverage; (c) any
   touched file with zero suite references at all (the measured 18-script set) returns the
   full-sweep sentinel.
4. **Record, rather than solve, the deployed-vs-source resolution order** per selected suite: when
   building the mapping, classify each suite's resolution preference for the touched file's basename
   (source-first/source-only vs. deployed-first) and surface this in `suite-selection-lib.sh`'s
   output or a comment-level warning — not as a selection-blocking condition, consistent with
   Settled decision 15's already-accepted trade-off.
5. **Model the new regression suite on `test-verify-deploy-gate-selection.sh`**: source-store-only
   subject resolution (no deployed candidate for its own subject), explicit fixture construction
   for the fail-safe case using one or more of the 18 zero-reference scripts identified above, and
   assertions that a selected run's pass/fail set is a strict subset of an unselected run's
   (acceptance item 2) plus byte-identical no-flag output (acceptance item 5).
6. **Leave `manifest.json` and `verify-deploy.sh` untouched beyond the one-line manifest
   registration**, per the dispatch's own carve-out — confirmed still correct: Gate 8's own
   invocation (`verify-deploy.sh:591`) needs no change since it is designed to keep running the
   full sweep unconditionally, and no caller inside this task's scope needs a `verify-deploy.sh`
   pass-through. Record any future need for one as a follow-up, not scope creep here.

## Risks & Mitigations

- **Risk**: A future plan reuses `script-inventory.sh`'s `has_test` verbatim for the mapping,
  inheriting its undocumented directory-resolution bug for `lib/`/`lint/` candidates, silently
  under-mapping those scripts to "no suite found" more often than reality warrants (fail-safe
  would still fire correctly, but far too often, defeating the task's purpose).
  **Mitigation**: `suite-selection-lib.sh` implements its own fixed-location lookup (always against
  `scripts/tests/` and flat `scripts/`, never a per-candidate-directory guess) rather than calling
  `has_test` directly; this is called out explicitly as a Decision above.
- **Risk**: A selected-subset phase-gate pass gets informally treated by a future agent or human
  as equivalent evidence to a full Gate 8 run, including for the 52 suites that resolve their
  subject from a possibly-stale deployed copy. **Mitigation**: the "must not be presented as
  evidence" language from Settled decision 15 should be echoed verbatim in
  `suite-selection-lib.sh`'s header and in any planning-layer guidance (the companion task 368's
  scope) that tells an agent when to use `--only`.
- **Risk**: `--only`'s validation is implemented as silent best-effort matching instead of
  `--only-gate`'s strict "validate every token before running any" discipline, producing a
  selection that quietly runs zero suites on a typo. **Mitigation**: explicit recommendation 2
  above; the new regression suite should include an invalid-token case mirroring
  `test-verify-deploy-gate-selection.sh`'s own case (c).
- **Risk**: The suite-population counts (100/119) and deployed-vs-source ratio (52/91, 52/100)
  drift again by the time a plan is written from this report, the same way the dispatch's own
  "92 suites" figure had already drifted. **Mitigation**: the plan phase should re-run the exact
  measurement commands recorded in this report's Appendix rather than citing this report's
  numbers as frozen facts, consistent with ROADMAP's Standing rule 5 ("verify by execution, not by
  reading").

## Context Extension Recommendations

- **Topic**: `script-inventory.sh`'s `has_test` directory-resolution gap.
- **Gap**: `context/standards/shell-script-testing.md` and `script-inventory.sh`'s own header
  document the basename-suffix caveat for `has_test` (`lib/common.sh` <-> `test-common-lib.sh`) but
  not the separate, more severe directory-level miss for `lib/`/`lint/` candidates identified in
  this report's Findings. ROADMAP's existing "Unfiled observations" note about `has_test`
  under-reporting is about a different cause (the `inbound_callers` field's own vacuous-reference
  issue) and does not cover this one.
- **Recommendation**: Either fix `has_test` in `script-inventory.sh` (task 328's declared ground,
  per Settled decision 16, as the standing consumer of this probe) to resolve nested-directory
  candidates against the fixed `scripts/tests/` location rather than a per-candidate-directory
  guess, or add a documented caveat alongside the existing basename-suffix one so a future reader
  of `script-inventory.sh`'s output does not trust `has_test: false` for a `lib/`/`lint/` script as
  proof of missing coverage. This is adjacent to, but should not be folded into, task 366's own
  `suite-selection-lib.sh` work, since `script-inventory.sh` is task 328's declared ground.

## Appendix

### Measurement commands (re-run these, do not cite frozen numbers)

```bash
# Suite population counts
cd agent-system/extensions/core/scripts
ls tests/test-*.sh | wc -l        # narrow suites (excl. run-all.sh)
ls test-*.sh | wc -l              # flat suites

# Deployed-vs-source ratio (exact replication of the prior task's methodology)
grep -l '\$REPO_ROOT/\.claude' tests/*.sh | wc -l

# Naming-convention coverage for lint/ (clean precedent)
for f in lint/*.sh; do b=$(basename "$f"); [ -f "tests/test-$b" ] || echo "NO-TEST: $b"; done

# Grep-based reference coverage for a given basename (used for the 18-script zero-reference set)
grep -l "<basename>.sh" tests/*.sh test-*.sh 2>/dev/null
```

### Zero-reference script set (fail-safe fixture candidates)

`audit-deletion-references.sh`, `claude-cleanup.sh`, `events-query.sh`,
`export-to-markdown.sh`, `generate-context-line-counts.sh`, `install-aliases.sh`,
`install-extension.sh`, `install-systemd-timer.sh`, `issue-grouping.sh`,
`measure-eager-surface.sh`, `memory-harvest.sh`, `migrate-directory-padding.sh`,
`migrate-state-legacy-fields.sh`, `reconcile-artifacts.sh`, `tier-selection.sh`,
`uninstall-extension.sh`, `validate-context-index.sh`, `validate-index.sh`.

### Key file:line references

- `agent-system/extensions/core/scripts/tests/run-all.sh` — flag parsing (~86-144), nested guard
  (~173), sequential path (~283-325), parallel path (~325-500), `TOTAL_ACCOUNTED` (~429),
  `LOAD_SENSITIVE_BASENAMES` (~353-384).
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `--only-gate` parsing (~79-130),
  `gate_selected()` (~260-270), Gate 8 call site (~566-596).
- `agent-system/extensions/core/scripts/script-inventory.sh` — `has_test` (~416-430), its own
  documented caveat (~112-116).
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — structural precedent for a
  new sourced-only lib.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — reference
  test-authoring precedent for a selection flag.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — `--jobs`/`--timings`/
  `--only-gate` narrative, known-failures/roster contract.
- `specs/ROADMAP.md` — Settled decisions 13, 15, 16, 17; Unfiled observations on `has_test`/
  `inbound_callers`.
