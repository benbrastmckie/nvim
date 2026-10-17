# Implementation Plan: Task #359

- **Task**: 359 - Close lint curated array coverage gaps
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: None
- **Research Inputs**: specs/359_close_lint_curated_array_coverage_gaps/reports/01_lint-array-coverage-gaps.md
- **Artifacts**: plans/01_close-lint-curated-array-gaps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`lint-agent-contracts.sh` asserts contract-bullet coverage against hand-curated path arrays, one
per check. Two of those arrays have measurably drifted: the two books implementation agents are
absent from Check C's and Check G's arrays, and no research agent carries the bounded-wait bullet
pair Check H enforces for implementation agents. This plan normalizes the books files' bullet
text *before* registering them (registering first would redden the lint), propagates the
bounded-wait pair to the measured 11-of-23 exposed research-agent subset behind a new Check M,
and adds a completeness-net check so the next drift fails the lint instead of waiting to be
discovered by measurement. Definition of done: the lint exits 0 with every newly covered file
registered, a deliberate-removal demonstration FAILs by name for each newly covered class, the
extended test suite is green, and the source store is redeployed.

### Research Integration

The research report re-derived both gaps against the lint's own expected text and corrected the
dispatch's and the prior record's framing in four load-bearing ways, all of which this plan
sequences around:

- `books-implementation-agent.md`'s Check C bullet is correct but wrapped across **three**
  physical lines, and its Check G bullet is present but sitting in the **MUST DO** list with two
  extraneous backtick pairs around `update-plan-status.sh`/`update-task-status.sh` — so unwrapping
  alone would still miss Check G's `grep -qF`.
- `books-implementation-hard-agent.md`'s Check C item is a genuine abbreviated paraphrase needing
  full replacement, and its Check G bullet is wholly absent (though the fragment's "Clarifying
  Sentence" prose is already present verbatim in the base agent and needs no change).
- Gap 2 is **11 of 23**, not 23: 11 research agents name a concrete local build/test command (or,
  for `general-research-agent.md`, carry no tool restriction at all); 2 Lean agents use the
  separate sanctioned `lake-build-guard.sh` mechanism; 10 hold a Bash grant that is narrowly
  non-build-shaped or unexercised boilerplate.
- The deliberate sweep of Check C and Check G found **no further absentees**, with one flagged
  edge case (`literature/agents/literature-agent.md`) explicitly deferred.

The report's line-wrap ruling (hold bullets unwrapped by convention; do not teach the lint to
normalize whitespace) and its curated-array ruling (keep curation, add a completeness net) are
adopted as written and implemented in Phases 1 and 5 respectively.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:

- Check C and Check G cover both books implementation agents, with their bullets normalized to
  text the lint actually matches, and the lint exits 0.
- The line-wrap brittleness is ruled on explicitly (convention, not lint-side normalization), the
  ruling is stated in all three fragments where a bullet author will see it, and a fixture pins it.
- The exposed research-agent subset is determined by measurement, every exclusion carries an
  inline per-file reason, and the Lean sanctioned build-guard path is confirmed unbroken.
- A new completeness-net check FAILs when an agent file matching the relevant glob is in neither
  an in-scope array nor a recorded exclusion list.
- Deliberate-removal demonstrations prove each newly covered class is genuinely enforced.
- `test-lint-agent-contracts.sh` extended and green; the sanctioned shellcheck lint clean; `check-task-references.sh`
  clean on every changed path; source store redeployed.

**Non-Goals**:

- Do not edit `general-implementation-agent.md` (canonical source, reused verbatim, claimed by
  other open tasks).
- No new documents — extend `bounded-build-waiter.md` and the two existing contract fragments.
- No consumer-repo work.
- Do not classify `literature/agents/literature-agent.md`; it is a deliberately deferred Check C
  edge case, recorded rather than folded in.
