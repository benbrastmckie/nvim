# Research Report: sf1 Virtual Plugin — Position/Size Mechanics and Loader Verification

- **Task**: 578 - Build in-config sf1 Neovim virtual plugin with configurable split position
- **Started**: 2026-11-10T19:45:17Z
- **Completed**: 2026-11-10T20:10:00Z
- **Effort**: ~30 minutes (second research pass, building on the seed report)
- **Dependencies**: `specs/578_sf1_neovim_virtual_plugin_with_split_position/reports/01_sf1-nvim-plugin-seed.md` (seed report)
- **Sources/Inputs**:
  - `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/win.lua`, `lua/snacks/terminal.lua` (installed plugin source, read directly)
  - `lua/neotex/plugins/ai/init.lua`, `lua/neotex/plugins/tools/stt-plugin.lua` (executed via `nvim --headless -l`)
  - `lua/neotex/config/keymaps.lua`, `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/plugins/ai/opencode.lua`, `lua/neotex/plugins/ai/claudecode.lua`
  - `lua/neotex/plugins/ai/README.md`, `lua/neotex/plugins/tools/README.md`, `.claude/context/project/neovim/standards/documentation-policy.md`
  - Live HTTPS re-probe against `https://app.spnc.ai` (read-only GETs, 2026-11-10)
  - `specs/state.json` (task 578's current record; no `file_scope` set)
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- The single largest open question from the seed report — whether `snacks.terminal`'s four position values and `size` key all behave as the task description assumes — is now resolved by reading `snacks.win`'s source directly: all of `float`/`bottom`/`left`/`right` are valid `position` values, and `height`/`width` both accept relative (`<1`) fractions uniformly across positions.
- For a **split** (`bottom`/`left`/`right`), `snacks.win:open_win()` consumes only one dimension — `local size = vertical and opts.width or opts.height` — so mapping `size` to both `height` and `width` unconditionally in `terminal.lua` is safe: the unused key is computed but never applied to a `:resize`.
- For **`float`**, both `height` and `width` are applied directly to `nvim_open_win`, so a single `size` fraction mapped to both keys produces a `size × size` square float rather than the conventional wide/short shape other floats in this config use (`Snacks.config.style("float", {height=0.9, width=0.9})`). This needs an explicit decision in the plan (see Recommendations).
- The `ai/init.lua` loader-acceptance claim (seed finding 4) is now verified by execution, not just code trace: a headless Lua run of the planned `sapience-plugin.lua` spec table against `ai/init.lua`'s actual `safe_require` validation logic falls through all three rejection checks and is accepted, exactly like the control case (`stt-plugin.lua`'s real spec).
- The four capability probes and the `<leader>a` namespace sweep were re-run fresh rather than inherited from the seed; both reproduced identically (`/v1/sf1/handoff` 200, `/v1/sf1/state` 404, `/v1/sf1/delegate` 404, `/v1/work` 200; taken suffixes `a b c d h i k l m oo p r s t w W y`, free `e f g j n q u v x z`). No drift from the seed's point-in-time measurement.
- The repo-wide idiom for the `project = "git"` strategy already exists and is dependency-free: `vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")` then `vim.fn.fnamemodify(root, ":t")`, used identically in six other files in this config (none of them in `neotex.plugins.ai.sapience`'s future dependency graph).

## Context & Scope

This report is the second research pass for this task and builds directly on
`01_sf1-nvim-plugin-seed.md`, which the dispatch's user focus names explicitly. It does not
restate the seed's findings; it resolves the seed's open items (its own Recommendations 1-5) by
reading `snacks.nvim` source, executing the loader-validation logic, and re-running the two
time-sensitive measurements (server capability probes, keymap namespace sweep). Findings below
are freshly derived in this session unless marked otherwise.

Out of scope, per the task description and consistent with the seed: the `<C-CR>` two-stage
picker, any `/state`/`/delegate` affordance, and `agent-system/extensions/sapience/`.

## Findings

### 1. `snacks.win` position values — all four required values exist, plus two more

`lua/snacks/win.lua` declares the field type directly:
```
---@field position? "float"|"bottom"|"top"|"left"|"right"|"current"
```
and `M.new()` branches only on `opts.position == "float"` vs. everything else (treated as a
split), with `current` as its own branch that reuses the current window. `bottom`, `left`, and
`right` are therefore ordinary, already-exercised split positions — not edge cases — and `top`
exists as a bonus the task doesn't ask for.

### 2. `height`/`width` resolution — confirmed uniform, confirmed split-only-uses-one

Two separate pieces of `snacks.win` code settle this:

- `win.lua`'s window-geometry calculator computes `ret.height` and `ret.width` unconditionally
  from `self.opts.height`/`self.opts.width` via a shared `size()` helper that treats `<1` as a
  relative fraction of the parent dimension and `0` as full-size — identical logic for both
  keys, independent of `position`.
- `M:open_win()`'s split branch picks exactly one of them for the actual `:resize` call:
  `local vertical = position == "left" or position == "right"` then
  `local size = vertical and opts.width or opts.height`. The float branch instead passes the
  resolved `opts` table (both height and width) straight to `vim.api.nvim_open_win`.

Consequence for `terminal.lua`: mapping the plugin's single `size` option to **both**
`win.height` and `win.width` on every call is safe for `bottom`/`left`/`right` (the unused key is
silently ignored), but for `float` it sets both dimensions to the same fraction, yielding a
square-ish window. This repo's existing floats (`Snacks.config.style("float", {height = 0.9,
width = 0.9})`, and `claudecode.lua`/`opencode.lua` which never use `float`) give no in-repo
precedent for what a "right-sized" sf1 float should be — this is a genuinely open design choice,
not a fact to look up.

### 3. `ai/init.lua` loader acceptance — now verified by execution

The seed report's finding 4 was a code trace ("this is a code trace, not an executed test").
This pass replicated `ai/init.lua`'s exact `safe_require` validation body in a standalone script
and ran it headlessly (`nvim --headless -l`) against the literal spec table the plan would
produce for `sapience-plugin.lua` (`dir=...`, `name='sapience-sf1'`, `event='VeryLazy'`,
`config=function(_, opts) ... end`, no `[1]`, no `.setup`, no `.import`):

```
sapience-plugin.lua spec validation: ACCEPTED (falls through, returns spec table)
stt-plugin.lua spec validation (control): ACCEPTED (falls through, returns spec table)
```

Both the planned spec and a `dofile()` of the real `stt-plugin.lua` (as a control) pass through
all three rejection checks identically. The task's own instruction to verify rather than assume
this is now discharged; no loader change is needed.

### 4. Capability probes and keymap sweep re-run fresh — no drift

Re-running the seed's exact probe commands against the live server reproduced the identical
result set: `GET /v1/sf1/handoff` → 200, `GET /v1/sf1/state` → 404, `GET /v1/sf1/delegate` → 404,
`GET /v1/work` → 200. Re-running both `which-key.lua`/`keymaps.lua` grep sweeps for `<leader>a*`
also reproduced the seed's taken set (`a b c d h i k l m oo p r s t w W y`) and free set
(`e f g j n q u v x z`) exactly, including that `<leader>as` is taken by `DiscordSessions`
(`which-key.lua:300`). Decision 5 (no `/state`/`/delegate` UI) and the free-suffix set both stand
on fresh evidence, not inherited ones.

One refinement visible in the live file that the seed's grep pattern could not distinguish: of
the taken suffixes, `aa`, `ab`, `ah`, `ai`, `ap`, `at`, `am` are currently **commented out** in
`which-key.lua` (disabled OpenCode/TTS bindings), while `ac`, `ad`, `ar`, `as`, `ay`, `ak` are
live. Both groups still count as "taken" for planning purposes — a commented binding is a
placeholder likely to be re-enabled, not a safe reuse target — so this refinement does not change
the free set, only its provenance.

### 5. `project = "git"` strategy — dependency-free idiom already exists in this repo

`vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")` is used verbatim (or
with a trailing `:is-inside-work-tree`/`--git-dir` variant) in six files under
`lua/neotex/plugins/ai/claude/**` and `lua/neotex/core/git-info.lua`. None of those call sites are
`require`d by `neotex.*` modules outside the `ai/claude/` tree, so reusing the same shell-call
pattern directly inside `sapience/init.lua` (not by requiring one of those modules) keeps the
dependency-free constraint intact: `vim.fn.system(...)` plus `vim.fn.fnamemodify(root, ":t")` is
stdlib/API-only, nothing `neotex.*`.

