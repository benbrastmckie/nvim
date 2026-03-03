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
| Clause breaks | Long sentences may break after commas, semicolons, conjunctions |
| No auto-wrap | Disable automatic line wrapping in your editor |
| Protected spaces | Use `~` before citations: `text~\cite{foo}` |

### Quick Reference

```latex
% GOOD: One sentence per line
Modal logic extends propositional logic with modal operators.
The necessity operator $\nec$ is interpreted over all accessible worlds.
The possibility operator $\pos$ is its dual.

% BAD: Multiple sentences on one line
Modal logic extends propositional logic with modal operators. The necessity operator $\nec$ is interpreted over all accessible worlds. The possibility operator $\pos$ is its dual.
```

### Long Sentence Breaks

Break at natural clause boundaries:

```latex
% Break after comma (dependent clause)
The canonical model construction proceeds by first extending the consistent set,
then defining accessibility via modal witnesses.

% Break at conjunction
A frame is reflexive if every world accesses itself,
and transitive if accessibility composes.
```

## Common Patterns

### Notation Macros

Always use `logos-notation.sty` macros for consistency:

| Macro | Output | Usage |
|-------|--------|-------|
| `\nec` | $\Box$ | Necessity operator |
| `\pos` | $\Diamond$ | Possibility operator |
| `\allpast` | $\mathbf{H}$ | Always past |
| `\allfuture` | $\mathbf{G}$ | Always future |
| `\sempast` | $\mathbf{P}$ | Sometimes past |
| `\semfuture` | $\mathbf{F}$ | Sometimes future |

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
- [ ] `logos-notation.sty` macros used consistently
- [ ] Environments properly opened and closed
- [ ] Cross-references resolve without warnings
- [ ] No overfull hboxes in compiled output
- [ ] Builds successfully with `pdflatex`

## Build Commands

```bash
# Build main document
cd Theories/Logos/latex
pdflatex LogosReference.tex

# Build with bibliography
pdflatex LogosReference.tex
bibtex LogosReference
pdflatex LogosReference.tex
pdflatex LogosReference.tex

# Build subfile standalone
cd Theories/Logos/latex/subfiles
pdflatex 01-ConstitutiveFoundation.tex
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| Undefined control sequence | Missing package or macro | Check imports and `logos-notation.sty` |
| Missing $ inserted | Math mode issue | Wrap in `$...$` or use correct environment |
| Overfull hbox | Line too long | Break line at clause boundary or use `\linebreak` |
| Citation undefined | Missing bib entry | Add to `.bib` file and run bibtex |
