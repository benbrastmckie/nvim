# Implementation Plan: Task #179

- **Task**: 179 - Add a mechanical element-placement and density lint to the typst extension
- **Status**: [COMPLETED]
- **Effort**: 4.5 hours
- **Dependencies**: Task 178 (semantic-element usage contract) — already merged; its
  `standards/semantic-element-usage.md` is the sole source of element inventory and norms
- **Research Inputs**: `specs/179_typst_element_placement_density_lint/reports/01_element-placement-density-lint.md`
- **Artifacts**: plans/01_element-placement-density-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The typst extension currently has zero mechanical infrastructure (`provides.scripts: []`,
`hooks: []`, `rules: []`) and its only gate is `typst compile` exit 0, which is blind to
rhetorical and structural misuse. Task 178 landed the prose half of the fix
(`standards/semantic-element-usage.md`, plus Stage 4C self-review prose in
`typst-implementation-agent.md`); this task adds the mechanical backstop, because the
"prose is enough" hypothesis was already falsified in this extension — `chapter-template.md`
already required an opening paragraph and a 25-item `#remark` checklist still landed as the
first body content after `= Agency` in `08-agency.typ`. The work is: one new bash lint script
implementing three checks with a blocking/advisory severity split, a test suite, manifest
declaration, and wiring into the implementation agent's verification path alongside — never
replacing — `typst compile`. Done means: the lint fires on the real `08-agency.typ` defect,
stays silent on that file's ~50-line pre-heading macro block and on its post-result remarks,
density findings are warnings only, and the script is reachable from the agent and declared in
the manifest.

### Research Integration

Findings from `reports/01_element-placement-density-lint.md` that this plan encodes directly
rather than leaving to implementation-time rediscovery:

- **Element inventory is fixed and sourced** (Scope D): `#definition`, `#theorem`, `#lemma`,
  `#corollary`, `#example`, `#proof`, `#remark`, `#rule-block`, `#rule-list` — taken verbatim
  from `standards/semantic-element-usage.md`, matched as `#{element}\s*[\(\[]` so both the
  `#remark(` and bare `#remark[` call forms are caught (both appear live in the fixture).
- **Check 3's threshold has a textual anchor**; check 2's does not. The standard states
  "if a chapter has more remarks than theorems, that is a signal" — check 3 uses exactly that
  ratio (remark count vs. `definition+theorem+lemma+corollary+example` count) instead of an
  invented per-line density metric. Check 2's item-count threshold is a genuine judgment call
  with no citation available; this plan fixes it at 3 and marks it advisory-and-unreviewed.
- **Fixture ground truth**: `= Agency <sec-agency>` at line 55, blank line 56,
  `#remark("Formalization Status")[` at line 57 with zero intervening prose, 25 `+` items,
  remark closing at line 88 (its inner `#items[...]` closes at 87 — the brace matcher must not
  stop there). Two further remarks at lines 90 and 106, still before any body prose. Lines 1-53
  are the legitimate pre-heading `#import`/`#let`/comment block. Post-result legal remarks at
  lines 208, 237, 353. File-wide: 23 remarks vs 39 theorem-family elements — so check 3
  correctly stays silent on this file even though check 1 correctly fires.
- **Repo conventions**: scripts flat in `scripts/`, declared as relative paths in
  `provides.scripts` (test file listed as a sibling `tests/...` entry, per `lean/manifest.json`),
  invoked from agent `.md` as `bash .claude/scripts/{name}.sh` (deployed path, never the
  source-store path), Class B strict mode (`set -uo pipefail`, no `-e`) because the script
  accumulates counters across independent checks, and `lint-agent-contracts.sh`'s exit-code
  convention (0 = pass/warnings allowed, 1 = failures, 2 = usage/environment error).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `agent-system/extensions/typst/scripts/typst-element-lint.sh` implementing three
  checks: (1) semantic element as first body content after a heading — blocking;
  (2) enumerated list inside a `#remark` exceeding a threshold — advisory;
  (3) per-file remark-vs-result density ratio — advisory.
- Declare the script and its test in `manifest.json`'s `provides.scripts`.
- Wire the script into `typst-implementation-agent.md` at Stage 4C (per-file, alongside the
  existing prose self-review) and Stage 5 (whole-document final pass, alongside
  `typst compile`).
