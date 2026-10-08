# Implementation Plan: Task #353

- **Task**: 353 - Resolve the two red typst lint suites: chapter-quality-check.sh's stderr-into-JSON corruption, and typst-element-lint.sh's presence-versus-density check overlap
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: 352 (territory-serialization edge on the shared `known-failures.txt` registry only -- NOT a work dependency; see the dispatch's "WHY THE DEPENDENCY EDGE EXISTS" section, which forbids re-litigating it)
- **Research Inputs**: specs/353_typst_resolve_two_red_lint_suites/reports/01_typst-lint-channel-presence-ruling.md
- **Artifacts**: plans/01_typst-lint-channel-presence-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: typst
- **Lean Intent**: false

## Overview

Two independent red suites in the typst extension are closed out in one pass. Item A is a
mechanical channel-discipline defect: `chapter-quality-check.sh`'s `check_placement()` captures a
collaborator's output with `2>&1` and then line-parses it as structured text, so any stderr write
splices into the payload. Item B is not a defect in either check -- research established that
density (check 3) and presence (check 4) both behave exactly as their own headers document, and
the `case-h2` fixture conflated two independent edge conditions into a single over-broad
assertion. Definition of done: both suites green, both `known-failures.txt` rows this task owns
deleted, shellcheck clean on every in-scope touched file, and a redeploy verified from the
deployed tree.

**Edit target is the source store**: every file change lands under `agent-system/**`. Never
hand-edit a deployed `.claude/**` copy (`rules/source-store-deploy-boundary.md`). No file landing
under `agent-system/**` may carry a task-number reference
(`rules/no-task-references-in-deliverables.md`); task numbers are permitted only in this plan and
elsewhere under `specs/**`.

### Research Integration

The research report settles both items to a concrete, justified recommendation, and this plan
implements those rulings rather than re-deciding them:

- **Item A**: the violation is isolated to exactly one call site,
  `chapter-quality-check.sh:676`. A full `lint-json-channel-discipline.sh` auto-discovery sweep
  of all shipped (non-test) scripts under `agent-system/extensions/` found no other instance
  anywhere in the tree -- so the dispatch's "ALSO SETTLE" sibling question is answered **no**.
  The chosen fix is to drop `2>&1` so stderr inherits the caller's own fd 2 (observable, not
  discarded), rather than introducing a `mktemp`-and-relay capture file: `check_placement()`
  never inspects stderr content, so the heavier convention
  (`orchestrate-predispatch-review.sh:466-480`) is unneeded machinery here.
- **Item B ruling: resolution (iii)**, fixture layer only. `case-h2` is amended to carry one
  theorem-family element so it isolates the density floor its own comment always claimed to test;
  a new fixture gives check 4's presence path its first positive coverage (the suite currently has
  **zero** assertions exercising check 4 at all). Neither check's logic changes, and the existing
  `assert_not_contains "[WARN]"` assertion is kept unchanged in meaning.
  - Resolution (ii) is **rejected** on documentary grounds:
    `semantic-element-usage.md`'s Remark section states a remark "typically follows some
    substantial result ... because a reflection needs something to reflect *on*", so a
    remarks-only, zero-theorem-family file is precisely the shape the standard flags as suspect.
    Narrowing presence to "no semantic vocabulary at all" would suppress the signal in the worst
    case.
  - Resolution (i) is **rejected** as disproportionate: discriminating the two messages properly
    needs a machine-readable discriminator (exposing the AWK loop's raw `WARN\tdensity` /
    `WARN\tpresence` tag as a new structured-output mode), which is a real interface change to
    `typst-element-lint.sh` for what is a fixture-authoring mistake.
- **`known-failures.txt`**: both rows are fix-track, not formal-acceptance-track -- both suites
  reach full green, and the file's own header forbids a green suite keeping a known-failing
  exception. Both rows are therefore **deleted outright**, not re-owned.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no `roadmap_flag` was set, so no
roadmap phases are included and no roadmap item is claimed.

## Goals & Non-Goals

**Goals**:
- `test-lint-json-channel-discipline.sh` reaches 12/12 with stdout and stderr separated and
  stderr still observable (not discarded).
