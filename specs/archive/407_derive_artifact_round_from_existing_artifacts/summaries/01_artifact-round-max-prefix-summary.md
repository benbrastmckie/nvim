# Implementation Summary: Task #407

- **Task**: 407 - Derive artifact round from existing artifacts
- **Status**: [COMPLETED]
- **Started**: 2026-11-04T21:33:05Z
- **Completed**: 2026-11-04T22:24:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_derive-artifact-round-max-prefix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`skill_read_artifact_number()` in the core source store's `scripts/skill-base.sh` resolved a
task's artifact round from `state.json`'s `next_artifact_number`, defaulting an absent field to
`1` in a way that made its own count-based fallback unreachable — so a task created with a
pre-supplied `reports/01_*.md` and no stored counter got round `01` minted a second time. All
five plan phases are complete: the resolver now normalizes unconditionally as
`max(stored next_artifact_number, highest on-disk MM prefix + 1)`, applying the existing
`current`/`prev` mode logic to that single value; the dispatch integration suite and the
function's own unit-test suite both gained direct regression coverage for the fix; the schema
reference doc was aligned; and the deployed `.claude/` tree was regenerated and verified to
`RESULT=landed_verify_clean`.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — added `_skill_artifact_max_prefix()` (a
  pure-bash helper scanning `reports/`, `plans/`, and `summaries/` for the highest `[0-9][0-9]_*.md`
  prefix) and rewrote `skill_read_artifact_number()`'s body to normalize `stored` and
  `max_on_disk + 1` into one value before applying the unchanged `current`/`prev` mode logic.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — added Group 20
  (Cases A-D): the dispatch-required absent-field case for both modes, a sequence-gap max-prefix
  pin, and a behind-counter self-heal pin, plus a defensive fixture rebuild isolating the group
  from an earlier group's leftover artifact file.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — added Group 6, a
  direct per-mode resolution matrix for `skill_read_artifact_number` (six cases including an
  archive-aware `TASK_DIR` scan-root case), sourced source-store-first to avoid the deploy-first
  stale-copy hazard; dropped the function from the suite's uncovered-residual list.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — replaced the
  "Backward Compatibility" subsection's count-based illustrative snippet with a
  "Normalization Against Disk" subsection describing the implemented max-prefix rule.
- `agent-system/extensions/core/index-entries.json` — companion `line_count` fix for the schema
  doc edit above (724 → 729), committed as its own isolated commit.
- Regenerated deployed `.claude/` tree (gitignored, not a committed artifact) via
  `deploy-headless.sh`, reaching `RESULT=landed_verify_clean`.

## Decisions

- Normalization is **unconditional**, not fallback-only: all three `next_artifact_number` advance
  sites (`orchestrator-postflight.sh`, `orchestrate-stage5-postflight.sh`,
  `orchestrate-cycle-postflight.sh`) advance via `(.next_artifact_number // 1) + 1`, so a
  fallback-only fix would leave a second collision one dispatch later. Unconditional
  normalization makes the counter self-healing whenever it falls behind what is on disk.
- `_skill_artifact_max_prefix()` scans only the three canonical artifact subdirectories and only
  `[0-9][0-9]_*.md` names — never the task-directory root — so operator notes, `.dispatch/`, and
  `issues.jsonl` cannot inflate the round.
- `skill_read_artifact_number()`'s `artifact_dir` positional is retained, unconsulted, for
  call-site signature stability (one round shares a sequence number across all three
  subdirectories, so the scan is round-wide rather than per-subdirectory).

## Plan Deviations

- **Phase 3** (altered): the direct unit-coverage group sources `skill-base.sh` via a dedicated
  source-store-first resolution variable rather than the suite's default deploy-tree-first one,
  following Group 5's own existing precedent — the deployed copy was still pre-fix at that point
  in the dispatch (Phase 5's redeploy had not yet run), and a deploy-first resolution would have
  silently tested the OLD function and reported a false PASS.
- **Phase 5** (altered, caught by its own verification): Phase 1's implementation had kept a
  shellcheck SC2034 finding unsuppressed (the intentionally-unused `artifact_dir` positional) and
  had kept `// 1` on the `stored=` jq read rather than the plan's literal no-default form. Both
  were fixed forward during Phase 5 once its own verification bullets caught them; both are
  confirmed behaviorally inert (the full suites are unchanged before and after each fix).
- One companion fix beyond the plan's literal task list: `index-entries.json`'s `line_count` for
  the edited schema doc (required for gate 3 to report no new finding), committed in isolation
  from a second, unrelated, foreign uncommitted hunk already present in that file.

## Verification

- Build: N/A (shell scripts; `bash -n` parses clean on every edited script)
- Tests: Passed — `test-orchestrate-build-dispatch.sh` 171/171,
  `test-skill-base-lifecycle.sh` 62/62, both against the deployed tree
- Files verified: Yes
- `deploy-headless.sh` → `RESULT=landed_verify_clean`
- A full `verify-deploy.sh` (no `--skip-slow`) run reports 8 gate8 suite failures plus 1 gate16
  WARN, all mechanically confirmed unattributable to this task via
  `deploy_baseline_unattributable_findings` against this task's modified-files list

## Impacts

- Any task created with a pre-supplied artifact (e.g. a user-attached report) and no stored
  `next_artifact_number` now resolves its next research round correctly instead of colliding with
  the pre-supplied file's sequence number.
- A task whose stored counter has fallen behind what postflight's `// 1`-defaulted advance sites
  can leave on disk now self-heals at read time instead of propagating the staleness.

## Follow-ups

- None. The three `next_artifact_number` advance sites' own `// 1` default is explicitly left
  unfixed (Non-Goals) — the unconditional read-side normalization renders it harmless, and fixing
  all three in parallel would widen scope across heavily-claimed orchestrate scripts for no
  behavioural gain.

## References

- Plan: `specs/407_derive_artifact_round_from_existing_artifacts/plans/01_derive-artifact-round-max-prefix.md`
- Research: `specs/407_derive_artifact_round_from_existing_artifacts/reports/01_derive-artifact-round-from-artifacts.md`
- Issue log: `specs/407_derive_artifact_round_from_existing_artifacts/issues.jsonl`
