# Filetypes Extension Dependency Guide

Platform-specific installation instructions for all conversion tools used by the filetypes extension.

## Quick Install Summary

| Tool | NixOS | Ubuntu/Debian | macOS |
|------|-------|---------------|-------|
| pymupdf | `python3Packages.pymupdf` | `pip install pymupdf` | `pip install pymupdf` |
| pymupdf4llm | (pip in venv) | `pip install pymupdf4llm` | `pip install pymupdf4llm` |
| markitdown | `python3Packages.markitdown` | `pip install markitdown` | `pip install markitdown` |
| pandoc | `pandoc` | `apt install pandoc` | `brew install pandoc` |
| typst | `typst` | (manual/cargo) | `brew install typst` |
| pandas | `python3Packages.pandas` | `pip install pandas` | `pip install pandas` |
| openpyxl | `python3Packages.openpyxl` | `pip install openpyxl` | `pip install openpyxl` |
| python-pptx | `python3Packages.python-pptx` | `pip install python-pptx` | `pip install python-pptx` |
| xlsx2csv | `python3Packages.xlsx2csv` | `pip install xlsx2csv` | `pip install xlsx2csv` |
| pdflatex | `texlive.combined.scheme-basic` | `apt install texlive-base` | `brew install mactex-no-gui` |

## NixOS Installation

### Ephemeral (nix-shell)

For temporary use without modifying system configuration:

```bash
# Document conversion (PDF)
nix-shell -p python3Packages.pymupdf

# Document conversion (Office formats)
nix-shell -p python3Packages.markitdown

# Spreadsheet conversion
nix-shell -p python3Packages.openpyxl python3Packages.pandas

# Presentation extraction
nix-shell -p python3Packages.python-pptx

# LaTeX/PDF tools
nix-shell -p pandoc texlive.combined.scheme-basic

# Typst
nix-shell -p typst

# All at once
nix-shell -p python3Packages.pymupdf python3Packages.markitdown python3Packages.openpyxl python3Packages.pandas python3Packages.python-pptx pandoc typst texlive.combined.scheme-basic
```

### Persistent (home-manager)

Add to your `home.nix` for persistent installation:

```nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    pandoc
    typst
    texlive.combined.scheme-basic  # or scheme-full for complete LaTeX

    (python3.withPackages (ps: with ps; [
      pymupdf
      markitdown
      openpyxl
      pandas
      python-pptx
      xlsx2csv
    ]))
  ];
}
```

Then apply: `home-manager switch`

### Imperative (nix profile)

For ad-hoc installation on NixOS:

```bash
nix profile install nixpkgs#pandoc
nix profile install nixpkgs#typst
nix profile install nixpkgs#texlive.combined.scheme-basic

# Python packages (install via pip in a venv or use flakes)
```

### Using Flakes

For project-specific dependencies:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          pandoc
          typst
          (python3.withPackages (ps: with ps; [
            markitdown openpyxl pandas python-pptx xlsx2csv
          ]))
        ];
      };
    };
}
```

Then: `nix develop`

## Ubuntu/Debian Installation

### System Packages (apt)

```bash
# Pandoc and TeX
sudo apt update
sudo apt install pandoc texlive-base texlive-latex-recommended

# For more LaTeX packages
sudo apt install texlive-full  # Warning: large download
```

### Python Packages (pip)

```bash
# Create virtual environment (recommended)
python3 -m venv ~/.venvs/filetypes
source ~/.venvs/filetypes/bin/activate

# Install all conversion tools
pip install markitdown pandas openpyxl python-pptx xlsx2csv

# Verify installation
python3 -c "import pandas, openpyxl, pptx, markitdown; print('OK')"
```

### Typst Installation

Typst is not in Ubuntu repositories. Install via:

```bash
# Via cargo (Rust)
cargo install typst-cli

# Or download binary from GitHub releases
curl -LO https://github.com/typst/typst/releases/latest/download/typst-x86_64-unknown-linux-musl.tar.xz
tar xf typst-x86_64-unknown-linux-musl.tar.xz
sudo mv typst /usr/local/bin/
```

## macOS Installation

### Homebrew

```bash
# Core tools
brew install pandoc typst

# LaTeX (warning: large download)
brew install mactex-no-gui

# Or minimal LaTeX
brew install basictex
```

### Python Packages

```bash
# Using Homebrew Python
pip3 install markitdown pandas openpyxl python-pptx xlsx2csv

