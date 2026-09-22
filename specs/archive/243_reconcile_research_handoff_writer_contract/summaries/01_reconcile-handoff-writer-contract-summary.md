# Implementation Summary: Task #243

- **Task**: 243 - Reconcile research handoff writer contract
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T17:34:28Z
- **Completed**: 2026-09-22T18:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_reconcile-handoff-writer-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Reconciled a documentation conflict between `agents/general-research-agent.md` (and its 20
copy-templated extension counterparts), which unconditionally instructed research agents to
write `.orchestrator-handoff.json` under `orchestrator_mode: true`, and
`docs/architecture/handoff-schema.md`, which already documented the opposite rule: research
agents never write a handoff, in any mode. The runtime consumer
(`orchestrate-cycle-postflight.sh`) was already built around the "no handoff" case as expected,
so the fix direction was the 21 agent contracts, not the docs or scripts.

## What Changed

- `agent-system/extensions/core/agents/general-research-agent.md` — replaced the
  `### \`.orchestrator-handoff.json\` (orchestrator-mode dispatches)` section with a
  `### \`.orchestrator-handoff.json\` — research agents never write one` prohibition section;
  rewrote the Stage 3.6 "Scoping Decision" cross-reference to point at the prohibition instead of
  claiming a handoff-writing obligation.
- 17 uniform extension research-agent files (cslib, epidemiology, formal x4, founder, latex, nix,
  nvim, present, python, rust, typst, web, z3) — same section replacement, applied verbatim via a
  scripted exact-match substitution (each file's old section confirmed byte-identical before
  editing).
- `agent-system/extensions/lean/agents/lean-research-agent.md` — section replacement (preserving
  its `##` heading level, the one documented exception); removed a MUST DO bullet instructing the
  write and renumbered; added a MUST NOT bullet forbidding the write.
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` — section replacement (`###`
  heading); same MUST DO removal/renumber and MUST NOT bullet addition.
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` — section replacement; MUST DO
  bullet removed/renumbered; existing conditional MUST NOT bullet ("Write ... when the delegation
  context does NOT carry orchestrator_mode: true") rewritten to the unconditional form ("Write
  ... at all, in any mode").
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — corrected the Handoff
  Writers table's misattributed citation from "Stage 3.6 'Scoping Decision' in the research
  agents" (a passage that never stated the prohibition) to the now-correct
  `.orchestrator-handoff.json` — research agents never write one section. The rule statement
  itself was already correct and is unchanged.

All 21 files now carry the identical canonical prohibition text (apart from the one documented
`##`-vs-`###` heading-level exception in `lean-research-agent.md`), and the `dispatch_seq` echo
instruction that previously lived only inside the deleted handoff section was preserved by
redirecting it to `.return-meta.json`'s top-level `dispatch_seq` key instead of dropping it.

## Decisions

- Chose "research agents never write a handoff, in any mode" as the one settled rule (matching
  what `handoff-schema.md` and the runtime postflight script already assumed), rather than
  relaxing the docs to match the contradictory agent instruction — the postflight recovery path
  via `.return-meta.json` is what the system actually consumes.
- Preserved the `dispatch_seq` echo instruction by redirecting its target from the (now-removed)
  handoff file to `.return-meta.json`, rather than deleting the instruction outright, since 20 of
  the 21 files had no other `dispatch_seq` guidance.
- For the 3 variant files with extra MUST DO/MUST NOT references, removed the writing obligation
  and either added a new MUST NOT bullet (lean files) or rewrote an existing conditional MUST NOT
  bullet to its unconditional form (cslib), renumbering each disturbed list contiguously.
- `orchestrate-build-dispatch.sh` was verified, not edited: its `## Handoff` block only emits
  `handoff_path`/`task_dir` connectivity information for every dispatch alike and asserts no
  writing obligation, confirming the task description's premise that no script change was needed.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (markdown-only contract files)
- Tests: N/A
- Files verified: Yes — repo-wide acceptance grep confirms:
  - 0 hits for `MUST write \`.orchestrator-handoff` across all `*research*agent.md` files
  - 0 hits for the old heading text `orchestrator-mode dispatches)` anywhere in scope
  - 21/21 files carry `research agents never write one`
  - 21/21 files carry the `dispatch_seq` echo instruction (redirected to `.return-meta.json`)
  - `handoff-schema.md` no longer cites "Stage 3.6"
  - `git status --short` shows no modification under `.claude/`

## Impacts

- Removes the nondeterministic behavior observed during a prior multi-task orchestrate run
  (7 of 8 research dispatches wrote a handoff, 1 refused citing the schema) — all research agents
  now carry one unambiguous instruction.
- No runtime behavior change: `orchestrate-cycle-postflight.sh` was already built around the
  "no handoff after research" case, so agents that previously (incorrectly) wrote a handoff will
  simply stop doing so, which postflight already tolerates correctly either way.

## Follow-ups

- `planner-agent.md` and `general-implementation-agent.md` carry the same defect class (unclear
  or contradictory handoff-writing instructions) but were explicitly out of scope for this task:
  `general-implementation-agent.md` was claimed by concurrent sibling task territory this same
  cycle, and neither file was touched here. A follow-up task should apply the same reconciliation
  to those two files.

## References

- Plan: `specs/243_reconcile_research_handoff_writer_contract/plans/01_reconcile-handoff-writer-contract.md`
- Report: `specs/243_reconcile_research_handoff_writer_contract/reports/01_reconcile-handoff-writer-contract.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — "Handoff Writers — the
  settled decision, in one place" section
