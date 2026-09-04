# Implementation Summary: Task #143

- **Task**: 143 - Build orchestrate-cycle-postflight.sh: per-task postflight as one script (absorbs the MT handoff gates)
- **Status**: [COMPLETED]
- **Started**: 2026-09-03T19:04:42Z
- **Completed**: 2026-09-03T22:15:00Z
- **Effort**: ~6 hours (all 7 phases)
- **Dependencies**: 147 (satisfied and archived)
- **Artifacts**: plans/01_cycle-postflight-script.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `orchestrate-cycle-postflight.sh`, the single per-task postflight composer for
`/orchestrate` (Stage A.4 of `specs/PATH.md`), and cut BOTH engines (single-task Stage 5,
multi-task Stage MT-4) over to calling it exclusively. Covers the mtime staleness gate and
`dispatch_seq` identity gate this task originally scoped, plus the widened WORK items the
superseding description absorbed: return-meta recovery with `dispatch_seq` awareness,
writer-contract-aware defect recording, status transition with the completion-claim gate,
artifact linking and the multi-task artifact-round advance, a `modified_files`-vs-`file_scope`
excursion advisory, `user_decision` relay, per-task scoped commit, multi-task-scoped state/lock
bookkeeping, and (added during Phase 7) the stray-handoff sweep, absorbed into the one script so
both engines get it. All 7 plan phases are complete; Phase 7 closed as
`[COMPLETED WITH EXCLUSIONS]` — two items (a live externally-observed multi-task cycle, and two
pre-existing verify-deploy.sh findings unrelated to this task) are recorded as reasoned
exclusions, not residual work.

## What Changed

**Phases 1-6 (script build, tested and committed prior to this dispatch)**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — new script implementing
  WORK (a) through (j): both handoff gates, return-meta recovery, evidence corroboration, D1's
  writer-contract allowlist, the status-transition case ladder with the completion-claim gate and
  monotonic-max clamp, artifact link, artifact-round advance, the excursion advisory,
  `user_decision` relay, per-task scoped commit, multi-state update, per-task lock release, and
  the final compact JSON output.
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — added an optional 3rd
  positional `<expected_dispatch_seq>` (D2), gracefully degrading to mtime-only on an absent field
  and rejecting a mismatch with a new `META_DISPATCH_SEQ_MISMATCH` reason token.
- `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md` — new
  `dispatch_seq` field specification and copyable template fragment.
- `agent-system/extensions/core/agents/{general-research-agent,planner-agent,general-implementation-agent}.md`
  — updated to echo `dispatch_seq` into `.return-meta.json`.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — new "Writer-Contract
  Determination (D1)" section.
- `agent-system/extensions/core/manifest.json` — registered the new script and its test suites.

