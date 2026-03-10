# Cross-Reference Patterns

## Label Conventions

### Label Prefixes
| Prefix | Element Type | Example |
|--------|-------------|---------|
| `def:` | Definition | `\label{def:concept-name}` |
| `thm:` | Theorem | `\label{thm:soundness}` |
| `lem:` | Lemma | `\label{lem:helper-lemma}` |
| `prop:` | Proposition | `\label{prop:property}` |
| `cor:` | Corollary | `\label{cor:consequence}` |
| `eq:` | Equation | `\label{eq:main-equation}` |
| `sec:` | Section | `\label{sec:section-name}` |
| `tab:` | Table | `\label{tab:comparison}` |
| `fig:` | Figure | `\label{fig:diagram}` |

### Label Naming
- Use lowercase
- Hyphenate multi-word names
- Be descriptive but concise

```latex
\label{def:concept-name}        % Good
\label{def:cn}                   % Too abbreviated
\label{def:The_Concept_Name}     % Wrong style
```

## Reference Commands

### Standard References
```latex
% Basic reference
\ref{def:concept-name}          % Output: "1.1"

% With name (cleveref)
\cref{def:concept-name}         % Output: "Definition 1.1"
\Cref{def:concept-name}         % Output: "Definition 1.1" (at sentence start)

% Multiple references
\cref{def:frame,def:model}      % Output: "Definitions 1.1 and 1.2"
```

### Equation References
```latex
% Standard
\eqref{eq:main-equation}        % Output: "(3)"

% With cleveref
\cref{eq:main-equation}         % Output: "Equation (3)"
```

### Page References
```latex
\pageref{def:concept-name}      % Output: "12"
% Use sparingly - prefer section/definition references
```

## Cross-File References

### Source Code References
Define macros for referencing implementation code:
```latex
% Define in your notation package:
\newcommand{\srcref}[2]{\texttt{#1.#2}}
\newcommand{\fileref}[1]{\texttt{#1}}
```

### Usage Patterns

**After Definition**:
```latex
\begin{definition}[Concept Name]\label{def:concept-name}
...
\end{definition}

See \srcref{Module.Namespace}{ConceptName} for the implementation.
```

**Inline Reference**:
```latex
The evaluation function (\srcref{Core.Semantics}{evaluate})
determines the output value.
```

**File Reference**:
```latex
For the complete implementation, see \fileref{src/Core/Semantics.hs}.
```

### Source Reference Placement

Place source references at the **end of relevant sections** using the `\noindent` prefix for proper formatting.

**Rules**:
1. Use `\noindent` before source references to prevent indentation
2. Place after the final prose paragraph of the section
3. Include only when a relevant implementation exists
4. Reference the most specific definition/function, not entire modules

**Standard Pattern**:
```latex
\begin{definition}[Frame]\label{def:frame}
A \emph{frame} is a structure $\mathbf{F} = \langle W, R \rangle$...
\end{definition}

The frame captures the relational structure of worlds.
The relation $R$ represents accessibility.

\noindent\srcref{Foundation.Frame}{Frame}
```

## Bibliography References

### Citation Commands
```latex
\cite{author2020title}          % Standard citation
\cite[p.~42]{author2020title}   % With page number
\cite{author2020,other2021}     % Multiple citations
```

### Citation Placement
```latex
% At end of sentence
The theory is described in \cite{author2020title}.

% Mid-sentence
Following Author \cite{author2020title}, we define...
```

### BibTeX Entry Pattern
```bibtex
@article{author2020title,
  author = {Author, First},
  title = {Paper Title},
  journal = {Journal Name},
  year = {2020},
  pages = {1--20},
  publisher = {Publisher}
}
```

## Cross-Subfile References

### Referencing Other Subfiles
```latex
% In 03-Semantics.tex
As defined in \cref{def:frame} (see Section~\ref{sec:foundations}),
the frame provides...
```

### Forward References
```latex
% Reference to content defined later
The advanced features (see \cref{sec:extensions}) extend...
```

## Best Practices

### Do
- Label all definitions, theorems, and important equations
- Use cleveref (`\cref`) for automatic naming
- Include source code cross-references for implemented concepts
- Use descriptive label names

### Don't
- Over-label (skip trivial remarks)
- Use hard-coded numbers ("see Definition 3")
- Reference uncommitted code
- Use labels that might change meaning

## Example: Full Cross-Reference Flow

```latex
\section{Core Module}\label{sec:core}

\begin{definition}[Frame]\label{def:frame}
A \emph{frame} extends a base structure (\cref{def:base-structure})
with additional components.
\end{definition}

The frame (\cref{def:frame}) enables evaluation of complex
expressions. See \srcref{Core.Frame}{Frame} for the implementation.

\begin{theorem}[Soundness]\label{thm:soundness}
The principles P1--P6 (\cref{eq:p1,eq:p2,eq:p3,eq:p4,eq:p5,eq:p6}) are valid
in all frames.
\end{theorem}

This result follows from the theory developed in \cite{foundational2020}.
```
