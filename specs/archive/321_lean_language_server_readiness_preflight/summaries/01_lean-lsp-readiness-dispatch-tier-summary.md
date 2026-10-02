# Implementation Summary: Task #321

- **Task**: 321 - Lean language server readiness preflight
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T17:12:48Z
- **Completed**: 2026-10-02T19:55:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None blocking. Cross-references open task 268 (build-cache half) — no shared file scope.
- **Artifacts**: plans/01_lean-lsp-readiness-dispatch-tier.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Extended the existing WARN-only `lean-mcp-preflight-check.sh` probe so it reports language-server
**reachability** (not merely MCP registration), and threaded that finding into every dispatch
file `/orchestrate` writes — plus the parallel, smaller gap on the direct
`/research|/plan|/implement` path — so an agent working in a Lean project learns its evidence
tier before it issues its first `lean_local_search` call. The probe's always-exit-0, WARN-never-
BLOCK contract and its sub-100ms budget are preserved exactly; the call is unconditional, gated
only by the probe's own lakefile detection, never by `task_type` — closing the exact gap that let
the motivating incident's `formal`-typed dispatch proceed against an unreachable language server
with no warning.

## What Changed

- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` — added `probe_reachability()`
  (one `ps` snapshot, self-match guard, `/proc/<pid>/environ` `LEAN_PROJECT_PATH` cross-check) and
  a `--dispatch-block` output mode emitting a complete `<lean-readiness-context>` block
  (resolved project root, registration status, reachability tier, the `index`
  unavailable/warming/consulted interpretation rule, and the degraded-mode-proceed statement). The
  no-flag path is unchanged byte-for-byte, confirmed against the full pre-existing 17-fixture
  suite.
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` — fixtures J-N
  (reachable / not_reachable / wrong-project anti-vacuous guard / outside-Lean-project /
  no-flag-regression) plus Mutation 3 (environ cross-check deletion), with a fake-server helper
  and an isolated `ps` stub to keep the mutation's controls deterministic against ambient host
  processes.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new
  `lean_readiness_context` Stage 3.5 output, called unconditionally (gated only by the probe's own
  lakefile detection), appended to the dispatch-file writer immediately after
  `deploy_freshness_context`. A non-Lean dispatch build is byte-identical to one built before this
  change (confirmed via `git stash` diff).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — Group 15: four
  cases (absent / present+verbatim+ordered / `task_type: formal` regression guard / failing-probe
  non-vacuous), plus a manual non-vacuity confirmation (reverting the emission guard flips the
  present cases to FAIL, absent/failing cases unaffected).
- The four lean `SKILL.md` files (`skill-lean-research`, `skill-lean-research-hard`,
  `skill-lean-implementation`, `skill-lean-implementation-hard`) — Stage 2 now captures
  `--dispatch-block` output into `lean_readiness` alongside the existing human-readable call;
  each file's delegation-context JSON gained a `lean_readiness` field, and each invocation
  directive gained a one-line inclusion note.
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` — three-state
  `index` vocabulary (`unavailable`/`warming`/`consulted`) under `lean_local_search`.
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — a
  "Registration vs. Reachability" section naming the general concept, pointing at the Lean
  probe as the concrete implementation, and recording the projection-asymmetry diagnostic tell
  as a manual sanity check (explicitly not automated).

## Decisions

- Registration status in `--dispatch-block` mode is derived from a single `verify-lean-mcp.sh
  --quiet` invocation's exit code (0/2/other) — no second verifier call, confirming Phase 1's
  Scope Hypothesis.
- The reachability probe runs only when registration is `registered`, keeping the
  not-yet-registered path in its existing ~20ms band.
- `unknown` is the honest default whenever introspection cannot run (no `/proc`, `ps` failure,
  unreadable `environ`, or registration not confirmed) — never silently promoted to `reachable`.
- `.olean` staleness detection was explicitly excluded (per research Finding 7): it cannot be made
  sub-100ms at real-project scale and belongs to the build-cache-correctness concern tracked
  separately (`lake-build-guard.sh`'s stale-content-addressed-store theory), not this
  dispatch-readiness probe.

## Plan Deviations

- None (implementation followed plan). Two bugs were discovered and fixed during Phase 2's test
  authoring (a command-substitution hang on a backgrounded 300s sleep, and a subshell-scoped
  array-append loss) and one test-design issue during Mutation 3 (an ambient real `lean-lsp-mcp`
  process on the dev machine required an isolated `ps` stub for deterministic controls) — all are
  recorded in the Phase 2 progress file's `approaches_tried`, not deviations from the plan's own
  scope.

## Verification

- Build: N/A (shell scripts and Markdown only)
- Tests: `test-lean-mcp-preflight-check.sh` 24/24 PASS; `test-orchestrate-build-dispatch.sh`
  119/119 PASS; `bash .claude/scripts/verify-deploy.sh --skip-slow` 33/33 PASS;
  `run-all.sh` (full) 305 passed / 10 failed across three unrelated, pre-existing suites (see
  Follow-ups).
- Files verified: Yes (deployed `.claude/scripts/lean-mcp-preflight-check.sh` and
  `orchestrate-build-dispatch.sh` confirmed byte-identical to their source-store copies; the
  acceptance scenario built a dispatch file, via the actually-deployed tree, for a `formal`-typed
  task in a Lean project with no running server — exit 0, `<lean-readiness-context>` present with
  `not_registered`/`unknown` and the full interpretation rule).

## Impacts

- A `lean4`/`formal` dispatch in a Lean project now receives an explicit evidence-tier statement
  before its first `lean_local_search` call, on both the `/orchestrate` and the direct
  `/research|/plan|/implement` paths.
- A non-Lean dispatch (the overwhelming majority of this repo's own dispatches) is unaffected:
  byte-identical dispatch files, ~6-7ms unchanged latency.
- `mcp-server-ownership.md`'s registration-vs-reachability distinction is now documented as a
  general concept, available to any future per-project MCP server this codebase registers.

## Follow-ups

- `run-all.sh`'s full (non-`--skip-slow`) run shows 10 pre-existing failures across
  `test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh` (flags an
  unrelated, already-uncommitted typst script change), and `test-run-all-parallel.sh` (a
  load-sensitive timing comparison) — none reference any file this task touched; unrelated to
  this work and not fixed here.
- `.olean` staleness detection, relaying this run's stale-cache reproduction to task 268, and
  generalizing the registered-vs-reachable technique to other per-project MCP servers remain
  explicitly out of scope, per the plan's Non-Goals.

## References

- Plan: `specs/321_lean_language_server_readiness_preflight/plans/01_lean-lsp-readiness-dispatch-tier.md`
- Research report: `specs/321_lean_language_server_readiness_preflight/reports/01_lean-lsp-readiness-probe.md`
- Progress files: `specs/321_lean_language_server_readiness_preflight/progress/phase-{1,2,3,4,5,6,7}-progress.json`
