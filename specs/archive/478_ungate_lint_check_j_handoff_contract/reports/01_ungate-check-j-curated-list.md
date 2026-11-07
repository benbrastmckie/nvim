# Research Report: Task #478

**Task**: 478 - lint-agent-contracts.sh Check J is content-gated: it only scans agent files that
ALREADY mention .orchestrator-handoff.json. Replace the content gate with a curated in-scope
list, so that removal is detected.
**Started**: 2026-11-06T18:53:00Z
**Completed**: 2026-11-06T19:40:00Z
**Effort**: ~1.5 hours (research only)
**Dependencies**: None
**Sources/Inputs**: `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`,
`agent-system/extensions/core/docs/architecture/handoff-schema.md`,
`agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`,
archived task 212 and 359 artifacts, `specs/CHANGE_LOG.md`, direct mechanical probe of all 81
dispatchable agent files.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Check J's content gate is one line: `grep -qF '.orchestrator-handoff.json' "$f" || continue`
  at `lint-agent-contracts.sh:899`. Removing the entire handoff-writing section from an agent
  file (which also removes the only occurrence of that literal string) makes the file silently
  drop out of Check J's loop entirely — the exact hole the task describes.
- The correct in-scope criterion, confirmed by direct mechanical measurement against all 81
  dispatchable agent files, is almost universal: **every dispatchable agent EXCEPT (a) research
  agents, which correctly carry a documented "never write one" contract, and (b) a small,
  already-identifiable set of 8 agents that are invoked only via the forked-subagent pattern
  from within another skill/agent and never reach a `skill-orchestrate` `dispatch[]`/
  `aux_dispatch[]` row at all.**
- This repo has two sibling flavors of curated-array lint, not one: an INCLUDED-style (Checks
  C/G/H/M: a small hand-picked subset of a large population) and an EXCLUDED-style (Checks E/F:
  almost the whole population, minus a few named exceptions). Check J's scope shape matches the
  EXCLUDED-style precedent, not the INCLUDED-style one — this is the convention to match, and
  the choice is justified by the measured shape (44 writers vs. 8 exclusions), not by preference.
