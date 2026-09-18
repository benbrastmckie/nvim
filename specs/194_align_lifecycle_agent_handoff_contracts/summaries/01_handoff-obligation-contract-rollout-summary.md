# Implementation Summary: Align Lifecycle Agent Handoff Contracts

- **Task**: 194 - Align lifecycle agent handoff contracts
- **Status**: [COMPLETED]
- **Started**: 2026-09-17T00:00:00Z
- **Completed**: 2026-09-17T01:45:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_handoff-obligation-contract-rollout.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Every agent reachable via an `/orchestrate` `dispatch[]` row now carries an explicit, consistently
worded obligation to write `.orchestrator-handoff.json` on every `orchestrator_mode: true`
dispatch — established BEFORE the companion task widens `orchestrate-cycle-postflight.sh`'s
detection so an absent handoff becomes a real `HANDOFF_STALE_OR_ABSENT` defect. All 7 plan phases
completed: the canonical block was frozen and landed in the 3 core agents (2 prohibition
reversals + 1 addition), the 4 remaining non-core prohibition contracts were reversed, and the
block was rolled out additively to the remaining 55 zero-count agents across 8 extension
clusters (founder, present, filetypes, formal, cslib, epidemiology, email, lean,
latex/nvim/nix/python/rust/typst/web/z3).

## What Changed

