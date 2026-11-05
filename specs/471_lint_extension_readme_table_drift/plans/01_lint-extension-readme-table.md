# Implementation Plan: Task #471

- **Task**: 471 - Add lint-extension-readme-table.sh and wire it into verify-deploy.sh's gate set
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: task 470 (verify-deploy.sh TARGET-contract task) -- same header/argument-parsing region; serialize, do not co-schedule
- **Research Inputs**: specs/471_lint_extension_readme_table_drift/reports/01_lint-extension-readme-table-drift.md
- **Artifacts**: plans/01_lint-extension-readme-table.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a new source-store lint, `lint-extension-readme-table.sh`, that bidirectionally diffs the real
`agent-system/extensions/*/` directory set against the first column of
`agent-system/extensions/README.md`'s Available Extensions table, with `core` exempted by explicit
directory-name match. Wire it as gate 26 (next free id; re-confirmed at implementation time) via a
`gate-registry.data` row plus a `gate26_run` function in `verify-deploy.sh`, add a four-case
fixture suite, and declare both new scripts in `core`'s manifest through
`sync-manifest-scripts.sh --write`. One live drift must be repaired first -- the `sapience`
extension directory has no table row -- because the new gate cannot be green without it.

### Research Integration

Key findings carried into this plan:

- **Outcome #3 is already resolved and needs no code change.** Verified directly in this planning
  dispatch, independently of the report: `verify-deploy.sh` lines 381-401 derive
  `_only_gate_max_id` by iterating `gate_registry_ids` and taking the max, falling back to the
  literal `23` only when that enumeration yields `0` (degraded/empty registry). There is no
  `-gt 23` ceiling test anywhere in the `--only-gate` block. `--only-gate 24` and `--only-gate 25`
  both validate today. What remains is two cosmetic stale-prose mentions (line 173's "every one of
  the 23 real gates", line 737's `GATE FUNCTIONS 1-23` banner), which this plan folds into Phase 4
  as incidental cleanup alongside the new gate id. The dispatch's cited line numbers (171, 177,
  329-341) no longer describe a cap at all.
- **A live table/directory mismatch exists**, contradicting the dispatch's "the table is CORRECT
  right now" framing. Confirmed in this dispatch: 23 directories, minus `core`, equals 22 expected
  rows; the table has 21. The missing row is `sapience`. No dangling row exists (every table row
  names a real directory). Repairing this is a precondition for outcome #5, not scope creep.
- **Current max gate id is 25, not 24** (`gate24_run` and `gate25_run` both defined). New gate id
  is therefore 26, re-confirmed fresh at implementation time per the concurrency risk below.
- **Gate functions are dispatched dynamically** via `"gate${_gate_id}_run"` driven by
  `gate_registry_ids`, so a registry row plus a defined `gate26_run` is the complete wiring -- no
  call-site list to edit.
- **`core`'s exemption must be a hardcoded directory-name check.** `routing_exempt: true` is also
  set by `approvals`, `slidev`, and `sapience`, all of which belong in the table, so no manifest
  field is a usable proxy.
- **`input_corpus` = `@extensions` alone** is correct and sufficient; the README lives inside the
  tree that named view enumerates, so no compound corpus expression is needed.
- **Test discovery is automatic** (`run-all.sh` globs `scripts/tests/test-*.sh`), so the only
  declaration step is `sync-manifest-scripts.sh --write` against `core`'s manifest.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no `roadmap_flag` was set; this plan carries no
roadmap review/update phases.

## Goals & Non-Goals

**Goals**:

- A new lint at `agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh` that
  detects both drift directions (directory with no row; row with no directory) and exempts `core`
  explicitly.
- Gate registration: one `gate-registry.data` row with correct `cost_class` and `input_corpus`,
  plus a `gate26_run` function following the `gate24_run`/`gate25_run` shape exactly.
- A four-case fixture suite covering clean/missing-row/extra-row/core-exempt.
- The live `sapience` drift repaired so the new gate is green on the real corpus.
- Both new scripts declared in `core`'s manifest via `sync-manifest-scripts.sh --write`.
- Outcome #3 independently re-confirmed and its status recorded explicitly (already-resolved is
  itself the deliverable there), with the two stale `23`-mentioning prose lines corrected.
