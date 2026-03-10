# LaTeX Compilation Guide

## Quick Reference

### Full Build
```bash
cd project/latex
pdflatex MainDocument.tex
bibtex MainDocument
pdflatex MainDocument.tex
pdflatex MainDocument.tex
```

### Subfile Only
```bash
cd project/latex/subfiles
pdflatex 01-Foundations.tex
```

## Build Process

### Step 1: Initial Compilation
```bash
pdflatex MainDocument.tex
```
- Generates auxiliary files (.aux, .toc, .out)
- Cross-references will show as "??"

### Step 2: Bibliography
```bash
bibtex MainDocument
```
- Processes references.bib
- Generates .bbl file
- Must run after first pdflatex

### Step 3: Resolve References
```bash
pdflatex MainDocument.tex
pdflatex MainDocument.tex
```
- Two runs to resolve all cross-references
- First run incorporates bibliography
- Second run finalizes TOC and references

## Automated Build

### Using latexmk
```bash
latexmk -pdf MainDocument.tex
```

### latexmk Configuration (.latexmkrc)
```perl
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';
$bibtex_use = 2;
```

### Clean Build
```bash
latexmk -C MainDocument.tex   # Full clean
latexmk -c MainDocument.tex   # Keep PDF
```

## Directory Structure

```
project/latex/
├── MainDocument.tex          # Main document
├── MainDocument.pdf          # Output (generated)
├── MainDocument.aux          # Auxiliary (generated)
├── MainDocument.log          # Log file (generated)
├── MainDocument.toc          # TOC (generated)
├── MainDocument.bbl          # Bibliography (generated)
├── subfiles/
│   ├── 00-Introduction.tex
│   ├── 01-Foundations.tex
│   └── ...
├── assets/
│   ├── notation.sty
│   ├── formatting.sty
│   └── bib_style.bst
└── bibliography/
    └── references.bib
```

## Common Errors

### Undefined Control Sequence
```
! Undefined control sequence.
l.42 \customcommand
```
**Cause**: Custom macro not loaded
**Fix**: Add `\usepackage{assets/notation}` to preamble

### Missing $ Inserted
```
! Missing $ inserted.
l.55 The frame F = <W, R>
```
**Cause**: Math mode not entered for formulas
**Fix**: Wrap in `$...$` or use `\tuple{W, R}`

### Undefined Citation
```
LaTeX Warning: Citation 'author2020' on page 3 undefined
```
**Cause**: BibTeX not run, or key missing from .bib
**Fix**: Run `bibtex MainDocument` and check key exists

### Overfull Hbox
```
Overfull \hbox (15.2pt too wide) in paragraph at lines 42--45
```
**Cause**: Line too long
**Fix**: Break equation with `align` environment or reword text

### Package Not Found
```
! LaTeX Error: File 'stmaryrd.sty' not found.
```
**Cause**: Package not installed
**Fix**: Install via TeX distribution (e.g., `tlmgr install stmaryrd`)

## Subfile Compilation

### Standalone Testing
Each subfile can compile independently:
```bash
cd subfiles
pdflatex 01-Foundations.tex
```

### How It Works
```latex
\documentclass[../MainDocument.tex]{subfiles}
```
- Inherits preamble from main document
- Uses same packages and macros
- Standalone output for quick testing

### Subfile Limitations
- Bibliography references may not resolve standalone
- Cross-references to other subfiles won't work
- Use main document for final output

## Output Verification

### Check PDF
1. Open generated PDF
2. Verify TOC links work
3. Check cross-references resolved (no "??")
4. Verify bibliography appears
5. Check mathematical formatting

### Log File Review
```bash
grep -i "warning\|error" MainDocument.log
```

### Common Warnings to Address
- `Label ... multiply defined` - duplicate labels
- `Reference ... undefined` - missing label
- `Overfull \hbox` - line breaking issues

### Acceptable Warnings
- `Underfull \hbox` - minor, usually ignorable
- Font substitution warnings - if output looks correct

## Required Packages

### Core (usually pre-installed)
- amsmath
- amsthm
- amssymb

### Additional (may need installation)
- stmaryrd (semantic brackets)
- subfiles (modular documents)
- hyperref (links)
- cleveref (smart references)
- booktabs (tables)

### Install via tlmgr
```bash
tlmgr install stmaryrd subfiles cleveref booktabs
```

## Troubleshooting

### Fresh Start
```bash
rm -f *.aux *.log *.toc *.out *.bbl *.blg
pdflatex MainDocument.tex
bibtex MainDocument
pdflatex MainDocument.tex
pdflatex MainDocument.tex
```

### Debug Mode
```bash
pdflatex -interaction=errorstopmode MainDocument.tex
```
Stops at first error for detailed inspection.

### Verbose Output
Check `MainDocument.log` for detailed error messages and line numbers.

## Continuous Compilation

### Using latexmk with Preview
```bash
latexmk -pdf -pvc MainDocument.tex
```
- `-pvc`: Preview continuously, recompile on changes
- Works well with PDF viewers that auto-refresh

### Editor Integration

Most LaTeX editors (TeXstudio, VS Code with LaTeX Workshop, Neovim with VimTeX) provide:
- Build on save
- Forward/inverse search between source and PDF
- Error highlighting in source

## Build Scripts

### Makefile Example
```makefile
MAIN = MainDocument

.PHONY: all clean

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex subfiles/*.tex
	pdflatex $(MAIN).tex
	bibtex $(MAIN)
	pdflatex $(MAIN).tex
	pdflatex $(MAIN).tex

clean:
	rm -f *.aux *.log *.toc *.out *.bbl *.blg *.pdf
```

### Usage
```bash
make        # Build PDF
make clean  # Remove generated files
```
