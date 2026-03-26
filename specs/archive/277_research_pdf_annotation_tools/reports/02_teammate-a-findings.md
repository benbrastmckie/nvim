# Teammate A Findings: PDF Annotation Tool Analysis

**Date**: 2026-03-25
**Focus**: Primary implementation approaches and patterns for PDF annotation extraction

## Key Findings

- PyMuPDF (fitz) is the strongest overall choice: comprehensive annotation type support, fast C-based engine, rich Python API, and active maintenance
- pdfannots is purpose-built for annotation extraction with clean Markdown/JSON output, but has a limited Python API (CLI-first) and relies on pdfminer.six which can misplace text
- pdfplumber provides `.annots` access but lacks annotation-specific metadata (no comment text, no annotation subtype details) - not suitable as primary annotation extractor
- poppler-utils (command-line) lacks dedicated annotation extraction tools; its core library supports annotations but pdftotext/pdftohtml don't expose them
- Both PyMuPDF and pdfannots are available via pip; PyMuPDF is available in nixpkgs as `python3Packages.pymupdf`; pdfplumber as `python3Packages.pdf-plumber`; pdfannots not confirmed in nixpkgs (install via pip in a Nix Python environment)

---

## Tool Comparison

### pdfannots

- **Features**:
  - Purpose-built CLI tool for annotation extraction
  - Organizes annotations by semantic category (highlights, detailed comments, nits)
  - Includes page numbers and section headings from embedded PDF outlines/bookmarks
  - Designed specifically for reviewing academic papers

- **Annotation types**:
  - Highlights (with and without attached comments)
  - Standalone text annotations (sticky notes)
  - Underline, strikeout, squiggly underline (grouped as "nits")

- **Output formats**:
  - Markdown (default): structured sections for each annotation category
  - JSON: machine-readable export

- **Installation**:
  - `python3 -m pip install pdfannots`
  - NixOS: not confirmed as a nixpkgs attribute; use `pip` inside a `python3.withPackages` environment
  - Requires Python >= 3.9, depends on `pdfminer.six`

- **API**:
  - Primarily a CLI tool (`pdfannots file.pdf`)
  - No documented public Python API for programmatic use
  - CLI flags: `--cols`, `--word-margin`, `--no-group`, `--json`
  - Known limitation: pdfminer.six can miss or misplace characters, resulting in incomplete annotation text

---

### PyMuPDF (fitz)

- **Features**:
  - High-performance C-based PDF engine (MuPDF), Python bindings
  - Full read/write/modify support for PDF annotations
  - Broad document format support beyond PDF
  - Actively maintained (latest: 1.27.x as of 2025)
  - Supports conversion, rendering, text/table extraction in addition to annotations

- **Annotation types** (full PDF spec support):
  - Text markup: Highlight, Underline, StrikeOut, Squiggly
  - Comment/note: Text (sticky notes), FreeText
  - Graphical: Line, Square, Circle, Polygon, PolyLine, Ink (freehand)
  - Meta: Stamp (Draft/Approved), Caret, Redact
  - Attachments: FileAttachment

- **Output formats**:
  - No built-in structured export format; returns Python objects
  - Developer serializes to JSON, Markdown, CSV, or any format as needed

- **Installation**:
  - `pip install PyMuPDF`
  - NixOS: `python3Packages.pymupdf` available in nixpkgs (confirmed via nixpkgs issues referencing the attribute)
  - No mandatory external dependencies

- **API** (rich Python API):
  ```python
  import fitz  # or: import pymupdf as fitz

  doc = fitz.open("file.pdf")
  for page in doc:
      for annot in page.annots():
          print(annot.type[1])           # annotation type name
          print(annot.info)              # dict: content, title, author, dates
          print(annot.rect)              # bounding rectangle
          # For highlights: get underlying text
          text = page.get_text(clip=annot.rect)

  # Filter by type
  for annot in page.annots(types=(fitz.PDF_ANNOT_HIGHLIGHT, fitz.PDF_ANNOT_UNDERLINE)):
      highlighted_text = page.get_text(clip=annot.rect)
  ```

---

### pdfplumber

- **Features**:
  - Excellent for text, table, and geometric extraction from digital PDFs
  - Built on pdfminer.six
  - Visual debugging tools for layout analysis
  - Works best with digitally-created (non-scanned) PDFs

- **Annotation types**:
  - Exposes `.annots` property returning annotation objects
  - Explicitly identifies `.hyperlinks` (Link subtype with URI)
  - Does NOT provide annotation-specific metadata (no comment content, no annotation type distinctions beyond geometry)

- **Output formats**:
  - Python dictionaries with positional data
  - No annotation-specific export format

- **Installation**:
  - `pip install pdfplumber`
  - NixOS: `python3Packages.pdf-plumber` (exists in nixpkgs, had build issues in 2024 related to pdfminer-six)
  - Requires Python 3.10+

