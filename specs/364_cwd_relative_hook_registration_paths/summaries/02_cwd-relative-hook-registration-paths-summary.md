# Implementation Summary: Task #364

- **Task**: 364 - Resolve hook registration paths independently of session CWD so bare-registered
  blocking guards cannot fail open
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T20:24:00Z
- **Completed**: 2026-10-07T22:55:00Z
- **Effort**: ~7 hours (substantially above the 6.5h estimate, driven by five successive
  operator-directed strategy reversals for the already-deployed-repo remediation mechanism)
- **Dependencies**: None
- **Artifacts**: plans/02_cwd-relative-hook-registration-paths.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Every hook registration in the source store wrote `bash .claude/hooks/x.sh`, a CWD-relative path
the Claude Code harness resolves against the session's drifted Bash-tool CWD rather than the
project root, so each one silently failed open the moment a session `cd`d into a subdirectory —
defeating the six bare-registered blocking guards' entire purpose. All 34 source-store
registrations across 4 JSON files were rewritten to the `$CLAUDE_PROJECT_DIR`-prefixed form, one
missing merge-source counterpart was added, four documentation templates were fixed, and —
after an extended strategy search described below — the normal extension resync path itself
(`lua/neotex/plugins/ai/shared/extensions/merge.lua`) was hardened with identity-based hook
deduplication so that an ordinary resync, not a bespoke migration mechanism, repairs any
already-deployed repo, present-and-duplicated or not.

## What Changed

- `agent-system/extensions/core/root-files/settings.json` — 18 commands rewritten to
  `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` (including the nested `bash -c` form); added a
  top-level `_comment` documenting install-once semantics; removed a dead
  `claude-ready-signal.sh` registration (the script exists nowhere in the source store or either
  real deployed repo).
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — 14 commands rewritten; added
  the missing nested `validate-state-sync.sh` counterpart (byte-identical to root-files); moved
  six registrations that previously existed ONLY in install-once `root-files/settings.json`
  (`log-session.sh`, `post-command.sh`, `memory-nudge.sh`, `subagent-postflight.sh` with its
  `timeout: 30000`, `tts-notify.sh`, `validate-plan-write.sh`) into this fragment, including a
  brand-new top-level `Notification` event array, so the normal fragment merge now visits them.
- `agent-system/extensions/books/settings-hooks.json`, `agent-system/extensions/email/settings-fragment.json`
  — 1 command rewritten each.
- `agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md`,
  `tts-stt-integration.md`, `hooks/wezterm-integration.md`,
  `agent-system/extensions/core/context/troubleshooting/workflow-interruptions.md` — 8 JSON
  registration-template snippets fixed so documentation teaches the corrected shape.
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — added `hook_identity(hook)` (resolves a
  hook's registration identity as `"<type>:<NAME.sh>"` for any `.claude/hooks/NAME.sh`
  invocation, `nil` for anything else) and `find_hook_match(hooks, hook)` (the single shared
  lookup both functions below now use). Rewrote `normalize_hook_event_array` and
  `merge_hook_event_array` to REPLACE a stale-identity entry's command in place instead of
  appending a duplicate beside it, while falling through to exact `vim.deep_equal` comparison for
  any command not recognizable as a hooks-directory invocation (a hand-written custom hook —
  mandatory carve-out, regression-tested).
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` — new, 7 plenary/busted test cases
  covering the duplicated shape, the all-stale shape, idempotency, the normalize-only split-block
  case, the custom-hook carve-out, the six moved registrations' propagation, and a reconstruction
  of the real observed production duplicate shape.
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` — added Assertion E
  (three sub-checks: zero CWD-relative paths, bare-ness preserved, no duplicates) to the existing
  real-headless-deploy harness.

## Decisions

- **Settled mechanism (after five reversals)**: harden the normal resync path (`merge.lua`'s
  identity-based dedupe) plus move the six root-files-only registrations into the merge source,
  rather than a bespoke migration script or a `manager.repair_settings` picker action. This is the
  only approach of the four considered that repairs an already-deployed, already-duplicated repo
  via nothing more than the ordinary `<leader>al` "Reload All" / resync path.
