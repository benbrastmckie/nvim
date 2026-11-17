# Implementation Plan: Fixture dependency declaration drift lint

- **Task**: 604 - Fixture dependency declaration drift lint
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/604_fixture_dependency_declaration_drift_lint/reports/01_fixture-dependency-drift-lint.md
- **Artifacts**: plans/01_fixture-dependency-drift-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A test suite under `agent-system/extensions/core/scripts/tests/` that copies helper scripts into
its sandbox declares which helpers to copy as a hand-maintained list. When a copied helper gains a
new `source` dependency, nothing updates that list, and the suite fails at runtime with a bare
"No such file or directory". This plan builds a lint-time detector
(`scripts/lint/lint-fixture-dependency-declaration.sh`), registers it as the next contiguous
`verify-deploy.sh` gate, backs it with a regression suite seeded from the three measured
historical repairs, and writes the convention down in `shell-script-testing.md` for the first
time. No suite's pass/fail semantics and no existing gate's verdict change.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch flagged was checked against the research report and against
live state at plan time. Results stated explicitly, including where the description is confirmed
unchanged:

| Carried claim (dispatch) | Live measurement at plan time | Verdict |
|---|---|---|
| Edit target is `agent-system/extensions/core/**`, never a deployed `.claude/**` tree | `jq -r '.extensions.core.source_dir' .claude-extensions.json` = `/home/benjamin/.config/nvim/agent-system/extensions/core` | **Confirmed**, unchanged |
| "3 suites declare a named array" | `grep -lE '^[[:space:]]*(REQUIRED_LIBS\|REQUIRED_SCRIPTS\|REQUIRED_LIB_SCRIPTS\|REQUIRED_CORE_SCRIPTS)=\(' *.sh` = **8** | **Superseded** — the research report's correction (8, not 3) reproduces exactly against the live tree. The dispatch's own warning ("do not assume the array-declaring three are the population") is what this confirms |
| "8 use require_file" | `grep -l 'require_file ' *.sh` = **8** | **Confirmed**, unchanged |
| "88 reference scripts/lib/ at all" | `grep -l 'scripts/lib/' *.sh` = **90** (of 158 suites total) | **Drifted** by 2, within the noise of the intervening commits the dispatch itself names; does not change any decision below |
| `test-orchestrate-unwind-dispatch.sh` "already fixed to 21/0" | Historical context for why research narrowed to 3 suites; that narrowing is already reflected in the research report | **Confirmed** as historical, not load-bearing on this plan |

### Research Integration

The report's four substantive findings are carried into the phases below: (1) one **unified**
extraction procedure resolves both declaration shapes rather than two shape-specific parsers;
(2) the suite-selection predicate must test for the *behavior* (declares, then copies
`scripts/lib` dependencies into a sandbox), never for an array name or `require_file` alone —
`test-stall-reprompt-wiring.sh` is the measured correctly-excluded case; (3) the
mandatory-vs-optional `source` guard taxonomy (four shapes) is the dominant false-positive risk,
not the two declared shapes; (4) siting lands on route (a), the gate registry — see Decisions.

Two things the report did **not** establish, found at plan time and folded in as phase
obligations rather than left for the implementer to trip over:

- `agent-system/extensions/core/manifest.json`'s `provides.scripts` is an **explicit, non-glob
  list of 409 entries** whose completeness is enforced by `check-extension-docs.sh` Rule Q
  inside `verify-deploy.sh` **gate 3 (commit-blocking)**. Each new script therefore owes a
  manifest entry in the same phase that creates it.
- `context/formats/plan-format.md` carries the one line-number pin into
  `shell-script-testing.md` (`shell-script-testing.md:178-183`), and editing that file re-derives
  `index-entries.json`'s `line_count` (Rule R). Both are declared in Phase 4.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- A lint-time detector that reports a suite whose declared/copied set omits a MANDATORY `source`
  dependency of a script it copies, handling both declaration shapes through one extraction pass.
- A regression suite that would have flagged `lib/project-number-inuse.sh` as missing in all
  three measured pre-repair declarations, one of which is the Shape-2 open-coded suite.
- The detector running automatically on every deploy-verification pass (route (a) siting ruling,
  with its rationale recorded in Decisions, not left implicit in whichever file was edited).
- The dependency-declaration convention written down where a future suite author will find it.

