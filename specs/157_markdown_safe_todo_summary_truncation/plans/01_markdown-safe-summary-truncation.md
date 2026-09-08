# Implementation Plan: Markdown-safe "Grouped by Topic" truncation

- **Task**: 157 - Markdown-safe TODO summary truncation
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: None
- **Research Inputs**: None (task description carries a verified root cause, evidence, and acceptance bar)
- **Artifacts**: plans/01_markdown-safe-summary-truncation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/context/standards/shell-script-testing.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The "Grouped by Topic" summary lines in `specs/TODO.md` are produced by a blind character slice
in `generate-task-order.sh`, which both corrupts markdown (an unclosed inline-code backtick
bleeds highlighting across the rest of the line) and shows the top of a long prose
`.description` where a purpose-written `.title` already exists. This plan lands three coupled
sub-fixes at the single source expression that feeds every emit site, mirrors the guarantee to
the second slice site used for cross-topic "(see above)" annotations, and puts the regression
under a test the directory currently lacks entirely.

Definition of done: every line of the regenerated section has an even backtick count asserted
mechanically, truncated lines end at a word boundary with a visible marker, title-bearing tasks
render their title while title-less tasks are not made worse, both slice sites are demonstrated
(not assumed) to be covered, and a new suite under `scripts/tests/` fails against the pre-fix
script.

### Research Integration

No research report exists for this round, and none was requested: the task description already
carries a verified root cause with file-and-line citations, a live-file evidence trail, an
explicit three-part work list, and a measurable acceptance bar. Planning confirmed every load-
bearing claim directly against the repository rather than restating it (findings below).

Confirmed during planning:

- `agent-system/extensions/core/scripts/generate-task-order.sh:155` is the single
  `task_desc` producer, reading `(.description // .project_name) | ltrimstr(" ") | .[0:65]`.
- The second slice at `:592` (`local short_desc="${desc:0:40}"`) applies to the already-sliced
  value, inside the cross-topic branch of the tree printer.
- The other emit sites (`:593`, `:600`, `:766`) consume `task_desc` unmodified, so `:155` is
  genuinely the fix point for them.
