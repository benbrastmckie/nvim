# Research Report: sf1 Neovim Virtual Plugin Seed Findings

- **Task**: 578 - Build in-config sf1 Neovim virtual plugin with configurable split position
- **Started**: 2026-11-10T18:50:00Z
- **Completed**: 2026-11-10T19:45:00Z
- **Effort**: ~1 hour (seed only; not a complete research pass)
- **Dependencies**: None
- **Sources/Inputs**:
  - Installed vendor payload: `~/.sapience/sf1.py`, `~/.sapience/mcp.py`, `~/.sapience/config.json`
  - Nix wrappers: `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix`, `/etc/profiles/per-user/benjamin/bin/{sf1,sapience}`
  - Machine configuration record: `~/.dotfiles/docs/sapience.md`
  - Precedent modules: `lua/neotex/plugins/tools/stt-plugin.lua`, `lua/neotex/plugins/tools/stt/init.lua`, `lua/neotex/plugins/tools/himalaya-plugin.lua`, `lua/neotex/plugins/tools/himalaya/_plugin.lua`
  - Loader and picker: `lua/neotex/plugins/ai/init.lua`, `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`, `lua/neotex/plugins/ai/shared/picker/config.lua`
  - Window owners: `lua/neotex/plugins/ai/claudecode.lua`, `lua/neotex/plugins/ai/opencode.lua`
  - Keymaps: `lua/neotex/config/keymaps.lua`, `lua/neotex/plugins/editor/which-key.lua`
  - Extension docs: `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md`, `.../subagent-orientation.md`
  - Live HTTPS probes against `https://app.spnc.ai` (read-only GETs, 2026-11-10)
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Project Context

- **Upstream Dependencies**: `snacks.nvim` (`snacks.terminal`) for window management; the `sf1` binary on `$PATH` (nix wrapper at `/etc/profiles/per-user/benjamin/bin/sf1`); `~/.sapience/sf1.py` payload and `~/.sapience/config.json` token
- **Downstream Dependents**: None. No existing module requires the planned `neotex.plugins.ai.sapience` namespace
- **Alternative Paths**: MCP `sapience_ask` already answers vault questions inside a Claude Code session, so this plugin is additive rather than enabling
- **Potential Extensions**: later extraction to a standalone repository; a `termopen` fallback backend replacing the snacks dependency

## Executive Summary

- sf1 is not a separate product and is undocumented publicly: it ships inside the Sapience vendor payload as `~/.sapience/sf1.py` (653 lines, stdlib-only, self-identifying as `VERSION = '0.1.0 (2026-10-22)'`), and four pages of `spnc.ai` carry no mention of it.
- The repository already contains the exact structural pattern this task needs, used twice: a `<name>-plugin.lua` lazy.nvim virtual spec pointing at a sibling implementation directory via `dir = vim.fn.stdpath('config') .. '/lua/.../<name>'`. `stt` is the clean model; `himalaya` is the same shape at much larger scale.
- The `<C-CR>` picker is built on mutual exclusion between two agents contending for the same 40%-width right sidebar. sf1 is read-only and edits no buffers, so it belongs outside that picker — the task's prohibition is load-bearing, not stylistic.
- Three of the four SF-1 server routes the client knows about are unavailable to this account: `GET /v1/sf1/state` and `GET /v1/sf1/delegate` both return 404, and `/v1/sf1/delegate` additionally requires a Mac-side runner the client names explicitly. Only `/v1/sf1/handoff` and `/v1/work` answer.
- sf1 and the MCP server reach different engines — sf1 POSTs `/v1/sapience-chats/ask?stream=1` (multi-turn, persisted as a chat), MCP `sapience_ask` GETs/POSTs `/v1/ask` (one-shot) — which is the entire functional justification for a terminal surface inside the editor.
- `<leader>as`, which earlier conversation floated for this binding, is already taken by `DiscordSessions`. A two-pattern sweep gives the free set below.

## Context & Scope

This is a **seed report written at task creation**, not a completed research pass. It records what was measured while answering the conversational question that produced the task, so a research dispatch can skip re-deriving it and spend its budget on the open questions in `## Recommendations`.

In scope: the structural precedent for an in-config virtual plugin; the window-ownership facts that constrain where an sf1 terminal can live; the live capability surface of the sf1 client and its server; the keymap namespace.

