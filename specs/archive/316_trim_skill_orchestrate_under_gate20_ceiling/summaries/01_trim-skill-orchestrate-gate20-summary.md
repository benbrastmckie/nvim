# Implementation Summary: Task #316

- **Task**: 316 - Trim `skills/skill-orchestrate/SKILL.md` back under its verify-deploy gate 20 per-file context ceiling
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T17:00:00Z
- **Completed**: 2026-10-02T19:03:00Z
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_trim-skill-orchestrate-gate20.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`verify-deploy.sh` gate 20 (`ORCHESTRATOR_BUDGET_GATE_MODE=hard`) was RED: the source-store copy
of `skills/skill-orchestrate/SKILL.md` measured 20930 B against its 20000 B per-file ceiling.
Following the plan's option-(a) (relocate-and-trim) design, three duplicate-prose sites in
SKILL.md were converted to pointers into already-canonical or newly-canonical documentation,
bringing the file to 19855 B (145 B of margin) with every contract statement preserved in
equivalent or greater force at its new home.

## What Changed

- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — expanded the
  condensed `.status`/`.persisted_status` paragraph in `## Context Flatness Guarantee` into the
  full canonical contract text (self-report framing, `$verdict`/`$halt`/`$infra_exempt_cycle`
  loop-control distinction, empty-blocker `partial` example, "documented behavior, not a
  defect"), inverting its closing cross-reference so it no longer defers to SKILL.md.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — three edits:
  1. Replaced the 9-line `.status` vs. `.persisted_status` paragraph in Move 3 with a short
     pointer to the architecture doc's new canonical paragraph (-428 B).
  2. Collapsed the `## MUST NOT (Postflight Boundary)` body to a pointer into
     `docs/architecture/handoff-schema.md`'s existing "Postflight Boundary" section, which
     already carries the full 5-operation list and the D4 exception in greater detail; the
     heading itself was left byte-identical (-496 B).
  3. Tightened the `## MUST NOT (Context Flatness Constraint)` wording while retaining the
     artifact-read prohibition, the `orchestrate-cycle-postflight.sh` attribution, and the
     871 B/cycle/task figure (-151 B).
  - Net: 20930 B -> 19855 B (1075 B removed, 145 B margin under the 20000 B ceiling).
- Deployed `.claude/` mirrors of both files were already in sync (byte-identical) after the
  Phase 1/2 commits — no separate hand-sync was needed or performed.

## Decisions

- Chose option (a) (relocate-and-trim) over option (b) (re-deriving/raising the ceiling), per the
  dispatch's and research's framing: the ceiling is catching exactly the chronic-growth pattern
  it exists to catch, and raising it would remove the only mechanism forcing contract prose out
  of eager-loaded context.
- Inverted canonicality for the `.status`/`.persisted_status` contract (architecture doc now
  canonical, SKILL.md carries the pointer) rather than the reverse, matching the repo's stated
  lazy-context-loading idiom for SKILL.md.
- Left `## MUST NOT (Postflight Boundary)`'s heading text untouched byte-for-byte since
  `lint-postflight-boundary.sh` keys on it; only the body beneath was collapsed to a pointer.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/documentation task)
- Tests:
  - `ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20` —
    PASS, SKILL.md measured at 19855 B, within the 20000 B ceiling.
  - `bash .claude/scripts/verify-deploy.sh` (full suite) — 33 of 34 checks pass. The one failing
    check, Gate 8 (shell test suite runner), reports 4 failing suites:
    `test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`, and
    `test-run-all-parallel.sh` are self-reported `(EXPECTED)` by `run-all.sh`'s own summary line
    (pre-existing, known flaky/accepted failures unrelated to this task); `test-typst-element-lint.sh`
    is reported `(NEW)` but its failure traces to a pre-existing, already-uncommitted
    modification to `agent-system/extensions/typst/scripts/typst-element-lint.sh` present in the
    working tree before this dispatch began (confirmed via `git status --porcelain`, which was
    unchanged on that file by this task). Neither of this task's two edited files appears in
    Gate 8's failure set — no gate this task could plausibly affect regressed.
  - `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — 15
    passed, 0 failed.
  - `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` — 0 violations,
    full corpus; heading preserved byte-identical.
- Files verified: Yes — `wc -c` measured at every step; `diff` confirmed source-store/deployed
  mirror byte-identity for both edited files.

## No-Content-Lost Audit

| Removed from SKILL.md | Relocated to | Verified present |
|---|---|---|
| `.status` vs `.persisted_status` full contract | `orchestrate-state-machine.md`'s `## Context Flatness Guarantee` | Yes, every clause plus inverted closing pointer |
| `## MUST NOT (Postflight Boundary)` body (5 operations + D4 exception) | `handoff-schema.md`'s `## Postflight Boundary` | Yes, all 5 numbered operations and named D4 exception, in greater detail |
| `## MUST NOT (Context Flatness Constraint)` body detail | `orchestrate-cycle-postflight.md` / `orchestrate-state-machine.md`'s `## Context Flatness Guarantee` (pre-existing, unmodified targets) | Yes, prohibition list, script attribution, and 871 B figure retained inline in the tightened wording |

## Impacts

- `verify-deploy.sh` gate 20 is green again, unblocking every subsequent `/orchestrate`
  inter-cycle redeploy checkpoint that depends on it.
- The `.status`/`.persisted_status` contract is now more discoverable (canonical home in the
  architecture doc, which already aggregates related state-machine contracts) rather than buried
  in SKILL.md's Move 3 bash-heavy section.
- SKILL.md retains 145 B of margin, but the file is under the same "chronic budget pressure"
  research identified (two ceiling-breach fixes in its recent git history before this one); the
  next substantive contract addition to SKILL.md may re-breach the ceiling.

## Follow-ups

- Plan's Non-Goals explicitly deferred adding a standing "default to a pointer, not inline prose"
  guidance note for SKILL.md's chronic budget pressure — a candidate follow-up task, not done
  here.
- None of the 4 pre-existing Gate 8 failures were introduced or touched by this task; they remain
  open issues outside this task's scope (the `typst-element-lint.sh` working-tree modification in
  particular was already dirty at session start).

## References

- Plan: `specs/316_trim_skill_orchestrate_under_gate20_ceiling/plans/01_trim-skill-orchestrate-gate20.md`
- Research: `specs/316_trim_skill_orchestrate_under_gate20_ceiling/reports/01_trim_skill_orchestrate_gate20.md`
- Phase 1 commit: `6fb6b20cd` "task 316 phase 1: invert .status/.persisted_status canonicality"
- Phase 2 commit: `0020770b2` "task 316 phase 2: collapse MUST NOT section bodies to pointers"