# Or with virtual environment
python3 -m venv ~/.venvs/filetypes
source ~/.venvs/filetypes/bin/activate
pip install markitdown pandas openpyxl python-pptx xlsx2csv
```

## Package Details

### pymupdf (fitz)

PDF manipulation and extraction library.

- **Purpose**: Extract text, tables, and images from PDF, EPUB, and image files
- **Python package**: `pymupdf` (imported as `fitz`)
- **Capabilities**: Text extraction, table detection (`find_tables()`), OCR (with Tesseract), image extraction
- **Primary for**: PDF to Markdown conversion, EPUB extraction, image OCR
- **Note**: Decisively outperforms markitdown for PDF quality (structure, tables, formatting)

### pymupdf4llm (optional enhancement)

Enhanced markdown output from PyMuPDF.

- **Purpose**: High-quality PDF-to-markdown conversion optimized for LLM consumption
- **Python package**: `pymupdf4llm`
- **Capabilities**: Structured markdown with headers, lists, tables preserved from PDF layout
- **Note**: Optional enhancement; base pymupdf provides adequate output

### markitdown

Microsoft's document-to-markdown converter.

- **Purpose**: Convert DOCX, XLSX, PPTX, HTML, images to Markdown (primary for Office formats)
- **Python package**: `markitdown`
- **Capabilities**: OCR support, table extraction, embedded content
- **Note**: Not available as system package on most distros
- **NixOS fragility**: markitdown CLI availability can break on Nix Python version bumps; pymupdf is the more reliable option for PDF on NixOS

### pandoc

Universal document converter.

- **Purpose**: Convert between Markdown, LaTeX, HTML, DOCX, etc.
- **System package**: Available on all major platforms
- **Capabilities**: Beamer slides, citations, templates

### typst

Modern typesetting system (LaTeX alternative).

- **Purpose**: Generate PDFs from Typst markup
- **Capabilities**: Fast compilation, modern syntax, Polylux/Touying slides
- **Note**: Newer tool, may require manual installation on some systems

### pandas

Data analysis library with table I/O.

- **Purpose**: Read spreadsheets, generate LaTeX tables
- **Key function**: `DataFrame.to_latex()`
- **Requires**: openpyxl for .xlsx support

### openpyxl

Excel file handler for Python.

- **Purpose**: Read .xlsx files with full feature support
- **Capabilities**: Formulas, styles, charts (read calculated values)
- **Works with**: pandas for DataFrame creation

### python-pptx

PowerPoint file handler for Python.

- **Purpose**: Extract slides, text, images, speaker notes
- **Capabilities**: Full PPTX structure access
- **Works with**: pandas for tables, Pillow for images

### xlsx2csv

Simple XLSX to CSV converter.

- **Purpose**: Fallback for XLSX extraction
- **Capabilities**: Sheet selection, basic formatting
- **Use when**: pandas/openpyxl unavailable

### pdflatex

LaTeX to PDF compiler.

- **Purpose**: Compile Beamer slides to PDF
- **Part of**: texlive distribution
- **Note**: Large download; consider scheme-basic for minimal install

## Verification Commands

Check if tools are available:

```bash
# CLI tools
command -v markitdown && echo "markitdown: OK"
command -v pandoc && echo "pandoc: OK"
command -v typst && echo "typst: OK"
command -v pdflatex && echo "pdflatex: OK"
command -v xlsx2csv && echo "xlsx2csv: OK"

# Python packages
python3 -c "import fitz" && echo "pymupdf: OK"
python3 -c "import pymupdf4llm" && echo "pymupdf4llm: OK"
python3 -c "import pandas" && echo "pandas: OK"
python3 -c "import openpyxl" && echo "openpyxl: OK"
python3 -c "import pptx" && echo "python-pptx: OK"
python3 -c "import markitdown" && echo "markitdown (Python): OK"
```

## Troubleshooting

### "Package not found" in pip

```bash
# Ensure pip is up to date
pip install --upgrade pip

# Try with --user flag
pip install --user markitdown
```

### "python-pptx not in nixpkgs"

The package name in nixpkgs is hyphenated:
```nix
python3Packages.python-pptx  # Correct
python3Packages.pptx         # May also work
```

### "pdflatex command not found"

LaTeX is distributed as texlive. Install the appropriate scheme:
- `texlive-base` (apt) - Minimal
- `texlive.combined.scheme-basic` (Nix) - Minimal
- `texlive-full` / `scheme-full` - Complete (large)

### csv2latex Not Available

The csv2latex tool is not widely packaged. Use pandas instead:
```python
import pandas as pd
df = pd.read_csv("data.csv")
print(df.to_latex(index=False))
```