- `test-typst-element-lint.sh` reaches full green with the Item B ruling applied at the fixture
  layer, and with check 4's presence path covered positively for the first time.
- The Item B ruling and its two rejected alternatives are recorded durably in the test file's own
  fixture comments (durable anchors only, no task numbers), so the conflation cannot be
  reintroduced by a future reader.
- Both `known-failures.txt` rows this task owns are deleted; no row this task owns still reads
  `needs-owner`.
- Shellcheck reports no findings on every in-scope file this task touches, with any retained
  finding carrying a one-line `# shellcheck disable=...` rationale.
- Source store redeployed and verified; full suite sweep green.

**Non-Goals**:
- No change to `typst-element-lint.sh`'s check 3 or check 4 logic, thresholds, exemption class,
  or severity split. The ruling is that both are correct.
- No new structured-output mode / machine-readable warning-kind discriminator for
  `typst-element-lint.sh` (resolution (i)'s prerequisite). If a future caller needs to
  discriminate warning kinds programmatically, that is a separate task.
- No edits to `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh`. Its
  two pre-existing shellcheck findings (SC2034 `YELLOW` unused at :60, SC2016 info at :207) are
  **out of this task's `file_scope`** and are left untouched as a documented carry-over.
- No touching of any other task's `known-failures.txt` row.
- No `mktemp`-based stderr capture-and-relay in `check_placement()`.
- No removal of the dependency edge on the predecessor task, and no task filed to remove it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dropping `2>&1` changes what `check_placement()` sees, if some `typst-element-lint.sh` path writes diagnostics to stderr during a normal run | M | L | Research confirmed every `[FAIL]`/`[WARN]`/`[INFO]` line is written via plain `echo -e` to stdout; the only stderr writes are four CLI-usage-error paths unreachable from `check_placement()`'s single-valid-file invocation. Phase 1 re-runs `test-chapter-quality-check.sh` (83/83 today) as the regression guard before closing. |
| Adding a theorem-family element to `case-h2` trips check 1 (placement) or check 2 (item count), turning a silent fixture into a `[FAIL]` | M | L | Check 1 only evaluates the single line immediately following a heading; place the new element **after** the existing prose line, never directly under `= Chapter Nine`. Check 2 counts enumerated items inside a `#remark` body only. Phase 2's verification asserts exit 0 and no `[FAIL]` explicitly. |
| The new presence fixture collides with an existing `$WORKDIR` case path | L | L | The suite uses per-case `$WORKDIR/case-N.typ` consistently; use a basename not already present (confirm by grep before writing) and one that matches none of check 4's exemption patterns (`introduction`, `^appendix-`, `glossary`). |
| Removing a `local` variable that is in fact read somewhere in the function breaks the script silently | M | L | Phase 3 confirms each removal candidate is unread by grepping the enclosing function body before editing, and re-runs both suites plus `test-chapter-quality-check.sh` after. |
| "Shellcheck clean per shell-strict-mode.md" is an under-specified acceptance bullet: that standard documents strict-mode classes and says nothing about shellcheck, and no repo gate runs shellcheck | L | H (already observed) | Phase 3 adopts an explicit reading, recorded in the summary: (a) each touched script keeps its correct strict-mode class per `shell-strict-mode.md`, and (b) shellcheck reports no findings on in-scope touched files, pre-existing ones folded in as cleanup, out-of-`file_scope` ones documented and left. Record this as an issue-log entry when it is hit. |
| A redeploy overwrites or diverges from the source-store edits | H | L | All edits land under `agent-system/**`; Phase 5 redeploys and then re-runs the suite sweep **from the deployed tree**, so a divergence surfaces as a gate failure rather than silently. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`chapter-quality-check.sh` vs. `tests/test-typst-element-lint.sh`) and carry no dependency edge
between them. Phase 3 is serialized after both only because it re-touches files they own
(territory serialization, not a work dependency). Phase 4 is serialized after the fixes because a
row may only be deleted once its suite is observed green. Phase 5 is the terminal gate.

---

### Phase 1: Separate stdout and stderr in `check_placement()` [COMPLETED]

**Goal**: Remove the channel-discipline violation at the single confirmed call site so the
captured payload carries stdout only, with stderr still visible to the caller, and confirm the
suite reaches 12/12 against the real corpus.

