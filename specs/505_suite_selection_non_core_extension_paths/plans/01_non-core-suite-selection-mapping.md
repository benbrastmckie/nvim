# Implementation Plan: Task #505

- **Task**: 505 - Suite selection fails to resolve a covering suite for non-core extension source paths
- **Status**: [NOT STARTED]
- **Effort**: 4.75 hours
- **Dependencies**: None (ordering-only note with `plan_format_tier_justification_fixes`; no file overlap, no edge filed)
- **Research Inputs**: specs/505_suite_selection_non_core_extension_paths/reports/01_suite-selection-non-core-mapping.md
- **Artifacts**: plans/01_non-core-suite-selection-mapping.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`suite-selection-lib.sh` derives its scripts/tests roots exactly once, from its own file
location, and then evaluates every mapping stratum against that single tree — so a touched path
under `agent-system/extensions/<non-core-ext>/scripts/**` can never find its own extension's
paired suite and falsely escalates to `__FULL_SWEEP__`. This plan adds a per-touched-path
extension-root resolution step inside the library (additive by construction: a core path and a
deployed path both fall through to the roots already computed today), broadens
`suite_selection_classify`'s suite-file lookup the same way so the classification signal reaches
non-core suites too, re-derives the carried "0 of 19" figure the current header rests on instead
of forwarding it, pins all four required behaviours in `test-run-all-selection.sh`, and closes
with a redeploy plus a dual-vantage (source-store and deployed) suite run under the full gate
set.

### Research Integration

Key findings carried into the phase structure:

- The root cause is the one-time root derivation at `suite-selection-lib.sh:114-116`, consumed by
  all three strata inside `_ssl_resolve_one` (stratum 0 self-identity, stratum (a) strict
  basename + `-lib.sh` suffix variant, stratum (b) grep reference lookup). The touched path
  argument's own directory structure is discarded today — only `basename` is used.
- `tests/run-all.sh:343-353` already owns this corpus's one source-store-vs-deployed detection
  idiom (`CANDIDATE_EXT_ROOT` plus a `core/manifest.json` marker check) and its per-extension
  `for ext_dir in "$EXTENSIONS_ROOT"/*/` discovery loop. Both are reused verbatim rather than
  forking a second convention, which is what the dispatch's third hard constraint requires.
- `_SSL_SCRIPTS_ROOT/../..` from the library's own location lands on exactly the same
  `agent-system/extensions/` root that `run-all.sh`'s `$SCRIPT_DIR/../../..` lands on
  (both files sit exactly two directories under their extension root). Confirmed:
  `agent-system/extensions/core/manifest.json` exists.
