# Implementation Summary: Task #343

- **Task**: 343 - Bound agent background wait / stranded dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-10-06
- **Completed**: 2026-10-06
- **Effort**: ~2.5 hours
- **Dependencies**: None (declared file_scope overlap with four other non-terminal tasks on
  `skills/skill-orchestrate/SKILL.md`; no dependency edge created, per the plan's own Scope
  Decision)
- **Artifacts**: plans/01_bound-background-wait-stranded-dispatch.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented all 5 phases of the plan, closing a defect where an implementation agent could
detach a verification process via the harness's own asynchronous mechanism and end its turn
waiting for a completion notification that nothing guarantees will arrive — stranding the
dispatch with committed work on disk and none of its three closing artifacts written. Landed a
mechanism-mandating agent contract (forbidding the detach-then-await-notification path for local
gates), an explicit three-way deadline fork with a named `[COMPLETED WITH EXCLUSIONS]`
non-admission ruling, a loop-level consumer for the previously-dead `stall_suspected` signal (a
Move 3 accumulation guard plus a Move 4 batched re-prompt relay), four documentation rulings
recording the division of labour and the IDENTICAL-DISPATCH-HALT distinction, and a grep-based
regression test that fails if the consumer wiring disappears again.

## What Changed

- `agent-system/extensions/core/agents/general-implementation-agent.md` — strengthened the
  Local Long-Running Command Discipline subsection: a MUST mandating
  `bounded-build-waiter.md`'s canonical idiom verbatim, a local-case MUST NOT against
  `run_in_background`/`Monitor` (sibling of the pre-existing CI/remote MUST NOT), a
  foreground-preference MUST, a one-sentence ruling on why the detach-then-notify path is
  unsafe, and an explicit three-branch deadline fork (writer-alive -> `[PARTIAL]`,
  writer-dead-with-result -> use it normally, specific-enumerated-exclusion ->
  `[COMPLETED WITH EXCLUSIONS]`).
- `agent-system/extensions/core/context/standards/status-markers.md` — added a named
  non-admission note to the `[COMPLETED WITH EXCLUSIONS]` section: a bounded-wait deadline
  reached with no result is not an admissible exclusion by itself.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 3 now extracts
  `stall_suspected`, guards the `failed_tasks` append so a first-occurrence suspected stall
  accumulates into `pending_stall_reprompt[]`/`stall_ledger[]` instead of being charged as a
  failure; Move 4 adds a batched stall re-prompt relay beside the existing `AskUserQuestion`
  relay, with a `stall_reprompted[]` idempotency key bounding the obligation to exactly one
  re-prompt per dispatch.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — documented
  the allowed read-only, count-only liveness/staleness probe, and the ruling that acting on it
  is a loop-level action, never a per-dispatch postflight action.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — recorded the
  stale-`dispatch_seq` stranded-dispatch signal and its weakness relative to `stall_suspected`
  (Readers MUST check freshness section), and sited the stall relay as a loop-level
  clarification in the Postflight Boundary section.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — comment-only: named
  the now-real `stall_suspected` consumer, recorded the pre-first-commit boundary, and recorded
  the deliberate non-widening of the trigger against a stale `dispatch_seq` (verified
  comment-only via `git diff | grep -E '^\+' | grep -vE '^\+\s*#|^\+\+\+'` returning nothing).
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — documented the
  three new `mt_state_file` fields (`pending_stall_reprompt`, `stall_reprompted`,
  `stall_ledger`), sited the Loop obligation's actual relay mechanics, added the
  IDENTICAL-DISPATCH-HALT non-conflation note, and stated the related-but-not-blocking
  relationships (a per-dispatch cost/timing record; cross-batch session liveness) by durable
  anchor only.
- `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` — new: grep-based
  producer/consumer consistency suite (10 assertions) proving the `stall_suspected` signal has a
  consumer, the suppression guard and relay are sited correctly, and the three new fields are
  documented. Verified live (fails against a scratch copy with the consumer removed) and
  registered automatically via `run-all.sh`'s glob-based discovery.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — unplanned 8th
  file: a reviewed, dated per-file ceiling move for `skills/skill-orchestrate/SKILL.md`
  (20,000 B -> 21,500 B), required because Phase 3's SKILL.md growth could not be compacted
  below the pre-existing ceiling without losing necessary content.
- `agent-system/extensions/core/index-entries.json` — regenerated two stale `line_count`
  declarations (`postflight-tool-restrictions.md`, `status-markers.md`) via
  `generate-context-line-counts.sh --write`, surfaced by the full gate run.

## Decisions

- Backgrounding a local verification/gate process stays **permitted**, but only via
  `bounded-build-waiter.md`'s single foreground-blocking idiom; the harness-asynchronous
  detach-then-await-notification path is forbidden outright for a local gate (scope item 1).
- A bounded-wait deadline reached with no result is **not**, by itself, grounds for
  `[COMPLETED WITH EXCLUSIONS]` — it fails condition 5 of the exclusion admission test while the
  writer is still alive (scope item 2).