Out of scope, deliberately: anything under `agent-system/extensions/sapience/` (a separate deliverable area), the `/v1/sf1/delegate` feature set (unavailable — see Findings), and any modification to the two-stage tool picker.

### Freshness caveat

The server-capability findings are measurements of a hosted service on 2026-11-10. They are cheap to re-run (four `curl` GETs with the token from `~/.sapience/config.json`) and a research dispatch should re-run them rather than inherit them, because a vendor deploy could land `/v1/sf1/state` at any time and that would change what `/state` does.

## Findings

### 1. sf1's provenance and shape

- `~/.sapience/sf1.py` is 653 lines, imports only the standard library, and its module docstring describes it as "your Sapience's SF-1 in the terminal ... SF-1 P0 piece C".
- `sf1 --version` prints `sf1 0.1.0 (2026-10-22)`.
- The vendor's own naming splits SF-1 into three pieces, each visible in the client's code as a distinct route family: piece A `/v1/sf1/delegate` (hand a task to headless Claude Code or Codex), piece B `/v1/sf1/state` (approved versioned project state), piece C `/v1/sf1/handoff` plus the chat itself.
- A fetch of `https://spnc.ai/`, `/sapience`, `/intro`, and `/research/` found no occurrence of "SF1" or "sf1", and no CLI, install, or documentation section anywhere on the site. Treat the installed payload and `~/.dotfiles/docs/sapience.md` as the only available documentation.

### 2. The machine side is already built

- `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix` builds the `sf1` wrapper (`sf1Cli`, from line 259), which exports `SAPIENCE_HOST` and `NO_MEMFILES=1`, checks that `~/.sapience/sf1.py` exists, and `exec`s it under the nix `python3`.
- `sapience sf1 "$@"` dispatches to the same payload (same file, line 197), so there are two equivalent entry points.
- The nix module also installs an `sf1.desktop` GNOME launcher. That launcher passes no `--project` argument, so it retrieves account-wide; a cwd-derived `--project` inside Neovim would be strictly better scoped.
- Nothing needs installing for this task. The binary is on `$PATH` at `/etc/profiles/per-user/benjamin/bin/sf1`.

### 3. The in-config virtual-plugin precedent (the structural answer)

Two existing modules use the pattern this task should follow:

| File | Role |
|------|------|
| `lua/neotex/plugins/tools/stt-plugin.lua` | 15-line lazy.nvim spec: `dir = vim.fn.stdpath('config') .. '/lua/neotex/plugins/tools/stt'`, `name = 'stt'`, `event = { 'VeryLazy' }`, `config = function(_, opts) require('neotex.plugins.tools.stt.init').setup(opts) end` |
| `lua/neotex/plugins/tools/stt/init.lua` | 562 lines, single file, `M.setup(opts)` |
| `lua/neotex/plugins/tools/himalaya-plugin.lua` | Same shape, plus a `dependencies` block marking telescope `optional = true` |
| `lua/neotex/plugins/tools/himalaya/` | 128 Lua files across `core/`, `config/`, `ui/`, `test/`, `sync/`, and others |

Both are registered in `lua/neotex/plugins/tools/init.lua` by `safe_require` of the `-plugin` module followed by `add_if_valid` (lines 84, 87, 113, 122). Note that `tools/init.lua` carries a `himalaya-plugin`-specific special case at its lines 55-56 ("should return its own spec, not expose the full module") — `ai/init.lua` has no equivalent branch, which is relevant to finding 4.

A second, older spec also exists at `lua/neotex/plugins/tools/himalaya/_plugin.lua`. It returns a two-element list rather than a single spec table and is not the file `tools/init.lua` loads. The `-plugin.lua`-at-parent-level form is the live convention; do not model on `_plugin.lua`.

**Extraction-readiness contrast, which is the reason the task names both**: `stt/init.lua` requires nothing from `neotex.*` — it reads configuration from `vim.g.stt_*` globals and reports through `vim.notify`. `himalaya` requires freely across the config. That difference, not size, is what makes one liftable and the other welded in.

### 4. The `ai/init.lua` loader will accept a spec table — traced, not executed

