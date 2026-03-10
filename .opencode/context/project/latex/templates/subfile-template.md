# Subfile Template

## Standard Subfile Boilerplate

```latex
\documentclass[../MainDocument.tex]{subfiles}
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

See \srcref{{Module.Name}}{{definition_name}} for the implementation.

% ------------------------------------------------------------
% Subsection 2
% ------------------------------------------------------------

\subsection{{Another Subsection}}

{Content continues...}

\end{document}
```

## Filled Example: Foundations

```latex
\documentclass[../MainDocument.tex]{subfiles}
\begin{document}

% ============================================================
% Section: Foundations
% ============================================================

\section{Foundations}

The Foundations section provides the core semantic structure.
Evaluation is based on standard model-theoretic semantics.

% ------------------------------------------------------------
% Basic Structures
% ------------------------------------------------------------

\subsection{Basic Structures}

The foundational layer interprets the following primitives:

\begin{itemize}
  \item \textbf{Variables}: $v_1, v_2, v_3, \ldots$
  \item \textbf{Constants}: $a, b, c, \ldots$
  \item \textbf{Function symbols}: $f, g, h, \ldots$
  \item \textbf{Predicates}: $P, Q, R, \ldots$
  \item \textbf{Logical connectives}: $\neg, \land, \lor, \to$
\end{itemize}

% ------------------------------------------------------------
% Frame Definition
% ------------------------------------------------------------

\subsection{Frame Definition}

\begin{definition}[Frame]\label{def:frame}
A \emph{frame} is a structure $\mathbf{F} = \tuple{W, R}$ where:
\begin{itemize}
  \item $W$ is a nonempty set of \emph{worlds}
  \item $R$ is a binary relation on $W$ (accessibility relation)
\end{itemize}
\end{definition}

\begin{remark}
The frame structure provides:
\begin{itemize}
  \item \textbf{Possible worlds}: Elements of $W$ represent possible states
  \item \textbf{Accessibility}: The relation $R$ determines modal truth
\end{itemize}
\end{remark}

See \srcref{Foundation.Frame}{Frame} for the implementation.

\end{document}
```

## Extension Stub Template

For sections with placeholder content:

```latex
\documentclass[../MainDocument.tex]{subfiles}
\begin{document}

% ============================================================
% Section: {Extension Name}
% ============================================================

\section{{Extension Name}}

\textsc{[Details pending development]}

The {Extension Name} section extends the core structure with {brief description}.

% ------------------------------------------------------------
% Extended Frame
% ------------------------------------------------------------

\subsection{Extended Frame}

\textsc{[Details pending development]}

{Brief description of frame extension.}

\begin{question}
{Open research question}
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

## Theorem Environment Template

```latex
\begin{theorem}[{Theorem Name}]\label{thm:{theorem-label}}
{Theorem statement}
\end{theorem}

\begin{proof}
{Proof content}
\end{proof}

\begin{corollary}\label{cor:{corollary-label}}
{Corollary statement}
\end{corollary}
```

## Lemma with Proof Template

```latex
\begin{lemma}[{Lemma Name}]\label{lem:{lemma-label}}
{Lemma statement}
\end{lemma}

\begin{proof}
We proceed by {induction/cases/contradiction}.

\textbf{Base case}: {Base case proof}

\textbf{Inductive step}: {Inductive step proof}

Thus, {conclusion}.
\end{proof}
```

## Checklist for New Subfiles

- [ ] Document class is `[../MainDocument.tex]{subfiles}`
- [ ] Section title matches filename convention
- [ ] All definitions have labels with `def:` prefix
- [ ] All theorems have labels with `thm:` prefix
- [ ] Remarks follow definitions for clarification
- [ ] Cross-references included where applicable
- [ ] Custom notation macros used (not raw symbols)
- [ ] Compiles standalone with `pdflatex`
