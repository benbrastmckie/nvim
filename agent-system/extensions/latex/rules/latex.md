---
paths: ["**/*.tex", "**/*.latexmkrc", "**/*.bib", "**/build/**"]
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

## Continuous Build Safety

A user's editor (typically nvim's vimtex plugin) commonly runs a continuous-build watcher --
`latexmk -pvc` -- against the same `.tex` file and shared output directory an agent is about to
build. Running a competing build into that shared directory corrupts it: empty `.aux` files, a
deleted PDF, spurious "Build failed" entries appended by the project's `.latexmkrc`
`$failure_cmd`, bibtex reporting "I found no \citation commands", and a nonzero latexmk exit code
(commonly 12) despite zero actual LaTeX errors in the log. This section governs every build
command below and in `context/project/latex/tools/compilation-guide.md`, regardless of task type
-- the race is not specific to `latex`-typed dispatches.

**1. Detect before compiling.** Before any `latexmk`/`pdflatex`/`xelatex`/`lualatex` invocation,
check for a running continuous watcher on the same source:

```bash
pgrep -af 'latexmk.*-pvc'
```

Also check for any `latexmk`/`pdflatex` process whose arguments name the same `.tex` file or the
same `-outdir` you are about to use.

**2. If a watcher is running, do not contend.** Never run `latexmk`/`pdflatex` into the shared
`-outdir` (or whatever output directory the watcher uses). Never kill, stop, or restart the
watcher. Never run `latexmk -C` or `latexmk -c` against the shared directory.

**3. Use a non-contending path instead.** Either:
   - Make the edit and let vimtex rebuild -- it is already watching the file; or
   - Verify compilation with an isolated build into the session scratchpad and inspect the log
     there:

     ```bash
     latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null document.tex
     ```

     `-r /dev/null` bypasses the project `.latexmkrc`, which is what appends the spurious
     "Build failed" entries via `$failure_cmd`.

**4. Report, do not repair.** Report the isolated build's result. If the shared build directory
looks broken (missing PDF, empty `.aux`, "Build failed" entries in `build/compile.log`), tell the
user to run `:VimtexClean` then `:VimtexCompile`. Do not attempt repairs against the shared
directory.

**5. Classify the failure before rerunning.** When diagnosing a nonzero latexmk exit code,
distinguish a latexmk-level failure (exit 12, bibtex/aux complaints such as "I found no
\citation commands") from an actual LaTeX error (a `^!` line, or a file-line-error
`file.tex:N:` line) BEFORE rerunning anything. A clean log with a nonzero exit code is a
contention signal, not a source error.

## Validation Checklist

Before committing LaTeX changes:

- [ ] One sentence per line (semantic linefeeds)
- [ ] Environments properly opened and closed
- [ ] Cross-references resolve without warnings
- [ ] No overfull hboxes in compiled output
- [ ] Builds successfully via an isolated build (see "Continuous Build Safety" above) -- never a
      bare build into a directory a continuous watcher may own

## Build Commands

Before running any command below, apply "Continuous Build Safety" above -- check for a competing
`latexmk -pvc` watcher first.

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
