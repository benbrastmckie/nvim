# Implementation Plan: Task #578

- **Task**: 578 - Build in-config sf1 Neovim virtual plugin with configurable split position
- **Status**: [IMPLEMENTING]
- **Effort**: 5.25 hours
- **Dependencies**: None
- **Research Inputs**: `specs/578_sf1_neovim_virtual_plugin_with_split_position/reports/02_sf1-split-position-verification.md`, `specs/578_sf1_neovim_virtual_plugin_with_split_position/reports/01_sf1-nvim-plugin-seed.md`
- **Artifacts**: plans/02_sf1-virtual-plugin-split-position.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Build the sf1 terminal-chat surface as a lazy.nvim virtual plugin under
`lua/neotex/plugins/ai/`, following the `stt-plugin.lua` + `stt/init.lua` convention: a thin
spec file at the parent level pointing at a sibling implementation directory. The
implementation directory (`sapience/`) is built bottom-up — a snacks-backed window layer first,
then the public API over it, then the registration and keymap wiring — so that each phase closes
with something independently loadable. The `position`/`size` abstraction is the feature worth
building and gets its own verified mechanics rather than an assumed mapping.

### Research Integration

The second research pass resolved every mechanical unknown the plan would otherwise have had to
guess at, and this plan is built directly on those resolutions:

- All four `position` values (`bottom`/`right`/`left`/`float`) are valid `snacks.win` spellings,
  and `height`/`width` both accept `<1` relative fractions under identical logic. For a split,
  `open_win()` consumes exactly one dimension (`local size = vertical and opts.width or
  opts.height`), so mapping `size` onto both keys is harmless for `bottom`/`left`/`right`.
- For `float`, both dimensions apply, so a single `size` fraction on both keys yields a square
  window. **Decision (resolving research Recommendation 4): option (b)** — when
  `position == "float"`, `terminal.lua` omits `height`/`width` entirely and lets the snacks
  `"float"` style defaults apply; `size` is documented as meaningful only for the three split
  positions, matching the task description's own wording, which never mentions `float`.
- `ai/init.lua`'s `safe_require` acceptance of a `dir=`-style spec table is verified by headless
  execution, not traced. No loader change is expected; Phase 3 confirms it empirically anyway
  because the task description demands verification.
- `<leader>af` is free under both the literal and the loose config-wide sweep, and is not among
  the commented-out `<leader>a*` placeholders. A fresh sweep at authoring time reproduced this
  (`grep -rn "leader>af" --include=*.lua lua/ after/` → no matches), and `Sf1`/`sf1` has no
  existing occurrence anywhere in `lua/` or `after/`.
- The `git` project strategy uses `vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")`
  + `vim.fn.fnamemodify(root, ":t")` inline — stdlib/API only, nothing from `neotex.*`.

Two mechanics this plan establishes beyond the research reports, read from `snacks/win.lua` and
`snacks/terminal.lua` at authoring time because `M.set_position` cannot be specified without
them:

- `snacks.terminal`'s terminal id is derived from `cmd`, `cwd`, `env`, and `vim.v.count1` **only**
  — never from `win` options. Changing the position and re-toggling therefore reuses the same
  terminal object and would re-show it at its original position unless the live object's own
  options are mutated.
- `M:open_win()` reads `self.opts.position` and the resolved `self.opts.height`/`width` at open
  time, and `M:hide()` is `close({ buf = false })`, which preserves the terminal buffer and its
  running job. So mutating a live terminal's `opts` and then `hide()` + `show()` re-places the
  window **without killing the sf1 REPL** — this is what makes `M.set_position` a live operation
  rather than a restart.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A loadable lazy.nvim virtual plugin at `lua/neotex/plugins/ai/sapience-plugin.lua` registered
  through `ai/init.lua`'s existing `ai_plugins` list, visible in `:Lazy`.
- A dependency-free `sapience/` implementation directory (`init.lua` + `terminal.lua`) that
  requires nothing from `neotex.*` and can be lifted into a standalone repository unchanged.
- `position` / `size` as the primary configurable surface, with `M.set_position(pos)` able to
  re-place a live sf1 window without restarting the REPL.