**Tasks**:
- [x] Re-confirm the call site before editing: `grep -n '2>&1' agent-system/extensions/typst/scripts/chapter-quality-check.sh` -- expect exactly one hit, in `check_placement()` (around line 676). *(completed: confirmed exactly one hit at line 676)*
- [x] Change `out=$(bash "$sibling" --verbose "$f" 2>&1)` to `out=$(bash "$sibling" --verbose "$f")`. *(completed)*
- [x] Add a one-line comment immediately above the capture recording *why* stderr is deliberately left unredirected: the captured stream is line-parsed as structured `[FAIL]`/`[WARN]` output, so merging stderr into it would splice diagnostics into the payload; inheriting fd 2 keeps those diagnostics observable instead of discarding them. Durable anchors only -- name `lint-json-channel-discipline.sh` and the function, never a task number. *(completed: worded to avoid the literal `2>&1` substring so it does not false-positive the Verification grep)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` and confirm 12/12 with zero reported violations against the real corpus. *(completed: 12 passed, 0 failed)*
- [x] Run `bash agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` as the regression guard and confirm it is still fully green (83/83 today). *(completed: 83 passed, 0 failed)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts (a) exactly **one** `2>&1` call site in
`chapter-quality-check.sh`, (b) the suite currently passes **10 of 12** and will reach **12/12**,
and (c) `test-chapter-quality-check.sh` passes **83/83** before and after. All three are carried
figures from the research report, not facts. Confirm (a) by the grep above before editing, and (b)
and (c) by reading each suite's own printed tally line after the edit -- never by assuming the
carried number.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - drop `2>&1` from the `check_placement()` sibling capture; add the one-line rationale comment above it

**Verification**:
- `grep -n '2>&1' agent-system/extensions/typst/scripts/chapter-quality-check.sh` returns no hits.
- `test-lint-json-channel-discipline.sh` prints a 12/12 pass tally and exits 0.
- `test-chapter-quality-check.sh` prints a fully-green tally and exits 0.
- The sibling-sweep answer is confirmed by the suite's own real-corpus auto-discovery pass
  reporting zero violations across every shipped script -- this *is* the sweep the dispatch asked
  for; record the result for the summary.

---

### Phase 2: Apply the Item B ruling at the fixture layer [COMPLETED]

**Goal**: Make `case-h2` isolate only the density-floor condition it was written to test, add the
suite's first positive coverage of check 4's presence warning, and record the ruling and its
rejected alternatives in the test file itself.

**Tasks**:
- [x] Confirm the current state before editing: the suite passes 36 of 37, failing only
      `case-h2 (2 remarks / 0 theorems, floor holds): output unexpectedly contains [WARN]`.
      *(completed: confirmed 36 passed, 1 failed)*
- [x] Confirm no fixture basename collision and no existing presence coverage:
      `grep -n 'case-h3\|presence\|introduction\|appendix-\|glossary' agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh`
      (expect zero hits today). *(completed: zero hits confirmed)*
- [x] Amend the `case-h2` fixture body to carry exactly **one** theorem-family element
      (`#definition` or `#theorem`), placed **after** the existing prose line -- never as the first
      body content under a heading, which would trip check 1. Keep both remarks and keep all three
      existing `case-h2` assertions (`assert_exit 0`, `assert_not_contains "[WARN]"`,
      `assert_not_contains "[FAIL]"`) unchanged. *(completed: used `#theorem("Result")[...]`, byte-identical assertion lines confirmed via git diff)*
