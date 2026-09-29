## LaTeX Extension

This project includes LaTeX document development support via the latex extension.

### Scope

This extension covers formatting, compilation, styling, and structural concerns for existing
document content. Content-creation work (proofs, theorems, chapters, textbook prose) routes to
`lean4`, `formal`, or `general` as appropriate, not to `latex`.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `latex` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (pdflatex, latexmk) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-latex-implementation | latex-implementation-agent | LaTeX document implementation |

### Document Structure

- Use `\documentclass` appropriate for document type
- Organize with `\input{}` for modular documents
- Use `build/` directory for output files
- Keep `.bib` files organized by project

### Build Safety

Before any `latexmk`/`pdflatex` build command -- including outside a `latex`-typed task -- check
for a competing vimtex continuous-build watcher (`latexmk -pvc`) on the same target. See
`rules/latex.md`'s "Continuous Build Safety" section for the detection command and the
non-contending build path; not restated here.