- cwd-derived (or git-root-derived, or caller-supplied) `--project` scoping, shell-escaped.
- A `:Sf1` toggle command and a `<leader>af` which-key binding.
- An `is_sf1` branch in `_G.set_terminal_keymaps` that leaves `<C-h>`/`<C-j>`/`<C-k>`/`<C-l>`
  unmapped so sf1's readline prompt receives them.
- README coverage per the repo documentation policy, plus parent-README and keymap-reference
  consistency.

**Non-Goals**:
- Any entry in the `<C-CR>` two-stage tool picker, and any edit to
  `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` or `shared/picker/config.lua`. The
  picker enforces mutual exclusion over a shared 40% right sidebar; sf1 is meant to coexist.
- Any `/state` or `/delegate` affordance. Both routes return 404 for this account and
  `/delegate` additionally requires a Mac-side runner — any UI would be dead code twice over.
- Any safety gating. sf1 creates only a server-side chat, writes no knowledge objects, and
  leaves the `sapience review` gate and `auto_approve: false` untouched.
- Any change to the `<Esc>` remap guard at `keymaps.lua`'s `if not is_claude and not is_aerc`
  line. The task scopes the sf1 branch to `<C-hjkl>` only; if `<Esc>` later proves to interfere
  with readline's meta prefix, that is a follow-up, not scope creep here.
- A Lua test suite for the new modules. Per the seed report's Recommendation 7, `stt` ships
  none and this module is a thin wrapper over a terminal command whose behavior is almost
  entirely window placement. A headless load check plus a manual acceptance checklist is
  proportionate; this deviation from the repo's "all new Lua modules must have test coverage"
  standard is recorded deliberately here rather than taken silently.
- Any edit under `agent-system/extensions/sapience/`, including the known
  `vault-model.md` line-35 mischaracterization of sf1 as a "one-shot CLI". Both research passes
  flag it as a separate task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `is_sf1` Lua pattern misfires on an unrelated terminal whose cmd merely contains `sf1`, silently stripping `<C-hjkl>` window navigation from it | M | L | Anchor the pattern at the start of the cmd string (`^sf1`), matching the anchoring style `is_opencode` already uses, and verify the existing opencode/aerc/default branches still take their own arms (Phase 4 verification) |
| `M.set_position` is implemented as "update stored config only", so a live hidden terminal re-shows at its old position and the task's own acceptance criterion fails | H | M | Phase 2 mutates the live terminal object's `opts` and then `hide()` + `show()`; the plan records the verified reason (terminal id ignores `win` opts; `open_win()` re-reads `opts.position`) so the implementer cannot mistake it for an optimization |
| An implementing agent treats `shared/picker/ai-tool-picker.lua` as the natural integration point | H | L | The prohibition is in the task description, restated in Non-Goals, and mechanically reinforced: this plan's per-phase `Files to modify` blocks are harvested into the task's `file_scope` by `plan-file-scope-harvest.sh`, and those two paths appear in no phase (discharges research Recommendation 6) |
| `snacks.nvim` absent or failing to load breaks the plugin outright | M | L | All window calls stay behind `terminal.lua`'s `open`/`close`/`find` interface, snacks is loaded via `pcall`, and absence degrades to a single `vim.notify` warning rather than an error |
| A `neotex.*` require leaks into `sapience/init.lua` or `terminal.lua` during implementation, defeating the primary design constraint | H | M | Phase 6 runs an explicit grep assertion over both files as a gate, not an eyeball check |
| `float` ships as an unintentionally square window | L | L | Decision (b) above is named explicitly in Phase 1's task list, not left implicit |
| Phase 6's `verify-deploy.sh` run fails on the pre-existing core-extension deploy staleness flagged in this dispatch's context, unrelated to anything this task touches | M | M | Phase 6 attributes any gate failure to a touched path before acting; a failure tracing solely to the pre-existing staleness is recorded in the issue log and reported, **not** repaired here — a redeploy is whole-tree regeneration, which this plan deliberately does not declare |
| A future `which-key.lua` edit re-enables one of the currently-commented `<leader>a*` bindings and collides | L | L | `<leader>af` is free among both live and commented entries, so no further mitigation is needed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan's chain is strictly linear: each
phase's verification depends on the previous phase's artifact being loadable.

---

