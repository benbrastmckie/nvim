# Implementation Summary: Formal Research Agents Report Section Conformance

- **Task**: 495 - Give the formal extension research agents the verbatim required-heading contract their core counterpart already carries
- **Status**: [COMPLETED]
- **Started**: 2026-11-07T02:31:00Z
- **Completed**: 2026-11-07T02:42:00Z
- **Effort**: 4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_report-heading-contract-conformance.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The four formal-extension research agents carried a buried `### Recommendations` subsection
inside `## Findings` and no copy of the verbatim required-heading contract that
`general-research-agent.md` had already gained from an earlier, abandoned remediation. This task
established one canonical home for that contract in `report-format.md` (with a parallel section
in `summary-format.md`), converted `general-research-agent.md`'s verbatim copy into a pointer at
it, remediated all four formal research agents with a reachable pointer plus a structural
`### Recommendations` -> `## Recommendations` promotion, and completed the cross-extension sweep
the diagnosis had scoped but never run.

## What Changed

- `agent-system/extensions/core/context/formats/report-format.md` — added
  `## Required Section Headings (verbatim)` immediately after `## Structure`: the five literal
  headings, the `^##+ {section}` exact-text matching rule, both named near-misses
  (`## Recommended Next Steps`, `## Context Extension Recommendations`), and a pre-return grep
  self-check stated as an action, not a passive warning.
- `agent-system/extensions/core/context/formats/summary-format.md` — added the parallel
  `## Required Section Headings (verbatim)` section naming the six `SUMMARY_SECTIONS` headings,
  the same regex rule, and the same self-check.
- `agent-system/extensions/core/agents/general-research-agent.md` — the prior verbatim contract
  paragraph after the Stage 6 skeleton is now a short pointer at `report-format.md`'s new
  section; its `## Context References` already carried the pointer target, so no addition was
  needed there.
- `agent-system/extensions/formal/agents/{formal,logic,math,physics}-research-agent.md` — each
  gained: (a) a `report-format.md` Context References entry; (b) a pointer at the canonical
  section appended to the existing `**Copy source**:` note; (c) `### Recommendations` promoted
  from a `## Findings` subsection to a top-level `## Recommendations` heading between
  `## Findings` and `## Decisions`, matching `general-research-agent.md`'s canonical order.
  `### Cross-Domain Synthesis` and the per-domain `### {Domain N} Findings` subsections are
  unchanged.
- `specs/495_formal_research_agents_report_section_conformance/fixtures/` — three fixtures
  (`report-near-miss.md`, `report-nested-ok.md`, `report-toplevel-ok.md`), the `sweep-skeletons.sh`
  machine-check harness (a line-based fence parser reading `validate-artifact.sh`'s own
  `REPORT_SECTIONS`/`SUMMARY_SECTIONS` arrays live), and the captured baseline
  `sweep-baseline.txt`.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` (9 extensions resynced); deployed
  `report-format.md`/`summary-format.md` carry the new section, and deployed
  `general-research-agent.md` carries the pointer.
- `agent-system/extensions/core/index-entries.json` — line counts regenerated for
  `report-format.md`/`summary-format.md` (and, as an incidental side effect of the shared
  regeneration tool, for four unrelated entries already stale from a concurrent sibling task's
  in-flight edits on this tree — that part of the regen was declared out of this task's own
  `file_scope` and was correctly dropped from this task's commits by the scoped-commit wrapper).

## Decisions

- **Single referenceable home, not a fourth and fifth verbatim copy.** The contract now lives
  once in `report-format.md` (plus the parallel statement in `summary-format.md`); every
  consumer — `general-research-agent.md` and all four formal agents — points at it by name. Four
  divergent verbatim copies is the exact mechanism that let one copy (the formal extension's)
  drift out of date while another (core's) was updated; a single home removes that mechanism
  structurally rather than relying on every future editor remembering to update every copy.
- **`### Recommendations` was promoted to top-level `## Recommendations`** in all four formal
  skeletons (not left nested, relying only on the pointer/instruction). This removes the
  production failure's contributing factor (a) — burial — structurally: an agent restructuring
  `## Findings` for a real report no longer has a load-bearing subsection it could reasonably
  relocate or omit without realizing it was required.
- **No authorship-time `validate-artifact.sh` subprocess call was added inside the research
  agents.** The pre-return self-check is a stated grep-based action in the canonical contract
  text (`report-format.md`/`summary-format.md`), not a second validator invocation from inside
  the agent. The observed production failure was a non-blocking validator warning left
  unactioned at a later postflight stage that already runs the validator — the gap was
  "warning ignored," not "no gate exists." A grep-and-fix-before-writing step addresses that
  gap directly without duplicating the validator call.
- **`validate-artifact.sh` was explicitly NOT changed.** `REPORT_SECTIONS`, `SUMMARY_SECTIONS`,
  and the `^##+ {section}` any-depth-prefix regex are untouched. The Phase 1 fixture proved why:
  a substring relaxation of the `Recommendations` check would let
  `## Context Extension Recommendations` or `## Recommended Next Steps` satisfy it, converting
  the real, observed production failure into a silent false pass. Phase 5 re-ran all three
  fixtures against the deployed validator after every other change in this task landed, and the
  near-miss fixture still fails with exactly `Missing required section: ## Recommendations` —
  confirming the validator's strictness survived this task's changes intact.
- **The fixture and sweep harness live in this task's own `fixtures/` directory**, not as a new
  permanent `core/scripts/` script and not as a case appended to
  `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`. Sibling task 464 held
  that test file this cycle, and a new permanent script would carry its own script-inventory and
  test-suite obligations this record did not declare. Promoting the harness into a permanent
  script with its own suite is listed as a follow-up below rather than done here.

