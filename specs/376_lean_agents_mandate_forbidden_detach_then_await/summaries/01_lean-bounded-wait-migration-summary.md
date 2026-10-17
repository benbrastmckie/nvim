# Implementation Summary: Task #376

- **Task**: 376 - Lean implementation agents mandate the detach-then-await-notification path core forbids, stranding dispatches mid-phase
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T07:08:00Z
- **Completed**: 2026-10-17T09:05:00Z
- **Effort**: ~2 hours
- **Dependencies**: None (393 already completed)
- **Artifacts**: plans/01_lean-bounded-wait-migration.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The lean extension's two implementation agents instructed a dispatched agent to background a
`lake build` via the harness's own `Bash(run_in_background: true)` tool parameter and then end
its turn awaiting a completion notification — the exact shape
`core/agents/general-implementation-agent.md` forbids, and the shape that stranded a measured
`/orchestrate` dispatch mid-phase. This task traced the defect to a self-contradiction in
`long-builds.md`, rewrote it and every downstream lean contract site to prescribe
`bounded-build-waiter.md`'s bounded single-call idiom instead, propagated the canonical
MUST/MUST NOT bullet pair to the two implementation agents, discharged
`lint-agent-contracts.sh` Check K's now-stale exclusion for them, redeployed, and created a named
successor task for the cross-extension propagation-architecture question.

## What Changed

- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` — resolved the
  self-contradiction between "Obligation 1: detach" (which previously mandated
  `Bash(run_in_background: true)`) and "Blocking on a detached build" (which already pointed at
  the bounded idiom); rewrote the canonical invocation to show the complete idiom plus a
  preference order (plain foreground when it fits one call, detach-plus-bounded-waiter
  otherwise, a sequence of bounded calls for builds exceeding the ceiling outright); merged
  "Blocking on a detached build" into "Completion discipline"; added a "Which processes this
  anchor governs" section scoping the mandate to `lake`-family invocations only; recorded that
  `lake-build-guard.sh` already blocks synchronously and needs no new blocking mode.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — rewrote every site
  carrying the forbidden instruction; reworded MUST NOT item 13 to forbid only an UNBOUNDED
  foreground `lake build`, not the plain foreground form; added the canonical bounded-wait
  MUST/MUST NOT bullet pair verbatim and the non-`lake`-gate cross-reference.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — same treatment at its
  own site inventory.
- `agent-system/extensions/lean/rules/lean4.md`, `agents/lean-research-agent.md`,
  `agents/lean-research-hard-agent.md`, `skills/skill-lake-repair/SKILL.md` — consistency edits
  to the corrected invocation shape (the research agents carried no wait-for-notification
  instruction and already PASSed Check K; `skill-lake-repair`'s command-substitution carve-out is
  retained, only its named mechanism corrected).
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — emptied
  `CHECK_K_EXCLUDED_RELATIVE_PATHS` (both lean paths discharged; helper and array kept for a
  future exclusion) and added both lean implementation-agent paths to
  `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS`, rewriting both comment blocks to state the current,
  discharged position.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — updated the
  Classification Rule (now one exclusion, not three) and the Forbidden-Shape Lint Anchor's
  curated-exclusion paragraph; fixed a dangling cross-reference to the now-merged "Blocking on a
  detached build" section; fenced "Copy this exact text" block and the four Check K anchor lines
  confirmed byte-identical before/after.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh` —
  retargeted cases (3a)/(3b): the formerly-excluded fixture path now asserts a Check K **FAIL**,
  not a recorded-exclusion skip.
