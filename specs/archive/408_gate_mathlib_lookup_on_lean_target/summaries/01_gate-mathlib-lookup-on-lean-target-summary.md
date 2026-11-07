# Implementation Summary: Task #408

- **Task**: 408 - Gate the formal extension's mandatory Mathlib-lookup step on an actual Lean target
- **Status**: [COMPLETED]
- **Started**: 2026-11-06
- **Completed**: 2026-11-07
- **Effort**: 4 hours
- **Dependencies**: Task 359
- **Artifacts**: plans/01_gate-mathlib-lookup-on-lean-target.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Extracted the formal extension's previously-unconditional Mathlib-lookup obligation into one
registered shared gate (`context/patterns/mathlib-lookup-gate.md`), then rewrote all eight
contract surfaces — the four research-agent contracts and their four skill wrappers — to point at
it instead of restating the obligation unconditionally. The gate makes the step mandatory only
when the task has a genuine Lean target (primarily a `*.lean` path in `file_scope`, secondarily a
`lean4`-routed `task_type`) AND the four `lean_*` lookup tools are registered in the session
(checked via a single `ToolSearch` call); otherwise the step resolves to a logged, non-penalized
skip. Redeployed via `deploy-headless.sh` as a hygiene check of the repository's currently active
extensions (the `formal` extension itself has no `.claude-extensions.json` entry and is not
deployed here).

## What Changed

- `agent-system/extensions/formal/context/patterns/mathlib-lookup-gate.md` — new file; the single
  gate definition (condition (a) Lean-target signal, condition (b) tool-registration signal, the
  resolution table, skip-log wording, the `mathlib_lookup_gated` metadata contract, and the
  relationship to the existing tool-failure handling block)
- `agent-system/extensions/formal/manifest.json` — appended `"patterns"` to `.provides.context`
- `agent-system/extensions/formal/index-entries.json` — added one `.entries[]` record for the new
  pattern file (`domain: "core"`, `subdomain: "patterns"`, following the only existing precedent
  for a top-level `patterns/` tier)
- `agent-system/extensions/formal/agents/logic-research-agent.md` — gated all 12 obligation sites
  (tool-table intro, decision tree, search priority, research-question list, Step 2 header,
  synthesis bullet, report-template sections, Stage 6 JSON example, Stage 7 example return, MCP
  Tool Errors framing, MUST DO item 8)
- `agent-system/extensions/formal/agents/math-research-agent.md` — same 12 surface classes gated
- `agent-system/extensions/formal/agents/physics-research-agent.md` — same classes gated minus the
  Stage-2 research-question bullet (this file has none); `physics-research-agent.md:36`
  ("Mathlib4 integration patterns") left untouched as unrelated domain-knowledge guidance
- `agent-system/extensions/formal/agents/formal-research-agent.md` — thinner footprint (no decision
  tree, no Step 2 header, no dedicated Mathlib Theorems report section); 6 sites gated
- `agent-system/extensions/formal/skills/skill-logic-research/SKILL.md` — gated the Required Tool
  Invocation narrative mention and the example-return bullet
- `agent-system/extensions/formal/skills/skill-math-research/SKILL.md` — same two sites gated
- `agent-system/extensions/formal/skills/skill-physics-research/SKILL.md` — single narrative
  mention gated
- `agent-system/extensions/formal/skills/skill-formal-research/SKILL.md` — single narrative
  mention gated

## Decisions

