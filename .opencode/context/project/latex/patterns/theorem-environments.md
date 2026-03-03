# Theorem Environment Patterns

## Environment Definitions

### Standard amsthm Setup
```latex
% In preamble or formatting.sty
\theoremstyle{definition}
\newtheorem{definition}{Definition}[section]
\newtheorem{example}[definition]{Example}

\theoremstyle{plain}
\newtheorem{theorem}[definition]{Theorem}
\newtheorem{lemma}[definition]{Lemma}
\newtheorem{proposition}[definition]{Proposition}
\newtheorem{corollary}[definition]{Corollary}

\theoremstyle{remark}
\newtheorem{remark}[definition]{Remark}
\newtheorem{notation}[definition]{Notation}

% Custom environment for open questions
\newenvironment{question}
  {\begin{quote}\textsc{[Open Question]:}}
  {\end{quote}}
```

## Definition Environment

### Basic Definition
```latex
\begin{definition}[Constitutive Frame]
A \emph{constitutive frame} is a structure $\frame = \langle \statespace, \parthood \rangle$ where:
\begin{itemize}
  \item $\statespace$ is a nonempty set of states
  \item $\parthood$ is a partial order on $\statespace$ making $\langle \statespace, \parthood \rangle$ a complete lattice
\end{itemize}
\end{definition}
```

### Definition with Label
```latex
\begin{definition}[Core Frame]\label{def:core-frame}
A \emph{core frame} is a structure $\frame = \langle \statespace, \parthood, \temporalorder, \taskrel \rangle$ where:
\begin{itemize}
  \item $\langle \statespace, \parthood \rangle$ is a constitutive frame
  \item $\temporalorder = \langle D, +, \leq \rangle$ is a totally ordered abelian group
  \item $\taskrel$ is a ternary relation on $\statespace \times \temporalorder \times \statespace$
\end{itemize}
\end{definition}
```

### Definition with Multiple Parts
```latex
\begin{definition}[State Modality]
Let $\frame$ be a core frame. We define:
\begin{enumerate}
  \item A state $s$ is \emph{possible} ($s \in \possible$) iff $\task{s}{0}{s}$
  \item States $s, t$ are \emph{compatible} ($s \compatible t$) iff $\fusion{s}{t} \in \possible$
  \item A state $w$ is a \emph{world-state} ($w \in \worldstates$) iff $w$ is a maximal possible state
\end{enumerate}
\end{definition}
```

## Theorem Environment

### Theorem Statement
```latex
\begin{theorem}[Perpetuity Principles]\label{thm:perpetuity}
The task semantics validates:
\begin{align}
  \textbf{P1}: & \quad \nec\metaphi \to \alwaystemporal\metaphi \\
  \textbf{P2}: & \quad \sometimestemporal\metaphi \to \poss\metaphi \\
  \textbf{P3}: & \quad \nec\alwaystemporal\metaphi \leftrightarrow \alwaystemporal\nec\metaphi
\end{align}
\end{theorem}
```

### Theorem with Proof Reference
```latex
\begin{theorem}[Soundness]
If $\Gamma \vdash \metaphi$ then $\Gamma \satisfies \metaphi$.
\end{theorem}

See \leansrc{Logos.Core.Soundness}{soundness} for the Lean proof.
```

### Lean Cross-Reference in Theorem Environment

When a theorem has a corresponding Lean proof, include the Lean identifier directly in the theorem environment bracket using `\texttt{}`.
This pairs the LaTeX numbering with the Lean identifier inline, removing the need for footnote clutter.

**Preferred Pattern**:
```latex
\begin{theorem}[\texttt{soundness\_theorem}]\label{thm:soundness}
If $\Gamma \vdash \varphi$ then $\Gamma \models \varphi$.
\end{theorem}
```

**Deprecated Pattern** (acceptable for backwards compatibility):
```latex
\begin{theorem}[Soundness]\label{thm:soundness}
If $\Gamma \vdash \varphi$ then $\Gamma \models \varphi$.\footnote{%
  Lean: \texttt{Logos.Core.Soundness.soundness\_theorem}}
\end{theorem}
```

**Benefits of inline pattern**:
- Pairs LaTeX theorem number with Lean identifier visually
- Reduces footnote clutter in documents with many cross-references
- Makes the Lean name immediately visible in theorem statement

**Note**: Underscores in Lean names must be escaped as `\_` in LaTeX.

## Lemma and Proposition

```latex
\begin{lemma}[World-History Constraint]\label{lem:history-constraint}
For any world-history $\history : X \to \worldstates$, if $x, y \in X$ with $x \leq y$, then $\task{\history(x)}{y-x}{\history(y)}$.
\end{lemma}

\begin{proposition}[Bilateral Exclusivity]\label{prop:exclusive}
For any bilateral proposition $\langle V, F \rangle$, states in $V$ are incompatible with states in $F$.
\end{proposition}
```

## Remark Environment

### Clarifying Remark
```latex
\begin{remark}
The lattice structure provides:
\begin{itemize}
  \item \textbf{Null state} $\nullstate$: The bottom element
  \item \textbf{Full state} $\fullstate$: The top element
  \item \textbf{Fusion} $\fusion{s}{t}$: The least upper bound
\end{itemize}
\end{remark}
```

### Comparative Remark
```latex
\begin{remark}
Note the distinction between:
\begin{itemize}
  \item \emph{Grounding} ($\ground$): Timeless constitutive relation
  \item \emph{Causation}: Temporal productive relation (defined in future extension)
\end{itemize}
\end{remark}
```

## Notation Environment

```latex
\begin{notation}
We write $\task{s}{d}{t}$ (read: ``there is a task from $s$ to $t$ of duration $d$'').
\end{notation}

\begin{notation}
The set of all world-histories over $\frame$ is denoted $\historyspace$.
\end{notation}
```

## Example Environment

```latex
\begin{example}[Crimson and Red]
Consider the propositions:
\begin{itemize}
  \item $\metaA$ = ``Sam is crimson''
  \item $\metaB$ = ``Sam is red''
\end{itemize}
Then $\metaA \ground \metaB$ (being crimson grounds being red) because every verifier of $\metaA$ is a verifier of $\metaB$.
\end{example}
```

## Question Environment

For preserving open research questions from RECURSIVE_SEMANTICS.md:

```latex
\begin{question}
What is the exact structure of the credence function? Does it assign probabilities to individual state transitions or to sets of transitions?
\end{question}

\begin{question}
How do indicative conditionals relate to counterfactual conditionals in the semantic framework?
\end{question}
```

## Environment Usage Guidelines

| Environment | Use When |
|-------------|----------|
| `definition` | Introducing formal concepts |
| `theorem` | Stating proven results |
| `lemma` | Auxiliary results for proofs |
| `proposition` | Important but not central results |
| `corollary` | Immediate consequences |
| `remark` | Clarifications and intuitions |
| `notation` | Introducing new symbols |
| `example` | Concrete illustrations |
| `question` | Open research questions |

## Cross-Reference Pattern

```latex
\begin{definition}[World-History]\label{def:world-history}
...
\end{definition}

Later: By \cref{def:world-history}, world-histories assign world-states to times...

% Auto-generates: "By Definition 3.1, world-histories assign..."
```
