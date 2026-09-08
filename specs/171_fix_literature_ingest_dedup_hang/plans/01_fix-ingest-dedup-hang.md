# Implementation Plan: Fix literature online-ingest dedup hang

- **Task**: 171 - Fix the literature online-ingest hang caused by an O(n) per-title subprocess loop
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None (planned directly from the task specification plus first-hand reads of the target scripts; see Overview)
- **Artifacts**: plans/01_fix-ingest-dedup-hang.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`check_duplicate_title()` in `agent-system/extensions/literature/scripts/literature-ingest-online.sh`
spawns one `python3` process per title in the global Literature index (11,793 entries measured
2026-09-08 on `~/Projects/Literature/index.json`), so every `in_zotero_no_pdf` and `open_access`
ingest stalls for roughly 9-10 minutes before any directive token reaches stdout. The check is
documented as non-blocking and recommendation-only, so a multi-minute stall is pure cost: the
caller in `commands/literature.md` captures stdout and cannot distinguish a hang from a slow
success, and an external 540s timeout produced `rc=124` with no token at all. The fix collapses
the similarity sweep into a single `python3` invocation, short-circuits on exact/normalized
title equality before any scoring, and gives the check a hard time bound with fail-open
semantics. Done when a full-index dedup check completes in low single-digit seconds, the
existing WARNING line and 0.85 threshold are byte-for-byte preserved, and a regression suite
locks both in.

### Research Integration

No research report was produced for this round. The task description already carried the defect,
the measured evidence (11845 titles reported, 11793 confirmed today), the reproduction, the fix
direction, and the acceptance bar. Planning-time codebase reads confirmed every load-bearing
fact:

- `literature-ingest-online.sh:296-313` — `check_duplicate_title()`, the `while read` loop with a
  per-title `python3 "$SCRIPT_DIR/.zotero-title-sim.py"` call fed by
  `jq -r '.entries[]?.title // empty'`.
- `literature-ingest-online.sh:721` and `:835` — the two call sites (resolvable/create-item path
  and attach-to-existing path respectively).
- `.zotero-title-sim.py` — a 2-argv `SequenceMatcher` ratio over lowercased,
  punctuation-stripped titles, rounded to 4 places.
- `zotero-resolve-pdf.sh:99-104` — the **second** consumer of the helper, via `title_similarity()`
  using the same 2-argv form. Its contract must survive unchanged.
- `~/Projects/Literature/index.json` — 8.1 MB, `.entries | length == 11793`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap phases are required.

## Goals & Non-Goals

**Goals**:
- Collapse the per-title similarity sweep into one `python3` process invocation.
- Short-circuit on exact and normalized-equality matches before any similarity scoring runs.
- Give `check_duplicate_title()` a hard wall-clock bound and fail-open behavior so it can never
  gate or delay ingestion, consistent with its documented recommendation-only status.
- Preserve the existing WARNING output contract verbatim and the 0.85 similarity threshold.
- Preserve `.zotero-title-sim.py`'s existing 2-argv CLI contract for `zotero-resolve-pdf.sh`.
- Lock the behavior in with a regression suite following the house test pattern.

**Non-Goals**:
- Changing the dedup check from non-blocking to blocking, or altering the 0.85 threshold.
- Touching `check_live_doi_duplicate()`, the export-freshness guard, or any directive token /
  exit-code contract in the script's header block.
- Changing the similarity metric itself (`SequenceMatcher` ratio over normalized titles stays).
- Modifying `zotero-resolve-pdf.sh`'s resolution logic.
- Any work on the `literature-briefing.sh` SIGPIPE defect: the task description states it is
  ALREADY FIXED in this source store (now `jq -c first(...)`); only redeployment of stale
  consumer repos remains, and that is outside this task.