- The fix requires **no new completeness-net check** (unlike Checks C/G/M's bolted-on Check N):
  iterating `enumerate_dispatchable_agents()` directly and failing by default on anything not in
  the small exclusion array makes a future qualifying-but-unregistered agent **fail loud by
  construction**, which is the opposite (and safer) failure direction from Check N's own
  INCLUDED-style completeness net.
- An earlier, directly-adjacent idea — "replace `is_contractual_handoff_writer()` with a
  dispatch-derived predicate" — was pursued and **completed**, not abandoned on merit, via
  archived task 212, for a *different* file (`orchestrate-cycle-postflight.sh`, a runtime
  script with a live dispatch row to derive from). That reasoning does not transfer to Check J:
  `lint-agent-contracts.sh` is a static lint over markdown files with no dispatch context at
  lint time, so "dispatch-derived" is a category error here — the correct analog is a
  role/filename-derived classification, which is exactly the curated-array convention already in
  the file.
- Current baseline is fully green: `lint-agent-contracts.sh` 421 passed / 15 advisory warnings
  (Check I only) / 0 failed; all four named sibling suites (`test-lint-agent-contracts.sh` 61/61,
  `test-lint-agent-contracts-await-notification.sh` 6/6, `test-lint-agent-contracts-heartbeat.sh`
  6/6, `test-lint-agent-contracts-handoff-section.sh` 6/6) pass. Zero files are currently
  misclassified — this is a pure drift-closing fix, not a pre-existing-bug fix.

## Context & Scope

Researched: the shape of Check J's content gate, the full population of dispatchable agent
files and how each one currently resolves under Check J's existing section-locating logic, the
established curated-array conventions already present in `lint-agent-contracts.sh` (Checks
C/E/F/G/H/I/M/N), the documented authority for "which agents are contractual handoff writers"
(`docs/architecture/handoff-schema.md`'s "Handoff Writers" table), the history and actual
disposition of the "replace the allowlist with a dispatch-derived predicate" idea named in the
dispatch, the directly-named prior art (archived task 359, open record 418), and the existing
fixture suite's structure (`test-lint-agent-contracts-handoff-section.sh`).

Not researched (left for plan/implement): the exact final wording of new comments/array
entries, the precise diff to `check_j_handoff_section_artifacts()`, and the new fixture cases'
literal file contents — these are implementation-shaped decisions the plan phase should make
against the criterion and precedent established below.

## Findings

### The current content gate and why it is a hole, precisely

`agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh:892-926`
(`check_j_handoff_section_artifacts()`) loops over `enumerate_dispatchable_agents()` but
immediately `continue`s past any file for which
`grep -qF '.orchestrator-handoff.json' "$f"` is false (line 899). The section-locating helper,
`_check_j_locate_handoff_section()` (lines 842-872), already distinguishes three cases
correctly *once it is reached*:

- returns 0 — a writer heading (`` `.orchestrator-handoff.json` `` or `Wrap-Up`) found; check
  the artifacts requirement in its bounded window.
- returns 2 — the matching heading contains "never write one"; skip (research-agent non-writer
  contract).
- returns 1 — no heading matching either recognized form; FAIL as heading drift.

The bug is structural, not in this helper: a file that **removes the entire handoff-writing
section** (heading and body) also removes the only occurrence of the literal string
`.orchestrator-handoff.json`, so it never reaches `_check_j_locate_handoff_section()` at all —
it is skipped at line 899 before the helper's own, already-correct "no heading found" FAIL
branch would ever fire. Check J currently can only detect *degradation* of an existing section
(wrong heading, missing `artifacts` key), never *removal* of the section altogether. This is
exactly task 378's logged Non-Goal (citation `iss_1793813461325_LTteRB`), and this task is its
scheduled follow-on.

### Outcome 1 — the in-scope criterion, measured directly

The dispatch directs deriving the criterion from "an agent that writes, or is contractually
expected to write, `.orchestrator-handoff.json`" — not from current content. The authoritative
statement of this exists already: `docs/architecture/handoff-schema.md`'s "Handoff Writers —
the settled decision, in one place" section (lines 470-499) states writers are **every
`*-implementation-agent`/`*-implement-agent` plus the plan phase's resolved agent
(`planner-agent` or `reviser-agent`), across every extension**, active whenever the delegation
context carries `orchestrator_mode: true`; research agents never write one, in any mode, by
design.

To confirm this table is complete and current (rather than trust it blindly — the dispatch
explicitly warns against trusting a stated scope uncritically), I extracted
`_check_j_locate_handoff_section()`'s exact logic into a standalone probe and ran it against
every one of the 81 files `enumerate_dispatchable_agents()` currently returns (every
`agents/*.md` file with a `---`-fenced frontmatter block containing `name:`). Results:

- **44 files**: `WRITER_HEADING_FOUND` — carry a recognized writer heading today. This set is
  *larger* than "implementation/implement agents + planner + reviser" (21 files): it also
  includes every `founder/agents/*.md` and `present/agents/*.md` per-task-type terminal worker
  agent (`finance-agent`, `legal-council-agent`, `market-agent`, `strategy-agent`,
  `deck-builder-agent`, `meeting-agent`, `analyze-agent`, `project-agent`,
  `financial-analysis-agent`, `legal-analysis-agent`, `founder-plan-agent`,
  `founder-spreadsheet-agent`, `deck-planner-agent`, `budget-agent`, `funds-agent`,
  `grant-agent`, `slide-planner-agent`, `slidev-assembly-agent`, `timeline-agent`), plus every
  `filetypes/agents/*.md` agent EXCEPT `document-agent.md` (`docx-edit-agent`,
  `filetypes-router-agent`, `filetypes-spreadsheet-agent`, `presentation-agent`, `scrape-agent`,
  `sheet-agent`). **The handoff-schema.md table documents the core 3-phase lifecycle; founder
  and present route many additional per-task-type terminal/plan agents through their own
  `dispatch[]` rows under `orchestrator_mode`, and these already correctly carry the identical
  canonical writer section.** This is real, verified scope — not a hypothesis — and the plan
  phase should treat the true in-scope set as "every writer-shaped agent today," not merely the
  21-file subset the architecture doc names by role.
- **23 files**: `NEVER_WRITE_ONE` — every one of these is a `*research*agent.md` file (23 of 23;
  zero exceptions found), consistent with the documented "research agents never write, by
  design" rule. This subset needs no new exclusion-array entry: it already resolves correctly
  via the existing return-2 branch, because the string IS present (inside the contract's own
  "never write one" explanation) even though no actual write ever happens.
- **8 files**: `NO_HEADING_AT_ALL` — zero occurrences of the string anywhere:
  `core/agents/code-reviewer-agent.md`, `core/agents/meta-builder-agent.md`,
  `core/agents/spawn-agent.md`, `cslib/agents/cslib-vet-agent.md`,
  `filetypes/agents/document-agent.md`, `literature/agents/literature-agent.md`,
  `present/agents/pptx-assembly-agent.md`, `present/agents/slide-critic-agent.md`. Each was
  individually verified (not assumed) to be invoked only via the **forked-subagent pattern**
  from inside another skill or agent — e.g. `document-agent.md`'s own Overview: "Invoked by
  `filetypes-router-agent` or `skill-filetypes` via the forked subagent pattern";
  `meta-builder-agent.md`: "Invoked by `skill-meta` via the forked subagent pattern." None of
  these 8 is ever reached through `skill-orchestrate`'s `dispatch[]`/`aux_dispatch[]` rows, so
  `orchestrator_mode` never applies to them and the handoff obligation genuinely never arises —
  this is a confirmed, correct non-applicability, not a latent bug. (Three of these eight —
  `code-reviewer-agent.md` and `literature-agent.md` for Check F, plus `meta-builder-agent.md`
  for Check E — are already independently recorded as non-standard-metadata-vocabulary agents
  in this same script's existing exclusion arrays, corroborating the classification from a
  second angle.)

**Zero files were found misclassified under either the old or the new criterion.** Every one of
the 81 files resolves cleanly into exactly one of the three buckets above, and every bucket's
membership was independently justified (not merely counted). This means outcome 5's case (b) —
"a curated file WITHOUT the section FAILS" — will need a deliberately-constructed throwaway
fixture (mirroring Check N's own "Demonstration D" throwaway-file precedent in task 359), not a
pre-existing real gap, and `reviser-agent.md` (named explicitly in the dispatch) is already in
the 44-file writer set "by construction," confirming the dispatch's own framing.

### Outcome 2 — where the list lives, and which convention it matches

`lint-agent-contracts.sh` already contains **two distinct flavors** of curated-array lint, and
the dispatch asks specifically to name which one is matched, not merely that "a curated array"
is used:

| Flavor | Shape | Examples | Array location |
|---|---|---|---|
| **INCLUDED-style** | a small, hand-picked subset of a much larger population, requiring a human judgment call per file | Check C `IN_SCOPE_RELATIVE_PATHS` (31 files, deliverable-file authors), Check G `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` (16 files, phase-heading owners), Check H `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` (16 files), Check M `BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS` (11 of 23 research agents) | literal bash array inside `lint-agent-contracts.sh` |
| **EXCLUDED-style** | almost the entire population is in scope; a short, independently-justified array names the few genuine exceptions | Check F `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS` (2 files), Check E `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS` (5 files), Check N's own `CHECK_G_EXCLUDED_RELATIVE_PATHS` (3 files) and `CHECK_M_EXCLUDED_RELATIVE_PATHS` (12 files) | same: literal bash array inside `lint-agent-contracts.sh` |

Both flavors are declared as literal bash arrays **inside `lint-agent-contracts.sh` itself** —
there is no precedent anywhere in this file (or elsewhere in the lint family, as far as this
research covered) for a frontmatter-declared opt-in or a separate registry file. That settles
the "where" question unambiguously: a new literal array in `lint-agent-contracts.sh`, following
the file's own established location pattern (declared immediately above the check function that
consumes it, with a header comment documenting the derivation criterion and a reproduce
command — every existing array does this).

Given the measured shape above (44 writers vs. 8 exclusions — i.e. "almost everyone, with a few
named, justified exceptions"), **Check J's scope matches the EXCLUDED-style precedent (Checks
E/F/N's exclusion arrays), not the INCLUDED-style one (Checks C/G/H/M)**. This is not a stylistic
preference; an INCLUDED-style array here would require hand-listing 44 files and would
re-introduce exactly the "a new qualifying file is silently excluded until someone remembers to
add it" drift Checks C/G/H/M already carry and Check N exists specifically to backstop. An
EXCLUDED-style array of 8 entries is both smaller and, as outcome 4 below shows, fails *safe* on
drift rather than failing *silent*.

### Outcome 3 — severity tiering

Every check in this file FAILs on violation except Check I, which is an advisory WARN with its
own explicitly documented reason (lines 725-735: the underlying liveness gap is already closed
system-wide by a dispatch-boundary pulse, so Check I's WARN exists only to keep a *cosmetic*
per-agent gap visible, never an actual safety gap). Check J already uses `log_fail` on every
violation branch (missing-artifacts-requirement, heading drift) and `log_pass`/`log_info` on
success/skip. **The redesigned Check J should keep FAIL as its severity** — this is consistent
with the dominant tier (A, B, C, Detector B of E, F, G, H, J itself, M, N are all FAIL-tier), and
Check I's WARN tier is the sole, deliberately-reasoned exception, not a competing norm to match.

### Outcome 4 — the drift hazard of the curated list itself

Checks C/G/M (INCLUDED-style) needed a **bolted-on second check, Check N** (`lint-agent-contracts.sh:1187-1313`,
added by archived task 359) specifically because their own shape is drift-prone in the silent
direction: a new qualifying file that nobody adds to the array simply never gets checked, and
nothing else in the file would notice. Check N closes that by sweeping a filename glob and
asserting every match lands in *some* array (in-scope or recorded-exclusion).

The redesigned Check J, by contrast, does **not need an equivalent bolted-on net**, because its
proposed shape inverts the failure direction: if the check iterates `enumerate_dispatchable_agents()`
directly (the full universe, not a glob subset) and only *skips* a file that is explicitly in the
small exclusion array or whose own content states "never write one," then **a brand-new agent
file is in scope by default** the moment it is added — nothing has to remember to register it.
If that new agent genuinely needs no handoff section (a new forked-subagent-pattern-only agent),
*that* is the one case requiring a deliberate action: adding it to the exclusion array, and until
that happens the lint FAILs loudly by name. This is the opposite, safer default from both the
original content-gated bug (silent pass) and from Checks C/G/M's own INCLUDED-style risk (silent
omission) — it is "fail closed," not "pass open."

One cautionary, directly relevant finding from auditing Check N's own mechanics while confirming
this: Check N's Net 1/Net 2 enumeration glob is literally `'*implementation*agent.md'`
(`_check_n_enumerate '*implementation*agent.md'`, lines 1281 and 1294). This substring does
**not** match the `*-implement-agent.md` naming variant — `epidemiology/agents/epi-implement-agent.md`
and `founder/agents/founder-implement-agent.md` contain `implement` but not `implementation`.
`CHECK_G_EXCLUDED_RELATIVE_PATHS` (line 1202) lists `epi-implement-agent.md` as a recorded
exclusion, but Check N's own glob never actually enumerates that file, so the exclusion entry is
currently dead code with respect to Check N's sweep (it was presumably added defensively or
copied from Check G's own in-scope-array comment, not because Check N's glob ever reaches it).
This is **not in this task's file_scope to fix** (it is Check N's own pre-existing gap, a
different check), and is recorded separately (issue log, class `COVERAGE_GAP`, severity minor)
rather than folded into this task's scope — but it is directly instructive for outcome 4's
design: **Check J's own universe should be sourced from `enumerate_dispatchable_agents()`
(frontmatter-based enumeration, already correct for both naming suffixes, already used by every
other check in the file) rather than from a freshly-invented filename glob**, to avoid
reproducing the same substring trap in a new location.

