# Research Report: Task #608

**Task**: 608 - Improve chat pane styling for `<leader>as` to match Claude Code's appearance, with blank lines or divider lines between message parts so they don't run together
**Started**: 2026-11-12T00:44:46Z
**Completed**: 2026-11-12T00:49:14Z
**Effort**: ~1 hour
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/config/keymaps.lua`, `lua/neotex/plugins/ai/sapience-plugin.lua`, `lua/neotex/plugins/ai/sapience/init.lua`, `lua/neotex/plugins/ai/sapience/terminal.lua`
- Prior task artifact: `specs/archive/578_sf1_neovim_virtual_plugin_with_split_position/reports/01_sf1-nvim-plugin-seed.md`
- Vendor payload (outside this repo): `~/.sapience/sf1.py` (read in full), `~/.sapience/update.log`, `~/.sapience/.auto_update.json`
- Packaging repo (outside this repo): `~/.dotfiles/packages/sapience-flake/flake.nix`, `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix`
- `specs/state.json` (task 608 record), `specs/TODO.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `<leader>as` is bound to `:Sf1<CR>`, which toggles a `snacks.terminal` window running the external `sf1` binary (`lua/neotex/plugins/ai/sapience-plugin.lua` -> `sapience/init.lua` -> `sapience/terminal.lua`). This Neovim-side code controls only the window's position, size, and visibility — it never touches the bytes the terminal displays.
- `sf1` is `~/.sapience/sf1.py`, a 653-line, stdlib-only Python REPL that is **vendor payload**, not source code tracked in any git repository on this machine. It is fetched by plain `curl` from `https://app.spnc.ai` and is **re-fetched and silently overwritten by a daily auto-update** (`~/.sapience/update.log` shows `auto-update: updated`/`current` entries once per day, with timestamped backups for whichever files actually changed). All message-part rendering — the "picked up:" handoff banner, the streamed markdown answer, the "sources:" line, the next `sf1/project >` prompt — is printed by this file, append-only, one line at a time, with **no blank line ever inserted between parts**. That absence is exactly the "run together" complaint.
- Editing `~/.sapience/sf1.py` directly would work today but is not durable: it is not git-tracked, is not built by the `sapience-flake` Nix packaging (`flake.nix` states explicitly that the payload is "deliberately NEVER packaged as a Nix derivation" because it self-updates), and a future daily auto-update cycle can silently discard the edit with no mechanism in this repo (or any repo) to reapply it.
- **This task's literal request cannot be satisfied durably by editing anything inside `/home/benjamin/.config/nvim`.** Nothing in this repository ever sees sf1's output bytes; the repo's three sf1-related files are 100% window-placement code. Equally, "Claude Code's appearance" (the `claude` CLI's own turn-by-turn spacing) is produced by that CLI binary, not by any Lua code in this config — the same architectural gap applies to the comparison target.
- This is flagged below as a scope/judgment question for the user (`user_decision`), not resolved unilaterally, because research cannot determine which of three legitimate-but-different-cost paths the user wants: (a) a one-off, fragile hand-edit to the vendor file accepted as disposable; (b) a PTY-proxying wrapper built and owned inside this repo that rewrites sf1's output stream at display time; or (c) a separate task filed in `~/.dotfiles` (the repo that actually owns `sf1`'s packaging) to reapply spacing at each `sapience update`.

## Context & Scope

In scope: locating the exact code path `<leader>as` invokes; determining whether this repository's own Lua code can affect the chat pane's text styling; determining where the content actually comes from and how durable an edit there would be; comparing against how the "Claude Code" terminal integration in this same repo works (to check whether the comparison target is itself Neovim-governed).

Out of scope, deliberately: writing an actual patch to `~/.sapience/sf1.py` (vendor file, outside this repo, and this is a research dispatch); modifying the `sapience-flake` Nix packaging in `~/.dotfiles` (a different repository this task was not sited in); redesigning the two-stage AI tool picker (`ai-tool-picker.lua`), which sf1 deliberately stays outside of per the prior task's finding 5.

## Findings

### 1. The exact `<leader>as` code path

