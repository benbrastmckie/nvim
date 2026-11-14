# Implementation Summary: Task #614

- **Task**: 614 - Resolve a SF-1 card worktree to its parent checkout so card sessions get repo-scoped Sapience retrieval without hook-injected context
- **Status**: [COMPLETED]
- **Started**: 2026-11-13
- **Completed**: 2026-11-13
- **Effort**: ~7 hours
- **Dependencies**: None blocking (shares the sapience extension surface with the concurrently-dispatched grant-retraction and source-store-reconciliation tasks in this same batch)
- **Artifacts**: plans/01_card-worktree-sapience-retrieval.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A linked git worktree of a loaded checkout previously resolved to no Sapience registration at
all, because the SessionStart registration hook, the verifier, and the three
`[repo:<slug>]` provenance sites all called `git rev-parse --show-toplevel` directly, which
returns the worktree itself rather than its parent checkout. This implementation adds a single,
byte-identical, marker-delimited `resolve_checkout_toplevel` helper to all five call sites,
following a linked worktree to its checkout via a `--git-dir`/`--git-common-dir` comparison,
while leaving the hook/permission-grant channel (SessionStart, UserPromptSubmit, PreToolUse)
deliberately and structurally absent from a worktree. Six new regression cases and a verifier
check cover the worktree scenarios; the two-channel asymmetry is recorded in the extension's own
domain notes.

## What Changed

- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` — added the
  marker-delimited `resolve_checkout_toplevel` helper; `GIT_ROOT` now resolves a linked worktree
  to its parent checkout; header comment updated.
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — lockstep copy of the same
  helper; `GIT_ROOT` likewise checkout-resolved; new check (f) asserting a linked worktree
  carries no `mcp__sapience__*` permission grant and none of the five Sapience hook keys
  (skip-logged when CWD is not a worktree); header extended.
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — same helper; the read-side
  `repo_toplevel` (and therefore the `[repo:<slug>]` query filter) is now checkout-resolved.
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` — same helper; the write-side
  slug derivation now matches the read side, so a worktree-originated write is tagged with the
  checkout's slug rather than the throwaway worktree name.
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` — same helper
  applied to both the primary call and its bare-`git` fallback, keeping its documented mirror of
  `sapience-remember.sh`'s resolution true.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — added a
  worktree fixture builder (guarded on `git worktree` usability) and six new cases (25-30):
  loaded-checkout worktree registers under the checkout's key with no worktree-keyed entry and a
  notice; unloaded-checkout worktree is silent; an existing checkout-keyed entry is retracted
  from inside the worktree once the checkout unloads; a worktree-shaped-but-broken path and a
  plain non-git directory are each a silent no-op; `~/.claude.json` carries exactly the checkout
  key after all of the above; and a lockstep guard asserting the marker-delimited block is
  byte-identical across all five copies. Header case inventory extended.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — new
  `## Worktree Resolution and the Two-Channel Asymmetry` section recording why MCP retrieval is
  made to reach a worktree while the hook/permission-grant channel is deliberately kept absent,
  cross-referencing `injection-site-scoping.md`'s Foreclosure 2, and recording the
  `--strict-mcp-config` caveat for the SF-1 runner's own automated card-exec subprocess.
- `agent-system/extensions/sapience/index-entries.json` — `per-repo-scoping.md`'s `line_count`
  reconciled from 240 to 281 via `generate-context-line-counts.sh --write`.

## Decisions

- The resolution block is inlined at all five call sites (not sourced from a shared library),
  matching the existing design decision recorded in the plan: the registration hook must run
  correctly in a repository with no `.claude/` deploy at all, and a sourced library would become
  a third file the installer must copy. The duplication cost is converted into the mechanically
  checked lockstep guard (new case 30) rather than left as a prose promise.
- The write side (`sapience-remember.sh`) was brought in scope alongside the read side: an
  untreated worktree write would tag a knowledge object with the throwaway worktree name, which
  neither the checkout's nor the worktree's own subsequent query could ever retrieve.
