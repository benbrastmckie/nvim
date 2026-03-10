# LaTeX Document Structure Patterns

## Document Classes

### book
For longer documents with chapters.
```latex
\documentclass[11pt,a4paper]{book}
```

### article
For shorter documents with sections.
```latex
\documentclass[11pt,a4paper]{article}
```

### report
For technical reports, theses.
```latex
\documentclass[11pt,a4paper]{report}
```

## Basic Structure

```latex
\documentclass{article}

% Preamble: packages and settings
\usepackage{amsmath,amsthm,amssymb}
\usepackage{hyperref}

\title{Document Title}
\author{Author Name}
\date{\today}

\begin{document}
\maketitle
\tableofcontents

\section{Introduction}
Content...

\section{Main Content}
More content...

\bibliographystyle{plain}
\bibliography{references}

\end{document}
```

## Modular Documents with subfiles

For large documents, use the `subfiles` package:

### Main Document
```latex
% main.tex
\documentclass{book}
\usepackage{subfiles}

\begin{document}
\subfile{chapters/chapter1}
\subfile{chapters/chapter2}
\end{document}
```

### Subfile
```latex
% chapters/chapter1.tex
\documentclass[../main.tex]{subfiles}

\begin{document}
\chapter{First Chapter}
Content...
\end{document}
```

## Common Packages

| Package | Purpose |
|---------|---------|
| `amsmath` | Mathematical environments |
| `amsthm` | Theorem environments |
| `amssymb` | Mathematical symbols |
| `hyperref` | Hyperlinks and cross-refs |
| `cleveref` | Smart cross-references |
| `graphicx` | Images |
| `tikz` | Diagrams |
| `biblatex` | Modern bibliography |