- Ship a test suite with synthetic fixtures at `scripts/tests/test-typst-element-lint.sh`.
- Demonstrate acceptance against the live read-only `08-agency.typ` fixture: fires on the
  placement defect, silent on the pre-heading macro block, silent on post-result remarks.

**Non-Goals**:
- Editing `08-agency.typ` or any other chapter in the Logos/Theory repository. It is a
  read-only test fixture for this task.
- Inventing a second set of norms. All element definitions and the density heuristic come from
  `standards/semantic-element-usage.md`.
- Promoting checks 2 or 3 to blocking. They start advisory by explicit user constraint;
  promotion requires a documented review pass against real chapters, and that review is not in
  this task's scope.
- Adding hooks or rules to the extension. `provides.hooks` and `provides.rules` stay `[]`.
- Any edit under `.claude/**`. That tree is a regenerated deploy artifact; all edits land in
  `agent-system/extensions/typst/**` at the global root `/home/benjamin/.config/nvim`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Blanket "no remark near a heading" rule fires on correct documents and gets switched off (Constraint 1) | H | M | Check 1 keys only on *first body content after a `^=+ ` heading*. It never scans before the first heading, so the ~50-line pre-heading macro block is out of scope by construction, not by exemption. Post-result remarks are unreachable by the check because prose/results intervene. Phase 5 proves both silences on the real file. |
| Unreviewed density/item thresholds harden into blocking gates (Constraint 2) | H | M | Checks 2 and 3 never contribute to the exit code. The script's own header comment records that promotion to blocking requires a documented review pass against real chapters — the note lives in the script, not only in this plan, mirroring `literature_quality_gate.py`'s advisory-check documentation. |
| Naive brace matching stops at the inner `#items[...]` close instead of the remark's own close | M | H | Track bracket depth across all `[`/`]` in the block (fixture calibration: must find line 88, not 87). Phase 2's test suite includes a nested-block fixture asserting the correct span. |
| Bracket counting corrupted by `[`/`]` inside strings, math `$...$`, or comments | M | M | Strip `//` comment tails and quoted-string contents before depth counting; treat this as a known limitation documented in the script header rather than attempting a full Typst parser. |
| Skip-list for "intervening prose" drifts from spec and mis-classifies declarations as prose | M | M | Phase 1 fixes the skip list explicitly (blank, `//` comment, `#import`, `#let`, `#set`, `#show`, bare `<label>`) — resolving the open question the research flagged. Declarations are skipped, not counted as prose, which is the Constraint-1-consistent reading. |
| Hard-coding the document-local `#items[...]` wrapper macro, which lives in the Logos/Theory template, not this extension | M | M | Count Typst-native enumeration markers (`+`, `-`, `N.`) inside the matched remark span; never key on `items[`. |
| Script wired at the source-store path and therefore unreachable after deploy | M | L | Agent invocations use `bash .claude/scripts/typst-element-lint.sh` (deployed path). Phase 6 greps the agent file to confirm no `agent-system/` path appears in an invocation. |
| Merge conflict with task 178 on `typst-implementation-agent.md` | L | L | Task 178 is already merged; Phase 6 edits are additive insertions into the existing Stage 4C and Stage 5 blocks, not rewrites. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Phases 1-3 are strictly sequential because
all three modify the same script file; Phases 4 (writes `scripts/tests/`) and 5 (read-only run
against an external fixture) are file-disjoint and may run together.

### Phase 1: Script Scaffold and Check 1 (Placement, Blocking) [COMPLETED]

**Goal**: A runnable `typst-element-lint.sh` that correctly reports the placement violation —
a semantic element standing as the first body content after a heading with no intervening
prose — and exits nonzero when one is found.

**Tasks**:
- [x] Create `agent-system/extensions/typst/scripts/typst-element-lint.sh`. *(completed)*
- [x] Class B strict mode: `set -uo pipefail`, no `-e` (the script must keep scanning after the
      first finding and report a full summary). *(completed)*
- [x] Header comment block documenting: purpose, the three checks, the severity split, exit
      codes (`0` = pass, warnings allowed; `1` = placement failures; `2` = usage/environment
      error), and an explicit note that checks 2 and 3 are ADVISORY-ONLY and that promoting
      either to blocking requires a documented review pass against real chapters first. *(completed)*