`lua/neotex/plugins/ai/init.lua` holds its own `safe_require` (lines 9-39) and an `ai_plugins` list (lines 44-49) currently containing `claudecode`, `lectic`, `mcp-hub`, `opencode`. Its validation runs three checks in order and returns `result` if none match:

1. `type(result[1]) == "string"` — a `-plugin.lua` spec has no `[1]`, so no.
2. `result.import` — absent, so no.
3. `result.setup and type(result.setup) == "function" and not result[1]` — a spec table's entry point is `config`, not `setup`, so no.

Falling through all three, it returns the spec table and `table.insert(plugins, plugin_spec)` registers it. **This is a code trace, not an executed test.** The task description already requires verifying rather than assuming it; that instruction stands, and this finding only predicts the outcome.

The practical trap this implies: if the implementation puts `M.setup` and the spec in the *same* returned table, check 3 fires and the module is silently skipped with a DEBUG-level notify. Keeping the spec (`sapience-plugin.lua`) and the module (`sapience/init.lua`) in separate files avoids this by construction, which is why the convention exists.

### 5. Why sf1 must stay out of the `<C-CR>` picker

Both existing picker entries claim the same screen region:

- `lua/neotex/plugins/ai/claudecode.lua:10-11` — `split_ratio = 0.40`, `position = "vertical"`.
- `lua/neotex/plugins/ai/opencode.lua` (config block, around lines 40-44) — `position = "right"`, `width = 0.40`, `enter = true`, passed to `snacks.terminal`.

And the picker enforces exclusivity rather than merely defaulting to it:

- `ai-tool-picker.lua`'s `show_tool_picker()` hides the non-chosen tool before opening the chosen one (the `detect_active_opencode` / `detect_active_claude` branches around lines 222-245).
- `smart_toggle()` (from line 472) has a both-running branch whose documented cycle is `just opencode -> just claude -> neither -> just opencode`. There is no state in which both are visible.
- Detection is identity-based per tool: `detect_active_claude()` reads the `claude-code` plugin's own `claude_code.instances` registry with a buffer-name fallback; `detect_active_opencode()` matches `snacks_terminal.cmd` against the Lua pattern `opencode%s+%-%-port`.

sf1 creates a server-side chat and writes no files and no knowledge objects, so it cannot conflict with a coding agent over buffers — the hazard the exclusion exists to prevent does not apply to it. Adding it as a third Stage-1 peer would make selecting sf1 *hide* the coding agent, which inverts its purpose, and would additionally require excluding sf1 from the `smart_toggle` cycle, turning a two-state machine into a two-plus-one-state machine.

A second, independent reason: Stage 1 routes every entry into a Stage-2 session picker (`show_claude_session_picker`, `show_opencode_session_picker`). sf1 has no selectable session list — its session concept is the server-derived handoff, and `~/.sapience/sf1_state.json` persists a single last-project string. An sf1 entry would dead-end.

### 6. The terminal-keymap branch sf1 needs

`_G.set_terminal_keymaps` in `lua/neotex/config/keymaps.lua` (lines 115-154) classifies the buffer and branches:

- `is_claude` (buffer-name match) and `is_aerc` suppress the `<Esc>` remap.
- `is_opencode` (snacks cmd match on `opencode%s+%-%-port`) maps `<C-j>`/`<C-k>` to arrow keys and `<C-h>`/`<C-l>` to window navigation, plus `<C-g>` to toggle.
- `is_aerc` deliberately leaves `<C-hjkl>` unmapped so the application receives them.
- The `else` arm maps all four of `<C-h>`/`<C-j>`/`<C-k>`/`<C-l>` to window navigation.

An sf1 buffer currently falls into that `else` arm. Because sf1 drives a readline prompt (`input()` with `_readline_setup()`, `~/.sapience/sf1_history`), `<C-h>` is backspace there, so the default mapping steals a working editing key. The `is_aerc` arm is the precedent for the fix.

Also relevant: `<C-CR>` is mapped in terminal mode (`map("t", "<C-CR>", ...)` in the same file), so the tool picker remains reachable from inside an sf1 terminal. That is harmless and probably desirable; it is not a reason to change anything.

### 7. Live server capability surface (measured 2026-11-10)

Four read-only GETs with the account token from `~/.sapience/config.json`:

