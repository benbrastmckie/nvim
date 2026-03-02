---
paths: "**/*.tex"
---

# LaTeX Development Rules

## Source File Formatting

### Semantic Linefeeds

Use **one sentence per line** in LaTeX source files.

| Rule | Description |
|------|-------------|
| Sentence breaks | Each sentence starts on a new line |
| End punctuation | Period/exclamation/question followed by newline |
| Clause breaks | Long sentences may break after commas, semicolons |
| No auto-wrap | Disable automatic line wrapping in your editor |
| Protected spaces | Use `~` before citations: `text~\cite{foo}` |

### Quick Reference

```latex
% GOOD: One sentence per line
Modal logic extends propositional logic with modal operators.
The necessity operator $\Box$ is interpreted over all accessible worlds.
The possibility operator $\Diamond$ is its dual.

% BAD: Multiple sentences on one line
Modal logic extends propositional logic with modal operators. The necessity operator is interpreted...
```

## Common Patterns

### Theorem Environments

```latex
\begin{definition}[Name]
  Content here.
\end{definition}

\begin{theorem}[Name]
  Statement.
\end{theorem}

\begin{proof}
  Proof content.
\end{proof}
```

### Cross-References

```latex
% Use cleveref for automatic prefixes
\Cref{def:frame} produces "Definition 1"
\cref{thm:soundness} produces "theorem 2"

% Label conventions
def:name    % Definitions
thm:name    % Theorems
lem:name    % Lemmas
sec:name    % Sections
eq:name     % Equations
```

## Validation Checklist

Before committing LaTeX changes:

- [ ] One sentence per line (semantic linefeeds)
- [ ] Environments properly opened and closed
- [ ] Cross-references resolve without warnings
- [ ] No overfull hboxes in compiled output
- [ ] Builds successfully with `pdflatex`

## Build Commands

```bash
# Basic build
pdflatex document.tex
pdflatex document.tex  # Second pass

# With bibliography
pdflatex document.tex
bibtex document
pdflatex document.tex
pdflatex document.tex

# Automated (recommended)
latexmk -pdf document.tex

# Clean auxiliary files
latexmk -c
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| Undefined control sequence | Missing package | Add `\usepackage{...}` |
| Missing \$ inserted | Math mode issue | Wrap in `$...$` |
| Overfull hbox | Line too long | Break at clause boundary |
| Citation undefined | Missing bib entry | Add to `.bib` file |
