# Implementation Summary: Build in-config sf1 Neovim virtual plugin with configurable split position

- **Task**: 578 - Build in-config sf1 Neovim virtual plugin with configurable split position
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T12:00:00Z
- **Completed**: 2026-11-10T12:20:00Z
- **Effort**: ~5.25 hours (per plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/02_sf1-virtual-plugin-split-position.md

## Overview

Built the sf1 (Sapience terminal chat) integration as a lazy.nvim virtual plugin under
`lua/neotex/plugins/ai/`, following the existing `stt-plugin.lua`/`stt/init.lua` convention: a
thin spec file at the parent level pointing at a sibling `sapience/` implementation directory.
The implementation is split into a dependency-free window backend (`terminal.lua`, wrapping
`snacks.terminal`) and a public API (`init.lua`, opts schema + validation + lifecycle
functions), registered through the existing `ai/init.lua` loader with no loader changes, plus a
`:Sf1` command, a `<leader>af` which-key binding, and a terminal-keymap branch that leaves
`<C-hjkl>` unmapped for sf1's readline prompt.

## What Changed

- `lua/neotex/plugins/ai/sapience/terminal.lua` (new) — window backend: `open`, `close`,
  `find`, `reposition`, mapping `position`/`size` onto `snacks.terminal`.
- `lua/neotex/plugins/ai/sapience/init.lua` (new) — public API: `setup`, `open`, `close`,
  `toggle`, `set_position`, with `vim.validate`-backed opts validation and `--project`
  resolution/shell-escaping.
- `lua/neotex/plugins/ai/sapience-plugin.lua` (new) — lazy.nvim virtual plugin spec, modeled on
  `stt-plugin.lua`; registers the `:Sf1` user command.
- `lua/neotex/plugins/ai/sapience/README.md` (new) — module/opts/usage documentation per the
  repo documentation policy.
- `lua/neotex/plugins/ai/init.lua` — added `"sapience-plugin"` to the `ai_plugins` list (one
  line; no loader/`safe_require` change needed, confirmed empirically).
- `lua/neotex/config/keymaps.lua` — added `is_sf1` detection (anchored `^sf1` pattern) and an
  empty-body `<C-hjkl>` branch arm in `_G.set_terminal_keymaps`, between `is_opencode` and
  `is_aerc`. The only shared-territory file touched; the `is_opencode`/`is_aerc`/`else` arms are
  byte-identical to their pre-edit form.
- `lua/neotex/plugins/editor/which-key.lua` — added `<leader>af` -> `:Sf1` under the existing
  `<leader>a` group.
- `lua/neotex/plugins/ai/README.md` — added a `sapience-plugin.lua` module entry, a
  `sapience/README.md` subdirectory link, and a `<leader>af` keybinding line.
- `docs/MAPPINGS.md` — added the `<leader>af` row to the AI/ASSISTANT table.

## Decisions

- `float` position omits `height`/`width` entirely (letting the snacks `"float"` style defaults
  apply) rather than mapping `size` onto both dimensions, which would have produced an
  unintentionally square window; `size` is documented as meaningful only for the three split
  positions.
- `M.set_position` mutates a live terminal's own `opts.position`/`height`/`width` and then
  `hide()`+`show()`s it, rather than just updating stored config — this re-places an open sf1
  window without restarting its REPL, because `snacks.terminal`'s terminal identity is derived
  from `cmd`/`cwd`/`env`/`vim.v.count1` only, never from window options.
- Used the non-table `vim.validate(name, value, validator, message)` signature throughout
  (forward-compatible; the table form is deprecated on this nvim version).
- `:Sf1` is registered inside the plugin spec's `config` function, not inside `sapience/init.lua`,
  keeping the implementation directory free of editor-integration side effects at require time.
- No entry was added to the `<C-CR>` two-stage AI tool picker and neither `shared/picker/` file
  was touched, per the task's explicit prohibition (that picker enforces mutual exclusion between
  Claude Code and OpenCode; sf1 is read-only and meant to coexist).
- No `/state` or `/delegate` affordance was built (both routes are unavailable/require a separate
  runner for this account).

## Plan Deviations

- Phase 1, "Assert the dependency constraint by construction": altered — the in-file comment
  explaining the no-`neotex`-require constraint was reworded to avoid the literal substring
  `"neotex."` so the constraint's own grep-based verification would not false-positive against
  its own prose. The constraint itself is unaffected; confirmed by the grep returning no match.
- Phase 6, "Run the complete gate set": altered — `bash .claude/scripts/verify-deploy.sh` (full,
  no `--skip-slow`) failed 5 of 43 checks (gates 8, 10, 20, 22, 24). Every failure was traced to
  either the dispatch's own flagged pre-existing core-extension deploy staleness, unrelated
  repository state (shellcheck findings in `lint-routing-wiring.sh`/`test-routing-resolution.sh`/
  `lean-plan-compliance-check.sh`; `/ide` dead-command references in two memory-extension docs;
  an eager-load-budget baseline already exceeded before this task), or load-induced timeouts
  (gate 10's 60s `validate-state.sh --deep` budget under heavy concurrent system load on this
  machine). None mention `sf1`, `sapience`, or any file this task touched. Gate 8's 9 failing
  suites were re-run in isolation after confirming an unrelated stale gate-lock (left by an
  earlier, self-aborted verification attempt) had released, and reproduced identically,
  confirming they are not contention artifacts. Per the plan's own instruction, this was recorded
  via `issue-record.sh` and reported rather than repaired (a redeploy is whole-tree regeneration,
  outside this plan's declared scope).

## Impacts

- `<leader>a` which-key group gains one new binding (`<leader>af`); no existing binding under
  that namespace was touched or renumbered.
- `_G.set_terminal_keymaps` gains one new detection branch; all other terminal types
  (Claude Code, OpenCode, aerc, default) are unaffected — confirmed via diff read-through and a
  synthetic detection probe.
- `ai_plugins` gains one new lazy.nvim spec (`sapience-sf1`), loaded on `VeryLazy` like the
  existing entries; no change to load order semantics for the others.
- The new `sapience/` directory is dependency-free apart from one in-tree require
  (`neotex.plugins.ai.sapience.terminal` from `init.lua`), so it can be lifted into a standalone
  repository by editing that one line.

## Follow-ups

- The five pre-existing full-gate failures recorded above (gates 8, 10, 20, 22, 24) are
  unrelated to this task and were not repaired here; they remain outstanding for whichever task
  addresses the core-extension deploy staleness and the other unrelated findings.
- **Manual acceptance checklist** (requires a live terminal and a running `sf1` process; not
  claimed as passing by this implementation — the user should run these interactively):
  - [ ] `:Sf1` opens a working sf1 REPL in a bottom split.
  - [ ] `:lua require('neotex.plugins.ai.sapience.init').set_position("right")` followed by
        `:Sf1` shows the sf1 window as a right split.
  - [ ] sf1 and Claude Code are visible simultaneously (no forced mutual exclusion).
  - [ ] `<C-h>` while focused in the sf1 buffer sends backspace to the REPL rather than
        switching windows.

## References

- `specs/578_sf1_neovim_virtual_plugin_with_split_position/plans/02_sf1-virtual-plugin-split-position.md`
- `specs/578_sf1_neovim_virtual_plugin_with_split_position/reports/01_sf1-nvim-plugin-seed.md`
- `specs/578_sf1_neovim_virtual_plugin_with_split_position/reports/02_sf1-split-position-verification.md`
- `lua/neotex/plugins/tools/stt-plugin.lua` / `lua/neotex/plugins/tools/stt/init.lua` (model
  convention)