62 of the 64 reachable agent contract files under `agent-system/extensions/*/agents/` were
edited; the other 2 (`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`)
were verified unchanged as the wording reference. No file under `.claude/**` was touched (source
store / deploy boundary honored throughout), and `orchestrate-cycle-postflight.sh` was not
touched (companion task's disjoint territory).

**Reversals (6 files)** — prohibition text replaced with the obligation:
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
- `agent-system/extensions/cslib/agents/cslib-research-agent.md`
- `agent-system/extensions/lean/agents/lean-research-agent.md`
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md`

**Additions (56 files)** — canonical block inserted as a new `###` subsection adjacent to each
agent's existing return-metadata / wrap-up stage:
- `agent-system/extensions/core/agents/planner-agent.md`
- 15 founder agents: `analyze-agent.md`, `deck-builder-agent.md`, `deck-planner-agent.md`,
  `deck-research-agent.md`, `finance-agent.md`, `financial-analysis-agent.md`,
  `founder-implement-agent.md`, `founder-plan-agent.md`, `founder-spreadsheet-agent.md`,
  `legal-analysis-agent.md`, `legal-council-agent.md`, `market-agent.md`, `meeting-agent.md`,
  `project-agent.md`, `strategy-agent.md`
- 13 present/filetypes agents: `budget-agent.md`, `funds-agent.md`, `grant-agent.md`,
  `slide-planner-agent.md`, `slides-research-agent.md`, `slidev-assembly-agent.md`,
  `timeline-agent.md`, `docx-edit-agent.md`, `filetypes-router-agent.md`,
  `filetypes-spreadsheet-agent.md`, `presentation-agent.md`, `scrape-agent.md`, `sheet-agent.md`
  (`filetypes-router-agent.md` and `presentation-agent.md` additionally carry a one-sentence
  clarification that the obligation is the router's own and that `document-agent`,
  `spreadsheet-agent`, and `pptx-assembly-agent` receive no `orchestrator_mode` and write no
  handoff)
- 11 formal/cslib/epidemiology/email/lean agents: `formal-research-agent.md`,
  `logic-research-agent.md`, `math-research-agent.md`, `physics-research-agent.md`,
  `cslib-research-hard-agent.md`, `pr-review-implementation-agent.md`,
  `pr-review-research-agent.md`, `epi-implement-agent.md`, `epi-research-agent.md`,
  `email-implementation-agent.md`, `lean-implementation-agent.md`
- 16 language-toolchain agents: `latex-implementation-agent.md`, `latex-research-agent.md`,
  `neovim-implementation-agent.md`, `neovim-research-agent.md`, `nix-implementation-agent.md`,
  `nix-research-agent.md`, `python-implementation-agent.md`, `python-research-agent.md`,
  `rust-implementation-agent.md`, `rust-research-agent.md`, `typst-implementation-agent.md`,
  `typst-research-agent.md`, `web-implementation-agent.md`, `web-research-agent.md`,
  `z3-implementation-agent.md`, `z3-research-agent.md`

**Disambiguation clause** (distinguishing `.orchestrator-handoff.json` from the unrelated
context-pressure handoff at `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`)
appended in the 9 files that carry both mechanisms: `lean-implementation-agent.md` and the 8
Phase 6 implementation agents (`latex`, `neovim`, `nix`, `python`, `rust`, `typst`, `web`, `z3`).

**Verify-only, unchanged (2 files)**: `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`,
`agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`.

## Decisions

- **Dual-role agents get a combined variant.** 10 agents (`budget-agent`, `funds-agent`,
  `grant-agent`, `timeline-agent` in `present`; `docx-edit-agent`, `filetypes-router-agent`,
  `filetypes-spreadsheet-agent`, `presentation-agent`, `scrape-agent`, `sheet-agent` in
  `filetypes`) are the `dispatch[]` target for BOTH the research and implement phase of their
  routing entry (a single agent file serves both roles) — not documented as a distinct case in
  the plan's Appendix, which defines only research/plan/implement variants. A "dual" variant was
  authored: identical head/mid text, and a tail that states both status-enum and phase-count
  rules conditioned on "On a research dispatch... / On an implement dispatch...". This keeps the
  obligation byte-identical for the shared head/mid portion while correctly covering both phases
  the file is dispatched into.
- **Placement anchor generalized mechanically.** Rather than hand-placing each of the 55 additive
  insertions, the last `#{2,3} Stage \d+` heading in each file was located and the block inserted
  immediately before the next `## `-level heading following it — the same "sibling of the last
  Stage heading, before the next top-level section" placement Phase 1 established by hand for
  `general-implementation-agent.md` and `planner-agent.md`. This anchor held correctly across
  every observed heading-level variation (including `grant-agent.md`, which inconsistently uses
  `## Stage 6`/`## Stage 7` instead of `###` for its last two stages) and was spot-verified on a
  research agent, an implement agent, a dual-role agent, and both router agents.

## Plan Deviations

- **Additive/reversal count is 56/6/2, not 55/6/3 as the plan's Phase 7 Scope Hypothesis stated.**
  The plan's own two internal counts already disagreed before implementation: the Overview's
  Goals section says "55 by addition, 6 by reversal" (61 total) while its Research Integration
  section says "56 zero-count agents... 6 prohibition agents... 2 already-correct agents" (64
  total). The as-applied count matches the Research Integration figures: `planner-agent.md` is
  one of the 56 zero-count/additive agents (added in Phase 1 alongside the 2 core reversals), and
  55 further additions landed across Phases 3-6 (15+13+11+16), for 56 additive + 6 reversal + 2
  untouched = 64. This is a reconciliation of the plan's own pre-existing internal inconsistency,
  not a scope change: the reachable set, the 6 reversal files, and the 2 untouched files are
  exactly as the plan specified.

## Verification

- Build: N/A (markdown-only change)
- Tests: N/A
- Reachable-set derivation re-run: 64 names, unchanged from plan time. Command:
  ```bash
  for f in agent-system/extensions/*/manifest.json; do
    jq -r '[(.routing_agents.research//{}),(.routing_agents.plan//{}),(.routing_agents.implement//{}),
            (.routing_agents_hard.research//{}),(.routing_agents_hard.plan//{}),(.routing_agents_hard.implement//{})][] | .[]?' "$f"
  done | sort -u
  ```
- All 64 reachable agents have a nonzero `.orchestrator-handoff.json` mention count: confirmed.
- No reachable agent retains prohibition language (`non-writer by design`, `MUST NOT write
  .orchestrator-handoff`, `never writes a handoff`): confirmed clean.
- Wording consistency: all 62 edited files contain the frozen head sentence and the frozen
  write-location/dispatch_seq-echo paragraph block byte-identical to the Appendix (only the
  variant-specific status-enum/phase-count sentence, and the dual/router/disambiguation
  add-on sentences where applicable, differ).
- Aux-dispatch asymmetry: every one of the 62 edited files conditions the obligation on
  `orchestrator_mode: true`; zero files restate the `aux_dispatch[]` contract.
- MUST NOTs: `git diff --stat` against the pre-implementation commit shows zero changes to
  `orchestrate-cycle-postflight.sh`, zero changes under `.claude/**`, and zero changes to the 2
  already-correct hard-mode agents.
- Task-reference lint (`bash .claude/scripts/check-task-references.sh`): PASS, 0 unexempted
  occurrences across all 4 scanned trees.
- Files verified: Yes (all 62 edits spot-checked for placement and content; full-file diffs
  reviewed for the 9 reversal/addition files in Phases 1-2; structural `grep`-based verification
  across all 55 Phase 3-6 files).

## Impacts

- `docs/architecture/handoff-schema.md`'s "Handoff Writers" table, its D1 allowlist, and its
  "Open question, not decided here" paragraph are now stale: they describe base-mode
  `general-research-agent`/`planner-agent`/`general-implementation-agent` as "Never writes a
  handoff, by design," which this task reverses. Updating that doc is out of this task's file
  scope (`agent-system/extensions/*/agents/**` only) — recorded as a follow-up below.
- The companion task (widening `orchestrate-cycle-postflight.sh`'s
  `is_contractual_handoff_writer()` predicate so an absent handoff becomes a real
  `HANDOFF_STALE_OR_ABSENT` defect) can now proceed: every dispatch[]-reachable agent's contract
  states the obligation, so the widened detection will land on defects that reflect a real
  contract violation rather than an unstated one.
- **The obligation takes runtime effect only after the source store is redeployed to `.claude/`
  by the sanctioned deploy process** — this is the user's step, not something this task or a
  future dispatch performs automatically. Until redeploy, the live `.claude/` agent contracts
  still reflect the pre-task wording.

## Follow-ups

- Update `docs/architecture/handoff-schema.md`'s "Handoff Writers" table, D1 allowlist, and "Open
  question, not decided here" paragraph to reflect the new universal obligation (out of this
  task's file scope).
- Redeploy the source store to `.claude/` so the new contracts take effect for live dispatches.

## References

- `specs/194_align_lifecycle_agent_handoff_contracts/plans/01_handoff-obligation-contract-rollout.md`
- `specs/194_align_lifecycle_agent_handoff_contracts/reports/01_handoff-obligation-audit.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
