# Neovim Keybindings Reference

This document provides a comprehensive overview of all keybindings configured in this Neovim setup, organized by context and functionality.

## 🎯 Filetype-Dependent Mappings

**Important Note**: Many of the leader-based mappings listed below are **filetype-dependent** and only appear when working with relevant file types. This configuration uses a hybrid approach in which-key.nvim to provide context-aware keybindings:

- **Document** (`<leader>l*`): The single prefix for acting on the current document, in every
  filetype. Which commands appear depends on the file: LaTeX in `.tex`/`.latex`/`.bib`/`.cls`/`.sty`,
  Typst in `.typ`, Slidev in a deck's `.md`, and a pandoc conversion fallback in the remaining
  convertible formats (markdown, org, rst, html, docx). The core verbs mean the same thing in all
  of them -- see [DOCUMENT](#document-leaderl).
- **Jupyter** (`<leader>j*`): Only available in `.ipynb` files
- **Markdown** (`<leader>m*`): Only available in `.md`, `.markdown` files
- **Templates** (`<leader>T*`): Only available in LaTeX files
- **Lean Actions**: Only available in `.lean` files
- **Markdown Actions** (`<leader>ar`): Only available in markdown files

This means you'll only see relevant mappings for your current file type, providing a cleaner and more focused interface.

## Table of Contents

1. [Global Keybindings](#global-keybindings)
2. [Leader-Based Mappings](#leader-based-mappings)
3. [Buffer-Specific Mappings](#buffer-specific-mappings)
4. [Plugin-Specific Mappings](#plugin-specific-mappings)

---

## Global Keybindings

These keybindings are available in all contexts and override default Vim behavior for improved workflow.

### Navigation and Movement

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `<Space>` | n | Leader key | Main leader key for command sequences |
| `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` | n | Window navigation | Navigate between windows |
| `<Tab>` | n | Next buffer | Go to next buffer (by modified time) |
| `<S-Tab>` | n | Previous buffer | Go to previous buffer (by modified time) |
| `<C-u>`, `<C-d>` | n | Scroll with centering | Scroll half-page up/down with cursor centering |
| `<S-h>`, `<S-l>` | n,v | Line navigation | Go to start/end of display line |
| `J`, `K` | n,v | Display line navigation | Navigate display lines (respects wrapping) |
| `<A-Left>`, `<A-Right>`, `<A-h>`, `<A-l>` | n | Window resizing | Resize window horizontally |

### Quickfix and Location List Navigation

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `]q` | n | Next quickfix | Jump to next quickfix item (centered) |
| `[q` | n | Previous quickfix | Jump to previous quickfix item (centered) |
| `]Q` | n | Last quickfix | Jump to last quickfix item (centered) |
| `[Q` | n | First quickfix | Jump to first quickfix item (centered) |
| `]l` | n | Next location | Jump to next location list item (centered) |
| `[l` | n | Previous location | Jump to previous location list item (centered) |
| `]L` | n | Last location | Jump to last location list item (centered) |
| `[L` | n | First location | Jump to first location list item (centered) |

### Text Manipulation

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `Y` | n,v | Yank to end | Yank from cursor to end of line |
| `E` | n | Previous word end | Go to end of previous word |
| `m` | n,v | Center cursor | Center cursor at top of screen |
| `<A-j>`, `<A-k>` | n,x,v | Move lines | Move current line or selection up/down |
| `<`, `>` | n,v | Indentation | Decrease/increase indentation (preserves selection) |

### Search and File Operations

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `<CR>` | n | Clear search | Clear search highlighting |
| `<C-p>` | n | Find files | Find files with Telescope |
| `<C-s>` | n | Spelling suggestions | Show spelling suggestions with Telescope |
| `<S-m>` | n | Help lookup | Show help for word under cursor |
| `<C-m>` | n | Man pages | Search man pages with Telescope |

### Comments and Editing

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `<C-;>` | n | Toggle comment | Toggle comments for current line |
| `<C-;>` | v | Toggle comment | Toggle comments for selection |

### Terminal Integration

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `<C-t>` | n,t | Toggle terminal | Toggle terminal window |

### Disabled Keys

| Key(s) | Mode | Action | Description |
|--------|------|--------|-------------|
| `<C-z>` | n | Disabled | Prevents accidental suspension |
| `gc`, `gcc` | n | Disabled | Prevents conflict with mini.comment |

---

## Leader-Based Mappings

All leader-based mappings use `<Space>` as the leader key and are organized into logical groups.

### Top-Level Mappings

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>c` | Create vertical split | Split window vertically |
| `<leader>d` | Save and delete buffer | Save file and close buffer |
| `<leader>e` | Toggle NvimTree explorer | Open/close file explorer |
| `<leader>k` | Maximize split | Make current window full screen |
| `<leader>q` | Save all and quit | Save all files and exit Neovim |
| `<leader>u` | Open Telescope undo | Show undo history with preview |
| `<leader>w` | Write all files | Save all open files |

### AI/ASSISTANT (`<leader>a`)

**Claude Code Integration**

| Key | Mode | Description |
|-----|------|-------------|
| `<C-CR>` | All | Unified AI tool picker |
| `<leader>al` | Normal | AI commands/agent loader picker |
| `<leader>al` | Visual | Send selection with prompt |
| `<leader>as` | Normal | Browse Claude sessions |
| `<leader>at` | Normal | Toggle TTS notifications (project-specific) |
| `<leader>av` | Normal | View git worktrees |
| `<leader>aw` | Normal | Create new worktree with Claude session |
| `<leader>ar` | Normal | Restore closed worktree session |
| `<leader>ak` | Normal | Kill stale sessions |
| `<leader>aH` | Normal | Health check |

See [Claude Code documentation](../lua/neotex/plugins/ai/claude/README.md) for complete feature details.

**Other AI Tools**

| Key | Action | Description | Availability |
|-----|--------|-------------|--------------|
| `<leader>aX` | MCP Hub | Open MCP Hub interface | All files |
| `<leader>an` | New Lectic file | Create Lectic file | `.lec`/`.md` files |

### FIND (`<leader>f`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>fa` | Find all files | Search all files, including hidden |
| `<leader>fb` | Find buffers | Switch between open buffers |
| `<leader>fc` | Find citations | Search BibTeX citations |
| `<leader>ff` | Find in project | Search text in project files |
| `<leader>fl` | Resume last search | Continue previous search |
| `<leader>fp` | Copy buffer path | Copy current file path to clipboard |
| `<leader>fq` | Find in quickfix | Search within quickfix list |
| `<leader>fg` | Git commit history | Browse git commit history |
| `<leader>fh` | Help tags | Search Neovim help documentation |
| `<leader>fk` | Keymaps | Show all keybindings |
| `<leader>fr` | Registers | Show clipboard registers |
| `<leader>fs` | Search string | Search for string in project |
| `<leader>ft` | Find todos | Search for TODO comments |
| `<leader>fw` | Search word under cursor | Find current word in project |
| `<leader>fy` | Yank history | Browse clipboard history |

### GIT (`<leader>g`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>gb` | Browse branches | Browse and checkout branches |
| `<leader>gc` | View commits | Show commit history |
| `<leader>gd` | Diff HEAD | Show changes against HEAD |
| `<leader>gg` | LazyGit | Launch LazyGit interface |
| `<leader>gh` | Previous hunk | Jump to previous change |
| `<leader>gj` | Next hunk | Jump to next change |
| `<leader>gl` | Line blame | Show git blame for current line |
| `<leader>gp` | Preview hunk | Preview current change |
| `<leader>gs` | Git status | Show files with changes |
| `<leader>gt` | Toggle blame | Toggle line blame display |

### HELP (`<leader>h`)

| Key | Action | Description |
|-----|--------|-------------|
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>hh` | Help tags | Search Neovim help documentation |
| `<leader>hk` | Keymaps | Show all keybindings |
| `<leader>hm` | Man pages | Search man pages |

### LSP & LINT (`<leader>i`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ib` | Buffer diagnostics | Show all errors in current file |
| `<leader>ic` | Code action | Show available code actions |
| `<leader>id` | Go to definition | Jump to symbol definition |
| `<leader>iD` | Go to declaration | Jump to symbol declaration |
| `<leader>ih` | Hover help | Show documentation under cursor |
| `<leader>ii` | Implementations | Find implementations of symbol |
| `<leader>il` | Line diagnostics | Show errors for current line |
| `<leader>in` | Next diagnostic | Go to next error/warning |
| `<leader>ip` | Previous diagnostic | Go to previous error/warning |
| `<leader>ir` | References | Find all references to symbol |
| `<leader>is` | Restart LSP | Restart language server |
| `<leader>it` | Toggle LSP | Start/stop language server |
| `<leader>iy` | Copy diagnostics | Copy diagnostics to clipboard |
| `<leader>iR` | Rename | Rename symbol under cursor |
| `<leader>iL` | Lint file | Run linters on current file |
| `<leader>ig` | Toggle global linting | Enable/disable linting globally |
| `<leader>iB` | Toggle buffer linting | Enable/disable linting for buffer |

### JUPYTER (`<leader>j`)

**Availability**: Only available in `.ipynb` files.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>je` | Execute cell | Run current notebook cell |
| `<leader>jj` | Next cell | Navigate to next cell |
| `<leader>jk` | Previous cell | Navigate to previous cell |
| `<leader>jn` | Execute and next | Run cell and move to next |
| `<leader>jo` | Insert cell below | Add new cell below current |
| `<leader>jO` | Insert cell above | Add new cell above current |
| `<leader>js` | Split cell | Split current cell at cursor |
| `<leader>jc` | Comment cell | Comment out current cell |
| `<leader>ja` | Run all cells | Execute all notebook cells |
| `<leader>jb` | Run cells below | Run notebook cells below cursor |
| `<leader>ju` | Merge with cell above | Join current cell with cell above |
| `<leader>jd` | Merge with cell below | Join current cell with cell below |
| `<leader>ji` | Start IPython REPL | Start Python interactive shell |
| `<leader>jt` | Send motion to REPL | Send text via motion to REPL |
| `<leader>jl` | Send line to REPL | Send current line to REPL |
| `<leader>jf` | Send file to REPL | Send entire file to REPL |
| `<leader>jq` | Exit REPL | Close the REPL |
| `<leader>jr` | Clear REPL | Clear the REPL screen |
| `<leader>jv` | Send visual selection to REPL | Send selected text to REPL |

### DOCUMENT (`<leader>l`)

`<leader>l` is the only prefix for document commands. Each document filetype registers its own
buffer-local group under it, and these core verbs carry the same meaning in every one of them, so
the habit transfers between LaTeX, Typst and Slidev:

| Key | Verb | LaTeX | Typst | Slidev |
|-----|------|-------|-------|--------|
| `<leader>ll` | live / compile / preview | VimtexCompile | web preview (toggle) | dev server (toggle) |
| `<leader>lb` | build the artifact `lv` opens | latexmk | compile once | export PDF |
| `<leader>lv` | view output | VimtexView | Sioyek | Sioyek |
| `<leader>le` | errors | VimtexErrors | LSP diagnostics | -- |
| `<leader>lf` | format | latexindent | tinymist | -- |
| `<leader>lk` | clean artifacts | aux + cache | artifacts | -- |
| `<leader>lx` | stop background process | VimtexStop | watch + preview | dev server |
| `<leader>li` | index / outline | VimtexTocOpen | -- | -- |
| `<leader>lc` | convert (pandoc) | prompts for format | -- | -- |

Filetypes with no group of their own (org, rst, html, docx, and plain markdown) fall back to a
global `document` group offering just `<leader>lc` (convert) and `<leader>lv` (view pdf).

All bindings are two keys and lowercase; `<leader>lc` prompts for the target format rather than
spending a key on each one.

### LATEX (`<leader>l`)

**Availability**: Only available in `.tex`, `.latex`, `.bib`, `.cls`, `.sty` files.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ll` | Live compile | VimtexCompile (continuous) |
| `<leader>lb` | Build once | Single latexmk run |
| `<leader>lv` | View pdf | Preview PDF output |
| `<leader>le` | Errors | Display LaTeX error messages |
| `<leader>lf` | Format | Format LaTeX using latexindent |
| `<leader>lk` | Clean aux + cache | Remove aux files and clear the vimtex cache |
| `<leader>lx` | Stop compiler | VimtexStop |
| `<leader>li` | Index | Show document structure (TOC) |
| `<leader>lc` | Convert... | Pandoc conversion, prompts for format |
| `<leader>la` | Annotate | Work with PDF annotations |
| `<leader>ld` | Draft mode | Build with draft mode enabled |
| `<leader>lg` | Glossary | Open LaTeX glossary template |
| `<leader>lm` | Menu | Show VimTeX context actions |
| `<leader>lr` | Bib export (references) | Export BibTeX to separate file |
| `<leader>ls` | Subfile toggle | Toggle between subfile and main file |
| `<leader>lw` | Word count | Count words in LaTeX document |

### TYPST (`<leader>l`)

**Availability**: Only available in `.typ` files. Uses same prefix as LaTeX but filetype-isolated (no conflicts).

**Note**: For comprehensive Typst documentation including setup, preview, multi-file projects, and browser styling, see [TYPST.md](TYPST.md).

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ll` | Live preview (web) | Toggle browser preview with sync |
| `<leader>lb` | Build once | Single compilation run |
| `<leader>lv` | View pdf (Sioyek) | Open compiled PDF in external viewer |
| `<leader>le` | Errors (LSP) | Show diagnostics for current line |
| `<leader>lf` | Format | Format via tinymist LSP (using typstyle) |
| `<leader>lk` | Clean artifacts | Delete compiled svg/pdf and restart tinymist |
| `<leader>lx` | Stop (watch + preview) | Stop whichever background processes are live |
| `<leader>lw` | Watch (toggle) | Continuous compilation on save |
| `<leader>lq` | Quickfix (compile) | Open the compile-error quickfix list |
| `<leader>ls` | Sync cursor (web) | Manually sync preview to cursor position |
| `<leader>lp` | Pin main file | Pin current file as main (multi-file projects) |
| `<leader>lu` | Unpin main file | Return to automatic main file detection |

### SLIDEV (`<leader>l`)

**Availability**: Only in a Slidev deck's markdown -- a file whose first line opens YAML
frontmatter and whose directory (or its parent) has a `package.json` depending on `@slidev/cli`.
Ordinary markdown gets the global `document` group instead.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ll` | Live preview (toggle) | Start the dev server and open it, or stop it |
| `<leader>lb` | Build pdf (export) | `slidev export` to a PDF beside the deck |
| `<leader>lv` | View pdf (Sioyek) | Open the exported PDF |
| `<leader>lx` | Stop server | Stop this deck's dev server |
| `<leader>lo` | Open in browser | Reopen a running server's deck |
| `<leader>lp` | Presenter view | Open the presenter URL |
| `<leader>ls` | Build site (dist/) | `slidev build` static output |

### MARKDOWN (`<leader>m`)

**Availability**: Only available in `.md`, `.markdown` files.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ml` | Run Lectic | Run Lectic on current file |
| `<leader>mn` | New Lectic file | Create new Lectic file with template |
| `<leader>ms` | Submit selection | Submit visual selection with user message |
| `<leader>mp` | Format buffer | Format code with conform.nvim |
| `<leader>mu` | Open URL | Open URL under cursor |
| `<leader>ma` | Toggle all folds | Toggle all folds open/closed |
| `<leader>mf` | Toggle fold | Toggle fold under cursor |
| `<leader>mt` | Toggle folding method | Switch between manual/smart folding |

### NIXOS (`<leader>n`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>nd` | Nix develop | Enter nix development shell |
| `<leader>nf` | Rebuild flake | Rebuild system from flake |
| `<leader>ng` | Garbage collection | Clean up old nix packages (15d) |
| `<leader>np` | Browse packages | Open nixOS packages website |
| `<leader>nm` | MyNixOS | Open MyNixOS website |
| `<leader>nh` | Home-manager switch | Apply home-manager changes |
| `<leader>nr` | Rebuild nix | Run update.sh script |
| `<leader>nu` | Update flake | Update flake dependencies |

### RUN (`<leader>r`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>rc` | Clear plugin cache | Clear Neovim plugin cache |
| `<leader>re` | Show linter errors | Display all errors in floating window |
| `<leader>rk` | Wipe plugins and lock file | Remove all plugin files AND lazy-lock.json |
| `<leader>rn` | Next error | Go to next diagnostic/error |
| `<leader>rp` | Previous error | Go to previous diagnostic/error |
| `<leader>rr` | Reload configs | Reload Neovim configuration |
| `<leader>rm` | Show messages | Display notification history |

### SESSIONS (`<leader>S`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>Ss` | Save session | Save current session |
| `<leader>Sd` | Delete session | Delete a saved session |
| `<leader>Sl` | Load session | Load a saved session |

### SURROUND (`<leader>s`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ss` | Add surrounding | Add surrounding to text (requires motion) |
| `<leader>sd` | Delete surrounding | Remove surrounding characters |
| `<leader>sc` | Change surrounding | Replace surrounding characters |

### TODO (`<leader>t`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>tt` | Todo telescope | Find all TODOs in project |
| `<leader>tn` | Next todo | Jump to next TODO comment |
| `<leader>tp` | Previous todo | Jump to previous TODO comment |
| `<leader>tl` | Todo location list | Show TODOs in location list |
| `<leader>tq` | Todo quickfix | Show TODOs in quickfix list |

### TEMPLATES (`<leader>T`)

**Availability**: Only available in `.tex`, `.latex` files.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>Ta` | Article.tex | Insert article template |
| `<leader>Tb` | Beamer_slides.tex | Insert beamer presentation template |
| `<leader>Tg` | Glossary.tex | Insert glossary template |
| `<leader>Th` | Handout.tex | Insert handout template |
| `<leader>Tl` | Letter.tex | Insert letter template |
| `<leader>Tm` | MultipleAnswer.tex | Insert multiple answer template |
| `<leader>Tr` | Copy report/ directory | Copy report template directory |
| `<leader>Ts` | Copy springer/ directory | Copy springer template directory |

### TEXT (`<leader>x`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>xa` | Align | Start text alignment |
| `<leader>xA` | Align with preview | Start alignment with preview |
| `<leader>xs` | Split/join toggle | Toggle between single/multi-line |
| `<leader>xd` | Toggle diff overlay | Show diff between buffer and clipboard |
| `<leader>xw` | Toggle word diff | Show word-level diffs |

### VOICE (`<leader>v`)

Speech-to-text input using Vosk offline recognition.

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>vr` | Start recording | Begin audio capture for transcription |
| `<leader>vs` | Stop recording | Stop capture and insert transcribed text at cursor |
| `<leader>vv` | Toggle recording | Start recording if stopped, stop if recording |
| `<leader>vh` | Health check | Verify STT dependencies and model availability |
| `<C-\>` | Toggle recording | Works in both normal and terminal modes (Claude Code sidebar) |

**Commands**: `:STTStart`, `:STTStop`, `:STTToggle`, `:STTHealth`

**Dependencies**: `parecord` (PulseAudio/PipeWire), Python 3, Vosk package, vosk-transcribe.py script

**Configuration**: `lua/neotex/plugins/tools/stt/`

**Note**: In terminal buffers like Claude Code, `<C-\>` exits terminal mode temporarily to allow STT to function, then resumes after recording stops.

### YANK (`<leader>y`)

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>yh` | Yank history | Browse clipboard history with Telescope |
| `<leader>yc` | Clear history | Clear the yank history |

### Visual Mode Mappings

| Key | Mode | Action | Description |
|-----|------|--------|-------------|
| `<leader>ss` | v | Add surrounding to selection | Surround selected text |

---

## Buffer-Specific Mappings

These keybindings are automatically applied when specific buffer types are detected.

### Terminal Mode

Active in terminal buffers (`:terminal` command or toggleterm).

| Key | Action | Description |
|-----|--------|-------------|
| `<Esc>` | Exit terminal mode | Switch from terminal to normal mode |
| `<C-t>` | Toggle terminal | Close/open terminal window |
| `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` | Navigate windows | Move between terminal and other windows |
| `<M-h>`, `<M-l>`, `<M-Left>`, `<M-Right>` | Resize terminal | Adjust terminal window width |
| `<C-\>` | Toggle STT recording | Start/stop speech-to-text recording (exits terminal mode temporarily) |

### Markdown Buffers

Active in markdown files (`.md`, `.markdown` extensions).

| Key | Mode | Action | Description |
|-----|------|--------|-------------|
| `<CR>` | i | Smart bullet creation | Create new bullet point |
| `o` | n | New bullet below | Create bullet point below cursor |
| `O` | n | New bullet above | Create bullet point above cursor |
| `<Tab>` | i | Smart indent | Indent bullet and recalculate numbers |
| `<S-Tab>` | i | Smart unindent | Unindent bullet and recalculate numbers |
| `dd` | n | Delete and recalculate | Delete line and fix list numbering |
| `d` | v | Delete and recalculate | Delete selection and fix numbering |
| `<C-n>` | n | Toggle checkbox | Cycle checkbox status ([ ] � [x]) |
| `<C-c>` | n | Recalculate list | Fix all list numbering |
| `>`, `<` | n | Indent/unindent | Adjust bullet indentation with recalculation |

### Yanky (Clipboard Management)

| Key | Mode | Action | Description |
|-----|------|--------|-------------|
| `y` | n,x | Enhanced yank | Yank with history tracking |
| `p` | n | Enhanced paste after | Paste after cursor with formatting |
| `P` | n | Enhanced paste before | Paste before cursor with formatting |
| `gp` | n | Paste and position | Paste after and leave cursor after text |
| `gP` | n | Paste and position | Paste before and leave cursor after text |

### TODO Comments

| Key | Mode | Action | Description |
|-----|------|--------|-------------|
| `]t` | n | Next todo | Jump to next TODO comment |
| `[t` | n | Previous todo | Jump to previous TODO comment |

---

## Notes

1. **Leader Key**: The leader key is set to `<Space>` (spacebar) for easy access.

2. **Mode Abbreviations**:
   - `n` = Normal mode
   - `i` = Insert mode  
   - `v` = Visual mode
   - `x` = Visual block mode
   - `t` = Terminal mode

3. **Buffer-Specific Mappings**: Many mappings are automatically applied based on file type or buffer context. These are managed by autocmds in the configuration.

4. **Plugin Dependencies**: Some mappings require specific plugins to be loaded. If a plugin fails to load, fallback mappings may be used.

5. **Customization**: All mappings can be customized by editing the corresponding configuration files:
   - Global mappings: `lua/neotex/config/keymaps.lua`
   - Leader mappings: `lua/neotex/plugins/editor/which-key.lua`
   - Plugin-specific mappings: Individual plugin configuration files

## Navigation

- [Main Configuration ←](../README.md)
- [Installation Guide ←](INSTALLATION.md)

For more information about the overall configuration structure, see the main [README](../README.md).
## Related Documentation

- [AI_TOOLING.md](AI_TOOLING.md) - OpenCode keybindings
- [RESEARCH_TOOLING.md](RESEARCH_TOOLING.md) - VimTeX and research tool mappings
- [NOTIFICATIONS.md](NOTIFICATIONS.md) - Notification system commands
- [Neotex Plugins](../lua/neotex/plugins/README.md) - Plugin-specific keybindings