### 6. `vim.fn.shellescape` is the established repo idiom for shelling out to external commands

`himalaya/sync/lock.lua`, `himalaya/commands/utility.lua`, and `himalaya/setup/health.lua` all
build shell command strings with `vim.fn.shellescape(...)` around interpolated values. The task's
instruction to shell-escape the `--project` argument the same way is consistent with existing
practice, not a new convention. Because `terminal.lua` will hand `snacks.terminal.open/toggle` a
single command **string** (matching `opencode.lua`'s own `"opencode --port " .. port` pattern, a
string, not a table), `vim.fn.shellescape` is the correct escaping call for that string-building
step.

### 7. The `is_sf1` keymap branch's detection surface, confirmed at exact source

`_G.set_terminal_keymaps` in `lua/neotex/config/keymaps.lua`:
- Line 116: function start.
- Lines 122-129: `is_claude` (bufname match), `is_opencode` (reads `vim.b.snacks_terminal.cmd`,
  matches Lua pattern `opencode%s+%-%-port`), `is_aerc` (bufname match).
- Line 134: `if not is_claude and not is_aerc then` — the `<Esc>` remap guard.
- Lines 142-153: the `is_opencode` / `is_aerc` / default three-way branch for `<C-h/j/k/l>`.

`vim.b.snacks_terminal` is set by `snacks/terminal.lua`'s own `on_buf` callback to
`{ cmd = cmd, id = id, cwd = opts.cwd, env = opts.env }`, where `cmd` is exactly the first
argument passed to `M.open`/`M.toggle` — i.e., whatever string `terminal.lua` constructs
(`"sf1"` or `"sf1 --project " .. vim.fn.shellescape(name)`). A pattern anchored on `^sf1` against
that string (the same anchoring style `is_opencode` uses, just without the `--port` suffix
requirement sf1 has no equivalent of) is sufficient and requires no change to how `opencode`'s
own branch is detected.