- The defect reproduces exactly as the dispatch describes. Measured live at planning time:
  `suite_selection_select "agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh"`
  returns `__FULL_SWEEP__`, although `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
  pairs with it by plain strict basename pairing — the simplest possible stratum (a) case.
- The carried "0 of 19 non-core suites match the deployed-vs-source hazard" claim does not
  survive re-measurement: a direct grep for `$REPO_ROOT/.claude|/.claude/` across the 25 real
  non-core suites hits 5 of them. The figure is very likely an artifact of the same core-only
  lookup — `suite_selection_classify` cannot locate a non-core suite file from the source store,
  so it returns its vacuous `source-only` file-not-found fallback for every one of them, which is
  indistinguishable from a genuine absence of the hazard.
- Classification is therefore EXTENDED to non-core suites (research Decisions section), not
  justified as legitimately core-only — the premise for staying core-only is the figure that does
  not hold.
- Resolution is scoped to the ONE extension the touched path itself names, never a
  cross-extension search: broadening stratum (b)'s grep across every extension would risk
  selecting an unrelated extension's suite on a coincidental basename mention, which would be a
  behaviour change for core paths too rather than an additive one.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted and is not
modified by any phase.

## Goals & Non-Goals

**Goals**:

- A touched path under `agent-system/extensions/<ext>/scripts/**`, for any `<ext>`, resolves to
  that extension's own paired suite(s) when sourced from the source store.
- Deployed-mode selection (one merged flat tree) behaves byte-identically to today.
- Every path that resolves to a suite today resolves to the same suite afterwards — no narrowing.
- `suite_selection_classify` locates a non-core suite file and classifies it on real evidence
  rather than returning its file-not-found fallback.
- The library header's scope and classification notes state a freshly measured figure, with the
  measurement command recorded, and name the remaining known limitation honestly.
- `test-run-all-selection.sh` pins (a) non-core resolution, (b) a genuinely uncovered path still
  returning `__FULL_SWEEP__`, (c) deployed-mode selection unchanged, and (d) the classification
  ruling.
- `__FULL_SWEEP__` semantics are untouched: no stratum is weakened or made more permissive.

**Non-Goals**:

- Editing `run-all.sh`, `suite-classification.data`, `suite-cost-hints.txt`, or
  `plan-format.md` — read for context only; none is in this task's declared territory.
- Adding the 7 missing `books`/`typst` rows to `suite-classification.data` (a real, directly
  observed gap recorded in the research report's Context Extension Recommendations; a separate
  follow-up, not this task).
- Supporting a bare relative touched path with no `agent-system/extensions/<ext>/` segment (e.g.
  a caller that `cd`'d into an extension directory and passed `scripts/foo.sh`). Documented as a
  limitation, not special-cased.
- Changing the `--class` / `--tag` / `--cost-class` declarative axis, which is orthogonal to the
  touched-path mapping.
- Any hand edit under `.claude/**`. The source store is the edit target; the deployed tree is
  regenerated by `deploy-headless.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path-segment detection mis-parses an unusual argument shape (an unrelated `extensions` directory name, a relative path) | M | M | Require the literal `agent-system/extensions/<name>/scripts/` substring, and gate the whole branch on the `core/manifest.json` marker; any miss falls through to the pre-existing, already-tested default resolution — never a hard failure |
| An edit accidentally narrows what the selector admits today | H | L | Phase 3's fixtures keep the existing real-corpus cases (lint pairing, the `>= 10` many-to-one lib case, union escalation) untouched and add new cases alongside; Phase 1 re-runs the unmodified suite before any fixture is added |
| Sourcing discipline broken (a `set -e`, an `exit`, a leaked non-`_ssl_` variable) | H | L | Every new helper is `_ssl_`-prefixed, `local`, explicitly `unset` before return, returns 0, and never calls `exit`; Gate 8's shellcheck suite plus a direct source-and-inspect check in Phase 1 |
| The deployed-flat behaviour drifts because the detection branch fires in a deploy | H | L | In a deploy, `_SSL_SCRIPTS_ROOT/../../core/manifest.json` does not exist, so the branch cannot fire; Phase 3 case (c) pins deployed-mode output and Phase 5 runs the suite from the deployed vantage point |
| Classification's extension loop picks the wrong file on an ambiguous suite basename | M | L | Suite basenames are corpus-unique by the existing `test-*.sh` discovery convention; first match wins, and the loop order is the stable `*/` glob order — recorded in the header |
| New header text introduces a task-number reference or record-versioning language under `agent-system/**` | M | M | Header text names durable anchors only (file paths, function names, the measurement command); no "task N", no "previously/no longer/v2" framing. Both repo rules apply to every file this plan edits |
| A sibling task in this same cycle edits a neighbouring file and an unexpected failure looks like this task's regression | M | M | Re-read both target files immediately before editing; stage only this task's two files by explicit path; treat a failure outside the declared `file_scope` as possibly a sibling's in-flight edit and report rather than "fix" it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 2, 3 |
| 5 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. This plan is a single chain: each phase
consumes the previous one's result.

---

### Phase 1: Per-Touched-Path Extension-Root Resolution in `_ssl_resolve_one` [NOT STARTED]

**Goal**: A touched path naming a non-core extension's `scripts/` tree resolves its strata
against that extension's own `scripts/` + `scripts/tests/` directories, while every core path and
every deployed-mode path falls through to the roots already computed today.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` immediately
  before editing (a sibling task may be live in this tree) and re-derive the current line numbers
  for the root derivation block and `_ssl_resolve_one` — the figures quoted in this plan are from
  planning time and move.
- [ ] Add one internal helper, `_ssl_roots_for_path PATH`, emitting exactly two lines (scripts
  root, then tests dir) on stdout:
  - Derive the extensions parent once per call as `${_SSL_SCRIPTS_ROOT}/../..` and accept it only
    if `<parent>/core/manifest.json` exists — the same marker check `tests/run-all.sh` already
    uses. Do not invent a second detection idiom.
  - Extract `<ext>` from the literal substring `agent-system/extensions/<ext>/scripts/` in the
    touched path argument. Anything shorter (a bare `extensions/<ext>/scripts/`) is not accepted.
  - Emit `<parent>/<ext>/scripts` and `<parent>/<ext>/scripts/tests` only when the former is a
    real directory; otherwise emit `${_SSL_SCRIPTS_ROOT}` and `${_SSL_TESTS_DIR}` unchanged.
  - `_ssl_`-prefixed, all locals `unset` before return, always `return 0`, never `exit`, sets no
    shell options.
- [ ] Thread the resolved pair through `_ssl_resolve_one`: call the helper once at the top, hold
  the result in two locals, and replace every use of `_SSL_TESTS_DIR` / `_SSL_SCRIPTS_ROOT`
  inside that function (stratum 0 self-identity, stratum (a) `cand1`/`cand2` existence checks,
  stratum (b) the two `grep -l` scans) with those locals. `suite_selection_select`,
  `suite_selection_unmapped`, and `suite_selection_select_annotated` need no change.
- [ ] Leave `_ssl_discovered_basenames` and the whole `--class`/`--tag`/`--cost-class` section on
  the fixed library-local roots: they enumerate the discovered corpus for the runner, not a
  touched path, and are explicitly out of scope.
- [ ] Confirm by direct invocation that the reported defect is fixed and nothing narrowed:
  `source` the edited library and check that
  `suite_selection_select "agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh"`
  now prints `test-lean-challenge-snapshot.sh` (it printed `__FULL_SWEEP__` at planning time),
  while `suite_selection_select "agent-system/extensions/core/scripts/lib/suite-selection-lib.sh"`
  still prints exactly `test-run-all-selection.sh`.
- [ ] Confirm the sourcing contract: after sourcing in a fresh shell, no `_ssl_*` or `_SSL_SELF_*`
  name introduced by this phase survives, and `$-` is unchanged.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the fixed root pair is consumed at exactly three places
inside `_ssl_resolve_one` (strata 0, a, b) and nowhere else in the touched-path mapping path.
Confirm at implementation time by grepping `_SSL_TESTS_DIR\|_SSL_SCRIPTS_ROOT` across the whole
library and classifying every remaining hit as either threaded (inside `_ssl_resolve_one`),
deliberately fixed (`_ssl_discovered_basenames`, the declarative axis functions), or Phase 2's
ground (`suite_selection_classify`).

**Tier Justification**: `local` — the edit is confined to one sourced library with no public API
signature change, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh`
is the covering check (the exact, measured output of `suite_selection_select` on this file).

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - add `_ssl_roots_for_path`; thread its two-line result through `_ssl_resolve_one`'s three strata

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh`
  passes with the suite's pre-existing case set unmodified (no fixture added yet) — this is the
  no-narrowing evidence for every existing core case.
- The two direct `suite_selection_select` invocations above produce the stated outputs.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
  exits 0 (the repository's sanctioned shellcheck entry point, exit status checked — never the
  bare binary).

---

### Phase 2: Extend `suite_selection_classify`'s Suite-File Lookup Across Extensions [NOT STARTED]

**Goal**: `suite_selection_classify` locates a non-core suite file from the source store and
classifies it on real source-text evidence, instead of silently returning the vacuous
`source-only` file-not-found fallback for every non-core suite — the dispatch's item (2), ruled
by EXTENDING the signal rather than writing a core-only justification.

**Tasks**:

- [ ] Re-read the file before editing.
- [ ] Broaden only the suite-path lookup block at the top of `suite_selection_classify` (the
  `_SSL_TESTS_DIR` then `_SSL_SCRIPTS_ROOT` pair): keep both existing probes first and in order,
  then, when neither hits AND the extensions parent carries `core/manifest.json`, loop
  `for _ssl_ext_dir in "<parent>"/*/` probing `<ext>/scripts/tests/<suite>` then
  `<ext>/scripts/<suite>`, taking the first match. Mirror `run-all.sh`'s own per-extension
  discovery loop shape.
- [ ] Leave every downstream branch of the function untouched: the `.claude`-reference grep, the
  pure-comment-line exclusion, the first-occurrence ordering comparison, and all three emitted
  values. The only change is which file the function can find.
- [ ] Keep the documented fallback intact: a suite basename that still cannot be found or read
  emits `source-only` exactly as today.
- [ ] Factor the extensions-parent derivation so Phase 1's helper and this lookup share one
  implementation rather than two copies of the marker check.
- [ ] Update the `PUBLIC API` header line for `suite_selection_classify` so "resolved against
  this library's scripts tree" states the actual, broadened resolution order.
- [ ] Confirm by direct invocation that a known non-core suite now classifies on evidence:
  `suite_selection_classify test-lean-mcp-preflight-check.sh <a basename that suite references>`
  no longer returns the file-not-found `source-only` (that suite is one of the 5 carrying a
  `.claude` reference), and that a core pair's classification is unchanged from before the edit.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the change is confined to the suite-path lookup block
and the one header API line, leaving all three classification branches byte-identical. Confirm at
implementation time with `git diff` on the single file: every hunk must fall inside either that
lookup block, the shared parent-derivation helper, or the header.

**Tier Justification**: `local` — same single sourced library, no public API signature change, and
the same `run-all.sh --only test-run-all-selection.sh` suite (whose case2c already asserts every
selected suite carries a valid classification value) is the covering check.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - broaden `suite_selection_classify`'s suite-file lookup across every extension; share the extensions-parent derivation with Phase 1's helper; correct the API header line

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh`
  passes (case2c pins the classification value vocabulary).
