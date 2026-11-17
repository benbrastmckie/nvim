# Implementation Summary: Task #627

- **Task**: 627 - Reap orphan sapience MCP registrations
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T15:47:00Z
- **Completed**: 2026-11-17T16:45:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_reap-orphan-sapience-mcp.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the unreachable-`.claude-extensions.json` branch in the per-project sapience MCP
registration design: added a `--reap` cross-project standalone action to the writer
(`setup-sapience-mcp.sh`) that removes `.projects[<path>].mcpServers.sapience` for any
registered path that is no longer a directory on disk, and restructured the `SessionStart` hook
(`sapience-mcp-register-project.sh`) to invoke that reap pass unconditionally on every session
start, before and independent of the hook's own manifest-reachability branch. All four plan
phases completed, verified, and committed individually.

## What Changed

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` — added `REAP` flag, `--reap`
  parser case, `process_reap()` standalone action (placed before `resolve_interpreter`'s hard
  `exit 1`), and header/`--help` documentation.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — added
  writer-level cases 31-34 plus a discrimination check (inverted `[ ! -d ]` filter), and
  hook-level cases 35-36 (orphan reaped with no reachable manifest at all; orphan + active
  current-repo registration in one invocation). Suite now covers 36 numbered cases plus two
  unnumbered checks (mutation check, discrimination check); all green.
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` — hoisted the `jq`
  and writer-exists guards above the manifest-reachability branch; converted that branch's
  early-exit `else` arm into a `HAVE_PROJECT` flag; inserted the ungated `--reap --quiet`
  invocation before the per-repo half; replaced the single-`NOTICE` tail with array-based
  notice assembly so either, both, or neither half firing still yields exactly one JSON line;
  updated the header comment with the reap-pass rationale.
- `agent-system/extensions/sapience/README.md` — updated the writer's and hook's file-inventory
  rows to name `--reap` and the ungated reap pass.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — added
  `--reap` to the writer/hook triad bullets and a new "The Orphan Reaper (`--reap`)" prose
  paragraph after the "One-session-start removal lag" note, covering rationale, scope, and the
  two accepted edge cases (emptied `{}` end state; `[ ! -d ]` treating an inaccessible-but-
  existing directory as absent).
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`; user-level installed copies at
  `$HOME/.claude/{hooks,scripts}/` refreshed via `install-sapience-mcp-session-hook.sh` and
  confirmed byte-identical (`cmp`) to their source-store originals.

## Decisions

- `process_reap()` placed as a standalone action short-circuit immediately after the
  `--retire-global` block (before `PROJECT_PATH` resolution and `resolve_interpreter`'s hard
  `exit 1`), matching the plan's required placement so a machine with no resolvable `python3`
  still reaps correctly.
- The plan's two directional writer-level cases (mixed-server orphan reaped correctly; a
  present-path row surviving untouched) were merged into one case (31) sharing a single fixture
  and invocation, as the plan itself directed.
- An emptied `.mcpServers: {}` after reaping is left as-is rather than deleting the whole
  `.projects` row (preserves unrelated session/history/cost metadata); a path that exists but is
  unreadable/unmounted reads as absent via `[ ! -d ]` and is reaped anyway, accepted as
  self-healing since the next session start in that repo re-registers it.
- Phase 4's `verify-deploy.sh` verification criterion was discharged via this dispatch's Batch
  Gate Deferral directive: `deploy-headless.sh`'s own inline `verify-deploy.sh --skip-slow` pass
  (`RESULT=landed_verify_clean`, 40 checks/0 failures) rather than an independent full-depth
  invocation, deferring the complete gate set to the batch-level run.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts; `bash -n` syntax-checked on every edited file)
- Tests: Passed — `test-sapience-mcp-registration.sh` exits 0 from the source store (36/36) and
  from the deployed tree via `run-all.sh --only test-sapience-mcp-registration.sh` (1/1 suite,
  all cases green)
- Files verified: Yes
- `verify-sapience-mcp.sh`: (a)-(d) PASS, (e) FAIL matching the exact pre-existing, documented
  11/7-grant-count baseline (not new drift)
- Live `~/.claude.json` server-key census: identical before/after the first post-install
  reap-bearing invocation; `lean-lsp`-only rows (`cslib`, `cslib-pr648`, `Logos/Theory`)
  untouched; backup copy removed after confirmation
- Lockstep guard (case 30) re-verified: the marker-delimited `sapience-worktree-checkout-
  resolution` block remains byte-identical across all five copies after the hook restructuring

## Impacts

- An orphaned (deleted or renamed) project's per-project sapience MCP registration in
  `~/.claude.json` is now reaped by any other live session's `SessionStart` hook, rather than
  leaking forever. No orphans existed live at the time of this change (confirmed via the
  before/after census), so the live effect of this change will only become observable the next
  time a registered project directory is deleted or renamed.
- The `SessionStart` hook's control flow changed structurally (guards hoisted, early exits
  converted to a flag, notice assembly now array-based), but its external contract (always exit
  0, exactly one JSON line, silent on the steady-state case) is unchanged and re-verified by the
  full pre-existing regression suite.

## Follow-ups

- None.

## References

- Research: `specs/627_reap_orphan_sapience_mcp_registrations/reports/01_reap-orphan-sapience-mcp.md`
- Plan: `specs/627_reap_orphan_sapience_mcp_registrations/plans/01_reap-orphan-sapience-mcp.md`
- Phase handoffs: `specs/627_reap_orphan_sapience_mcp_registrations/handoffs/`
