# Implementation Summary: Task #143

- **Task**: 143 - Build orchestrate-cycle-postflight.sh: per-task postflight as one script (absorbs the MT handoff gates)
- **Status**: [IN PROGRESS]
- **Started**: 2026-09-03T19:04:42Z
- **Completed**: (Phase 7 remaining)
- **Effort**: ~3 hours (Phases 1-6 of 7)
- **Dependencies**: 147 (satisfied and archived)
- **Artifacts**: plans/01_cycle-postflight-script.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `orchestrate-cycle-postflight.sh`, the new ONE-script per-task postflight composer for
`/orchestrate` (Stage A.4 of `specs/PATH.md`), covering the mtime staleness gate and `dispatch_seq`
identity gate this task originally scoped, plus the widened WORK items the superseding description
absorbed (return-meta recovery with `dispatch_seq` awareness, writer-contract-aware defect
recording, status transition with the completion-claim gate, artifact linking and round advance,
a `modified_files`-vs-`file_scope` excursion advisory, `user_decision` relay, per-task scoped
commit, and multi-task-scoped state/lock bookkeeping). Phases 1 through 6 of the plan's 7 are
complete, tested, and committed; Phase 7 (the live both-engine cutover of `SKILL.md`) is handed
off to a follow-up dispatch — see the phase-6 handoff artifact for the full rationale and the
exact next action.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — new, ~830-line script
  implementing WORK (a) through (j): both handoff gates, return-meta recovery, evidence
  corroboration, D1's writer-contract allowlist, the status-transition case ladder with the
  completion-claim gate and monotonic-max clamp, artifact link, artifact-round advance, the
  excursion advisory, `user_decision` relay, per-task scoped commit, multi-state update, per-task
  lock release, and the final compact JSON output.
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — added an optional 3rd
  positional `<expected_dispatch_seq>` (D2), gracefully degrading to mtime-only on an absent field
  and rejecting a mismatch with a new `META_DISPATCH_SEQ_MISMATCH` reason token.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new, 21
  assertions covering all 5 acceptance conditions and 3 invariants.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` — new, 7
  assertions covering the D2 addition.
- `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md` — new
  `dispatch_seq` field specification and copyable template fragment.
- `agent-system/extensions/core/agents/{general-research-agent,planner-agent,general-implementation-agent}.md`
  — updated to echo `dispatch_seq` into `.return-meta.json`.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — new "Writer-Contract
  Determination (D1)" section recording the allowlist mechanism and how to register a future
  writer.
- `agent-system/extensions/core/manifest.json` — registered the new script and both new test
  suites.

## Decisions

- D1 (writer-contract allowlist) and D2 (dispatch_seq on the return-meta channel) implemented
  exactly per the plan's own Design Decisions section.
- Recorded, documented scope decision: `orchestrate-cycle-postflight.sh` accepts
  `--dispatch-seq`/`--dispatch-start-ts` as explicit optional flags beyond the plan's literal
  Phase 2 flag enumeration, because single-task `/orchestrate` has never persisted a per-cycle
  `dispatch_seq`/`dispatch_start_ts` anywhere — only an orchestrator-turn-local shell variable.
  Multi-task callers may omit both; the script derives them from the multi-state file.
- The multi-state-update and per-task-lock-release halves of WORK (j) are scoped to the
  multi-task engine only (detected via an empty `--loop-guard-file`) — single-task mode holds its
  lock for the whole invocation and has no multi-state bookkeeping at all, a distinction that
  follows necessarily from the two-engine architecture already established in Phase 2.
- `is_live()` (the `--dry-run` gate) leaves exactly one documented, deliberate exception:
  `skill_gate_completion_claim`'s own internal, non-fatal `system-defect-record.sh` call in its
  Case 3/3 refuse branch — a shared function this script does not own or duplicate.

## Plan Deviations

- Phase 2.3 (flag enumeration): added `--dispatch-seq`, `--dispatch-start-ts`, and
  `--command-suffix`, absent from the plan's literal list, for the reason recorded above.
- Phase 2.6 (detecting-site suffixes): used `:cycle-postflight-*` suffixes rather than the
  single-task engine's own `:stale-handoff`/`:dispatch-seq-mismatch`, so the two coexisting gate
  implementations (this script's, and SKILL.md's still-live inline ones) stay distinguishable in
  the defect ledger until Phase 7's cutover removes the inline ones.
- Phase 5 (multi-state update, lock release): scoped to the multi-task engine only, as recorded
  above and in the plan's own annotated checklist.
- Phase 4's off-schema `verdict` surfacing: the banner/record/no-transition land in Phase 4 as
  specified; the `offschema_dispatch_status` field feeding the final `verdict` mapping is wired in
  Phase 5, per the plan's own phase split (Phase 5 owns "output").

## Verification

- Build: N/A (shell scripts)
- Tests: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — **68/68 suites passed, 0
  failed** (source-store mode), including both new suites.
  `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — 101 passed, 0
  warnings, 0 failed.
- Files verified: Yes — every new/modified file read back and hand-tested against sandbox
  fixtures reproducing both live incidents this task's dispatch named
  (`evt_1787614360544_SgKpRP`, `evt_1788246742189_Fodegl`) before the fixture suite formalized
  them.
- `verify-deploy.sh` deliberately NOT run this dispatch — see the phase-6 handoff's "What NOT to
  Try" section (concurrent sibling `/orchestrate` dispatches in the same batch share the deployed
  `.claude/` tree; a redeploy belongs to the dispatch that owns Phase 7's live cutover).

## Impacts

- No live behavior changed yet — Phases 1-6 are entirely additive (the new script and the
  `dispatch_seq` schema/contract additions have no caller until Phase 7 wires them in).
- Once Phase 7 lands, both `/orchestrate` engines will share one postflight implementation
  instead of two independently-maintained bodies, closing the originally-scoped defect (Stage
  MT-4 trusting any handoff that happens to exist) by construction.
- Two real bugs were found and fixed during hand-testing before they could reach the fixture
  suite or a live cutover: a bash parameter-expansion landmine (`"${var:-{}}"` silently appending
  a stray `}`) that was corrupting a status read on the non-recovered path, and a stdout-leak
  chain (`git-commit-scoped.sh`, `update-task-status.sh` via `skill_postflight_update`,
  `generate-todo.sh` via `skill_link_artifacts`) that would have corrupted the script's
  single-JSON-line stdout contract for every caller.

## Follow-ups

- Phase 7: both-engine cutover, prose relocation to `docs/architecture/`, retargeting
  `test-handoff-dispatch-identity.sh`, byte-removal measurement, a live multi-task `/orchestrate`
  cycle run, and the full gate run including `verify-deploy.sh`. See the phase-6 handoff artifact
  (`handoffs/phase-6-handoff-20260903T195215Z.md`) for the complete next-action detail, the
  pre-answered Scope Hypothesis grep (a third file, `test-handoff-reader-parity.sh`, references
  the sentinel only in a harmless historical comment — not part of the required atomic batch),
  and the concurrency reason deploy verification was deferred.

## References

- Plan: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/plans/01_cycle-postflight-script.md`
- Research: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/reports/01_cycle-postflight-consolidation.md`
- Handoff: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/handoffs/phase-6-handoff-20260903T195215Z.md`
- Progress: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/progress/phase-{1..6}-progress.json`