**Phase 7 (this dispatch — the live cutover)**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — extended (three
  preceding green sub-steps, before the atomic batch):
  - Added `halt` and `infra_exempt_cycle` boolean output fields. Neither engine could apply
    correct loop-control from `verdict` alone: `verdict="failed"` covers both a genuine
    in-vocabulary `dispatch_status="failed"` (must NOT halt) and an off-schema status (MUST halt);
    `verdict="defer"` covers both a corroborated infra-exempt cycle (must NOT charge
    `cycle_count`) and ordinary in-budget outcomes (must charge). 5 new assertions.
  - Absorbed the stray-handoff sweep (previously single-task-only, via
    `orchestrate-stage5-gates.sh`) so both engines get it by construction — resolving the
    originating dispatch's own open "decide and record the reasoning either way" question. 4 new
    assertions.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — added a `force` boolean field
  to each dispatch row (live and `--dry-run` paths): the only point in the pipeline where "was
  this task's phase forced this cycle" is still observable, since `force_phases_remaining` is
  popped before the row is built. Threaded by Stage MT-4 as `--force-invoked`. 4 new assertions.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the cutover itself:
  - Stage 5 (single-task): replaced the inline mtime/`dispatch_seq` gate pair, the
    `orchestrate-stage5-gates.sh` call, and the `orchestrate-stage5-postflight.sh` "Shared
    postflight tail" with one call to `orchestrate-cycle-postflight.sh`. Caller-side prose now
    handles ONLY what the script must not own: `halt`/`cycle_count`/`EXIT (partial)` loop control,
    `user_decision` surfacing to the human (new — no prior consumer existed), Defect 6's
    marker/handoff crosscheck (re-derives its own read-only view of the accepted handoff, since
    the script's compact JSON doesn't carry raw prose), and drift detection.
  - Stage MT-4 (multi-task): replaced the ~450-line six-step per-task postflight body (recovery,
    corroboration, status transition, artifact link, scoped commit, lock release) with one call
    per dispatched task, iterating the same `plan_json.dispatch[]` rows the dispatch-composition
    loop already produces. Two small supplemental caller-side checks remain (the script does not
    own loop-control): a genuinely-missing/declined outcome still charges `failed_tasks`
    (idempotent re-add if the script already did), and a per-task `MAX_INFRA_FAILURES` cap check
    (the script increments/persists `infra_failures[$t]`; the cap decision is the caller's).
  - Retired the local single-task `append_detected_defect_mt` shim and the MT-4
    `append_detected_defect_mt` function — both engines now record defects directly against their
    own store (loop guard / multi-state file) from inside the shared script.
  - `## MUST NOT (Context Flatness Constraint)` trimmed to the constraint itself plus a pointer;
    the two detailed "Recovery exception" narratives relocated.
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md` — new,
  the relocated narrative (what the script owns vs. the callers, the two Context Flatness
  recovery exceptions in full, the `halt`/`infra_exempt_cycle` contract, the stray-sweep and
  `force`/`force_invoked` additions, and what's left orphaned).
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` — rewritten from
  sentinel-region extraction (`dispatch-seq-gate:begin`/`:end`, now removed from `SKILL.md`) to
  direct invocation of `orchestrate-cycle-postflight.sh` in a sandbox, exercising the same 4 cases
  (match / mismatch-inside-window / old-mtime / absent-seq) via black-box accept/reject detection.
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` — retargeted (a
  genuine regression caught by the mandatory full gate run, not a pre-planned Phase 7 item):
  `dispatch_status`/`dispatch_summary`/`phases_completed`/`phases_total`/`plan_markers_verified`/
  `artifacts[0].*` extraction now points at the script; `blockers` stays targeted at SKILL.md's
  own caller-side re-derivation; `next_action_hint`/`continuation` retired as dead reads with no
  live consumer in either file.
- `agent-system/extensions/core/index-entries.json` — fixed two `line_count` entries
  (`formats/return-metadata-file.md` 675→695, `contracts/return-meta-artifacts-template.md`
  96→124) that had drifted stale since Phase 1's own edits to those files, caught by
  `verify-deploy.sh` gate3 (never run during Phases 1-6, per the Phase 6 handoff).
- `agent-system/extensions/core/commands/orchestrate.md`,
  `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`,
  `agent-system/extensions/core/scripts/system-defect-record.sh` — small accuracy fixes
  (detecting-site string examples, a stale script-name reference) to stay consistent with the
  cutover.

## Decisions

- D1/D2 (from Phases 1-6): implemented exactly per the plan's Design Decisions section; not
  revisited.
- **`halt`/`infra_exempt_cycle` output fields** (new this phase): added to the already-tested
  script rather than reconstructing the distinction from `verdict` string matching at each of the
  two call sites, keeping the disambiguation in one place.
- **`force` dispatch-row field** (new this phase): added to `orchestrate-cycle-plan.sh` — the
  only correct place to capture it, since the information is otherwise lost by postflight time.
- **Stray-handoff sweep**: absorbed into the shared script (not left single-task-only, not
  bolted on as a second per-engine call) — the strongest form of "closing the gap for both
  engines," matching the whole task's own framing.
- **`user_decision` surfacing**: implemented as the minimal safe behavior given no
  `.decisions.json` reader exists yet anywhere in the codebase (confirmed by search) — the
  orchestrator prints the question/options/recommendation and, for a `blocking: true` payload,
  halts via `EXIT (partial)` with a clear re-run instruction; a `blocking: false` payload is
  logged and the loop continues. Building a `.decisions.json` writer/reader pair was judged
  premature infrastructure outside this task's own WORK list.
- **CHECKPOINT 3 in `commands/orchestrate.md`** (single-task's own end-of-invocation commit/
  cleanup step) was deliberately left untouched. Per-cycle commits now happen inside
  `orchestrate-cycle-postflight.sh` itself (WORK (i)), so CHECKPOINT 3 becomes a harmless
  end-of-invocation safety net for the completion branch's `.return-meta.json` deletion — not
  redundant in a harmful sense, and not in this task's declared file list. Left as a documented,
  known follow-up rather than an unscoped structural change.
- **verify-deploy.sh's remaining 2 findings**: diagnosed, confirmed pre-existing and unrelated
  (git blame + gitignore/mtime inspection), reported rather than fixed — see the plan's own
  Phase 7 `#### Reasoned Exclusions` table for the full record and evidence.

## Plan Deviations

See `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/progress/phase-{1..7}-progress.json`
for the complete per-phase `deviations` arrays. Phase 7's own six deviations (three preceding
green sub-steps outside the declared atomic batch, the reader-parity regression fix, the
index-entries.json fix, and the two reasoned exclusions) are recorded there and in the plan's own
Phase 7 `#### Reasoned Exclusions` table.