### 8. Documentation-policy consistency check for the new `sapience/` subdirectory

`documentation-policy.md` requires a "Parent Link" from a subdirectory README back to its
parent's README — `sapience/README.md` must link to `../README.md` (i.e.
`lua/neotex/plugins/ai/README.md`). Whether `ai/README.md` itself needs a new "Subdirectories"
entry for `sapience/` is a softer call: `tools/README.md` lists both `himalaya/` and `stt/` under
"Specialized Subdirectories" (the precedent the task cites), but `ai/README.md` currently lists
only `claude/` under "## Subdirectories" and has no entry at all for the already-existing
`opencode/` subdirectory — so the parent-side link is not uniformly enforced in this directory
today. This is a planning-level choice (add a `sapience/` entry to stay consistent with the
`tools/` precedent, or not, matching the `opencode/` omission already present) rather than a
hard requirement from the task description, which does not mention `ai/README.md`.

## Decisions

Carried forward from the seed, now resting on freshly re-verified evidence in this pass (not
carried blind): decisions 1-7 in the seed report stand unchanged. This pass adds one:

8. **`terminal.lua` maps `size` to both `win.height` and `win.width` unconditionally** for
   `bottom`/`left`/`right`, since finding 2 shows the unused key is harmless for splits. For
   `float`, the plan must make an explicit choice (see Recommendations) rather than relying on
   the same unconditional mapping producing a well-proportioned window by accident.

## Recommendations

Carrying the seed's recommendation numbering forward (this pass resolves 1-3 and 5 fully, and
narrows 4):

1. **(Resolves seed Rec. 1)** Capability probes re-run fresh in this pass; no further action
   needed before planning.
2. **(Resolves seed Rec. 2)** Loader acceptance verified by execution in this pass (Finding 3);
   no loader change needed, and the plan does not need to re-verify this.
3. **(Resolves seed Rec. 3)** Use `<leader>af` — confirmed free in both the seed's sweep and this
   pass's fresh re-sweep, and not among the commented-out placeholders in Finding 4's refinement
   (so it is unambiguously free, not merely "currently disabled").
