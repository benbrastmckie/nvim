# Implementation Summary: Task #444

- **Task**: 444 - Retire routing_agents_hard in favour of hard_contracts across books, cslib and lean, then remove the ladder rung and gate16
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T04:10:00Z
- **Completed**: 2026-11-10T11:55:00Z
- **Effort**: ~13 hours (matches the plan's own estimate)
- **Dependencies**: None (task 445 noted as completed, unrelated gate8 work, no interaction)
- **Artifacts**: plans/01_retire-routing-agents-hard.md, summaries/01_retire-routing-agents-hard-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

All eight plan phases completed. `--hard` no longer dispatches a separate `-hard`-suffixed agent
in any of the three domains that used to declare `routing_agents_hard` (books, cslib, lean);
instead it dispatches the SAME agent as standard mode, with domain-specific behavioral
differences injected into the dispatch prompt via the manifest's `hard_contracts` block. The
migration ran in the order the plan required: contract injection was built and demonstrated per
domain BEFORE the routing block was removed, so no intermediate state silently downgraded a
`--hard` dispatch to a contract-free standard agent. The twelve now-unreachable wrapper files
(six agents, six skills) and the roughly fifty files that referenced them were retired and
converged in the same pass. gate16 and the schema/routing-guide documentation are updated to
describe the new, collapsed model as the standing state of the system, not a pending migration.

## What Changed

- `agent-system/extensions/lean/context/contracts/lean4-{anti-analysis,reference-grounding,adversarial-verification,context-hygiene}.md` — renamed from unprefixed basenames (domain-prefixed convention, prevents the deploy-merge clobber Defect A caused)
- `agent-system/extensions/lean/context/contracts/lean4-sorry-discipline.md` — new; the sorry-inventory lifecycle, Zero-Debt policy and single-phase-focus rule the standard `lean-implementation-agent.md` never carried, now a standalone injectable contract
- `agent-system/extensions/cslib/context/contracts/cslib-adversarial-verification.md` — renamed from unprefixed basename; `cslib/manifest.json` now declares `"contracts"` in `provides.context` so it actually deploys
- `agent-system/extensions/core/context/contracts/anti-analysis.md` — corrected the Domain Specialization bullet's dangling `.claude/extensions/{domain}/...` path (Defect B)
- `agent-system/extensions/lean/manifest.json`, `agent-system/extensions/cslib/manifest.json` — declare `hard_contracts.lean4` / `hard_contracts.cslib`; `routing_agents_hard` removed from all three (`books`, `cslib`, `lean`) manifests
- `agent-system/extensions/core/scripts/command-route-agent.sh` — hard branch fully collapsed (no `if effort_flag == "hard"` conditional remains); `effort_flag` survives only as a trace argument
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` — Check C deleted; Check B narrowed to `routing_agents` only
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` — Assert 2/3 retargeted to the collapsed single-rung model (13 assertions, all pass)
- Six hard skill directories deleted (`books/cslib/lean` × `research`/`implementation`); six `provides.skills` entries removed
- Six hard agent files deleted (`books/cslib/lean` × `research`/`implementation`); six `provides.agents` entries removed; every roster array in `lint-agent-contracts.sh`, its three roster tests, `books/opencode-agents.json`, and ~15 illustrative-citation files converged
- `agent-system/extensions/core/scripts/lint/collapsed-blocks/registry.tsv` row 12 retargeted from the deleted `cslib-implementation-hard-agent.md` onto `python-implementation-agent.md`; `core/manifest.json`'s `provides.scripts` updated to match
- `agent-system/extensions/core/scripts/verify-deploy.sh` — gate16 rewritten as a standing `routing_hard`/`routing_agents_hard` absence guard (was framed as a transitional migration warning); `gate-registry.data` row 16 name updated; gates NOT renumbered (documented why)
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — case (r) retargeted onto a dedicated synthetic fixture (`FIXTURE_GATE16_WARN`) declaring `routing_agents_hard` itself; new green-side case (r-e) added; also fixed an unrelated pre-existing `REPO_ROOT` depth bug discovered while verifying this phase
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — full rewrite for the contract-injection model (worked example per domain, deployed-inventory table)
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` — collapsed to the one-block-plus-one-unrelated-key model throughout
- `agent-system/extensions/core/merge-sources/claudemd.md` — generated CLAUDE.md's Hard Mode section no longer names `routing_agents_hard`

## Decisions

- **Books declares no `hard_contracts` block at all.** Its 3-tier H3 reference-grounding elaboration was judged duplicative of the generic core contract rather than worth extracting into an override file, per the research report's own framing.
- **gate16 is kept, not deleted**, as a standing absence guard — `lint-gate-registry.sh` Check E requires contiguous gate ids, so deleting it would force renumbering gates 17-27 across eight files for a gate that now costs nothing to keep.
- **`collapsed-blocks/registry.tsv` row 12 retargeted, not deleted**, onto `python-implementation-agent.md`, a verified-safe surviving exemplar of the same collapsed Stage-0 block shape.
- **`check-extension-docs.sh`'s `routing_agents_hard` resolvability arm kept as a reappearance guard**, not removed — a no-op today, but ready if the key is ever copy-pasted back in from a stale template.
- **`test-resume-scan-nonconformance.sh`'s Site C removed, not retargeted** — the skill it guarded was already routing-unreachable before this task, so the lost coverage was for dead code.

## Plan Deviations

- **Task 4.5** (test-routing-resolution.sh's lean4 sub-assertion): altered rather than deleted — retargeted to confirm hard and standard resolution are now IDENTICAL, a stronger regression guard than deletion would have left.
- **Task 4.6** (hard-miss-standard-fallback mention in hard-mode-routing.md): deferred to Phase 8's own full rewrite rather than fixed in Phase 4, as the plan itself permitted.
- No other deviations from the plan's task list. Several additive fixes beyond each phase's explicit file enumeration are recorded in the plan's own phase sections and the per-phase progress files' `deviations`/notes arrays (the plan's own instruction to "derive the list from a fresh grep... not from this enumeration" covers these).

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-routing-resolution.sh` (13/13), `test-verify-deploy-gate-selection.sh` (27/27), `test-lint-agent-contracts.sh` (57/57), `test-lint-agent-contracts-heartbeat.sh` (6/6), `test-lint-agent-contracts-handoff-section.sh`, `test-resume-scan-nonconformance.sh` (3/3), `test-lit-pipeline.sh`, `test-books-approvals-signal.sh` (68/68) — all passed
- Lints: `lint-routing-wiring.sh` (262/262), `lint-agent-contracts.sh` (377 passed, 12 pre-existing WARN, 0 FAIL), `lint-anchor-pointer-collapse.sh` (78 rows, 0 violations), `lint-gate-registry.sh` (7/7), `check-extension-docs.sh` (all extensions PASS)
- Deploy gate: `verify-deploy.sh --only-gate 3,5,6,7,13,16,18` clean; full gate set deferred to the batch-level stage per this dispatch's Batch Gate Deferral directive (3 pre-existing/unrelated findings — eager-load budget, shellcheck, dead-command-recommendation — observed consistently across every phase's redeploy, none attributable to this task)
- Files verified: Yes — final re-grep of `routing_agents_hard`/`routing_hard` across `agent-system/` returns 19 files, each individually confirmed as a deliberate survivor (gate16's absence guard + its registry row + its tests, the schema guide's own retirement note, `check-extension-docs.sh`'s reappearance guard, or historical motivating-incident/measurement-snapshot prose)

## Impacts

- **Deliberate behavior change a reviewer could mistake for a regression**: a `--hard` dispatch of any NON-lean task type now reads core's generic `anti-analysis.md` instead of lean's override — this fixes Defect A (a deploy-merge clobber that had every `--hard` dispatch of any task type silently reading lean's proof-specific contract), but is a real, visible change in what content a non-lean `--hard` dispatch's prompt carries.
- cslib's `--hard` dispatches now additionally receive `lean4-context-hygiene.md` (a deliberate, documented cross-extension dependency), since cslib's own hard-mode behavior always relied on lean's goal-state hygiene discipline but had no formal mechanism connecting the two before this task.
- The standing warning that motivated this task (gate16 WARNing on every full-gate run) is resolved: gate16 now reports `pass` in this and every other repository where no manifest declares either retired key.

## Follow-ups

- `check-extension-docs.sh`'s Rule G dangling-reference regex is not widened to catch the extension-namespaced path shape (`.claude/extensions/{domain}/...`) that caused Defect B — recorded as a non-goal since every live instance was fixed by this task's own agent retirements; the widening would only protect against recurrence.
- `--hard` planning dispatches continue to resolve `planner-agent` directly; plan parity was never required in `routing_agents_hard` and is not added by this task.

## References

- `specs/444_retire_routing_agents_hard_for_hard_contracts/reports/01_retire-routing-agents-hard.md`
- `specs/444_retire_routing_agents_hard_for_hard_contracts/plans/01_retire-routing-agents-hard.md`
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md`
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
