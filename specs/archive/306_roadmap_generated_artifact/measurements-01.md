# Phase 1 Measurements: Task 306

Re-measurement of every figure the plan (`plans/01_roadmap-generation-contract.md`) carries from
research, per `specs/ROADMAP.md` Standing rule 5 ("re-measure before acting on it"). Captured
before any file in this task's `file_scope` was written.

## `specs/ROADMAP.md`

- `wc -l specs/ROADMAP.md` -> **422** (plan asserted 422 — MATCH)
- `grep -n '^## ' specs/ROADMAP.md` -> 8 sections (plan asserted 8 `## ` sections under a
  `# Roadmap` title — MATCH):
  ```
  8:## Goal
  21:## Gate state
  63:## Next
  195:## Open work
  271:## Checks before and after every call
  297:## Settled decisions (do not re-litigate)
  368:## Standing rules
  389:## Unfiled observations (none worth a task yet)
  ```
  This is exactly the plan's assumed nine-element list (Goal, Gate state, Next, Open work, Checks
  before and after every call, Settled decisions, Standing rules, Unfiled observations, plus the
  `# Roadmap` title and italic preamble) — MATCH, no reconciliation needed.

## Context files

- `agent-system/extensions/core/context/formats/roadmap-format.md` -> **65** lines (plan asserted
  65 — MATCH)
- `agent-system/extensions/core/context/patterns/roadmap-update.md` -> **100** lines (plan
  asserted 100 — MATCH)

## `generate-task-order.sh --print`

Run from the deployed tree (`bash .claude/scripts/generate-task-order.sh --print`; the
agent-system source-store copy refuses to run standalone via its own deploy-root guard, as
expected). Exit 0. Emits a `**Dependency Waves**:` table:

```
**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 22,251,271,272,280,284,295,296,299,302,306,311,318,319,338,342,345,347,349,360,362,363,366,367 | -- | core-agent-system, extensions, neovim, ... |
| 2 | 29,170,273,275,281,303,335,344,350,354,355,368 | 22,251,271,272,280,284,306,311,345,349,366 | core-agent-system, extensions, orchestrator |
| 3 | 274,282,304,359,369 | 29,273,275,281,284,302,344,350 | core-agent-system, orchestrator |
| 4 | 312,328 | 170,282,303,304,318,344 | core-agent-system, orchestrator |
| 5 | 313 | 328,344 | core-agent-system |
```

This is a **5-wave table** (plan asserted "currently emits a 5-wave table" — MATCH).

## `roadmap-integration.sh` live/quarantined location

- `agent-system/extensions/core/scripts/roadmap-integration.sh` -> does not exist (confirmed)
- `agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh` -> exists, **944**
  lines (plan asserted 944 — MATCH)

## Gate baselines (for Phase 7 delta comparison)

- `bash .claude/scripts/check-extension-docs.sh --quiet` -> exit **0**, all extensions `PASS`
  ("PASS: all extensions OK")
- `bash .claude/scripts/generate-context-line-counts.sh --check` -> exit **1** (pre-existing;
  unrelated to this task). Summary: 567 entries checked, 566 exact, **1 mismatch**:
  `core: 'schemas/state-schema.json' mismatch: declared 438, actual 442` — this is task 271's
  territory, not this task's. Both of this task's target entries
  (`formats/roadmap-format.md`, `patterns/roadmap-update.md`) currently report **exact match**
  (declared == actual, 65 and 100 respectively) — this is the pre-edit baseline Phase 7 corrects
  against.
- `bash .claude/scripts/validate-context-budgets.sh` -> **10 violations** (plan asserted "10
  violations including `planner-agent OVER:8920` and `general-research-agent OVER:16496`" —
  MATCH on both named figures):
  ```
  nix-research-agent                      9472     8000    OVER:1472
  general-research-agent                 24496     8000   OVER:16496
  general-implementation-agent           39824     8000   OVER:31824
  nix-implementation-agent               16616     8000    OVER:8616
  planner-agent                          23920    15000    OVER:8920
  neovim-research-agent                   9640     8000    OVER:1640
  neovim-implementation-agent            17848     8000    OVER:9848
  meta-builder-agent                     15232    15000     OVER:232
  ```
  Note: `reviser-agent` does not appear in this validator's agent table at all (it has no tracked
  cap entry in `.claude/context/index.json`'s agent-budget check), so no numeric baseline exists
  for it to compare against in Phase 7 — this is a pre-existing gap in the validator's coverage,
  not something this task introduces or must fix.

## Gate: reconciliation needed?

**No.** Every figure the plan carries from research matches the live measurement exactly. Phase
2 proceeds against the plan's contract as written, with no reconciliation.