- Full gate set green after a `deploy-headless.sh` redeploy.

**Non-Goals**:

- Rewriting or extending `check-extension-docs.sh` or `lint-routing-wiring.sh` -- neither reads the
  top-level `agent-system/extensions/README.md`, and neither's detection model fits a markdown
  table diff. A new file is the right shape (confirmed by the research's net-size reasoning).
- Validating table row *order*, description text, or `Docs` link targets. This lint checks set
  membership of the first column only.
- Re-deriving an ordering policy for the Available Extensions table. The `sapience` row is inserted
  by local convention; the lint is order-blind.
- Any edit under `.claude/**`. That tree is a disposable deploy artifact; all edits land in the
  source store and reach `.claude/` only via redeploy.
- Touching the cache-invalidation comment near line 2033, whose gate-id list is a historical
  reproduction record (a specific past repro with specific warm entries), not a stale enumeration.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A concurrent task claims gate id 26 before this task's implement phase runs (#418, #414 declare `gate-registry.data`) | M | M | Phase 1 re-enumerates the registry's max id immediately before Phase 4 edits it; never trust 26 from this plan as final |
| `verify-deploy.sh`'s header/arg-parsing region drifts again under task 470 and the concurrent writers (#444, #445, #449) | M | M | Phase 1 re-greps the `--only-gate` block for a literal cap by pattern, not by this plan's line numbers; Phase 4 locates its insertion point by anchor text (`gate25_run`), never by line number |
| Another task adds or removes an extension directory mid-flight, re-introducing drift and turning Phase 6's gate run red | H | L | Phase 6 re-runs the new lint directly before the full gate set and repairs any newly-missing row as part of that phase rather than reporting a spurious failure |
| The new lint's two-corpus input shape (markdown file + directory listing) makes fixtures awkward | M | M | Phase 2 designs the lint to take a single optional positional `EXTENSIONS_ROOT`, reading `<root>/README.md` and enumerating `<root>/*/` from it, so one scratch directory is a complete fixture |
| `lint-gate-registry.sh` rejects the new row on a grammar or contiguity violation | M | L | Phase 4 runs `lint-gate-registry.sh` on the edited file before closing, and `test-gate-registry-resolution.sh` case31 asserts the real registry lints clean |
| Hand-editing `manifest.json` reformats two non-canonical manifests | M | L | Phase 5 uses `sync-manifest-scripts.sh --write` exclusively; the manifest is never edited by hand |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 2, 3 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-confirm preconditions and repair the live table drift [COMPLETED]

**Goal**: Independently re-verify the three facts this plan depends on (outcome #3's status, the
next free gate id, the real table-vs-directory diff) against the tree as it stands at
implementation time, then add the missing `sapience` row so the new gate can reach green.

**Tasks**:

- [x] Re-grep `agent-system/extensions/core/scripts/verify-deploy.sh` for a literal `--only-gate`
      ceiling by pattern, not line number: `grep -n 'only_gate_max_id\|-gt 23\|1-23'`. Confirm the
      derived-max form is still in place and no hardcoded cap has returned. *(completed: confirmed, derived-max form intact)*
- [x] Record the outcome #3 verdict explicitly for the summary: expected result is "already
      resolved by commit `3d28b4399`; no functional change required", with the two stale prose
      mentions (line ~173 `23 real gates`, line ~737 `GATE FUNCTIONS 1-23`) named as the only
      remaining residue. If a hardcoded cap HAS returned, fix it in Phase 4 together with the new
      gate id and note the deviation in the issue log. *(completed: no cap returned; verdict recorded in progress file)*
- [x] Re-enumerate the registry's current max id:
      `grep -v '^#' agent-system/extensions/core/scripts/gate-registry.data | awk -F'\t' 'NF>1 {print $1}' | sort -n | tail -1`.
      Record the next free id; use it everywhere Phase 4 says "26". *(completed: max=25, next free=26)*
- [x] Re-diff the real corpus: compare `ls -d agent-system/extensions/*/` basenames (minus `core`)
      against the first column of `agent-system/extensions/README.md`'s Available Extensions table.
      Record both directions. *(completed: sapience missing, no dangling rows)*
- [x] Add the missing table row for `sapience` to `agent-system/extensions/README.md`, with
      `Task Type: -` (the convention used by `filetypes`, `memory`, `literature`, `slidev`,
      `approvals`), a description drawn from `agent-system/extensions/sapience/manifest.json`'s
      `description` field, and `Docs` link `[README](sapience/README.md)`. Place it alongside the
      other routing-exempt, `-`-task-type rows that already cluster at the table's tail rather than
      re-deriving an ordering policy. *(completed)*
- [x] Add any other row the re-diff found missing, and remove any row naming no real directory. *(completed: none other found)*
- [x] Record an issue-log entry for the dispatch's invalidated CURRENT STATE claim via
      `issue-record.sh` (`--kind issue --class stale-dispatch-context --severity minor`). *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The only file written is a markdown table in the source store with no
executable surface, so `suite_selection_select` returns `__FULL_SWEEP__` (sub-case b); the honest
covering check is `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` row's diff read-through confirming every changed hunk lies inside the table.

**Scope Hypothesis**: This phase asserts that exactly one row (`sapience`) is missing and zero rows
are dangling, from a 23-directory / 21-row corpus measured during planning. The implementer
confirms by re-running the bidirectional diff described above and adjusts the edit to whatever the
fresh diff actually shows -- the count is a hypothesis, not a fact.

**Files to modify**:

- `agent-system/extensions/README.md` - add the missing `sapience` row (and any other row the fresh
  re-diff requires) to the Available Extensions table

**Verification**:

- `grep -c '^| ' agent-system/extensions/README.md` within the Available Extensions table equals
  the number of non-`core` extension directories plus the two header/separator lines.
- Every non-`core` directory basename appears as a first-column value, and every first-column value
  names a real directory.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0.
- The outcome #3 verdict and the fresh next-free gate id are both written down for Phase 4 and the
  summary.

---

### Phase 2: Author lint-extension-readme-table.sh [COMPLETED]

**Goal**: A new lint that bidirectionally diffs the extension directory set against the Available
Extensions table's first column, exempting `core` by explicit name, following the structural
conventions of its siblings in the same directory.

**Tasks**:

- [x] Create
      `agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh`, modeled
      structurally on `lint/lint-dead-command-recommendations.sh`: `set -euo pipefail`, source
      `lib/common.sh` and `lib/lint-corpus-scan-lib.sh`, parse flags via
      `lint_corpus_scan_parse_flags SCAN_PATHS VERBOSE QUIET -- "$@"`, and resolve the project root
      with the dual-mode `resolve_project_root()` helper (`common_repo_root "$SCRIPT_DIR" 3` first,
      then an up-to-8-parent walk looking for `agent-system/extensions`) so it runs identically
      from the source store and the deployed copy. *(completed)*
- [x] Define the input contract as a single optional positional `EXTENSIONS_ROOT` (the first
      `SCAN_PATHS` entry), defaulting to `$PROJECT_ROOT/agent-system/extensions`. The lint reads
      `<root>/README.md` and enumerates `<root>/*/` from that same root. This single-root shape is
      what makes one scratch directory a complete fixture in Phase 3; it also keeps the sibling
      positional-path convention rather than inventing a new `--readme`/`--extensions-dir` flag
      pair. *(completed)*
- [x] Parse the directory set: every immediate subdirectory of the root, basename only, excluding
      the literal `core` via an explicit string comparison with an inline comment stating WHY
      (`core` is the unconditionally-loaded base system, deliberately not a pickable "available
      extension") and why no manifest field can substitute (`routing_exempt: true` is also set by
      `approvals`, `slidev`, and `sapience`, all of which belong in the table). *(completed)*
- [x] Parse the table: locate the `## Available Extensions` heading, skip the header and separator
      rows, and extract the first pipe-delimited cell of each subsequent table row until the table
      ends (first non-`|` line). Trim whitespace and strip optional surrounding backticks so the
      parser is robust to either styling. *(completed)*
- [x] Emit both drift directions as `[VIOLATION]`-tagged lines: a directory with no row, and a row
      naming no directory. Emit `[EXEMPT]` for `core` under `--verbose`. Suppress the per-finding
      and summary output under `--quiet`. *(completed)*
- [x] Exit `0` when clean, `1` when any violation is found, `2` on environment error (unresolvable
      project root, missing shared lib, missing `README.md`, no `## Available Extensions` heading,
      or an empty directory enumeration -- each a loud named failure, never a silent pass). *(completed)*
- [x] Write the dense header comment block every sibling in this directory carries: WHY THIS EXISTS
      (the table is the only extension inventory a human reads and nothing mechanically checked it),
      DETECTION MODEL (bidirectional set diff; order-blind, description-blind, link-blind), THE
      `core` EXEMPTION (explicit name match, with the `routing_exempt` false-signal reasoning),
      NET-SIZE RATIONALE (why a new file rather than extending `check-extension-docs.sh` or
      `lint-routing-wiring.sh`), USAGE, and EXIT CODES. *(completed)*
- [x] `chmod +x` the new script. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The file is a brand-new, self-contained script with no callers yet (the
gate that invokes it does not exist until Phase 4), so its blast radius is the single file; the
covering checks are `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh`
(the shellcheck lint accepts explicit paths per its own usage line) plus a direct run of the new
lint against the real corpus.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh` - new file: the lint

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh --verbose` exits 0
  against the real corpus (after Phase 1's row fix lands) and prints an `[EXEMPT]` line for `core`.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh`
  exits 0.
- Running the lint against a scratch root missing a row exits 1 and names the missing extension;
  against a scratch root with an extra row exits 1 and names the dangling row (spot-checked by hand
  here; asserted mechanically in Phase 3).
- Running from both the source-store path and the deployed path resolves the project root
  identically.

---

### Phase 3: Author the four-case fixture suite [NOT STARTED]

**Goal**: A regression suite asserting the lint's behavior on synthetic fixtures for all four cases
outcome #4 names, independent of whether the live corpus is clean.

**Tasks**:

- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh`,
      modeled on `tests/test-lint-dead-command-recommendations.sh`: `set -uo pipefail`, source
      `../lib/common.sh`, resolve `REPO_ROOT` via `common_test_repo_root "$SCRIPT_DIR"`, resolve the
      lint under test via `common_test_resolve_candidate` (deployed copy first, source-store
      fallback), and initialize a `mktemp`-scoped workdir via `common_test_workdir_init`.
- [ ] Build a fixture helper that writes a synthetic extensions root into `$WORKDIR`: a `README.md`
      carrying a `## Available Extensions` heading and table, plus subdirectories matching whatever
      the case needs (including a `core/` subdirectory in every fixture, so the exemption is
      exercised by construction).
- [ ] Case 1 -- clean table: directories `core`, `alpha`, `beta`; rows for `alpha` and `beta`. Assert
      the lint exits 0.
- [ ] Case 2 -- missing row: directories `core`, `alpha`, `beta`; row for `alpha` only. Assert the
      lint exits non-zero and names `beta` on a `[VIOLATION]`-tagged line.
- [ ] Case 3 -- extra row: directories `core`, `alpha`; rows for `alpha` and `ghost`. Assert the
      lint exits non-zero and names `ghost` on a `[VIOLATION]`-tagged line.
- [ ] Case 4 -- `core` exemption: directories `core`, `alpha`; row for `alpha` only, deliberately
      with no `core` row. Assert the lint exits 0, and assert under `--verbose` that `core` is
      reported `[EXEMPT]` rather than silently absent from the output -- the exemption must be
      visible, not accidental.
- [ ] Add an environment-error case: a root with no `README.md`, asserting exit 2 rather than a
      silent 0.
- [ ] Use `common_test_pass`/`common_test_fail`/`common_test_info` throughout, tally
      `PASSED`/`FAILED`, exit `0` all-pass / `1` any-fail / `2` environment error. Never mutate the
      repository.
- [ ] `chmod +x` the new suite.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The suite is one new file whose only consumer is `run-all.sh`'s automatic
`scripts/tests/test-*.sh` glob, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-extension-readme-table.sh`.

**Scope Hypothesis**: This phase asserts the suite needs five cases (four named by outcome #4 plus
one environment-error case) and that a single scratch-root fixture shape suffices for all of them.
The implementer confirms by checking that the lint as actually written in Phase 2 accepts a single
positional root override; if it ended up needing two separate path overrides, the fixture helper
grows a second argument and the case count stays the same.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh` - new file: the
  fixture suite

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh` exits 0 with
  every case reported PASS.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-extension-readme-table.sh`
  exits 0 and reports the suite as selected and run (not skipped).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh`
  exits 0.
- The suite leaves no files outside its `mktemp` workdir (`git status --short` unchanged by the run).

---

### Phase 4: Register the gate and clear the stale gate-count prose [NOT STARTED]

**Goal**: The new lint runs as part of the gate set, via a conforming `gate-registry.data` row and a
`gate26_run` function matching `gate24_run`'s shape exactly; the two stale `23`-mentioning prose
lines in `verify-deploy.sh` are corrected to the real gate count in the same edit.

**Tasks**:

- [ ] Use the next free gate id recorded in Phase 1 (expected 26). Append a 9-field,
      TAB-separated row to `agent-system/extensions/core/scripts/gate-registry.data`:
      id = the free id; name = `Extension README table lint (lint-extension-readme-table.sh)`;
      invoke = `gate<ID>_run`; dependencies = `-` (the placeholder, never a genuinely empty field --
      an empty field silently collapses the tab delimiter and shifts every later column);
      requires_source_store = `true`; timeout_s = `30`; cost_class = `free` (matching every other
      pure-lint gate: 6, 7, 9, 11, 12, 15, 17, 18, 19, 24, 25); serialized = `false`;
      input_corpus = `@extensions`.
- [ ] Confirm the `@extensions` choice in a one-line comment or in the summary: the named view is
      the shared `git ls-files` enumeration of `agent-system/extensions/`, which already contains
      `agent-system/extensions/README.md`, so it covers both of the lint's inputs and makes
      `--skip-unchanged` invalidation correct without a compound expression.
- [ ] Add `gate<ID>_run()` to `agent-system/extensions/core/scripts/verify-deploy.sh` immediately
      after `gate25_run`, located by that anchor text and never by line number. Mirror
      `gate24_run`'s body exactly: `if gate_selected <ID>; then`, `say "<ID>. Extension README table
      lint (lint-extension-readme-table.sh)"`, `CURRENT_GATE="gate<ID>"`, SKIP with a stated reason
      when `$TARGET/agent-system/extensions` does not exist, `fail` when the lint script is missing
      from the source store, otherwise
      `cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh" --verbose`,
      `pass` on 0, and on nonzero `fail` plus -- under `FINDINGS` -- stream
      `verify_deploy_extract_verdict_lines '[VIOLATION]' "$output"` into
      `FINDINGS_LIST+=("FINDING gate<ID> $line")`. Confirm `[VIOLATION]` is the tag the Phase 2
      lint actually emits before wiring it.
- [ ] Verify no call-site list needs editing: gate functions are dispatched dynamically as
      `"gate${_gate_id}_run"` driven by `gate_registry_ids`, so the registry row plus the defined
      function is the complete wiring.
- [ ] Correct the two stale prose mentions in the same file: line ~173's "every one of the 23 real
      gates" and line ~737's `# GATE FUNCTIONS 1-23` banner, both to the real post-change count.
      Leave the cache-invalidation comment near line 2033 untouched -- its gate-id list is a record
      of one specific past reproduction, not a live enumeration.
- [ ] If Phase 1 found that a hardcoded `--only-gate` ceiling had returned, fix it here in the same
      edit (deriving the bound from `gate_registry_ids`, matching the form already present), and
      record the deviation in the issue log.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: interface

**Tier Justification**: The registry row and the `gate<ID>_run` function are a two-file contract
whose direct dependents are enumerable and already covered, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-gate-selection-crash-net.sh`
plus `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose`.

**Scope Hypothesis**: This phase asserts the free gate id is 26 and that exactly two stale
`23`-mentioning prose lines remain (at roughly lines 173 and 737). The implementer confirms both by
re-running Phase 1's max-id enumeration and
`grep -n '23 real gates\|1-23\|23 gates' verify-deploy.sh` immediately before editing, and uses
whatever those two commands actually report.

**Files to modify**:

- `agent-system/extensions/core/scripts/gate-registry.data` - append the new 9-field gate row
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add `gate<ID>_run` after `gate25_run`;
  correct the two stale `23`-gate-count prose mentions

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` exits 0 (row is
  9-field, id set contiguous from 1, invoke function exists, dependencies acyclic, `input_corpus`
  parses against the grammar).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-gate-selection-crash-net.sh`
  exits 0.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate <ID> /home/benjamin/.config/nvim`
  runs the new gate (not SKIP, not a zero-check-under-filter condition) and passes.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate <ID+1> /home/benjamin/.config/nvim`
  is rejected with an out-of-range error naming the new derived max, proving the bound tracks the
  registry.
- `grep -n '23 real gates\|GATE FUNCTIONS 1-23' verify-deploy.sh` returns nothing.

---

### Phase 5: Declare both new scripts in core's manifest [NOT STARTED]

**Goal**: `agent-system/extensions/core/manifest.json`'s `provides.scripts` array lists the new lint
and the new test suite, derived mechanically rather than hand-edited.

**Tasks**:

- [ ] Confirm both new files are tracked by git (`git add -- <lint> <suite>` if needed), since
      `sync-manifest-scripts.sh` derives `provides.scripts` from `git ls-files`.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` first to see
      the pending delta, then `--write` to apply it. Never hand-edit `provides.scripts` -- the tool
      is surgical (a line-oriented rewrite of just that array), whereas a hand edit or a `jq`
      round-trip would reformat the two manifests that are not `jq --indent 2` canonical.
- [ ] Confirm the resulting diff touches only the `provides.scripts` array and adds exactly the two
      expected entries: `lint/lint-extension-readme-table.sh` and
      `tests/test-lint-extension-readme-table.sh`.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Tier Justification**: The only write is a mechanical rewrite of one JSON array by a purpose-built
tool, so the covering check is that tool's own idempotence assertion --
`bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0 after the
`--write` -- plus `jq . agent-system/extensions/core/manifest.json >/dev/null`.

**Scope Hypothesis**: This phase asserts the sync adds exactly two entries and touches nothing else.
The implementer confirms with `git diff -- agent-system/extensions/core/manifest.json` after the
`--write`, and investigates rather than accepting any hunk outside the `provides.scripts` array.

**Files to modify**:

- `agent-system/extensions/core/manifest.json` - `provides.scripts` gains the two new entries (via
  `sync-manifest-scripts.sh --write`, never by hand)

**Verification**:

- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- `jq -e '.provides.scripts | index("lint/lint-extension-readme-table.sh")' agent-system/extensions/core/manifest.json`
  and the same for `tests/test-lint-extension-readme-table.sh` both succeed.
- `git diff -- agent-system/extensions/core/manifest.json` shows changes confined to the
  `provides.scripts` array.

---

### Phase 6: Redeploy and run the full gate set [NOT STARTED]

**Goal**: The source-store changes reach `.claude/` through a real redeploy, and the complete gate
set -- including the new gate -- is observed green.

**Tasks**:

- [ ] Re-run the new lint directly against the live corpus first:
      `bash agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh --verbose`. If
      a concurrent task has added or removed an extension directory since Phase 1, repair the table
      here (add the missing row, drop the dangling one) rather than reporting a spurious gate
      failure; record the repair in the issue log.
- [ ] Redeploy with the bounded-wait idiom, raising the Bash tool timeout to 600000:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`. Wait for `RESULT=landed_verify_clean`.
      Never hand-patch a deployed file in place of a redeploy.
- [ ] Confirm the deployed copies landed:
      `.claude/scripts/lint/lint-extension-readme-table.sh` and
      `.claude/scripts/tests/test-lint-extension-readme-table.sh` both exist, and
      `.claude/scripts/gate-registry.data` carries the new row.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. No `--skip-slow`, no
      `--only-gate`, no `--max-cost` narrowing -- a narrowed pass is not evidence for this phase's
      purpose.
- [ ] Run the full shell-suite battery: `bash .claude/scripts/tests/run-all.sh` (no `--only`).
- [ ] Record the outcome #3 verdict from Phase 1 in the task summary as an explicit finding
      ("confirmed already resolved; no functional change required; two stale prose mentions
      corrected"), not as a silently-skipped outcome.
- [ ] Record a `kind: win` issue-log entry if the dynamic gate dispatch meant no call-site list
      needed editing, or attest explicitly that nothing noteworthy arose.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed tree
- `agent-system/extensions/README.md` - only if the pre-redeploy re-check finds fresh drift from a
  concurrent task

**Verification**:

- `timeout 540 bash .claude/scripts/deploy-headless.sh` reaches `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` exits 0 with a final PASS line and zero FAILURES, with
  the new gate listed among the gates that ran and passed.
- `bash .claude/scripts/tests/run-all.sh` exits 0 with no failing suite.
- `bash .claude/scripts/lint/lint-extension-readme-table.sh --verbose` exits 0 from the deployed
  copy as well as the source-store copy.
- `git status --short` shows only the intended source-store files as modified (plus gitignored
  `.claude/**` churn).

---

## Testing & Validation

- [ ] `test-lint-extension-readme-table.sh` passes all five cases (clean, missing row, extra row,
      `core` exempt-and-visible, missing-README environment error).
- [ ] `lint-gate-registry.sh` passes on the edited `gate-registry.data`.
- [ ] `test-gate-registry-resolution.sh` passes (its case31 asserts the real registry lints clean).
- [ ] `test-verify-deploy-gate-selection.sh` and `test-verify-deploy-gate-selection-crash-net.sh`
      both pass with the new gate present.
- [ ] `--only-gate <new-id>` is accepted and runs the gate; `--only-gate <new-id + 1>` is rejected
      with the derived-max error.
- [ ] `sync-manifest-scripts.sh --check` is clean.
- [ ] `verify-deploy.sh` (unnarrowed) and `tests/run-all.sh` (unnarrowed) are both green after
      redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh` (new)
- `agent-system/extensions/core/scripts/gate-registry.data` (one new row)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (new `gate<ID>_run`; two stale gate-count
  prose lines corrected)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` synced)
- `agent-system/extensions/README.md` (missing `sapience` row added)
- Redeployed `.claude/` tree reaching `RESULT=landed_verify_clean`
- An explicit written verdict on outcome #3 in the task summary

## Rollback/Contingency

Every change is additive and confined to the source store, so reverting is a per-file operation
with no migration to undo:

- Before Phase 4's `verify-deploy.sh` edit, take a durable checkpoint that does not touch the
  working tree: `bash .claude/scripts/git-snapshot.sh 471 --no-revert`.
- To back out the gate without removing the lint: delete the `gate-registry.data` row and the
  `gate<ID>_run` function. Because gate dispatch is driven by `gate_registry_ids`, removing the row
  alone already stops the gate from running; both must go for `lint-gate-registry.sh` to stay clean
  (it checks that each row's `invoke` function exists, not the converse).
- To back out the new files entirely: `git rm --cached` the two new scripts, delete them, and re-run
  `sync-manifest-scripts.sh --write` to drop their manifest entries.
- The `agent-system/extensions/README.md` row is independently correct documentation and should be
  kept even if the lint is backed out.
- If the redeploy fails or lands dirty, the source store is unaffected; re-run
  `deploy-headless.sh` after resolving the reported cause rather than hand-patching `.claude/**`.
- If a concurrent writer has claimed the chosen gate id by the time Phase 4 runs, pick the next free
  id and update the `gate<ID>_run` name, the `say` line, the `CURRENT_GATE` value, and the
  `FINDING gate<ID>` tag together -- all four must agree.