- **API**:
  ```python
  import pdfplumber

  with pdfplumber.open("file.pdf") as pdf:
      for page in pdf.pages:
          for annot in page.annots:
              print(annot)  # dict with x0, y0, x1, y1, page_number, object_type
          # Only geometry, no comment text or annotation type details
  ```

- **Critical limitation**: `.annots` only returns bounding-box geometry and `object_type="annot"`. It does not expose annotation content (comment text), annotation subtype (highlight vs. note), or author. Not suitable as a primary annotation extractor.

---

### poppler-utils (pdftotext, pdfinfo, pdftohtml, etc.)

- **Features**:
  - Comprehensive PDF rendering library used by most Linux PDF viewers and LibreOffice
  - Full ISO 32000-1 compliance including annotations (since v0.18, 2011)
  - Command-line utilities: pdftotext, pdfinfo, pdftohtml, pdftocairo, pdfimages, pdfdetach, pdffonts, pdfseparate, pdfunite, pdftoppm, pdfsig

- **Annotation types**:
  - Library core supports full annotation spec (Acroforms, all annotation types)
  - Command-line utilities do NOT expose annotation extraction directly

- **Output formats**:
  - pdftotext: plain text (no annotation data)
  - pdftohtml: HTML/XML (includes some annotation rendering, but not extractable metadata)
  - pdfinfo: document metadata only (title, author, pages)
  - No utility outputs annotation comment text or structured annotation data

- **Installation**:
  - NixOS: `pkgs.poppler_utils` (system package, well-supported)
  - Most Linux distros: `sudo apt install poppler-utils` / `nix-env -iA nixpkgs.poppler_utils`

- **API**:
  - No direct Python bindings for annotation extraction
  - python-poppler and poppdf exist as third-party wrappers but have limited annotation support
  - Best used via subprocess for text extraction, not annotation extraction

- **Critical limitation**: None of the standard poppler-utils command-line tools extract annotation comment text, annotation type, or annotation metadata. The underlying C library supports it, but it is not exposed in the CLI utilities included in the package.

---

## Recommended Approach

**Primary recommendation: PyMuPDF (fitz)**

PyMuPDF is the clear choice for a robust, production-ready PDF annotation extractor:

1. **Complete annotation coverage**: Supports every PDF annotation type including highlights, notes, underlines, stamps, freetext, and redactions
2. **Rich data access**: Returns annotation type, content/comment text, bounding rect, author, dates, colors - everything needed for a complete extractor
3. **Text extraction integration**: Can retrieve the actual highlighted/underlined text via `page.get_text(clip=annot.rect)`, which pdfannots also needs but handles less reliably
4. **Performance**: C-based MuPDF engine is significantly faster than pdfminer.six-based tools
5. **NixOS availability**: Available as `python3Packages.pymupdf` in nixpkgs
6. **Active maintenance**: Version 1.27.x, large community, comprehensive documentation
7. **Flexible output**: Developer controls output format (JSON, Markdown, CSV) rather than being locked into a predefined structure

**When to use pdfannots instead**: If the use case is specifically extracting annotations from academic PDFs for human-readable Markdown review notes, pdfannots provides a ready-made output format without custom code. For programmatic integration or custom output formats, PyMuPDF is superior.

**Do not use pdfplumber** for annotation extraction - it only provides bounding-box geometry with no annotation content or type information.

**Do not use poppler-utils** for annotation extraction - the CLI tools do not expose annotation data.

---

## Confidence Level

**High** - Multiple sources corroborate the tool capabilities, official documentation confirms API details for PyMuPDF, and the limitations of pdfplumber and poppler-utils are clearly documented. The recommendation for PyMuPDF is well-supported.

One uncertainty: pdfannots availability in nixpkgs was not confirmed; the NixOS search interface was not crawlable. This should be verified with `nix search nixpkgs pdfannots` before attempting to add it to a NixOS configuration.

---

## Sources

- [pdfannots on PyPI](https://pypi.org/project/pdfannots/)
- [pdfannots GitHub (0xabu/pdfannots)](https://github.com/0xabu/pdfannots)
- [PyMuPDF documentation](https://pymupdf.readthedocs.io/en/latest/)
- [PyMuPDF Annot class](https://pymupdf.readthedocs.io/en/latest/annot.html)
- [PyMuPDF Annotations recipes](https://pymupdf.readthedocs.io/en/latest/recipes-annotations.html)
- [Working With PDF Annotations in Python (PyMuPDF blog)](https://medium.com/@pymupdf/working-with-pdf-annotations-in-python-4d97e3788b7)
- [pdfplumber GitHub (jsvine/pdfplumber)](https://github.com/jsvine/pdfplumber)
- [Poppler (software) - Wikipedia](https://en.wikipedia.org/wiki/Poppler_(software))
- [poppler.freedesktop.org](https://poppler.freedesktop.org/)
- [PyMuPDF on PyPI](https://pypi.org/project/PyMuPDF/)
- [nixpkgs python3Packages.pdf-plumber build issue](https://github.com/NixOS/nixpkgs/issues/339639)
- [PyMuPDF GitHub](https://github.com/pymupdf/PyMuPDF)
