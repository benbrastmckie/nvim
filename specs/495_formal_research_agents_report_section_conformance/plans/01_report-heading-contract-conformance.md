# Implementation Plan: Task #495

- **Task**: 495 - Formal research agents report section conformance
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/495_formal_research_agents_report_section_conformance/reports/01_formal-research-agents-report-section-conformance.md
- **Artifacts**: plans/01_report-heading-contract-conformance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The four formal-extension research agents carry a buried `### Recommendations` subsection inside
`## Findings` and zero copy of the verbatim required-heading contract that
`general-research-agent.md` gained. This plan fixes the gap by establishing ONE canonical home for
that contract in `context/formats/report-format.md` (the standard every report's own
`**Standards**:` line already cites), converting `general-research-agent.md`'s existing verbatim
copy into a pointer at it, and giving the four formal agents the same pointer plus a structural
promotion of `### Recommendations` to a top-level `## Recommendations`. A task-directory fixture
reproduces the production failure red-then-green, and a task-directory sweep harness machine-checks
every extension agent's embedded skeleton against the validator's own section arrays and regex.

### Research Integration

The report's five decisions are adopted as-is and drive the phase split:

1. **Single referenceable home** in `report-format.md` (plus the parallel six-heading statement in
   `summary-format.md`), not a fourth and fifth verbatim copy — Phase 2.
2. **Promote `### Recommendations` to `## Recommendations`** in all four formal skeletons; this is
   realignment with `general-research-agent.md`'s canonical order (Findings -> Recommendations ->
   Decisions -> Risks & Mitigations), not a divergence from it — Phase 4.
3. **A grep-based pre-return self-check stated once in the canonical contract text**, not a second
   `validate-artifact.sh` subprocess call from inside the agent (postflight already runs the
   validator on every report; the failure mode was a non-blocking warning left unactioned, not a
   missing gate) — Phase 2.
4. **The validator is NOT changed.** `REPORT_SECTIONS`, `SUMMARY_SECTIONS`, and the
   `^##+ {section}` regex are untouched; the report's fixture confirmed that any substring
   relaxation would let `## Context Extension Recommendations` satisfy a check for
   `Recommendations`, converting a true failure into a false pass.
5. **The scope-item-(4) sweep's further gap classes are recorded, not fixed here** — Phase 5.

Two additions this plan makes beyond the report, both measured during planning:

- **None of the four formal agents list `report-format.md` in their `## Context References`** (only
  `return-metadata-file.md`), unlike `general-research-agent.md` which loads it "when creating
  report". A pointer alone would therefore be unreachable, so Phase 4 adds the Context References
  entry alongside the pointer. Without this the single-home remedy would be a dead link and the
  gap would survive the fix.
- **The `formal` extension is not currently loaded in this repository** (`.claude-extensions.json`
  lists approvals, core, email, lean, literature, memory, nix, nvim, sapience — no `formal`), so
  `deploy-headless.sh` will deploy the core changes but will NOT produce a deployed
  `.claude/agents/formal-research-agent.md`. Every verification of the four formal agents must
  therefore read the source store directly; a deployed-tree check for them would silently pass on
  absent files.

### Prior Plan Reference

No prior plan for this record. The inherited diagnosis comes from abandoned project 166 (whose
agent-side remedy landed in core only) and the shape to follow for any further gap comes from
completed project 137 (which gave the lean research/implementation agents their skeletons); both
are referenced through the research report rather than re-derived here.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; `specs/ROADMAP.md` was not
consulted and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- One canonical, referenceable statement of the required-heading contract in
  `context/formats/report-format.md`, with the parallel statement in `summary-format.md`.
- `general-research-agent.md`'s verbatim block converted to a pointer, so no two copies can diverge.
- All four formal research agents carry a reachable pointer (Context References entry + skeleton-site
  sentence) and a top-level `## Recommendations` heading.
- The exact production failure reproduced in a fixture, shown red before the remedy and green after.
- The scope-item-(4) cross-extension enumeration recorded with remaining gaps listed as follow-ups.
- `## Context Extension Recommendations` preserved as a distinct, useful section everywhere it exists.

**Non-Goals**:
- Any change to `validate-artifact.sh` (its arrays, its regex, its exit behavior). Explicitly
  forbidden by the dispatch and re-confirmed by the research fixture.
