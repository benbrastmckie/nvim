## Document Converter Extension

This project includes document format conversion support via the document-converter extension.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-document-converter | document-converter-agent | Document format conversion |

### Supported Conversions

| Source | Target | Primary Tool | Fallback |
|--------|--------|--------------|----------|
| PDF | Markdown | markitdown | pandoc |
| DOCX | Markdown | markitdown | pandoc |
| XLSX/PPTX | Markdown | markitdown | - |
| HTML | Markdown | markitdown | pandoc |
| Images | Markdown | markitdown | - |
| Markdown | PDF | pandoc | typst |

### Command Usage

```bash
# PDF to Markdown (output inferred)
/convert document.pdf                    # -> document.md

# DOCX to Markdown with explicit output
/convert report.docx notes.md            # -> notes.md

# Markdown to PDF
/convert README.md README.pdf            # -> README.pdf
```

### Prerequisites

Install one or more conversion tools:
- `markitdown`: `pip install markitdown`
- `pandoc`: Install from package manager
- `typst`: Install for Markdown to PDF (alternative to pandoc)
