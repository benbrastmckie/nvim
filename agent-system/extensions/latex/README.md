# LaTeX Extension

LaTeX document development support with VimTeX integration and standard LaTeX tooling (`pdflatex`, `latexmk`).

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `latex` | latex-research-agent | LaTeX/package/class research |
| `latex` | latex-implementation-agent | LaTeX document implementation |

## Installation

Loaded via the extension picker. Once loaded, `latex` becomes a recognized task type.

## Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via `/orchestrate`) with `task_type: "latex"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-latex-research | latex-research-agent | LaTeX/package research |
| skill-latex-implementation | latex-implementation-agent | LaTeX document implementation |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `latex` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash(pdflatex, latexmk) |

## VimTeX Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>ll` | `:VimtexCompile` - compile current document |
| `<leader>lv` | `:VimtexView` - view PDF |
| `<leader>lk` | `:VimtexClean` + `:VimtexClearCache` - clean build artifacts |
| `<leader>li` | `:VimtexTocOpen` - open table of contents |

## Document Structure Conventions

- Use `\documentclass{...}` appropriate for document type
- Organize with `\input{}` for modular documents
- Use a dedicated `build/` directory for output files
- Keep `.bib` files organized by project

## Rules Applied

- `latex.md` - LaTeX style conventions (auto-applied to `*.tex`, `*.bib` files)

## References

- [LaTeX Project](https://www.latex-project.org/)
- [VimTeX](https://github.com/lervag/vimtex)
- [TeX Stack Exchange](https://tex.stackexchange.com/)