- Any change to `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — sibling
  task 464 holds that file this cycle; the fixture lives in this task's own directory instead.
- Fixing the gaps the sweep found in other extensions (nix/nvim/web implementation agents,
  web-research-agent, the founder/present/epi domain-shaped agents, the seven skeleton-less research
  agents). Listed as follow-ups in Phase 5; a fix for any of them requires its own record with its
  own widened `file_scope`.
- Backfilling pre-existing non-conforming artifacts authored before their agent gained a conforming
  contract (out of scope per the dispatch, and per project 166's own ruling).
- A new permanent script in `core/scripts/`. See Phase 1's decision note for why the sweep harness
  stays in the task directory.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Converting `general-research-agent.md`'s verbatim block to a pointer removes text that demonstrably survived in production, weakening a working agent | H | M | That agent already loads `report-format.md` conditionally "when creating report" — exactly when the contract is needed. Phase 3 verifies the Context References entry is present BEFORE deleting the block, and the pointer names the exact file and section heading. |
| The four formal agents never load `report-format.md`, so a pointer-only remedy is a dead link | H | H (confirmed, not hypothetical) | Phase 4 adds the `@.claude/context/formats/report-format.md` Context References entry to each of the four as a required sub-step, verified by grep per file before the phase closes. |
| Promoting `### Recommendations` changes the report shape a downstream consumer may parse | M | L | No formal agent's `Copy source` language commits any consumer to parsing nested Findings structure; the move changes heading level and position only, not content. Fixture-verified to validate both before and after. |
| Sibling task 464 is editing `validate-artifact.sh` and `test-validate-artifact.sh` on this same tree this cycle | M | H | Treat an unexpected `test-validate-artifact.sh` failure as possibly 464's in-flight edit, not this task's regression; re-read before any edit; stage only this task's own files; never run `git-snapshot.sh` in its reverting default mode. Both plans declare `__WHOLE_TREE__`, which serializes the two redeploys by design. |
| `formal` is not a loaded extension here, so a deployed-tree check of the four agents passes vacuously | M | M | Every formal-agent verification in Phases 1, 4 and 5 reads `agent-system/extensions/formal/agents/*.md` directly and asserts a non-zero file count before asserting conformance. |
| Record-versioning or task-reference lint failures on the new prose landing under `agent-system/**` | L | M | The new contract text names headings, a regex, and two near-miss heading strings — no task numbers, no draft-history framing. Gate 4 (task-reference lint) and gate 3 (doc-lint) run in Phases 2-4 and again in full in Phase 5. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Reproduce the Failure and Build the Sweep Harness [NOT STARTED]

**Goal**: Establish the RED baseline required by the acceptance criteria — a fixture carrying the
production failure's exact shape fails `validate-artifact.sh` — and build the machine-check harness
that Phases 4 and 5 use for every conformance assertion, so no conformance claim in this task is
ever made by eye.

**Decision recorded in this phase (do not silently revisit)**: the fixture and harness live in this
task's own directory, NOT as a new permanent `core/scripts/` script and NOT as a case appended to
`test-validate-artifact.sh`. Two reasons: sibling task 464 holds `test-validate-artifact.sh` this
cycle, and a new permanent script carries script-inventory and own-test-suite obligations that this
record does not declare. The durable-script option is listed as a Phase 5 follow-up, not taken here.

**Tasks**:
- [ ] `mkdir -p specs/495_formal_research_agents_report_section_conformance/fixtures`
- [ ] Write `fixtures/report-near-miss.md`: a complete report carrying every other required heading
      (`## Executive Summary`, `## Context & Scope`, `## Findings`, `## Decisions`) plus
      `## Context Extension Recommendations` AND `## Recommended Next Steps`, and NO
      `## Recommendations` / `### Recommendations` anywhere. This is the BimodalLogic shape.