### Outcome 5 — fixture suite

`scripts/tests/test-lint-agent-contracts-handoff-section.sh` (256 lines, 6 existing assertions,
all currently green) already builds an isolated scratch `REPO_ROOT` tree via `mktemp -d` and
places fixture agent files at `agent-system/extensions/fixture/agents/*.md` — a location that
`enumerate_dispatchable_agents()`'s own glob (`*/agents/*.md` under `AGENTS_ROOT`) already
sweeps in unmodified, confirmed by the suite's existing cases 1-6 exercising the real,
unmodified `lint-agent-contracts.sh` via `REPO_ROOT=<scratch>`. This is the correct, pre-existing
mechanism for the new cases the dispatch names:

- (a) curated file WITH the section — already covered by existing cases 1/2 (prose-form and
  JSON-form writers), no new fixture needed, though the plan may want one fixture file in the
  new exclusion array's namespace too (confirming an *excluded* file is correctly skipped
  without ever reaching the artifacts check).
- (b) curated file WITHOUT the section FAILS — new fixture: a dispatchable agent file with zero
  mention of `.orchestrator-handoff.json` anywhere, not listed in the new exclusion array. Under
  the current script this passes silently (the exact bug); under the fix it must FAIL by name.
  This is the single most important new fixture and should be written first.