## Plan Deviations

- None in the edits applied — all three per-file edits across all four formal agents matched the
  plan's prescription exactly, and every file's extracted skeleton passed the real
  `validate-artifact.sh` binary on the first attempt.
- A **measurement deviation** was found and recorded (not a plan deviation in the edit sense):
  this task's own Phase 1 sweep re-run found the cross-extension FAIL enumeration to be larger
  than the research report stated. See Follow-ups below for the corrected count — this summary
  uses this task's own measured `fixtures/sweep-baseline.txt` as the authoritative source rather
  than the report's own (slightly undercounted) enumeration.
- The Phase 2 draft of `report-format.md`'s near-miss sentence initially wrapped
  "Recommended Next Steps" across two source lines, which made the phase's own
  `grep -c 'Recommended Next Steps'` verification criterion fail against a single-line match;
  caught immediately by that same verification step and reworded onto one line before the phase
  closed.

## Impacts

- Future authoring drift between the formal extension's four research agents and
  `general-research-agent.md` is now structurally harder: the contract has one home, and the
  required heading is a top-level heading in all five agents' skeletons rather than buried in
  four of them.
- `agent-system/extensions/formal/` is not currently a loaded extension in this repository (not
  listed in `.claude-extensions.json`), so these four agents have **no deployed counterpart
  here** — their conformance evidence is the source-store machine-check (Phase 4's harness run
  plus the real `validate-artifact.sh` binary against each extracted skeleton), not a
  deployed-tree check. A repository that does load the `formal` extension will receive this fix
  on its next deploy.
- The sweep harness built in Phase 1 (`fixtures/sweep-skeletons.sh`) is reusable by any future
  record that wants to machine-check an agent's embedded report/summary skeleton against the
  validator's own arrays and regex, without re-deriving the line-based fence parser this task's
  research established was necessary (a naive regex mis-pairs fences in these files).

## Follow-ups

Scope item (4) asked for a complete cross-extension sweep against the validator's own
`REPORT_SECTIONS`/`SUMMARY_SECTIONS` arrays and regex, with any further gaps recorded as
follow-ups rather than fixed here. This task's own Phase 1/5 harness runs are the authoritative
measurement (not the research report's enumeration, which undercounted the founder-extension
group — see the measurement deviation above); each group below needs its own record with its own
widened `file_scope`:

- **(a) Four confirmed, narrowly-scoped gaps**, each missing only a few trailing headings:
  `agent-system/extensions/nix/agents/nix-implementation-agent.md` (summary: missing Impacts,
  Follow-ups, References), `agent-system/extensions/nvim/agents/neovim-implementation-agent.md`
  (summary: same three), `agent-system/extensions/web/agents/web-implementation-agent.md`
  (summary: same three), and `agent-system/extensions/web/agents/web-research-agent.md` (report:
  missing Context & Scope).
- **(b) A larger, pre-existing domain-shaped-report gap class — 15 agents, not 11 or 13**: this
  task's own measurement found 10 founder-extension agents (`analyze-agent.md`,
  `deck-builder-agent.md`, `deck-research-agent.md`, `finance-agent.md`,
  `founder-implement-agent.md`, `founder-spreadsheet-agent.md`, `legal-council-agent.md`,
  `market-agent.md`, `project-agent.md`, `strategy-agent.md` — the research report named only 9
  of these 10 while describing them as "eight"), 3 present-extension agents (`budget-agent.md`,
  `slide-critic-agent.md`, `slides-research-agent.md`), and 2 epidemiology-extension agents
  (`epi-research-agent.md`, `epi-implement-agent.md`) that write heavily domain-customized
  report/summary shapes (e.g. `## Summary` instead of `## Executive Summary`; no `## Decisions`,
  `## Recommendations`, `## Impacts`, `## Follow-ups`, or `## References` at all in most of them)
  while still landing under a path `skill-base.sh`'s artifact-validation sweep treats as a report
  or summary regardless of `task_type`. This predates this task and is substantially larger than
  the gap this task was filed to close.
- **(c) Seven research agents carrying no embedded report skeleton at all**:
  `typst-research-agent.md`, `z3-research-agent.md`, `books-research-agent.md`,
  `latex-research-agent.md`, `python-research-agent.md`, `rust-research-agent.md`, and
  `cslib-research-agent.md`. Their "Create Research Report" stage is a single path line with no
  structural guidance and no pointer to `report-format.md` or `general-research-agent.md` — a
  different failure shape than the formal extension's burial problem (there is nothing to bury;
  there is no skeleton to deviate from), offering the authoring agent even less signal than a
  buried-but-present skeleton does. Completed project 137 (which gave the lean research and
  implementation agents their skeletons) is the model to follow for closing this gap.
- **(d) Optional**: promote this task's `fixtures/sweep-skeletons.sh` sweep harness into a
  permanent `core/scripts/` script with its own test suite, so future records in groups (a)-(c)
  above (and any future drift check) do not need to re-derive the line-based fence parser. Not
  done here deliberately — see Decisions above.

## References

- `specs/495_formal_research_agents_report_section_conformance/plans/01_report-heading-contract-conformance.md`
- `specs/495_formal_research_agents_report_section_conformance/reports/01_formal-research-agents-report-section-conformance.md`
- `specs/495_formal_research_agents_report_section_conformance/fixtures/sweep-baseline.txt`
- `agent-system/extensions/core/context/formats/report-format.md`'s `## Required Section Headings (verbatim)` section
- `agent-system/extensions/core/context/formats/summary-format.md`'s `## Required Section Headings (verbatim)` section