| Route | Status | Consequence |
|-------|--------|-------------|
| `GET /v1/sf1/handoff` | 200 | Works. Response keys: `ok`, `project`, `project_known`, `projects`, `state`, `last_session`, `subthreads`, `kos`, `text`, `line`, `made_at`. Returned 8 KOs and a 2131-character `text` body. |
| `GET /v1/work` | 200 | Answers, but `tree: []`, `open: 0`, `cap: 2`, `max_open: 12`. `/sub` therefore prints "No sub-threads yet." |
| `GET /v1/sf1/state` | 404 `{"error":"not found"}` | Piece B absent. `sf1.py`'s `cmd_state` treats 404/405 as a fallback signal and re-reads the handoff's derived state, so `/state` degrades rather than erroring. |
| `GET /v1/sf1/delegate` | 404 `{"error":"not found"}` | Piece A absent. `cmd_delegate` discovers by GET before POSTing and prints "Delegation is not on this server yet (SF-1 piece A). Nothing was run." |

Two further constraints read out of `cmd_delegate` and `_watch`: the client requires `caps.runner` to be a table with an `online` field and a `workers` list, and its offline message is "your Mac's runner is offline". Delegation is therefore gated on a Mac-side component regardless of whether the route lands. Any delegation UI in this plugin would be dead code twice over.

### 8. Project scoping behaves usefully even though no projects are registered

- The handoff response carries `projects: []` and `project_known: false`.
- Passing a name anyway (`GET /v1/sf1/handoff?project=nvim`) returned `project: "nvim"`, `project_known: false`, **and a different payload** — `state.goal` became `null` and `state.last_decision` was a different KO than the unscoped call returned.

So `--project` filters retrieval server-side even for an unregistered name. A cwd-derived project string is therefore functionally meaningful from the first run, not merely forward-looking. `sf1.py` persists the last project to `~/.sapience/sf1_state.json` (`remember_project` / `last_project`), so a bare `sf1` resumes it.

### 9. sf1 versus the MCP server — different engines

