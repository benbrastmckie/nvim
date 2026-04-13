# Filetypes Conversion Tables

## Document Conversions (via /convert)

| Source | Target | Primary Tool | Fallback 1 | Fallback 2 |
|--------|--------|--------------|------------|------------|
| PDF | Markdown | pymupdf | pandoc | markitdown |
| DOCX | Markdown | markitdown | pandoc | - |
| HTML | Markdown | markitdown | pandoc | - |
| EPUB | Markdown | pymupdf | pandoc | - |
| Images | Markdown | pymupdf (OCR) | markitdown | - |
| PPTX/XLSX | Markdown | markitdown | - | - |
| Markdown | PDF | pandoc | typst | - |

## Spreadsheet Conversions (via /table)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| XLSX | LaTeX table | pandas + openpyxl | xlsx2csv |
| XLSX | Typst table | pandas -> CSV -> Typst csv() | xlsx2csv |
| CSV | LaTeX table | pandas | manual |
| CSV | Typst table | Typst csv() | manual |
| ODS | LaTeX/Typst table | pandas | - |

## Presentation Conversions (via /convert)

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| PPTX | Beamer | python-pptx + pandoc | markitdown |
| PPTX | Polylux (Typst) | python-pptx | markitdown |
| PPTX | Touying (Typst) | python-pptx | markitdown |
| Markdown | PPTX | pandoc | - |

**Note**: `/slides` in the `present` extension is a distinct research-talk task-creation command; for PPTX file conversion, use `/convert --format beamer|polylux|touying`.

## PDF Annotation Extraction (via /scrape)

| Source | Output Format | Primary Tool | Fallback 1 | Fallback 2 |
|--------|---------------|--------------|------------|------------|
| PDF    | Markdown      | PyMuPDF      | pypdf      | pdfannots  |
| PDF    | JSON          | PyMuPDF      | pypdf      | pdfannots  |

Supported annotation types: highlight, note, underline, strikeout, freetext, stamp, ink

## Edit Operations (via /edit)

Edit operations modify documents in-place, unlike format conversion which creates new files.

| Operation | File Type | Primary Tool | Fallback | Notes |
|-----------|----------|--------------|----------|-------|
| Edit DOCX | .docx | SuperDoc MCP | python-docx | Tracked changes supported (SuperDoc only) |
| Batch edit DOCX | directory | SuperDoc MCP | python-docx | Iterates all .docx files |
| Create DOCX | .docx (new) | SuperDoc MCP | python-docx | Headings, paragraphs, tables |
| Edit XLSX | .xlsx | openpyxl MCP | - | Planned, not yet available |

**Key distinction**: `/convert` creates a new file in a different format. `/edit` modifies the original file in-place. Both use different tool chains and agents.

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

# Presentation conversion (PPTX to slide formats)
/convert presentation.pptx --format beamer          # -> presentation.tex (Beamer)
/convert deck.pptx slides.typ --format polylux
/convert talk.pptx talk.typ --format touying

# PDF annotation extraction
/scrape paper.pdf                              # -> paper_annotations.md
/scrape paper.pdf notes.md                     # -> notes.md
/scrape paper.pdf --format json                # -> paper_annotations.md (JSON)
/scrape paper.pdf --types highlight,note       # -> only highlights and notes

# In-place document editing
/edit contract.docx "Replace ACME Corp with NewCo Inc."
/edit ~/Documents/Contracts/ "Replace old name with new name in all files"
/edit --new memo.docx "Create Q2 budget review with summary table"
```

## Prerequisites

Install conversion tools based on your needs:

**Document Conversion**:
- `pymupdf`: `pip install pymupdf` (primary for PDF/EPUB/Images)
- `pymupdf4llm`: `pip install pymupdf4llm` (optional, enhanced PDF-to-markdown)
- `markitdown`: `pip install markitdown` (primary for DOCX/PPTX/XLSX/HTML)
- `pandoc`: Install from package manager (universal fallback)
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
    pymupdf markitdown openpyxl pandas python-pptx xlsx2csv pypdf pikepdf
  ]))
];
```

## Dependency Summary

| Tool | Purpose | Required For |
|------|---------|--------------|
| pymupdf | PDF/EPUB/Image extraction | /convert (PDF primary) |
| pymupdf4llm | Enhanced PDF-to-markdown | /convert (PDF optional) |
| markitdown | Office to Markdown | /convert (DOCX/PPTX/XLSX) |
| pandoc | Universal converter | /convert (fallback) |
| typst | Typst compiler | /convert (typst output) |
| pandas | DataFrame handling | /table |
| openpyxl | XLSX support | /table (xlsx) |
| python-pptx | PPTX extraction | /convert (with --format) |
| xlsx2csv | XLSX fallback | /table (fallback) |
| pdflatex | LaTeX compilation | Beamer PDF output |
| pymupdf   | PDF annotation extraction     | /scrape (primary)    |
| pypdf     | PDF annotation extraction     | /scrape (fallback)   |
| pdfannots | PDF annotation CLI extraction | /scrape (fallback)   |
| pikepdf   | Decrypt encrypted PDFs        | /scrape (preprocess) |
| superdoc  | DOCX read-write editing       | /edit (primary)      |
| python-docx | DOCX read-write (no tracking) | /edit (fallback)   |
