# LaTeX Compilation Guide

## Quick Reference

### Full Build
```bash
cd Logos/LaTeX
pdflatex LogosReference.tex
bibtex LogosReference
pdflatex LogosReference.tex
pdflatex LogosReference.tex
```

### Subfile Only
```bash
cd Logos/latex/subfiles
pdflatex 01-ConstitutiveFoundation.tex
```

## Build Process

### Step 1: Initial Compilation
```bash
pdflatex LogosReference.tex
```
- Generates auxiliary files (.aux, .toc, .out)
- Cross-references will show as "??"

### Step 2: Bibliography
```bash
bibtex LogosReference
```
- Processes LogosReferences.bib
- Generates .bbl file
- Must run after first pdflatex

### Step 3: Resolve References
```bash
pdflatex LogosReference.tex
pdflatex LogosReference.tex
```
- Two runs to resolve all cross-references
- First run incorporates bibliography
- Second run finalizes TOC and references

## Automated Build

### Using latexmk
```bash
latexmk -pdf LogosReference.tex
```

### latexmk Configuration (.latexmkrc)
```perl
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';
$bibtex_use = 2;
```

### Clean Build
```bash
latexmk -C LogosReference.tex   # Full clean
latexmk -c LogosReference.tex   # Keep PDF
```

## Directory Structure

```
Logos/latex/
├── LogosReference.tex          # Main document
├── LogosReference.pdf          # Output (generated)
├── LogosReference.aux          # Auxiliary (generated)
├── LogosReference.log          # Log file (generated)
├── LogosReference.toc          # TOC (generated)
├── LogosReference.bbl          # Bibliography (generated)
├── subfiles/
│   ├── 00-Introduction.tex
│   ├── 01-ConstitutiveFoundation.tex
│   └── ...
├── assets/
│   ├── logos-notation.sty
│   ├── formatting.sty
│   └── bib_style.bst
└── bibliography/
    └── LogosReferences.bib
```

## Common Errors

### Undefined Control Sequence
```
! Undefined control sequence.
l.42 \statespace
```
**Cause**: logos-notation.sty not loaded
**Fix**: Add `\usepackage{assets/logos-notation}` to preamble

### Missing $ Inserted
```
! Missing $ inserted.
l.55 The frame F = ⟨S, ⊑⟩
```
**Cause**: Math mode not entered for formulas
**Fix**: Wrap in `$...$` or use `\frame = \langle \statespace, \parthood \rangle`

### Undefined Citation
```
LaTeX Warning: Citation 'fine2017' on page 3 undefined
```
**Cause**: BibTeX not run, or key missing from .bib
**Fix**: Run `bibtex LogosReference` and check key exists

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
pdflatex 01-ConstitutiveFoundation.tex
```

### How It Works
```latex
\documentclass[../LogosReference.tex]{subfiles}
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
grep -i "warning\|error" LogosReference.log
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
pdflatex LogosReference.tex
bibtex LogosReference
pdflatex LogosReference.tex
pdflatex LogosReference.tex
```

### Debug Mode
```bash
pdflatex -interaction=errorstopmode LogosReference.tex
```
Stops at first error for detailed inspection.

### Verbose Output
Check `LogosReference.log` for detailed error messages and line numbers.