- The two direct `suite_selection_classify` invocations above behave as stated.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
  exits 0.

---

### Phase 3: Pin All Four Behaviours in `test-run-all-selection.sh` [NOT STARTED]

**Goal**: The suite fails if any of the four required behaviours regresses: non-core resolution, a
genuinely uncovered non-core path still escalating, deployed-mode selection unchanged, and the
classification ruling.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` before
  editing. New cases go in PART 1 (real-corpus, pure-function cases) with
  `common_test_pass`/`common_test_fail` and the existing numbering style; do not disturb cases
  1-3 or 14-25.
- [ ] Derive the non-core fixture DYNAMICALLY, never hardcoded: scan `$CORE_DIR/../../*/` for a
  non-`core` extension directory holding both `scripts/<name>.sh` and
  `scripts/tests/test-<name>.sh`, and take the first such pair. This keeps the suite honest in a
  repo whose extension set differs, and mirrors case 1's existing "never hardcode a basename"
  discipline.
- [ ] Case (a) — non-core resolution: `suite_selection_select` on the derived
  `agent-system/extensions/<ext>/scripts/<name>.sh` path includes `test-<name>.sh` and is not the
  sentinel.
- [ ] Case (b) — honest sentinel preserved: a path under a real non-core extension's `scripts/`
  whose basename no suite in that extension pairs with or references still returns
  `__FULL_SWEEP__`, and `suite_selection_unmapped` names it verbatim. Derive the zero-reference
  candidate dynamically, the same way case 1 does.
- [ ] Case (c) — deployed-mode unchanged: build a synthetic DEPLOYED-shaped fixture under
  `$WORKDIR` (a flat `scripts/` + `scripts/tests/` pair with NO `core/manifest.json` two
  directories above it), copy the real library in at `scripts/lib/`, source that copy in a
  subshell, and assert that a touched path carrying an
  `agent-system/extensions/<ext>/scripts/` segment resolves against the flat merged tree exactly
  as it does today — proving the detection branch cannot fire without the marker.
- [ ] Case (d) — classification ruling: assert that a non-core suite file is now actually located,
  by checking that `suite_selection_classify` on a derived non-core suite/touched-basename pair
  distinguishes evidence-based values rather than returning the file-not-found default for every
  non-core input. Pin the ruling (classification extended to non-core suites), not a specific
  corpus count, so the case does not go stale when a suite's text changes.
- [ ] Guard every derivation: when no non-core extension with a paired suite exists at all (a
  deployed vantage point has no extensions root), the cases must report a clear skip rather than
  a failure — the suite must pass from both vantage points, which Phase 5 exercises.
- [ ] Keep this suite's SOURCE-STORE-ONLY subject-resolution header promise intact: resolve every
  new path from `SCRIPT_DIR`'s siblings, never from a deployed `$REPO_ROOT/.claude` path.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts exactly four new behaviours are pinned, in one file, with
no existing case modified. Confirm at implementation time by diffing the suite and checking that
the pre/post `Results: N passed` count rises by exactly the number of new cases added, with no
previously passing case changing verdict.

**Tier Justification**: `local` — the edit is confined to one test file, and running that file is
itself the covering check: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - add the four pinning cases to PART 1, with dynamic fixture derivation and a deployed-shaped synthetic fixture

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh`
  passes, with every new case PASS and no pre-existing case changing verdict.
- Each new case is shown to be load-bearing: temporarily reverting one Phase 1/Phase 2 hunk makes
  the corresponding case FAIL (then restore).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`
  exits 0.

---

### Phase 4: Re-Derive the Carried Figure and Rewrite the Header Notes [NOT STARTED]

**Goal**: The library's SCOPE and classification header notes state what the corrected code
actually does and a figure measured against it, with the measurement command recorded — the
carried "0 of 19 non-core suites ... a core-only phenomenon today" claim is replaced by a fresh
measurement rather than a bumped denominator.

**Tasks**:

- [ ] Run the corrected `suite_selection_classify` across every real non-core suite discoverable
  in the source store, paired with a touched basename that suite actually references, and record
  the resulting counts per value (`source-only` / `source-first` / `deployed-first`). Record the
  exact command used so a future reader can re-run it.
- [ ] Rewrite the SCOPE block to describe per-touched-path extension resolution: which segment is
  detected, the `core/manifest.json` marker gate, the deployed-flat fall-through, and why the
  change cannot alter deployed behaviour.
- [ ] Replace the carried figure with the freshly measured one, stated as a measurement with its
  command — not as a standing property of the corpus.
- [ ] Record the classification ruling in the RESOLUTION-ORDER CLASSIFICATION block:
  classification now reaches non-core suites, the lookup order (library-local tree first, then the
  per-extension loop), and that first match wins on a basename the discovery convention already
  keeps unique.
- [ ] Document the one remaining limitation: a touched path with no
  `agent-system/extensions/<ext>/scripts/` segment (a bare relative path from inside an extension
  directory) still resolves against the library-local tree.
- [ ] Keep `__FULL_SWEEP__`'s documented meaning untouched, and keep the HONESTY CONSTRAINT block
  as it stands.
- [ ] Write no task numbers and no record-versioning language into the header: name durable
  anchors (file paths, function names, the measurement command) only.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Scope Hypothesis**: this phase asserts its edits fall entirely inside the library's `#` comment
header (the SCOPE, RESOLUTION-ORDER CLASSIFICATION, and PUBLIC API blocks) with zero executable
hunks. Confirm at implementation time by checking that every line in `git diff` for this phase
begins with `#` after the diff marker.

**Tier Justification**: `prose` — the edit is comment-only with no elaboration surface, so the
`prose` row's diff read-through (every changed hunk inside the `#` header block) plus the
recorded measurement command is the covering check; `--only-gate 3,4` has no bearing on a shell
file's internal comments.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - rewrite the SCOPE and RESOLUTION-ORDER CLASSIFICATION header blocks with the re-derived figure, the classification ruling, and the remaining limitation

**Verification**:

- Diff read-through confirming every changed hunk lies inside the `#` header block.
- The recorded measurement command reproduces the figure now written in the header.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-selection.sh`
  still passes (a comment-only edit must not move a single case).
- No occurrence of a task-number reference or record-versioning phrasing in the new header text.

---

### Phase 5: Redeploy and Verify From Both Vantage Points Under the Full Gate Set [NOT STARTED]

**Goal**: The source-store change is deployed, the suite passes from both a source-store and a
deployed vantage point, and the complete gate set is green.

**Tasks**:

- [ ] Re-read both edited files and confirm the working tree holds only this task's changes to
  them (a sibling task is scheduled this same cycle; a foreign modification is reported, not
  absorbed).
- [ ] Run the suite from the SOURCE-STORE vantage point:
  `bash agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`.
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout`
  parameter raised to 600000, per the external-process-wait bounded-wait idiom). The deployed tree
  is stale for `core` and `lean` at planning time, so this also clears that divergence. Never
  hand-patch any file under `.claude/**` as a substitute.
- [ ] Run the suite from the DEPLOYED vantage point:
  `bash .claude/scripts/tests/test-run-all-selection.sh`, confirming the deployed-mode cases pass
  and the non-core derivation cases skip or pass cleanly there rather than failing.
- [ ] Spot-check deployed-mode selection by hand: source `.claude/scripts/lib/suite-selection-lib.sh`
  and confirm a touched path resolves against the merged flat tree exactly as before the change.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Record issues and wins in the task's issue log as they arise, per the dispatch's Issue Log
  section.

**Timing**: 1.0 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the deploy regenerates the whole `.claude/**` tree and
that no file outside this task's two declared source-store files is modified by this task.
Confirm at implementation time with `git status --short` before staging: only the two declared
paths (plus the gitignored deployed tree) may carry this task's changes.

**Files to modify**:

- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/**` tree (whole-tree-claim declaration; no hand edit under `.claude/**`)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` exits 0
  (source-store vantage point).
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully.
- `bash .claude/scripts/tests/test-run-all-selection.sh` exits 0 (deployed vantage point).
- `bash .claude/scripts/verify-deploy.sh` is green — the complete gate set, not a
  `--skip-slow` or `--only-gate` subset. A selected or skipped pass is not evidence here.

---

## Testing & Validation

- [ ] A touched `agent-system/extensions/<non-core-ext>/scripts/<name>.sh` path resolves to that
  extension's own `test-<name>.sh`, not `__FULL_SWEEP__`.
- [ ] Every path that resolved to a suite before the change resolves to the same suite after it
  (the suite's pre-existing real-corpus cases, unmodified, are the evidence).
- [ ] A genuinely uncovered path — core or non-core — still returns `__FULL_SWEEP__`, and
  `suite_selection_unmapped` still names it verbatim.
- [ ] Deployed-mode selection is byte-identical to today, pinned by a synthetic deployed-shaped
  fixture and by a real deployed-vantage run.
- [ ] `suite_selection_classify` locates non-core suite files and classifies them on evidence;
  the three emitted values and all core classifications are unchanged.
- [ ] The library sets no shell options, exports nothing new, leaks no `_ssl_*` name, and every
  function still returns 0 and never exits.
- [ ] The header's figure is reproducible by the command recorded beside it.
- [ ] `test-run-all-selection.sh` passes from both vantage points; `verify-deploy.sh` is green.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` — extension-aware
  per-touched-path resolution, broadened classification lookup, rewritten header notes.
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` — four new pinning cases.
- A regenerated deployed `.claude/**` tree (gitignored deploy artifact, not a committed output).
- This plan, plus the task's issue-log entries for the implementation phase.

## Rollback/Contingency

- Both edited files are tracked and this task holds them alone, so a per-file revert
  (`git checkout HEAD -- <path>` from a clean tree, or a `git revert` of the phase commit) restores
  prior behaviour exactly; redeploy afterwards to bring `.claude/**` back in line.
- Before any risky step, take a non-reverting checkpoint:
  `bash .claude/scripts/git-snapshot.sh 505 --no-revert`. Do not use the default reverting form as
  a routine checkpoint — a sibling task is live in this working tree.
- If Phase 1's detection proves unable to hold deployed behaviour identical (Phase 3 case (c)
  fails and cannot be made to pass without changing deployed output), stop and report rather than
  relaxing the hard constraint: the non-core selection gap stays open and the hand-named covering
  suite remains the documented workaround.
- If the Phase 4 re-measurement turns out to contradict extending classification (for example
  every non-core suite genuinely classifies `source-only` on real evidence), keep the extended
  lookup — it is what makes the measurement trustworthy — and record the measured result in the
  header as the ruling's basis instead of asserting a hazard that does not exist.