- Do not give the 2 Lean research agents the generic bullet pair; their sanctioned mechanism
  would conflict with it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Registering the books paths before normalizing their bullet text turns the lint red mid-implementation | M | H if sequencing is ignored | Phase 1 orders normalization strictly before array registration as explicit sub-steps; the phase does not close until the lint exits 0 |
| Editing a fragment disturbs the `grep -F ... \| head -n1` anchor the lint extracts its expected text from, silently changing what every carrying file is checked against | H | M | Every fragment-touching phase runs the lint before and after and diffs the PASS/FAIL set; Phase 2 additionally forbids a non-byte-identical second copy of the bullet pair text |
| Check M's new array entries have no fixture in the test suite's scratch tree, producing unexplained `in-scope agent file not found` FAILs that the suite's exit-1 expectation silently absorbs | M | M | Phase 6 adds a scratch fixture for every newly registered path, or asserts the not-found line explicitly; an unexplained FAIL line is not accepted as green |
| The `formal`-family exclusion (4 files, one shared reason) looks under-scrutinized if a future edit wires a real build into one of them | M | L | Phase 2 records the exclusion reason inline per-file, never "formal family, see above", so a future grant diff is reviewable against its own justification |
| Check N's glob net false-fails a legitimately differently-worded exclusion | M | M | Check N asserts membership in in-scope **or** a recorded exclusion array; Check C's net is scoped to the `*implementation*agent.md` subset only, which the fragment's own rule makes unconditional |
| Check M double-counts or conflicts with Check K's whole-corpus antipattern check | L | L | Check K is absence-of-contradiction over every dispatchable agent; Check M is presence-only over an 11-file array — complementary by construction, exactly as Check H and Check K already are |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Rule on line-wrap, normalize the books bullets, register both files [COMPLETED]

**Goal**: Checks C and G cover both books implementation agents with the lint at exit 0, and the
single-physical-line convention is stated in both fragments that currently omit it.

**Tasks**:

- [x] Capture a baseline `lint-agent-contracts.sh --verbose` run (expected today: exit 0, 0
      failures, 13 warnings) to diff every later run against. *(completed: confirmed exit 0, 348
      passed, 13 warnings, 0 failed)*
- [x] Add the single-physical-line instruction to `no-task-references-bullet.md`'s and
      `plan-status-ownership.md`'s "Copy this exact text" instructions, mirroring
      `bounded-build-waiter.md`'s existing wording ("verbatim and each on a single physical line").
      *(completed)*
- [x] Re-run the lint and confirm the extraction anchors still resolve to the canonical fenced
      line, not the newly added prose sentence: `grep -F 'Reference task numbers' <fragment> | head -n1`
      and `grep -F 'Hand-edit the plan METADATA' <fragment> | head -n1` must return the same text
      as the baseline. *(completed: PASS/FAIL line diff against baseline was empty)*
- [x] Normalize `books-implementation-agent.md`'s Check C bullet (MUST NOT item 6): collapse the
      three physical lines into one line matching the fragment's text byte-for-byte. *(completed:
      also dropped two extraneous backtick pairs discovered during normalization, not just the
      wrap, confirmed byte-identical to the fragment's extracted line)*
- [x] Normalize `books-implementation-agent.md`'s Check G bullet: remove it from **MUST DO** item
      6, add it as a **MUST NOT** item carrying the fragment's canonical single-line text with no
      backticks around `update-plan-status.sh`/`update-task-status.sh`. *(completed)*
- [x] While in that same MUST NOT section, renumber its items into one continuous sequence,
      fixing the pre-existing restart at "9." after item 12. *(completed)*
- [x] Replace `books-implementation-hard-agent.md`'s MUST NOT item 7 abbreviated paraphrase with
      the Check C fragment's full canonical sentence. *(completed)*
- [x] Add a new MUST NOT item to `books-implementation-hard-agent.md` carrying Check G's canonical
      bullet verbatim. Leave the base agent's existing "Clarifying Sentence" prose untouched — it
      already matches the fragment. *(completed: Clarifying Sentence confirmed present verbatim,
      untouched)*