**Non-Goals**:
- Changing any suite's pass/fail semantics or any existing gate's verdict.
- Converting the curated lists into a runtime-derived mechanism (deliberately deferred on
  measured evidence of zero additional drift; do not re-litigate without new measured drift).
- Touching `scripts/tests/run-all.sh` or `scripts/tests/known-failures.txt` — the advisory
  roster-staleness check is a separate, dependent task, and both files are a concurrent sibling's
  declared territory this cycle.
- Adding a `docs/reference/utility-scripts-inventory.md` entry (see Decisions).
- Correcting the stale hand-written gate-count figures in unrelated prose ("22 gates", "23
  gates", "24 gates", all already disagreeing with the registry's 29). They are not derived from
  the registry and chasing them would widen scope for no verdict benefit.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| False positives from the OPTIONAL guard shapes (`_RR_LIB`'s `[ -f "$V" ] && . "$V"`; the log-and-continue `*_CANDIDATES` pass-through) | H | H | The regression suite carries dedicated negative cases for both before the detector gains a gate. A clean run on today's corpus is the cheapest regression anchor available: every current suite is already repaired, so a first-run violation on any current suite is a false positive, not new rigor |
| Shape (iii) is syntactically identical to the MANDATORY shape (i) `*_CANDIDATES` form — only the empty-result branch body distinguishes them (`exit <nonzero>` vs. log-and-continue) | H | M | Classifier inspects the empty-branch body, not the array declaration. Negative case in Phase 2 pins it |
| Gate id collision: concurrent siblings #584 and #601 each register their own new gate row, and `lint-gate-registry.sh` enforces contiguity from 1 | M | M | Gate id is computed at edit time as `max(existing)+1` after re-reading `gate-registry.data`, never hardcoded. 30 is a plan-time estimate, not a reservation |
| New script omitted from `manifest.json` `provides.scripts` → gate 3 Rule Q fails, and the file never deploys | M | H without the mitigation | `sync-manifest-scripts.sh --write` then `--check` in the same phase that creates each script (Phases 1, 2) |
| Phase 4's insertion shifts `shell-script-testing.md` lines 178-183, silently breaking `plan-format.md`'s pin; no mechanical checker exists for line-number pins | L | M | Pin declared in Phase 4's own file list; measure the pinned content before and after and update the citation in the same phase |
| Sibling edits on a shared working tree | M | M | Re-read every target file immediately before editing; stage only this task's own hunks with an explicit file list, never a directory or glob; never run `git-snapshot.sh` in its reverting default mode. If a foreign commit or foreign uncommitted modification appears, STOP and report after checking `git log` |
| A `deploy-root-guard.sh`-sourcing script cannot run from the source store pre-deploy | L | L | The new lint follows `lint-subject-resolution-declaration.sh`, which does **not** source `deploy-root-guard.sh` (measured: 0 occurrences; only 3 of 25 lints source it). Every source-store verification command named below therefore executes as written, pre-deploy |

## Decisions

- **Siting: route (a) — join `scripts/gate-registry.data`.** Two already-registered gates scan
  this identical corpus for an identical class of problem: gate 27
  (`lint-subject-resolution-declaration.sh`, `input_corpus` =
  `agent-system/extensions/core/scripts/tests/*.sh`, `timeout_s=30`, `cost_class=free`) and gate
  29 (`lint-test-root-resolution.sh`, same corpus plus sibling extensions, same budget). A static
  text scan over the same corpus is the same order of cost, so `timeout_s=30`/`cost_class=free`
  fits a stated budget with no new evidence needed. **Rationale for rejecting route (b)**
  (standalone utility script): the task's own stated goal is to report this drift *before* a run
  hits it, which requires the check to run on every deploy-verification pass — a hand-run-only
  script is exactly the kind of check that would itself drift out of use, reproducing in the
  detector the very failure mode it exists to catch.
- **No `docs/reference/utility-scripts-inventory.md` entry.** The two most recently added
  gate-registered lints (gates 27, 29) have no entry there at all; only the older gates (6, 7,
  11) do, and gate 11's entry explicitly states it is "Wired as a verify-deploy.sh gate; not
  automated beyond that". The convention has already shifted toward not duplicate-documenting a
  gate-registered lint, with `gate-registry.data` and the script's own header as the sole
  registration record. Follow the newer precedent.
- **No `gate-cost-model.csv` row and no `suite-cost-hints.txt` entry.**
  `gate-cost-model.csv` is mechanically generated wholesale by `measure-gate-costs.sh` (15 rows
  today, no row per registered gate; nothing checks for one), and `suite-cost-hints.txt` is
  explicitly advisory and also mechanically generated — an unhinted suite simply keeps discovery
  order. Both are a concurrent sibling's declared territory this cycle, so not touching them is
  both correct and the lower-collision choice.
- **Transitive closure implemented, though depth-1 suffices today.** None of the six `lib/*.sh`
  files in the measured population sources anything further, so a depth-1 scan covers the whole
  measured corpus. The closure is implemented anyway because it is cheap and a `lib/*.sh` file
  gaining its own dependency is a plausible future change this lint should survive without
  re-design. The plan records that today's corpus does not exercise that generality, rather than
  presenting the closure as load-bearing.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Detector script [COMPLETED]

**Goal**: `scripts/lint/lint-fixture-dependency-declaration.sh` exists, implements the unified
extraction and the four-shape mandatory/optional classifier, and runs clean against the live
corpus.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/manifest.json` immediately before editing it *(completed)*
- [x] Create `agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh`
      modelled structurally on `lint/lint-subject-resolution-declaration.sh`: the
      `[--verbose] [--quiet] [path...]` CLI, the `[VIOLATION]`/`[PASS]` output convention, and the
      `0`/`1`/`2` exit-code contract every sibling lint already uses, so
      `verify_deploy_extract_verdict_lines '[VIOLATION]' ...` needs no new consumer-side code
      *(completed)*
- [x] Corpus: `scripts/tests/*.sh`, flat and non-recursive — not the shared-corpus `[[ == ]]` glob
      match, whose pattern spans directory separators and would silently widen the scan (the same
      rationale `lint-subject-resolution-declaration.sh` records for itself) *(completed)*
- [x] Suite-selection predicate, **both** conditions required: (a) the file declares at least one
      `require_file "<...>/lib/<name>.sh"` call OR an array whose elements are consumed by such a
      call; AND (b) the file contains at least one `cp` line whose destination resolves under a
      sandbox root (`$WORKDIR/.claude/scripts` or `$root/.claude/scripts` — both literal forms
      are live). A file satisfying (a) without (b) is out of population *(completed: measured
      selection is exactly the 8 named-array + 7 open-coded suites, excluding
      test-stall-reprompt-wiring.sh, matching the research report's corrected population)*
- [x] Declared/copied-set extraction, **one pass, both shapes**: the union of every literal
      `require_file` argument, every literal `cp` argument, every element of any array literal
      consumed by a `for f in "${NAME[@]}"` loop whose body contains a `require_file` or `cp`
      (regardless of array name, and including the combined-array sub-variant that mixes
      top-level and `lib/`-prefixed entries), and every direct `cp "$VAR" "$dest"` line. The
      declared set is "everything this suite's setup actually copies into the sandbox", never
      "the named array's contents" *(completed: implemented as Tier A (direct literal
      `lib/<name>.sh`), Tier B (bare elements of a `*LIB*`-named array), and Tier C (a literal
      word-list for-loop whose body concatenates `lib/$VAR`) — plus GLOB-ALL-LIBS recognition for
      a `cp .../lib/*.sh` wildcard copy, a legitimate third declared-set shape measured live in
      this corpus (test-update-task-status.sh and three open-coded suites) that the research
      report did not separately name)*
- [x] Mandatory-dependency extraction per copied script (resolve each copied-set entry to its real
      on-disk path under `scripts/`, then scan its text), classifying each `lib/<name>.sh`
      occurrence by the four measured shapes: (i) bare `source "..."`/`. "..."` with no enclosing
      `[ -f ... ] &&` on the same line → MANDATORY; (ii) the single-line `[ -f "$VAR" ] && . "$VAR"`
      idiom → OPTIONAL, never reported; (iii) a `*_CANDIDATES=(...)` array plus search loop →
      inspect the empty-result branch body: an `exit <nonzero>` → MANDATORY, a log-and-continue
      with no exit → OPTIONAL; (iv) `if ! . "$PATH" ...; then ... exit/return <nonzero>; fi` →
      MANDATORY *(completed: also added a multi-line variant of shape (ii) — `if [ -f "<literal>"
      ]; then source "<same literal>"; fi` across lines, measured live in issue-record.sh's
      central-log-lib.sh guard — and narrowed shape (iv) to only a column-0 (unconditionally
      reached) occurrence, since an INDENTED occurrence is task-lock.sh's lazy
      `ensure_file_scope_overlap_lib()` wrapper, called only from the one CLI subcommand that
      needs it; the research report itself notes this reachability is undecidable by static
      analysis and drove none of the measured repairs, so it is deliberately never flagged)*
- [x] Recurse into each MANDATORY dependency found — implement as a closure, not a single pass
      *(completed: `transitive_mandatory_libs_of_script`, depth-bounded and visited-set-guarded;
      a corpus-wide sweep at implementation time confirms zero `lib/*.sh` file in today's corpus
      sources a further `lib/*.sh` file, so the closure is currently a no-op beyond depth 1, kept
      for forward-compatibility per the plan's own rationale)*
- [x] Verdict: for each selected suite, any MANDATORY dependency of any copied script absent from
      that suite's own declared/copied set is one `[VIOLATION]` line naming the suite, the copied
      script that needs it, and the missing library *(completed)*
- [x] State the KNOWN LIMITATION plainly in the script header, matching the convention every
      cited sibling uses for itself: a regex/text-level classifier of shapes (i)-(iv), not a shell
      parser; a dependency reached only through an unrecognized shape (a fifth guard idiom, a
      variable-indirected `source "$(resolve_lib foo)"`) is a bounded blind spot, not a soundness
      claim. Record the hybrid shared-fixture suite (`common_test_fixture_overlay`) as a second
      documented blind spot — no such hybrid exists in the measured corpus today *(completed)*
- [x] Add the new script to `provides.scripts`:
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`, then `--check`
      *(completed: required `git add` of the new file first, since sync-manifest-scripts.sh
      diffs against `git ls-files`, not a raw disk walk — an undocumented precondition worth
      recording)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Measured at plan time against the live source store: **8** suites declare a
named array (`REQUIRED_LIBS|REQUIRED_SCRIPTS|REQUIRED_LIB_SCRIPTS|REQUIRED_CORE_SCRIPTS`), **8**
call `require_file`, **90** reference `scripts/lib/` at all, out of **158** suites total. The
research report's further claim — that 7 of the 8 `require_file` callers also carry
sandbox-copy lines and `test-stall-reprompt-wiring.sh` is the correctly-excluded eighth — is a
hypothesis, not a fact. Confirm it by printing the predicate's own selected-suite list under
`--verbose` and comparing against those numbers before trusting the clean run.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's two touched paths taken together (measured at plan time) — the new lint has no paired
suite yet, so no suite subset covers this phase and none may be claimed. Per the sentinel's
source-store sub-case the covering checks are `bash <repo_root>/.claude/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 <repo_root>` (gate 3 carries the Rule Q manifest-completeness check
this phase's `provides.scripts` edit must satisfy) plus a direct clean-corpus run of the new lint
itself.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh` - new detector
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new script
  (derived surface whose completeness gate 3 Rule Q enforces; regenerated in this same phase)

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh --verbose`
  exits 0 with zero `[VIOLATION]` lines against the live corpus
- The `--verbose` selected-suite list includes all 8 named-array suites and the open-coded
  copy suites, and excludes `test-stall-reprompt-wiring.sh`
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no finding for the
  new file
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0

---

### Phase 2: Regression fixture suite [COMPLETED]

**Goal**: `scripts/tests/test-lint-fixture-dependency-declaration.sh` proves the detector flags
`lib/project-number-inuse.sh` as missing in all three measured pre-repair declarations (covering
both shapes) and stays clean on current text and on the OPTIONAL guard shapes.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/manifest.json` immediately before editing it *(completed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-lint-fixture-dependency-declaration.sh`
      following `context/standards/shell-script-testing.md`'s required structural model
      (`mktemp`/trap/pass-fail counters) and the explicit
      `common_test_resolve_subject`/`common_test_declare_subject` declaration pair — gate 27
      enforces the paired declaration on every suite in this corpus *(completed; also added an
      explicit self-exemption in the lint itself for this suite's own heredoc-embedded fixture
      text, matching lint-subject-resolution-declaration.sh's own precedent, rather than relying
      on a coincidental non-violation)*
- [x] Seed three positive fixtures from the exact pre-repair text:
      `git show d3e45535e^:<path to test-postflight-deploy-gate.sh>`,
      `git show 1c10b01f7^:<path to test-redeploy-checkpoint-promotion.sh>`,
      `git show 4c96ccb4f^:<path to test-orchestrate-predispatch-review.sh>`. Confirm each path
      spelling actually resolves at that commit before relying on it — the source-store path may
      differ there. Assert the detector reports `lib/project-number-inuse.sh` missing for each
      *(completed: all three paths resolved as named, no spelling drift)*
- [x] The third fixture is the Shape-2 open-coded suite, so this one fixture set exercises both
      declaration shapes; assert that explicitly rather than leaving it implicit *(completed: each
      case records and asserts its own shape label)*
- [x] Three matching negative fixtures from the same three suites' current text: clean, zero
      violations *(completed)*
- [x] Dedicated OPTIONAL-shape negative cases: shape (ii) — `_RR_LIB`'s
      `[ -f "$V" ] && . "$V"` idiom, deliberately absent from every suite's declared list today —
      and shape (iii) — the log-and-continue `*_CANDIDATES` pass-through
      (`OVERLAP_LIB`/`DEPLOY_FRESHNESS_LIB`). Neither may be reported as missing *(completed:
      isolated as two separate synthetic fixtures, one per shape, each declaring the OTHER
      shape's optional dependency so a misclassification of either is independently detectable.
      The shape-iii case surfaced and drove the fix of a real detector bug — see Plan Deviations
      in the summary — the body-scan was not skipping comment lines, so update-task-status.sh's
      own prose comment describing an unrelated quirk ("...which returns exit 1 at heredoc
      EOF...") was misread as a hard-fail signal)*
- [x] Add the new suite to `provides.scripts`:
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`, then `--check`
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The three commit SHAs (`d3e45535e`, `1c10b01f7`, `4c96ccb4f`) and the claim
that each pre-repair text omits `lib/project-number-inuse.sh` are the research report's
measurement. Confirm each `git show <sha>^:<path>` resolves and that the extracted text actually
omits that library before writing an assertion around it.

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
phase's two touched paths taken together (measured at plan time), so no suite subset covers this
phase and none may be claimed; the covering checks are a direct invocation of the regression suite
this phase creates (every case passing) plus `bash <repo_root>/.claude/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 <repo_root>` for the `provides.scripts` edit (gate 3's Rule Q).

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-fixture-dependency-declaration.sh` - new
  regression suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new suite
  (derived surface gate 3 Rule Q enforces; regenerated in this same phase)

**Verification**:
- The new suite exits 0, every case passing — the three positive pre-repair cases, the three
  current-text negatives, and both OPTIONAL-shape negatives
- `bash agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh --verbose`
  exits 0 (gate 27: the new suite declares its subject)
- `bash agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh --verbose` exits 0
  (gate 29)
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0

---

### Phase 3: Gate registration [COMPLETED]

**Goal**: the detector is registered as the next contiguous `verify-deploy.sh` gate (route (a)),
with a `gate<id>_run` function structurally copied from `gate29_run`.

**Tasks**:
- [x] **RE-READ `agent-system/extensions/core/scripts/gate-registry.data` immediately before
      editing.** Compute the new id as `max(existing id) + 1` at edit time; do **not** hardcode
      30. Concurrent siblings #584 and #601 may each have appended a row, and
      `lint-gate-registry.sh` enforces a contiguous range starting at 1, so a stale assumed id
      breaks the registry *(completed: re-read at edit time found max=29 unchanged, so the
      computed id is in fact 30 -- no concurrent sibling had appended a row yet)*
- [x] Append one TAB-separated 9-field row:
      `<id>` / `Fixture dependency declaration lint (lint-fixture-dependency-declaration.sh)` /
      `gate<id>_run` / `-` / `true` / `30` / `free` / `false` /
      `agent-system/extensions/core/scripts/tests/*.sh`. The `timeout_s=30` / `cost_class=free`
      budget is matched to gates 27 and 29, which scan this same corpus. `-` for `dependencies`
      is the required placeholder, never a genuinely empty field *(completed)*
- [x] Re-read `agent-system/extensions/core/scripts/verify-deploy.sh`, then add `gate<id>_run` as
      a verbatim structural copy of `gate29_run`: the `gate_selected <id>` guard, the
      `say "<id>. ..."` line, `CURRENT_GATE`, the `[SKIP]` branch for a `$TARGET` that is a deploy
      consumer rather than the source store, the `fail` branch for a missing lint script, and the
      `pass`/`fail` + `FINDINGS_LIST` population from
      `verify_deploy_extract_verdict_lines '[VIOLATION]'`. No new `verify-deploy.sh` mechanism is
      required *(completed: gate30_run added verbatim-structurally after gate29_run, before the
      Per-gate bounded execution comment block; no central dispatch table needed editing, since
      the gate loop derives `gate${id}_run` from the registry automatically)*
- [x] Add no `gate-cost-model.csv` row, no `suite-cost-hints.txt` or `known-failures.txt` entry,
      and no `utility-scripts-inventory.md` entry (see Decisions for each) *(completed: none
      added)*

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: The next contiguous gate id is **30** — the measured max in
`gate-registry.data` at plan time is 29. This is an estimate, not a reservation. Confirm by
re-reading the file at edit time and taking `max + 1`.

**Tier Justification**: the cheapest checks that actually cover this phase's edits pre-deploy are
`bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` (the registry's
own structural validator — the enumerated direct dependent of `gate-registry.data`, checking
field grammar, id uniqueness and contiguity) and `bash -n
agent-system/extensions/core/scripts/verify-deploy.sh`; `suite_selection_select` returns 32
suites for this phase's touched paths, deliberately claimed by none of them here because the new
gate cannot execute until Phase 5 redeploys — that 32-suite surface is discharged by Phase 5's
`full` run, not deferred past this plan.

**Files to modify**:
- `agent-system/extensions/core/scripts/gate-registry.data` - one new 9-field gate row
- `agent-system/extensions/core/scripts/verify-deploy.sh` - one new `gate<id>_run` function

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` exits 0 —
  9-field grammar, unique and contiguous id, valid `input_corpus` shape
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` parses cleanly
- The new gate cannot be *executed* in this phase: the deployed `verify-deploy.sh` and
  `gate-registry.data` are still the pre-edit copies until Phase 5 redeploys. Live gate execution
  is deliberately Phase 5's verification, not a bullet this phase can honestly claim

---

### Phase 4: Document the dependency-declaration convention [COMPLETED]

**Goal**: `context/standards/shell-script-testing.md` gains a "Dependency declaration
completeness" subsection — the first written record of this convention anywhere in the corpus.

**Tasks**:
- [x] **RE-READ `agent-system/extensions/core/context/standards/shell-script-testing.md`
      immediately before editing.** It is shared territory with tasks #511 and #523 and with this
      proposal's sibling roster task; no concurrent sibling declares it this cycle, but re-read
      regardless *(completed; no concurrent edit found)*
- [x] Add the subsection near the existing "Required structural model for a new suite" section,
      summarizing: Shape 1 (a named array consumed twice — once by a `require_file`-style
      existence loop, once by the `setup_sandbox()` copy loop), Shape 2 (the open-coded parallel
      `require_file`/`cp` pair with no named array), the four-shape mandatory/optional guard
      taxonomy including the degrade-safe-guard exemption, and the new lint by name and gate id
      *(completed: "Dependency declaration completeness" subsection added immediately after
      that section)*
- [x] Write no task numbers into the prose — `agent-system/**` is outside the `specs/**` exemption
      (`rules/no-task-references-in-deliverables.md`). Cite durable anchors: the lint's filename,
      the gate id, section headings *(completed; confirmed via check-task-references.sh)*
- [x] The one line-number pin into this file is `context/formats/plan-format.md`'s
      `shell-script-testing.md:178-183` citation (measured at plan time by
      `grep -rn 'shell-script-testing\.md:[0-9]'` over `agent-system/extensions/core` — exactly
      one hit). Read the pinned lines' content before the insertion, read them again after, and
      update that citation in this same phase if the insertion shifted them. No mechanical
      checker enforces line-number pins, which is why this is declared here rather than left to a
      gate *(completed: the insertion shifted the pinned content from 178-183 to 232-237; updated
      plan-format.md's citation to match, confirming the shifted content is byte-identical to the
      pre-edit text)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      re-derive `index-entries.json`'s `line_count` for the edited file
      (`check-extension-docs.sh` Rule R's tripwire; advisory by default and auto-healed by
      `deploy-headless.sh`, declared and regenerated here because this phase moves its input)
      *(deviation: altered — the script itself refuses to run from the source store
      (deploy-root-guard.sh-style guard; same class as the memory-context note on this), so the
      mechanical `wc -l`-derived `line_count` value (1427, up from 1373) was written directly
      instead, replicating exactly what `--write` computes. `--check` will self-verify after
      Phase 5's redeploy)*

**Timing**: 45 minutes

**Depends on**: 1

**Scope Hypothesis**: Exactly **one** line-number pin into `shell-script-testing.md` exists in the
source store (`context/formats/plan-format.md`, citing lines 178-183), measured at plan time by
`grep -rn 'shell-script-testing\.md:[0-9]'` over `agent-system/extensions/core`. Re-run that grep
at edit time before relying on it being the only one.

**Verification Tier**: prose

**Tier Justification**: the edit is markdown prose with no compile or elaboration surface, so the
covering checks are the lints that actually apply to it — `bash
<repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` plus `bash
agent-system/extensions/core/scripts/check-record-versioning.sh` and `bash
agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` for the two derived
surfaces this phase moves; `suite_selection_select` returns 53 suites for this phase's touched
paths (a grep-based reference fan-out from the edited standards file, not a real compile
dependency), claimed by none of them here and discharged by Phase 5's `full` run.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new
  "Dependency declaration completeness" subsection
- `agent-system/extensions/core/context/formats/plan-format.md` - line-number pin update, only if
  the insertion shifted `shell-script-testing.md` lines 178-183
- `agent-system/extensions/core/index-entries.json` - re-derived `line_count` for the edited
  context file (coupled generated surface; regenerated in this same phase)

**Verification**:
- Diff read-through confirming every changed hunk is markdown prose
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no new occurrence
- `bash agent-system/extensions/core/scripts/check-record-versioning.sh` reports no new occurrence
- `grep -rn 'shell-script-testing\.md:[0-9]' agent-system/extensions/core` re-run: every pinned
  range still names the content it claimed
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` exits 0

---

### Phase 5: Deploy and full gate verification [COMPLETED]

**Goal**: the source store is redeployed and the new gate is proven to execute and pass in a real
deployed tree, with the complete gate set green and no previously-green gate regressed.

**Tasks**:
- [x] Re-read every file this task touched and confirm no sibling has modified them since; if a
      foreign commit or foreign uncommitted modification is observed, STOP and report after
      checking `git log` to confirm the work is not this task's own *(completed: `git log`
      confirms every commit since Phase 1 is this task's own; `git status --porcelain` shows
      only the same pre-existing foreign dirty files present at dispatch start, none of this
      task's own files among them)*
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` — whole-tree
      regeneration, which is why `__WHOLE_TREE__` is declared below *(completed: landed; its own
      line_count auto-repair found 0 entries to correct, confirming Phase 4's hand-applied
      `index-entries.json` value was already right)*
- [x] Confirm the new lint and the new suite landed in the deployed tree
      (`.claude/scripts/lint/`, `.claude/scripts/tests/`) — if either is absent, the
      `provides.scripts` entry from Phase 1 or 2 did not take *(completed: both present, and
      `.claude/scripts/gate-registry.data`/`.claude/context/standards/shell-script-testing.md`
      carry the new row and subsection respectively)*
- [x] Run `bash .claude/scripts/verify-deploy.sh` — the complete gate set — with `TARGET` the
      source-store repository's own root, which is simultaneously the deploy consumer and the
      source store *(deviation: altered per this dispatch's own Batch Gate Deferral directive --
      this is one of several concurrent `implement`-phase dispatches in a multi-task batch, so
      the complete gate set is deferred to the once-per-invocation batch-level stage rather than
      run independently here. `deploy-headless.sh`'s own internal "fast gates" pass (gates 1-7,
      9-30; gate 8 deferred by that script itself) ran as a side effect of the deploy step above
      and reported gate 30 PASS plus every other non-timed-out gate PASS; gates 3 and 4 hit their
      60s timeout under measured host load (`uptime` load average 8.90 at the time), confirmed a
      transient host-contention artifact, not a regression, by a direct standalone re-run (`bash
      .claude/scripts/verify-deploy.sh --only-gate 3,4 .`) passing cleanly in 42s. The scoped
      discharge actually run: `bash .claude/scripts/verify-deploy.sh --only-gate 30
      --skip-unchanged .` (PASS) plus `bash .claude/scripts/tests/run-all.sh --only
      test-lint-fixture-dependency-declaration.sh,test-lint-subject-resolution-declaration.sh,test-lint-test-root-resolution.sh`
      (3/3 PASS, gate 8's own scoped slice) for the one UNMAPPABLE sub-criterion ("no
      previously-green gate regressed") that neither narrowing invocation alone expresses*
- [x] Confirm the new gate's own `say` line appears in the output, reports a pass, and that the
      run's gate count and verdicts show no previously-green gate regressed *(completed via the
      scoped discharge above: gate 30's own `say "30. Fixture dependency declaration lint..."`
      line appears and reports PASS; every other fast-gate line in the same deploy-headless.sh
      run also reports PASS except the two host-load timeouts addressed above)*
- [x] Confirm the new suite is discovered and green inside Gate 8's battery *(completed: scoped
      `run-all.sh --only` slice above discovers and passes it against the deployed copy)*
- [x] Confirm the new gate's `[SKIP]` branch behaves correctly for a `TARGET` that is a deploy
      consumer rather than the source store *(completed: a scratch directory carrying `.claude/`
      but no `agent-system/extensions` correctly prints the `[SKIP] ... is a deploy consumer, not
      the source store ...` line and `verify-deploy.sh` reports "cannot attest: every gate
      selected ... skipped")*

**Timing**: 45 minutes

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree
  (reserved sentinel per plan-format.md's whole-tree-claim declaration rule; deliberately not a
  real wide path)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set this tier requires, not a
  hand-picked subset — exits 0, with the new gate present and passing
- No previously-green gate's verdict changed, and no suite's pass/fail semantics changed
  (the task's primary non-goal)

## Testing & Validation

- [ ] The detector reports zero violations against the live corpus (every current suite is already
      repaired; a first-run violation on a current suite is a false positive)
- [ ] The detector flags `lib/project-number-inuse.sh` as missing in all three measured pre-repair
      declarations — the regression bar this task owes, covering both declaration shapes
- [ ] Neither OPTIONAL guard shape (`_RR_LIB`'s single-line `[ -f ] &&` idiom; the
      log-and-continue `*_CANDIDATES` pass-through) is reported as missing
- [ ] The selection predicate includes the measured named-array and open-coded copy suites and
      excludes `test-stall-reprompt-wiring.sh`
- [ ] `lint-gate-registry.sh` accepts the new row; the id is contiguous and unique
- [ ] `sync-manifest-scripts.sh --check` and `generate-context-line-counts.sh --check` both exit 0
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 post-deploy with the new gate passing

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-fixture-dependency-declaration.sh` (new)
- `agent-system/extensions/core/scripts/gate-registry.data` (one new gate row)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (one new `gate<id>_run` function)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (new subsection)
- `agent-system/extensions/core/context/formats/plan-format.md` (conditional pin update)
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  (derived surfaces, regenerated)
- The regenerated deployed `.claude/` tree

## Rollback/Contingency

Every phase is additive: a new script, a new suite, one appended registry row, one new function,
one new doc subsection. Nothing existing is rewritten, so reverting is per-file and cheap.

- **Phases 1-4**: revert the phase's own commit(s) with `git revert`, then re-run
  `sync-manifest-scripts.sh --check` and `generate-context-line-counts.sh --check` to confirm the
  derived surfaces are consistent again. No destructive git is needed on uncommitted work
- **Phase 3 specifically**: removing the appended registry row restores a contiguous range
  automatically, since the row is the highest id. Remove the `gate<id>_run` function in the same
  revert so no registry row points at a missing function
- **Phase 5**: a failing post-deploy gate is fixed forward — correct the source store and
  redeploy. Never discard uncommitted work to reach a passing gate
- If a genuine rollback of uncommitted work becomes necessary, use the snapshot-then-rollback
  recipe in `context/contracts/recovery.md`'s rollback rung for the exact invocation shape
  (including its out-of-scope override flag), never a bare precautionary snapshot
