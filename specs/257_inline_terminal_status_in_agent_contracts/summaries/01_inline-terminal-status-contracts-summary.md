# Implementation Summary: Inline terminal status in agent contracts

- **Task**: 257 - Inline terminal status in agent contracts
- **Status**: [COMPLETED]
- **Started**: 2026-09-25T00:00:00Z
- **Completed**: 2026-09-25T03:30:00Z
- **Effort**: ~10 hours (9 phases)
- **Dependencies**: None (blocking). Shares one extraction prerequisite with the
  recovery-decline-attribution task, which now consumes `lib/return-meta-status-vocabulary.sh`
  rather than re-deriving it.
- **Artifacts**: plans/01_inline-terminal-status-contracts.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A research dispatch once wrote `"status": "completed"` into `.return-meta.json`;
`orchestrate-recover-outcome.sh`'s success arm accepted only `researched|planned|implemented`, so
a fully successful phase was charged as a failure. The root cause was structural: 20 dispatchable
agent files showed their model either a bare `"artifacts": [...]` fragment with no status key, or
a pipe-alternatives placeholder that is not a literal vocabulary member. This task brought all 20
files (22 edit sites) up to the shape already-protected agents use, extracted the canonical
8-value `.return-meta.json` status vocabulary out of `validate-return-meta.sh` into a shared
sourced library consumed by the validator, the recovery arm, and a new lint Check E, and closed
the regression loop so the examples cannot silently drift back to an unprotected shape.

## What Changed

- `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh` — new shared
  library: `RETURN_META_STATUS_VALUES` (8-value enum), `RETURN_META_FORBIDDEN_STATUS`,
  `RETURN_META_SUCCESS_STATUSES` (3-value subset), `is_return_meta_status`,
  `is_return_meta_success_status`.
- `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` — new
  27-assertion regression suite for the library.
- `agent-system/extensions/core/manifest.json` — registered both new paths.
- `agent-system/extensions/core/scripts/validate-return-meta.sh` — sources the library; deleted
  its private `valid_statuses` array and the hardcoded forbidden-value message, both replaced by
  library constants (output byte-identical to before).
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — sources the library;
  restructured the `case "$status" in researched|planned|implemented) ...` success arm into an
  `if is_return_meta_success_status "$status"` chain, semantics-preserving (every arm's body and
  exit code unchanged).
- 20 agent contract files (22 edit sites) across `core`, `email`, `lean`, `cslib`, `latex`,
  `python`, `rust`, `typst`, `z3`, `web`, `present`: each now carries a concrete inline terminal
  status (`researched`/`planned`/`implemented`) and, where absent, the never-use-`"completed"`
  MUST-NOT bullet. `planner-agent.md`'s happy-path example (the default plan agent for every task
  type, previously the ONLY complete JSON example in the file being the `needs_research` failure
  path) and `general-research-agent.md` (the default research agent for `general`/`meta`/
  `markdown`) were the highest-blast-radius fixes. `lean-implementation-hard-agent.md` and
  `cslib-implementation-hard-agent.md`'s pipe-placeholder `.orchestrator-handoff.json` blocks were
  rewritten to concrete values with a prose pointer to `handoff-schema.md`'s status enum.
  `grant-agent.md` kept its workflow-conditioned status table intact and gained a note recording
  `drafted`/`tracked`/`assembled` as agent-local, non-canonical values.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — new Check E: Detector A
  fails a non-excluded dispatchable agent with no conformant inline terminal status (excluding
  `in_progress`); Detector B fails ANY dispatchable agent carrying a literal
  `"status": "completed"` pair, regardless of exclusion. 5-entry exclusion list (not the plan's
  hypothesized 13 — see Plan Deviations). Wired into `main()` and `--help`.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — repaired
  `compliant-agent.md`/`check-f-conforming-agent.md` fixtures (now carry a conformant status);
  6 new Check E fixtures (4 positive, 2 negative) plus their assertions; both scratch fixture
  trees now also carry a copy of the new status-vocabulary library, a new environment
  prerequisite the real lint script introduced.

## Decisions

- Category B/A/hard-twin files use a minimal 2-key wrap (`status` + `artifacts`) rather than the
  richer `status`/`artifacts`/`metadata` shape, except `planner-agent.md`'s happy-path block,
  which mirrors its own `needs_research` block's completeness (status/artifacts/metadata/
  dispatch_seq) since the plan explicitly asked for "a complete worked example alongside" that
  block.
- `lean-implementation-hard-agent.md` and `cslib-implementation-hard-agent.md`'s pipe placeholders
  were replaced with a concrete `"implemented"` value plus a one-line prose pointer to
  `handoff-schema.md`'s `### status (required)` field definition, rather than restating the full
  six-value enum inline in each agent body.
- `grant-agent.md`'s primary example uses its canonical `funder_research` branch
  (`"status": "researched"`), the only branch whose value is a member of the 8-value canonical
  vocabulary; the workflow table and its `drafted`/`tracked`/`assembled` values are preserved
  unchanged, with a new note recording them as agent-local and out of scope for promotion here.