- `lua/neotex/plugins/editor/which-key.lua:301`: `{ "<leader>as", "<cmd>Sf1<CR>", desc = "sf1 sapience chat", icon = "󰭻" }`.
- `:Sf1` is defined in `lua/neotex/plugins/ai/sapience-plugin.lua:96-98`, calling `sapience.toggle()`.
- `sapience/init.lua` (`M.toggle`) delegates every window operation to `sapience/terminal.lua`, which wraps `snacks.terminal.toggle`/`.get`/`:show()`/`:hide()`. These functions set `win.position`, `win.height`/`width`, and `enter = true` — nothing else. There is no text-processing, highlight-group, or buffer-content code anywhere in this three-file chain.
- The doc-comment line `lua/neotex/config/keymaps.lua:25` ("`<leader>as` | AI tool session picker") is stale — the live binding is the sf1 toggle above, confirmed against the un-commented which-key entry and against the commented-out `<leader>as` AI-tool-picker block at `which-key.lua:259-267` (replaced by the unified `<leader>al` picker per its own comment).

### 2. `sf1` is vendor payload, not source in any repo on this machine

- `which sf1` resolves to `/home/benjamin/.nix-profile/bin/sf1`, which `readlink -f`s to a Nix store wrapper (`/nix/store/.../sf1/bin/sf1`) built by `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix:259-269` (`sf1Cli`). That wrapper's entire body is a presence check followed by `exec python3 "${stateDir}/sf1.py" "$@"` — it does no post-processing of sf1's output.
- `${stateDir}/sf1.py` resolves to `~/.sapience/sf1.py`. `git -C ~/.sapience status` reports "not a git repository" — this directory is not under version control at all.
- `~/.dotfiles/packages/sapience-flake/flake.nix` documents the policy explicitly in its header comment: "The vendor payload (`~/.sapience/*.py`) is deliberately NEVER packaged as a Nix derivation — upstream ships no releases, tags or content hashes and self-updates in the background, so a pinned `fetchurl` would break on the vendor's next edit and fight the client's own updater."
- `~/.sapience/update.log` confirms the self-update is live and running on this machine: entries for 2026-11-04 through 2026-11-07 show specific files (`sapience_upkeep.py`, `mcp.py`, `upload.py`, `sapience_capture.py`) being backed up and overwritten, followed by `auto-update: updated`; 2026-11-08 through 2026-11-10 show `auto-update: current` (checked, nothing changed that day). `sf1.py`'s own mtime (Nov 3) predates this log window, i.e. it has not changed recently, but the mechanism that would silently overwrite it is active and runs roughly daily.
- Conclusion: a hand-edit to `~/.sapience/sf1.py` is not analogous to editing a deploy artifact that simply needs redeploying from a known source (the `.claude/**` case `source-store-deploy-boundary.md` describes) — there is no local source to redeploy from. It is a edit to someone else's shipped binary that can vanish on the next silent vendor sync, with no diff, no backup restoration path for *local* changes, and no repo anywhere on this machine that could "own" reapplying it automatically.

### 3. How sf1 currently renders a turn (why parts run together)

Read in full (`~/.sapience/sf1.py`, 653 lines). The relevant control flow:

- `Markdown.feed()`/`._line()` (lines ~85-131) stream the answer **one completed line at a time**, each written with `self.out.write(... + '\n')` followed by an immediate `.flush()`. There is no cursor repositioning (`\r`/ANSI cursor codes) anywhere in this path — the one place `\r\033[2K` appears is the transient status indicator on `stderr` (lines 269-272), which is explicitly cleared (`clear()`) before any stdout write. This matters for feasibility: the output is a strictly append-only line stream, so inserting extra blank lines into it is not fighting an in-place redraw.
- The actual turn boundaries, as currently printed, with **zero blank-line separation** at every one of them:
  - `Session.start()` (lines ~218-233) prints the green "picked up: ..." handoff line, then nothing before the REPL's first prompt.
  - `main()`'s REPL loop (lines ~641-653) calls `input(_prompt(style, ses.project))` immediately after `ses.handle(line)` returns — no blank line between the end of one answer (or a slash-command's output) and the next `sf1/project >` prompt.
  - `Session.ask()` (lines ~254-313) streams the answer directly after the user's question (echoed by the terminal's own line-editing, not by this script) with nothing in between, and appends the `sources: ...` line directly after the last answer line with nothing in between.
- There is no existing config surface for this: `parse_args()` (lines 603-620) only recognizes `-p/--project`, `-h/--help`, `-V/--version`, `--no-color`, `--`; the only environment variables honored anywhere in the file are `SAPIENCE_CONFIG`, `SF1_HISTORY`, `SF1_STATE`, `SF1_TIMEOUT`, `SAPIENCE_HOST`, `SAPIENCE_TOKEN`, `NO_COLOR`/`SF1_NO_COLOR`/`SF1_COLOR`. None of these affect spacing.

