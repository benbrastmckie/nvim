# Implementation Summary: Task #300

- **Task**: 300 - Resolve AskUserQuestion's unreachability in dispatched subagents: verify the mechanism, correct the frontmatter standard's tool-inheritance claim, and rehome every user-choice gate
- **Status**: [COMPLETED]
- **Started**: 2026-10-06T20:21:00Z
- **Completed**: 2026-10-06T23:45:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_rehome-askuserquestion-gates.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Executed the 7-phase plan adopting Resolution 1 (rehome the gates), the only remediation
research's live measurement supports. Corrected all three "inherit the full tool set" claims and
settled every optional row of `agent-frontmatter-standard.md`'s Supported Fields table (measured
or explicitly unverified); dropped the `isolation` row on its drop branch with the justifying
probes recorded and both of its mirrors (`lint-agent-contracts.sh`, `agent-template.md`) brought
into agreement. Relocated `/meta`'s interactive interview (Interview Stages 0-5, 516 lines,
diff-confirmed byte-identical to the original) and the prompt-mode clarification/confirmation
steps into a new `core/context/workflows/meta-interview.md`, read and executed by `skill-meta`'s
own pre-delegation stage, which gained `AskUserQuestion` in its `allowed-tools:`. Stripped the
self-instructing `AskUserQuestion` mandate from `meta-builder-agent.md` and from 22 further agent
files across the founder, epidemiology, present, and literature extensions (one file,
`deck-planner-agent.md`, was already correct and needed no edit). Added a capped fork
prompt-scoping hazard addendum to `fork-patterns.md` (one subsection, one table row, one
qualifier). Landed a structural regression fixture
(`core/scripts/tests/test-askuserquestion-rehome.sh`, 14 PASS) and narrowed this task's
`file_scope` from 4 coarse directory entries to 34 explicit paths, clearing the standing
coarse-scope warning.

## What Changed

- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` — corrected both "inherit the full tool set" occurrences with the measured exception; added a Verified column to the Supported Fields table (measured/unverified per row); dropped the `isolation` row with Probes B/C and the deliberate-non-probe reason recorded
- `agent-system/extensions/core/docs/templates/agent-template.md` — corrected the third inheritance-claim occurrence; dropped `isolation` from the field-name pointer list
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — removed `["isolation"]=1` from `SUPPORTED_KEYS`
- `agent-system/extensions/core/docs/fork-patterns.md` — pointer to the standard's corrected section; capped fork prompt-scoping hazard addendum (one subsection, one table row, one qualifier)
- `agent-system/extensions/core/context/workflows/meta-interview.md` — new: the `/meta` interview relocated verbatim (interactive + prompt-mode clarification/confirmation)
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` — `AskUserQuestion` added to `allowed-tools`; new pre-delegation interview stage; subagent-will list and postflight MUST NOT corrected; `collected_answers` added to the delegation context
- `agent-system/extensions/core/index-entries.json` — one entry appended for `workflows/meta-interview.md`
- `agent-system/extensions/core/manifest.json` — one `provides.scripts` entry appended for the new test file (discovered necessary by the gate itself)
- `agent-system/extensions/core/agents/meta-builder-agent.md` — interview stages removed (relocated), three mandate statements removed, MUST NOT bullets added (cslib-vet-agent.md phrasing)
- 13 founder/epidemiology agent files — self-instruction removed, non-interactive fallback kept where present, tools-list advertisements dropped
- 7 present agent files + 2 present SKILL.md files — same correction; the two skills gained one load-bearing-placement sentence each
- `agent-system/extensions/literature/agents/literature-agent.md` — `AskUserQuestion` dropped from `tools:`; inertness note added
- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` — new structural regression fixture (14 PASS)
- `specs/state.json` / `specs/TODO.md` — `file_scope` narrowed to 34 explicit paths

## Decisions

- Resolution 1 (rehome) adopted per the plan; Resolution 3 (fix frontmatter) was already foreclosed by measurement before this dispatch began.
- `skill-slide-critic`'s interactive loop runs *after* its `Agent` dispatch (not before, as `skill-slide-planning` does) — both place the asking in the skill, never the agent, which is the property that matters; the added sentence states each skill's own correct ordering.
- `legal-analysis-agent.md`'s full two-way interactive protocol with `skill-consult` is documented as a known architectural gap rather than implemented, since `skill-consult` is outside this task's `file_scope`.
- `deck-planner-agent.md` required no edit — already matches the proven-correct pattern verbatim.

## Plan Deviations

- **Phase 3 verification** ("`grep -n 'AskUserQuestion'` returns exactly one hit"): 4 hits remain, all unavailability/pointer statements (none instructs a call) — see plan Phase 3 Verification annotation.
- **Phase 4** (`deck-planner-agent.md`): no edit needed, file already correct.
- **Phase 4** (`legal-analysis-agent.md`): documented the skill-consult round-trip gap rather than implementing it (out of `file_scope`).
- **Phase 5** (`skill-slide-critic` ordering): asks after its dispatch returns, not before — see plan Phase 5 Verification annotation.
- **Phase 7** (`manifest.json`): one additional file edit required, discovered by the gate itself (script registration requirement not anticipated in any phase).
- **Phase 7** (Gate 8): concluded within budget but surfaced 4 pre-existing failures entirely outside this task's `file_scope` (confirmed via `SUT_SRC`/`resolve_candidate` grep) — closed `[COMPLETED WITH EXCLUSIONS]` with the four named substitute suites as binding evidence, all green.

## Verification

- Build: N/A (documentation + agent-file system)
- Tests: `test-askuserquestion-rehome.sh` 14/14 PASS; `test-lint-agent-contracts.sh` 26/26 PASS; `test-index-entries-schema.sh` 9/9 PASS; `check-task-references.sh` 0 occurrences; `lint-agent-contracts.sh --verbose` 195 passed / 0 warnings / 0 failed throughout all 7 phases
- Files verified: Yes (diff-confirmed verbatim relocation; `wc -l` cross-checks at each phase)
- Full gate (`verify-deploy.sh`, no `--skip-slow`): 32 of 34 checks pass; 2 excluded with evidence — see Phase 7's `#### Reasoned Exclusions` record in the plan