- [x] Rewrite the `case-h2` fixture comment banner to state both conditions explicitly: the
      fixture isolates check 3's absolute density floor (2 remarks < floor of 3), and it now also
      satisfies check 4 (family != 0) so that the blanket "no `[WARN]`" assertion tests what it
      claims. Record the ruling inline in that banner: the two checks are independent axes, both
      behave as their own headers document, the fixture -- not either check -- was the thing at
      fault, and the two rejected alternatives (narrowing the assertion by rendered-text substring;
      narrowing check 4 to mean "no semantic vocabulary at all") with one clause each on why.
      Cite `semantic-element-usage.md`'s Remark "Legal placement" rationale as the documentary
      ground for keeping check 4's behavior. Durable anchors only -- no task numbers.
      *(completed: banner cites the Remark section's Legal placement text verbatim, "typically follows some substantial result ... because a reflection needs something to reflect on")*
- [x] Add a new adjacent fixture (`case-h3`) covering check 4's positive path: 2 remarks, **zero**
      theorem-family elements, under a basename matching none of the exemption patterns. Assert
      exit code **0** (checks 2-4 are advisory-only and never affect the exit code -- the severity
      split), that the output **does** contain `[WARN]`, and that it contains the presence
      message's own distinguishing text (`zero theorem-family elements`) rather than the
      shared `theorem-family` token.
- [x] Run `bash agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` and
      confirm every assertion passes and it exits 0. *(completed: 40 passed, 0 failed)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the suite holds **37** assertions today (36 passing) and
that the new fixture adds roughly **3** more, for a final count near **40**. These are carried
figures, not facts, and the dispatch's literal "37/37" acceptance bullet must be read as "the
existing 37 plus any new fixture's own assertions, all green" -- not as a ceiling forbidding added
coverage. Confirm by reading the suite's own printed tally line before and after, and report both
numbers in the summary.

**Files to modify**:
- `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` - amend the `case-h2` fixture body and comment banner; add the new `case-h3` presence fixture and its assertions

**Verification**:
- `test-typst-element-lint.sh` exits 0 with every assertion passing, and its total assertion count
  is strictly greater than 37.
- The `case-h2` assertions are byte-identical to their pre-edit form (only the fixture body and
  comment changed) -- confirm by reading `git diff` for that hunk.
- The new fixture's `[WARN]` assertion matches on `zero theorem-family elements`, not on the
  ambiguous bare `theorem-family` substring.
- `grep -rn 'task [0-9]' agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh`
  returns no hits (no task-number references in a file under `agent-system/**`).

---

### Phase 3: Shellcheck cleanup on in-scope touched files [COMPLETED]

**Goal**: Make shellcheck report no findings on every in-scope file this task touches, preferring a
documented `disable` over deletion wherever the flagged construct is a deliberate harness slot,
and explicitly record the out-of-`file_scope` carry-over.

**Tasks**:
- [x] Re-run the baseline to get the live finding set rather than trusting the carried list:
      `nix-shell -p shellcheck --run 'shellcheck -x agent-system/extensions/typst/scripts/chapter-quality-check.sh agent-system/extensions/typst/scripts/typst-element-lint.sh agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh'`.
      *(completed: live findings matched the carried set exactly -- SC2016 at :495, SC2034 at :527 (`chapter-quality-check.sh`), SC2034 at :91 (`typst-element-lint.sh`), SC2329 at :58 and SC2034 at :68 (`test-lint-json-channel-discipline.sh`); `test-typst-element-lint.sh` clean)*
- [x] `chapter-quality-check.sh`: confirm `ratio` is unread anywhere inside `check_claim_ratio`
      (grep the function body), then drop it from that function's `local` declaration list.
      *(completed)*
- [x] `chapter-quality-check.sh`: resolve the SC2016 info finding (literal backtick pattern inside
      a single-quoted `grep -oE` regex -- not an actual expansion bug) with a
      `# shellcheck disable=SC2016` carrying a one-line rationale naming the intent, since
      requoting would change the regex. *(completed: directive placed before the enclosing inner `while` statement, since a bare trailing comment after a `done < <(...)` redirection does not parse as a valid shellcheck directive position)*
- [x] `typst-element-lint.sh`: confirm `SCRIPT_DIR` is referenced nowhere else in the file (it is
      genuinely dead -- this script resolves sibling paths differently), then delete the assignment.
      *(completed)*
- [x] `test-lint-json-channel-discipline.sh`: **keep** `LAST_STDERR` and add a
      `# shellcheck disable=SC2034` with a one-line rationale -- it is a deliberate captured-stderr
      harness slot, and deleting the stderr capture from a channel-discipline suite would remove
      exactly the capability this task's Item A fix is about. Likewise annotate the `cleanup`
      SC2329 finding, which is a false positive on `trap`-registered indirect invocation.
      *(completed)*
- [x] Confirm each touched script's strict-mode class is unchanged and still correct per
      `context/standards/shell-strict-mode.md` (the counter-idiom test harnesses are Class B and
      must not gain `-e`). *(completed: no `set -` line touched in any of the four files)*
- [x] Record, for the summary, that
      `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh`'s two findings
      (SC2034 `YELLOW`, SC2016 info) are **outside this task's `file_scope`** and were
      deliberately left untouched. *(completed: recorded here and will be recorded in the summary)*
- [x] Re-run all three affected suites and confirm they are still green. *(completed: 12/12, 40/40, 83/83)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts a specific finding set carried from research -- SC2016 at
`chapter-quality-check.sh:495`, SC2034 at `:527`, SC2034 at `typst-element-lint.sh:91`, SC2329 at
`test-lint-json-channel-discipline.sh:58` and SC2034 at `:68`, with
`test-typst-element-lint.sh` clean. Line numbers will have shifted by Phases 1-2's edits, and the
set may differ under a different shellcheck version. Confirm by re-running the baseline command
above as the phase's first step and working from its live output, never from these carried
line numbers.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - drop the unused `ratio` local; add the SC2016 disable with rationale
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` - delete the dead `SCRIPT_DIR` assignment
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` - add the SC2034 (`LAST_STDERR`) and SC2329 (`cleanup`) disables with rationales

**Verification**:
- The baseline shellcheck command above reports no findings on all four listed files.
- `test-lint-json-channel-discipline.sh`, `test-typst-element-lint.sh`, and
  `test-chapter-quality-check.sh` all still exit 0 with green tallies.
- Every added `# shellcheck disable=` line carries a rationale clause on the same or preceding
  line; no bare disable.
- No task-number reference appears in any edited file (all four live under `agent-system/**`).

---

### Phase 4: Close out both `known-failures.txt` rows [NOT STARTED]

**Goal**: Delete the two registry rows this task owns, now that both suites are green -- the
fix-track outcome, not the formal-acceptance branch.

**Tasks**:
- [ ] Re-confirm ownership and row count before editing:
      `grep -n 'test-lint-json-channel-discipline.sh\|test-typst-element-lint.sh' agent-system/extensions/core/scripts/tests/known-failures.txt`
      -- expect exactly two non-comment data rows (plus unrelated comment-line mentions in the
      file's own seed note, which are **not** rows and must not be deleted).
- [ ] Delete both data rows outright. Do **not** rewrite `needs-owner` to this task's durable slug:
      the formal-acceptance branch applies only when the assertion is kept as permanently
      wrong/moot, and here both suites reach full green, so the file's own header forbids retaining
      a known-failing exception ("leaving the row is how a stale exception silently masks a future
      regression of the same suite").
- [ ] Leave every other task's row untouched -- verify with `git diff` that exactly two lines were
      removed and nothing else changed.
- [ ] Do not duplicate this status in prose anywhere else; this file is the single source of truth
      (`context/standards/shell-script-testing.md` points here rather than keeping a copy).
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --jobs auto --fail-on-new`
      and confirm neither suite appears as a failure, and that no previously-EXPECTED failure has
      been reclassified NEW by the row removal.
- [ ] Commit this green sub-step.

**Timing**: 0.25 hours

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts this task owns exactly **two** rows (one per suite, both
`category=real-defect`, both `owner=needs-owner`). Confirm by the grep above before deleting, and
confirm the diff removes exactly two lines -- the file also mentions `test-typst-element-lint.sh`
inside a comment-line seed note, which is deliberately not a row.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - delete the `test-lint-json-channel-discipline.sh` and `test-typst-element-lint.sh` data rows

**Verification**:
- `grep -c '^test-lint-json-channel-discipline.sh|\|^test-typst-element-lint.sh|' known-failures.txt`
  returns 0.
- No row anywhere in the file that this task owns still reads `needs-owner` (there are none left,
  because both were deleted).
- `git diff --stat` for the file shows exactly two deletions and zero insertions.
- `run-all.sh --fail-on-new` exits 0.

---

### Phase 5: Redeploy and run the full gate from the deployed tree [NOT STARTED]

**Goal**: Push the source-store changes into the deployed `.claude/` tree, verify the deploy
matches its source, and confirm the whole suite sweep is green from the deployed tree.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the
      source store.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm it exits 0 (deploy tree matches
      source store, hooks registered). Note that a pass here claims only deploy currency, not
      end-to-end exercise -- the suite sweep below is the second half.
- [ ] From the deployed tree, re-run both subject suites and the regression suite, confirming each
      exits 0 with a green tally.
- [ ] Run the full `bash .claude/scripts/tests/run-all.sh --jobs auto --fail-on-new` sweep and
      confirm exit 0 with no NEW failures.
- [ ] Confirm no task-number reference landed anywhere under `agent-system/**` in this task's diff:
      `git diff --name-only` scoped to `agent-system/`, then
      `bash .claude/scripts/check-task-references.sh` if available.
- [ ] Commit the phase.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- none planned (this phase redeploys and verifies; the deployed `.claude/**` tree is regenerated output, never a hand-edit target)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 -- the complete gate set this tier names.
- `run-all.sh --jobs auto --fail-on-new` exits 0 from the deployed tree.
- `test-lint-json-channel-discipline.sh` 12/12 and `test-typst-element-lint.sh` fully green, both
  observed from the deployed tree rather than only from the source store.
- The task-reference check reports no hits under `agent-system/**`.

---

## Testing & Validation

- [ ] `test-lint-json-channel-discipline.sh`: 12/12, zero reported violations against the real
      corpus.
- [ ] `test-typst-element-lint.sh`: every assertion green, total count strictly greater than 37
      (the added presence fixture).
- [ ] `test-chapter-quality-check.sh`: still fully green (regression guard for the `2>&1` removal).
- [ ] `run-all.sh --jobs auto --fail-on-new`: exit 0, no NEW failures, from both the source store
      and the deployed tree.
- [ ] `shellcheck -x` on all four in-scope touched scripts: no findings.
- [ ] `verify-deploy.sh`: exit 0.
- [ ] No task-number reference anywhere in this task's `agent-system/**` diff.

## Artifacts & Outputs

- `specs/353_typst_resolve_two_red_lint_suites/plans/01_typst-lint-channel-presence-fixes.md` (this plan)
- `specs/353_typst_resolve_two_red_lint_suites/summaries/01_*-summary.md` recording: the Item B
  ruling as implemented (resolution (iii)) with the two rejected alternatives and their grounds;
  the sibling-sweep answer for the `2>&1`-then-parse shape (**no** sibling instance anywhere in
  `agent-system/extensions/`); the before/after assertion counts for both suites; the adopted
  reading of the "shellcheck clean" acceptance bullet; and the out-of-`file_scope`
  `lint-json-channel-discipline.sh` carry-over.
- Modified source-store files: `chapter-quality-check.sh`, `typst-element-lint.sh`,
  `tests/test-typst-element-lint.sh`, `tests/test-lint-json-channel-discipline.sh`,
  `tests/known-failures.txt`.
- Regenerated deployed `.claude/` tree (output, not a deliverable to hand-edit).

## Rollback/Contingency

Each phase commits its own green sub-step, so a failed phase reverts by discarding only that
phase's uncommitted edits -- the preceding green state is already committed.

- **Phase 1 regression** (`test-chapter-quality-check.sh` goes red): restore the `2>&1` to return
  to the committed baseline, then re-examine whether `typst-element-lint.sh` has a reachable
  stderr write that the research sweep missed. If so, the fix shape changes to the heavier
  capture-and-relay convention (`orchestrate-predispatch-review.sh:466-480`) rather than plain
  removal -- that is a fix-shape change, not a ruling change, and should be recorded.
- **Phase 2 regression** (the amended `case-h2` trips check 1 or check 2): move the added
  theorem-family element further from the heading, never special-case the check.
- **Phase 4**: the two deleted rows are recoverable verbatim from git history; re-adding them
  restores the prior advisory baseline exactly, and per the file's own header a missing or partial
  manifest never changes which suites run.
- If uncommitted work must be discarded before a genuine rollback, take a durable checkpoint
  first per `context/contracts/recovery.md`'s rollback rung -- do not emit a bare precautionary
  `git-snapshot.sh` as a routine start-of-phase step.