### 4. "Claude Code's appearance" is produced the same way — by a terminal-embedded external binary

- The repository's Claude Code integration (`claude-code.nvim`, referenced from the prior task's finding 5 as `lua/neotex/plugins/ai/claudecode.lua:10-11`, `split_ratio = 0.40`, `position = "vertical"`) is architecturally identical to sf1's own integration: a `snacks`/terminal-style window running the external `claude` CLI binary. The turn-by-turn blank lines and divider boxes the user wants to match are drawn by the `claude` binary's own TUI code, not by any Lua in this config. Neither integration this repo owns can post-process the other's byte stream today.
- Consequence: the comparison target itself confirms the architectural gap in Finding 1 rather than offering a Neovim-side styling mechanism to copy. There is no `claude-code.nvim`-side highlight/format function that could be reused for sf1.

### 5. What would actually be required to add dividers, and where each option is sited

Three technically coherent paths were identified; none is a change inside this repo alone that is also durable:

| Option | Where it lives | Mechanism | Durability | Risk |
|---|---|---|---|---|
| (a) Hand-edit `~/.sapience/sf1.py` | Vendor payload, no repo | Add `self.err.write('\n')`/`self.out.write('\n')` at the three boundaries in Finding 3 (after `start()`'s handoff line, after `handle()` returns in the REPL loop before the next `input()`, before the answer begins streaming in `ask()`) | Low — not git-tracked; silently overwritten by the next daily auto-update that happens to touch `sf1.py` (Finding 2) | Lowest implementation risk, highest loss-of-work risk |
| (b) PTY-proxying wrapper owned by this repo | `lua/neotex/plugins/ai/sapience/` (new file), invoked by changing `config.cmd` away from the bare `"sf1"` string | A small script spawns `sf1` under its own pseudo-terminal (so `sys.stdout.isatty()` and `readline` keep working for color and line-editing) and rewrites the byte stream, inserting a blank line when it recognizes the colored "picked up:" banner, the plain-text `sources:` line, or the `sf1%s > ` prompt | High — lives in and is versioned by this repo | Medium-high — it is pattern-matching on printed text (prompt string, line prefixes) rather than a semantic hook, and breaks silently if the vendor changes those literal strings or color codes; a naive shell pipe (`sf1 \| filter`) would NOT work because it turns `stdout` into a non-tty, disabling color and risking readline's interactive editing |
| (c) Reapply-at-activation patch | `~/.dotfiles/packages/sapience-flake/` (a different repository, per `no-record-versioning`/task-siting conventions this is where a task targeting that `source_dir` belongs) | Extend the `sf1Cli` wrapper or a home-manager activation step to apply the same three-line insertion to `~/.sapience/sf1.py` idempotently every time the payload changes | Medium — survives auto-update cycles as long as the three anchor points' surrounding code doesn't move; breaks if upstream restructures those functions | Needs a task created in `~/.dotfiles`, not here (task-siting rule) |

No path lets this task be closed by `general-implementation-agent` editing only files under `/home/benjamin/.config/nvim` and have the result be both correct and durable. (b) is the only option fully sited in this repo, and it is also the most fragile of the three along a different axis (text-pattern matching on another program's literal output, including its ANSI color sequences).

## Decisions

1. **Confirmed `<leader>as` resolves to the sf1 terminal integration, not any other chat surface.** The stale `AI tool session picker` doc comment in `keymaps.lua` is noted but not corrected here (out of scope for a research report; cosmetic doc-comment drift unrelated to this task's goal).
2. **Ruled out any fix inside `ai-tool-picker.lua` or the two-stage picker.** sf1 is deliberately kept outside that picker (prior task's finding 5, re-confirmed by reading the live `sapience-plugin.lua`/`init.lua`/`terminal.lua`), and this task's request does not touch tool selection, only rendering.
3. **Determined that no change confined to this repository can durably satisfy the request.** This is stated as a finding, not assumed; it follows from Findings 1-3 (this repo never sees sf1's output bytes) combined with Finding 2 (the one file that does produce those bytes is vendor-owned, untracked, and auto-overwritten).

## Recommendations

1. **Set `user_decision` and let the user pick one of the three paths in Finding 5's table before any plan is written.** This is not a routine field: which path is correct depends on how much the user values durability versus staying inside this repo versus accepting the edit may vanish — a genuine preference call research cannot infer. Phrase the choice exactly as the three rows of that table.
2. **If the user picks (b) (stay inside this repo):** the plan should scope the new file to `lua/neotex/plugins/ai/sapience/` only (consistent with the existing dependency-free convention noted in the prior task's Decision 6), build the PTY proxy as a small Python script (the repo's Nix/Python toolchain already provides `python3`; no new dependency), and explicitly document in the module's own comments which three literal markers it keys on (`picked up:` prefix color code, the `sources:` line prefix, the `_prompt()` format string `'sf1%s > '`) so a future reader can tell at a glance what breaks if the vendor changes its output text.
3. **If the user picks (a) or (c):** this task (608) should be re-sited or closed as `[BLOCKED]`/redirected rather than implemented here, per the task-siting convention in `.claude/rules/source-store-deploy-boundary.md` (a task whose edit target is a different repository's `source_dir` is created in that repository, not this one). (a) additionally has no repository to create a task in at all — it is a disposable, unversioned local edit the user would make by hand, not an agent-orchestrated task.
4. **Whichever path is chosen, re-verify Finding 3's three anchor points against a freshly-read `~/.sapience/sf1.py` at implementation time**, not against this report's line numbers — the file is explicitly self-updating and this report's line citations are a 2026-11-12 snapshot.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| An implementing agent, given only this task's description, edits `~/.sapience/sf1.py` directly without realizing it is untracked vendor payload outside the task-management system's reach | This report's Finding 2 and Decision 3 are written specifically to prevent that; the `user_decision` recommendation (Recommendation 1) is the gate that should stop an autonomous `/orchestrate --implement` from proceeding on an unexamined assumption |
| A PTY-proxy wrapper (option b) silently stops inserting dividers after a vendor update changes the literal prompt string or banner color code | Recommendation 2's documentation requirement; no automated test can catch this without a live `sf1` session, so the module's own comments are the primary defense |
| The daily auto-update overwrites a hand-edit (option a) between task creation and verification, making the "fix" appear to work in one session and silently vanish in the next | Not mitigable from this repo; this is exactly why option (a) is flagged as low-durability in Finding 5 rather than recommended |

## Context Extension Recommendations

- **Topic**: sf1's output-stream stability contract for any future Neovim-side wrapper
- **Gap**: no context file in this repository documents that `~/.sapience/sf1.py` is untracked, auto-updating vendor payload, or that its rendering is strictly append-only (no cursor tricks) — both facts this report had to re-derive from scratch by reading the file and `update.log` directly, exactly as the prior task's own Context Extension Recommendations predicted would need re-deriving for `vault-model.md`'s sf1 characterization.
- **Recommendation**: if option (b) from Finding 5 is ever implemented, record the append-only-stream fact and the literal markers it depends on in a short note under `agent-system/extensions/sapience/context/project/sapience/domain/` (that domain already exists per the task's own memory-context hit) so a future sf1-adjacent task does not re-read all 653 lines to rediscover it. Out of this task's own file scope; a separate task.

## Appendix

### Search/read commands used

- `grep -rn "leader>as" --include="*.lua" .` and `grep -rln "Sf1\|sapience" --include="*.lua" .`
- Full reads: `sapience-plugin.lua`, `sapience/init.lua`, `sapience/terminal.lua`, `~/.sapience/sf1.py` (all 653 lines, in four passes), the prior task's seed report in full.
- `which sf1` / `readlink -f` chase from `~/.nix-profile/bin/sf1` to the Nix store wrapper to `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix`.
- `git -C ~/.sapience status` (confirmed: not a git repository).
- `cat ~/.sapience/.auto_update.json`, `tail -30 ~/.sapience/update.log` (confirmed daily auto-update cadence and specific overwritten files).
- `jq` queries against `specs/state.json` for task 608's record (status `researching`, no plan or prior artifacts yet).

### References

- `specs/archive/578_sf1_neovim_virtual_plugin_with_split_position/reports/01_sf1-nvim-plugin-seed.md` — the task that built the three live sf1 integration files; still the authoritative account of why sf1 is excluded from the `<C-CR>` picker and why its implementation files are dependency-free.
- `~/.dotfiles/packages/sapience-flake/flake.nix` header comment — the vendor-payload-is-deliberately-unpackaged policy statement, verbatim source for Finding 2.
- `~/.sapience/update.log` — live evidence of the auto-update cadence.