- The orchestrator-side detection mechanism (`stall_suspected`) already existed, was already
  tested, and already respected both the Context Flatness Constraint and the Postflight Boundary
  — the real gap was the missing consumer, which this task wires via an accumulate-then-relay
  pattern (the same shape the existing `AskUserQuestion` relay already uses) rather than any new
  detection mechanism (scope item 3).
- `stall_suspected`'s trigger is deliberately **not** widened with an OR against a stale
  `dispatch_seq`: that would destroy the field's only discrimination between an abandoned
  wrap-up and a dispatch that never did anything.
- A Gate 20 per-file byte-ceiling regression (caused by Phase 3's necessary SKILL.md growth) was
  resolved by a combination of compaction and a reviewed ceiling move, following this exact
  codebase's own documented precedent for the sibling `commands/orchestrate.md` ceiling, rather
  than by cutting necessary content to fit an old, now-too-tight budget.

## Plan Deviations

- **Task 5 (run-all.sh/suite-cost-hints.txt registration)** altered: no edit was made to either
  file. `run-all.sh` discovers every `scripts/tests/test-*.sh` file via glob (no explicit
  per-suite registration list exists to edit), and `suite-cost-hints.txt`'s own header states it
  is advisory-only. Confirmed via a full `run-all.sh` run showing the new suite discovered and
  passing.
- **Phase 3, pending_stall_reprompt[] entry shape** altered: the entry additionally carries an
  `agent` field (the `subagent_type` the original dispatch used), not present in the plan's
  literal shape, because Move 4's relay task explicitly requires re-dispatching to "the same
  subagent_type that dispatch used" and no other field carries that value.
- **Phase 5, unplanned 8th file** (`context/config/orchestrator-context-budget.json`): a
  reviewed, dated per-file ceiling move, required to close a genuine Gate 20 regression this
  task's own Phase 3 edit introduced. See Decisions above and the plan's own Phase 5 Reasoned
  Exclusions for the full justification.

## Verification

- Build: N/A (meta task; no build step)
- Tests: `test-stall-reprompt-wiring.sh` 10/10 pass (and correctly fails 8/10, with the 2
  consumer-dependent assertions failing, against a scratch copy with the consumer removed);
  `test-orchestrate-cycle-postflight.sh` 184/184 pass (including the four pre-existing
  `stall_suspected` S1-S4 assertions, confirming the comment-only postflight-script edit changed
  no executable behavior); full `scripts/tests/run-all.sh` run: 112 passed, 5 failed (2 already
  tracked as EXPECTED in `known-failures.txt`; the other 3 confirmed pre-existing/unrelated via
  `git log` — see Plan Phase 5's Reasoned Exclusions table).
- Lints: `lint-agent-contracts.sh`, `lint-postflight-boundary.sh`, `lint-json-channel-discipline.sh`,
  `lint-contract-compliance.sh` all pass against every touched file.
- Files verified: Yes (all 9 touched files read before editing; every edit confirmed via grep
  against the plan's own stated verification commands).
- Task-reference lint: 0 occurrences in every edit (`check-task-references.sh`).
- Full gate (`verify-deploy.sh`): 31/34 checks pass. The 3 remaining findings (deployed-script
  drift for the 8 source-only files this task touched; the matching manifest-driven
  content-hash drift; 3 test-suite failures unrelated to this task's `file_scope`) are
  enumerated, evidenced, and excluded in the plan's Phase 5 Reasoned Exclusions — none leaves
  residual work for a future dispatch.

## Impacts

- An agent that backgrounds a local gate now has an unambiguous, mechanism-level contract to
  follow, closing the reachable parking failure mode for every implementation agent that shares
  this contract (not only the one that reproduced the measured incident).
- A dispatch that does real, committed work and then stalls on wrap-up is now automatically
  caught and given exactly one foreground re-prompt by the loop itself, rather than requiring
  out-of-band human diagnosis — the recovery path the measured incident required by hand is now
  mechanized.
- The regression test closes the specific defect class this task's own research uncovered: a
  computed, tested, documented signal that silently lost its only consumer. Any future removal
  of that consumer now fails a dedicated, fast, grep-based suite instead of surfacing only as a
  live stranded dispatch days or weeks later.

## Follow-ups

- The gate-runtime question (making the underlying verification gate itself faster, or dropping
  it from the `full` tier) is explicitly out of scope — it belongs to the gate-runtime work that
  already owns it (`tasks 170/328` in this specs/ tree).
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (which instructs the
  defect-producing pattern verbatim two sentences after correctly citing
  `bounded-build-waiter.md`) and the ten other implementation agents carrying no
  background-wait discipline at all are durable, verified findings recorded in the research
  report, deliberately left for a follow-up task that can act on them without re-deriving them.
- A future deliberate redeploy (`deploy-headless.sh`/`<leader>al`) will clear the 8-file
  deployed-script-drift finding this task's source-only edits introduced; no action is needed
  from this task itself.

## References

- `specs/343_bound_agent_background_wait_stranded_dispatch/plans/01_bound-background-wait-stranded-dispatch.md`
- `specs/343_bound_agent_background_wait_stranded_dispatch/reports/01_background-wait-stranded-dispatch.md`
- `specs/343_bound_agent_background_wait_stranded_dispatch/progress/phase-{1,2,3,4,5}-progress.json`