- Hand-editing anything under `.claude/**`. That tree is a gitignored deploy artifact
  regenerated from `agent-system/extensions/**` (see
  `.claude/rules/source-store-deploy-boundary.md`); every edit in this plan targets the source
  store.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Batch mode changes scores seen by `zotero-resolve-pdf.sh`, shifting PDF resolution outcomes | H | L | Batch mode is strictly additive; the 2-argv path keeps its current code path and output format. Phase 3 asserts 2-argv output is byte-identical to pre-change for a fixture set. |
| Reusing one `normalize()` across both modes silently drifts from the current definition | M | L | Do not rewrite `normalize()`. Both modes call the same untouched function; Phase 3 pins its behavior with fixtures. |
| Best-match tie-breaking differs from the old loop (old loop kept the FIRST strict maximum) | L | M | Reimplement strict `>` comparison in index order so the first strict maximum wins, matching the shell loop exactly. Phase 3 includes a tie fixture. |
| A malformed or huge `index.json` makes the single invocation slow or fail | M | L | Wrap the call in a hard `timeout`; any non-zero exit, empty output, or unparseable line is treated as "no duplicate found" and the function returns 0 (fail-open). |
| A shell edit accidentally alters the WARNING string, breaking a downstream reader | M | L | Copy the `log "WARNING: possible duplicate -- ..."` line verbatim; Phase 3 greps stderr for the exact rendered text. |
| `set -euo pipefail` turns a fail-open branch into a hard script abort | H | M | Every new command that may fail is guarded with `|| true` / an explicit `if`; no bare pipeline whose failure could propagate. Phase 2 verification exercises the missing-index and unreadable-index paths. |
| Fix lands in the source store but the running `.claude/` deploy stays stale | M | M | Phase 4 records the redeploy requirement explicitly in the summary/handoff. Redeploy itself is user-driven and out of scope. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add additive batch mode to `.zotero-title-sim.py` [COMPLETED]

**Goal**: Give the similarity helper a single-invocation batch mode that scores one candidate
title against an arbitrary list of existing titles, short-circuiting on normalized equality,
without disturbing the existing 2-argv contract.

**Tasks**:
- [x] Read `agent-system/extensions/literature/scripts/.zotero-title-sim.py` in full and confirm
      the current `normalize()` / `main()` shape before editing.
- [x] Add a `--batch <candidate-title>` mode: existing titles are read from **stdin**, one per
      line, so no argv length limit is hit for an 11k-entry index.
- [x] In batch mode, normalize the candidate once, then iterate stdin lines; skip blank lines
      and lines whose normalized form is empty.
- [x] Short-circuit: if a line's normalized form equals the candidate's normalized form, emit
      that line as the best match with score `1.0` and stop reading immediately (no
      `SequenceMatcher` call for it or any later line).
- [x] Otherwise score with the same `SequenceMatcher(None, a, b).ratio()` rounded to 4 places,
      keeping the first strict maximum (strict `>`, so index order breaks ties the same way the
      old shell loop did).
- [x] Emit exactly one output line on stdout: `<score>\t<original-existing-title>`. When stdin
      yields no usable title, emit `0.0\t` (score, tab, empty title) and exit 0.
- [x] Leave `normalize()` untouched and leave the 2-argv branch's behavior and output format
      exactly as they are (including the `len(sys.argv) != 3 -> print("0.0")` fallback for the
      non-batch path).
- [x] Update the module docstring: it currently claims the helper is "invoked by the resolver
      script only", which is already false (`literature-ingest-online.sh` calls it too). Name
      both consumers and both modes.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two consumers invoke `.zotero-title-sim.py`
(`zotero-resolve-pdf.sh:99` via `title_similarity()`, and `literature-ingest-online.sh:304`), and
both use the 2-argv form. Confirm at implementation time with
`grep -rn "zotero-title-sim" agent-system/` before editing; if a third consumer appears, add it
to the Phase 1 verification set rather than proceeding on this plan's count.

**Files to modify**:
- `agent-system/extensions/literature/scripts/.zotero-title-sim.py` - add `--batch` mode,
  normalized-equality short-circuit, corrected docstring.