## Impacts

- `/meta`'s interactive and prompt modes can now actually ask the user, since the asking happens in `skill-meta`'s own execution rather than inside a dispatched subagent that cannot call `AskUserQuestion`.
- 23 further agent files across 5 extensions no longer instruct themselves to call a tool they cannot reach; `literature-agent.md`'s allowlist is honest about the measured runtime grant.
- `agent-frontmatter-standard.md` is now an accurate record of measured harness behavior rather than an unverified claim, for every optional frontmatter field.
- The roadmap's stated premise for a downstream `/approve`-type task ("it needs AskUserQuestion to work in a dispatched subagent") is falsified by this task's measurement; that task's approach needs re-derivation from the rehome pattern (not acted on here, per non-goals).

## Follow-ups

- **Primary-session- or user-owned, NOT self-verified by this dispatch**: run `/meta` with no arguments after this redeploy and confirm it completes a real interactive interview and creates a task. A dispatched subagent cannot call `AskUserQuestion` — that is the exact fact this task fixes — so this implementer cannot take this check itself.
- `agent-system/extensions/founder/agents/legal-analysis-agent.md`'s full two-way interactive protocol with `skill-consult` (per-finding review loop) is documented as a known gap, not implemented; a future task should wire `skill-consult` to actually run that loop, consuming this agent's structured finding output.
- The two foreign, pre-existing defects observed while running the shared gate (both already logged via `issue-record.sh`, class `foreign-defect-observed`) are not fixed here, as they belong to other tasks: (1) `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` is on disk but not registered in `core/manifest.json`'s `provides.scripts` (added by the sibling task's own commit, already marked COMPLETED); (2) 4 `run-all.sh` suites (`test-orchestrate-cycle-plan.sh`, `test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`, `test-typst-element-lint.sh`) fail for reasons unrelated to this task.

## References

- `specs/300_askuserquestion_unreachable_in_subagents/plans/01_rehome-askuserquestion-gates.md`
- `specs/300_askuserquestion_unreachable_in_subagents/reports/01_askuserquestion-subagent-reachability.md`
- `specs/300_askuserquestion_unreachable_in_subagents/progress/phase-{1..7}-progress.json`
- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- `agent-system/extensions/core/context/workflows/meta-interview.md`
- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh`
