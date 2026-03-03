# Subfile Template

## Standard Subfile Boilerplate

```latex
\documentclass[../LogosReference.tex]{subfiles}
\begin{document}

% ============================================================
% Section: {SECTION_NAME}
% ============================================================

\section{{Section Title}}

{Introductory paragraph explaining the purpose and scope of this section.}

% ------------------------------------------------------------
% Subsection 1
% ------------------------------------------------------------

\subsection{{Subsection Title}}

\begin{definition}[{Concept Name}]\label{def:{concept-label}}
{Definition content}
\end{definition}

\begin{remark}
{Clarifying remarks}
\end{remark}

See \leansrc{{Lean.Module}}{{definition_name}} for the Lean implementation.

% ------------------------------------------------------------
% Subsection 2
% ------------------------------------------------------------

\subsection{{Another Subsection}}

{Content continues...}

\end{document}
```

## Filled Example: Constitutive Foundation

```latex
\documentclass[../LogosReference.tex]{subfiles}
\begin{document}

% ============================================================
% Section: Constitutive Foundation
% ============================================================

\section{Constitutive Foundation}

The Constitutive Foundation provides the foundational semantic structure based on exact truthmaker semantics. Evaluation is hyperintensional, distinguishing propositions that agree on truth-value across all possible worlds but differ in their exact verification and falsification conditions.

% ------------------------------------------------------------
% Syntactic Primitives
% ------------------------------------------------------------

\subsection{Syntactic Primitives}

The Constitutive Foundation interprets the following syntactic primitives:

\begin{itemize}
  \item \textbf{Variables}: $x, y, z, \ldots$ (ranging over states)
  \item \textbf{Individual constants}: $a, b, c, \ldots$ (0-place function symbols)
  \item \textbf{n-place function symbols}: $f, g, h, \ldots$
  \item \textbf{n-place predicates}: $F, G, H, \ldots$
  \item \textbf{Sentence letters}: $p, q, r, \ldots$ (0-place predicates)
  \item \textbf{Lambda abstraction}: $\lambda x.A$ (binding variable $x$ in formula $A$)
  \item \textbf{Logical connectives}: $\neg, \land, \lor, \top, \bot, \propid$
\end{itemize}

% ------------------------------------------------------------
% Constitutive Frame
% ------------------------------------------------------------

\subsection{Constitutive Frame}

\begin{definition}[Constitutive Frame]\label{def:constitutive-frame}
A \emph{constitutive frame} is a structure $\frame = \langle \statespace, \parthood \rangle$ where:
\begin{itemize}
  \item $\statespace$ is a nonempty set of \emph{states}
  \item $\parthood$ is a partial order on $\statespace$ making $\langle \statespace, \parthood \rangle$ a complete lattice
\end{itemize}
\end{definition}

\begin{remark}
The lattice structure provides:
\begin{itemize}
  \item \textbf{Null state} $\nullstate$: The bottom element (fusion of the empty set)
  \item \textbf{Full state} $\fullstate$: The top element (fusion of all states)
  \item \textbf{Fusion} $\fusion{s}{t}$: The least upper bound of $s$ and $t$
\end{itemize}
\end{remark}

See \leansrc{Logos.Foundation.Frame}{ConstitutiveFrame} for the Lean implementation.

\end{document}
```

## Extension Stub Template

For extensions with placeholder content:

```latex
\documentclass[../LogosReference.tex]{subfiles}
\begin{document}

% ============================================================
% Section: {Extension Name} Extension
% ============================================================

\section{{Extension Name} Extension}

\textsc{[Details pending development]}

The {Extension Name} Extension extends the Core Extension with structures for {brief description}.

% ------------------------------------------------------------
% Frame Extension
% ------------------------------------------------------------

\subsection{Frame Extension}

\textsc{[Details pending development]}

{Brief description of frame extension.}

\begin{question}
{Open research question from RECURSIVE_SEMANTICS.md}
\end{question}

% ------------------------------------------------------------
% Operators
% ------------------------------------------------------------

\subsection{Operators}

\begin{tabular}{ll}
\toprule
\textbf{Operator} & \textbf{Intended Reading} \\
\midrule
{$Op_1$} & {Reading 1} \\
{$Op_2$} & {Reading 2} \\
\bottomrule
\end{tabular}

\textsc{[Full semantic clauses pending specification]}

\end{document}
```

## Checklist for New Subfiles

- [ ] Document class is `[../LogosReference.tex]{subfiles}`
- [ ] Section title matches filename convention
- [ ] All definitions have labels with `def:` prefix
- [ ] Remarks follow definitions for clarification
- [ ] Lean cross-references included where applicable
- [ ] logos-notation.sty macros used (not raw symbols)
- [ ] Compiles standalone with `pdflatex`