### Phase 1: Window Backend (`terminal.lua`) [COMPLETED]

**Goal**: A dependency-free window layer that maps the plugin's `position`/`size` vocabulary onto
`snacks.terminal`, behind an `open`/`close`/`find` interface narrow enough that a `termopen`
backend could replace it by editing this file alone.

**Tasks**:
- [x] Create `lua/neotex/plugins/ai/sapience/terminal.lua` returning a module table `M` with
      exactly three public functions: `M.open(cmd, position, size)`, `M.close(cmd)`,
      `M.find(cmd)`.
- [x] Load snacks through `pcall(require, "snacks.terminal")` in a private `_snacks()` helper.
      On failure, `vim.notify` a single WARN naming snacks as the missing dependency and return
      `nil` from the calling public function — never error.
- [x] Implement a private `_win_opts(position, size)` that returns `{ win = { position = ...,
      enter = true, ... } }`:
      - for `"bottom"`, `"left"`, `"right"`: set **both** `height = size` and `width = size`
        (verified safe — a split's `open_win()` consumes only the one dimension its orientation
        needs);
      - for `"float"`: set **neither** `height` nor `width`, letting the snacks `"float"` style
        defaults apply. This is Decision (b) from the Overview; do not map `size` onto a float.
- [x] `M.open` calls `snacks.terminal.toggle(cmd, _win_opts(...))` so a second invocation on a
      visible window hides it (this is what makes `:Sf1` a toggle without `init.lua` having to
      track visibility itself).
- [x] `M.find(cmd)` calls `snacks.terminal.get(cmd, { create = false })` and returns the window
      object or `nil`. The `create = false` is load-bearing: `get`'s default is `create = true`,
      which would spawn a terminal from a mere lookup.
- [x] `M.close(cmd)` finds via `M.find` and calls `term:close()` when found; no-op otherwise.
- [x] Add a `_reposition(term, position, size)` private helper that mutates
      `term.opts.position`/`height`/`width` per the same `_win_opts` rules and, when
      `term:valid()`, calls `term:hide()` then `term:show()`. Export it as `M.reposition(cmd,
      position, size)` — a fourth function beyond the task's named three, justified because the
      live-reposition mechanic belongs in the window layer, not in `init.lua`, for the backend
      swap to stay a one-file change.
- [x] Assert the dependency constraint by construction: the file contains no `require` of any
      `neotex.*` path, and reads no `vim.g.neotex_*`. *(deviation: altered — the explanatory
      comment stating this constraint avoids the literal substring "neotex." so the
      dependency-assertion grep in Verification does not false-positive on its own prose;
      constraint is still satisfied by construction, confirmed by that grep returning no match)*
- [x] 2-space indent, `~100`-char lines, `snake_case` locals, LuaDoc `---@param`/`---@return`
      on each public function, per `.claude/rules/neovim-lua.md`.

**Timing**: 1.0 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The file is new and nothing requires it yet, so its entire blast radius
is itself; `bash .claude/scripts/tests/run-all.sh --only` has no suite covering this path
(`suite_selection_select` returns `__FULL_SWEEP__` for it), making the honest covering check
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
(sub-case (c): a deploy-consumer-tree path with no mapped suite) alongside the `local` row's
single-module load check.

**Files to modify**:
- `lua/neotex/plugins/ai/sapience/terminal.lua` - new file; the snacks-backed window layer
  exposing open, close, find, and reposition

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.sapience.terminal')" -c "q"` exits 0 with
  no output.
- `nvim --headless -c "lua local t = require('neotex.plugins.ai.sapience.terminal'); print(type(t.open), type(t.close), type(t.find), type(t.reposition))" -c "q"` prints four `function`s.
- `grep -n "neotex\." lua/neotex/plugins/ai/sapience/terminal.lua` returns no match.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
  passes.

---

### Phase 2: Module Core (`sapience/init.lua`) [COMPLETED]

**Goal**: The public API and the whole of the configuration surface — opts schema with
validation, project-string resolution, command-string construction, and the four lifecycle
functions — with every window call delegated to Phase 1's backend.

**Tasks**:
- [x] Create `lua/neotex/plugins/ai/sapience/init.lua` with a module-local `config` table holding
      the defaults: `cmd = "sf1"`, `position = "bottom"`, `size = 0.35`, `project = "cwd"`.
