# sf1 Sapience Chat

In-config integration for sf1, the Sapience terminal chat client, as a lazy.nvim virtual
plugin. sf1 is a read-only chat surface over the user's Sapience vault: it creates a
server-side chat and writes no knowledge objects, and is meant to coexist alongside a coding
agent (Claude Code, OpenCode) rather than replace one.

## Modules

### init.lua
The public API and configuration surface: the opts schema with `vim.validate`-backed
validation, project-string resolution, sf1 command-string construction, and the lifecycle
functions `setup`, `open`, `close`, `toggle`, and `set_position`. Every window operation is
delegated to `terminal.lua`.

### terminal.lua
The window backend: `open`, `close`, `find`, and `reposition`, mapping `position`/`size` onto
`snacks.terminal`. All `snacks` access is wrapped in `pcall`, so a missing `snacks.nvim`
degrades to a single warning rather than an error.

## Configuration

```lua
require("neotex.plugins.ai.sapience.init").setup({
  cmd = "sf1",        -- executable name
  position = "bottom", -- "bottom" | "right" | "left" | "float"
  size = 0.35,          -- fraction in (0, 1]; see Behavior Notes below
  project = "cwd",      -- "cwd" | "git" | false | function
})
```

| Option     | Type                              | Default    | Meaning |
|------------|------------------------------------|------------|---------|
| `cmd`      | `string`                           | `"sf1"`    | Executable launched in the terminal |
| `position` | `"bottom"\|"right"\|"left"\|"float"` | `"bottom"` | Window placement |
| `size`     | `number` in `(0, 1]`                | `0.35`     | Split height/width fraction; ignored for `float` |
| `project`  | `"cwd"\|"git"\|false\|function`      | `"cwd"`    | `--project` scoping strategy |

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
<leader>af                                                      " same, via which-key
```

```lua
require("neotex.plugins.ai.sapience.init").set_position("right")
```

`set_position` re-places an already-open sf1 window immediately, without restarting its REPL,
and also updates the position used by the next `:Sf1` if no window is currently open.

## Behavior Notes

- **`size` only applies to split positions.** For `"bottom"`, `"left"`, and `"right"`, `size`
  sets both the window's height and width (a split's own layout only consumes the one
  dimension its orientation needs, so this is harmless). For `"float"`, `size` is ignored
  entirely and the snacks `"float"` style's own defaults apply — mapping a single fraction
  onto both dimensions of a float would produce an unintentionally square window.
- **Project scoping changes sf1's answers.** The default `project = "cwd"` strategy means
  this integration's sf1 session is scoped to the current Neovim working directory, which
  will answer differently than an unscoped `sf1` launched from a GNOME launcher or a bare
  shell. This is expected, not a defect — set `project = false` to get the same unscoped
  behavior.

## Dependencies

- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) — provides the terminal window
  backend (`snacks.terminal`).
- The `sf1` binary on `$PATH`.

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