- [x] **Only after every normalization above**: add `books/agents/books-implementation-agent.md`
      and `books/agents/books-implementation-hard-agent.md` to `IN_SCOPE_RELATIVE_PATHS` (Check C)
      and `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` (Check G). *(completed: registration also surfaced an
      incidental Check I ripple -- both books files failed the heartbeat-mechanization-adoption
      advisory check once added to OWNERSHIP_IN_SCOPE_RELATIVE_PATHS; resolved by adding both to
      HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008 alongside the other 13 pre-existing
      non-invoking agents -- same shape, not a new regression)*
- [x] Update `no-task-references-bullet.md`'s prose enumeration (add `books` to its named-extension
      list and to its placement-example list) and `plan-status-ownership.md`'s "In-Scope
      Enumeration (14 files)" fenced block to 16 files. *(completed)*
- [x] Re-derive the Check C / Check G absentee sweep with the report's own method (frontmatter-gated
      agent enumeration diffed against each array via `comm -23`) and record the result for the
      final phase to report; confirm or refute "no further absentees". *(completed: glob-based
      cross-check of every `*implementation*agent.md` file against both arrays found zero
      absentees for either check, corroborating the research report's broader 77-file sweep;
      full result recorded for Phase 7's report)*
- [x] Run the lint; confirm exit 0 and both books paths named in Check C and Check G PASS lines.
      *(completed: exit 0, both books paths PASS Check C and Check G by name)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the report asserts exactly four bullet defects across the two books files
(one three-line wrap, one MUST-DO misplacement plus two backtick pairs, one abbreviated
paraphrase, one wholly absent bullet) and no further C/G absentees. The implementer confirms by
re-reading each bullet against the fragment-extracted expected text before editing, by the lint
reaching exit 0 with both files named in PASS lines after registration, and by re-deriving the
absentee sweep rather than adopting the report's result on sight.

**Tier Justification**: the blast radius is the lint's own C/G arrays plus four markdown files,
fully covered by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
plus a direct `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
exit-0 run.

**Files to modify**:

- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` - add the
  single-physical-line instruction; add `books` to the prose and placement-example enumerations
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md` - add the
  single-physical-line instruction; In-Scope Enumeration 14 -> 16 files
- `agent-system/extensions/books/agents/books-implementation-agent.md` - unwrap Check C bullet;
  move Check G bullet to MUST NOT without backticks; renumber MUST NOT list
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - replace Check C
  paraphrase with the canonical sentence; add Check G's bullet as a new MUST NOT item
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - register both books paths
  in `IN_SCOPE_RELATIVE_PATHS` and `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS`

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0.
- Both books paths appear in a Check C PASS line and a Check G PASS line by name.
- The baseline-vs-after PASS/FAIL diff shows only the two newly added PASS pairs — no previously
  passing file changed state (proving the fragment prose edits did not move the extraction anchor).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
  is green.

---

### Phase 2: Record the research-agent bounded-wait classification in the fragment [COMPLETED]

**Goal**: `bounded-build-waiter.md` carries the measured in-scope research-agent set and every
exclusion with an inline per-file reason, and its existing "Research Agents Are Out of Scope Here"
ruling is amended to point at the new section instead of contradicting it.

**Tasks**:

- [x] Re-derive the classification per file before writing anything: read each of the 23 research
      agents' tool-grant section and grep the full file for a concrete build/test invocation
      (`lake build`, `pytest`, `cargo`, `pnpm`, `nixos-rebuild`, `nvim --headless`, `latexmk`, any
      `.sh` invocation). Record any divergence from the report's 11/2/10 split explicitly rather
      than adopting it silently. *(completed: re-derivation confirmed the report's 11/2/10 split
      exactly -- no divergence found)*
- [x] Add a new section recording the in-scope set with per-file evidence (the concrete command
      named, or `general-research-agent.md`'s absent tool-restriction section, which is a wider
      exposure than any scoped grant). *(completed: "Research-Agent Bounded-Wait Scope
      (Measured)" section added)*
- [x] Record every exclusion with its own inline reason, written out per file — never "formal
      family, see above" — so a future diff touching one file's Bash grant is reviewable against
      its own recorded justification. The two Lean agents are recorded as the separate sanctioned
      `lake-build-guard.sh` mechanism, explicitly not instances of the defect. *(completed)*
- [x] Amend the existing "Item 4 Ruling: Research Agents Are Out of Scope Here, Not Dismissed"
      subsection to state that the recommended follow-up has landed and to name the new section.
      Do not delete its original reasoning. *(completed: original reasoning preserved, pointer
      sentence appended)*
- [x] State in the new section that the single-physical-line convention applies to the research
      propagation too. *(completed)*
- [x] State explicitly that the new section MUST NOT introduce a second, divergent copy of the
      bullet pair text: Check H and the planned Check M both extract their expected text with
      `grep -F ... | head -n1`, so a non-byte-identical second copy would silently become the
      expected text for one of them. Prefer referencing the existing "Copy this exact text" block
      over repeating it. *(completed: new section references the existing block rather than
      repeating the bullet text; confirmed both anchor phrases occur exactly once in the file)*
- [x] Re-run the lint and confirm Check H's two extracted anchors are byte-identical to the
      baseline and its PASS set is unchanged. *(completed: exit 0, full PASS/FAIL line diff
      against the Phase 1 baseline was empty)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the report asserts 11 in-scope, 2 sanctioned-mechanism exclusions, and 10
not-genuinely-exposed exclusions, totalling exactly the 23 named files. The implementer confirms
by re-deriving each file's classification from its own tool grant plus a full-file build-command
grep before writing the section, and records any file whose classification differs from the
report's.

**Tier Justification**: this file is the source the lint extracts Check H's expected text from, so
the one executable consequence is that text match, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
plus a direct lint run diffed against the Phase 1 baseline.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - new research-agent
  scope section (in-scope set with evidence, exclusions with inline per-file reasons); amend the
  Item 4 Ruling subsection; state the single-physical-line and no-divergent-second-copy constraints

**Verification**:

- Check H's extracted anchors (`grep -F 'canonical idiom VERBATIM' | head -n1` and
  ``grep -F 'arm a `Monitor` to watch a local verification' | head -n1``) are byte-identical to
  the Phase 1 baseline.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0 with
  Check H's PASS set unchanged.
- The section's in-scope count plus exclusion count equals 23, with every one of the 23 named
  files appearing exactly once.

---

### Phase 3: Propagate the bullet pair into the in-scope research agents [COMPLETED]

**Goal**: every research agent the Phase 2 section records as in-scope carries both canonical
bullets verbatim, each on a single physical line; every recorded exclusion is untouched.

**Tasks**:

- [x] Copy both bullets verbatim — each on one physical line — into each in-scope file's
      `## Critical Requirements` MUST / MUST NOT lists, creating that section where absent.
      *(completed: all 10 non-general in-scope files already had a Critical Requirements MUST
      DO/MUST NOT section, so each bullet was appended as the next sequential numbered item;
      every placement spot-checked against the fragment's byte-for-byte anchors)*
- [x] For `general-research-agent.md`, place the local-wait pair alongside its existing remote-wait
      discipline section rather than replacing it; the two halves are complementary, and the
      missing local half is the exact partial-coverage shape this phase closes. *(completed: new
      "Local Wait Discipline" subsection added immediately after "External Process Wait
      Discipline", mirroring its MUST/MUST NOT bullet-list shape)*
- [x] Confirm the two Lean research agents are untouched and their `lake-build-guard.sh` routing
      text still reads intact (`grep -n lake-build-guard` on both). *(completed with a correction:
      the two Lean research agents route through the bounded single-call idiom documented in
      `context/project/lean4/operations/long-builds.md`, not a literal `lake-build-guard.sh`
      string -- `git status --porcelain` on both files confirms zero diff, i.e. genuinely
      untouched)*
- [x] Confirm by `grep -lF` for the MUST anchor across all `*research*agent.md` files that exactly
      the in-scope set carries it and no excluded file does. *(completed: `grep -lF` result is a
      byte-for-byte match against the 11-file in-scope set, no extra, no missing)*
- [x] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` and confirm it is
      clean on every changed path. *(completed: 0 unexempted occurrences via the
      `REPO_ROOT=$(pwd)` source-store invocation override, scoped to `agent-system/extensions`)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly the Phase 2 in-scope set (expected: 11 files) receives the pair and
the recorded exclusions (expected: 12 files) are untouched. The implementer confirms with a
`grep -lF` of the MUST anchor across every `*research*agent.md`, asserting the returned set equals
the in-scope array exactly — neither a superset nor a subset.

**Tier Justification**: the only executable consequence of these markdown edits is the lint's own
text match, covered by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
plus `bash agent-system/extensions/core/scripts/check-task-references.sh` over the changed paths.

**Files to modify**:

- `agent-system/extensions/books/agents/books-research-agent.md` - add the bullet pair
- `agent-system/extensions/books/agents/books-research-hard-agent.md` - add the bullet pair
- `agent-system/extensions/core/agents/general-research-agent.md` - add the local-wait pair
  alongside the existing remote-wait discipline section
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` - add the bullet pair
- `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md` - add the bullet pair
- `agent-system/extensions/nix/agents/nix-research-agent.md` - add the bullet pair
- `agent-system/extensions/nvim/agents/neovim-research-agent.md` - add the bullet pair
- `agent-system/extensions/python/agents/python-research-agent.md` - add the bullet pair
- `agent-system/extensions/rust/agents/rust-research-agent.md` - add the bullet pair
- `agent-system/extensions/web/agents/web-research-agent.md` - add the bullet pair
- `agent-system/extensions/z3/agents/z3-research-agent.md` - add the bullet pair

**Verification**:

- `grep -lF '<MUST anchor>' agent-system/extensions/*/agents/*research*agent.md` returns exactly
  the in-scope set.
- `grep -n lake-build-guard` on both Lean research agents still returns their routing text.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` is clean.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` still exits 0
  (Check M does not exist yet, so this phase's edits are additive and inert to the lint).

---

### Phase 4: Add Check M — research-agent bounded-wait bullet presence [COMPLETED]

**Goal**: the lint enforces the bullet pair on the in-scope research-agent array, structurally
identical to Check H.

**Tasks**:

- [x] Add `BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS` with the in-scope research-agent paths.
      *(completed: 11 entries, matching Phase 3's propagation set exactly)*
- [x] Add a header comment block mirroring Check H's (a)-(d) shape: curated-not-glob note, the
      recorded exclusions with their reasons, the verbatim re-audit reproduce command for the
      `*research*agent.md` glob, and the "a future addition is classified by the fragment's rule,
      this check does not infer scope" note. *(completed)*
- [x] Add `check_m_bounded_wait_research_contract_bullet`, structurally identical to
      `check_h_bounded_wait_contract_bullet`, reusing the same two fragment anchors. *(completed)*
- [x] Wire `check_m_...` into `main()` after `check_l_modified_files_bullet`. *(completed)*
- [x] Run the sanctioned shellcheck entry point (Gate 22) per
      `context/standards/shell-strict-mode.md`: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`, exit 0.
      *(completed: 0 findings across 398 files. Incidentally discovered and fixed: the new
      16-entry OWNERSHIP_IN_SCOPE_RELATIVE_PATHS from Phase 1 rippled into
      test-lint-agent-contracts-heartbeat.sh's own hardcoded 14-entry mirror of that array,
      producing 2 Check I "file not found" FAILs against that suite's fixture tree -- fixed by
      adding both books files to the mirror and updating the WARN-count expectations (13->15,
      12->14); not named in this phase's task list, recorded in the issue log)*

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Check M's array holds exactly the Phase 2 in-scope set, and the check is a
structural copy of Check H requiring no new extraction logic. The implementer confirms by diffing
`check_m_...` against `check_h_...` (expected difference: the array name, the check letter, and
the log strings only) and by the lint exiting 0 with every array entry named in a PASS line.

**Tier Justification**: the edit is confined to `lint-agent-contracts.sh`, whose covering suites
are resolved by `suite_selection_select` to the lint-agent-contracts family —
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-handoff-section.sh,test-lint-agent-contracts-heartbeat.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - new in-scope array, header
  comment block, `check_m_bounded_wait_research_contract_bullet`, `main()` wiring

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0 with
  a Check M section naming every array entry in a PASS line.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 (Gate 22's sanctioned entry point, not a bare `shellcheck` call).
- The four lint-agent-contracts suites are green under `run-all.sh --only`.

---

### Phase 5: Add the completeness net [COMPLETED]

**Goal**: a new check FAILs by name when an agent file matching the relevant glob is in neither an
in-scope array nor a recorded exclusion list — so the next drift is caught, not discovered.

**Tasks**:

- [x] Promote Check G's recorded exclusions from fragment prose into an array, the way
      `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS` already works for Check F, carrying each
      file's existing "confirmed out of scope" reason as a comment. *(completed:
      `CHECK_G_EXCLUDED_RELATIVE_PATHS`, 3 entries)*
- [x] Add the research-agent exclusion array from Phase 2, each entry carrying its inline reason.
      *(completed: `CHECK_M_EXCLUDED_RELATIVE_PATHS`, 12 entries)*
- [x] Add `check_n_curated_array_completeness`: enumerate
      `agent-system/extensions/*/agents/*implementation*agent.md` and FAIL by name any entry in
      neither `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` nor the Check-G exclusion array; apply the same
      net to Check C's `*implementation*agent.md` subset only (the subset the fragment's own rule
      makes unconditional, so a glob net is safe there without false-failing a legitimately
      excluded non-implementation agent); enumerate
      `agent-system/extensions/*/agents/*research*agent.md` and apply the same net against Check
      M's array plus its exclusion array. *(completed: three nets, 57 PASS lines total (17 + 17 +
      23), zero FAILs on first run -- every glob match was already accounted for, confirming the
      Scope Hypothesis)*
- [x] Wire `check_n_...` into `main()` after `check_m_...`. *(completed)*
- [x] Run the sanctioned shellcheck entry point: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`, exit 0.
      *(completed: 0 findings, 398 files)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the glob nets are expected to find every matching file already accounted for
once the exclusion arrays are added — i.e. Check N passes on the first run with no further
registrations needed. The implementer treats a Check N failure as new information to classify
deliberately (and to report), not as a reason to pad an exclusion array to reach green.

**Tier Justification**: the edit is confined to `lint-agent-contracts.sh`, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-handoff-section.sh,test-lint-agent-contracts-heartbeat.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - Check-G and research-agent
  exclusion arrays with per-file reasons, `check_n_curated_array_completeness`, `main()` wiring

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0 with
  a Check N section reporting every globbed file as accounted for.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 (Gate 22's sanctioned entry point, not a bare `shellcheck` call).
- The four lint-agent-contracts suites are green.

---

### Phase 6: Extend the test suite [COMPLETED]

**Goal**: fixtures pin the line-wrap ruling, Check M, and Check N, and the suite stays honestly
green — with no unexplained FAIL lines absorbed by its existing exit-1 expectation.

**Tasks**:

- [x] Add Check M fixtures mirroring Check H's existing pair: a research agent missing the bullet
      (asserted to FAIL by name) and a near-miss paraphrase (asserted to FAIL by name). Fixture
      filenames must match Check M's array entries exactly, since the check iterates curated paths
      rather than globbing. *(completed: nix-research-agent.md missing, rust-research-agent.md
      near-miss, both real BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS entries)*
- [x] Add the two line-wrap pinning fixtures: a Check C bullet and a Check G bullet, each
      correctly worded but wrapped across two physical lines, each asserted to FAIL by name —
      pinning the ruling as enforced, not merely documented. *(completed:
      python-implementation-agent.md / web-implementation-agent.md, each made otherwise fully
      compliant with every other curated check it is a real member of, so only the intended
      check's FAIL line is unexplained-free)*
- [x] Add Check N fixtures: an `*implementation*agent.md` and a `*research*agent.md` in neither
      in-scope nor exclusion array, each asserted to FAIL by name; plus one negative fixture per
      exclusion array asserted to produce no FAIL against it. *(completed: rogue-widget-
      implementation/research-agent.md positives (the implementation one asserted against BOTH
      of Check N's two nets over that glob, Check G's and Check C's), pr-review-implementation/
      research-agent.md negatives standing in for one real member of each exclusion array)*
- [x] Add assertions that scratch fixtures standing in for the two books files PASS Checks C and G
      by name (the scratch tree does not contain the real repo, so these are dedicated fixtures
      named to the real array paths). *(completed: both books fixtures also made fully compliant
      with Check H and Check L, real array memberships of theirs, producing a genuinely zero-FAIL
      fixture rather than a PASS buried among unexplained FAILs)*
- [x] Add a scratch fixture for every path newly registered in Phases 1, 4, and 5, or assert the
      `in-scope agent file not found` line explicitly for each. An unexplained FAIL line absorbed
      by the suite's "exits 1 against a fixture tree with real violations" expectation is not
      accepted as green. *(completed: Phase 1's 2 books paths got full PASS fixtures; Phase 4's
      11 research-agent paths are 2 dedicated FAIL fixtures plus 9 explicit named
      "in-scope research agent file not found" assertions; Phase 5's two exclusion arrays are
      each represented by one real member as a Check N negative fixture. Every FAIL line
      attributable to a new fixture is matched by name by an explicit assertion -- verified by a
      temporary debug capture of the full lint output, cross-referenced line by line, then
      removed before this phase closed)*
- [x] Run the sanctioned shellcheck entry point: `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`, exit 0.
      *(completed: 0 findings, 398 files)*

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the fixture count added is expected to be two for Check M, two for the
line-wrap ruling, four for Check N, two for the books PASS assertions, plus one per newly
registered path. The implementer confirms the final fixture set by counting the suite's PASS lines
before and after and reconciling the delta against this list, rather than assuming the planned
count was complete.

**Tier Justification**: the edit is confined to `test-lint-agent-contracts.sh`, whose own
execution is the covering check: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - Check M fixtures,
  two line-wrap pinning fixtures, Check N fixtures and negatives, books PASS assertions, fixtures
  or explicit not-found assertions for every newly registered path

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` reports zero
  FAILs of its own.
- Every FAIL line in the scratch lint output is matched by an explicit assertion — none left
  unaccounted for.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0.

---

### Phase 7: Removal demonstrations, sweep report, gates, redeploy [NOT STARTED]

**Goal**: each newly covered class is demonstrated to fail by name on deliberate removal and
return to exit 0 on restoration; the sweep result is reported; the full gate set is green and the
source store is redeployed.

**Tasks**:

- [ ] Demonstration A (Check C): strip the Check C bullet from
      `books-implementation-hard-agent.md`, run the lint, confirm it FAILs naming that path;
      restore; confirm exit 0.
- [ ] Demonstration B (Check G): same removal/restore cycle for the Check G bullet on
      `books-implementation-agent.md`.
- [ ] Demonstration C (Check M): same cycle for one in-scope research agent's MUST bullet.
- [ ] Demonstration D (Check N): add a throwaway `*research*agent.md` file in neither list,
      confirm Check N FAILs naming it, remove it, confirm exit 0.
- [ ] Confirm the Lean sanctioned build-guard path is unbroken: both Lean research agents still
      route through `lake-build-guard.sh`, are absent from Check M's in-scope array, and are
      present in its exclusion list with their reason.
- [ ] Report the full Check C / Check G absentee sweep result from Phase 1 in the task summary,
      including the deliberately deferred `literature/agents/literature-agent.md` edge case and
      its reason for deferral.
- [ ] Record the line-wrap ruling's outcome in the summary: convention (stated in all three
      fragments) plus fixture, not lint-side whitespace normalization — and the curated-array
      ruling: curation kept, completeness net added.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0, covering both modified shell
      scripts per `context/standards/shell-strict-mode.md`.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` clean on every changed
      `agent-system/**` path.
- [ ] Redeploy: `bash .claude/scripts/deploy-headless.sh`.
- [ ] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh`
      (all gates, including Gate 8's full `run-all.sh` suite battery) and confirm green.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: four removal demonstrations are expected to cover every newly covered class
(Check C, Check G, Check M, Check N). The implementer confirms the class list against the arrays
actually changed in Phases 1, 4, and 5 before closing, and adds a demonstration for any class
those phases introduced beyond these four.

**Files to modify**:

- `agent-system/extensions/books/agents/books-implementation-agent.md` - transient removal and
  restoration only (demonstration B); no net change
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - transient removal
  and restoration only (demonstration A); no net change
- `specs/359_close_lint_curated_array_coverage_gaps/summaries/01_close-lint-curated-array-gaps-summary.md` -
  sweep result, line-wrap ruling, curated-array ruling, demonstration outcomes

**Verification**:

- Each of the four demonstrations shows the lint FAILing by the removed file's name and returning
  to exit 0 after restoration, with the before/after exit codes recorded.
- `git status --short` shows no residual change from any demonstration — every stripped bullet is
  restored byte-for-byte.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0, covering both
  `lint-agent-contracts.sh` and `test-lint-agent-contracts.sh`.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` clean.
- `bash .claude/scripts/deploy-headless.sh` succeeds.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` — the complete gate set — exits 0.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0
      with both books files registered in Checks C and G and every Check M array entry passing.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` reports zero
      FAILs, with every scratch-lint FAIL line matched by an explicit assertion.
- [ ] The two line-wrap fixtures FAIL by name, proving the convention is enforced rather than only
      documented.
- [ ] Check N FAILs by name for an unaccounted glob match and passes once it is classified.
- [ ] All four deliberate-removal demonstrations FAIL by name and return to exit 0 on restoration.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0, covering both modified shell
      scripts.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` clean on every changed
      `agent-system/**` path.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` (complete gate set) exits 0
      after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — two books paths registered
  in Checks C and G; new research-agent in-scope array and Check M; exclusion arrays and Check N;
  `main()` wiring for both new checks.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — Check M fixtures,
  two line-wrap pinning fixtures, Check N fixtures and negatives, books PASS assertions.
- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` and
  `plan-status-ownership.md` — single-physical-line instruction; updated enumerations.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — research-agent scope
  section with per-file evidence and per-file exclusion reasons; amended Item 4 Ruling.
- Two books implementation agents with normalized bullets; the in-scope research agents carrying
  the bullet pair.
- `specs/359_close_lint_curated_array_coverage_gaps/summaries/01_close-lint-curated-array-gaps-summary.md`
  — the sweep result, both rulings, and the demonstration outcomes.
- A redeployed `.claude/` tree.

## Rollback/Contingency

All edits are confined to two shell scripts and a bounded set of markdown files under
`agent-system/extensions/**`, committed per green sub-step, so the ordinary contingency is
`git revert` of the offending commit — no working-tree discard is needed.

If a later phase reveals that an earlier registration must be undone (for example Check N
surfaces a file whose classification changes Check M's array), remove that path from the array and
re-run the lint; the normalized bullet text can stay in place harmlessly, since an unregistered
file is simply never visited by the per-file loop.

If a genuine rollback of uncommitted work becomes necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag — never a bare precautionary snapshot at the start
of a phase.