## Verification

- Build: N/A (shell scripts / markdown skill instructions)
- Tests: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — **68/68 suites passed, 0
  failed** (source-store mode), including the retargeted `test-handoff-dispatch-identity.sh` (8
  assertions) and `test-handoff-reader-parity.sh` (15 assertions).
  `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — 101 passed, 0
  warnings, 0 failed.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` — 27/29 gates passed after
  redeploy (up from 26/29 before the index-entries.json fix); the 2 remaining findings are
  pre-existing and unrelated to this task (see Decisions above and the plan's Reasoned
  Exclusions table).
- `grep -c 'dispatch-seq-gate' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  returns 0.
- Bytes removed from `SKILL.md`: 225553 → 183025 bytes (**42528 bytes removed, ~18.9% net
  shrink**), measured via `git show <pre-Phase-7-commit>:...SKILL.md | wc -c` vs. `wc -c` on the
  post-cutover file.
- Files verified: Yes — every new/modified file read back; every new/retargeted test suite run
  standalone and as part of the full gate set.
- Live multi-task cycle: NOT run from within this dispatch — see Follow-ups.

## Impacts

- Both `/orchestrate` engines now share ONE postflight implementation instead of two
  independently-maintained bodies. The originally-scoped defect (Stage MT-4 trusting any handoff
  that happens to exist, with neither the mtime staleness gate nor the `dispatch_seq` identity
  gate) is closed by construction — both gates now apply to both engines because there is only
  one implementation of them.
- Two multi-task gaps absorbed as part of this consolidation, both closed by construction: the
  multi-task artifact-round advance (`next_artifact_number` never advanced on a multi-task
  dispatch before this task), and the multi-task stray-handoff sweep.
- `SKILL.md` shrank by ~18.9% (42528 bytes), materially reducing the file both `/orchestrate`
  engines' own maintainers read on every future change.
- Two real bugs were found and fixed during Phases 1-6 hand-testing (recorded in the earlier
  handoff): a bash parameter-expansion landmine and a stdout-leak chain that would have corrupted
  the script's single-JSON-line contract.

## Follow-ups

- **Live multi-task cycle observation**: the next `/orchestrate` invocation in multi-task mode
  will exercise Stage MT-4's new per-task postflight call live; no code change is expected, this
  is an observational confirmation only (the code path is already exhaustively fixture-tested).
- **verify-deploy.sh gate12** (`test-force-phases.sh` hand-rolled state.json writes) and
  **gate13** (orphan `.claude/index-entries.json`): pre-existing, unrelated to this task; belong
  to whichever task owns `test-force-phases.sh` (last touched by an unrelated task's own Phase 7)
  or a future deploy-tree `--wipe` cycle, respectively.
- **CHECKPOINT 3 granularity** (`commands/orchestrate.md`): now a redundant-but-harmless
  end-of-invocation safety net for single-task mode, since per-cycle commits happen inside
  `orchestrate-cycle-postflight.sh` itself. A future task could simplify it to just the
  `.return-meta.json` cleanup, dropping its own now-largely-redundant commit call — not attempted
  here (out of this task's declared file list).
- `orchestrate-stage5-gates.sh` and `orchestrate-stage5-postflight.sh` are now orphaned (zero call
  sites). Left in the tree per this task's own Non-Goals ("deleting the single-task engine" is a
  separate, already-tracked task).

## References

- Plan: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/plans/01_cycle-postflight-script.md`
- Research: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/reports/01_cycle-postflight-consolidation.md`
- Handoff: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/handoffs/phase-6-handoff-20260903T195215Z.md`
- Progress: `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/progress/phase-{1..7}-progress.json`
- New docs: `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md`
