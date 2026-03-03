# Cross-Reference Patterns

## Label Conventions

### Label Prefixes
| Prefix | Element Type | Example |
|--------|-------------|---------|
| `def:` | Definition | `\label{def:constitutive-frame}` |
| `thm:` | Theorem | `\label{thm:soundness}` |
| `lem:` | Lemma | `\label{lem:fusion-associative}` |
| `prop:` | Proposition | `\label{prop:exclusive}` |
| `cor:` | Corollary | `\label{cor:p1-p2-duality}` |
| `eq:` | Equation | `\label{eq:verification}` |
| `sec:` | Section | `\label{sec:core-extension}` |
| `tab:` | Table | `\label{tab:state-modality}` |
| `fig:` | Figure | `\label{fig:extension-diagram}` |

### Label Naming
- Use lowercase
- Hyphenate multi-word names
- Be descriptive but concise

```latex
\label{def:constitutive-frame}      % Good
\label{def:cf}                       % Too abbreviated
\label{def:The_Constitutive_Frame}   % Wrong style
```

## Reference Commands

### Standard References
```latex
% Basic reference
\ref{def:constitutive-frame}        % Output: "1.1"

% With name (cleveref)
\cref{def:constitutive-frame}       % Output: "Definition 1.1"
\Cref{def:constitutive-frame}       % Output: "Definition 1.1" (at sentence start)

% Multiple references
\cref{def:frame,def:model}          % Output: "Definitions 1.1 and 1.2"
```

### Equation References
```latex
% Standard
\eqref{eq:verification}             % Output: "(3)"

% With cleveref
\cref{eq:verification}              % Output: "Equation (3)"
```

### Page References
```latex
\pageref{def:constitutive-frame}    % Output: "12"
% Use sparingly - prefer section/definition references
```

## Lean Cross-References

### leansrc Macro
```latex
% Define in logos-notation.sty:
\newcommand{\leansrc}[2]{\texttt{#1.#2}}
\newcommand{\leanref}[1]{\texttt{#1}}
```

### Usage Patterns

**After Definition**:
```latex
\begin{definition}[Constitutive Frame]\label{def:constitutive-frame}
...
\end{definition}

See \leansrc{Logos.Foundation.Frame}{ConstitutiveFrame} for the Lean implementation.
```

**Inline Reference**:
```latex
The verification relation (\leansrc{Logos.Foundation.Semantics}{verifies})
determines which states make a formula true.
```

**Module Reference**:
```latex
For the complete semantics, see \leanref{Logos/Core/Semantics.lean}.
```

### Lean Module Mapping

| LaTeX Section | Lean Module | Primary Definitions |
|---------------|-------------|---------------------|
| Constitutive Foundation | `Logos.Foundation` | `ConstitutiveFrame`, `verifies` |
| Core Extension Syntax | `Logos.Core.Syntax` | `Formula`, operators |
| Core Extension Semantics | `Logos.Core.Semantics` | `satisfies`, `WorldHistory` |
| Core Extension Axioms | `Logos.Core.Axioms` | `C1`-`C7`, `M1`-`M5` |

### Code Path Formatting

Use consistent formatting for Lean directories, file paths, modules, and definitions.

| Element | Format | Example |
|---------|--------|---------|
| Directory | `\texttt{}` with `/` | `\texttt{Logos/Core/}` |
| File path | `\texttt{}` with `.lean` | `\texttt{Logos/Core/Semantics.lean}` |
| Module | `\texttt{}` with `.` | `\texttt{Logos.Core.Semantics}` |
| Definition | `\texttt{}` | `\texttt{soundness\_theorem}` |

**Important**: Underscores in Lean names must be escaped as `\_` in LaTeX source.

**Examples**:
```latex
% Directory reference
The semantics module is located in \texttt{Logos/Core/}.

% File path reference
See \texttt{Logos/Core/Semantics.lean} for the implementation.

% Module reference
The \texttt{Logos.Core.Semantics} module defines the satisfaction relation.

% Definition with underscore
The theorem \texttt{soundness\_theorem} establishes...
```

**Note**: The `\leansrc` and `\leanref` macros handle this formatting automatically when available.
Use raw `\texttt{}` only when the macros are not defined.

## Bibliography References

### Citation Commands
```latex
\cite{fine2017truthmaker}           % Standard citation
\cite[p.~42]{fine2017truthmaker}    % With page number
\cite{fine2017,rosen2010}           % Multiple citations
```

### Citation Placement
```latex
% At end of sentence
The exact truthmaker semantics is described in \cite{fine2017truthmaker}.

% Mid-sentence
Following Fine \cite{fine2017truthmaker}, we define verification as...
```

### BibTeX Entry Pattern
```bibtex
@article{fine2017truthmaker,
  author = {Fine, Kit},
  title = {Truthmaker Semantics},
  journal = {A Companion to the Philosophy of Language},
  year = {2017},
  pages = {556--577},
  publisher = {Wiley-Blackwell}
}
```

## Cross-Subfile References

### Referencing Other Subfiles
```latex
% In 03-CoreExtension-Semantics.tex
As defined in \cref{def:constitutive-frame} (see Section~\ref{sec:foundation}),
the constitutive frame provides...
```

### Forward References
```latex
% Reference to content defined later
The counterfactual conditional (see \cref{sec:counterfactual}) extends...
```

## Best Practices

### Do
- Label all definitions, theorems, and important equations
- Use cleveref (`\cref`) for automatic naming
- Include Lean cross-references for implemented concepts
- Use descriptive label names

### Don't
- Over-label (skip trivial remarks)
- Use hard-coded numbers ("see Definition 3")
- Reference uncommitted Lean code
- Use labels that might change meaning

## Example: Full Cross-Reference Flow

```latex
\section{Core Extension}\label{sec:core-extension}

\begin{definition}[Core Frame]\label{def:core-frame}
A \emph{core frame} extends a constitutive frame (\cref{def:constitutive-frame})
with temporal structure.
\end{definition}

The core frame (\cref{def:core-frame}) enables evaluation of modal and temporal
formulas. See \leansrc{Logos.Core.Frame}{CoreFrame} for the Lean implementation.

\begin{theorem}[Perpetuity]\label{thm:perpetuity}
The principles P1--P6 (\cref{eq:p1,eq:p2,eq:p3,eq:p4,eq:p5,eq:p6}) are valid
in all core frames.
\end{theorem}

This result follows from the task semantics developed in \cite{brastmckie2024possible}.
```
