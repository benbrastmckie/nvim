# sf1 Sapience Chat

In-config integration for sf1, the Sapience terminal chat client, as a lazy.nvim virtual
plugin. sf1 is a read-only chat surface over the user's Sapience vault: it creates a
server-side chat and writes no knowledge objects. Opening it hides whichever coding agent
(Claude Code, OpenCode) is currently visible, so the three AI surfaces share one screen region
instead of competing for it; each agent is hidden by its own toggle, keeping its buffer and
running session intact for an unchanged re-show.

## Modules

### init.lua
The public API and configuration surface: the opts schema with `vim.validate`-backed
validation, project-string resolution, sf1 command-string construction, and the lifecycle
functions `setup`, `open`, `close`, `toggle`, `set_position`, and `is_visible`. Every window
operation is delegated to `terminal.lua`.

### terminal.lua
The window backend: `open`, `show`, `close`, `find`, `visible`, and `reposition`, mapping
`position`/`size` onto
`snacks.terminal`. All `snacks` access is wrapped in `pcall`, so a missing `snacks.nvim`
degrades to a single warning rather than an error.

### sf1_proxy.py
A pty-proxying wrapper, invoked in place of the bare `sf1` command whenever `styling.enabled`
is true: it launches sf1 under its own pseudo-terminal and rewrites the merged output byte
stream to insert a separator (a blank line by default, or a dim horizontal rule) between
message parts, so the pane reads like Claude Code's turn-separated output instead of one
unbroken block of text. It is deliberately a pty, not a pipe — a plain shell pipe would turn
sf1's stdout into a non-tty, disabling both its color output and GNU readline's line editing.
The filter is pattern-matching, never patch-applying: it keys on a small set of sf1's own
literal output strings (documented in full in the module's own docblock), and degrades to
pass-through — "no dividers", never a crash or a corrupted pane — the moment any of that text
no longer matches. Its own `sf1_proxy_test.py` suite (stdlib `unittest`, no network, no vendor
dependency) covers the filter logic as a pure byte-chunk function and the pty harness itself
against a scripted stub child.

## Configuration

```lua
require("neotex.plugins.ai.sapience.init").setup({
  cmd = "sf1",        -- executable name
  position = "right", -- "bottom" | "right" | "left" | "float"
  size = 0.40,        -- fraction in (0, 1]; see Behavior Notes below
  project = "cwd",    -- "cwd" | "git" | false | function
  on_open = nil,      -- optional function, called just before a hidden window is shown
  on_close = nil,     -- optional function, called just after a visible window is hidden
  styling = {         -- see Modules > sf1_proxy.py above
    enabled = true,       -- proxy sf1 through sf1_proxy.py to insert turn separators
    separator = "blank",  -- "blank" | "rule" | "none"
  },
})
```

| Option     | Type                              | Default    | Meaning |
|------------|------------------------------------|------------|---------|
| `cmd`      | `string`                           | `"sf1"`    | Executable launched in the terminal |
| `position` | `"bottom"\|"right"\|"left"\|"float"` | `"right"`  | Window placement |
| `size`     | `number` in `(0, 1]`                | `0.40`     | Split height/width fraction; ignored for `float` |
| `project`  | `"cwd"\|"git"\|false\|function`      | `"cwd"`    | `--project` scoping strategy |
| `on_open`  | `function\|nil`                     | `nil`      | Called before a hidden window is shown |
| `on_close` | `function\|nil`                     | `nil`      | Called after a visible window is hidden |
| `styling.enabled`   | `boolean`                 | `true`     | Proxy sf1 through `sf1_proxy.py` for turn separation |
| `styling.separator` | `"blank"\|"rule"\|"none"` | `"blank"`  | `"blank"`: one blank line; `"rule"`: a dim horizontal rule; `"none"`: identity pass-through (proxied, but unstyled) |

The `project` strategies:
- `"cwd"` — the current working directory's basename.
- `"git"` — the git repository root's basename, falling back to the `"cwd"` derivation
  outside a repository.
- `false` — no `--project` flag; sf1 resumes the last project from its own state file.
- a function — called with no arguments; its string return value is used, and anything else
  (including an empty string) falls back to no `--project` flag.

## Usage

```vim
:Sf1                                                            " toggle the sf1 window
<leader>as                                                      " same, via which-key
```

```lua
require("neotex.plugins.ai.sapience.init").set_position("right")
```

`set_position` re-places an already-open sf1 window immediately, without restarting its REPL,
and also updates the position used by the next `:Sf1` if no window is currently open.

The two hooks are the module's only extension point for host-side coordination, and are what
keep this directory free of any host dependency: the hook body lives with the host (for this
config, in `../sapience-plugin.lua`, where `on_open` hides a visible coding agent), never
here. A hook that raises is reported as a warning and never prevents the window from opening
or closing.

## Behavior Notes

- **`size` only applies to split positions.** For `"bottom"`, `"left"`, and `"right"`, `size`
  sets both the window's height and width (a split's own layout only consumes the one
  dimension its orientation needs, so this is harmless). For `"float"`, `size` is ignored
  entirely and the snacks `"float"` style's own defaults apply — mapping a single fraction
  onto both dimensions of a float would produce an unintentionally square window.