**Verification**:
- 2-argv regression: `python3 .zotero-title-sim.py "A Title" "A Title"` prints `1.0`;
  `python3 .zotero-title-sim.py "A Title" "Totally Other"` prints the same value it printed
  before the edit (capture the pre-edit value first and diff).
- Batch smoke: `printf '%s\n' "Foo Bar" "A Title" | python3 .zotero-title-sim.py --batch "A Title"`
  prints `1.0\tA Title`.
- Empty stdin: `printf '' | python3 .zotero-title-sim.py --batch "X"` exits 0 and prints `0.0\t`.
- Direct dependent (`interface` tier): run `zotero-resolve-pdf.sh` in whatever no-side-effect
  form it supports (or, if none, exercise its `title_similarity()` helper by sourcing the same
  2-argv invocation) and confirm scores are unchanged.

---

### Phase 2: Rewrite `check_duplicate_title()` as a single bounded invocation [COMPLETED]

**Goal**: Replace the O(n)-subprocess loop with one `python3 --batch` call under a hard
wall-clock bound, preserving the WARNING output and the 0.85 threshold and never gating ingest.

**Tasks**:
- [x] Replace the `while IFS= read -r existing_title ... done < <(jq ...)` loop body in
      `check_duplicate_title()` with a single pipeline: `jq -r '.entries[]?.title // empty'` piped
      into `python3 "$SCRIPT_DIR/.zotero-title-sim.py" --batch "$title"`.
- [x] Wrap the invocation in `timeout` with a small explicit bound (10s) so the check can never
      dominate ingest wall-clock, and guard the whole thing so failure cannot abort the script
      under `set -euo pipefail` (`|| true` on the assignment, then branch on emptiness).
- [x] Treat every non-success outcome as "no duplicate found" and `return 0`: non-zero exit,
      timeout (rc 124), empty output, or an output line that does not parse into
      `<float>\t<title>`. Log a single explanatory line for the timeout/failure case so the
      fail-open is visible rather than silent, phrased so it cannot be mistaken for a duplicate
      warning.
- [x] Parse the single output line into `best_sim` and `best_title` with parameter expansion on
      the tab (no extra subprocesses).
- [x] Keep the threshold gate byte-for-byte:
      `if [ -n "$best_title" ] && awk -v s="$best_sim" 'BEGIN{exit !(s>=0.85)}'; then`.
- [x] Keep the WARNING `log` line byte-for-byte, including the
      `(non-blocking recommendation-only check; proceeding)` suffix.
- [x] Keep the early `[ -f "$idx" ] || return 0` guard and the function's `return 0`-always
      contract; do not change either call site (`:721`, `:835`).
- [x] Update the helper's own comment block (`:292-295`) to say the check is a single bounded
      invocation with normalized-equality short-circuit and fail-open semantics, replacing the
      stale "using the existing .zotero-title-sim.py helper (zotero-resolve-pdf.sh pattern)"
      framing.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the change is confined to `check_duplicate_title()` and its comment block;
