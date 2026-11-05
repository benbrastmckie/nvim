# Implementation Plan: Task #414

- **Task**: 414 - Enforce the gate verdict-line extraction contract mechanically
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: 413, 411 (per state.json)
- **Research Inputs**: specs/414_enforce_verdict_extraction_contract/reports/01_lint-verdict-extraction-anchoring-design.md
- **Artifacts**: plans/01_lint-verdict-extraction-anchoring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The verdict-line extraction contract (`scripts/lib/gate-verdict-extract-lib.sh` plus the prose
section in `context/standards/shell-script-testing.md`) is today defended only by prose: nothing
stops a future author from adding a new extraction site that bypasses
`verify_deploy_extract_verdict_lines`. This plan adds the missing mechanical enforcer — a new
`scripts/lint/lint-verdict-extraction-anchoring.sh` modeled on the existing boundary-lint cluster,
registered as gate 25 in `scripts/gate-registry.data` with a `gate25_run` wiring in
`verify-deploy.sh` — plus a both-polarity fixture suite, a one-sentence pointer from the prose
contract to its enforcer, and the `--only-gate` range-bound fix without which gate 25 could never
be selected individually. Done means: the lint flags both bad shapes distinctly, stays silent on
every intended exemption, satisfies the producer side of the very contract it enforces, and the
full gate set passes against an explicit source-store TARGET after redeploy.

All edits land in the source store `agent-system/extensions/core/**`, never in the deployed
`.claude/**` tree (see `rules/source-store-deploy-boundary.md`).

### Research Integration

The research report is integrated as follows, and its two headline findings shape two whole
phases:

- **Narrow, hand-picked scan corpus** (report Recommendation 2, Decision 1) is adopted as
  written: the lint's default corpus is exactly `scripts/verify-deploy.sh`,
  `scripts/lib/gate-verdict-extract-lib.sh`, and `scripts/lint/*.sh` — not `@extensions`, not
  `scripts/tests/**`, not `hooks/**`, not `orchestrate-cycle-postflight.sh`. This is justified by
  the contract's own stated scope ("Several verify-deploy.sh gates fold a producer script's
  output into FINDING rows"), and it is what keeps the allowlist to a single entry instead of an
  open-ended list grown reactively against dozens of ordinary test-assertion lines.
