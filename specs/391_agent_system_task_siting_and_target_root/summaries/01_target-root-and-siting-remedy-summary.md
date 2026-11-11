# Implementation Summary: Task #391

- **Task**: 391 - Agent system task siting and target root
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T18:24:36Z
- **Completed**: 2026-11-11T19:58:00Z
- **Effort**: 5.75 hours (estimated)
- **Dependencies**: 372, 373 (ordering only)
- **Artifacts**: plans/01_target-root-and-siting-remedy.md, reports/01_task-siting-and-target-root.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the authoring hole that let the orchestrate conclusion stage's channel (b) file
agent-system task records into whatever repository `/orchestrate` happened to be running in, and
settled the `file_scope` deploy-path convention question in writing. All six phases of the plan
completed; Phase 6 (redeploy and verification) closed `[COMPLETED WITH EXCLUSIONS]` against two
confirmed pre-existing, unrelated gate findings.

## What Changed

- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 4b now resolves
  `target_root`/`mode_target: "global"` (byte-identical formula to `skill-meta`) immediately
  before dispatching `meta-builder-agent`, threads both fields plus the path-qualification
  imperative into the dispatch body, and states why channel (b) has no `--local` analogue.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — Conclusion
  Stage `Bash` row's enumeration gains the `GLOBAL_ROOT` resolution assignment.
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Stage 1's absent-`target_root`
  branch changed from a silent best-guess fallback to an explicit refusal (`status: "blocked"`,
  names the missing field and the calling convention, creates nothing). The `GLOBAL_ROOT`-vs-CWD
  distinction and explicit-value-always-wins precedence (global or local) survive unchanged.
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` — the stale "carried by the prompt
  today... dependent follow-up" sentence is replaced with a statement of the current mechanism:
  the agent enforces its own `target_root` requirement independently (refusing on absence), and
  the prompt instruction is defense-in-depth alongside it.
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` — new, separately titled
  "Task Siting (Where a Source-Store Task Is Created)" subsection: a task whose edit target is a
  source-store path must be created in the repository that owns that `source_dir`; kept distinct
  from the `specs/**` artifact-location exemption.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` —
  matching narrative detail anchored at the existing "Known limitation" paragraph, stating the
  siting rule's enforcement is documentary/agent-contract-only.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — "File Scope
  Field" section gains the deploy-path convention verdict: declaring both a source-store path
  and its deployed mirror is legitimate (not a field overload), with an owning-repo-vs-deploy-
  only-repo asymmetry, no new field/marker, and a cross-reference to the Task Siting subsection
  by heading.
- Deployed `.claude/**` tree regenerated via `deploy-headless.sh`; all six edited files confirmed
  byte-identical between source store and deployed mirror.

## Decisions

- Remedy mix adopted: (a) teach Step 4b to resolve and thread `target_root` [Phase 1]; a revised
  (b) that strengthens the agent's already-present `GLOBAL_ROOT` fallback into a loud refusal
  rather than adding a resolution step it already had [Phase 2]; (c) a standing task-siting rule
  kept distinct from the `specs/**` artifact-location exemption [Phase 4].
- `context/standards/postflight-tool-restrictions.md` accepted into scope at plan time (the new
  shell-variable resolution needed an enumeration entry in its Conclusion Stage `Bash` row).
- `commands/meta.md` rejected from scope at plan time: not a dispatcher, already correct, no
  mechanical gain from touching it.
- The dual-path `file_scope` convention is legitimate as observed (both paths genuinely touched
  by a source-store-targeting task's mandated redeploy); no second field or per-entry marker was
  added, since the "edit target" and "declared collision surface" readings are never in tension.

## Plan Deviations

- **Phase 6, task 3** altered: the redeploy lands correctly (all six edited files propagate
  byte-identical) but `verify-deploy.sh`'s fast-gate pass reports `RESULT=landed_verify_red`
  rather than the plan's required `RESULT=landed_verify_clean`, on two findings — gate10
  (`validate-state.sh --deep` killed at its own 60s internal timeout; confirmed to pass cleanly
  standalone in 61.4s wall-clock, a pre-existing marginal budget unrelated to this task) and
  gate20 (pre-existing orchestrator context-budget overage on files outside this task's
  `file_scope`, already surfaced during Phase 4). See the plan's Phase 6 Reasoned Exclusions
  table for the full evidence.
- **Phase 6, task 4** altered: per this dispatch's own Batch Gate Deferral directive, the full
  verification battery was not independently re-run; discharged instead via scoped
  `check-task-references.sh`/`check-record-versioning.sh` on the six edited paths plus two fast
  whole-repo structural validators (`validate-wiring.sh`, `validate-context-index.sh`), all clean.
- No other deviations across Phases 1-5 — each followed its plan exactly, confirmed via its own
  phase verification criteria.

## Enumeration of Direct `meta-builder-agent` Dispatchers (re-confirmed at implement time)

Exactly three, matching the plan's Scope Hypothesis:
1. `skills/skill-meta/SKILL.md` — already resolved `target_root` (no fix needed).
2. `context/patterns/telemetry-meta-submode.md` (via `skill-telemetry`) — already resolved
   `target_root` (no fix needed).
3. `context/contracts/conclusion-stage.md` Step 4b — fixed in Phase 1.

No fourth dispatch site exists; re-swept via two differently-shaped `grep` passes at implement
time, matching the research/plan findings.

## WHAT IS OWED — Discharge Mapping

1. Channel (b) can no longer file into an arbitrary repository — Phase 1 (target_root resolution
   and threading).
2. Every direct dispatcher enumerated, each fixed or recorded as already correct — see above.
3. `skill-meta`'s stale "carried by the prompt today" acknowledgment discharged — Phase 3.
4. The deploy-path `file_scope` convention settled in writing — Phase 5.
5. Reasoning for rejected remedies recorded — Decisions section above and the plan's own
   `## Decisions` section (commands/meta.md rejected; postflight-tool-restrictions.md accepted).

## Verification

- Build: N/A (documentation/contract repository)
- Tests: Phases 1-5 each passed their own scoped verification
  (`test-orchestrate-conclusion-aggregate.sh`, `test-return-meta-status-vocabulary.sh`,
  `test-context-reachability.sh`, `check-task-references.sh`, `check-record-versioning.sh`,
  `validate-context-budgets.sh`'s Tier 1 sub-check). Phase 6 closed with exclusions (see above).
- Files verified: Yes — all six edited files confirmed byte-identical between source store and
  deployed `.claude/**` mirror via `diff -q`.

## Impacts

- Channel (b) of the orchestrate conclusion stage can no longer silently mis-file an
  agent-system change-request task into whatever repository `/orchestrate` happens to be running
  in.
- `meta-builder-agent` now refuses loudly (rather than guessing) on any future caller that omits
  `target_root`, converting a class of silent mis-filing into a single visible, actionable error.
- A standing, documented siting rule now exists for any task whose own edit target is the source
  store, independent of this specific channel-(b) fix.
- The `file_scope` deploy-path convention has one documented answer instead of two undocumented,
  diverging per-repository conventions.

## Follow-ups

- None owed by this task. Separately-owned, already-identified conditions noted but explicitly
  not absorbed: the repo-wide agent context-budget overages (`validate-context-budgets.sh`), the
  gate10 (`validate-state.sh --deep`) 60s timeout's marginal tightness, and the backlog-audit
  semantic-scorer defect (`fix_backlog_audit_semantic_scorer`).

## References

- `specs/391_agent_system_task_siting_and_target_root/reports/01_task-siting-and-target-root.md`
- `specs/391_agent_system_task_siting_and_target_root/plans/01_target-root-and-siting-remedy.md`
- `specs/391_agent_system_task_siting_and_target_root/progress/phase-{1..6}-progress.json`
- `specs/391_agent_system_task_siting_and_target_root/handoffs/phase-{1..6}-handoff-*.md`
