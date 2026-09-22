# Typst Integration

This document describes the complete Typst setup including LSP, preview, keybindings, and browser styling configuration.

## Overview

Typst is a modern typesetting system with first-class Neovim support via tinymist LSP and typst-preview.nvim. This configuration provides a LaTeX-like workflow with the same `<leader>l` prefix, filetype-isolated to prevent conflicts.

**Key Features**:
- **Tinymist LSP** - Completions, diagnostics, formatting, hover info
- **Treesitter** - Syntax highlighting and code folding
- **typst-preview.nvim** - Live browser preview with bidirectional sync
- **Multi-file projects** - Automatic main file detection for chapters/sections
- **SnipMate snippets** - ~60 comprehensive snippets for common patterns
- **nvim-surround** - Typst-specific delimiter pairs (bold, italic, math, code)
- **Custom styling** - Sioyek-style soft background via browser extension

## Table of Contents

1. [Keybindings](#keybindings)
2. [Multi-File Projects](#multi-file-projects)
3. [Preview and Sync](#preview-and-sync)
4. [Browser Styling Setup](#browser-styling-setup)
5. [Snippets](#snippets)
6. [Surround Operators](#surround-operators)
7. [LSP Features](#lsp-features)
8. [Troubleshooting](#troubleshooting)

---

## Keybindings

**Availability**: Only available in `.typ` files.

All Typst keybindings use the `<leader>l` prefix (same as LaTeX). Filetype isolation ensures no conflicts - `<leader>l` shows "LaTeX" in `.tex` files and "Typst" in `.typ` files.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ll` | Live preview (web) | Toggle browser preview with sync |
| `<leader>lb` | Build once | Single compilation run |
| `<leader>lv` | View PDF (Sioyek) | Open compiled PDF in external viewer |
| `<leader>le` | Errors | Show diagnostics for current line |
| `<leader>lf` | Format | Format via tinymist LSP (using typstyle) |
| `<leader>lk` | Clean artifacts | Delete compiled svg/pdf and restart tinymist |
| `<leader>lx` | Stop preview | Stop the live preview if one is running |
| `<leader>lq` | Quickfix (compile) | Open the compile-error quickfix list |
| `<leader>ls` | Sync cursor (web) | Manually sync preview to cursor position |
| `<leader>lp` | Pin main file | Pin current file as main (multi-file projects) |
| `<leader>lu` | Unpin main file | Return to automatic main file detection |

`ll`, `lb`, `lv`, `le`, `lf`, `lk` and `lx` are the shared core verbs and mean the same thing in
the LaTeX and Slidev groups -- see [MAPPINGS.md](MAPPINGS.md#document-leaderl).

**Note**: Sync features (forward/backward) only work with the web preview (`<leader>ll`), not with external PDF viewers.

**No separate watch command**: tinymist's LSP config sets `exportPdf = "onSave"`, so every
save of any file in a pinned/detected project already exports the main document's PDF. `<leader>lb`
covers an on-demand rebuild (e.g. after a file changes on disk outside Neovim); there is no
`<leader>lw`.

---

## Multi-File Projects

All main-file and project-root logic lives in one shared module,
`lua/neotex/util/typst.lua`, used by the `<leader>l` commands, the web preview
(`typst-preview.nvim`), and the tinymist pin sync. Inspect it directly:

```vim
:lua print(require'neotex.util.typst'.main_file(vim.api.nvim_buf_get_name(0)))
:lua print(require'neotex.util.typst'.project_root(vim.api.nvim_buf_get_name(0)))
```

### Automatic Main File Detection

When editing files in subdirectories (`chapters/`, `sections/`, `parts/`, `includes/`,
`content/`), the configuration detects the main file in the parent directory. Detection is
**content-aware**: it prefers whichever root-level file actually `#include`s or `#import`s the
current chapter, rather than relying on file naming or alphabetical order.

**Detection order** (`neotex.util.typst.main_file`):
1. **Project pin**, if one is set (`<leader>lp` below) -- always wins.
2. If the current file is not inside a recognized subdirectory, the current file itself.
3. **Content-aware scan**: among the `.typ` files one level up, the first (sorted) one whose
   text contains `#include "<path-to-current-file>"` or `#import "<path-to-current-file>"`.
4. Common names: `main.typ`, `index.typ`, `document.typ`, or a file named after the parent
   directory (e.g. `BimodalReference.typ` inside a `BimodalReference/` or `typst/` directory).
5. Any `.typ` file in the parent directory (alphabetically first), as a last-resort guess.
6. The current file, if nothing above matched.

**Example structure**:
```
typst/
├── BimodalReference.typ          # #include's chapters/00-introduction.typ -> detected as main
└── chapters/
    ├── 00-introduction.typ        # Subfile
    └── 01-foundations.typ         # Subfile
```

When editing `chapters/00-introduction.typ`, step 3 finds that `BimodalReference.typ`
`#include`s it, so:
- `<leader>lb` builds `BimodalReference.typ`, saved as `BimodalReference.pdf`
- `<leader>lv` opens `BimodalReference.pdf`
- Saving the chapter exports `BimodalReference.pdf` (tinymist's `exportPdf = "onSave"`),
  never a stray `chapters/00-introduction.pdf`
- The web preview (`<leader>ll`) shows the full document

This is independent of alphabetical order: a root file named earlier in the alphabet that does
*not* include the chapter is skipped in favor of the one that does.

### Project Root Detection

The `--root` flag (needed for cross-directory imports) and the root passed to tinymist and the
web preview come from one rule, `neotex.util.typst.project_root`:
1. The `TYPST_ROOT` environment variable, if set.
2. The directory of the nearest `typst.toml` or `.git` found upward from the main file (a
   `typst.toml` found at the same directory level as a `.git` wins).
3. The main file's own directory, if neither marker is found.

There is no special-cased `typst/` subdirectory rule; this one rule is shared by the CLI
commands, `typst-preview.nvim`, and tinymist's `root_markers`.

### Manual Main File Pinning

For non-standard structures, or when auto-detection picks the wrong file:

1. Open the file that should be treated as main (e.g. `BimodalReference.typ`)
2. Press `<leader>lp` to pin it
3. Notification confirms: "Pinned BimodalReference.typ as main file for BimodalLogic"
4. Editing *any* file under the same project root now resolves to the pinned main file

**To unpin**: Press `<leader>lu` to return to automatic (content-aware) detection.

**Note**: The pin is **project-wide** (keyed by project root, not per-buffer), so it applies
from any chapter buffer, and it survives `<leader>lk`'s `:LspRestart` -- tinymist is re-sent
the pin automatically on the next `LspAttach`. tinymist is always kept pinned to the resolved
main file, whether that came from an explicit pin or from detection, so
`exportPdf = "onSave"` always targets the right document.

---

## Preview and Sync

### Web Preview (Recommended)

The web preview provides the best experience with instant bidirectional sync:

**Forward Sync (Neovim → Browser)**:
- Automatic: Preview follows cursor as you type (`follow_cursor = true`)
- Manual: Press `<leader>ls` to scroll preview to cursor position

**Backward Sync (Browser → Neovim)**:
- Click any text in browser preview
- Neovim jumps to corresponding source location
- Requires `websocat` dependency (auto-downloaded)

**Commands**:
- `<leader>ll` - Toggle preview (recommended for daily use)
- `<leader>ls` - Sync cursor (when follow disabled)
- `<leader>lx` - Stop preview

### PDF Viewer (Sioyek)

Opens the compiled PDF in Sioyek for static viewing:

- `<leader>lv` - Opens `{main_file}.pdf` in Sioyek
- No forward/backward sync (external PDF sync not yet supported)
- Useful for final review or printing

**Note**: Sioyek custom colors configured via `~/.config/sioyek/prefs_user.config`.

### Preview Architecture

The preview system:
1. Watches for file changes
2. Incrementally compiles to SVG
3. Sends via WebSocket to browser
4. Uses VDOM diff for efficient updates

**Performance**: Sub-100ms updates for typical documents.

---

## Browser Styling Setup

The web preview can be styled to match Sioyek's soft background using browser extensions.

### Automatic Styling with Stylus (Recommended)

**One-time setup** (5 minutes):

1. **Install Stylus extension**:
   - Brave/Chrome: [Chrome Web Store](https://chromewebstore.google.com/detail/stylus/clngdbkpkpeebahjckkjfobafhncgmne)
   - Firefox: [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/styl-us/)

2. **Create style**:
   - Click Stylus icon → "Manage"
   - Click "Write new style"
   - Paste CSS (see below)
   - Under "Applies to", select "URLs starting with"
   - Enter: `http://127.0.0.1` (and optionally add `http://localhost`)
   - Name: "Typst Preview - Sioyek Colors"
   - Save (Ctrl+S)

3. **CSS to use**:

```css
/* Automatic Sioyek-style colors for typst-preview (persistent) */

/* Force body background */
body {
  background-color: #ebdbb2 !important;
  background: #ebdbb2 !important;
}

/* Target all possible container divs */
body > *,
body > div,
body > div > *,
#app,
#root,
.container,
.preview-container {
  background-color: #ebdbb2 !important;
  background: #ebdbb2 !important;
}

/* SVG should be transparent to show background through */
svg {
  background-color: transparent !important;
  background: transparent !important;
}

/* Target the white page background in SVG */
svg rect[fill="white"],
svg rect[fill="#ffffff"],
svg rect[fill="#fff"],
svg rect[fill="rgb(255, 255, 255)"] {
  fill: #ebdbb2 !important;
}

/* Text colors from Sioyek */
text, tspan, .typst-text {
  fill: #3c3836 !important;
}

/* Override any inline styles that might be added dynamically */
body[style*="background"],
div[style*="background"] {
  background-color: #ebdbb2 !important;
  background: #ebdbb2 !important;
}
```

**Colors match Sioyek settings**:
- Background: `#ebdbb2` (warm beige/cream)
- Text: `#3c3836` (dark brown)

Derived from `~/.config/sioyek/prefs_user.config`:
```
custom_background_color 0.922 0.859 0.698  # → #ebdbb2
custom_text_color 0.235 0.220 0.212        # → #3c3836
```

### Alternative: Dark Reader

For a simpler approach without custom CSS:

1. Install [Dark Reader](https://darkreader.org/)
2. When preview opens, click Dark Reader icon
3. Set:
   - Mode: Filter or Filter+
   - Brightness: 100-110
   - Contrast: 90-95
   - Sepia: 15-30 (adjust to preference)

**Note**: Less precise than Stylus but requires no CSS knowledge.

### Verification

After setup:
1. Open a Typst file in Neovim
2. Press `<leader>ll`
3. Browser should open with soft beige background
4. Background persists through dynamic content loading

**Troubleshooting**: If background flickers to white:
- Increase CSS `!important` specificity
- Check Stylus is enabled for `http://127.0.0.1`
- Verify URL pattern matches (check port in preview URL)

---

## Snippets

Comprehensive SnipMate-format snippets at `~/.config/nvim/snippets/typst.snippets`.

### Document Structure

| Trigger | Expansion | Description |
|---------|-----------|-------------|
| `h1` | `= ${1:Title}` | Level 1 heading |
| `h2` | `== ${1:Title}` | Level 2 heading |
| `h3` | `=== ${1:Title}` | Level 3 heading |
| `doc` | Full document template | Complete document with metadata |
| `temp` | Document template skeleton | Minimal template |

### Text Formatting

| Trigger | Expansion | Description |
|---------|-----------|-------------|
| `bf` | `*${1:text}*` | Bold text |
| `it` | `_${1:text}_` | Italic text |
| `code` | `` `${1:code}` `` | Inline code |
| `link` | `#link("${1:url}")[${2:text}]` | Hyperlink |
| `raw` | `\`\`\`${1:lang}\n${2}\n\`\`\`` | Code block |

### Math

| Trigger | Expansion | Description |
|---------|-----------|-------------|
| `dm` | `$ ${1:equation} $` | Display math |
| `im` | `$${1:expr}$` | Inline math |
| `frac` | `(${1:num})/(${2:den})` | Fraction |
| `sum` | `sum_(${1:i}=${2:start})^${3:end}` | Summation |
| `int` | `integral_(${1:a})^${2:b}` | Integral |
| `lim` | `lim_(${1:x} -> ${2:val})` | Limit |

### Environments

| Trigger | Expansion | Description |
|---------|-----------|-------------|
| `fig` | Figure with image | Image figure with caption |
| `tab` | Table environment | Table with headers |
| `enum` | Numbered list | Enumerated list |
| `item` | Bulleted list | Itemized list |
| `quote` | Block quote | Quotation block |

### Theorem-like

| Trigger | Expansion | Description |
|---------|-----------|-------------|
| `thm` | Theorem block | Numbered theorem |
| `lem` | Lemma block | Numbered lemma |
| `def` | Definition block | Numbered definition |
| `proof` | Proof environment | Proof with QED |
| `rem` | Remark block | Remark environment |

### Usage

1. Type trigger word (e.g., `h1`)
2. Press `<Tab>` to expand
3. Navigate placeholders with `<Tab>` / `<S-Tab>`
4. Fill in content

**Check available snippets**: Type partial word and trigger completion (`<C-n>`)

---

## Surround Operators

nvim-surround configured with Typst-specific delimiter pairs.

Typst shares the markup surround vocabulary used for markdown and LaTeX; see
`lua/neotex/plugins/tools/README.md` (Surround Operations) for the cross-filetype table.

| Key | Add Delimiter | Description |
|-----|---------------|-------------|
| `b` | `*...*` | Bold (strong emphasis) |
| `i` | `_..._` | Italic (emphasis) |
| `c` | `` `...` `` | Inline code |
| `C` (or `r`) | ` ```lang ` block | Raw block (prompts for language) |
| `m` (or `$`) | `$...$` | Inline math |
| `M` | `$ ... $` | Display math (with spaces) |
| `l` | `#link("url")[...]` | Link (prompts for URL) |
| `e` | `#fn[...]` | Function call (prompts for name) |
| `~` | `#strike[...]` | Strikethrough |

Examples: `ysiwb` -> `*word*`, `ds$` -> removes math delimiters, `csbi` -> bold to italic.

### Visual Mode

1. Select text (visual mode)
2. Press `S` followed by surround key
3. Example: `viwSb` (or `viw<leader>ssb`) → wraps word in `*...*`

---

## LSP Features

Powered by tinymist LSP server.

### Completions

- **Trigger**: Type and wait, or press `<C-n>` / `<C-Space>`
- **Context-aware**: Functions, symbols, packages, labels
- **Snippets**: Built-in LSP snippets for common patterns

### Diagnostics

- **Real-time**: Errors and warnings as you type
- **View**: `<leader>le` - Show diagnostic for current line
- **Navigate**: `]d` / `[d` - Next/previous diagnostic
- **List**: `<leader>xx` - Open trouble.nvim list

### Hover

- **Trigger**: `K` on symbol
- **Shows**: Type signature, documentation, parameter info
- **Examples**: Function signatures, Unicode symbol info

### Formatting

- **Command**: `<leader>lf`
- **Tool**: typstyle (via tinymist)
- **Scope**: Entire file or visual selection
- **On save**: Not enabled by default (add to ftplugin if desired)

### Go-to Definition

- **Trigger**: `gd` on symbol
- **Works for**: Functions, labels, references, imports
- **Multi-file**: Requires main file pinning for cross-file navigation

### References

- **Trigger**: `gr` on symbol
- **Shows**: All references to symbol in project
- **Telescope**: Searchable list with preview

### Code Actions

- **Trigger**: `<leader>ca`
- **Actions**: Import suggestions, refactorings, quick fixes

---

## Troubleshooting

### Preview doesn't open

**Check browser default**:
```bash
xdg-mime query default text/html
```

**Should show**: `brave-browser.desktop` or similar

**Fix**: Set default browser:
```bash
xdg-settings set default-web-browser brave-browser.desktop
```

### Sync not working (click-to-jump)

**Cause**: Missing `websocat` dependency

**Check**:
```lua
-- In your config, should have:
dependencies_bin = {
  ["tinymist"] = "tinymist",
  ["websocat"] = nil,  -- nil = auto-download
}
```

**Manual install** (optional):
```bash
# NixOS
environment.systemPackages = [ pkgs.websocat ];

# Then change config to:
dependencies_bin = {
  ["tinymist"] = "tinymist",
  ["websocat"] = "websocat",
}
```

### Compile command not finding main file

**From subfile** (e.g., `chapters/00-introduction.typ`):

1. Check subdirectory name is recognized: `chapters`, `sections`, `parts`, `includes`, `content`
2. Verify a root-level file `#include`s or `#import`s the subfile, or that a
   `main.typ`/`index.typ`/`document.typ`/directory-named file exists
3. Manually pin: Open main file → `<leader>lp`

**Check detection**:
```vim
:lua print(require'neotex.util.typst'.main_file(vim.api.nvim_buf_get_name(0)))
:lua print(require'neotex.util.typst'.project_root(vim.api.nvim_buf_get_name(0)))
```

### LSP not working

**Check tinymist running**:
```vim
:LspInfo
```

**Should show**: "tinymist attached"

**Restart LSP**:
```vim
:LspRestart
```

**Check installation**:
```bash
which tinymist
tinymist --version
```

### Treesitter syntax broken

**Reinstall parser**:
```vim
:TSInstall typst
:TSUpdate typst
```

**Check status**:
```vim
:TSInstallInfo
```

### Stylus not persisting

1. Check URL pattern: `http://127.0.0.1` (not `localhost`)
2. Verify style is enabled (toggle in Stylus manage page)
3. Check "Applies to" has correct URL pattern
4. Reload preview: `<leader>lx` then `<leader>ll`

### Background flickers white

**Cause**: Dynamic content overrides CSS

**Solution**: Use the more aggressive CSS from [Browser Styling Setup](#browser-styling-setup)

**Key rules**:
```css
/* These handle dynamic SVG content */
svg rect[fill="white"],
svg rect[fill="#ffffff"] {
  fill: #ebdbb2 !important;
}
```

---

## Configuration Files

### Plugin Configuration

- **typst-preview.nvim**: `~/.config/nvim/lua/neotex/plugins/text/typst-preview.lua`
- **LSP**: `~/.config/nvim/lua/neotex/plugins/lsp/lspconfig.lua`
- **Treesitter**: `~/.config/nvim/lua/neotex/plugins/editor/treesitter.lua`

### Filetype Configuration

- **Ftplugin**: `~/.config/nvim/after/ftplugin/typst.lua`
  - Keybindings
  - Main file detection
  - Buffer-local settings

### Snippets

- **Location**: `~/.config/nvim/snippets/typst.snippets`
- **Format**: SnipMate
- **~60 snippets**: Headings, math, figures, theorems, lists

### Browser Styling

- **Stylus**: Managed via browser extension
- **Applies to**: `http://127.0.0.1` (typst-preview URLs)
- **Colors**: Derived from Sioyek config

---

## Comparison with LaTeX

| Feature | LaTeX (VimTeX) | Typst (This Setup) |
|---------|----------------|-------------------|
| Keybindings | `<leader>l*` | `<leader>l*` (same prefix) |
| Preview | VimTeX viewer + SyncTeX | Web preview + click-to-jump |
| Compilation | `<leader>lb` (build once) | `<leader>lb` (build once) + `exportPdf=onSave` |
| PDF viewer | Sioyek with sync | Sioyek without sync (static) |
| Multi-file | `%!TEX root=` magic | Automatic detection + pinning |
| Snippets | LuaSnip | SnipMate (~60 snippets) |
| LSP | texlab | tinymist |
| Formatting | latexindent | typstyle (via LSP) |

**Key difference**: Web preview provides better sync experience than SyncTeX, but external PDF viewers don't support sync yet.

---

## Navigation

- [← Documentation Index](README.md)
- [← Mappings Reference](MAPPINGS.md)
- [← Architecture](ARCHITECTURE.md)

## Related Documentation

- [MAPPINGS.md](MAPPINGS.md) - Complete keybinding reference
- [INSTALLATION.md](INSTALLATION.md) - Setup instructions
- [RESEARCH_TOOLING.md](RESEARCH_TOOLING.md) - Academic writing workflows

## External Resources

- [Typst Documentation](https://typst.app/docs/)
- [tinymist GitHub](https://github.com/Myriad-Dreamin/tinymist)
- [typst-preview.nvim GitHub](https://github.com/chomosuke/typst-preview.nvim)
- [Stylus Extension](https://github.com/openstyles/stylus)
