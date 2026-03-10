# Document Structure Standards

## Main Document Layout

### Standard Main Document Structure
```latex
\documentclass[11pt]{article}

% ============================================================
% Packages
% ============================================================
\usepackage{amsmath}
\usepackage{amsthm}
\usepackage{amssymb}
\usepackage{stmaryrd}
\usepackage{subfiles}
\usepackage{hyperref}
\usepackage{cleveref}

% Custom packages
\usepackage{assets/notation}
\usepackage{assets/formatting}

% ============================================================
% Document Info
% ============================================================
\title{Document Title}
\author{Author Name}
\date{\today}

% ============================================================
% Begin Document
% ============================================================
\begin{document}

\maketitle
\tableofcontents
\newpage

% ============================================================
% Main Content
% ============================================================
\subfile{subfiles/00-Introduction}
\subfile{subfiles/01-Foundations}

% ============================================================
% Additional Sections
% ============================================================
\subfile{subfiles/02-Section-One}
\subfile{subfiles/03-Section-Two}

% ============================================================
% Back Matter
% ============================================================
\bibliographystyle{assets/bib_style}
\bibliography{bibliography/references}

\end{document}
```

## Subfile Structure

### Standard Subfile Template
```latex
\documentclass[../MainDocument.tex]{subfiles}
\begin{document}

\section{Section Title}

% Content here

\end{document}
```

### Section Hierarchy
```
\section{Major Division}           % Level 1
  \subsection{Sub-topic}           % Level 2
    \subsubsection{Detail}         % Level 3
      \paragraph{Fine point}       % Level 4 (rare)
```

## Subfile Naming Convention

### Numbering Scheme
```
00-Introduction.tex              % Overview
01-Foundations.tex               % Foundational concepts
02-MainTopic-Part1.tex           % Main content part 1
03-MainTopic-Part2.tex           % Main content part 2
04-Extensions.tex                % Additional material
05-Appendices.tex                % Appendices
```

### Naming Rules
- Two-digit prefix for ordering
- CamelCase descriptive name
- Hyphen to separate multi-part names
- `.tex` extension

## Content Organization

### Section Content Flow
1. **Introduction paragraph**: Brief overview of section purpose
2. **Definitions**: Formal definitions using `definition` environment
3. **Remarks**: Clarifying notes using `remark` environment
4. **Examples**: Illustrative cases (when helpful)
5. **Cross-references**: Links to related sections and implementation code

### Subsection Guidelines
- Each subsection should be self-contained
- Start with context for the concept
- Provide formal definition
- Add remarks for intuition
- Reference implementation when available

## Front Matter

### Title Page
- Document title
- Author name
- Date (using `\today` for updates)

### Table of Contents
- Generated automatically
- Page break after TOC

## Back Matter

### Bibliography
- BibTeX format in `bibliography/references.bib`
- Cite using `\cite{key}`
- Custom style file if needed

### Index (Optional)
- Add `\usepackage{makeidx}` if needed
- Use `\index{term}` for entries

## Cross-References

### Internal References
```latex
\label{def:concept-name}           % Label definitions
\label{thm:theorem-name}           % Label theorems
\label{eq:equation-name}           % Label equations

\cref{def:concept-name}            % Reference with auto-naming
```

### External References
```latex
\srcref{Module.Namespace}{Definition}    % Source code reference
\cite{author2020paper}                   % Bibliography reference
```

## Compilation Order

### Standard Build
```bash
cd project/latex
pdflatex MainDocument.tex
bibtex MainDocument
pdflatex MainDocument.tex
pdflatex MainDocument.tex
```

### With Subfile Changes
Individual subfiles can be compiled standalone for testing:
```bash
cd subfiles
pdflatex 01-Foundations.tex
```

## Directory Structure

```
project/latex/
├── MainDocument.tex          # Main document
├── MainDocument.pdf          # Output (generated)
├── subfiles/
│   ├── 00-Introduction.tex
│   ├── 01-Foundations.tex
│   └── ...
├── assets/
│   ├── notation.sty
│   └── formatting.sty
└── bibliography/
    └── references.bib
```