| Dimension | MCP `sapience_ask` | sf1 |
|-----------|--------------------|-----|
| Route | `/v1/ask` (`~/.sapience/mcp.py:1548`, with a 130s timeout chosen to exceed the server's 120s `ENGINE_ASK_TIMEOUT_S`) | `/v1/sapience-chats/ask?stream=1` (`sf1.py`, `Session.ask`) |
| Shape | One-shot, stateless | Multi-turn, carries a `chat` id, persisted under Chat in the hosted app |
| Opening state | None | Handoff package injected as a synthetic first exchange (`SEED_Q = 'sf1 session start: where did we leave off?'`) |
| Transport | Request/response | Server-sent events with `stage`, `sources`, `delta`, `revise`, `done` event types and line-granular markdown rendering |
| Writes | `sapience_remember` / `_wrapup` ingest KOs | None; only the chat is created |

The last row matters for safety review: sf1 never stages or ingests a knowledge object, so `~/.sapience/config.json`'s `auto_approve: false` and the `sapience review` gate are untouched by this plugin. No safety gating is required.

`mcp.py` additionally has no `--search` and no `--ask` CLI mode (its modes are `--briefing-text`, `--statusline`, `--stats`, `--status`, `--receipt`, `--effect-line`, `--adddoc`, `--adddir`, `--refresh-cache`), which is why `sf1` is the only shell-side path to vault question-answering.

### 10. The `<leader>a` namespace

Enumerated with two differently-shaped sweeps, both recorded verbatim:

- Pattern 1 (literal, quoted, two files): `grep -o '"<leader>a[a-zA-Z]*"' lua/neotex/plugins/editor/which-key.lua lua/neotex/config/keymaps.lua` — yielded `a b c d h i k l m p r s t y`.
- Pattern 2 (loose, unquoted, whole config excluding `deprecated/`): `grep -rn "leader>a" --include=*.lua lua/ after/ | grep -v "/deprecated/" | grep -oE "leader>a[a-zA-Z]+"` — yielded `a b c d h i k l m oo p r s t w W y`.

Pattern 2 is the superset and found three suffixes pattern 1 missed (`oo`, `w`, `W`), across 14 contributing files including `lua/neotex/plugins/text/lean.lua`, `lua/neotex/plugins/tools/worktree.lua`, and `lua/neotex/plugins/editor/telescope.lua`.

**Taken**: `a b c d h i k l m oo p r s t w W y`. Note `o` functions as a group prefix via `aoo`.

**Free single letters**: `e f g j n q u v x z`.

`<leader>as` is taken — `{ "<leader>as", "<cmd>DiscordSessions<CR>", desc = "discord sessions" }` at `which-key.lua:300`. Earlier conversation suggested `<leader>as` for this plugin; that suggestion was wrong and should not be carried into the plan.

## Decisions

These were settled during the conversation that created the task and are recorded here so research does not reopen them. Research may overturn any of them with evidence, but should state that it is doing so.

1. **Virtual-plugin shape, following `stt-plugin.lua`.** Not a plain module in `ai/`, and not a `tools/` placement. A lazy.nvim virtual spec plus a sibling implementation directory, because that is the convention already used twice and it makes later extraction a path change.
2. **Placement under `lua/neotex/plugins/ai/`, not `tools/`.** sf1 is an AI surface; a future reader looks for it beside `claude/` and `opencode/`. The required separation is a dependency rule (`sapience/` requires nothing from `ai/shared/`), not directory distance.
3. **Non-exclusive window, outside the `<C-CR>` picker.** Grounded in finding 5. A bottom split by default so sf1 and a 40%-width right-sidebar coding agent can be visible together.
4. **`position`/`size` as the core abstraction.** This is the feature worth building — it is the thing a standalone plugin would exist to provide, and the thing the user wants to evaluate empirically.
5. **No `/state` and no `/delegate` affordances.** Grounded in finding 7: both routes 404, and delegation needs a Mac runner.
6. **Dependency-free implementation files.** `sapience/init.lua` and `sapience/terminal.lua` require nothing from `neotex.*`, per the `stt`-versus-`himalaya` contrast in finding 3.
7. **No safety gating.** Grounded in finding 9: sf1 performs no vault writes.

## Recommendations

Ordered by what unblocks the plan fastest.

1. **Re-run the four capability probes before planning.** Four `curl -H "Authorization: Bearer $TOK"` GETs against `/v1/sf1/handoff`, `/v1/sf1/state`, `/v1/sf1/delegate`, `/v1/work`. Decisions 5 depends on them, and they describe a hosted service that can change under us. Do not inherit finding 7.
2. **Execute the `ai/init.lua` loader check rather than trusting finding 4.** The cheap form: add `"sapience-plugin"` to `ai_plugins`, create a stub spec file, and confirm the plugin appears in `:Lazy`. Finding 4 is a trace, and the task description already demands verification.
3. **Settle the keymap suffix from the free set in finding 10** (`e f g j n q u v x z`). `<leader>af` is the most mnemonic for "sf1" and is free under both sweeps; `<leader>aq` ("query") is the fallback. Confirm against a fresh sweep at authoring time, since the namespace is shared and the measurement above is a point-in-time one.
4. **Resolve the four `position` values against `snacks.terminal`'s actual option surface.** This seed confirms `position = "right"` with `width` works (opencode uses exactly that) and that `position` and `height`/`width` are the right keys, but it did not verify that `"bottom"`, `"left"`, and `"float"` are all accepted spellings, nor whether `"float"` ignores `size` or takes different keys. This is the single largest open question for the plan, because it determines whether `terminal.lua` needs a per-position option mapping or a uniform one. [CORPUS-UNVERIFIED: snacks.terminal / whether all four position values and their size keys are accepted as specified]
5. **Decide the `project = "git"` strategy's implementation.** The task lists `"cwd"|"git"|false|function` but only the `cwd` strategy has a stated derivation (`vim.fn.fnamemodify(vim.fn.getcwd(), ":t")`). A `git` strategy needs a repo-root discovery method that stays dependency-free per decision 6 — plain `vim.fs.root` or a `git rev-parse` job, not a `neotex.*` helper.
6. **Keep the `is_sf1` keymap branch minimal and name it in `file_scope`.** It is the only shared-territory edit. Declaring `file_scope` on the task would mechanically prevent an implementing agent from straying into `shared/picker/`, which decision 3 forbids and which no other mechanism currently guards.
7. **Do not add tests beyond a load check unless the plan finds a reason.** The repository's quality standard asks for coverage on new Lua modules, but `stt` ships none and the module is a thin wrapper over a terminal command whose behavior is almost entirely window placement. A headless `require` plus manual position verification is proportionate; note the deviation explicitly rather than silently skipping.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `snacks.terminal` rejects one of the four `position` values, forcing a per-position mapping late in implementation | Recommendation 4 resolves it before the plan commits to a uniform mapping |
| A later vendor payload changes sf1's CLI surface (it is version 0.1.0 and undocumented publicly) | Depend only on `sf1 --project <name>` and bare `sf1`, both of which `parse_args` handles; avoid parsing sf1's stdout |
| `snacks.nvim` becoming unavailable breaks the plugin outright | Confine all window calls to `terminal.lua` behind `open`/`close`/`find` so a `termopen` fallback is one file, and `pcall` the snacks require |
| The implementing agent edits `ai-tool-picker.lua` because it looks like the natural integration point | Declare `file_scope` (recommendation 6); the prohibition is already in the task description |
| Drift between the plugin's default project string and the GNOME launcher's unscoped retrieval, producing two different answer sets for the same question | Document the difference in the module README; it is expected behavior, not a bug |

## Context Extension Recommendations

- **Topic**: sf1's actual interface and the SF-1 server capability split
- **Gap**: `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md` line 35 describes sf1 as a "one-shot CLI". It is primarily an interactive REPL with slash commands (`/delegate`, `/state`, `/sub`, `/project`, `/new`, `/chat`, `/help`, `/quit`); the one-shot form is one of its modes. No context file records that pieces A and B are unavailable while piece C is live, nor that sf1 and `sapience_ask` reach different engines.
- **Recommendation**: correct the line-35 characterization and add the piece A/B/C availability split to `vault-model.md`. This is outside this task's file scope (it is extension source, not Neovim config) and should be a separate task rather than scope creep here.

- **Topic**: `neovim` task-type detectability
- **Gap**: `detect_task_type` cannot resolve `neovim`. The nvim extension's `manifest.json` declares `task_type: "neovim"` but no `keyword_overrides`, and `neovim` is absent from the core weak-signal table, so a Neovim task resolves to `general` — or, when it cites `himalaya-plugin.lua` as a precedent, to `email`, because `himalaya` is an email-extension keyword. This task's type was set by hand.
- **Recommendation**: add a `keyword_overrides` block to `.claude/extensions/nvim/manifest.json`. Separate task.

## Appendix

### Reproducing the capability probe

```bash
TOK=$(python3 -c "import json;print(json.load(open('$HOME/.sapience/config.json')).get('token',''))")
for p in /v1/sf1/handoff /v1/sf1/state /v1/sf1/delegate /v1/work; do
  curl -sS -o /dev/null -w "$p HTTP %{http_code}\n" \
    -H "Authorization: Bearer $TOK" -H "User-Agent: sf1/0.1.0" "https://app.spnc.ai$p"
done
```

The token is the entire credential for the account and should not be echoed.

### sf1 slash-command surface, for reference

Read out of `sf1.py`'s `Session.handle` and `HELP`: `/delegate claude|codex <task>`, `/state`, `/sub` (aliases `/subs`), `/project <name>`, `/new`, `/chat`, `/help` (`/h`, `/?`), `/quit` (`/exit`, `/q`). Ctrl-C interrupts a streaming answer; Ctrl-D exits. Environment overrides the client honors: `SAPIENCE_HOST`, `SAPIENCE_TOKEN`, `SAPIENCE_CONFIG`, `SF1_HISTORY`, `SF1_STATE`, `SF1_TIMEOUT` (default 300), `SF1_COLOR`, `SF1_NO_COLOR`, `NO_COLOR`.

### References

- `~/.dotfiles/docs/sapience.md` — machine configuration, first-time setup, the three GNOME launchers, and the "there is no native desktop application" note
- `lua/neotex/plugins/tools/stt-plugin.lua` and `lua/neotex/plugins/tools/stt/init.lua` — the model to follow
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md` — the existing decision that Sapience retrieval is an explicitly invoked escape hatch rather than an injected per-dispatch mechanism, which this plugin is consistent with
