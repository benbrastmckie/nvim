## LaTeX Extension

This project includes LaTeX document development support via the latex extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `latex` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (pdflatex, latexmk) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-latex-implementation | latex-implementation-agent | LaTeX document implementation |

### VimTeX Integration

- Compile: `:VimtexCompile` (`<leader>lc`)
- View PDF: `:VimtexView` (`<leader>lv`)
- Clean: `:VimtexClean` (`<leader>lk`)
- TOC: `:VimtexTocOpen` (`<leader>li`)

### Document Structure

- Use `\documentclass` appropriate for document type
- Organize with `\input{}` for modular documents
- Use `build/` directory for output files
- Keep `.bib` files organized by project