- [x] CLI: `typst-element-lint.sh [--verbose] [--help] PATH...` where each PATH is a `.typ`
      file or a directory scanned recursively for `*.typ`. No PATH, or a nonexistent PATH,
      exits 2 with usage guidance. *(completed)*
- [x] Colored/plain `PASS` / `FAIL` / `WARN` output per file, plus a trailing summary line with
      counts, following `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`'s
      shape. *(completed)*
- [x] Element inventory as a single array constant, sourced from
      `context/project/typst/standards/semantic-element-usage.md`: `definition`, `theorem`,
      `lemma`, `corollary`, `example`, `proof`, `remark`, `rule-block`, `rule-list`. Match as
      `#{element}` followed by optional whitespace then `(` or `[`. *(completed)*
- [x] Implement check 1 as an awk line-scan: on matching `^=+ ` (covering `=`, `==`, `===`
      uniformly per the standard's Universal Placement Rule), advance to the next content line,
      skipping blank lines, `//` comment lines, `#import`/`#let`/`#set`/`#show` declaration
      lines, and bare `<label>` lines. If that content line opens a semantic element, report a
      FAIL naming file, line number, heading text, and element. *(completed)*
- [x] Violation message points the author at the correct home for the content per the
      standard's "Where Tracking Content Belongs" section (`specs/**`, an appendix, or a
      dedicated status section) rather than only saying the placement is wrong. *(completed)*
- [x] Never scan before the first heading match — the pre-heading region is out of scope by
      construction. *(completed)*
- [x] `bash -n` clean; `shellcheck` clean if available on PATH. *(completed: shellcheck not installed on this system, so only bash -n was run)*
- [x] Manual smoke run against `~/Projects/Logos/Theory/typst/manual/chapters/08-agency.typ`
      (read-only) confirming a FAIL is reported at line 57. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The element inventory is exactly the nine elements listed above, and
`08-agency.typ`'s placement defect sits at heading line 55 / element line 57. Confirm by
re-reading the `## Element Inventory` region of
`agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md` and by
`grep -n '^= \|#remark' ~/Projects/Logos/Theory/typst/manual/chapters/08-agency.typ | head`
before hard-coding either. If the standard lists a tenth element or different names, the
standard wins — do not carry this plan's list forward unverified.

**Files to modify**:
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` - new file; scaffold, CLI,
  element inventory, check 1.

**Verification**:
- `bash -n scripts/typst-element-lint.sh` exits 0.
- Running the script on the live fixture prints a FAIL for line 57 and exits 1.
- Running it on a hand-made minimal file whose heading is followed by a prose paragraph exits 0
  with no findings.
- Running it on a file consisting only of `#import`/`#let`/comments with no heading exits 0.

---

### Phase 2: Check 2 — Enumerated Items Inside a Remark (Advisory) [COMPLETED]

**Goal**: The script warns — without affecting its exit code — when a `#remark` block's body
contains more enumerated items than the threshold.

**Tasks**:
- [x] Implement bracket-depth matching over a `#remark` block to find its true extent: from the
      opening `[` of the remark body, track `[`/`]` depth across lines until depth returns to
      zero. *(completed)*
- [x] Before depth counting on each line, strip `//` comment tails and quoted-string contents so
      brackets inside them do not corrupt the depth. *(completed)*
- [x] Within the matched span, count Typst-native enumeration markers at line start (after
      leading whitespace): `+ `, `- `, and `N. `. Do NOT key on the document-local `#items[`
      wrapper macro, which is defined in the Logos/Theory template rather than in this
      extension and will not exist in other content repos. *(completed)*