- [ ] Write `fixtures/report-nested-ok.md`: the same document with `### Recommendations` nested under
      `## Findings` (formal's current shape).
- [ ] Write `fixtures/report-toplevel-ok.md`: the same document with a top-level `## Recommendations`
      (formal's post-remedy shape).
- [ ] Run the real validator against all three, capturing output to a file and grepping that file:
      `bash agent-system/extensions/core/scripts/validate-artifact.sh <fixture> report`. Confirm
      near-miss emits `Missing required section: ## Recommendations` and fails; both others pass.
- [ ] Write `fixtures/sweep-skeletons.sh` (or `.py`): extracts each fenced block from every
      `agent-system/extensions/*/agents/*.md` using a LINE-BASED fence parser (per the research
      report's Appendix, a `` ```lang ... ``` `` regex mis-pairs fences in these files and silently
      merges blocks), classifies a block as report or summary by its `# ...Report`/`# ...Summary`
      first line, and checks it with the validator's own `^##+ {section}` regex against the arrays
      read live out of `validate-artifact.sh` — never hardcoded copies of those arrays.
- [ ] Run the harness; capture the baseline to `fixtures/sweep-baseline.txt`. Confirm it reproduces
      the research report's enumeration (the four formal agents PASS as written; the four
      nix/nvim/web gaps and the domain-shaped/skeleton-less classes appear).
- [ ] Record an issue-log entry (`issue-record.sh`, non-fatal) for anything that deviated from the
      research report's measured baseline, or a `win` entry if the harness reproduced it exactly.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: Every path this phase writes lies under `specs/**` with no executable
surface in the repository corpus, so `suite_selection_select` returns `__FULL_SWEEP__` and no suite
covers it (plan-format.md's `__FULL_SWEEP__` sub-case (a)); the honest covering check is
`bash agent-system/extensions/core/scripts/validate-artifact.sh <fixture> report` run against each
of the three fixtures, which is this phase's whole deliverable.

**Scope Hypothesis**: The harness is expected to reproduce the research report's enumeration
exactly — four formal agents passing, four confirmed small gaps (`nix-implementation-agent.md`,
`neovim-implementation-agent.md`, `web-implementation-agent.md` summaries;
`web-research-agent.md` report), plus the eleven domain-shaped and seven skeleton-less agents. Any
divergence from that baseline is confirmed by re-running the real `validate-artifact.sh` binary
against the extracted block before the harness's own verdict is trusted; a harness/validator
disagreement is a harness bug, not a new finding.

**Files to modify**:
- `specs/495_formal_research_agents_report_section_conformance/fixtures/report-near-miss.md` - new; the RED fixture
- `specs/495_formal_research_agents_report_section_conformance/fixtures/report-nested-ok.md` - new; current-shape control
- `specs/495_formal_research_agents_report_section_conformance/fixtures/report-toplevel-ok.md` - new; post-remedy control
- `specs/495_formal_research_agents_report_section_conformance/fixtures/sweep-skeletons.sh` - new; the machine-check harness
- `specs/495_formal_research_agents_report_section_conformance/fixtures/sweep-baseline.txt` - new; captured baseline output

**Verification**:
- `validate-artifact.sh fixtures/report-near-miss.md report` exits non-zero and its captured output
  contains `Missing required section: ## Recommendations`.
- `validate-artifact.sh` on both `-ok.md` fixtures exits zero.
- The harness, run with no arguments, prints a per-agent PASS/FAIL line for at least 30 agent files
  and asserts a non-zero count of `agent-system/extensions/formal/agents/*.md` inputs before
  reporting any formal verdict.
- `fixtures/sweep-baseline.txt` exists, is non-empty, and its formal-extension lines all read PASS.

---

### Phase 2: Establish the Canonical Contract in the Format Standards [NOT STARTED]

**Goal**: Put the verbatim required-heading contract, the matching-rule statement, both named
near-misses, and the pre-return grep self-check into `context/formats/report-format.md` as the ONE
place they live, with the parallel six-heading statement in `summary-format.md`.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/formats/report-format.md` immediately before
      editing (sibling task 464 is live on this tree and holds `plan-format.md` in the same directory).
- [ ] Add a new section to `report-format.md` — heading `## Required Section Headings (verbatim)`,
      placed immediately after `## Structure` so it reads as that list's enforcement counterpart —
      containing: the five headings written out literally (`## Executive Summary`,
      `## Context & Scope`, `## Findings`, `## Decisions`, `## Recommendations`); the statement that
      `validate-artifact.sh` matches each with the any-depth heading-prefix regex `^##+ {section}`,
      which is exact-text and not fuzzy; the statement that a heading merely discussing the same
      topic in different wording does not satisfy the check; both observed near-misses named
      outright (`## Recommended Next Steps` and `## Context Extension Recommendations`) with the
      explicit instruction to keep the latter as a distinct section but never as a substitute.
- [ ] Add the pre-return self-check to that same new section: before finalizing a report, grep the
      written file once per required heading (`grep -qE "^##+ <section>" <path>`) and add any missing
      heading before proceeding to the metadata-file stage — stated as an action to take, not a
      passive warning, since the observed production failure was a non-blocking warning left
      unactioned.
- [ ] State in that section that the five headings and the regex are read from
      `validate-artifact.sh`'s `REPORT_SECTIONS` array and its own check loop, and that this section
      is the single home other agents point at rather than copy.
- [ ] Add the parallel section to `agent-system/extensions/core/context/formats/summary-format.md`
      — heading `## Required Section Headings (verbatim)` — naming the six
      `SUMMARY_SECTIONS` headings (`## Overview`, `## What Changed`, `## Decisions`, `## Impacts`,
      `## Follow-ups`, `## References`), the same regex statement, and the same self-check. Keep that
      file's existing required-minimum-not-whitelist paragraph and its `## Plan Deviations` optional
      section intact.
- [ ] Confirm no task-number reference and no record-versioning phrasing entered either file (the new
      text names headings, a regex, and two heading strings only).
- [ ] Record an issue-log entry for any deviation, blocker, or notably smooth result.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Both touched paths are pure-guidance markdown in the core source store with
no executable surface, so `suite_selection_select` returns `__FULL_SWEEP__` and no suite covers
them (plan-format.md's `__FULL_SWEEP__` sub-case (b)); the honest covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(repository root as `TARGET`, since it holds both a deployed `.claude/` tree and the
`agent-system/extensions` source store), plus the `local` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/formats/report-format.md` - add `## Required Section Headings (verbatim)` after `## Structure`: five literal headings, the `^##+ {section}` exact-text rule, both named near-misses, the pre-return grep self-check
- `agent-system/extensions/core/context/formats/summary-format.md` - add the parallel section naming the six summary headings, same regex rule, same self-check

**Verification**:
- `grep -c 'Recommended Next Steps' agent-system/extensions/core/context/formats/report-format.md`
  is at least 1, and `grep -q '\^##+' report-format.md` succeeds.
- All five `REPORT_SECTIONS` strings and all six `SUMMARY_SECTIONS` strings appear literally in
  their respective new sections — checked by a loop reading the arrays out of
  `validate-artifact.sh`, not a hand-typed list.
- `verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` reports neither gate SKIPped and both
  pass (a selection whose every gate SKIPs attests to nothing).
- `bash agent-system/extensions/core/scripts/check-task-references.sh` and
  `check-record-versioning.sh` are clean for both touched files.

---

### Phase 3: Convert the Core Agent's Verbatim Copy to a Pointer [NOT STARTED]

**Goal**: Remove the second copy of the contract so the two cannot diverge, leaving
`general-research-agent.md` with a short pointer at the canonical section Phase 2 created.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/agents/general-research-agent.md` immediately before
      editing.
- [ ] Verify FIRST that its `## Context References` already carries
      `@.claude/context/formats/report-format.md` with a "when creating report" load condition. If
      it does not, add it before touching the block — the pointer must not be able to become a dead
      link.
- [ ] Replace the verbatim contract paragraph that follows the Stage 6 skeleton fence (the block
      beginning `**The five required section headings above are verbatim and non-paraphrasable**`)
      with a two-to-three sentence pointer naming the file and the exact section heading
      (`context/formats/report-format.md`'s `## Required Section Headings (verbatim)`), stating that
      the five headings are exact-text and non-paraphrasable and that the pre-return self-check is
      defined there.
- [ ] Leave the Stage 6 skeleton fence itself untouched, including its top-level `## Recommendations`
      and its `## Context Extension Recommendations`.
- [ ] Run the extraction harness from Phase 1 against this file to confirm the skeleton still
      machine-checks PASS after the edit.
- [ ] Record an issue-log entry for any deviation or blocker.

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to one pure-guidance markdown file in the core source
store with no executable surface, so `suite_selection_select` returns `__FULL_SWEEP__`
(plan-format.md's `__FULL_SWEEP__` sub-case (b)); the honest covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the Phase 1 harness re-run on this one file.

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md` - replace the verbatim contract paragraph after the Stage 6 skeleton with a pointer at `report-format.md`'s new section; add or confirm the `report-format.md` Context References entry; skeleton fence unchanged

**Verification**:
- The file contains exactly one reference to `Required Section Headings (verbatim)` and no longer
  contains the sentence `matches each with an any-depth heading-prefix regex` (the moved text).
- `grep -q 'context/formats/report-format.md' <file>` succeeds in the `## Context References` block.
- The Phase 1 harness reports PASS for this file's report skeleton (the top-level
  `## Recommendations` and `## Context Extension Recommendations` both still present).
- `verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` passes with neither gate SKIPped.

---

### Phase 4: Remediate the Four Formal Research Agents [NOT STARTED]

**Goal**: Give each of the four formal research agents a reachable pointer at the canonical contract
and a top-level `## Recommendations` in its embedded skeleton, removing contributing factor (a)
structurally rather than by instruction-following.

**Tasks**:
- [ ] For each of `formal-research-agent.md`, `logic-research-agent.md`, `math-research-agent.md`,
      `physics-research-agent.md` under `agent-system/extensions/formal/agents/`, re-read the file
      immediately before editing it, then apply all three edits below to that file before moving to
      the next (one file fully done per sub-step, each committed on green).
- [ ] Edit (a) — Context References: add `@.claude/context/formats/report-format.md` with a
      "when creating report" load condition, beside the existing `return-metadata-file.md` entry.
      This is the load path that makes edit (b) reachable; without it the pointer is a dead link.
- [ ] Edit (b) — pointer: immediately after the skeleton's closing fence and before/beside the
      existing `**Copy source**:` note, add a short pointer at
      `context/formats/report-format.md`'s `## Required Section Headings (verbatim)`, stating that
      the five headings are exact-text and non-paraphrasable and that the pre-return self-check is
      defined there. Do not restate the contract's body — a fifth copy is the mechanism that
      produced this gap.
- [ ] Edit (c) — promotion: remove the `### Recommendations` subsection from inside the skeleton's
      `## Findings` block and insert it as a top-level `## Recommendations` between the end of
      `## Findings` and `## Decisions`, matching `general-research-agent.md`'s canonical order
      (Findings -> Recommendations -> Decisions -> Risks & Mitigations). Leave
      `### Cross-Domain Synthesis` and every per-domain `### {Domain N} Findings` subsection in place
      and unchanged.
- [ ] Keep each file's `**Copy source**:` note accurate: it names `general-research-agent.md`'s
      Stage 6 as the canonical shape, which remains true after Phase 3's pointer conversion.
- [ ] Run the Phase 1 harness restricted to `agent-system/extensions/formal/agents/`; confirm four
      inputs were found and all four report PASS.
- [ ] Extract each of the four skeletons verbatim to a temporary file and run the real
      `bash agent-system/extensions/core/scripts/validate-artifact.sh <extracted> report` on each,
      so the acceptance claim rests on the validator binary and not only on the harness's regex
      re-implementation.
- [ ] Record an issue-log entry per deviation, blocker or notable win as it arises.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: The pointer added here resolves against the section Phase 2 created in a
different file, so the edit spans a producer/consumer pair across files — the enumerated one-hop
dependent set is `report-format.md` plus the four agent files, and the covering check is the
Phase 1 harness run over `agent-system/extensions/formal/agents/*.md` together with
`bash agent-system/extensions/core/scripts/validate-artifact.sh <extracted-skeleton> report` on each
of the four extracted skeletons.

**Scope Hypothesis**: Each of the four files is expected to contain exactly ONE occurrence of the
string `Recommendations` before the edit (the buried `### Recommendations`) and ZERO occurrences of
`validate-artifact`. Confirm per file with `grep -c` immediately before editing it; a count other
than 1 and 0 means the file diverged from the measured baseline and the edit must be re-derived for
that file rather than applied blind.

**Files to modify**:
- `agent-system/extensions/formal/agents/formal-research-agent.md` - Context References entry; pointer at the canonical section; `### Recommendations` promoted to top-level `## Recommendations` before `## Decisions`
- `agent-system/extensions/formal/agents/logic-research-agent.md` - same three edits
- `agent-system/extensions/formal/agents/math-research-agent.md` - same three edits
- `agent-system/extensions/formal/agents/physics-research-agent.md` - same three edits

**Verification**:
- Per file: `grep -c '^## Recommendations' <file>` is 1 and `grep -c '^### Recommendations' <file>`
  is 0.
- Per file: `grep -q 'context/formats/report-format.md' <file>` succeeds in the
  `## Context References` block, and the file references
  `Required Section Headings (verbatim)` exactly once.
- Per file: `grep -q '### Cross-Domain Synthesis' <file>` still succeeds (the per-domain structure
  was not collapsed by the promotion).
- The Phase 1 harness asserts four formal inputs found and reports PASS for all four.
- `validate-artifact.sh <extracted-skeleton> report` exits zero for each of the four extracted
  skeletons.

---

### Phase 5: Redeploy, Full Gate Verification, and Record the Sweep [NOT STARTED]

**Goal**: Regenerate the deployed tree, run the complete gate set, re-run the fixture and sweep to
confirm red-to-green and no regression, and record the scope-item-(4) enumeration with its remaining
gaps listed as follow-ups.

**Tasks**:
- [ ] Re-read every file this task touched, confirming no sibling edit landed on top of it
      (`git log` and `git status --short` on each path; a foreign commit or foreign modification in
      this task's paths is a STOP-and-report condition, not noise to dismiss).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` in the foreground with a bounded timeout,
      redirecting output to a file, then grep that file for its own success line. Do NOT end the
      dispatch awaiting a background job.
- [ ] Confirm the deployed `.claude/context/formats/report-format.md` and
      `.claude/context/formats/summary-format.md` carry the new section, and that the deployed
      `.claude/agents/general-research-agent.md` carries the pointer.
- [ ] Record explicitly in the summary that the four formal agents have NO deployed counterpart in
      this repository (the `formal` extension is not in `.claude-extensions.json`), so their
      conformance evidence is the source-store check from Phase 4, not a deployed-tree check.
- [ ] Re-run all three Phase 1 fixtures through `validate-artifact.sh`: the near-miss fixture must
      STILL fail (the validator was not weakened) and both `-ok` fixtures must still pass. A
      near-miss fixture that now passes means the validator was changed and is a hard failure of
      this task.
- [ ] Re-run the Phase 1 harness in full; diff against `fixtures/sweep-baseline.txt`. The only
      expected deltas are the four formal agents (unchanged PASS, now with the pointer) and
      `general-research-agent.md` (unchanged PASS).
- [ ] Run the complete gate set in the foreground with a bounded timeout, output to a file, then grep
      that file: `bash .claude/scripts/verify-deploy.sh` for the full battery (including Gate 8's
      shell-suite run via `agent-system/extensions/core/scripts/tests/run-all.sh`). Treat a failure
      in `test-validate-artifact.sh` or any `plan-format.md`-related suite as possibly sibling task
      464's in-flight edit — check `git log` to confirm the work is not this task's before
      attributing it.
- [ ] Record the scope-item-(4) enumeration in the implementation summary's `## Follow-ups`: (a) the
      four confirmed small gaps — `nix-implementation-agent.md`, `neovim-implementation-agent.md`,
      `web-implementation-agent.md` (summary: missing Impacts, Follow-ups, References) and
      `web-research-agent.md` (report: missing Context & Scope); (b) the eleven domain-shaped
      report/summary agents across the founder, present and epidemiology extensions; (c) the seven
      research agents carrying no embedded skeleton at all (typst, z3, books, latex, python, rust,
      cslib); (d) the optional promotion of this task's sweep harness into a permanent core script
      with its own suite. Each needs its own record with its own widened `file_scope`.
- [ ] Record in the summary's `## Decisions` why `validate-artifact.sh` was NOT changed: a substring
      relaxation would let `## Context Extension Recommendations` satisfy a check for
      `Recommendations`, converting the real production failure into a silent false pass.
- [ ] Record a final issue-log entry, or attest explicitly in the handoff that nothing further arose.

**Timing**: 45 minutes

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree, an implicit scope claim over it
- `specs/495_formal_research_agents_report_section_conformance/summaries/01_report-heading-contract-conformance-summary.md` - new; carries the scope-item-(4) enumeration, the follow-up list, and the ruling on why the validator was not changed

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, no `--skip-slow`, no `--only-gate`)
  passes; its captured output is grepped for the per-gate verdicts, and Gate 8's shell-suite battery
  is green or every failure is attributed by `git log` to a sibling task's in-flight edit rather than
  to this task.
- `validate-artifact.sh fixtures/report-near-miss.md report` still exits non-zero with
  `Missing required section: ## Recommendations` — the validator was not weakened to make this task
  green.
- `validate-artifact.sh` on both `-ok` fixtures exits zero.
- The Phase 1 harness reports PASS for all four formal agents and for
  `general-research-agent.md`, with no new FAIL relative to `fixtures/sweep-baseline.txt`.
- The deployed `.claude/context/formats/report-format.md` contains
  `## Required Section Headings (verbatim)`.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` and
  `check-record-versioning.sh` are clean across every file this task wrote under `agent-system/**`.
- `validate-artifact.sh <summary path> summary` exits zero for the implementation summary.

---

## Testing & Validation

- [ ] The near-miss fixture fails `validate-artifact.sh` with exactly
      `Missing required section: ## Recommendations` before the remedy and still fails after it
      (proving the validator was not relaxed).
- [ ] Both control fixtures (nested `### Recommendations`, top-level `## Recommendations`) pass.
- [ ] All four formal research agents' extracted skeletons pass the real `validate-artifact.sh`
      binary, with a non-zero input count asserted first.
- [ ] Each of the four formal agents has exactly one `^## Recommendations` and zero
      `^### Recommendations`.
- [ ] Each of the four formal agents loads `report-format.md` via `## Context References` and points
      at its `## Required Section Headings (verbatim)` section exactly once.
- [ ] `general-research-agent.md`'s skeleton still passes and its contract text exists only as a
      pointer (no second copy).
- [ ] `## Context Extension Recommendations` survives as a distinct section in
      `general-research-agent.md` and in `report-format.md`'s own example skeleton.
- [ ] The full gate set passes after redeploy, with any failure attributed by `git log` to a sibling
      rather than to this task.
- [ ] The scope-item-(4) enumeration and the four follow-up groups are recorded in the summary.

## Artifacts & Outputs

- `specs/495_formal_research_agents_report_section_conformance/plans/01_report-heading-contract-conformance.md` (this plan)
- `specs/495_formal_research_agents_report_section_conformance/fixtures/` — three fixtures, the sweep harness, the captured baseline
- `specs/495_formal_research_agents_report_section_conformance/summaries/01_report-heading-contract-conformance-summary.md`
- `agent-system/extensions/core/context/formats/report-format.md` (new canonical contract section)
- `agent-system/extensions/core/context/formats/summary-format.md` (parallel section)
- `agent-system/extensions/core/agents/general-research-agent.md` (verbatim copy -> pointer)
- `agent-system/extensions/formal/agents/{formal,logic,math,physics}-research-agent.md`
- Regenerated `.claude/` deploy tree (core changes only; `formal` is not a loaded extension here)
- Issue-log entries in `specs/495_formal_research_agents_report_section_conformance/issues.jsonl`

## Rollback/Contingency

Every phase is a separate commit scoped to its own explicit file list, so a single `git revert` of a
phase commit undoes that phase without touching the others. Phase ordering is chosen so the risky
deletion (Phase 3's removal of working contract text) happens only after its replacement exists and
is reachable — if Phase 3 proves wrong, reverting it alone restores the verbatim block while leaving
the canonical section and the formal-agent pointers in place, which is a coherent two-copy state
rather than a broken one.

If a redeploy in Phase 5 produces a broken tree, re-run `deploy-headless.sh` (non-destructive
resync) before considering `--wipe`; a wipe is not warranted by a markdown-only change set. Because
a sibling task is live on this tree, any rollback that would discard uncommitted work must be
preceded by `bash .claude/scripts/git-snapshot.sh 495 --no-revert` — never the reverting default
form, which would revert the sibling's in-flight edits along with this task's.
