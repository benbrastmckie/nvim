# Implementation Summary: Task #305

- **Task**: 305 - Trim `agent-system/extensions/core/commands/orchestrate.md` below its 21,000 B ceiling, then promote `ORCHESTRATOR_BUDGET_GATE_MODE` from warn to hard
- **Status**: [COMPLETED]
- **Started**: 2026-10-01
- **Completed**: 2026-10-01
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_trim-orchestrate-md-promote-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the last open finding in `verify-deploy.sh` Gate 20 by trimming
`agent-system/extensions/core/commands/orchestrate.md` from 21,328 B (328 B over its 21,000 B
ceiling) down to 19,024 B, with every removed clause verified still present (in more detail) in
`docs/architecture/orchestrate-state-machine.md`. Then promoted `ORCHESTRATOR_BUDGET_GATE_MODE`
from `warn` to `hard` in `verify-deploy.sh` in the same change, refreshed the measurement and
narrative record, and ran narrow verification confirming Gate 20 passes clean under `hard` mode.

## What Changed

- `agent-system/extensions/core/commands/orchestrate.md` — replaced the four phase-forcing
  Options table rows (`--fast`, `--research`, `--plan`, `--implement`) and the forced-phase
  Constraints bullet with short summary-plus-pointer form, cutting the file from 21,328 B to
  19,024 B. Table structure, row order, and row count all preserved.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — dropped/reworded
  the two sentences that pointed back at `commands/orchestrate.md`'s Options table as "the full
  per-flag wording" (now backward after the trim), so the doc reads as the self-sufficient
  authoritative long-form source.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — flipped
  `ORCHESTRATOR_BUDGET_GATE_MODE`'s default from `warn` to `hard` (line ~197); rewrote the
  preceding dated comment block to narrate the successful 2026-10-01 promotion (the reverted
  first attempt, the restatement trim that closed the overage, both per-file ceilings clear at
  promotion time, no ceiling/baseline moved).
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — updated
  `files["commands/orchestrate.md"].measured_bytes` to 19024 and extended its `derivation` with
  the dated closure narrative; rewrote the top-level `_comment` to record the completed
  promotion. `ceiling_bytes` (21000) and `eager_load.baseline_bytes` (65950) left byte-identical.
- `specs/ROADMAP.md` — refreshed the `commands/orchestrate.md` budget status row from "328 B
  OVER (new)... blocks promoting..." to the closed/under-ceiling figure and promotion note,
  matching the adjacent eager-load and `SKILL.md` rows' closure phrasing.

## Decisions

- Used the research report's byte-measured drafted replacement text for the Options table rows
  essentially as-is; it landed the file at exactly the estimated 19,024 B.
- Reworded (rather than fully dropped) the destination doc's two backward pointer sentences, so
  `commands/orchestrate.md` still names where the flags are typed, while the destination doc is
  explicit that it — not the Options table — carries the authoritative full contract.
- Ran the optional deploy sync (`deploy-headless.sh`) as part of closing verification, since it
  cleared the newly-introduced core-extension deploy drift this task's own source-store edits
  created. Left the drift in unrelated extensions (lean, typst) and unrelated pre-existing core
  files untouched and uncommitted — out of this task's scope.

## Plan Deviations

- **Task 4.1** altered: `test-verify-deploy-context-budget.sh` reports 14 passed / 1 failed, not
  the plan's expected 15/15. The `gate20 finding lines=0` figure confirms the per-file ceiling
  WARN this task's trim was meant to clear is gone; the one remaining failure is the
  baseline-fixture's full-battery run tripping on pre-existing, out-of-scope lean-extension
  deploy staleness (gate3/gate5/gate16), confirmed by direct inspection of the finding lines
  (identical to the findings already named in this dispatch's own `<deploy-freshness-context>`
  block before implementation began).

## Verification

- Build: N/A (documentation/config change)
- Tests: `test-verify-deploy-context-budget.sh` — 14 passed / 1 failed (1 failure is documented
  pre-existing lean staleness, not gate20; see Plan Deviations)
- Files verified: Yes

Evidence:
- `wc -c agent-system/extensions/core/commands/orchestrate.md` → 19024 (ceiling 21000, target
  <=20500)
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` → exits 0
- `grep -n 'ORCHESTRATOR_BUDGET_GATE_MODE:-'` → exactly one occurrence, `:-hard`
- `jq -e '.files["commands/orchestrate.md"].ceiling_bytes == 21000 and .eager_load.baseline_bytes != null'` → `true`
- `verify-deploy.sh --skip-slow --only-gate 20` (no env override, i.e. the new `hard` default) →
  `PASS -- 4 check(s), 0 failure(s)`; live-figures block:
  ```
  eager load: 65663 B / baseline 65950 B (mode: hard for per-file ceilings)
  commands/orchestrate.md: 19024 B / ceiling 21000 B (under)
  skills/skill-orchestrate/SKILL.md: 19993 B / ceiling 20000 B (under)
  ```
- `verify-deploy.sh --findings` over the real repo (post-deploy-sync) → no `FINDING gate20` line;
  remaining findings are pre-existing lean staleness (gate3/gate5/gate16) and 3 pre-existing,
  unrelated core `context/contracts/*.md` drifts, all present before this task started.
- `grep -rn 'remains warn-tier|Promotion is deferred|328 B OVER'` across
  `agent-system/extensions/core/` and `specs/ROADMAP.md` → no matches.

## Impacts

- Gate 20's per-file ceiling sub-check now defaults to `fail()` severity: a future PR that grows
  `commands/orchestrate.md` or `skills/skill-orchestrate/SKILL.md` past their ceilings will FAIL
  `verify-deploy.sh` by default rather than WARN, without an explicit
  `ORCHESTRATOR_BUDGET_GATE_MODE=warn` override.
- `commands/orchestrate.md` now has ~1,976 B of headroom under its 21,000 B ceiling, reducing the
  odds of a sibling-commit overage like the one this task closed.
- `docs/architecture/orchestrate-state-machine.md` is now unambiguously the single authoritative
  long-form source for the forced-phase/`--fast` contract.

## Follow-ups

- None required for this task's scope. The pre-existing lean-extension deploy staleness
  (gate3/gate5/gate16) and the 3 pre-existing core `context/contracts/*.md` drifts remain open,
  unrelated findings — already tracked outside this task.

## References

- `specs/305_trim_orchestrate_md_and_promote_budget_gate/plans/01_trim-orchestrate-md-promote-gate.md`
- `specs/305_trim_orchestrate_md_and_promote_budget_gate/reports/01_trim-orchestrate-md-budget-gate.md`
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
