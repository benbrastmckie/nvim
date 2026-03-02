# LaTeX Theorem Environments

## Setup with amsthm

```latex
\usepackage{amsthm}

% Theorem-like (italic text)
\newtheorem{theorem}{Theorem}[section]
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{corollary}[theorem]{Corollary}
\newtheorem{proposition}[theorem]{Proposition}

% Definition-like (upright text)
\theoremstyle{definition}
\newtheorem{definition}[theorem]{Definition}
\newtheorem{example}[theorem]{Example}

% Remark-like (italic text, no numbering)
\theoremstyle{remark}
\newtheorem*{remark}{Remark}
\newtheorem*{note}{Note}
```

## Usage

### Basic Theorem
```latex
\begin{theorem}
Every vector space has a basis.
\end{theorem}
```

### Named Theorem
```latex
\begin{theorem}[Pythagorean]
In a right triangle, $a^2 + b^2 = c^2$.
\end{theorem}
```

### Labeled for Reference
```latex
\begin{theorem}[Completeness]\label{thm:completeness}
If $\Gamma \models \phi$, then $\Gamma \vdash \phi$.
\end{theorem}

By \cref{thm:completeness}, ...
```

## Proofs

```latex
\begin{proof}
We proceed by induction.
...
Therefore, the result holds.
\end{proof}

% Custom QED symbol
\begin{proof}[Proof Sketch]
The key idea is...
\end{proof}
```

## Custom Environments with thmtools

```latex
\usepackage{thmtools}

\declaretheorem[
  style=definition,
  name=Definition,
  numberwithin=section
]{definition}

\declaretheorem[
  style=plain,
  name=Theorem,
  sibling=definition
]{theorem}
```

## Label Conventions

| Prefix | Environment |
|--------|-------------|
| `def:` | Definition |
| `thm:` | Theorem |
| `lem:` | Lemma |
| `cor:` | Corollary |
| `prop:` | Proposition |
| `ex:` | Example |
