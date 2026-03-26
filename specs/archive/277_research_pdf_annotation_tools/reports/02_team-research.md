# Research Report: Task #277

**Task**: 277 - Research PDF annotation extraction tools
**Date**: 2026-03-25
**Mode**: Team Research (2 teammates)

## Summary

PyMuPDF (fitz) is the clear best choice for PDF annotation extraction, replacing the current pdfannots tool. It provides comprehensive annotation type coverage, a rich Pythonic API, high performance via its C-based MuPDF engine, and is available in nixpkgs. pypdf serves as the best pure-Python fallback for environments where binary dependencies are problematic.

## Key Findings

### Primary Approach (from Teammate A)

**PyMuPDF is the recommended primary tool** for annotation extraction:

1. **Complete annotation coverage**: Supports every PDF annotation type - highlights, notes, underlines, stamps, freetext, redactions, ink, polygons, file attachments
2. **Rich Python API**: `page.annots()` iterator with `annot.type`, `annot.info` (content, title, author, dates), `annot.rect`
3. **Integrated text extraction**: `page.get_text(clip=annot.rect)` retrieves highlighted/underlined text reliably
4. **High performance**: C-based MuPDF engine, significantly faster than pdfminer.six-based tools
5. **NixOS availability**: `python3Packages.pymupdf` in nixpkgs
6. **Active maintenance**: v1.27.x, large community, comprehensive documentation

**pdfannots** (current tool) is purpose-built for academic PDF review with clean Markdown/JSON output, but is CLI-first with no public Python API, relies on pdfminer.six which can misplace text, and is not confirmed in nixpkgs.

**pdfplumber** only returns bounding-box geometry - no comment text, no annotation type. Not suitable.

**poppler-utils** CLI tools do not expose annotation data despite the underlying library supporting it.

### Alternative Approaches (from Teammate B)

**pypdf** (PyPDF2 successor) is the best pure-Python alternative:
- First-class annotation API via `page.annotations`
- Extracts subtypes: Text, Highlight, Underline, StrikeOut, Squiggly, FileAttachment
- Apache 2.0 license, no native dependencies
- 10-20x slower than C-backed alternatives for large documents

**pikepdf** (QPDF-backed) is useful for preprocessing:
- Handles encrypted/malformed PDFs via QPDF repair
- Has Annotation class but cannot extract text
- Best used to decrypt/repair before passing to extraction tool

**pypdfium2** (Google PDFium bindings) is a license-friendly alternative:
- Apache 2.0 (vs PyMuPDF's AGPL)
- High performance but annotation extraction requires raw C-API calls

**Not suitable**: pdfrw (unmaintained), pdf-annotate (write-only), pdfminer.six (explicitly no annotation support per GitHub issue #531)

## Synthesis

### Recommended Tool Chain

```
Primary:    PyMuPDF (fitz)     - Best API, performance, coverage
Fallback 1: pypdf              - Pure Python, no native deps
Fallback 2: pdfannots          - CLI fallback, backwards compatible
Preprocess: pikepdf            - Decrypt/repair encrypted PDFs
```

### Conflicts Resolved

1. **pdfannots vs PyMuPDF as primary**: Both teammates agree PyMuPDF is superior. pdfannots is relegated to CLI fallback for backwards compatibility with existing `<leader>la` workflow.

### Edge Cases to Handle

- UTF-16 BOM encoding in annotation strings (PyMuPDF issue #4564)
- CJK encodings with non-standard CMaps
- Encrypted PDFs (preprocess with pikepdf)
- Whitespace-only annotations (highlight covering whitespace returns empty text)
- Multi-column PDFs (column-order text extraction errors)
- Incremental-update annotations missed by some parsers
- Zotero/Mendeley annotations stored in SQLite databases, not PDFs (users must export first)

### NixOS Installation

```nix
# home.nix
home.packages = with pkgs; [
  (python3.withPackages (ps: with ps; [
    pymupdf     # Primary: python3Packages.pymupdf
    pypdf       # Fallback: python3Packages.pypdf
    pikepdf     # Preprocessing: python3Packages.pikepdf
  ]))
];
```

### API Design for scrape-agent

```python
import fitz

def extract_annotations(pdf_path, output_format="markdown", types=None):
    doc = fitz.open(pdf_path)
    annotations = []
    for page in doc:
        for annot in page.annots():
            if types and annot.type[1] not in types:
                continue
            entry = {
                "page": page.number + 1,
                "type": annot.type[1],
                "content": annot.info.get("content", ""),
                "author": annot.info.get("title", ""),
                "date": annot.info.get("modDate", ""),
                "rect": list(annot.rect),
            }
            # For highlights/underlines, get underlying text
            if annot.type[0] in (8, 9, 10, 11):  # Highlight, Underline, Squiggly, StrikeOut
                entry["highlighted_text"] = page.get_text(clip=annot.rect)
            annotations.append(entry)
    return annotations
```

## Recommendations

1. **Use PyMuPDF as primary tool** in scrape-agent with pypdf as fallback
2. **Support both markdown and JSON output** formats
3. **Add pikepdf preprocessing** for encrypted PDFs
4. **Keep pdfannots as CLI fallback** for backwards compatibility
5. **Handle edge cases**: encoding issues, empty annotations, multi-column text

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary tool analysis | completed | high |
| B | Alternatives and prior art | completed | high |

## Sources

### Teammate A Sources
- [PyMuPDF documentation](https://pymupdf.readthedocs.io/en/latest/)
- [PyMuPDF Annot class](https://pymupdf.readthedocs.io/en/latest/annot.html)
- [pdfannots GitHub](https://github.com/0xabu/pdfannots)
- [pdfplumber GitHub](https://github.com/jsvine/pdfplumber)

### Teammate B Sources
- [pypdf annotation docs](https://pypdf.readthedocs.io/en/stable/user/reading-pdf-annotations.html)
- [pikepdf GitHub](https://github.com/pikepdf/pikepdf)
- [pypdfium2 GitHub](https://github.com/pypdfium2-team/pypdfium2)
- [pdfminer.six annotation issue #531](https://github.com/pdfminer/pdfminer.six/issues/531)
- [Zotero annotations in database](https://www.zotero.org/support/kb/annotations_in_database)
- [ISO 32000-2 PDF Association](https://pdfa.org/resource/iso-32000-2/)