- Check E's `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS` uses the same full
  `agent-system/extensions/...`-prefixed path convention as Check F's exclusion list (matching
  `rel_path()`'s actual output), not the shorter convention `IN_SCOPE_RELATIVE_PATHS` (Check C)
  uses — the two existing lists in this file are inconsistent with each other, and Check E had to
  pick the one matching its own comparison target.

## Plan Deviations

- **Phase 8's exclusion-list scope hypothesis (13 entries) was wrong; the final list has 5
  entries.** Live re-verification against the real source store (explicitly required by the
  plan's own Scope Hypothesis note before finalizing) found that the 7 `filetypes/*` agents and
  `founder/agents/legal-analysis-agent.md` all already carry a genuine `"failed"`/`"partial"`
  canonical status for their error path, so they pass Check E's presence detector (Detector A)
  on their own merit and do not belong on the exclusion list — adding them would have violated
  the plan's own "a file that is merely unfixed gets fixed, never excluded" rule. Final 5-entry
  list: `core/agents/meta-builder-agent.md`, `present/agents/pptx-assembly-agent.md`,
  `present/agents/slidev-assembly-agent.md`, `core/agents/code-reviewer-agent.md`,
  `literature/agents/literature-agent.md`.

## Verification

- Build: N/A (documentation/lint task, no build step)
- Tests: Passed — `test-return-meta-status-vocabulary.sh` (27/27),
  `test-validate-return-meta.sh` (14/14), `test-orchestrate-recover-outcome.sh` (7/7),
  `test-orchestrate-recover-message-findings.sh` (23/23), `test-lint-agent-contracts.sh` (21/21).
  `lint-agent-contracts.sh --verbose` over the whole source store: 173 passed, 0 warnings, 0
  failed (Check E covers all 73 dispatchable agents; the 5 recorded exclusions each produce a
  named `[INFO]` skip, never a FAIL).
  `run-all.sh`: 90 passed, 4 failed, 0 skipped, 94 total. The 4 failing suites
  (`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-verify-deploy-context-budget.sh`) are confirmed
  pre-existing/out-of-scope by `git log`: none reference any file this plan touched, three were
  last modified by unrelated historical tasks, and the fourth correlates with a concurrently
  dispatched sibling task's own edit to `orchestrate-cycle-postflight.sh` (outside this plan's
  file scope).
- Files verified: Yes — every edited fenced JSON block validated with placeholder substitution;
  `jq empty` on `manifest.json`; zero pipe-alternatives placeholders remain; zero literal
  `"status": "completed"` pairs anywhere under `agent-system/extensions/*/agents/`; `git status
  --short -- .claude/` empty (no deploy-tree files touched).

## Impacts

- The default plan agent (`planner-agent.md`) and the default research agent for
  `general`/`meta`/`markdown` tasks (`general-research-agent.md`) — the two highest-blast-radius
  files — now show the model a complete, status-carrying success example, closing the exact
  defect class that caused the original typst-research-agent incident.
- `orchestrate-recover-outcome.sh`, `validate-return-meta.sh`, and `lint-agent-contracts.sh` now
  read one shared vocabulary definition instead of three independently-maintained copies, so the
  three cannot silently drift apart again.
- `lint-agent-contracts.sh` Check E is a permanent regression guard: any future agent file that
  regresses to a bare/pipe-placeholder shape, or that introduces a literal
  `"status": "completed"` pair, now fails the lint by name.

## Follow-ups

- **Wire a return-meta status validator into the dispatch read path** (deferred, recorded in the
  plan's "Deferred Follow-Up Tasks" #1). `validate-return-meta.sh` already rejects `"completed"`
  with the right message and has zero runtime callers. Blocked on the next item.
- **Widen `orchestrate-recover-outcome.sh`'s success-outcome acceptance set** (deferred, plan's
  "Deferred Follow-Up Tasks" #2) to admit intentional non-canonical extension vocabularies
  (`consulted`, `converted`, `assembled`) used by bona fide registered phase-routing targets.
- **Decide `"drafted"`'s status** (deferred, plan's "Deferred Follow-Up Tasks" #3): promote to the
  canonical vocabulary, move to a distinct `workflow_status` sub-field, or leave agent-local as
  today (the current, minimal choice).
- The 4 pre-existing `run-all.sh` failures noted under Verification above are unrelated to this
  task and were not investigated further (out of file scope); worth a separate look if they
  persist.

## References

- Plan: `specs/257_inline_terminal_status_in_agent_contracts/plans/01_inline-terminal-status-contracts.md`
- Research report: `specs/257_inline_terminal_status_in_agent_contracts/reports/01_terminal-status-vocabulary.md`
- Progress files: `specs/257_inline_terminal_status_in_agent_contracts/progress/phase-{1..9}-progress.json`
- Handoffs: `specs/257_inline_terminal_status_in_agent_contracts/handoffs/`