no call site, directive token, or exit code changes. Confirm at implementation time with
`git diff --stat` showing exactly one file touched and
`git diff` showing no hunk outside lines ~292-313 of the script.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` -
  `check_duplicate_title()` body and its preceding comment block.

**Verification**:
- `bash -n agent-system/extensions/literature/scripts/literature-ingest-online.sh` passes.
- `shellcheck` on the script produces no new findings relative to a pre-edit baseline (capture
  the baseline first; do not treat pre-existing findings as regressions).
- Timing (the acceptance bar): with `LITERATURE_DIR=$HOME/Projects/Literature`, a direct call of
  the new pipeline against the real 11,793-entry index completes in low single-digit seconds,
  measured with `time`. Read-only — do not write to the real corpus.
- Missing index: with `LITERATURE_DIR` pointed at an empty temp dir, the function returns 0
  silently and the script does not abort.
- Unreadable/garbage index: with a temp `index.json` containing invalid JSON, the function
  returns 0 and the script does not abort.

---

### Phase 3: Regression suite for the batch path and the preserved contract [COMPLETED]

**Goal**: Lock in the 2-argv contract, the batch short-circuit, the tie-break order, the 0.85
threshold, and the exact WARNING text so a future edit cannot silently reintroduce the defect or
change the recommendation semantics.

**Tasks**:
- [x] Create `agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh` following
      the house pattern established by `tests/test-literature-build-index.sh`: `set -uo pipefail`,
      `TESTS_DIR`/`SCRIPT_DIR` resolution, `t_log`/`t_pass`/`t_fail` counters, `mktemp -d`
      workdir with a `trap ... EXIT` cleanup, exit 0 on all-pass / 1 on any required failure.
- [x] Header comment must state the suite MUST NOT read from or write to `~/Projects/Literature/`
      (the real corpus), matching the existing suite's stated invariant, and must name the defect
      it locks in.
- [x] Test: 2-argv identical titles -> `1.0`; 2-argv wrong-arity -> `0.0`; 2-argv
      punctuation/case-only difference -> `1.0` (pins `normalize()`).
- [x] Test: batch exact-normalized match returns score `1.0` and the original (un-normalized)
      title string.
- [x] Test: batch tie-break — two stdin lines scoring identically against the candidate; assert
      the FIRST is returned (strict `>` semantics, matching the replaced shell loop).
- [x] Test: batch with empty stdin, and batch where every line is blank -> `0.0` and empty title,
      exit 0.
- [x] Test: end-to-end over a scratch `LITERATURE_DIR` whose `index.json` contains a
      near-duplicate title above 0.85 — assert stderr contains the exact literal
      `WARNING: possible duplicate --` and the literal
      `(non-blocking recommendation-only check; proceeding)`.
- [x] Test: same scratch harness with only sub-0.85 titles — assert NO `WARNING: possible
      duplicate` line is emitted.
- [x] Test: fail-open — scratch `index.json` containing invalid JSON produces no duplicate
      warning and a zero return.
- [x] Register the new file in `agent-system/extensions/literature/manifest.json` under
      `provides.scripts` as `tests/test-title-sim-dedup.sh`, alongside the existing
      `tests/test-*.sh` entries.
- [x] Make the script executable (`chmod +x`).

**Timing**: 60 minutes

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: `provides.scripts` in the literature manifest currently lists 5
`tests/`-prefixed shell/python entries and this phase adds exactly one. Confirm at implementation
time by re-reading `manifest.json` and asserting the new entry is present exactly once and the
file remains valid JSON (`jq . manifest.json > /dev/null`).

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh` - new regression
  suite.
- `agent-system/extensions/literature/manifest.json` - register the new test script.

**Verification**:
- `bash agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh` exits 0 with
  every assertion reported PASS.
- `jq . agent-system/extensions/literature/manifest.json > /dev/null` succeeds.
- Deliberate-break check: temporarily revert `check_duplicate_title()`'s threshold to a wrong
  value, confirm the suite fails, then restore. A suite that passes against a broken
  implementation is not a regression suite.
- Confirm the suite left `~/Projects/Literature/` untouched (`git`-independent check: compare
  `stat -c %Y` on the real `index.json` before and after the run).

---

### Phase 4: Record the measured outcome and the redeploy requirement [COMPLETED]

**Goal**: Update the script's own documentation to reflect the bounded, fail-open check, and
record the before/after timing plus the stale-deploy caveat where a future reader will find them.

**Tasks**:
- [x] Measure and record: wall-clock of a full-index dedup check before the fix (from the task
      description's observed 9-10 minutes / rc=124 at 540s) and after (Phase 2's measurement),
      against the confirmed 11,793-entry index.
