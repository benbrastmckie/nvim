# Implementation Plan: Task #278

- **Task**: 278 - Create scrape-agent for PDF annotation extraction
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: Task #277 (research completed)
- **Research Inputs**: specs/278_create_scrape_agent/reports/01_meta-research.md
- **Artifacts**: plans/01_scrape-agent-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `.claude/extensions/filetypes/agents/scrape-agent.md` following the established `document-agent.md` pattern. The agent detects available PDF annotation tools (PyMuPDF, pypdf, pdfannots) with a fallback chain, extracts annotations with type filtering, and returns structured JSON matching the subagent-return.md schema.

### Research Integration

Task 277 determined the tool chain: PyMuPDF (fitz) is primary for best API and performance, pypdf is pure-Python fallback, pdfannots is CLI fallback for backwards compatibility, and pikepdf handles encrypted PDF preprocessing. The agent must detect all three and select the best available.

## Goals & Non-Goals

**Goals**:
- Create scrape-agent.md in `.claude/extensions/filetypes/agents/`
- Implement 6-stage execution flow matching document-agent.md pattern
- Support tool detection for pymupdf, pypdf, and pdfannots with fallback chain
- Support annotation type filtering (highlight, note, underline, strikeout, comment)
- Support markdown and JSON output formats
- Handle edge cases: encrypted PDFs (pikepdf decrypt), empty annotations, encoding errors
- Return valid JSON matching subagent-return.md schema

**Non-Goals**:
- OCR for image-only PDFs (out of scope)
- Modifying PDF annotations (read-only)
- Integration with filetypes-router-agent dispatch (handled in task 279/280)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| PyMuPDF API differences across versions | M | L | Use conservative API subset, document version requirements |
| Encrypted PDFs blocking extraction | M | M | Add pikepdf decrypt step before extraction |
| Empty annotation set appearing as failure | L | M | Distinguish empty-but-valid from extraction failure |
| Encoding issues in annotation text | L | M | Use UTF-8 with error replacement in Python code |

## Implementation Phases

### Phase 1: Create scrape-agent.md [NOT STARTED]

**Goal**: Write the complete scrape-agent definition file following document-agent.md structure exactly.

**Tasks**:
- [ ] Create file at `.claude/extensions/filetypes/agents/scrape-agent.md`
- [ ] Write YAML frontmatter with `name: scrape-agent` and description
- [ ] Write Overview section establishing agent purpose and invocation chain
- [ ] Write Agent Metadata section (name, purpose, invoked-by, return format)
- [ ] Write Allowed Tools section (Read, Write, Edit, Glob, Grep, Bash)
- [ ] Write Context References section pointing to tool-detection.md and subagent-return.md
- [ ] Write Supported Extraction section (annotation types table with tools)
- [ ] Write Stage 1: Parse Delegation Context (input JSON schema with pdf_path, output_path, annotation_types, output_format, metadata)
- [ ] Write Stage 2: Validate Inputs (file exists check, output path derivation, format validation)
- [ ] Write Stage 3: Detect Available Tools (pymupdf/pypdf/pdfannots checks with bash commands)
- [ ] Write Stage 4: Preprocess (pikepdf decrypt if encrypted, skip if not needed)
- [ ] Write Stage 5: Execute Extraction (Python inline for pymupdf/pypdf, CLI for pdfannots, with fallback chain)
- [ ] Write Stage 6: Format Output (markdown grouping by page, JSON structured output)
- [ ] Write Stage 7: Validate Output (file exists, non-empty, content check)
- [ ] Write Stage 8: Return Structured JSON (success/partial/failed schemas)
- [ ] Write Tool Selection Logic pseudocode
- [ ] Write Critical Requirements section (MUST DO / MUST NOT)
- [ ] Write Error Handling section (all error scenarios with JSON examples)

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/filetypes/agents/scrape-agent.md` - Create new file

**Verification**:
- File exists at the correct path
- YAML frontmatter is valid (name and description fields present)
- All 8 stages are documented
- Tool detection uses `command -v` and `python3 -c "import fitz"` patterns
- Return JSON examples match subagent-return.md schema (status, summary, artifacts, metadata, next_steps)
- Error handling covers: file not found, no tools available, encrypted PDF, empty annotations, encoding error

## File Content Specification

### Delegation Context Input Schema

```json
{
  "pdf_path": "/absolute/path/to/document.pdf",
  "output_path": "/absolute/path/to/annotations.md",
  "annotation_types": ["highlight", "note", "underline"],
  "output_format": "markdown",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "scrape", "skill-scrape", "scrape-agent"]
  }
}
```

### Tool Detection Commands

```bash
# Primary: PyMuPDF
python3 -c "import fitz" 2>/dev/null && echo "available"

