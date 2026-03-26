# Filetypes Conversion Tables

## Document Conversions (via /convert)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| PDF | Markdown | markitdown | pandoc |
| DOCX | Markdown | markitdown | pandoc |
| HTML | Markdown | markitdown | pandoc |
| Images | Markdown | markitdown | - |
| Markdown | PDF | pandoc | typst |

## Spreadsheet Conversions (via /table)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| XLSX | LaTeX table | pandas + openpyxl | xlsx2csv |
| XLSX | Typst table | pandas -> CSV -> Typst csv() | xlsx2csv |
| CSV | LaTeX table | pandas | manual |
| CSV | Typst table | Typst csv() | manual |
| ODS | LaTeX/Typst table | pandas | - |

## Presentation Conversions (via /slides)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| PPTX | Beamer | python-pptx + pandoc | markitdown |
| PPTX | Polylux (Typst) | python-pptx | markitdown |
| PPTX | Touying (Typst) | python-pptx | markitdown |
| Markdown | PPTX | pandoc | - |

## PDF Annotation Extraction (via /scrape)

| Source | Output Format | Primary Tool | Fallback 1 | Fallback 2 |
|--------|---------------|--------------|------------|------------|
| PDF    | Markdown      | PyMuPDF      | pypdf      | pdfannots  |
| PDF    | JSON          | PyMuPDF      | pypdf      | pdfannots  |

Supported annotation types: highlight, note, underline, strikeout, freetext, stamp, ink

## Command Usage Examples

```bash
# Document conversion (format inferred)
/convert document.pdf                    # -> document.md
/convert report.docx notes.md            # -> notes.md
/convert README.md README.pdf            # -> README.pdf

# Spreadsheet to table
/table data.xlsx                         # -> data.tex (LaTeX)
/table data.xlsx output.typ --format typst
/table budget.csv budget.tex --format latex

# Presentation conversion
/slides presentation.pptx                # -> presentation.tex (Beamer)
/slides deck.pptx slides.typ --format polylux
/slides talk.pptx talk.typ --format touying

# PDF annotation extraction
/scrape paper.pdf                              # -> paper_annotations.md
/scrape paper.pdf notes.md                     # -> notes.md
/scrape paper.pdf --format json                # -> paper_annotations.md (JSON)
/scrape paper.pdf --types highlight,note       # -> only highlights and notes
```

## Prerequisites

Install conversion tools based on your needs:

**Document Conversion**:
- `markitdown`: `pip install markitdown`
- `pandoc`: Install from package manager
- `typst`: Install for Typst output

**Spreadsheet Conversion**:
- `pandas`: `pip install pandas`
- `openpyxl`: `pip install openpyxl` (for XLSX support)
- `xlsx2csv`: `pip install xlsx2csv` (fallback)

**Presentation Conversion**:
- `python-pptx`: `pip install python-pptx`
- `pandoc`: For Beamer output

**PDF Annotation Extraction**:
- `pymupdf`: `pip install pymupdf` (recommended, best annotation coverage)
- `pypdf`: `pip install pypdf` (pure Python fallback)
- `pdfannots`: `pip install pdfannots` (CLI fallback)
- `pikepdf`: `pip install pikepdf` (optional, for encrypted PDFs)

### NixOS Quick Install

```nix
# home.nix
home.packages = with pkgs; [
  pandoc typst
  (python3.withPackages (ps: with ps; [
    markitdown openpyxl pandas python-pptx xlsx2csv pymupdf pypdf pikepdf
  ]))
];
```

## Dependency Summary

| Tool | Purpose | Required For |
|------|---------|--------------|
| markitdown | Office to Markdown | /convert |
| pandoc | Universal converter | /convert, /slides |
| typst | Typst compiler | /convert (typst output) |
| pandas | DataFrame handling | /table |
| openpyxl | XLSX support | /table (xlsx) |
| python-pptx | PPTX extraction | /slides |
| xlsx2csv | XLSX fallback | /table (fallback) |
| pdflatex | LaTeX compilation | Beamer PDF output |
| pymupdf   | PDF annotation extraction     | /scrape (primary)    |
| pypdf     | PDF annotation extraction     | /scrape (fallback)   |
| pdfannots | PDF annotation CLI extraction | /scrape (fallback)   |
| pikepdf   | Decrypt encrypted PDFs        | /scrape (preprocess) |