- `agent-system/extensions/lean/index-entries.json`, `agent-system/extensions/core/index-entries.json`
  — mechanical `line_count` regenerations (the former a direct consequence of editing
  `long-builds.md`; the latter a pre-existing drift from a concurrent sibling task's own commits,
  unrelated to this task's content, committed separately as a `sync:` commit).
- `specs/state.json` / `specs/TODO.md` — new task #439 (successor), created via the standard
  Create Task flow.

## Decisions

- Lean's livelock rationale (a killed build caches no `.olean`, causing retry livelock) is
  **upheld as written, not re-tested** — no long Lean build exists in this repository to test it
  against (Phase 1). Detachment is therefore preserved; only the wait step changed.
- Check K's `PROHIBITIVE_MARKER_PATTERN` is the literal, case-sensitive set
  `MUST NOT|forbidden|prohibited|antipattern` — "never"/"NEVER" alone does not satisfy it. Phase
  3's first-pass wording (using "never" near a `run_in_background`/"completion notification"
  pairing) tripped 2 genuine Check K FAILs once Phase 5 discharged the exclusion; fixed by
  rewording three passages to use "forbidden"/"prohibited" explicitly (see Plan Deviations).
- The successor task (#439) is scoped to the propagation-architecture *ruling* plus a minimal
  demonstration, not a full ~14-file migration — the prior framing ("~18 files may each carry a
  divergent copy") was superseded by this task's own research finding that those files already
  carry the correct bullet pair and PASS both Check H and Check K.

## Plan Deviations

- **Phase 2**: editing `long-builds.md` went stale `agent-system/extensions/lean/index-entries.json`'s
  Rule T `line_count` field (195 -> 239 lines), failing Gate 3. Regenerated via
  `generate-context-line-counts.sh --write` and committed separately (not bundled into the phase
  commit, which would have dropped it as outside the declared `file_scope`).
- **Phase 4**: Gate 3 reported a transient "deployed rule content drift" FAIL for `rules/lean4.md`
  between editing the source and Phase 6's scheduled redeploy — confirmed by `diff` to be the
  *only* Gate 3 failure and to be Rule I's by-design behavior for any manifest-`provides.rules`
  entry edited pre-redeploy; resolved once Phase 6's redeploy ran.
- **Phase 5**: discharging Check K's exclusion surfaced 2 genuine Check K FAILs (not anticipated
  by the plan) on `lean-implementation-agent.md` (1 site) and `lean-implementation-hard-agent.md`
  (2 sites) — Phase 3's wording used "never" rather than a recognized prohibitive marker. Fixed
  within the same phase by rewording those three passages; both files remain within task 376's
  own declared `file_scope`.
- **Phase 6**: per this dispatch's own Batch Gate Deferral directive (this task is one of several
  `implement`-phase dispatches in one multi-task `/orchestrate` batch invocation), the final
  phase's `**Verification Tier**: full` was discharged against the scoped gate subset
  `--skip-slow --only-gate 3,4,6,22` (covering every file this task's phases touched) plus
  `test-lake-build-guard.sh` directly, rather than independently running the complete, unscoped
  `verify-deploy.sh`. The complete gate set is deferred to the batch-level stage, attributed back
  via this task's own `modified_files`. One incidental observation during the redeploy step: a
  full (non-`--only-gate`) `verify-deploy.sh` run (triggered internally by `deploy-headless.sh`'s
  own post-deploy verification) reported Gate 10 (`validate-state.sh --deep`) exceeding its
  internal 30s timeout; running `validate-state.sh --deep specs/state.json` directly afterward
  completed in 9s with 19 passed / 20 warnings / **0 failed**, confirming this was a transient
  timing condition unrelated to this task's own changes, not a real schema violation.

## Verification

- Build: N/A (no Lean build; this is a `meta` task editing agent-system contract files)
- Tests:
  - `test-lint-agent-contracts-await-notification.sh`: 6/6 PASSed (retargeted cases 3a/3b confirm
    the formerly-excluded path now FAILs Check K rather than being silently skipped).
  - `test-lake-build-guard.sh`: 48/0 PASSed (guard script unchanged; Phase 1's scratch fixture
    work left nothing behind).
  - `lint-agent-contracts.sh --verbose`: **348 passed, 13 warnings, 0 failed** (Phase 1 baseline:
    344/13/0 — the +4 delta is exactly the 2 new Check H and 2 new Check K PASS lines for the two
    lean files now evaluated on merit instead of excluded/skipped).
- Gate subset `--skip-slow --only-gate 3,4,6,22`: PASS, 0 failures (both pre- and post-redeploy).
- Files verified: Yes (all 10 declared `file_scope` paths present and committed; see git log for
  this task's phase commits).

## Impacts

- A lean `implement` dispatch that must run a long local `lake build` can no longer be stranded
  mid-phase by a detach-then-await-notification instruction: the agent contracts now prescribe
  the bounded single-call idiom, which always returns control to the agent.
- The measured incident's over-generalization (a non-`lake` probe sweep treated as if it were
  covered by lean's `lake`-specific detach mandate) is now textually foreclosed by the new
  "Which processes this anchor governs" section.
- `lint-agent-contracts.sh` Check K now has a genuinely empty curated-exclusion list, so any
  future regression of this antipattern — in any dispatchable agent contract, lean or otherwise —
  surfaces as a real lint FAIL rather than a silent skip.

## Follow-ups

- Task #439 (`audit_cross_extension_bounded_wait_duplication`, topic `core-agent-system`) carries
  forward the cross-extension propagation-architecture question, the reproduce commands, the
  `@`-reference standing constraint, and the two decisions this task made that bind it.

## References

- Plan: `specs/376_lean_agents_mandate_forbidden_detach_then_await/plans/01_lean-bounded-wait-migration.md`
- Research report: `specs/376_lean_agents_mandate_forbidden_detach_then_await/reports/01_detach-then-await-contradiction.md`
- Phase 1 probe transcripts: `specs/376_lean_agents_mandate_forbidden_detach_then_await/phase1-probe-notes.md`
- Phase progress files and handoffs: `specs/376_lean_agents_mandate_forbidden_detach_then_await/progress/`, `.../handoffs/`
- Successor task: #439, `specs/state.json` / `specs/TODO.md`

## Acceptance Verification (per-bullet evidence)

- **"No lean agent definition instructs an agent to end its turn awaiting a harness notification
  for a local gate or build, and none is left unable to comply with core's preference."**
  Discharged by: `grep -rn 'completion notification' agent-system/extensions/lean/` (4
  occurrences, all inside prohibitive sentences) and `grep -rn 'run_in_background'
  agent-system/extensions/lean/` (18 occurrences, all inside "never"/"forbidden" phrasing);
  MUST NOT item 13 in both implementation agents now forbids only an UNBOUNDED foreground call.
- **"The fix is demonstrated against a real artifact ... not asserted in prose."** Discharged by:
  Phase 1 Probe C (a replayed `lake-build-guard.sh` invocation against the standalone-reproduced
  fake-`lake` fixture, single Bash call, `GUARD_EXIT` captured un-piped via `wait`) and Phase 5's
  real `lint-agent-contracts.sh --verbose` run (348/13/0, Check K PASS lines for both lean files).
- **"If lean's livelock rationale is upheld, the retained detachment is paired with the bounded
  single-call wait idiom, and the guard invocation implementing it is shown working."**
  Discharged by: Phase 1's explicit non-test statement (rationale upheld, not re-tested);
  `long-builds.md`'s "Obligation 1: detach" and "The canonical invocation" retain shell-level
  detachment; Probe C shows the guard invocation working under the new idiom.
- **"A named successor task exists for the cross-extension duplication audit, carrying this
  task's grep evidence forward."** Discharged by: task #439, created and committed, description
  carries the reproduce commands, the corrected framing, the `@`-reference constraint, and the
  two binding decisions verbatim.
- **"Redeployed if any deployed file changed, and the stale-tree question answered."**
  Discharged by: `deploy-headless.sh` run (landed; `diff .claude/rules/lean4.md
  agent-system/extensions/lean/rules/lean4.md` returns no difference post-deploy) and
  `check-deploy-freshness.sh` (exit 0, no stale-extension WARN for `core` or `lean`); the
  stale-tree answer (the contradictory wording was already present in the last source-store
  commit preceding the measured incident, so a redeploy alone would not have prevented it) is
  recorded in this summary's Overview/Decisions, per research Finding 6.