- No worktree-keyed `~/.claude.json` entry is ever written, and therefore no teardown/retraction
  mechanism was built for one — confirmed live against the real, shared `~/.claude.json`: a real
  `git worktree add --detach` of this checkout, with its worktree-local `.claude-extensions.json`
  removed (modelling an SF-1 card worktree whose checkout's extensions file is untracked),
  registered under the checkout's own path and left no worktree-keyed entry either before or
  after `git worktree remove`.

## Plan Deviations

- **Task 6.7** (run the complete gate set via a bare `verify-deploy.sh`) altered: this
  dispatch's own dispatch file carries a Batch Gate Deferral directive for a
  concurrently-scheduled multi-task `/orchestrate` batch invocation, superseding the plan's
  full-gate-set instruction for this final phase. Discharged instead against the scoped gates
  (3, 4, 5, 22 — doc-lint, task-reference lint, content-hash equality, shellcheck) and the
  targeted suite set covering this task's own touched files, all green. A bare unscoped run
  surfaced three failures unrelated to this task's edits (gate 8's shell test suite runner, gate
  10's `validate-state.sh --deep` timeout, and the eager-load/`skill-orchestrate/SKILL.md`
  ceiling check); none names a file this task touched, and all are consistent with a
  concurrently running sibling task in the same batch. See the plan's Phase 6 Verification
  section for the full scoped-discharge record.

## Verification

- Build: N/A (shell scripts; no build step)
- Tests: `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
  exits 0, 29/29 cases PASS, including a discriminative check confirming the new worktree cases
  FAIL against a reverted, pre-fix copy of the hook.
- Files verified: `bash -n` and `shellcheck` clean on all six edited scripts.
- Deployment: `deploy-headless.sh` regenerated the deployed tree; scoped gates 3, 4, 5, 22 all
  PASS against `/home/benjamin/.config/nvim`.
- Live acceptance: all four acceptance-criteria scenarios (loaded-worktree registration under
  the checkout's key; no hooks/grants reachable in the worktree per `verify-sapience-mcp.sh`
  check (f); unloaded-checkout and retraction fixtures; no dead `~/.claude.json` entry after
  teardown) verified against the real, shared `~/.claude.json` and the live vault — see the
  plan's Phase 6 task annotations for the full evidence trail, including a direct
  `GET /v1/search` cross-check proving a confirmed second repository's (`[repo:sapience-app]`)
  tagged object is excluded from an `nvim`-scoped query for the identical keyword.

## Impacts

- A session started inside a linked git worktree of a loaded checkout (such as an SF-1
  hub-runner card worktree) now gets the checkout's own repo-scoped Sapience MCP retrieval
  (`sapience_search`, and the dispatch-time `sapience-retrieve.sh` injection), while continuing
  to receive none of the extension's hooks or permission grants — the two channels are now
  scoped independently and deliberately, rather than both being lost together by accident.
- A worktree-originated `sapience-remember.sh` write now tags its knowledge object with the
  checkout's slug, keeping the read and write sides of per-repo scoping consistent for a
  worktree exactly as they already were for a checkout.

## Follow-ups

- The SF-1 runner's own automated card-exec subprocess (which passes `--strict-mcp-config` with
  an empty `--mcp-config`) still sees zero MCP servers regardless of this fix, by its own flags;
  this is vendor-owned, out of this repository's filesystem, and recorded rather than closed
  (per-repo-scoping.md's new section and the plan's Risk table).
- A pre-existing, documented residual (check (e) in `verify-sapience-mcp.sh` reporting 11/7
  Sapience permission grants for this repository, from before the grant was narrowed to 7) is
  owned by a different, concurrently-dispatched task in this same batch and was observed but not
  touched here.
- Observed a foreign `~/.claude.json` `.projects` entry (`.../fake-foreign-repo`) written by a
  different concurrently-running sibling dispatch's own session-id scratchpad while this task's
  live worktree test ran against the same real, shared file; recorded via `issue-record.sh` and
  left untouched as out of this task's scope.

## References

- specs/614_scope_card_worktree_sapience_retrieval/reports/01_card-worktree-sapience-retrieval.md
- specs/614_scope_card_worktree_sapience_retrieval/plans/01_card-worktree-sapience-retrieval.md
- agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md
- agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md