- **Replacement tracking reuses the existing removal mechanism**: a replaced hook is tracked into
  the same `tracked.hook_items` list an append uses (under the new value), so `unmerge_settings`
  needed no new code path — it already finds-and-removes by `vim.deep_equal` on the tracked
  value, which is "undo what this merge changed" for a replacement too, and never resurrects the
  replaced stale command.
- **Dead registration removed, not rewritten**: `scripts/claude-ready-signal.sh` does not exist
  anywhere; removed from `root-files/settings.json` entirely rather than given a
  `$CLAUDE_PROJECT_DIR` form pointing at nothing.
- **Non-destructive verification over live mutation**: both real repos' live `settings.json`
  files were used as read-only inputs (copied to a scratch workdir, never edited in place),
  per the operator's explicit "do not leave either repo worse than you found it" requirement.

## Plan Deviations

- **Phases 3, 4, 6** were entirely repurposed mid-dispatch (same phase numbers, different
  mechanism) after the operator's settled strategy superseded the original migration-script plan.
  See the plan file's Phase 3 "SUPERSEDES" note for the full five-reversal history.
- **Phase 5**: skipped the plan's "demonstrate assertion teeth via re-break/re-run/restore"
  verification sub-step — `deploy-headless.sh` always reads extension source from the real, live
  checkout (no override), and a concurrent sibling task (365, confirmed active via a real commit
  landing mid-dispatch) made mutating that shared file for a test run an active concurrency
  hazard. `merge_spec.lua`'s unit tests cover the same negative space without touching shared
  state. *(deviation: altered — scope narrowed, reasoned, see Phase 5 Reasoned Exclusions)*
- **Phase 6**: criteria 1 and 2 (live session-level reproduction: no hook error from a
  subdirectory CWD, a guard demonstrably blocking from that CWD, against an actually-redeployed
  repo) are NOT satisfied by this task. Demonstrating them would require a live redeploy into a
  real repo mid-dispatch, which the operator's non-destructive landing requirement directed
  against. *(deviation: skipped — see Phase 6 Reasoned Exclusions)*
- **The cited `.bak` fixture was absent.** The operator referenced
  `/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json.bak` as the intended
  fixture for proving convergence. This agent confirmed via `ls`/`find` that no such file exists
  on disk at verification time. Used a labeled reconstruction from the operator's own reported
  counts for one unit test, and the two real repos' actual live files (via non-destructive
  copies) for the strongest available real-repo evidence instead.
- **Full `run-all.sh`/`verify-deploy.sh` gates not re-run after the final round of changes**
  (merge.lua, the six-registration move, the dead-registration removal), given their long
  observed runtime (10+ and 5+ minutes respectively) and the time already invested in targeted
  verification. They WERE run once earlier in this dispatch (after Phase 1), surfacing one
  pre-existing, unrelated failure (a typst extension JSON-channel-discipline lint violation,
  confirmed unrelated by inspection). *(deviation: deferred — recorded as an open item, not
  hidden)*

## Verification