- [x] `M.setup(opts)`: merge `opts` over the defaults with `vim.tbl_deep_extend("force", ...)`,
      then validate. Use the **non-table `vim.validate(name, value, validator, message)`
      signature**, not the deprecated table form: nvim here is v0.12.3, where the table form is
      deprecated (the three existing table-form call sites in this config all live under
      `ai/shared/`, which this task must not touch), and both forms were confirmed callable at
      authoring time, so this is a forward-compatibility choice rather than a necessity.
      Validate: `cmd` string; `position` one of `"bottom"|"right"|"left"|"float"`; `size` a
      number in `(0, 1]`; `project` a string in `{"cwd","git"}`, or `false`, or a function.
- [x] Private `_resolve_project()` returning a project name string or `nil`:
      - `"cwd"` → `vim.fn.fnamemodify(vim.fn.getcwd(), ":t")`;
      - `"git"` → `vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")`
        then `vim.fn.fnamemodify(root, ":t")`, falling back to the `"cwd"` derivation when the
        root is empty (not in a repo);
      - `false` → `nil` (bare `sf1`, which resumes the last project from
        `~/.sapience/sf1_state.json`);
      - function → call it, and treat a non-string or empty return as `nil`.
- [x] Private `_command()` returning the command **string** (not a table — snacks stores the
      first argument verbatim in `vim.b.snacks_terminal.cmd`, and Phase 4's detection reads it):
      `config.cmd` alone when `_resolve_project()` is `nil`, else
      `config.cmd .. " --project " .. vim.fn.shellescape(name)`.
- [x] `M.open()`, `M.close()`, `M.toggle()`: delegate to the backend's `open`/`close`/`open`
      with `_command()` and the current `config.position`/`config.size`. `M.open` and `M.toggle`
      share the backend's toggle semantics; keep both names since the task's API names both.
- [x] `M.set_position(pos)`: validate `pos` against the same four-value enum, assign
      `config.position`, then — if `backend.find(_command())` returns a terminal — call
      `backend.reposition(...)` so a **live REPL is re-placed without being restarted**. When no
      terminal exists, the stored value alone is enough and the next `M.open()` picks it up.
- [x] Same dependency constraint as Phase 1: no `require` of any `neotex.*` path. Require the
      backend by its full module path (`neotex.plugins.ai.sapience.terminal`) — this is the one
      unavoidable in-tree path reference, so make it a single module-local
      `local backend = require(...)` at the top of the file with a comment naming it as the
      **only** line to edit when the directory is lifted into a standalone repository.
- [x] LuaDoc every public function; `pcall` nothing that cannot fail; no global variables.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit adds one new module whose only consumer (the lazy spec) does
not exist until Phase 3, so the blast radius is this file plus the Phase 1 backend it calls, and
the cheapest covering check is `bash .claude/scripts/tests/run-all.sh --only
test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-mcp-merge-target.sh` (the three suites
`suite_selection_select` actually returns for this path) alongside the `local` row's
single-module load check.

**Files to modify**:
- `lua/neotex/plugins/ai/sapience/init.lua` - new file; opts schema, validation, project
  resolution, command construction, `setup`/`open`/`close`/`toggle`/`set_position`

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.sapience.init').setup({})" -c "q"` exits 0.
- `nvim --headless -c "lua local m = require('neotex.plugins.ai.sapience.init'); m.setup({}); print(m._command and 'private-leak' or 'ok')" -c "q"` prints `ok` (the command builder stays private).
- Each invalid-opt case errors: `position = "top"`, `size = 0`, `size = 2`,
  `project = "repo"` each raise from `M.setup`, confirmed with four `pcall` probes.
- `nvim --headless -c "lua local m = require('neotex.plugins.ai.sapience.init'); m.setup({}); m.set_position('right'); print('ok')" -c "q"` prints `ok` with no terminal present.
- `grep -n "require(\"neotex\|require('neotex" lua/neotex/plugins/ai/sapience/init.lua` returns
  exactly one line, the backend require.
- `bash .claude/scripts/tests/run-all.sh --only test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-mcp-merge-target.sh`
  passes.

---

### Phase 3: Spec File, Loader Registration, and `:Sf1` [COMPLETED]

**Goal**: The module becomes a plugin lazy.nvim actually manages, reachable as `:Sf1`.

**Tasks**:
- [x] Create `lua/neotex/plugins/ai/sapience-plugin.lua` modeled line-for-line on
      `lua/neotex/plugins/tools/stt-plugin.lua`: `dir = vim.fn.stdpath('config') ..
      '/lua/neotex/plugins/ai/sapience'`, `name = 'sapience-sf1'`, `event = { 'VeryLazy' }`,
      and a `config = function(_, opts)` body that requires
      `neotex.plugins.ai.sapience.init` through a module-path local (the indirection
      `stt-plugin.lua` uses to avoid static-analysis complaints) and calls `setup(opts)`.
- [x] Keep the spec table free of a `[1]` string, an `import` key, and a `setup` function — all
      three are `ai/init.lua` `safe_require` rejection conditions, and the third is the trap
      that would silently skip the module with only a DEBUG notify.
- [x] Register the `:Sf1` user command inside the spec's `config` body, after `setup`:
      `vim.api.nvim_create_user_command("Sf1", function() require('neotex.plugins.ai.sapience.init').toggle() end, { desc = "Toggle sf1 Sapience chat terminal" })`.
      It belongs here rather than in `sapience/init.lua` so the implementation directory stays
      free of editor-integration side effects at require time.
- [x] Add `"sapience-plugin"` to the `ai_plugins` list in `lua/neotex/plugins/ai/init.lua`,
      preserving the existing alphabetical-ish ordering of that list and changing nothing else
      in the file — in particular, add no `sapience`-specific branch to `safe_require`.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: The spec table is a new externally-consumed surface and `ai/init.lua` is
its single enumerated one-hop dependent, so the `interface` row's "changed module plus its
enumerated direct dependents" is exactly the right breadth; `suite_selection_select` returns the
`__FULL_SWEEP__` sentinel across this phase's touched paths, so no suite covers them and the
honest covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
(sub-case (c)) plus the headless plugin-registration probe below.

**Scope Hypothesis**: This phase asserts that `ai/init.lua`'s existing `safe_require` accepts the
new spec table unchanged, so the only edit to that file is one list entry. Research verified this
by replicating the validation body headlessly, but the implementer MUST confirm it against the
real loader — not the replica — by checking that `sapience-sf1` appears in lazy's plugin list
(verification below). If the plugin is absent, the cause is almost certainly a `setup` key or a
string `[1]` accidentally present in the spec table; fix the spec, and do not add a loader
branch.

**Files to modify**:
- `lua/neotex/plugins/ai/sapience-plugin.lua` - new file; lazy.nvim virtual spec plus the `:Sf1`
  user command
- `lua/neotex/plugins/ai/init.lua` - add `"sapience-plugin"` to the `ai_plugins` list

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.sapience')" -c "q"` exits 0 with no output
  (the task's own stated load check; `sapience/init.lua` is reached via the directory's
  `init.lua`).
- `nvim --headless -c "lua local specs = require('neotex.plugins.ai'); local found = false; for _, s in ipairs(specs) do if s.name == 'sapience-sf1' then found = true end end; print(found)" -c "q"`
  prints `true` — the loader accepted the spec.
- `nvim --headless -c "lua print(vim.tbl_contains(vim.tbl_keys(require('lazy.core.config').plugins), 'sapience-sf1'))" -c "q"`
  prints `true` — lazy registered it (the `:Lazy` criterion, checked without the UI).
- `nvim --headless -c "doautocmd User VeryLazy" -c "lua print(vim.fn.exists(':Sf1'))" -c "q"`
  prints `2` — the command exists after the plugin loads.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
  passes.

---

### Phase 4: Terminal Keymap Branch and `<leader>af` [COMPLETED]

**Goal**: sf1's readline prompt receives `<C-h>` as backspace, and the toggle is reachable from
the `<leader>a` AI group. This is the only phase touching shared-territory files.

**Tasks**:
- [x] In `_G.set_terminal_keymaps` in `lua/neotex/config/keymaps.lua`, add an `is_sf1` local
      alongside the existing `is_opencode` detection, reading the same source
      (`vim.b.snacks_terminal.cmd`, normalized to a string the same way the existing code
      normalizes a table cmd) and matching the **start-anchored** pattern `^sf1` — anchored
      deliberately, so a terminal whose cmd merely contains `sf1` later does not capture this
      branch. Reuse the existing `cmd_str` local rather than recomputing it.
- [x] Add `is_sf1` as its own arm of the existing three-way `<C-hjkl>` branch, placed after
      `is_opencode` and before `is_aerc`, with an empty body and a comment stating why: sf1
      drives a readline prompt where `<C-h>` is backspace, so all four keys are left unmapped
      for the application, exactly as the `is_aerc` arm does.
- [x] Change nothing else in this function — specifically, leave the
      `if not is_claude and not is_aerc` `<Esc>` guard untouched (see Non-Goals) and leave the
      `<M-...>` resize maps below the branch untouched.
- [x] In `lua/neotex/plugins/editor/which-key.lua`, add
      `{ "<leader>af", "<cmd>Sf1<CR>", desc = "sf1 sapience chat", icon = "󰭻" }` inside the
      existing `<leader>a` AI/ASSISTANT group block, adjacent to the other live entries
      (`<leader>ac`, `<leader>ad`, `<leader>as`, `<leader>ar`). Use `<cmd>Sf1<CR>` rather than a
      `require(...)` call so the binding degrades to a clean "command not found" if the plugin
      is disabled, instead of a Lua error.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: `_G.set_terminal_keymaps` is a shared runtime branch whose single
enumerated one-hop dependent is the `TermOpen` autocmd call site in
`lua/neotex/config/autocmds.lua`, which the `interface` row's breadth covers exactly;
`suite_selection_select` returns `__FULL_SWEEP__` for both touched paths, so the covering check
is `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
(sub-case (c)) plus the per-branch regression reads below.

**Scope Hypothesis**: This phase asserts that `<leader>af` is free and that `Sf1` collides with
no existing command. A fresh authoring-time sweep found zero matches for `leader>af` and zero for
`Sf1`/`sf1` across `lua/` and `after/` excluding `deprecated/`. The implementer MUST re-run both
greps before editing — the `<leader>a` namespace is shared and the measurement is point-in-time —
and, on a collision, fall back to `<leader>aq` ("query"), which research names as the alternate
and which the same sweep showed free.

**Files to modify**:
- `lua/neotex/config/keymaps.lua` - add the sf1 detection local and its control-hjkl branch arm
  inside the global terminal-keymap setup function
- `lua/neotex/plugins/editor/which-key.lua` - add the `<leader>af` entry to the `<leader>a` group

**Verification**:
- `grep -rn "leader>af" --include=*.lua lua/ after/ | grep -v deprecated` returns exactly the one
  new line.
- `nvim --headless -c "lua require('neotex.config.keymaps')" -c "q"` exits 0.
- Branch-regression read of the diff: the `is_opencode`, `is_aerc`, and `else` arms are
  byte-identical to their pre-edit form, and the new arm is additive — confirmed with
  `git diff -- lua/neotex/config/keymaps.lua`.
- A synthetic detection probe: set `vim.b.snacks_terminal = { cmd = "sf1 --project nvim" }` and
  `{ cmd = "opencode --port 3421" }` in two scratch buffers and confirm the anchored pattern
  matches the first and not the second.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
  passes.

---

### Phase 5: Documentation [COMPLETED]

**Goal**: The new directory carries a policy-compliant README, and the two existing documents
that would otherwise drift are updated.

**Tasks**:
- [x] Create `lua/neotex/plugins/ai/sapience/README.md` following the documentation policy's
      structure template and `lua/neotex/plugins/tools/stt/README.md`'s shape: purpose; a
      `## Modules` section documenting `init.lua` and `terminal.lua`; the full opts schema with
      defaults and accepted values; usage examples for `:Sf1`, `<leader>af`, and
      `M.set_position("right")`; a `## Dependencies` note naming `snacks.nvim` and the `sf1`
      binary on `$PATH`; and a `## Navigation` section linking back to `../README.md` (the
      policy's Parent Link requirement).
- [x] Document two behaviors in that README that will otherwise read as bugs: (a) `size` applies
      only to `bottom`/`left`/`right` and is ignored for `float`, which uses the snacks float
      style's own defaults; (b) the plugin's default cwd-derived `--project` scoping makes its
      answers differ from the unscoped GNOME `sf1` launcher's — expected, not a defect.
- [x] Also state in that README the extraction constraint: both Lua files are dependency-free
      apart from the single backend require in `init.lua`, and that constraint is the reason the
      directory is shaped this way.
- [x] In `lua/neotex/plugins/ai/README.md`, add a `### sapience-plugin.lua` entry under
      `## Modules`, a `- [sapience/](sapience/README.md)` entry under `## Subdirectories`, and a
      `<leader>af` line under the `**Leader-based AI Commands**` list in the Keybindings section.
      **Decision (resolving research Recommendation 7): yes, add the subdirectory entry.** The
      documentation policy requires navigation links to subdirectory READMEs; the existing
      absence of an `opencode/` entry in this same file is a gap, not a precedent worth copying.
      Do not fix the `opencode/` gap here — it is out of scope.
- [x] In `docs/MAPPINGS.md`, add a `| <leader>af | Normal | Toggle sf1 Sapience chat |` row to
      the existing AI/ASSISTANT (`<leader>a`) table, matching the surrounding row format.
- [x] Cite no task numbers in any of these files (`.claude/rules/no-task-references-in-deliverables.md`),
      and state the current design only, with no draft-history or version framing
      (`.claude/rules/no-record-versioning-in-deliverables.md`).

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: prose

**Tier Justification**: All three files are markdown with no executable surface, and
`suite_selection_select` returns the `__FULL_SWEEP__` sentinel across this phase's touched paths,
so the honest covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
(sub-case (c): deploy-consumer-tree markdown outside `specs/**`, where gate 4's task-reference
lint is the real check and gate 3 would only SKIP) run together with the `prose` row's diff
read-through confirming every hunk is prose.

**Files to modify**:
- `lua/neotex/plugins/ai/sapience/README.md` - new file; module documentation per the
  documentation policy
- `lua/neotex/plugins/ai/README.md` - add module entry, subdirectory link, and keybinding line
- `docs/MAPPINGS.md` - add the `<leader>af` row to the AI/ASSISTANT table

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 4 /home/benjamin/.config/nvim`
  passes.
- The new README contains a `## Navigation` link resolving to `../README.md`, and
  `lua/neotex/plugins/ai/README.md` contains `sapience/README.md`; both confirmed by grep.
- Diff read-through: every changed hunk in all three files is prose or a markdown table row.

---

### Phase 6: Verification and Acceptance [NOT STARTED]

**Goal**: Prove the whole integration loads clean, the design constraints hold mechanically, and
hand the user the short interactive checklist that cannot be run headlessly.

**Tasks**:
- [ ] Run the full headless suite below and record each result.
- [ ] Assert the primary design constraint mechanically, not by reading:
      `grep -rn "require(.neotex" lua/neotex/plugins/ai/sapience/` must return **exactly one**
      line (the backend require in `init.lua`), and `grep -rn "vim.g.neotex\|neotex\.plugins\.ai\.shared"
      lua/neotex/plugins/ai/sapience/` must return none.
- [ ] Assert the prohibitions mechanically: `git status --short` shows no modification to
      `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` or `shared/picker/config.lua`,
      and `grep -rn "sf1\|Sf1" lua/neotex/plugins/ai/shared/` returns nothing.
- [ ] Assert no `/state` or `/delegate` affordance was built:
      `grep -rniE "delegate|/state|v1/sf1" lua/neotex/plugins/ai/sapience/` returns nothing
      outside the README's own prose, if anything at all.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Before acting on any
      failure, attribute it to a path this task touched; a failure tracing solely to the
      pre-existing core-extension deploy staleness flagged in this dispatch's context is recorded
      via `issue-record.sh` and reported, **not** repaired here (a redeploy is whole-tree
      regeneration, outside this plan's declared scope).
- [ ] Write the manual acceptance checklist into the implementation summary for the user to run
      interactively, verbatim from the task's own verification line: `:Sf1` opens a working sf1
      REPL in a bottom split; `:lua require('neotex.plugins.ai.sapience.init').set_position("right")`
      then `:Sf1` shows it as a right split; sf1 and Claude Code are visible simultaneously;
      `<C-h>` in the sf1 buffer sends backspace to the REPL rather than switching windows. These
      four require a live terminal and a running `sf1` process and are explicitly **not**
      claimed as passing by this phase.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- (none — verification only)

**Verification**:
- The complete gate set for the repository passes: `bash .claude/scripts/verify-deploy.sh`.
- `nvim --headless -c "lua require('neotex.plugins.ai.sapience')" -c "q"` exits 0 with no output.
- `nvim --headless -c "lua require('neotex.plugins.ai.sapience.terminal')" -c "q"` and
  `... require('neotex.config.keymaps')" -c "q"` both exit 0.
- `nvim --headless -c "lua print(vim.tbl_contains(vim.tbl_keys(require('lazy.core.config').plugins), 'sapience-sf1'))" -c "q"`
  prints `true`.
- `nvim --headless -c "doautocmd User VeryLazy" -c "lua print(vim.fn.exists(':Sf1'))" -c "q"`
  prints `2`.
- `nvim --headless -c "checkhealth" -c "q"` surfaces no new error attributable to the plugin.
- The four dependency/prohibition grep assertions above return their stated results.
- The manual acceptance checklist is present in the summary artifact, marked as user-run.

## Testing & Validation

- [ ] Every new and modified Lua file loads headlessly without error or warning.
- [ ] `sapience-sf1` is registered with lazy and `:Sf1` exists after `VeryLazy`.
- [ ] All four `position` values are accepted by `M.set_position` and all four invalid-opt cases
      are rejected by `M.setup`.
- [ ] `sapience/` contains exactly one `neotex.*` require, and no reference to `neotex.plugins.ai.shared`.
- [ ] Neither `shared/picker/` file is modified, and neither mentions sf1.
- [ ] No `/state` or `/delegate` affordance exists in the implementation files.
- [ ] `<leader>af` is bound exactly once across `lua/` and `after/`.
- [ ] The `is_opencode`, `is_aerc`, and default `<C-hjkl>` arms are unchanged from their
      pre-edit form.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes, or every failure is attributed to a path
      this task did not touch and recorded.
- [ ] The manual acceptance checklist is handed to the user rather than claimed as passing.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/sapience-plugin.lua` (new)
- `lua/neotex/plugins/ai/sapience/init.lua` (new)
- `lua/neotex/plugins/ai/sapience/terminal.lua` (new)
- `lua/neotex/plugins/ai/sapience/README.md` (new)
- `lua/neotex/plugins/ai/init.lua` (modified: one list entry)
- `lua/neotex/config/keymaps.lua` (modified: `is_sf1` detection and branch arm)
- `lua/neotex/plugins/editor/which-key.lua` (modified: `<leader>af` entry)
- `lua/neotex/plugins/ai/README.md` (modified: module entry, subdirectory link, keybinding line)
- `docs/MAPPINGS.md` (modified: one table row)
- `specs/578_sf1_neovim_virtual_plugin_with_split_position/summaries/02_*-summary.md`, carrying
  the manual acceptance checklist

## Rollback/Contingency

Every edit is additive and confined to nine files, four of which are new. To revert:

- Delete `lua/neotex/plugins/ai/sapience-plugin.lua` and the `lua/neotex/plugins/ai/sapience/`
  directory.
- Revert the single-line additions in `lua/neotex/plugins/ai/init.lua`,
  `lua/neotex/plugins/editor/which-key.lua`, and `docs/MAPPINGS.md`, and the three-entry
  addition in `lua/neotex/plugins/ai/README.md`.
- Revert the `is_sf1` local and branch arm in `lua/neotex/config/keymaps.lua` — the one
  shared-territory file, and the only revert that affects behavior outside this feature.

Because each phase commits on its own green verification, a failure mid-plan leaves the
preceding phases' work intact and independently revertible. Before any rollback that would
discard uncommitted work, take a checkpoint first:
`bash .claude/scripts/git-snapshot.sh 578 --no-revert` for an ordinary defensive checkpoint, or
the default reverting form only for a genuine rollback.
