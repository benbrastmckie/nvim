# Phase 3-6 Handoff: Settled strategy landed (identity dedupe + six-registration move)

## Immediate Next Action
All 7 plan phases are now closed (5 [COMPLETED], 2 [COMPLETED WITH EXCLUSIONS] for narrowly-scoped,
reasoned gaps). The task is ready for postflight/completion review. If resumed, the only
genuinely open items are: (a) the full `run-all.sh`/`verify-deploy.sh` gates were not re-run after
this final round of changes (time-bounded decision, recorded below), and (b) criteria 1/2's live
session-level reproduction against an actually-redeployed real repo (deliberately not attempted,
per the operator's non-destructive landing requirement).

## Current State

This dispatch went through FIVE successive operator-directed strategy changes for the
already-deployed-repo remediation mechanism before settling:
1. Ship an idempotent migration script (original plan).
2. Drop it — a planned full redeploy would reach already-deployed repos directly.
3. The redeploy was run for real against PossibleWorlds and left 21 stale registrations
   coexisting with 15 fixed ones (confirmed by this agent via direct `grep -c` against that
   repo's live settings.json: 21 stale / 15 fixed at that point). Operator asked for the
   migration script restored with a strengthened dedup requirement; it was rewritten, smoke-tested
   (13 fixture assertions, all passing) but never committed.
4. Dropped again in favor of a `manager.repair_settings` picker action (snapshot -> delete ->
   resync, exploiting install-once-copies-fresh-when-absent). Researched the mechanism
   (`loader.lua`'s install_once guard, `manager.resync_all`, `manager.wipe`/`regenerate`'s
   backup/restore machinery) but no Lua edit had been written when the operator sent a HOLD.
5. **SETTLED**: harden the normal resync path itself in `merge.lua` (identity-based hook dedupe,
   replacing a stale command in place rather than appending beside it) plus move the six
   root-files-only registrations into `core/merge-sources/settings-hooks.json` so the normal
   fragment merge visits them too. This fixes BOTH an absent AND an already-present-duplicated
   target, with no new script, no new picker action, no per-repo manual step.

Additional operator-directed scope landed in this same round:
- Removed a dead `claude-ready-signal.sh` registration from `root-files/settings.json` (the
  script does not exist anywhere in the source store or either real deployed repo).
- Swept the full source store (14 settings/fragment JSON files, not only the 4 in the original
  `file_scope`) for any other non-`.claude/`-prefixed relative-path hook command. Found none
  beyond the now-removed dead entry.

## Key Decisions Made

- **Identity model**: `hook_identity(hook)` resolves `"<type>:<NAME.sh>"` for any command
  recognizable as a `.claude/hooks/NAME.sh` invocation (stale or fixed form, bare or nested in
  `bash -c`), `nil` otherwise. A `nil` identity ALWAYS falls through to exact `vim.deep_equal`
  comparison — the mandatory custom-hook carve-out, verified by a dedicated regression test.
- **Replacement tracking**: a replaced hook is tracked into the SAME `tracked.hook_items` list an
  append uses, under the new hook's own value — `unmerge_settings` needed NO new branch, since it
  already finds-and-removes-by-`vim.deep_equal`-on-the-tracked-value, which is "undo what this
  merge changed" for a replacement too. It never resurrects the replaced stale command.
- **Six-registration move**: kept in `root-files/settings.json` too (so a fresh install still gets
  them before the first fragment merge), matching how the 11 already-shared hooks work. Verified
  byte-identical to `root-files/settings.json` via `jq` extraction for all six, including
  `subagent-postflight.sh`'s `timeout: 30000` field.
- **The genuinely-cited `.bak` fixture was absent.** The operator referenced
  `/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json.bak` (8193 bytes, 21
  stale + 15 correct) as the intended fixture. This agent confirmed via `ls`/`find` that no such
  file exists on disk. Used a faithful reconstruction from the operator's own reported counts for
  one unit test (`merge_spec.lua`'s last case, clearly labeled as a reconstruction), and instead
  demonstrated against the two real repos' ACTUAL LIVE `settings.json` files (via non-destructive
  scratch copies) for the strongest available real-repo evidence.
- **Non-destructive verification**: neither real repo's live `settings.json` was ever mutated.
  Both were copied to a scratch workdir; `merge.merge_settings` was run against the copies using
  the real, on-disk `core/merge-sources/settings-hooks.json` fragment. `md5sum` of both originals
  recorded identical before and after this entire dispatch.
- **"Teeth" demonstration skipped, reasoned**: `test-deploy-propagation.sh`'s plan-mandated
  re-break/re-run/restore cycle was not performed because `deploy-headless.sh` always reads
  extension SOURCE from the real, live checkout (no override), and a concurrent sibling task (365,
  observed via a genuine commit `9a2814cca` landing mid-dispatch) makes mutating that shared file
  for a test run an active concurrency hazard. `merge_spec.lua`'s unit tests cover the same
  negative space without touching shared state.
- **Full gate suites not re-run after the final round**: `run-all.sh` (10+ min observed) and
  `verify-deploy.sh` (5+ min observed, itself calling `run-all.sh`) were run once earlier in this
  dispatch (confirming one pre-existing, unrelated failure: a typst extension JSON-channel lint
  violation). After the final `merge.lua`/registration-move/dead-removal round, only the
  TARGETED verification (`merge_spec.lua`, `test-deploy-propagation.sh`, the real-repo scratch
  demonstration, and a worktree-based pre-existing-failure comparison for 3 other spec files) was
  re-run, given the time already invested. This is recorded as an open item, not hidden.

## Deviations from Plan

- Phase 3/4 fully repurposed from "write/test a migration script" to "harden the resync path" —
  same phase numbers, entirely different mechanism, per the settled operator strategy. See each
  phase's body for the full rationale.
- Phase 6 repurposed from "migrate and demonstrate" to "demonstrate convergence
  non-destructively" — no migration occurred; both real repos' live files were read-only inputs.
- Phase 5: the plan's "teeth" verification sub-step skipped, reasoned (see above).
- Criteria 1/2 (live session-level reproduction) not satisfied by this task; recorded explicitly
  rather than claimed.

## What NOT to Try

- Do not write a migration script for already-deployed repos, or a `manager.repair_settings`
  picker action — BOTH are permanently superseded by the hardened resync path, per explicit
  operator settlement after direct field evidence (the redeploy-leaves-duplicates failure) ruled
  out the simpler alternatives.
- Do not assume `deploy-headless.sh` can be pointed at a worktree-isolated source copy — it
  cannot; this is why the "teeth" demonstration was skipped rather than attempted unsafely.

## Critical Context

- Real evidence gathered DIRECTLY by this agent (not relayed): this repo's own live
  `.claude/settings.json` had 21 stale/0 fixed at verification time (not yet redeployed with this
  task's changes); PossibleWorlds' live file had 0 stale/22 fixed (already reloaded by the
  operator, confirmed independently via `grep -c`).
- A concurrent sibling agent (task 365, "lint_cwd_relative_hook_path_registrations") is active in
  this same session and landed a real commit (`9a2814cca`) mid-dispatch, touching only
  `specs/TODO.md`/`specs/state.json` — no file collision with this task's work, confirmed.

## References
- Plan: specs/364_cwd_relative_hook_registration_paths/plans/02_cwd-relative-hook-registration-paths.md
- Progress: specs/364_cwd_relative_hook_registration_paths/progress/phase-{3,4,5,6}-progress.json
- New test file: lua/neotex/plugins/ai/shared/extensions/merge_spec.lua
- Phases: 3, 4, 5, 6 of 7 (all closed this round)
