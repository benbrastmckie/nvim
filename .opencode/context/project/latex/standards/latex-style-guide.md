# LaTeX Style Guide

## Document Class

### Main Documents
```latex
\documentclass[11pt]{article}
```

### Subfiles
```latex
\documentclass[../LogosReference.tex]{subfiles}
```

## Required Packages

### Core Packages
```latex
\usepackage{amsmath}       % Mathematical typesetting
\usepackage{amsthm}        % Theorem environments
\usepackage{amssymb}       % Mathematical symbols
\usepackage{stmaryrd}      % Semantic brackets \llbracket \rrbracket
\usepackage{subfiles}      % Modular document structure
```

### Formatting Packages
```latex
\usepackage{hyperref}      % Cross-references and links
\usepackage{cleveref}      % Smart cross-references
\usepackage{enumitem}      % List customization
\usepackage{booktabs}      % Professional tables
\usepackage{array}         % Table column formatting
```

### Custom Packages
```latex
\usepackage{assets/logos-notation}  % Logos-specific notation
\usepackage{assets/formatting}      % Document formatting
```

## Formatting Rules

### Line Length
- Source lines: 100 characters maximum
- Break long equations using `align` environment

### Indentation
- Use 2 spaces for LaTeX source indentation
- Align `&` in multi-line equations

### Spacing
- One blank line between paragraphs
- Two blank lines before `\section`
- One blank line before `\subsection`

### Comments
```latex
% Single-line comment for brief notes

% -----------------------------------------------------
% Section comments for major divisions
% -----------------------------------------------------
```

## Source File Formatting

### Semantic Linefeeds

Use **one sentence per line** in LaTeX source files.
This convention, also called "semantic linefeeds," was documented by Brian Kernighan in 1974 and remains a best practice for technical writing.

**Rationale**:
1. **Version control**: Git diffs show only changed sentences, not entire paragraphs
2. **Editor efficiency**: Text editors manipulate lines easily; sentences become natural units
3. **Review clarity**: Pull request reviews can comment on specific sentences
4. **No output impact**: LaTeX ignores single line breaks in compiled output

**Rules**:
1. Each sentence starts on a new line
2. A period (or other sentence-ending punctuation) is always followed by a line break
3. Long sentences may break at natural clause boundaries (after commas, semicolons, or conjunctions)
4. Do not use automatic line wrapping/reflow
5. Preserve protected spaces before citations: `text~\cite{foo}`

### Pass Example
```latex
Modal logic extends classical logic with operators for necessity and possibility.
The box operator $\nec$ expresses metaphysical necessity,
while the diamond operator $\pos$ expresses possibility.

These operators satisfy the duality $\pos \varphi \leftrightarrow \neg\nec\neg\varphi$.
```

### Fail Example
```latex
% Bad: Multiple sentences on one line, hard to diff
Modal logic extends classical logic with operators for necessity and possibility. The box operator $\nec$ expresses metaphysical necessity, while the diamond operator $\pos$ expresses possibility. These operators satisfy the duality $\pos \varphi \leftrightarrow \neg\nec\neg\varphi$.
```

### Long Sentence Guidelines

Break long sentences at natural clause boundaries:

```latex
% Good: Breaks at clause boundary (after comma)
The canonical model construction proceeds by first extending the consistent set
to a maximal consistent set,
then defining the accessibility relation via modal witnesses.

% Good: Break at conjunction
A frame is reflexive if every world accesses itself,
and transitive if accessibility composes.
```

## Theorem and Definition Naming

### Named Theorem Formatting

When referencing theorems by name (e.g., Soundness Theorem, Lindenbaum's Lemma), use consistent formatting across prose, environments, and Lean cross-references.

| Context | Format | Example |
|---------|--------|---------|
| Prose reference | *Italics* | the *Soundness Theorem* states... |
| Environment name | Normal (in brackets) | `\begin{theorem}[Soundness]` |
| Lean reference | `\texttt{}` | `\texttt{soundness\_theorem}` |

**Note**: Lean names containing underscores must be escaped as `\_` in LaTeX.

### Pass Example
```latex
The \emph{Soundness Theorem} establishes that provable formulas are valid.

\begin{theorem}[Soundness]\label{thm:soundness}
If $\Gamma \vdash \varphi$ then $\Gamma \models \varphi$.
\end{theorem}

See \texttt{Logos.Core.Soundness.soundness\_theorem} for the Lean proof.
```

### Fail Example
```latex
% Bad: Inconsistent formatting
The Soundness Theorem establishes that provable formulas are valid.
\begin{theorem}[\emph{Soundness}]  % Wrong: italics inside bracket
```

### Definition Ordering

Definitions must appear before their first use in prose.
When introducing new concepts, place the formal definition environment before explanatory text that references the defined term.

**Rationale**: Readers should encounter the formal definition before informal explanations that assume familiarity with it.

### Pass Example
```latex
\begin{definition}[Constitutive Frame]\label{def:constitutive-frame}
A \emph{constitutive frame} is a structure $\mathbf{F} = \langle S, \sqsubseteq \rangle$...
\end{definition}

A constitutive frame captures the mereological structure of states.
The partial order $\sqsubseteq$ represents the parthood relation.
```

### Fail Example
```latex
% Bad: Using term before defining it
A constitutive frame captures the mereological structure of states.
The partial order $\sqsubseteq$ represents the parthood relation.

\begin{definition}[Constitutive Frame]  % Definition comes too late
```

## File Organization

### Main Document Structure
```
LogosReference.tex          % Main document
├── subfiles/               % Content subfiles
│   ├── 00-Introduction.tex
│   ├── 01-ConstitutiveFoundation.tex
│   └── ...
├── assets/                 % Style files
│   ├── logos-notation.sty
│   └── formatting.sty
└── bibliography/           % Bibliography
    └── LogosReferences.bib
```

### Subfile Naming Convention
```
{NN}-{Section-Name}.tex
```
- NN: Two-digit sequence number
- Section-Name: CamelCase description

## Code Quality

### Pass Example
```latex
\begin{definition}[Constitutive Frame]
A \emph{constitutive frame} is a structure $\mathbf{F} = \langle S, \sqsubseteq \rangle$ where:
\begin{itemize}
  \item $S$ is a nonempty set of \emph{states}
  \item $\sqsubseteq$ is a partial order on $S$
\end{itemize}
\end{definition}
```

### Fail Example
```latex
% Bad: No environment, poor formatting
A constitutive frame is F = <S, ⊑> where S is states and ⊑ is partial order.
```

## Validation Checklist

- [ ] One sentence per line (semantic linefeeds)
- [ ] All packages imported in preamble
- [ ] logos-notation.sty macros used consistently
- [ ] Environments properly opened and closed
- [ ] Cross-references resolve without warnings
- [ ] No overfull hboxes in compiled output
- [ ] Named theorems use italics in prose, normal text in environment brackets
- [ ] Definitions appear before first use in prose