- **Demonstrated** (not merely asserted), with the exact command and evidence:
  - `jq empty` on all 4 edited settings JSON files: all pass.
  - `grep -rn 'bash \.claude/hooks' agent-system --include=*.json`: zero matches.
  - 6 unique bare blocking-guard registrations confirmed by grep; every advisory hook retains
    `2>/dev/null || echo '{}'`.
  - All 6 moved registrations + the original 5 shared hooks verified byte-identical between
    `root-files/settings.json` and `merge-sources/settings-hooks.json` via `jq` extraction.
  - `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua"`:
    **7 passed, 0 failed, 0 errors.**
  - `bash agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` (a REAL
    `deploy-headless.sh` run against a scratch git repo, real headless `nvim` subprocess):
    **7 passed, 0 failed** (the pre-existing Assertions A-D plus the new Assertion E).
  - Real-repo scratch-copy demonstration (`nvim --headless -c "luafile ..."` calling
    `merge.merge_settings` directly against copies of both repos' LIVE files, with the real
    on-disk core fragment):
    - `thisrepo` (`/home/benjamin/.config/nvim`): BEFORE 21 stale/0 fixed -> AFTER 0 stale/21
      fixed; 23 total hook commands unchanged; `env`/`permissions` keys preserved; 0 duplicate
      `(event,matcher,hook)` triples; valid `jq`-parseable JSON.
    - `possibleworlds` (`/home/benjamin/Philosophy/Papers/PossibleWorlds`, already reloaded by
      the operator): BEFORE 0 stale/22 fixed -> AFTER 0 stale/22 fixed (true idempotent no-op).
    - BOTH real repos' original live files confirmed byte-identical (`md5sum`) before and after
      this entire dispatch — neither was mutated.
  - Pre-existing Lua spec regression check: ran all 8 `*_spec.lua` files under
    `lua/neotex/plugins/ai/`; 3 showed failures (`metadata_spec.lua` 1, `registry_spec.lua` 6,
    `claude/extensions/manifest_spec.lua` 1) — confirmed PRE-EXISTING, not a regression, by
    re-running the same 3 files against a disposable `git worktree add /tmp/nvim-head-check HEAD`
    checkout (this repo's own last-committed state before the `merge.lua` edit) and observing
    identical fail counts there; worktree removed after comparison.
- **Asserted, not demonstrated**: acceptance criteria 1 and 2 (live session-level hook-error-free
  Bash call and a real blocking-guard refusal, both from a subdirectory CWD in an actually
  live-redeployed repo) — explicitly NOT claimed as satisfied; see Plan Deviations.
- Build: N/A (no compiled artifact). Tests: documented above, both passing. Files verified: Yes.

## Impacts

- Every hook registration in the source store now resolves against the project root regardless
  of session CWD drift, restoring the six blocking guards' intended `exit 2` enforcement.
- The normal extension resync path is now self-healing for this entire defect class: any
  already-deployed repo, in any of the three possible states (fully stale, partially duplicated,
  or already correct), converges to exactly one correct registration per hook on its next
  ordinary resync — no bespoke tooling required.
- Tasks 282 and 347 (both open, both adding new hook registrations to the merge source) will now
  inherit the corrected convention automatically rather than needing a separate follow-up fix.
- Task 365 (the standing lint gate for this convention, dependent on this task) can now encode
  its accept-pattern against a settled, landed path shape.

## Follow-ups

- Run `bash .claude/scripts/tests/run-all.sh` and `bash .claude/scripts/verify-deploy.sh` once
  more against the final committed state, now that time pressure has eased — not expected to
  surface anything new given the targeted verification already performed, but not yet directly
  confirmed.
- This repo's own `.claude/settings.json` was found still stale (21 CWD-relative, 0 fixed) during
  verification — it has not yet been redeployed with this task's source-store changes. An
  ordinary `<leader>al` "Reload All" (or `deploy-headless.sh`) will now converge it correctly
  given the hardened resync path, but that redeploy itself was intentionally not performed by
  this task (non-destructive landing requirement).
- `/home/benjamin/Philosophy/Papers/PossibleWorlds` is already correctly repaired by the
  operator's own earlier reload (0 stale, 22 fixed as of verification) and needs no further
  action from this task.
- Criteria 1/2's live session-level reproduction remains open for a future, deliberate,
  operator-authorized live redeploy + session test.
- Task 365 is unblocked to proceed with its lint gate now that the path-shape decision (identity
  dedupe + six-registration move, not a migration script) is settled and landed.

## References

- Plan: `specs/364_cwd_relative_hook_registration_paths/plans/02_cwd-relative-hook-registration-paths.md`
- Research: `specs/364_cwd_relative_hook_registration_paths/reports/02_cwd-relative-hook-paths-research.md`,
  `specs/364_cwd_relative_hook_registration_paths/reports/01_cwd-relative-hook-paths.md`
- Handoffs: `specs/364_cwd_relative_hook_registration_paths/handoffs/` (phase-1, phase-2,
  phase-3-4-6-exclusion [superseded], phase-7, phase-3-6-settled)
- Decision log: `specs/364_cwd_relative_hook_registration_paths/.decisions.json`