- The regression witness is live right now. Exactly one line in the "Grouped by Topic" section
  of the current `specs/TODO.md` carries an odd backtick count, and it is the line the operator
  reported (an unclosed `` ` `` after "not per-session.").
- `scripts/tests/` contains no suite exercising `generate-task-order.sh` or `generate-todo.sh`.

Three findings that **change the shape of the work** relative to the description and are
carried into the phases below:

1. **The counts in the description have drifted.** The description measured 29 active tasks /
   23 with a title / 6 without. The live `specs/state.json` now shows 41 active non-terminal
   tasks and 14 with an empty-or-absent title. The *direction* of the finding holds; the numbers
   do not. Every phase asserting a count carries a Scope Hypothesis line accordingly.
2. **Sub-fix (a) largely masks sub-fix (b) on live data.** No `.title` value in the current
   state.json contains a backtick at all (checked: 27 non-empty titles, zero backticks). Once
   `.title` is preferred, the backtick hazard stops firing for every title-bearing task —
   including the witness line. The witness therefore demonstrates (a), *not* (b). Only a
   deliberately constructed adversarial fixture can prove (b), which is exactly why the
   acceptance bar demands one; this is a trap the implementer must not fall into.
3. **The longest title is 114 characters.** Titles are truncated by the same 65-character
   budget, so sub-fix (c) — word-boundary cut plus a truncation marker — is load-bearing for
   the new content, not merely a tidy-up of the old.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` found in this repository; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Make every "Grouped by Topic" line markdown-safe by construction, so no cut can leave an
  unbalanced inline-code span (or unbalanced `*`, `_`, `[`).
- Prefer the purpose-written `.title` over the top of a long prose `.description`, with
  `.description` retained as the fallback for title-less tasks.
- Cut on a word boundary and signal truncation visibly, so an elided line reads as elided
  rather than as corrupted text.
- Extend the same guarantees to the second slice site at `:592`, demonstrated on real output.
- Leave the regression covered by a test suite that fails against the pre-fix script.

**Non-Goals**:
- Hand-editing `specs/TODO.md`. It is wholly generated; any hand edit is erased on the next
  regeneration.
- Editing `.claude/scripts/**`. That tree is a gitignored deploy artifact regenerated from
  `agent-system/extensions/core/**`.
- Changing the 65-character budget itself, the topic-grouping algorithm, the dependency-tree
  rendering, or anything else in `generate-task-order.sh` beyond the two slice sites.
- Bringing the diverged `.opencode/` mirror to full feature parity with the core copy. Only the
  two slice expressions are mirrored (see Phase 6 for why that boundary).
- Backfilling `.title` for the title-less tasks. They keep rendering from `.description`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sub-fix (a) is a **content** change to roughly two dozen lines, not a formatting change; a diff reviewed only for line count would hide a regression in what the section says | H | H | Phase 5 requires eyeballing the full before/after of the section, with the baseline captured to a committed file in Phase 1 so the comparison is mechanical rather than from memory |
| Sub-fix (b) appears to work on live data purely because sub-fix (a) removed every backtick-bearing source string; the real defect ships uncovered | H | H | The adversarial fixture in Phase 2 is mandatory and is written *before* the fix; it places a backtick exactly at the cut boundary and must fail against the pre-fix script |
| jq escaping hazard: `!=` in a jq program is mangled per CLAUDE.md's "jq Command Safety" | M | L | The composed form uses no `!=`; Phase 3 re-greps the final expression to confirm, and uses `if/then/else` or `select(... | not)` if a negation becomes necessary |
| The source-store copy cannot be executed in place — `deploy-root-guard.sh` aborts it — so a naively written test silently tests the *deployed* (old) script | H | M | Phase 2 uses the proven scratch-repo harness from `test-errors-append.sh` (copy tool + guard + `lib/common.sh` into `<scratch>/.claude/scripts/`) and resolves the tool **source-store-first**, the deliberate inversion `test-postflight-deploy-gate.sh` documents |
| Fix lands in the source store but `specs/TODO.md` is regenerated by the stale deployed copy, so verification "passes" against unfixed code | H | M | Phase 5 deploys before regenerating and asserts the deployed copy matches the source store |
| Stripping backticks removes inline-code styling that some readers rely on | L | M | Accepted and recorded as a decision (below), not left implicit; at a 65-character budget the styling buys nothing and fabricated spans actively mislead |
| The `.opencode/` mirror has diverged substantially from the core copy; a mechanical port drags in unrelated differences | M | M | Phase 6 ports only the two slice expressions, by hand, and diffs the result to confirm nothing else moved |
| `.title` for a given task turns out less informative than its `.description` | L | L | Phase 5's eyeball pass is the check; a bad title is a data problem to fix in `state.json`, not a reason to revert the generator |

### Decision: strip markup rather than balance it

Recorded here so the implementer does not re-litigate it silently. **Chosen**: strip inline
markup characters before slicing. **Rejected**: appending a closing backtick when the count is
odd. The parity approach preserves code styling but fabricates a span around a truncated
fragment — rendering a cut-off path as though it named a real one when the actual content was
longer. Stripping also eliminates the whole class (`` ` ``, `*`, `_`, unclosed `[`) where a
parity check handles only the one symptom observed. If the implementer disagrees after looking
at real output, the parity approach may be chosen instead, but the reason must be stated in the
execution summary and the adversarial test must still pass.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Capture the pre-fix baseline [COMPLETED]

**Goal**: Freeze the current rendering of the "Grouped by Topic" section to a committed file so
the Phase 5 before/after comparison is mechanical, and re-measure the title-coverage numbers the
description asserted.

**Tasks**:
- [x] Extract the current "Grouped by Topic" section from `specs/TODO.md` verbatim into
      `specs/157_markdown_safe_todo_summary_truncation/baseline-grouped-by-topic.txt` *(completed)*
- [x] Run a backtick-parity census over every line of that section and record which lines have
      an odd count; confirm the witness line is among them and note its exact current text
      *(completed: exactly one odd line, task 44, 1 backtick)*
- [x] Re-measure against the live `specs/state.json`: count of active non-terminal tasks, count
      with a non-empty `.title`, and the list of task numbers without one
      *(completed: live numbers are 38 active / 26 titled / 12 title-less, both the description's
      29/23/6 and the planning-time 41/14 have drifted further)*
- [x] Record the maximum `.title` length and whether any title contains a backtick, since these
      determine whether sub-fixes (b) and (c) are exercised by live data at all
      *(completed: max title length 114 chars; 0 of 26 titles contain a backtick)*
- [x] Append the measurements as a short header comment inside the baseline file *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The description asserts 29 active tasks, 23 with a title, and exactly six
without (29, 30, 45, 51, 89, 127). Planning-time measurement already contradicts this: 41 active
and 14 title-less. Confirm the live numbers at implementation time and use those, not either
earlier figure. Likewise the claim "exactly one line carries an odd backtick count" held at
planning time; re-derive it rather than assuming.

**Files to modify**:
- `specs/157_markdown_safe_todo_summary_truncation/baseline-grouped-by-topic.txt` - new; the
  frozen pre-fix section plus its measurements

**Verification**:
- The baseline file exists, is non-empty, and contains the full section (heading through the
  last indented line).
- The odd-backtick line list in the file is reproducible by re-running the census command.
- The recorded task counts match a fresh query of `specs/state.json`.

---

### Phase 2: Write the failing regression suite [COMPLETED]

**Goal**: Create `scripts/tests/test-generate-task-order.sh` asserting all four guarantees, and
demonstrate that it FAILS against the pre-fix script. Written before the fix so it cannot be
retrofitted to whatever the fix happens to produce.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` following
      the directory's conventions: `set -uo pipefail`, `pass()`/`fail()`/`info()` helpers,
      integer `PASSED`/`FAILED` counters, `mktemp -d` workdir with a `trap ... EXIT` cleanup,
      exit 0 all-pass / 1 any-fail / 2 environment error *(completed)*
- [x] Build the scratch-repo harness modeled on `test-errors-append.sh`: create
      `<scratch>/.claude/scripts/` and copy in `generate-task-order.sh`, `deploy-root-guard.sh`,
      and `lib/common.sh`, so the guard's `*/.claude` case matches and `PROJECT_ROOT` resolves
      to the scratch root *(completed)*
- [x] Resolve `generate-task-order.sh` **source-store-first** with a deployed-tree fallback —
      the deliberate inversion documented in `test-postflight-deploy-gate.sh` — so the suite
      goes green on the source edit rather than waiting for a deploy. Resolve the two unchanged
      dependencies deploy-first, as every other suite does *(completed)*
- [x] Drive the script through `--update-todo <scratch-todo> <scratch-state>` against synthetic
      fixture `state.json` files; never read the live `specs/state.json` or `specs/TODO.md`
      *(completed: an end-of-run sha256 checksum guard on the real specs/TODO.md and
      specs/state.json confirms isolation)*
- [x] Case group 1 (markdown safety): a fixture description placing a backtick **exactly at the
      cut boundary** so the pre-fix slice orphans it, asserting an even backtick count on the
      emitted line. Add a companion case for an unbalanced `*` and one for an unclosed `[`
      *(completed)*
- [x] Case group 2 (title preference): one fixture task with both `.title` and `.description`,
      asserting the emitted line derives from the title; one with `.description` only,
      asserting it still renders and is not degraded; one with neither, asserting the
      `.project_name` fallback still applies *(completed)*
- [x] Case group 3 (budget and word boundary): a fixture whose source string exceeds the budget,
      asserting the line does not exceed it, ends at a word boundary, and carries the truncation
      marker; plus a short fixture asserting an untruncated line carries **no** marker
      *(completed)*
- [x] Case group 4 (second slice site): a fixture producing a genuine cross-topic
      "(see above)" annotation — two topics with a cross-topic dependency edge — asserting the
      same balance, boundary, and marker guarantees on that shorter form *(completed: two
      fixtures, one where the primary slice is under budget and the 40-char cut alone
      truncates, one where the primary slice is already truncated+marked and the second cut
      must not double the marker)*
- [x] Add an anti-vacuity guard per `context/standards/shell-script-testing.md`: for the
      adversarial cases, assert both the naive/wrong result and the correct one on the same
      fixture, so a fixture both approaches would get right never counts as coverage
      *(completed: case group 1's three fixtures each assert the naive 65-char slice IS
      unbalanced before asserting the actual rendered line is balanced)*
- [x] Run the suite against the unmodified script and record the failures; at minimum case
      groups 1, 2 and 3 must fail *(completed: 6 of 16 assertions failed pre-fix, spanning case
      groups 1 (1a/1b/1c), 2 (2a), 3 (3a), and 4 (4a's marker assertion) -- recorded verbatim in
      specs/157_markdown_safe_todo_summary_truncation/pre-fix-test-run.log)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `--update-todo TODO STATE` is a sufficient injection
point for a synthetic state file and that `generate-task-order.sh` sources only
`lib/common.sh` and `deploy-root-guard.sh` (both confirmed at planning time). Re-confirm the
sourced-dependency list before building the harness; if the script gained another dependency,
the scratch `.claude/scripts/` tree needs it too.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` - new suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` exits non-zero
  against the pre-fix script, with the failing case names naming the specific guarantee broken.
- The suite touches no path outside its `mktemp -d` workdir (confirm `specs/` is unchanged
  after a run).
- The suite is picked up by `scripts/tests/run-all.sh` glob discovery with no registration edit
  (`test-*.sh` under `scripts/tests/`).

---

### Phase 3: Make the primary slice site markdown-safe and title-aware [NOT STARTED]

**Goal**: Replace the blind `.[0:65]` slice at `generate-task-order.sh:155` with an expression
satisfying sub-fixes (a), (b) and (c) at once, turning Phase 2's red cases green.

**Tasks**:
- [ ] Change the source expression to prefer `.title`, falling back to `.description` then
      `.project_name`
- [ ] Strip inline markup characters before slicing (backtick at minimum; extend to `*`, `_`
      and `[` per the recorded decision)
- [ ] Normalize embedded newlines to spaces **inside jq**, replacing the current post-hoc bash
      `${desc//$'\n'/ }` which cannot work: a newline in the jq raw output splits the record
      across two lines before the `while read` loop ever sees it
- [ ] Truncate only when over budget, backing off to the last space at or before the budget and
      appending a truncation marker; leave under-budget values untouched and unmarked
- [ ] Confirm the final jq program contains no `!=` (CLAUDE.md "jq Command Safety"); if a
      negation is needed, use `select(... | not)` or an `if/then/else`
- [ ] Add a brief comment above the expression naming what each transform guards against, so a
      future reader does not "simplify" the strip or the boundary back-off away
- [ ] Run the Phase 2 suite; case groups 1, 2 and 3 must now pass

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/generate-task-order.sh` - the `desc_data` jq expression
  in `build_graph()` (line ~155), plus the now-redundant bash newline substitution below it

**Verification**:
- Phase 2's case groups 1, 2 and 3 pass; group 4 may still fail (that is Phase 4's job).
- `grep -n '!=' ` over the changed expression returns nothing.
- `bash -n agent-system/extensions/core/scripts/generate-task-order.sh` parses clean.
- Spot-run the script against a copy of the live `state.json` through the Phase 2 harness and
  read the output; no line is empty, no line lost its task number or status marker.

---

### Phase 4: Extend the guarantees to the cross-topic slice site [NOT STARTED]

**Goal**: Give the `${desc:0:40}` cut at `generate-task-order.sh:592` the same word-boundary and
marker treatment, so a cross-topic annotation cannot re-break what Phase 3 fixed.

**Tasks**:
- [ ] Introduce a small bash helper (word-boundary back-off plus truncation marker, budget as a
      parameter) rather than open-coding the logic a second time
- [ ] Replace the `${desc:0:40}` slice with a call to that helper
- [ ] Handle the already-truncated input case: a value Phase 3 already ended with a marker must
      not end up with a doubled marker after the 40-character cut
- [ ] If the implementer chose the parity approach over stripping in Phase 3, apply the same
      choice here — a parity fix at `:155` alone leaves `:592` able to split a surviving pair
- [ ] Confirm no third slice site exists: re-grep the file for `[0:` and `:0:` patterns and
      verify the emit sites at `:593`, `:600` and `:766` consume `task_desc` unmodified
- [ ] Run the Phase 2 suite; case group 4 must now pass alongside the rest

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: The description asserts exactly two slice sites and that `:593`, `:600`
and `:766` are pass-through. Both held at planning time. Re-derive the slice-site list from the
post-Phase-3 file (line numbers will have shifted) rather than trusting these numbers.

**Files to modify**:
- `agent-system/extensions/core/scripts/generate-task-order.sh` - the cross-topic branch's
  `short_desc` slice (line ~592) plus the new helper function

**Verification**:
- The full Phase 2 suite exits 0.
- A grep for character-slice syntax across the file returns only sites covered by the helper.
- `bash -n` parses clean.

---

### Phase 5: Deploy, regenerate, and verify against live data [NOT STARTED]

**Goal**: Land the fix in the deployed tree, regenerate `specs/TODO.md` from `state.json`, and
demonstrate every acceptance criterion on real output — including eyeballing the content change
that sub-fix (a) makes.

**Tasks**:
- [ ] Deploy the source store (`bash .claude/scripts/deploy-headless.sh`) and confirm
      `.claude/scripts/generate-task-order.sh` now matches the source-store copy byte for byte
- [ ] Regenerate `specs/TODO.md` via `bash .claude/scripts/generate-todo.sh` (never by hand)
- [ ] Assert mechanically over the **whole** regenerated "Grouped by Topic" section that every
      line has an even backtick count — a census, not a spot check
- [ ] Show the witness line before and after, from the Phase 1 baseline file. Record explicitly
      that its repair demonstrates sub-fix (a) (its source string changed), and that sub-fix (b)
      is proven only by the Phase 2 adversarial fixture — do not present the witness as proof
      of (b)
- [ ] Diff the section against the Phase 1 baseline and **read every changed line**, not just
      the count. Confirm each title-derived line is more informative than the description
      fragment it replaced; flag any that are worse
- [ ] Demonstrate both directions of sub-fix (a): pick title-bearing tasks and confirm the title
      is shown; pick title-less tasks from the Phase 1 list and confirm they still render from
      `.description` and are not degraded
- [ ] Assert no line exceeds the budget; assert every truncated line ends at a word boundary
      with the marker and every untruncated line carries none
- [ ] Locate an actual cross-topic "(see above)" line in the regenerated output and verify the
      same guarantees on it directly. If none exists in the live data, say so plainly and lean
      on Phase 2's case group 4 rather than claiming a live demonstration that did not happen
- [ ] Confirm no administrative preamble fragments (`=== REVISED`, `=== ADDENDUM`) remain on
      lines belonging to title-bearing tasks

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: Sub-fix (a) is expected to change roughly two dozen lines (planning-time
measurement: 27 title-bearing active tasks, so up to 27 lines change, minus any whose title and
description already coincide). Confirm the actual changed-line count from the diff against the
Phase 1 baseline; a count far below this suggests the title preference is not taking effect, and
one far above suggests the truncation change is rewriting lines it should have left alone.

**Files to modify**:
- `specs/TODO.md` - regenerated output only, never hand-edited
- `.claude/scripts/**` - written by the deploy process only

**Verification**:
- Backtick-parity census over the regenerated section reports zero odd lines.
- Budget and word-boundary assertions pass over every line of the section.
- The changed-line set from the baseline diff has been read line by line, with the reading
  recorded (not merely a count).
- Both title-bearing and title-less renderings are shown.

---

### Phase 6: Mirror to `.opencode/` and run the full gate set [NOT STARTED]

**Goal**: Apply the same two slice fixes to the tracked `.opencode/` renderer mirror, then run
the repository's full test suite and lints.

**Tasks**:
- [ ] Apply the settled Phase 3 expression to `.opencode/scripts/generate-task-order.sh`'s own
      source expression, and the settled Phase 4 treatment to its own cross-topic slice. Port
      **only** those two changes — the mirror has diverged substantially (it lacks the
      transitive-reduction block and the `deploy-root-guard.sh` sourcing), and a wholesale
      sync is explicitly out of scope
- [ ] Diff the mirror before and after to confirm nothing beyond the two expressions moved
- [ ] Note in the execution summary that this follows the established render-side-parity
      practice for this mirror rather than being a new precedent
- [ ] Run `bash .claude/scripts/tests/run-all.sh` and confirm no regression, with the new suite
      discovered and passing
- [ ] Run the task-reference lint and confirm no task numbers were introduced outside `specs/**`
      (the new test file, the generator comments, and the `.opencode/` mirror are all
      deliverables under this rule)
- [ ] Confirm the deploy-freshness state is clean so the completion deploy gate will pass

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes `.opencode/scripts/generate-task-order.sh` is the only
additional tracked copy carrying the same defect, and that it carries it at its own two sites
(planning-time measurement found the identical `.[0:65]` and `${desc:0:40}` expressions there).
Re-run a repository-wide search for copies of the generator before concluding the port is
complete.

**Files to modify**:
- `.opencode/scripts/generate-task-order.sh` - the two slice expressions only

**Verification**:
- `run-all.sh` exits 0, with `test-generate-task-order.sh` among the passing suites.
- The `.opencode/` diff touches only the two intended expressions.
- The task-reference lint passes.

---

## Testing & Validation

- [ ] `test-generate-task-order.sh` fails against the pre-fix script (recorded in Phase 2) and
      passes after Phase 4.
- [ ] The adversarial fixture — a backtick placed exactly at the cut boundary — is present and
      is the case that fails pre-fix. A suite that only uses today's data does not satisfy this.
- [ ] Every line of the regenerated "Grouped by Topic" section has an even backtick count,
      asserted over the whole section.
- [ ] The witness line is shown before and after, with its repair correctly attributed to
      sub-fix (a) rather than presented as proof of (b).
- [ ] Title-bearing tasks show their title; title-less tasks still render from `.description`
      and are not degraded. Both directions demonstrated.
- [ ] No line exceeds the budget; truncated lines end at a word boundary with a marker;
      untruncated lines carry no marker.
- [ ] The cross-topic slice site is demonstrated on a real "(see above)" line, or its absence
      from live data is stated plainly and Phase 2's case group 4 is cited instead.
- [ ] `run-all.sh` exits 0.
- [ ] The final jq program contains no `!=`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/generate-task-order.sh` - both slice sites fixed
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` - new regression suite
- `.opencode/scripts/generate-task-order.sh` - render-side parity port
- `specs/157_markdown_safe_todo_summary_truncation/baseline-grouped-by-topic.txt` - pre-fix baseline
- `specs/TODO.md` - regenerated (not hand-edited)
- `specs/157_markdown_safe_todo_summary_truncation/summaries/01_*-summary.md` - execution summary,
  which must state whether the strip or parity approach was used and why

## Rollback/Contingency

Every phase is a self-contained commit against tracked files, so rollback is `git revert` of the
phase commits in reverse order followed by a redeploy and a `generate-todo.sh` regeneration —
`specs/TODO.md` is fully derived, so it returns to the pre-fix rendering automatically and needs
no separate restoration. The Phase 1 baseline file is the independent check that it did.

Partial-rollback contingencies, in decreasing order of likelihood:

- **Sub-fix (a) produces worse lines than it replaced.** Revert only the source-expression
  change to `.title // ...` while keeping the stripping and word-boundary work; the markdown
  safety fix stands on its own and the adversarial test still passes. Fix the offending titles
  in `state.json` as separate work.
- **The `.opencode/` port destabilizes that mirror.** Revert Phase 6's mirror edit alone. The
  core fix and its test are unaffected, and the mirror is dormant (no `OC_`-prefixed task
  directories exist in this repository).
- **The deploy step misbehaves.** The source store is the tracked truth; re-running
  `deploy-headless.sh` after a revert restores `.claude/` with no manual repair, since that tree
  is gitignored and fully regenerated.
