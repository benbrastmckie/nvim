# Teammate B Findings: Alternative Approaches and Prior Art

**Completed**: 2026-03-25
**Focus**: Alternative tools, prior art, edge cases, PDF standards

## Key Findings

- **pypdf** (successor to PyPDF2) is a strong pure-Python alternative for annotation extraction with active maintenance and clear annotation API
- **pikepdf** provides low-level PDF object access (via QPDF) and has an Annotation class, but cannot extract text — useful for structural inspection, not annotation text retrieval
- **pdfrw** is a lightweight pure-Python library for reading/writing PDFs but focuses on manipulation, not annotation extraction; pdf-annotate builds on it to *add* annotations but not extract them
- **pypdfium2** exposes Google's PDFium via ctypes bindings — high performance, Apache-licensed, and can access annotations through the raw PDFium API, though annotation helpers are limited
- **pdfminer.six** explicitly does NOT support annotation extraction (confirmed via GitHub issue #531)
- **Academic reference managers** (Zotero, Mendeley) use proprietary internal databases for annotation storage rather than PDF-native approaches
- PDF annotation standards are governed by ISO 32000-1 (PDF 1.7) and ISO 32000-2 (PDF 2.0), with PDF 2.0 available free from PDF Association
- Encoding issues (UTF-16 BOM, GBK2K-H/V cmaps), column-order errors, and whitespace-only annotations are the most common failure modes

## Alternative Tools

### pypdf

pypdf is the actively maintained successor to the deprecated PyPDF2 (pure Python, Apache 2.0 licensed). It has first-class annotation support:

- Iterates all annotations per page via `page.annotations`
- Extracts annotation subtypes: `/Text`, `/Highlight`, `/Underline`, `/StrikeOut`, `/Squiggly`, `/FileAttachment`
- Accesses quad points for highlight coordinate data
- Returns raw PDF dictionary objects for unrecognized annotation types

**Strengths**: Pure Python (no native deps), well-documented annotation API, actively maintained (v6.8.0 as of 2025).
**Weaknesses**: 10-20x slower than C-backed alternatives for large documents; text extraction quality lags behind PyMuPDF/pypdfium2.

**Verdict**: Best pure-Python fallback when binary dependencies are a concern.

### pikepdf

pikepdf (backed by QPDF) provides low-level PDF object manipulation:

- Has an `Annotation` class with access to annotation dictionaries
- Can iterate page `/Annots` arrays and inspect annotation objects
- **Cannot extract text** — no text rendering engine
- Primarily designed for PDF repair, manipulation, and security features

**Strengths**: Excellent for structural access to annotation metadata; handles malformed/corrupted PDFs well (QPDF's repair capabilities); active maintenance (v10.5.1, 2025).
**Weaknesses**: Cannot retrieve annotation text content without pairing with a text extraction library; not designed as an annotation extraction tool.

**Verdict**: Good for structural inspection or preprocessing (e.g., detecting annotation presence, unlocking encrypted PDFs via QPDF before extraction). Pair with pypdf or PyMuPDF for text.

### pdfrw / pdf-annotate

**pdfrw**: Pure-Python library for reading/writing PDFs. Provides low-level access to PDF objects but does not have an annotation extraction API. Rarely updated (last significant release 2019).

**pdf-annotate** (plangrid): Built on pdfrw specifically to *add* annotations to PDFs, not extract them. Provides `TextAnnotation`, `SquareAnnotation`, etc. for writing. No extraction functionality.

**Verdict**: Neither is suitable for annotation extraction. pdfrw is a legacy option; pdf-annotate is write-only.

### pypdfium2

Python bindings to Google's PDFium (Apache 2.0 licensed — unlike MuPDF which is AGPL):

- Access to all PDFium C APIs through raw ctypes bindings
- Annotation support available via `FPDF_PAGEOBJ` and the raw PDFium annotation API (`FPDFAnnot_*` functions)
- High-level helpers are limited for annotations — raw API access required
- Excellent text extraction quality (comparable to PyMuPDF)

**Strengths**: Apache 2.0 license (vs. PyMuPDF's AGPL), high performance, backed by Google's PDF engine (used in Chrome).
**Weaknesses**: Annotation extraction requires raw C-API calls — more verbose than PyMuPDF's Pythonic interface; annotation helper coverage is incomplete.

**Verdict**: Strong alternative to PyMuPDF when licensing matters. Annotation extraction is possible but requires more boilerplate.

### pdfminer.six

Explicitly does NOT support annotation extraction (GitHub issue #531 confirmed). Designed for text and structure extraction only. AcroForm support is present but annotations are not extracted.

**Verdict**: Not applicable for annotation extraction.

### Other tools discovered

- **pdflib** (poppler wrapper): Replaces pdf2image/pdftotext but primarily for text/rendering; no specific annotation extraction API documented.
- **camelot-py**: Table extraction only; no annotation support.
- **Apache Tika**: Server-based text extraction, excellent quality, but no annotation extraction capability.
- **pdf2image**: Rendering only; converts pages to images.
- **ocrmypdf**: OCR layer addition; not relevant for annotation extraction.

## Prior Art Analysis

### Academic Reference Managers

**Zotero approach**:
- Annotations created in Zotero's built-in PDF reader are stored in Zotero's SQLite database (`zotero.sqlite`), NOT embedded in the PDF file
- Table: `itemAnnotations` — stores annotation content, color, type, PDF item ID
- Supports: highlights, underlines, notes, area selections, freehand ink
- External PDF annotations (pre-existing) appear read-only (locked) but can be imported into the database
- Export: annotations can be written back to PDF as standard embedded annotations at any time
- Design rationale: enables fast conflict-free sync for group libraries; prevents file-level conflicts

**Mendeley approach**:
- Also uses internal database storage for annotations
- Zotero can import Mendeley annotations, converting rectangle highlights to image annotations
- Mendeley's migration away from local SQLite (in newer versions) has caused compatibility issues for export tools

**Implications for extraction tooling**: Academic tools deliberately avoid PDF-native annotation storage for sync reliability. Users who annotate in Zotero and want programmatic access to annotations must either (a) read the SQLite database directly or (b) export to PDF first, then use a Python extraction library.

### PDF Annotation Standards

**PDF 1.x (ISO 32000-1:2008 — PDF 1.7)**:
- Annotations defined in Section 12.5 of the specification
- Core annotation types: Text, Link, FreeText, Line, Square, Circle, Polygon, PolyLine, Highlight, Underline, Squiggly, StrikeOut, Caret, Stamp, Ink, Popup, FileAttachment, Sound, Movie, Widget, Screen, PrinterMark, TrapNet, Watermark, 3D
- Markup annotations (highlights, underlines, etc.) use `/QuadPoints` array for coordinate data
- Annotation content in `/Contents` key; rich text in `/RC` (rich contents) or `/DS` (default style)

**PDF 2.0 (ISO 32000-2:2020)**:
- Available free of charge from the PDF Association
- Adds: `Projection` annotation, `RichMedia` annotation improvements, better accessibility support
- Clarifies ambiguities in markup annotation coordinate systems
- Deprecates some annotation types (PrinterMark, TrapNet)
- Most real-world PDFs encountered in practice are PDF 1.x; PDF 2.0 adoption is still limited

**Key interoperability issue**: Tools creating annotations may store data in non-standard locations or use vendor-specific extensions. Adobe Acrobat, for instance, may store annotation data in ways that differ from what simple dictionary access returns.

## Edge Cases and Failure Modes

### Text Content Issues
- **Missing characters**: PDF text extractor fails to reconstruct annotation text, yielding empty or partial content — particularly common with custom fonts or CIDFont encodings
- **Missing spaces**: Characters captured without inter-word spaces; affects word-boundary detection in annotation text
- **Column order errors**: Multi-column PDFs return annotation text in wrong reading order (top of column 2 before end of column 1)
- **Whitespace-only annotations**: StrikeOut/highlight covering pure whitespace returns no text — annotation silently skipped by some tools (pdfannots behavior)

### Encoding Issues
- **UTF-16 BOM**: Strings encoded as UTF-16 with BOM (`FE FF` prefix) can produce trailing low surrogate characters that break subsequent operations (confirmed PyMuPDF issue #4564)
- **CJK encodings**: Advanced CMaps like `/GBK2K-H` and `/GBK2K-V` not implemented in some libraries — causes warnings or garbled output
- **PDFDocEncoding vs. UTF-16**: PDF allows both; tools must handle both encoding forms in the same document

### Structural Issues
- **Encrypted/password-protected PDFs**: Most tools cannot read annotations without first decrypting (pikepdf/QPDF can handle decryption preprocessing)
- **Malformed annotation dictionaries**: Missing required keys (`/Rect`, `/Subtype`) cause crashes or silent skips
- **Annotations on XObject forms**: Annotations on referenced form XObjects rather than page content may be missed
- **Overlapping annotations**: Multiple annotations on same text region — tools vary in how they handle deduplication

### PDF Version Compatibility
- **PDF 2.0 annotations**: Most Python libraries have incomplete support for PDF 2.0-specific annotation types
- **Linearized PDFs**: Generally handled correctly for annotation extraction; linearization affects download order, not object structure
- **Incremental updates**: Annotations added via incremental update (appended to file) are sometimes missed by parsers that only read the original cross-reference table

## Recommended Fallback Chain

Based on research, the following priority chain is recommended for a robust annotation extraction implementation:

```
1. PyMuPDF (primary)
   - Best annotation coverage, Pythonic API, high performance
   - AGPL license — consider for open-source projects

2. pypdf (first fallback)
   - Pure Python, Apache 2.0 license
   - Slower but no native dependencies
   - Good for environments where binary wheels are unavailable

3. pypdfium2 (second fallback — license-sensitive contexts)
   - Apache 2.0 license alternative to PyMuPDF
   - Requires raw API usage for annotations

4. pikepdf (preprocessing only)
   - Use for decryption/repair before passing to extraction tool
   - Not suitable as standalone annotation extractor

5. pdfannots (CLI/specialized use)
   - Best for command-line workflows or Markdown output
   - Not suitable for programmatic integration as a library
```

**Preprocessing recommendation**: For encrypted PDFs, use pikepdf (QPDF-backed) to decrypt/repair first, then pass to primary extraction tool.

## Confidence Level

**High** for:
- Library capabilities and limitations (backed by documentation and issue tracker evidence)
- Zotero/Mendeley storage architecture (official documentation)
- PDF standard version information (ISO documentation)
- Common failure modes (confirmed across multiple sources)

**Medium** for:
- pypdfium2 annotation extraction API specifics (limited high-level documentation; raw API required)
- PDF 2.0 adoption rates in practice (no current statistics found)

## Sources

- [pypdf annotation documentation](https://pypdf.readthedocs.io/en/stable/user/reading-pdf-annotations.html)
- [pikepdf PyPI](https://pypi.org/project/pikepdf/)
- [pikepdf GitHub](https://github.com/pikepdf/pikepdf)
- [pypdfium2 GitHub](https://github.com/pypdfium2-team/pypdfium2)
- [pdf-annotate GitHub (plangrid)](https://github.com/plangrid/pdf-annotate)
- [pdfminer.six annotation issue #531](https://github.com/pdfminer/pdfminer.six/issues/531)
- [Zotero annotations in database (official KB)](https://www.zotero.org/support/kb/annotations_in_database)
- [ISO 32000-2 PDF Association](https://pdfa.org/resource/iso-32000-2/)
- [ISO 32000-1 PDF 1.7 specification](https://www.iso.org/standard/51502.html)
- [Python PDF Ecosystem 2024 - Martin Thoma](https://martinthoma.medium.com/the-python-pdf-ecosystem-in-2024-2cad87732e49)
- [PyMuPDF common issues documentation](https://pymupdf.readthedocs.io/en/latest/recipes-common-issues-and-their-solutions.html)
- [PyMuPDF encoding issue #4564](https://github.com/pymupdf/PyMuPDF/issues/4564)
- [pypdf CMap encoding issue #2356](https://github.com/py-pdf/pypdf/issues/2356)
- [Zotero annotation database forum discussion](https://forums.zotero.org/discussion/107387/what-kind-of-database-does-the-pdf-reader-use-and-is-it-exportable)