- [x] Update the `literature-ingest-online.sh` header comment block where it describes the
      non-blocking `check_duplicate_title()` heuristic (the `EXPORT FRESHNESS + LIVE DEDUP GUARD`
      paragraph, ~line 95, and the `ONLINE_INGEST_DUPLICATE_DETECTED` token description, ~line
      75) so the "non-blocking" claim is backed by the new hard time bound and fail-open
      semantics.
- [x] Add a short subsection to
      `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md`
      (or the most specific existing home found at implementation time) describing the dedup
      check's contract: recommendation-only, single bounded invocation, 0.85 threshold,
      fail-open on timeout/parse failure. Cite the script and function by name — no task numbers
      (`.claude/rules/no-task-references-in-deliverables.md`).
- [x] Note in the implementation summary that `.claude/scripts/literature-ingest-online.sh` and
      `.claude/scripts/.zotero-title-sim.py` are stale deploy copies until the user redeploys the
      literature extension, and that the sibling `literature-briefing.sh` SIGPIPE fix is already
      in the source store and likewise only awaits redeployment.

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the doc edits are confined to comment/prose regions — the script header
comment block and a markdown context file. Confirm with a diff read-through showing every
changed hunk in `literature-ingest-online.sh` lies inside the leading `#` comment block, and
`bash -n` still passes.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - header comment block
  only.
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md` - dedup
  check contract subsection.

**Verification**:
- Diff read-through confirms every hunk in the shell script is inside a `#` comment region.
- `bash -n agent-system/extensions/literature/scripts/literature-ingest-online.sh` still passes.
- `grep -nE '\btasks? [0-9]+' ` over the two edited files returns no task-number references.
- Recorded before/after timing appears in the implementation summary with the index entry count
  it was measured against.

## Testing & Validation

- [ ] `bash -n` clean on `literature-ingest-online.sh`.
- [ ] `shellcheck` shows no new findings versus the pre-change baseline.
- [ ] `python3 -m py_compile` clean on `.zotero-title-sim.py`.
- [ ] `tests/test-title-sim-dedup.sh` exits 0, and fails when the implementation is deliberately
      broken.
- [ ] Existing literature suites still pass: `tests/test-literature-build-index.sh`,
      `tests/test-literature-convert.sh`, `tests/test-literature-discover-tier3.sh`
      (any that already pass on this tree — capture a pre-change baseline first and do not treat
      a pre-existing failure as a regression).
- [ ] Full-index dedup check against the real 11,793-entry index completes in low single-digit
      seconds (read-only).
- [ ] `zotero-resolve-pdf.sh`'s 2-argv similarity scores are unchanged.
- [ ] `jq . agent-system/extensions/literature/manifest.json` succeeds.
- [ ] No file under `.claude/**` was hand-edited (`git status` shows changes only under
      `agent-system/extensions/literature/**` and `specs/**`).

## Artifacts & Outputs

- `specs/171_fix_literature_ingest_dedup_hang/plans/01_fix-ingest-dedup-hang.md` (this file)
- `specs/171_fix_literature_ingest_dedup_hang/summaries/01_fix-ingest-dedup-hang-summary.md`
- Modified: `agent-system/extensions/literature/scripts/.zotero-title-sim.py`
- Modified: `agent-system/extensions/literature/scripts/literature-ingest-online.sh`
- Modified: `agent-system/extensions/literature/manifest.json`
- Modified: `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md`
- New: `agent-system/extensions/literature/scripts/tests/test-title-sim-dedup.sh`

## Rollback/Contingency

Every phase is a small, self-contained commit under the per-substep mandate, so
`git revert <sha>` on the Phase 2 commit alone restores the original loop while keeping the new
batch mode (which is additive and harmless on its own). If the batch mode itself proves to
change `zotero-resolve-pdf.sh`'s resolution outcomes, revert Phase 1 and Phase 2 together — the
two consumers then return to the exact pre-change code path. No corpus, index, or Zotero state
is written by any phase, so there is no data rollback to perform; all verification against
`~/Projects/Literature/` is read-only and all test fixtures live in `mktemp -d` scratch
directories.