- The new index-entries.json entry uses `domain: "core"` / `subdomain: "patterns"` rather than
  `domain: "project"` (the value every pre-existing formal entry uses). `domain`'s enum is closed
  to `core`/`project`/`system` (`check-extension-docs.sh` Rule T), and `project` is reserved for
  the logic/math/physics domain-knowledge tier, not this cross-cutting gate mechanism; `core`
  with `subdomain: "patterns"` is the only existing precedent for a top-level `patterns/` tier
  (the core extension's own `patterns/*` entries use this exact pairing).
- Condition (a)'s primary signal is a `*.lean` path in the task's `file_scope` (read directly from
  `specs/state.json` keyed on `project_number`, since a research agent's own dispatch file never
  carries its own `file_scope`), not `task_type == "lean4"` — the four agents this gate covers
  route only under `formal`/`formal:logic`/`formal:math`/`formal:physics` and never under `lean4`,
  so the `task_type` branch is secondary and would never fire alone in practice.
- A skip is framed as an accepted degraded mode, mirroring `lean-mcp-preflight-check.sh`'s
  `emit_dispatch_block()` convention for Lean work proceeding without lean-lsp — never a
  `partial` status, and never routed through `issue-record.sh` (reserved for genuine deviations
  and wins, not a gate resolving exactly as designed).

## Plan Deviations

- **Phase 4, deploy-headless.sh target**: `deploy-headless.sh` landed the deploy but reached
  `RESULT=landed_verify_red`, not the plan's targeted `landed_verify_clean`. Closed as
  `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned Exclusions record in the plan: the 2 failing
  checks (gate10's internal 30s timeout against `validate-state.sh --deep`, and
  `lint-dead-command-recommendations.sh`'s 2 `/ide`-has-no-definition-file findings in the
  unrelated `memory` extension) are both confirmed pre-existing and outside this task's
  `agent-system/extensions/formal/**` scope — a direct standalone `validate-state.sh --deep` run
  passed cleanly in 33.358s (just over the 30s wrapper timeout), and `git log` shows the memory
  files' most recent touch (`a146cba61`) long predates and is unrelated to this dispatch. Doc-lint
  and task-reference lint both independently PASS in the same run.
- **Phase 4, complete gate set**: the full `verify-deploy.sh` (no `--only-gate`, no `--skip-slow`)
  and the full `run-all.sh` Gate 8 battery were deferred to the once-per-batch full-depth run per
  this dispatch's own Batch Gate Deferral directive, rather than independently run at full depth
  inside this single-task dispatch. The narrower `--only-gate 3,4` covering check stayed green
  through all four phases, and `check-extension-docs.sh`, `check-task-references.sh`, and
  `check-record-versioning.sh` were each independently re-confirmed green standalone.

## Verification

- Build: N/A (markdown and JSON only; no runtime code)
- Tests: Scoped 27-suite `--only` run (Phase 1 Tier Justification) — 25 passed, 2 failed
  (`test-gate-cache-equivalence.sh`, pre-existing EXPECTED; `test-orchestrate-cycle-postflight.sh`,
  confirmed foreign/pre-existing via `git log`, traced to commit `d67f3c527` outside this task's
  scope)
- `verify-deploy.sh --skip-slow --only-gate 3,4` — green after every phase, neither gate SKIPping
- `check-extension-docs.sh` — green; `formal` reports PASS
- `check-task-references.sh` — 0 unexempted occurrences repo-wide
- `check-record-versioning.sh agent-system/extensions/formal` — 0 unexempted occurrences
- Cross-surface tally: `grep -l 'mathlib-lookup-gate' agents/*.md skills/*/SKILL.md | wc -l` = 8
- All four agent contracts' Stage 6 (or Stage 5) JSON examples carry `mathlib_lookup_gated`
- `physics-research-agent.md:36` confirmed unchanged
- Files verified: Yes (all 11 files present; `wc -l` of the new pattern file matches its declared
  `line_count`)

## Impacts

- A future research dispatch under `formal`/`formal:logic`/`formal:math`/`formal:physics` with no
  Lean target and no lookup tools registered no longer incurs an unconditional Mathlib-lookup
  obligation it cannot discharge; it logs one line and proceeds, with the skip machine-visible via
  `mathlib_lookup_gated` in `.return-meta.json`.
- The gate definition now lives in exactly one place, so a future change to the gate's conditions
  or skip wording touches one file instead of eight.
- Two pre-existing, unrelated defects were surfaced and recorded (not fixed, per territory
  discipline): a `validate-state.sh --deep` gate10 timing margin that is tight against the current
  519-task `state.json` under load, and two `/ide`-command dead-recommendation findings in the
  `memory` extension's documentation.

## Follow-ups

- The two pre-existing defects recorded above (gate10's timing margin; the memory extension's
  `/ide` dead-command references) are outside this task's scope and were not fixed here. They
  remain open for whichever task owns `validate-state.sh`'s timeout budget and the `memory`
  extension's documentation respectively.
- None of this task's own deliverable requires further work.

## References

- `specs/408_gate_mathlib_lookup_on_lean_target/plans/01_gate-mathlib-lookup-on-lean-target.md`
- `specs/408_gate_mathlib_lookup_on_lean_target/reports/01_gate-mathlib-lookup-surfaces.md`
- `specs/408_gate_mathlib_lookup_on_lean_target/progress/phase-1-progress.json` through
  `phase-4-progress.json`
- `specs/408_gate_mathlib_lookup_on_lean_target/issues.jsonl`