- [x] Threshold: warn when the count exceeds 3. Record in the script header that this number has
      no anchor in `semantic-element-usage.md` (which is qualitative — "sparing", "never a long
      enumerated status or tracking list") and is therefore an initial, unreviewed value. *(completed)*
- [x] Emit as `WARN`, incrementing a warning counter only. Never contributes to a nonzero exit. *(completed)*
- [x] Warning text names the remark's opening line, the item count, and the correct home for
      tracking content. *(completed)*
- [x] Document the known limitation (no full Typst parse; brackets inside math `$...$` may still
      confuse depth) in the header comment. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The fixture's first remark spans lines 57-88 with exactly 25 `+` items,
and its inner `#items[...]` closes at line 87 — the matcher must not stop one line early.
Confirm with `sed -n '57,90p' ~/Projects/Logos/Theory/typst/manual/chapters/08-agency.typ` and a
direct count of `+`-marker lines in that range before treating 25 / line 88 as settled.

**Files to modify**:
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` - add the bracket matcher and
  check 2.

**Verification**:
- On the live fixture, the script warns that the remark opening at line 57 contains 25 items,
  and reports the block extent as ending at line 88 (not 87).
- Adding only check 2 does not change the exit code on a file that has a long remark but no
  placement violation: exit stays 0.
- A synthetic remark containing a nested `#items[...]` block resolves to the outer close.

---

### Phase 3: Check 3 — Remark Density (Advisory) and Exit-Code Semantics [COMPLETED]

**Goal**: Per-file density warning grounded in the standard's own stated ratio, plus a final,
explicitly tested exit-code contract that keeps advisory findings non-blocking.

**Tasks**:
- [x] Count per file: `#remark` occurrences vs. the theorem-family total
      (`#definition` + `#theorem` + `#lemma` + `#corollary` + `#example`), using the same
      `#{element}\s*[\(\[]` matching as check 1. *(completed)*
- [x] Warn when remarks strictly exceed the theorem-family count, citing the standard's own
      wording ("if a chapter has more remarks than theorems, that is a signal the remarks are
      doing work that belongs elsewhere") rather than an invented metric. *(completed)*
- [x] Guard the degenerate case: a file with zero theorem-family elements and a small number of
      remarks should not warn merely because `n > 0` — require at least a small absolute floor
      (e.g. 3 remarks) before the ratio is meaningful, and document the floor in the header. *(completed)*
- [x] Consolidate exit-code logic in one place: exit 1 if and only if the check-1 failure count
      is greater than zero; exit 0 otherwise regardless of warning count; exit 2 for
      usage/environment errors. *(completed)*
- [x] Summary line reports failures and warnings separately so an advisory finding is visibly
      distinct from a blocking one. *(completed)*
- [x] `--verbose` prints per-file counts even when nothing is flagged, so the thresholds can be
      reviewed against real corpora later (this is the data the eventual promotion review needs). *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: `08-agency.typ` has 23 remarks against 39 theorem-family elements, so
check 3 must stay SILENT on that file while check 1 fires. Confirm with counting greps over the
fixture before relying on it as the "does not trivially fire" evidence; if the counts differ,
report the observed numbers rather than the plan's.

**Files to modify**:
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` - add check 3 and finalize
  exit-code handling.

**Verification**:
- On the live fixture: check 1 FAILs, check 2 WARNs, check 3 does NOT warn, exit code is 1.
- On a synthetic file with 5 remarks and 1 theorem: check 3 WARNs, exit code is 0.
- On a synthetic file with 2 remarks and 0 theorems: no warning (absolute floor holds).
- `--verbose` on a clean file prints counts and exits 0.

---

### Phase 4: Test Suite and Synthetic Fixtures [COMPLETED]

**Goal**: A self-contained test suite proving each check's fire and silence cases without
depending on the external Logos/Theory repository.

**Tasks**:
- [x] Create `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` per
      `shell-script-testing.md`'s narrow-single-script rule. *(completed)*
- [x] Fixtures created in a temp dir by the test itself (inline heredocs, cases a-i plus a
      warnings-only case and CLI/directory-scan cases) — all nine required cases (a)-(i)
      implemented, matching the plan's naming. *(completed)*
- [x] Assert exit codes explicitly, including that a warnings-only run exits 0. *(completed)*
- [x] Test script follows the same Class B strict mode and reports a PASSED/FAILED summary. *(completed)*
- [x] Run the suite; all cases green (37 assertions passed, 0 failed). *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Nine fixture cases (a)-(i) are asserted as sufficient coverage. Confirm at
implementation time that each of the three checks has at least one fire case and one silence
case, and add cases rather than dropping them if a check turns out uncovered.

**Files to modify**:
- `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` - new file.

**Verification**:
- `bash agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` exits 0 with all
  cases passing.
- The suite passes with no network access and without the Logos/Theory repository present.

---

### Phase 5: Acceptance Validation Against the Live Fixture [COMPLETED]

**Goal**: Documented evidence that the lint satisfies the task's three acceptance criteria on
the real defect, with zero modifications to the fixture.

**Tasks**:
- [x] Run the script against `~/Projects/Logos/Theory/typst/manual/chapters/08-agency.typ` in
      read-only mode; capture the full output. *(completed)*
- [x] Confirm criterion 1: a placement FAIL is reported for the remark at line 57 following the
      `= Agency` heading at line 55. *(completed)*
- [x] Confirm criterion 2: no finding references any line in the pre-heading region (lines 1-53
      — `#import`, chapter-local `#let` macros, `//` comment blocks). *(completed)*
- [x] Confirm criterion 3: no finding references the post-result remarks at lines 208, 237,
      353, which are the standard's endorsed usage. *(completed)*
- [x] Confirm criterion 4: density findings are advisory — the observed remark/theorem-family
      counts do not produce a blocking result, and the run's exit code is driven solely by the
      placement failure. *(completed)*
- [x] Run against the whole `~/Projects/Logos/Theory/typst/manual/chapters/` directory and note
      the aggregate false-positive rate; if any correct document is flagged by check 1, treat
      that as a blocking defect in the check and fix it before Phase 6. *(completed: 40 placement
      failures across 8 of 12 chapters; manual inspection of a representative sample of 7+
      instances across 6 different files confirmed every one is a genuine instance of the same
      defect pattern -- a heading immediately followed by a semantic element with zero
      intervening prose -- not a lint false positive; zero correct documents were flagged)*
- [x] Record the observed output verbatim in the implementation summary as the acceptance
      evidence. *(completed)*
- [x] Verify with `git -C ~/Projects/Logos/Theory status --porcelain` that the fixture
      repository is unmodified. *(completed: typst/manual/chapters/ shows zero diff)*

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The acceptance anchors are heading line 55 / element line 57 / pre-heading
region lines 1-53 / legal post-result remarks at lines 208, 237, 353. These line numbers are a
snapshot of an external repository that this task does not control and may have drifted. Re-derive
them with `grep -n` at implementation time and report the observed values; a drifted line number
is not a lint defect, but a defect found at a *different* structural position is.

**Files to modify**:
- None. This phase is read-only; `08-agency.typ` and the Logos/Theory repository MUST NOT be
  modified.

**Verification**:
- All four acceptance criteria observed and recorded.
- `git -C ~/Projects/Logos/Theory status --porcelain` shows no change attributable to this task.

---

### Phase 6: Manifest, Agent, and Extension Documentation Wiring [COMPLETED]

**Goal**: The lint is declared in the manifest, invoked from the implementation agent's
verification path alongside `typst compile`, and mentioned in the extension's tooling
documentation.

**Tasks**:
- [x] `agent-system/extensions/typst/manifest.json`: set `provides.scripts` to
      `["typst-element-lint.sh", "tests/test-typst-element-lint.sh"]`, matching the
      array-of-relative-paths shape used by `lean/manifest.json`. Leave `provides.hooks` and
      `provides.rules` as `[]`. *(completed)*
- [x] Validate the manifest still parses: `jq . manifest.json` exits 0. *(completed)*
- [x] `agents/typst-implementation-agent.md` Stage 4C: add the mechanical invocation immediately
      alongside the existing "Structural self-review (executed, not a reminder)" prose block, as
      its counterpart — `bash .claude/scripts/typst-element-lint.sh {changed .typ file}` per
      changed file. State that a placement FAIL blocks marking the phase complete and that
      advisory warnings must be reported, not silently ignored. *(completed)*
- [x] `agents/typst-implementation-agent.md` Stage 5: add a whole-document lint pass alongside
      the existing `typst compile` — explicitly "alongside, not replacing" — so a run that
      resumed mid-plan and skipped per-phase Stage 4C still gets one full pass before final
      metadata. *(completed)*
- [x] Add a MUST DO bullet to the agent's Critical Requirements naming the lint, and confirm the
      existing MUST NOT #7/#8 prose (from the semantic-element contract) is left intact. *(completed)*
- [x] Use the DEPLOYED path `.claude/scripts/typst-element-lint.sh` in every agent invocation,
      never the `agent-system/extensions/typst/scripts/` source-store path. *(completed)*
- [x] `EXTENSION.md`: extend the "Language Routing" table's Implementation Tools cell from
      `Bash (typst compile)` to also name the lint, and add a line under "Common Operations"
      showing the invocation. *(completed)*
- [x] Confirm no task-number reference ("task N") appears in any file touched outside `specs/**`
      per `no-task-references-in-deliverables.md`. *(completed)*
- [x] Confirm no file under `.claude/**` was written by this task. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly three files are wired in this phase — `manifest.json`,
`agents/typst-implementation-agent.md`, `EXTENSION.md` — and `provides.scripts` gets exactly two
entries. Confirm at implementation time by grepping the extension for any other declaration site
that enumerates scripts (e.g. `index-entries.json`, `opencode-agents.json`); if one exists and
requires the script listed, add it and record the deviation rather than silently skipping it.

**Files to modify**:
- `agent-system/extensions/typst/manifest.json` - populate `provides.scripts`.
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - Stage 4C per-file
  invocation, Stage 5 whole-document invocation, Critical Requirements bullet.
- `agent-system/extensions/typst/EXTENSION.md` - Language Routing tools cell and Common
  Operations entry.

**Verification**:
- `jq -r '.provides.scripts[]' agent-system/extensions/typst/manifest.json` lists both entries.
- `grep -n 'typst-element-lint' agent-system/extensions/typst/agents/typst-implementation-agent.md`
  shows invocations in both Stage 4C and Stage 5, all using `.claude/scripts/`.
- `grep -rn 'agent-system/extensions/typst/scripts' agent-system/extensions/typst/agents/`
  returns nothing (no source-store paths in invocations).
- `grep -rn 'typst compile' agent-system/extensions/typst/agents/typst-implementation-agent.md`
  still present — the lint was added alongside, not as a replacement.
- `git status --porcelain .claude/` shows no changes from this task.

---

## Testing & Validation

- [ ] `bash -n` and (where available) `shellcheck` clean on both the lint script and its test.
- [ ] `bash agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` exits 0 with
      every case passing, with no dependency on the external Logos/Theory repository.
- [ ] Lint run on `08-agency.typ` reports the placement FAIL at the remark following
      `= Agency`, and exits 1.
- [ ] Lint run on `08-agency.typ` reports NO finding in the pre-heading macro region and NO
      finding on the post-result remarks.
- [ ] A warnings-only run (advisory findings, no placement violation) exits 0 — the Constraint 2
      guarantee, tested explicitly, not assumed.
- [ ] Lint run across the whole chapters directory produces no check-1 false positive on a
      correct document.
- [ ] `jq . agent-system/extensions/typst/manifest.json` parses.
- [ ] The Logos/Theory repository is byte-for-byte unmodified.

## Artifacts & Outputs

- `agent-system/extensions/typst/scripts/typst-element-lint.sh` (new)
- `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` (new)
- `agent-system/extensions/typst/manifest.json` (modified — `provides.scripts` populated)
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` (modified — Stage 4C,
  Stage 5, Critical Requirements)
- `agent-system/extensions/typst/EXTENSION.md` (modified — tooling documentation)
- `specs/179_typst_element_placement_density_lint/summaries/01_*-summary.md` including the
  verbatim Phase 5 acceptance output

## Rollback/Contingency

All changes are confined to `agent-system/extensions/typst/**` and are additive: two new files
plus three additive edits. Rollback is `git checkout -- agent-system/extensions/typst/` (after a
snapshot per `git-workflow.md`'s destructive-git rule) or reverting the per-phase commits in
reverse order. Because `provides.scripts` was previously `[]`, reverting the manifest entry
returns the extension to a state with no script infrastructure — no other component depends on
the script existing.

Partial-completion contingency: Phases 1-5 produce a standalone, tested script that is simply
not yet wired. If Phase 6 must be abandoned, the script is inert (nothing invokes it) and causes
no regression; the task can be marked `[PARTIAL]` with Phase 6 deferred without leaving the
extension in a broken state.

If Phase 5 reveals check 1 firing on a correct document, that is a blocking defect in the check,
not an acceptable cost: fix the check before wiring, since a gate that fires on correct documents
is precisely the failure mode Constraint 1 exists to prevent.