- (c) non-curated file without the section does NOT fail — reframed under the EXCLUDED-style
  design as: a file *in* the new exclusion array, with zero mention of the string, must still
  be a skip (`log_info`), never a FAIL or a silent omission from the output.
- (d) a qualifying-but-unregistered file produces the intended finding — under outcome 4's
  fail-closed-by-default design, this is the **same mechanism as case (b)**: any new agent not
  in the exclusion array is "qualifying" by default. No separate completeness-net check (no
  Check-N-equivalent) is needed for this outcome, simplifying the plan relative to the Check
  C/G/M/N precedent.

### Outcome 6 — sibling suites and current baseline

Ran directly, against the real, unmodified source-store script (no edits made this phase):

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — **421 passed, 15
  warnings (Check I only), 0 failed.**
- `test-lint-agent-contracts.sh` — 61/61 passed.
- `test-lint-agent-contracts-await-notification.sh` — 6/6 passed.
- `test-lint-agent-contracts-heartbeat.sh` — 6/6 passed.
- `test-lint-agent-contracts-handoff-section.sh` — 6/6 passed.

This establishes a clean, fully-green baseline for the plan/implement phases to diff against; no
pre-existing failures exist in the shared file or its sibling suites today.

### The abandoned "dispatch-derived predicate" — full reasoning, and why it doesn't transfer

