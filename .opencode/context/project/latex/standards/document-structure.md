# Document Structure Standards

## Main Document Layout

### LogosReference.tex Structure
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
\usepackage{assets/logos-notation}
\usepackage{assets/formatting}

% ============================================================
% Document Info
% ============================================================
\title{Logos: A Reference Manual}
\author{Benjamin Brast-McKie}
\date{\today}

% ============================================================
% Begin Document
% ============================================================
\begin{document}

\maketitle
\tableofcontents
\newpage

% ============================================================
% Foundation Layer
% ============================================================
\subfile{subfiles/00-Introduction}
\subfile{subfiles/01-ConstitutiveFoundation}

% ============================================================
% Core Extension
% ============================================================
\subfile{subfiles/02-CoreExtension-Syntax}
\subfile{subfiles/03-CoreExtension-Semantics}
\subfile{subfiles/04-CoreExtension-Axioms}

% ============================================================
% Future Extensions (uncomment when developed)
% ============================================================
% \subfile{subfiles/05-Epistemic}
% \subfile{subfiles/06-Normative}
% \subfile{subfiles/07-Spatial}
% \subfile{subfiles/08-Agential}

% ============================================================
% Back Matter
% ============================================================
\bibliographystyle{assets/bib_style}
\bibliography{bibliography/LogosReferences}

\end{document}
```

## Subfile Structure

### Standard Subfile Template
```latex
\documentclass[../LogosReference.tex]{subfiles}
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
01-ConstitutiveFoundation.tex    % Foundation layer
02-CoreExtension-Syntax.tex      % Core syntax
03-CoreExtension-Semantics.tex   % Core semantics
04-CoreExtension-Axioms.tex      % Core axiom system
05-Epistemic.tex                 % Epistemic extension
06-Normative.tex                 % Normative extension
07-Spatial.tex                   % Spatial extension
08-Agential.tex                  % Agential extension
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
5. **Cross-references**: Links to related sections and Lean code

### Subsection Guidelines
- Each subsection should be self-contained
- Start with context for the concept
- Provide formal definition
- Add remarks for intuition
- Reference Lean implementation

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
- BibTeX format in `bibliography/LogosReferences.bib`
- Cite using `\cite{key}`
- Style: custom bib_style.bst

### Index (Optional)
- Add `\usepackage{makeidx}` if needed
- Use `\index{term}` for entries

## Cross-References

### Internal References
```latex
\label{def:constitutive-frame}     % Label definitions
\label{thm:perpetuity-1}           % Label theorems
\label{eq:verification}            % Label equations

\cref{def:constitutive-frame}      % Reference with auto-naming
```

### External References
```latex
\leansrc{Logos.Foundation.Frame}{ConstitutiveFrame}  % Lean code
\cite{fine2017truthmaker}                             % Bibliography
```

## Compilation Order

### Standard Build
```bash
pdflatex LogosReference.tex
bibtex LogosReference
pdflatex LogosReference.tex
pdflatex LogosReference.tex
```

### With Subfile Changes
Individual subfiles can be compiled standalone for testing:
```bash
cd subfiles
pdflatex 01-ConstitutiveFoundation.tex
```