- **The `--only-gate` bound is already stale at 1-23 and already rejects the existing gate 24**
  (report's live-verified finding). Confirmed independently during planning: `verify-deploy.sh`
  hardcodes `23` in three places (two error messages and one numeric comparison) at its
  `--only-gate` case branch, while `gate_registry_load` has already run by that point in the
  file. Phase 3 fixes this by deriving the bound from `gate_registry_ids` rather than hardcoding
  a fourth literal.
- `test-gate-registry-resolution.sh`'s three hardcoded `24` sites and its separately-stale
  "23-gate registry" comment are confirmed present and are bumped in Phase 3.
- The report's structural prior art is adopted: `lint-state-writer-boundary.sh` /
  `lint-hook-registration-paths.sh` for the lint, `test-lint-hook-registration-paths.sh` for the
  suite (mktemp fixtures, no committed fixture files), `gate24_run` for the gate wiring, and
  gate 24's registry row for the new row's field values.

Two refinements to the research findings were established during planning and are what the phases
below are written against:

1. **The exemption set is tighter than the report assumed.** `gate-verdict-extract-lib.sh`'s
   executable extraction (its `sed`/`grep` pipeline) anchors on a *variable*
   (`$_gvel_anchor_ere`), not on a literal `[FAIL]`/`[VIOLATION]` token, so a literal-token
   candidate pattern cannot match it at all — only its header *comment* lines match. The same is
   true of `lint-json-channel-discipline.sh`'s comment. A Layer-1 structural rule exempting
   comment lines (first non-whitespace character `#`) therefore covers both of those exemptions
   on principle — a commented-out grep does not execute — leaving the file-level
   `EXCLUDED_FILES` allowlist with exactly **one** entry: the new lint's own source, whose
   candidate-pattern and remedy-message literals sit in executable assignment lines rather than
   comments. This is the same two-layer discipline the sibling lints use, not a new convention.
2. **Two wiring obligations the report did not name.** (a) `core/manifest.json`'s
   `provides.scripts` array is an explicit, hand-maintained list — a new script that is missing
   from it is simply never deployed, with no authoring-time signal; the sanctioned repair is
   `scripts/sync-manifest-scripts.sh --write`, which derives the array from `git ls-files`, so
   both new files must be `git add`-ed before it is run. (b) No `run-all.sh` roster edit and no
   suite-selection map edit are needed: `run-all.sh` discovers `scripts/tests/test-*.sh` by glob,
   and `suite-selection-lib.sh` resolves `lint/lint-NAME.sh -> test-lint-NAME.sh` by strict
   basename pairing — which the chosen filenames satisfy by construction.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch (`roadmap_path` absent, `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:

- A new lint that mechanically flags any verdict-token extraction from a captured producer output
  that bypasses `verify_deploy_extract_verdict_lines`, with the unanchored shape and the
  naive-line-start-anchored shape reported as **distinct** verdicts and distinct remedy messages
  (the naive-anchor remedy naming the SGR-stripping requirement by name).
- The lint registered as gate 25 in the declarative registry with a declared timeout, cost class,
  dependencies, source-store requirement, and `input_corpus`, accepted by
  `lint-gate-registry.sh`.
- A both-polarity fixture suite proving each flagged shape is detected from a seeded fixture, the
  correct helper-routed call is not flagged, each intended exemption is not flagged, and the
  lint's own verdict rows satisfy the producer side of the contract (round-trip through
  `verify_deploy_extract_verdict_lines`).
- `--only-gate 25` actually selectable, via a bound derived from the live registry rather than a
  fourth hardcoded literal.
- One sentence in `context/standards/shell-script-testing.md`'s existing verdict-line extraction
  contract section naming the new lint and its gate id.
- A redeployed tree and a green full gate set run against an explicit source-store TARGET.

**Non-Goals**:

- Re-landing any of the four things the dispatch records as already done (the helper, the prose
  contract, the roster-comment note, the three regression suites). None is touched.
- Fixing, allowlisting, or otherwise modifying `orchestrate-cycle-postflight.sh:788`,
  `hooks/validate-handoff-location.sh:105`, or the lean extension's
  `lean-mcp-preflight-check.sh:253`. None is in this task's `file_scope`, and the narrow corpus
  makes touching them unnecessary. If a follow-up is wanted for the postflight site, that is a
  separate task, not a scope expansion here.
- Widening the lint to a repo-wide or `@extensions`-wide corpus.
- Any edit to `context/standards/shell-script-testing.md` outside its existing verdict-line
  extraction contract section (a sibling task sequenced after this one also edits this file).
- Any edit under `.claude/**` as a substitute for a source-store edit plus redeploy.
- Catching variable-indirected or multi-line-assembled extraction sites. That limitation is
  disclaimed in the lint's header, matching every sibling boundary lint.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling task holds `scripts/verify-deploy.sh` (and `scripts/tests/test-verify-deploy-gate-selection.sh`) in its own declared `file_scope` this same cycle | H | H | Re-read `verify-deploy.sh` immediately before each edit; stage only this task's own hunks with an explicit file list (never a directory or glob add); confine the verify-deploy.sh edit to one phase so there is one edit window, not four; do **not** add the `--only-gate` assertions to `test-verify-deploy-gate-selection.sh` (a sibling owns that file) — put them in `test-gate-registry-resolution.sh`, where deriving the bound from the registry legitimately belongs; treat an unexpected failure outside this task's own files as possibly a sibling's in-flight edit and report rather than "fix" it |
| A broad corpus makes the gate red on first landing against files never intended as the contract's targets | H | M | The narrow hand-picked corpus of Phase 1, justified from the contract's own stated scope; Phase 1 verification runs the lint against the live tree and requires a clean result **before** the gate is registered in Phase 3 |
| The lint's own source contains the literal bad shapes (candidate pattern, remedy text) and self-flags | M | H | Single-entry file-level `EXCLUDED_FILES` allowlist with its reason stated inline; Phase 2 asserts the live lint run over the real corpus is clean |
| `gate_registry_ids` degrades to empty (the file's own degrade-safe `gate_registry_ids() { :; }` stub when the library is unavailable), so a max-derived bound becomes empty and every `--only-gate` value is rejected or accepted wrongly | M | M | The derivation must carry an explicit fallback when the id list is empty; Phase 3 verification exercises the degraded path directly, not only the happy path |
| A lint that silently matches nothing passes as working | H | M | Phase 2's seeded-violation fixtures assert detection end-to-end for **each** flagged shape, with the exact distinguishing remedy text asserted, not merely a non-zero exit |
| New scripts missing from `manifest.json` `provides.scripts` are silently never deployed | M | M | Phase 4 runs `sync-manifest-scripts.sh --check` and `--write` after `git add`-ing both new files, and Phase 5's full gate set includes the doc-lint that catches an undeclared script |
| Known-unrelated pre-existing failures (Gate 3 lean4 index.json entry, Gate 20 eager-load budget, Gate 8 suites test-detect-noop-bash.sh / test-four-tier-conflict.sh / test-guard-git-push.sh) misattributed to this work | M | H | Named explicitly in Phase 5's verification criteria as expected and out of scope; do not fix them here |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the verdict-extraction-anchoring lint [COMPLETED]

**Goal**: A standalone, runnable `lint-verdict-extraction-anchoring.sh` that reports the two bad
shapes distinctly over the narrow hand-picked corpus and is clean against the live tree.

**Tasks**:

- [x] Read `scripts/lint/lint-state-writer-boundary.sh` in full as the structural template, and
      `scripts/lint/lint-hook-registration-paths.sh` for its two-layer classification shape. *(completed)*
- [x] Create `scripts/lint/lint-verdict-extraction-anchoring.sh` with: a header stating the
      contract it enforces, a cross-citation of
      `context/standards/shell-script-testing.md`'s "Verdict-line extraction contract
      (producer/consumer)" section, a `DETECTION MODEL` block describing both layers, and a
      `KNOWN LIMITATION` block disclaiming variable-indirected and multi-line-assembled
      extraction (matching the sibling lints' wording discipline). *(completed)*
- [x] Implement argument handling via `lint_corpus_scan_collect_files` /
      `lint_corpus_scan_parse_flags` from `scripts/lib/lint-corpus-scan-lib.sh`, sourcing
      `scripts/lib/common.sh` first per that library's contract: `--verbose`, `--quiet`, and
      positional scan paths (a positional path is what lets the Phase 2 fixture suite point the
      lint at a scratch directory). *(completed)*
- [x] Implement `resolve_project_root` robust to both the deployed
      (`.claude/scripts/lint/`) and source-store (`agent-system/extensions/core/scripts/lint/`)
      invocation locations, as the sibling lints do. *(completed)*
- [x] Set the default corpus to exactly the three hand-picked entries:
      `scripts/verify-deploy.sh`, `scripts/lib/gate-verdict-extract-lib.sh`, and
      `scripts/lint/*.sh` (resolved under the source store). Do **not** default to
      `agent-system/extensions`. *(completed)*
- [x] Implement Layer 1 (`classify_line`) returning three outcomes: `VIOLATION (unanchored)` for
      a bare `grep -F '[FAIL]'` / `grep -F '[VIOLATION]'`; `VIOLATION (naive-anchor, SGR-blind)`
      for a bare `grep -E '^\[FAIL\]'` / `grep -E '^\[VIOLATION\]'` with no SGR strip in the same
      statement; and `EXEMPT: <reason>` otherwise. Classify the two shapes apart by whether the
      matched pattern argument's first character after the quote is `^`. *(completed)*
- [x] Add the Layer-1 comment-line exemption (`EXEMPT: comment line`) for a candidate whose first
      non-whitespace character is `#` — this is what covers
      `gate-verdict-extract-lib.sh`'s explanatory header and
      `lint-json-channel-discipline.sh`'s comment on principle rather than by name. *(completed)*
- [x] Add the Layer-2 `EXCLUDED_FILES` array with its single entry (this lint's own source) and
      that entry's reason stated inline, per the cluster's exemption-marker discipline. *(completed)*
- [x] Emit findings as `echo -e "${RED}[VIOLATION]${NC} $file:$lineno: <message>"` — line-initial
      modulo SGR, exactly one space after the token — so the lint itself satisfies the producer
      side of the contract it enforces. Give the two shapes visibly different remedy text, the
      naive-anchor one naming the SGR-stripping requirement and the helper explicitly. *(completed)*
- [x] Implement the cluster's exit-code contract: 0 clean, 1 violations found, 2 environment or
      bad-scan-path error, with a quiet/verbose summary block. *(completed)*
- [x] `chmod +x` the new script. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts it creates exactly one new file and modifies none.
Confirm at implementation time with `git status --short` showing a single untracked path under
`agent-system/extensions/core/scripts/lint/`; if any existing file turns out to need a change
(for example `lint-corpus-scan-lib.sh` cannot accept a multi-entry default corpus without
modification), record that as an issue and re-check the phase's file list before committing.

**Tier Justification**: `local` is the cheapest covering tier because the edit creates one
self-contained new script with no existing caller yet — the covering checks are
`bash -n scripts/lint/lint-verdict-extraction-anchoring.sh`, the repository's own shellcheck
entry point `scripts/lint/lint-shellcheck.sh` pointed at that single file, and a direct run of
the lint itself; no other module can observe this file until Phase 3 wires it.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh` - new file: the lint

**Verification**:

- `bash -n agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh` parses
  clean.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh`
  exits 0 — the repository's own sanctioned shellcheck entry point (which hardens binary
  resolution), pointed at the one new file, with its exit status checked rather than its stdout
  diffed. This is the same check Gate 22 makes, narrowed to one file.
- `bash agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh --verbose`
  against the live tree exits 0 and its `--verbose` output shows the expected exempt candidates
  (the library header comment lines, the `lint-json-channel-discipline.sh` comment, and the
  lint's own file skipped by the allowlist) — a clean exit with *zero candidates seen* is not
  acceptable evidence, since it would equally indicate a pattern that matches nothing.
- `--quiet`, `--verbose`, a positional-directory argument, and a nonexistent positional path each
  behave per the documented contract (the last exiting 2).

---

### Phase 2: Both-polarity fixture suite for the lint [COMPLETED]

**Goal**: A committed test suite that proves each flagged shape is detected from a seeded
fixture, each intended exemption is not flagged, and the lint's own output satisfies the
producer-side contract.

**Tasks**:

- [x] Read `scripts/tests/test-lint-hook-registration-paths.sh` in full as the structural model
      (`common_test_repo_root`, `common_test_resolve_candidate`, `common_test_workdir_init`,
      `common_test_pass`/`common_test_fail`/`common_test_info`, mktemp `WORKDIR` fixtures,
      no committed fixture files). *(completed)*
- [x] Create `scripts/tests/test-lint-verdict-extraction-anchoring.sh` resolving the
      lint-under-test deploy-tree-first with source-store fallback, as that model does. *(completed)*
- [x] FAILING case: a fixture `.sh` containing a bare `grep -F '[FAIL]'` applied to a captured
      producer-output variable — assert exit 1 and assert the emitted message is the
      **unanchored** remedy text. *(completed)*
- [x] FAILING case: a fixture `.sh` containing a bare `grep -E '^\[FAIL\]'` — assert exit 1 and
      assert the emitted message is the **naive-anchor** remedy text and that it names the
      SGR-stripping requirement. Assert the two messages are not identical to each other, so a
      future merge of the two verdicts into one generic message fails this suite. *(completed)*
- [x] FAILING case: the same two shapes with the `[VIOLATION]` token instead of `[FAIL]`. *(completed)*
- [x] PASSING case: a fixture routing through
      `verify_deploy_extract_verdict_lines '[FAIL]' "$output"` — assert exit 0. *(completed)*
- [x] PASSING case: a fixture reproducing `gate-verdict-extract-lib.sh`'s own shape — the literal
      bad shapes appearing only inside `#` comment lines, plus an executable pipeline anchored on
      a variable — assert exit 0. *(completed)*
- [x] PASSING case: a fixture reproducing `lint-json-channel-discipline.sh`'s comment shape —
      assert exit 0. *(completed)*
- [x] PASSING case: a fixture with an unrelated `grep` and an unrelated bracketed token — assert
      exit 0 (no over-matching). *(completed)*
- [x] Producer-side self-check case (the dispatch's explicit requirement): capture the lint's own
      stdout from a multi-violation fixture, source
      `scripts/lib/gate-verdict-extract-lib.sh`, pipe that output through
      `verify_deploy_extract_verdict_lines '[VIOLATION]' "$output"`, and assert the selected line
      count and content equal the lint's own reported finding set exactly. *(completed: compares
      against the lint's own "Total violations: N" summary line rather than a raw substring
      grep, since a flagged fixture line can legitimately re-quote the bracketed token in its own
      message continuation)*
- [x] Live-corpus case: run the lint with no positional argument against the real source store
      and assert exit 0 — the standing assertion that the gate is not red on the live tree. *(completed)*
- [x] `chmod +x` the new suite; confirm it is auto-discovered by `run-all.sh` (glob-based, no
      roster edit) and that `suite_selection_select` pairs it to the lint by basename. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts it creates exactly one new file and modifies none — in
particular that `run-all.sh` and `suite-selection-lib.sh` need no edit because discovery is
glob-based and pairing is by strict basename. Confirm by running
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-verdict-extraction-anchoring.sh`
and observing the suite is found and executed; if it is not found, the no-edit hypothesis is
false and the phase's file list must be revised before committing.

**Tier Justification**: `local` is the cheapest covering tier because the covering check is the
suite subset `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-verdict-extraction-anchoring.sh`,
which exercises the one new file and the one file it tests, and nothing else in the tree
references either yet.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lint-verdict-extraction-anchoring.sh` - new file: both-polarity fixture suite

**Verification**:

- `bash -n` on the new suite parses clean, and
  `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/tests/test-lint-verdict-extraction-anchoring.sh`
  exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-verdict-extraction-anchoring.sh`
  reports the suite discovered and every case PASS.
- Negative control: temporarily neutralize one of the lint's two verdict branches and confirm the
  corresponding suite case FAILS, then restore — proving the assertions are load-bearing rather
  than vacuous. Do not commit the neutralized state.

---

### Phase 3: Register gate 25 and fix the `--only-gate` range bound [NOT STARTED]

**Goal**: Gate 25 runs as part of the battery, is individually selectable via `--only-gate 25`,
and the registry lint plus the registry-resolution suite accept the new row.

**Tasks**:

- [ ] Re-read `scripts/verify-deploy.sh` immediately before editing (a concurrent sibling task
      declares this file in its own `file_scope` this same cycle).
- [ ] Add row 25 to `scripts/gate-registry.data`, TAB-separated, 9 fields, cloning gate 24's
      field values where they apply: `id=25`;
      `name=Verdict-extraction anchoring lint (lint-verdict-extraction-anchoring.sh)`;
      `invoke=gate25_run`; `dependencies=-`; `requires_source_store=true`; `timeout_s=30`;
      `cost_class=free`; `serialized=false`; and an `input_corpus` naming the same narrow corpus
      the lint scans, as repo-relative literal paths plus one glob (not `@extensions`, not
      `@repo`):
      `agent-system/extensions/core/scripts/verify-deploy.sh,agent-system/extensions/core/scripts/lib/gate-verdict-extract-lib.sh,agent-system/extensions/core/scripts/lint/*.sh`.
- [ ] Add `gate25_run()` to `scripts/verify-deploy.sh`, cloning `gate24_run`'s shape exactly:
      `gate_selected 25` guard, `say "25. ..."`, `CURRENT_GATE="gate25"`, the
      `[ ! -d "$TARGET/agent-system/extensions" ]` deploy-consumer SKIP branch, the
      lint-not-found `fail` branch, a `--verbose` invocation capturing output and status, `pass`
      on 0, and on non-zero a `fail` plus — under `--findings` — a
      `while ... done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$output")` loop
      appending `FINDING gate25 ...` rows.
- [ ] Replace the three hardcoded `23` occurrences in the `--only-gate` case branch (the
      invalid-token error message, the `-gt 23` numeric comparison, and the out-of-range error
      message) with a bound derived from the live registry. `gate_registry_load` has already run
      by the time this block is parsed, so the max of `gate_registry_ids`' ascending output is
      available.
- [ ] Give that derivation an explicit fallback for the degraded case: the file's own degrade-safe
      stub makes `gate_registry_ids` emit nothing when the library is unavailable, which must not
      silently reject every gate id or accept any. Choose and comment the fallback behavior
      explicitly rather than leaving it implicit.
- [ ] Update `scripts/tests/test-gate-registry-resolution.sh`: `seq 1 24` -> `seq 1 25`; the two
      assertion messages naming "24 migrated ids"/"24 migrated gates" -> 25, with the first
      naming what gate 25 is (mirroring how that message currently names gate 24); and correct
      the already-stale "the real 23-gate registry" comment to "25-gate registry".
- [ ] Add assertions to `test-gate-registry-resolution.sh` covering the new derived bound:
      `--only-gate 25` is accepted, an id above the live max is still refused with exit 2, and a
      non-numeric token is still refused. Put these here rather than in
      `test-verify-deploy-gate-selection.sh`, which a concurrent sibling task declares in its own
      `file_scope`.
- [ ] Stage only this task's own hunks with an explicit file list; never a directory or glob add.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts its blast radius is exactly three files
(`gate-registry.data`, `verify-deploy.sh`, `test-gate-registry-resolution.sh`) and that the
`--only-gate` bound is hardcoded in exactly three places within one case branch. Confirm at
implementation time with `grep -n "1-23\|-gt 23" agent-system/extensions/core/scripts/verify-deploy.sh`
before and after the edit; if that grep returns occurrences outside the `--only-gate` branch, or
if `grep -rn "only-gate" ` surfaces a second independent validator, revise the file list and the
task list before committing.

**Tier Justification**: `interface` is the cheapest covering tier because the `--only-gate` bound
change alters a selection predicate whose call sites span `verify-deploy.sh` and its enumerated
direct dependents — covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh,test-gate-cache-equivalence.sh`
plus a live `--only-gate 25` selection, and not by any single-module check.

**Files to modify**:

- `agent-system/extensions/core/scripts/gate-registry.data` - new row 25
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add `gate25_run`; derive the `--only-gate` bound from the registry
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - 24 -> 25 bumps, stale comment correction, new bound assertions

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` accepts the new
  row (field well-formedness, id contiguity 1-25, dependency acyclicity, `input_corpus` grammar).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 25 agent-system/extensions/core`
  selects and runs exactly gate 25 and reports it PASS — this is the assertion the bound fix
  exists to make possible, and it must be run with an explicit source-store TARGET, since the
  bare form defaults TARGET to the consumer root where this gate SKIPs.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 24 agent-system/extensions/core`
  now also works (the previously-stale bound no longer rejects the existing gate 24).
- An out-of-range id (e.g. `--only-gate 99`) and a non-numeric token are both still refused with
  exit 2 and the documented error text.
- The degraded path: with the registry library made unavailable, `--only-gate` behaves per the
  explicitly chosen fallback rather than rejecting every id silently.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh,test-gate-cache-equivalence.sh`
  passes.
- `git status --short` confirms no file outside this phase's declared list was staged.

---

### Phase 4: Prose pointer and manifest declaration [NOT STARTED]

**Goal**: The prose contract names its own mechanical enforcer, and both new scripts are declared
for deployment.

**Tasks**:

- [ ] Re-read `context/standards/shell-script-testing.md`'s "Verdict-line extraction contract
      (producer/consumer)" section immediately before editing (a sibling task sequenced after
      this one also edits this file).
- [ ] Append one sentence to the **end of that section only**, naming the new lint and its gate
      id — e.g. "Mechanically enforced by `scripts/lint/lint-verdict-extraction-anchoring.sh`
      (gate 25 in `scripts/gate-registry.data`)." Do not restructure the section, do not touch
      the adjacent "Measurement discipline" section, and do not add a second paragraph.
- [ ] `git add` the two new files from Phases 1 and 2 so `sync-manifest-scripts.sh`'s
      `git ls-files` enumeration can see them.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` and confirm
      it reports exactly the two new scripts as undeclared.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` and confirm
      the resulting `core/manifest.json` diff adds exactly `lint/lint-verdict-extraction-anchoring.sh`
      and `tests/test-lint-verdict-extraction-anchoring.sh` and nothing else.
- [ ] Confirm no task-number reference and no record-versioning language entered any file under
      `agent-system/**` in this phase's diff.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the manifest diff is exactly two added array entries and
the prose diff is exactly one added sentence. Confirm with `git diff` on both files before
committing; a manifest diff touching any other entry means `sync-manifest-scripts.sh --write`
re-derived more than expected and the diff must be inspected before it is staged.

**Tier Justification**: `local` is the cheapest covering tier because the covering checks are
`sync-manifest-scripts.sh --check` (which is precisely the mechanical check for the manifest
edit) plus, for the markdown edit, a source-store-targeted gate subset
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
— the explicit TARGET is required because the bare form would silently SKIP both gates at the
consumer root.

**Files to modify**:

- `agent-system/extensions/core/context/standards/shell-script-testing.md` - one-sentence pointer at the end of the verdict-line extraction contract section
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entries for the two new scripts

**Verification**:

- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits clean after
  the `--write`.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
  passes for gate 4 (task-reference lint) and reports gate 3's result; a pre-existing gate 3
  lean4 `index.json` failure is expected and out of scope (see the dispatch's known-unrelated
  list) and must be reported as such rather than fixed.
- `git diff` on `shell-script-testing.md` shows changes confined to the verdict-line extraction
  contract section.

---

### Phase 5: Redeploy and full gate set [NOT STARTED]

**Goal**: The deployed tree carries the new lint and suite, and the complete gate set passes
against an explicit source-store TARGET with the new gate green.

**Tasks**:

- [ ] Re-read every file this task touched, confirming no concurrent sibling has changed it since
      this task's own last commit; if a foreign commit or foreign uncommitted modification is
      observed, check `git log` to confirm it is not this task's own work and then STOP and report
      rather than proceeding.
- [ ] Redeploy the source store with the bounded-wait idiom:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's
      `timeout` parameter raised to 600000 (not its 120000 default), per
      `context/patterns/external-process-wait.md` Rule 1.
- [ ] Confirm the deployed tree now contains
      `.claude/scripts/lint/lint-verdict-extraction-anchoring.sh` and
      `.claude/scripts/tests/test-lint-verdict-extraction-anchoring.sh`.
- [ ] Run the complete gate set with an explicit source-store TARGET:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core`.
      The bare, no-argument form is **not** acceptable evidence for this phase: TARGET defaults
      to the consumer repo root, where every source-store-only gate — including the new gate 25 —
      silently SKIPs.
- [ ] Re-run the producer-side round-trip against the live lint one final time: capture the
      deployed lint's own output from a seeded fixture, pipe it through
      `verify_deploy_extract_verdict_lines '[VIOLATION]'`, and confirm the selected set equals the
      real finding set.
- [ ] Record the full gate result, naming the known-unrelated pre-existing failures explicitly as
      pre-existing and unfixed.
- [ ] Record any issue or win from this task via `issue-record.sh` if not already recorded during
      earlier phases.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts it modifies no source-store file at all — its only
write is the whole-tree regeneration of `.claude/**` performed by the deploy script, declared
below via the reserved sentinel. Confirm with `git status --short` showing no new or modified
path under `agent-system/**` attributable to this phase.

**Files to modify**:

- `__WHOLE_TREE__` - whole-tree regeneration via `deploy-headless.sh`

**Verification**:

- `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core` — the
  complete gate set, all 25 gates, with the explicit source-store TARGET. Gate 25 reports PASS.
- Gate 8's full `tests/run-all.sh` battery includes
  `test-lint-verdict-extraction-anchoring.sh` and `test-gate-registry-resolution.sh`, both
  passing.
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` passes.
- The only failures present are the dispatch's named known-unrelated pre-existing ones: Gate 3
  lean4 doc-lint missing `index.json` entry; Gate 20 eager-load budget over baseline; Gate 8
  suites `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh`, `test-guard-git-push.sh`. Any
  other failure is attributable to this work and must be fixed forward, not excused.
- A deliberately-seeded violation of each flagged shape, planted in a fixture rather than in the
  live tree, is detected by the deployed lint — so a lint that silently matches nothing cannot
  pass as working.

---

## Testing & Validation

- [ ] `bash -n` clean on both new scripts, and
      `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose <both paths>`
      exits 0 (the repository's own entry point, exit status checked — never the bare binary).
- [ ] `run-all.sh --only test-lint-verdict-extraction-anchoring.sh` — every case PASS, including
      both flagged shapes for both tokens, the helper-routed negative control, each intended
      exemption, and the producer-side round-trip.
- [ ] The two remedy messages are asserted distinct, so merging them into one generic message
      breaks the suite.
- [ ] `run-all.sh --only test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh,test-gate-cache-equivalence.sh`
      passes.
- [ ] `lint-gate-registry.sh --verbose` accepts row 25 (contiguity 1-25, field grammar,
      `input_corpus` grammar).
- [ ] `verify-deploy.sh --only-gate 25 agent-system/extensions/core` selects and passes gate 25;
      `--only-gate 24` also now works; an out-of-range and a non-numeric token are still refused
      with exit 2.
- [ ] `sync-manifest-scripts.sh --check` clean.
- [ ] `verify-deploy.sh agent-system/extensions/core` — complete gate set, explicit source-store
      TARGET, only the named pre-existing failures.
- [ ] No task-number reference and no record-versioning language in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-verdict-extraction-anchoring.sh` (new)
- `agent-system/extensions/core/scripts/gate-registry.data` (row 25 added)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (`gate25_run`; registry-derived
  `--only-gate` bound)
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` (count bumps,
  stale-comment correction, bound assertions)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (one-sentence pointer)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` entries)
- Regenerated `.claude/**` deploy tree
- `specs/414_enforce_verdict_extraction_contract/summaries/01_*-summary.md` (implementation
  summary)

## Rollback/Contingency

Each phase commits independently, so reverting is per-phase `git revert` of this task's own
commits — the preferred contingency, since it preserves concurrent siblings' work on the shared
tree.

Should a genuine working-tree rollback be required before a commit, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag. Do **not** take a reverting snapshot as a
routine precaution; an ordinary defensive checkpoint before risky work uses
`git-snapshot.sh --no-revert`, which is durable without reverting the working tree.

Phase-specific contingencies:

- If the narrow corpus turns out to miss a shape the contract genuinely needs covered, widen the
  corpus only together with the allowlist the research report enumerates, and treat a
  red-on-landing gate as a blocker to be resolved before Phase 3 registers the gate — never by
  registering the gate anyway.
- If the registry-derived `--only-gate` bound proves infeasible at that point in the file, fall
  back to a single explicit literal with a comment naming the staleness class it reintroduces,
  and record the compromise as an issue rather than leaving it silent.
- If the deploy in Phase 5 fails, the source store is unchanged and authoritative; re-run the
  deploy rather than hand-patching any file under `.claude/**`.