# Fallback 1: pypdf
python3 -c "import pypdf" 2>/dev/null && echo "available"

# Fallback 2: pdfannots CLI
command -v pdfannots >/dev/null 2>&1 && echo "available"

# Preprocess: pikepdf (for encrypted PDFs)
python3 -c "import pikepdf" 2>/dev/null && echo "available"
```

### PyMuPDF Extraction Pattern (inline Python)

```python
import fitz
import json

doc = fitz.open(pdf_path)
annotations = []
annot_types = {"highlight": 8, "underline": 9, "strikeout": 10, "note": 0}

for page_num, page in enumerate(doc, 1):
    for annot in page.annots():
        annot_type = annot.type[1].lower()
        if not annotation_types or annot_type in annotation_types:
            annotations.append({
                "type": annot_type,
                "page": page_num,
                "content": annot.info.get("content", ""),
                "author": annot.info.get("title", ""),
                "color": annot.colors.get("stroke", None),
                "rect": list(annot.rect)
            })

doc.close()
```

### pypdf Fallback Pattern

```python
import pypdf
import json

reader = pypdf.PdfReader(pdf_path)
annotations = []

for page_num, page in enumerate(reader.pages, 1):
    if "/Annots" in page:
        for annot in page["/Annots"]:
            obj = annot.get_object()
            annot_type = str(obj.get("/Subtype", "")).lstrip("/").lower()
            if not annotation_types or annot_type in annotation_types:
                annotations.append({
                    "type": annot_type,
                    "page": page_num,
                    "content": str(obj.get("/Contents", "")),
                    "author": str(obj.get("/T", "")),
                })
```

### Status Values

- `scraped` - Successful extraction with annotations found
- `empty` - Extraction succeeded but no annotations found (not a failure)
- `partial` - Some annotations extracted but errors encountered
- `failed` - Extraction could not complete

### Return JSON Schema

```json
{
  "status": "scraped",
  "summary": "Extracted 42 annotations from document.pdf using pymupdf. 28 highlights, 10 notes, 4 underlines.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/annotations.md",
      "summary": "Annotation extraction in markdown format"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 3,
    "agent_type": "scrape-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "scrape", "skill-scrape", "scrape-agent"],
    "tool_used": "pymupdf",
    "annotation_count": 42,
    "annotation_types_found": ["highlight", "note", "underline"],
    "page_count": 15,
    "output_format": "markdown"
  },
  "next_steps": "Review annotations at output path"
}
```

## Testing & Validation

- [ ] File created at `.claude/extensions/filetypes/agents/scrape-agent.md`
- [ ] YAML frontmatter valid (name, description)
- [ ] All 8 execution stages documented with clear inputs/outputs
- [ ] Tool detection covers all three tools (pymupdf, pypdf, pdfannots)
- [ ] pikepdf decrypt preprocessing documented
- [ ] Both output formats (markdown, JSON) have implementation examples
- [ ] All annotation types handled (highlight, note, underline, strikeout, comment)
- [ ] Error cases all have JSON return examples
- [ ] Return JSON uses status "scraped" not "completed"
- [ ] Critical Requirements lists MUST NOT use "completed" status

## Artifacts & Outputs

- `.claude/extensions/filetypes/agents/scrape-agent.md` - New agent definition

## Rollback/Contingency

If implementation reveals the document-agent.md pattern does not adapt cleanly to annotation extraction, fall back to a simpler two-stage approach (detect tool, run extraction) without preprocessing. The annotation type filtering can be post-processed from full output rather than using tool-native filtering.