- **The defaults match the Claude Code sidebar.** `position = "right"` with `size = 0.40`
  places sf1 in the same screen region, at the same width, as Claude Code's own
  `split_ratio = 0.40` vertical split. Since opening sf1 hides a visible coding agent, the two
  trade places in one sidebar rather than splitting the screen three ways.
- **Only `<C-h>` is taken from the REPL.** sf1 runs on GNU readline's default emacs
  keymap, where `<C-j>` is `accept-line` (it submits the line), `<C-k>` is `kill-line`, and
  `<C-l>` is `clear-screen` — the only screen clear sf1 has, since it ships no `/clear`
  command. All three are therefore left unmapped in terminal mode. `<C-h>` is mapped to
  `wincmd h` instead: it is readline's `backward-delete-char`, but the Backspace key sends
  `0x7f`, which readline binds separately, so backspace is unaffected — and since sf1 sits in
  the right sidebar, leftward is the only direction needed to leave it. Each unmapped key stays
  reachable as `<C-\><key>` (`:help terminal-input`). The branch lives in
  `../../../config/keymaps.lua`, keyed on the snacks terminal `cmd` anchored at `^sf1`.
- **Project scoping changes sf1's answers.** The default `project = "cwd"` strategy means
  this integration's sf1 session is scoped to the current Neovim working directory, which
  will answer differently than an unscoped `sf1` launched from a GNOME launcher or a bare
  shell. This is expected, not a defect — set `project = false` to get the same unscoped
  behavior.
- **The separator styling is a dependency on sf1's own literal output text.** `sf1_proxy.py`
  keys on a handful of exact strings sf1 writes (the `picked up:` handoff line, the turn
  prompt, the transient status indicator) — see that file's own module docblock for the full
  marker contract and what happens to each boundary if the vendor changes its text. The vendor
  payload (`~/.sapience/sf1.py`) is untracked and can auto-update at any time; the failure mode
  for a text change is always "no dividers appear", never a crash or a corrupted pane.
- **A runtime `styling` change takes effect only for terminals opened after it.**
  `snacks.terminal`'s identity key is derived from the full command string passed to it, which
  now includes the proxy invocation when styling is enabled. Calling `setup()` again with a
  different `styling` value mid-session therefore does not retroactively restyle an
  already-open sf1 terminal — exactly the same "take effect for terminals opened after it"
  property `position`/`size` already have, documented above. The previously-open terminal
  remains fully usable and closable; nothing is broken by the change, it simply keyed a
  different underlying terminal object.

## Dependencies

- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) — provides the terminal window
  backend (`snacks.terminal`).
- The `sf1` binary on `$PATH`.
- `python3` on `$PATH`, for `sf1_proxy.py` (stdlib only, no pip dependency). Entirely optional:
  when `python3` is missing, `styling.enabled = true` degrades to the bare `sf1` command with a
  single WARN notification rather than failing to open.

## Extraction Constraint

`init.lua` and `terminal.lua` are dependency-free apart from a single require of
`neotex.plugins.ai.sapience.terminal` from `init.lua`. That is a deliberate design constraint,
not an oversight: it keeps this directory liftable into a standalone repository by editing
only that one require line, should the integration ever need to live outside this
configuration.

## Non-Goals

- No entry in the `<C-CR>` two-stage AI tool picker (`shared/picker/`). That picker enforces
  mutual exclusion between Claude Code and OpenCode over a shared screen region; sf1 is
  read-only and meant to be visible alongside either of them, not through the same picker.
- No `/state` or `/delegate` affordance. Both routes are unavailable for a typical Sapience
  account, and `/delegate` additionally requires a separate runner process.

## Navigation
- [← Parent Directory](../README.md)
