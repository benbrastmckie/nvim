# Implementation Summary: Task #791

**Completed**: 2026-06-30
**Duration**: ~1 session

## Overview

Fixed the `<leader>al` "Load Core" loader so WezTerm lifecycle tab coloring propagates to every repo the agent system is copied into. Two independent, compounding bugs were closed: a stale `provides.hooks` allow-list that silently dropped hook scripts during copy (Bug A), and a state-gated settings re-injection loop that never merged hook registrations into repos that only ran "Load Core" (Bug B).

## What Changed

- `.claude/extensions/core/manifest.json` — reconciled `provides.hooks` to the full 14-file on-disk list (removed phantom `wezterm-clear-status.sh`; added `claude-stop-notify.sh`, `validate-meta-write.sh`, `wezterm-preflight-status.sh`, `wezterm-utils.sh`); added `merge_targets.settings` declaration targeting the committed `.claude/settings.json`.
- `.opencode/extensions/core/manifest.json` — identical `provides.hooks` reconciliation for the `.opencode` tree.
- `.claude/extensions/core/merge-sources/settings-hooks.json` — new fragment with exactly 3 event arrays (`SessionStart`, `Stop`, `UserPromptSubmit`) registering the WezTerm lifecycle hooks.
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` — `reinject_loaded_extensions()` now unconditionally includes `"core"` in `loaded_names`, closing the state-gating gap for repos that never ran "Load Extension".

## Decisions

- The new settings fragment targets the **committed** `.claude/settings.json`, not `.claude/settings.local.json` (the pattern used by lean/nix/epidemiology), because hook wiring is required core functionality, not personal preference.
- The `_comment` explaining `deep_merge`'s append/non-self-healing semantics was placed on the manifest's `merge_targets.settings` entry rather than inside the fragment file, since `process_merge_targets`/`reinject_loaded_extensions` only read `.source`/`.target` from that object (extra keys are ignored) — putting it in the fragment instead would have merged a stray `_comment` key into every target repo's settings.json.
- The now-unreachable `if #loaded_names == 0 then return end` guard in `reinject_loaded_extensions` was removed since inserting `"core"` unconditionally guarantees the list is never empty past that point.

## Plan Deviations

- **Phase 2, Task 3** altered: comment placed on the manifest's `merge_targets.settings` entry instead of inside the merge-source fragment (see Decisions above).
- **Phase 3, Task 1** altered: removed the now-dead early-return guard following the core-insertion patch.
- **Phase 4** altered: the plan's literal `jq -s '.[0] * .[1]'` "static merge simulation" was found to be a misleading approximation of the real `deep_merge` algorithm (jq's `*` replaces arrays wholesale instead of appending+deduping), so the headless nvim harness running the actual `merge.merge_settings` Lua function was treated as the authoritative test instead. The state-independence check was performed by directly exercising the state-read + patched-insertion logic + `merge_mod.merge_settings` call (the same primitives `reinject_loaded_extensions` uses internally) rather than invoking the full interactive `M.load_all_globally` UI flow, since that function is not exported for headless testing and includes an interactive overwrite-conflict dialog. Throwaway copies were placed under the session scratchpad directory rather than literal `/tmp` paths.

## Verification

- Neovim startup: Success (`nvim --headless -c "lua print('OK')" -c "q"` after every phase).
- Both core manifests parse as valid JSON; `provides.hooks` fully reconciles against on-disk `.sh` files in both `.claude` and `.opencode` trees (`comm -3` empty in both).
- `settings-hooks.json` parses and declares exactly `SessionStart`/`Stop`/`UserPromptSubmit`; every referenced script is present in `provides.hooks`.
- `merge_targets.settings.target == ".claude/settings.json"`.
- `sync.lua` loads headlessly without error; `reinject_loaded_extensions` unconditionally includes `"core"`.
- Against a throwaway copy of `/home/benjamin/Projects/BimodalLogic` (never mutated — confirmed post-cleanup): the real `merge_settings` function is a true no-op for `SessionStart`/`UserPromptSubmit` (already byte-identical) and appends one additional `"*"` `Stop` matcher entry alongside the existing combined one — exactly the documented, accepted append-semantics risk from the plan's Risk table (safe, non-clobbering, since Claude Code runs all matching hook entries).
- Merging twice (both against the already-registered settings.json and a stripped one) produces zero further duplicate entries — idempotent.
- Project-specific `permissions`/MCP/`env`/other hook events are byte-identical before and after every merge scenario tested.
- After the `provides.hooks` fix, `wezterm-preflight-status.sh` copied into the throwaway target no longer exits 127 (now exits 0).
- State-independence: with `core` deleted from a throwaway repo's `extensions.json` (simulating a "Load Core"-only repo), `state_mod.list_loaded()` confirmed to exclude `"core"` beforehand; applying the patched insertion logic plus `merge_mod.merge_settings` against core's fragment correctly re-adds the 3 hook events with all other settings.json keys untouched.
- Regression check: no diff to `lean`/`nix`/`epidemiology` manifests from this task's commits — their `settings.local.json` merge targets are unaffected.

## Notes

- The dotfiles `~/.config/.claude` tree and the `.opencode` `wezterm-preflight-status.sh` content-drift issue remain out of scope per the plan's Non-Goals, as does self-healing of drifted hook command paths in `merge_settings` (documented as a follow-up risk in the manifest's `_comment`).
- Real `/home/benjamin/Projects/BimodalLogic` was never mutated; all verification ran against throwaway copies under the session scratchpad directory, cleaned up afterward.