4. **(Narrows seed Rec. 4)** `terminal.lua`'s position→win-option mapping is fully specified for
   `bottom`/`left`/`right` (Decision 8). For `float`, the plan must choose one of:
   (a) map `size` to both `height` and `width` anyway, accepting a square-ish float; or
   (b) when `position == "float"`, omit explicit `height`/`width` from the `win` table entirely
   and let `snacks.win` fall back to the `"float"` style's `0.9`/`0.9` defaults, treating `size`
   as meaningful only for the three split positions. Option (b) matches "size (fraction; maps to
   window height for bottom, width for right/left)" in the task description more literally, since
   that sentence never mentions `float`.
5. **(Resolves seed Rec. 5)** Implement the `git` project strategy with
   `vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")` +
   `vim.fn.fnamemodify(root, ":t")` directly inside `sapience/init.lua`, matching the idiom used
   six times elsewhere in this config (Finding 5) without requiring any of those modules.
6. **(Seed Rec. 6, unresolved by research — a process point for the orchestrator/planner)** No
   `file_scope` is currently set on this task (confirmed by reading `specs/state.json`'s task 578
   record directly in this pass). Since the task description already carries two hard `MUST NOT`
   constraints naming `shared/picker/ai-tool-picker.lua` and `shared/picker/config.lua`, the plan
   should declare `file_scope` explicitly so an implementing agent is mechanically prevented from
   touching those files, rather than relying on the prose constraint alone.
7. **New**: decide, at plan time, whether `ai/README.md` gains a `sapience/` entry under its
   "Subdirectories" section. Either choice is defensible given the mixed precedent in Finding 8;
   record whichever is chosen as a deliberate decision rather than an oversight either way.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `float` position ships with an unintentionally square window because the uniform `size`→height/width mapping was applied without the explicit choice Recommendation 4 calls for | Plan must name option (a) or (b) explicitly in its `terminal.lua` phase, not leave it implicit |
| A future `which-key.lua` edit re-enables one of the currently-commented `<leader>a*` bindings (Finding 4) and collides with whatever suffix this task picks | `<leader>af` is free in both live and commented entries, so this risk is already minimized; no further mitigation needed |
| An implementing agent edits `shared/picker/*` because the prose prohibition is easy to miss mid-implementation | Recommendation 6: declare `file_scope` on the task record |

## Context Extension Recommendations

Carried from the seed report, unchanged by this pass (out of this task's scope, each a candidate
for a separate task):

- **Topic**: sf1's actual interface and the SF-1 server capability split — see seed report
  Finding/Recommendation on `agent-system/extensions/sapience/.../vault-model.md` line 35.
- **Topic**: `neovim` task-type detectability via `keyword_overrides` — see seed report.

## Appendix

### Loader-verification script (reproducible)

```lua
-- Replicates ai/init.lua's safe_require validation logic verbatim, against the
-- exact spec table shape the sf1 plan would return (sapience-plugin.lua), run via
-- `nvim --headless -l <script>`.
local function safe_require_validate(result)
  if type(result) == "table" then
    if type(result[1]) == "string" then return "REJECTED: has string [1]" end
    if result.import then return "REJECTED: has .import" end
    if result.setup and type(result.setup) == "function" and not result[1] then
      return "REJECTED: has .setup function and no [1]"
    end
    return "ACCEPTED (falls through, returns spec table)"
  end
  return "REJECTED: not a table"
end
```

### Capability-probe reproduction (unchanged from seed, re-run in this pass)

```bash
TOK=$(python3 -I -c "import json;print(json.load(open('$HOME/.sapience/config.json')).get('token',''))")
for p in /v1/sf1/handoff /v1/sf1/state /v1/sf1/delegate /v1/work; do
  curl -sS -o /dev/null -w "$p HTTP %{http_code}\n" --max-time 10 \
    -H "Authorization: Bearer $TOK" -H "User-Agent: sf1/0.1.0" "https://app.spnc.ai$p"
done
```

### References

- `specs/578_sf1_neovim_virtual_plugin_with_split_position/reports/01_sf1-nvim-plugin-seed.md` — prior pass, structural precedent, server capability split, keymap namespace
- `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/win.lua` (geometry calculator, `M.new`, `M:open_win`) and `lua/snacks/terminal.lua` (`M.open`, `on_buf`) — primary source for Findings 1-2, 7
- `lua/neotex/plugins/ai/claude/core/session.lua`, `worktree.lua`, `core/visual.lua`, `claude-session/git.lua`, `ui/native-sessions.lua`, `lua/neotex/core/git-info.lua` — `git rev-parse --show-toplevel` idiom (Finding 5)
