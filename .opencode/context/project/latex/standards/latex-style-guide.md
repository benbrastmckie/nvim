# LaTeX Style Guide

## Document Class

### Main Documents
```latex
\documentclass[11pt]{article}
```

### Subfiles
```latex
\documentclass[../MainDocument.tex]{subfiles}
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
\usepackage{assets/notation}    % Project-specific notation
\usepackage{assets/formatting}  % Document formatting
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
The box operator $\Box$ expresses necessity,
while the diamond operator $\Diamond$ expresses possibility.

These operators satisfy the duality $\Diamond \varphi \leftrightarrow \neg\Box\neg\varphi$.
```

### Fail Example
```latex
% Bad: Multiple sentences on one line, hard to diff
Modal logic extends classical logic with operators for necessity and possibility. The box operator $\Box$ expresses necessity, while the diamond operator $\Diamond$ expresses possibility. These operators satisfy the duality $\Diamond \varphi \leftrightarrow \neg\Box\neg\varphi$.
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

When referencing theorems by name (e.g., Soundness Theorem, Lindenbaum's Lemma), use consistent formatting across prose, environments, and code references.

| Context | Format | Example |
|---------|--------|---------|
| Prose reference | *Italics* | the *Soundness Theorem* states... |
| Environment name | Normal (in brackets) | `\begin{theorem}[Soundness]` |
| Code reference | `\texttt{}` | `\texttt{soundness\_theorem}` |

**Note**: Underscores must be escaped as `\_` in LaTeX.

### Definition Ordering

Definitions must appear before their first use in prose.
When introducing new concepts, place the formal definition environment before explanatory text that references the defined term.

### Pass Example
```latex
\begin{definition}[Frame]\label{def:frame}
A \emph{frame} is a structure $\mathbf{F} = \langle W, R \rangle$...
\end{definition}

A frame captures the relational structure of possible worlds.
The relation $R$ represents accessibility.
```

### Fail Example
```latex
% Bad: Using term before defining it
A frame captures the relational structure of possible worlds.
The relation $R$ represents accessibility.

\begin{definition}[Frame]  % Definition comes too late
```

## Set Notation

### The \set{} Macro

Use a `\set{}` macro for set notation instead of raw `\{ \}` braces.

**Rationale**:
1. **Consistency**: Ensures uniform set notation across all documents
2. **Maintainability**: Allows global styling changes from one location
3. **Readability**: Source code is cleaner without escaped braces
4. **Semantics**: Distinguishes set braces from other brace usages

### Pass Example
```latex
% Good: Using \set{} macro
The set of elements $\set{x \in S \mid P(x)}$ forms a subset.
Let $\set{a, b, c}$ be the collection.
```

### Fail Example
```latex
% Bad: Raw escaped braces
The set of elements $\{ x \in S \mid P(x) \}$ forms a subset.
Let $\{ a, b, c \}$ be the collection.
```

## File Organization

### Main Document Structure
```
MainDocument.tex            % Main document
├── subfiles/               % Content subfiles
│   ├── 00-Introduction.tex
│   ├── 01-Foundations.tex
│   └── ...
├── assets/                 % Style files
│   ├── notation.sty
│   └── formatting.sty
└── bibliography/           % Bibliography
    └── references.bib
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
\begin{definition}[Frame]
A \emph{frame} is a structure $\mathbf{F} = \langle W, R \rangle$ where:
\begin{itemize}
  \item $W$ is a nonempty set of \emph{worlds}
  \item $R$ is a binary relation on $W$ (accessibility)
\end{itemize}
\end{definition}
```

### Fail Example
```latex
% Bad: No environment, poor formatting
A frame is F = <W, R> where W is worlds and R is a relation.
```

## Writing Quality Standards

### Tone Guidelines

**Direct professional tone**: Write in a mathematically mature voice. Avoid grandiose verbiage, unnecessary qualifiers, and inflated language. Let the mathematics speak for itself.

**No bold for emphasis**: Never use `\textbf{}` for emphasis in prose. Reserve bold for structural elements (section headers, definition terms in specific contexts). Use *italics* for defined terms when first introduced.

**Concise writing**: Include only interesting and important points. Omit trivial observations, obvious statements, and filler content.

### Organization Guidelines

**Remarks follow technical content**: Remarks should follow (not precede) the definitions, theorems, or technical content they illuminate.

**Show, don't tell**: Avoid trivial announcements like "We now define X" or "The following theorem establishes Y." Proceed directly to the definition or theorem.

## Prose Conventions

### Em-Dash Spacing

**Rule**: When using em-dashes (triple dashes `---`), always follow them with a space.

**Correct**:
```latex
The formalism provides a foundation--- one that captures the essence.
```

**Incorrect**:
```latex
The formalism provides a foundation---one that captures the essence.
```

### No Rhetorical Questions

**Rule**: Do not use rhetorical questions in prose. Rephrase as declarative statements.

**Incorrect**:
```latex
Why do we need this construction? Consider the following...
```

**Correct**:
```latex
The need for this construction becomes clear when we consider...
```

## Validation Checklist

- [ ] One sentence per line (semantic linefeeds)
- [ ] All packages imported in preamble
- [ ] Custom notation macros used consistently
- [ ] Environments properly opened and closed
- [ ] Cross-references resolve without warnings
- [ ] No overfull hboxes in compiled output
- [ ] Named theorems use italics in prose, normal text in environment brackets
- [ ] Definitions appear before first use in prose
- [ ] Use `\set{}` macro for set notation (not `\{ \}`)
- [ ] Source code references placed at end of sections with `\noindent`