The dispatch names this explicitly as a check to make before re-proposing the mechanism here.
Full chain, confirmed from primary sources (not inferred):

1. A task (reused task-number 195, created 2026-09-09 alongside task 194 "Align lifecycle agent
   contracts on `.orchestrator-handoff.json` writing") proposed replacing
   `is_contractual_handoff_writer()` — then a two-entry hardcoded `case` statement in
   `orchestrate-cycle-postflight.sh` naming only `cslib-implementation-hard-agent` and
   `lean-implementation-hard-agent` — with a predicate derived from whether the **dispatch row**
   supplied a `handoff_path` (favored option (b) in the task's own description, over (a)
   "extend the hardcoded allowlist").
2. In the 2026-09-17 "seventh-pass" backlog consolidation (`git show 5398cfd76`), task 195 was
   **merged into task 212**, not independently implemented — recorded verbatim in the archived
   TODO.md entry: `"ABANDONED 2026-09-17 (seventh-pass consolidation): merged into task 212
   (postflight honesty); no work lost"`.
3. **Task 212 completed this exact idea** (`specs/archive/212_gate_research_dispatch_missing_report/summaries/01_gate-research-report-handoff-predicate-summary.md`):
   deleted `is_contractual_handoff_writer()` entirely and replaced it with a dispatch-derived
   `--handoff-expected true|false` (default `true`) flag threaded from
   `skill-orchestrate/SKILL.md`'s Move 3 call site. `docs/architecture/handoff-schema.md`'s
   "Writer-Contract Determination (D1)" section (lines 501-535) documents this as the current,
   live mechanism.

So the idea was **not rejected on merit and not abandoned as unworkable** — it succeeded, fully,
for `orchestrate-cycle-postflight.sh`. The reason it does not transfer to Check J is structural,
not a repeat of a failed attempt: `orchestrate-cycle-postflight.sh` runs at **dispatch-postflight
time**, when a real `dispatch[]` row with a real `handoff_path`/`orchestrator_mode` field exists
to derive the predicate from. `lint-agent-contracts.sh` runs as a **static lint over markdown
files** — there is no dispatch, no `orchestrator_mode` field, nothing to derive from at lint
time. "Dispatch-derived" is a category error for Check J; the correct analog for a markdown-file
lint is a role/filename-and-content-derived classification, which is precisely what the curated
EXCLUDED-style array (outcome 2) already provides, and is the same kind of classification every
other check in this file already uses.

### `test-lint-agent-contracts-handoff-section.sh` and the adjacent record-418 concern

Record 418 (open, `PLANNED`) flags a *different* hazard shared by some lint-fixture-test suites:
a `resolve_candidate()`-based "deploy-tree-first / source-store-fallback" resolution that can
silently exercise the stale deployed `.claude/` copy instead of the source-store change under
test. Verified directly: `test-lint-agent-contracts-handoff-section.sh` does **not** use
`resolve_candidate()` at all — `LINT_SRC="$SCRIPT_DIR/../lint/lint-agent-contracts.sh"` is a
plain, unconditional source-store-sibling path. This suite is therefore **not** part of record
418's flagged population, and running it during plan/implement (before any redeploy) will
correctly exercise the edited source-store script, not a stale deployed copy. No action needed
here; recorded so the plan phase does not need to re-derive this.

## Recommendations

1. **Remove the content gate.** Delete `grep -qF '.orchestrator-handoff.json' "$f" || continue`
   (line 899) and iterate `enumerate_dispatchable_agents()` directly, exactly as every sibling
   check in this file already does.
2. **Add one new EXCLUDED-style array**, e.g. `CHECK_J_EXCLUDED_RELATIVE_PATHS`, holding the 8
   confirmed forked-subagent-pattern-only files (`core/agents/code-reviewer-agent.md`,
   `core/agents/meta-builder-agent.md`, `core/agents/spawn-agent.md`,
   `cslib/agents/cslib-vet-agent.md`, `filetypes/agents/document-agent.md`,
   `literature/agents/literature-agent.md`, `present/agents/pptx-assembly-agent.md`,
   `present/agents/slide-critic-agent.md`), each with its own per-file "invoked only via the
   forked-subagent pattern, never a `skill-orchestrate` dispatch row" reason comment — matching
   Check N's `CHECK_G_EXCLUDED_RELATIVE_PATHS`/`CHECK_M_EXCLUDED_RELATIVE_PATHS` comment style
   (one reason per entry, never "see above").
3. **Leave the existing return-2 ("never write one") skip untouched** — it already correctly
   covers all 23 research agents via content, and does not need to become curated, since the
   string is genuinely present in those files by design.
4. **Do not build a Check-N-style bolted-on completeness net.** The fail-closed-by-default shape
   from recommendation 1 already provides the completeness guarantee outcome 4 asks for, more
   cheaply than Checks C/G/M's INCLUDED-style + Check N combination.
5. **New fixtures**, added to the existing `test-lint-agent-contracts-handoff-section.sh` scratch
   tree: a dispatchable agent with no mention of the string and not in the exclusion array (must
   now FAIL — this is the task's central regression test), and an excluded agent with no mention
   of the string (must remain a skip). Both slot into the suite's existing
   `build_fixture_tree()`/`REPO_ROOT`-override pattern without new infrastructure.
6. **Re-run, after the fix**, all four sibling suites plus the main lint to confirm the
   421-passed/15-warn/0-fail and 61/6/6/6 baseline holds (modulo the new fixtures' own expected
   pass/fail lines), per outcome 6.
7. Leave Check N's own `*implementation*agent.md` glob gap (recorded separately in the issue log)
   untouched — out of this task's file_scope, named only so the plan phase does not accidentally
   reproduce the same substring trap in Check J's own design.

## Decisions

- Check J's in-scope criterion is role/content-derived (EXCLUDED-style: everyone except research
  agents and the 8-file forked-subagent exclusion set), not dispatch-derived — the dispatch-
  derived mechanism that succeeded for `orchestrate-cycle-postflight.sh` (task 212) does not
  transfer to a static markdown lint with no dispatch context.
- The new array matches the EXCLUDED-style precedent (Checks E/F/N's exclusion arrays), not the
  INCLUDED-style precedent (Checks C/G/H/M), justified by the measured 44-vs-8 shape, not by
  preference.
- No new Check-N-equivalent completeness-net check is needed; the fail-closed-by-default
  iteration already provides that guarantee as a side effect of removing the content gate.
- Check J's severity stays FAIL, consistent with every check in the file except Check I's
  separately-reasoned advisory WARN.

## Risks & Mitigations

- **Risk**: a future new agent that genuinely needs no handoff section (another
  forked-subagent-pattern agent) will FAIL the lint until someone adds it to the new exclusion
  array. **Mitigation**: this is the intended, safer failure direction (fail loud, not silent)
  and is explicitly the point of outcome 4; the FAIL message should name the agent and point at
  the exclusion array by name so the fix is a one-line addition, not an investigation.
- **Risk**: the founder/present per-task-type terminal agents (19 files beyond the documented
  21-file "implementation/implement + planner/reviser" list) are real, verified writers today,
  but `docs/architecture/handoff-schema.md`'s "Handoff Writers" table does not name them by role.
  **Mitigation**: Check J's own in-scope set should be derived from "everyone except the 8
  exclusions," not from re-deriving the architecture doc's narrower table — do not narrow the
  new array to only the 21 role-named files, or the fix would immediately regress 19 currently-
  correct files to unchecked status (reproducing the exact hole this task closes, just one level
  removed).

## Context Extension Recommendations

- **Topic**: `docs/architecture/handoff-schema.md`'s "Handoff Writers" table.
- **Gap**: the table names writers by the core 3-phase-lifecycle role
  (`*-implementation-agent`/`*-implement-agent` + `planner-agent`/`reviser-agent`) but does not
  mention that founder and present extensions route many additional per-task-type terminal/plan
  agents through the same `orchestrator_mode`-gated writer contract. A reader relying solely on
  that table would under-scope any future writer-related lint or audit exactly as the task
  description warns against.
- **Recommendation**: a future documentation task could add a one-line pointer in that section
  noting that extensions with multiple per-task-type terminal agents (founder, present) register
  each such agent as a writer individually, rather than being implied by the 3-phase-lifecycle
  table alone. Not in this task's scope to add (it is a docs file, not Check J's own file_scope),
  named here only as a gap found during this research.

## Appendix

- Search queries / commands used: direct `grep -n` sweeps of `lint-agent-contracts.sh` for
  `Check J`, `is_contractual_handoff_writer`, `enumerate_dispatchable_agents`, `AGENTS_ROOT=`,
  `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS=`; a standalone bash probe re-implementing
  `_check_j_locate_handoff_section()`/`is_dispatchable_agent()` verbatim, run against all 81
  `agents/*.md` files under `agent-system/extensions`; `git log --all -S` searches against
  `specs/CHANGE_LOG.md`/`specs/TODO.md` for the task-195/212 history; direct execution of the
  live lint and its four sibling test suites.
- References: `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (Checks C, E,
  F, G, H, I, J, M, N); `agent-system/extensions/core/docs/architecture/handoff-schema.md`
  ("Handoff Writers", "Writer-Contract Determination (D1)"); `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`;
  `specs/archive/212_gate_research_dispatch_missing_report/summaries/01_gate-research-report-handoff-predicate-summary.md`;
  `specs/archive/359_close_lint_curated_array_coverage_gaps/summaries/01_close-lint-curated-array-gaps-summary.md`;
  `specs/TODO.md:5178` (open record 418).
