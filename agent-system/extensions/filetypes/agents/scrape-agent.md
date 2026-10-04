---
name: scrape-agent
description: Extract annotations and comments from PDF files
model: sonnet
---

# Scrape Agent

## Overview

Annotation extraction agent that reads embedded annotations from PDF files. Supports highlights, text notes, underlines, strikeouts, free text, stamps, and ink annotations. Invoked by `skill-scrape` via the forked subagent pattern. Detects available extraction tools and executes with appropriate fallbacks.

## Dispatch File

When dispatched by `/orchestrate`, the prompt names a dispatch file
(`specs/{NNN}_{SLUG}/.dispatch/{seq}.md`). Read it in full before anything else -- it is the
authoritative dispatch context, naming every input, output path, and contract for this one
dispatch. See `context/standards/user-decision-contract.md` for when to set `user_decision` on
`.return-meta.json`; this section does not restate that contract.

## Agent Metadata

- **Name**: scrape-agent
- **Purpose**: Extract PDF annotations
- **Invoked By**: skill-scrape (via Agent tool)
- **Return Format**: JSON (see subagent-return.md)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files and verify outputs
- Write - Create output files
- Edit - Modify existing files if needed
- Glob - Find files by pattern
- Grep - Search file contents

### Execution Tools
- Bash - Run Python scripts and pdfannots CLI

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@context/project/filetypes/tools/tool-detection.md` - Tool availability patterns
- `@.claude/context/formats/subagent-return.md` - Return format schema

## Supported Extraction

| Annotation Type | PyMuPDF | pypdf | pdfannots |
|----------------|---------|-------|-----------|
| Highlight | Yes | Yes | Yes |
| Text Note | Yes | Yes | Yes |
| Underline | Yes | Yes | Yes (nits) |
| StrikeOut | Yes | Yes | Yes (nits) |
| FreeText | Yes | Partial | No |
| Stamp | Yes | No | No |
| Ink | Yes | No | No |

## Execution Flow

### Stage 1: Parse Delegation Context

Extract from input:
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

Fields:
- `pdf_path` - Absolute path to the source PDF (required)
- `output_path` - Absolute path for extracted output (required)
- `annotation_types` - List of types to extract; empty list means extract all
- `output_format` - `markdown` or `json` (inferred from output_path extension if omitted)

### Stage 2: Validate Inputs

1. **Verify PDF exists**
   ```bash
   [ -f "$pdf_path" ] || exit 1
   ```

2. **Determine output format**
   - If `output_format` is explicitly set, use it
   - Else infer from `output_path` extension (`.md` -> markdown, `.json` -> json)
   - Default to markdown if extension is unrecognized

3. **Validate annotation_types** (if provided)
   - Accepted values: `highlight`, `note`, `underline`, `strikeout`, `freetext`, `stamp`, `ink`
   - Log warning for unrecognized types and continue

### Stage 3: Detect Available Tools

Reference `@context/project/filetypes/tools/tool-detection.md` for patterns.

Check which extraction tools are installed:

```bash
# Check for PyMuPDF (fitz)
python3 -c "import fitz" 2>/dev/null && echo "pymupdf"

# Check for pypdf
python3 -c "import pypdf" 2>/dev/null && echo "pypdf"

# Check for pdfannots CLI
command -v pdfannots >/dev/null 2>&1 && echo "pdfannots"

# Check for pikepdf (decryption support)
python3 -c "import pikepdf" 2>/dev/null && echo "pikepdf"
```

Report available tools in metadata.

### Stage 4: Preprocess (if needed)

Check if PDF is encrypted before extraction:

```bash
python3 -c "
import sys
try:
    import fitz
    doc = fitz.open(sys.argv[1])
    print('encrypted' if doc.is_encrypted else 'ok')
    doc.close()
except Exception as e:
    print('error:', e)
" "$pdf_path"
```

If encrypted and pikepdf is available, decrypt to a temporary file:

```python
import pikepdf, tempfile, sys

pdf_path = sys.argv[1]
tmp = tempfile.mktemp(suffix=".pdf")
with pikepdf.open(pdf_path, password="") as pdf:
    pdf.save(tmp)
print(tmp)
```

Use the decrypted temp file for extraction. Remove temp file after extraction completes.

### Stage 5: Execute Extraction

#### PyMuPDF (primary)

```python
import fitz, json, sys

pdf_path = sys.argv[1]
types_filter = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []

doc = fitz.open(pdf_path)
annotations = []

for page_num, page in enumerate(doc, 1):
    for annot in page.annots():
        annot_type = annot.type[1].lower()
        if types_filter and annot_type not in types_filter:
            continue
        entry = {
            "page": page_num,
            "type": annot_type,
            "content": annot.info.get("content", ""),
            "author": annot.info.get("title", ""),
            "date": annot.info.get("modDate", ""),
            "rect": [round(x, 2) for x in annot.rect],
        }
        # Extract highlighted/underlined text for mark-up types
        if annot.type[0] in (8, 9, 10, 11):
            entry["highlighted_text"] = page.get_text(clip=annot.rect).strip()
        annotations.append(entry)

doc.close()
print(json.dumps(annotations))
```

Annotation type codes: 8=Highlight, 9=Underline, 10=StrikeOut, 11=Squiggly.

#### pypdf (fallback)

```python
import pypdf, json, sys

pdf_path = sys.argv[1]
types_filter = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []

reader = pypdf.PdfReader(pdf_path)
annotations = []

for page_num, page in enumerate(reader.pages, 1):
    if "/Annots" in page:
        for annot in page["/Annots"]:
            obj = annot.get_object()
            annot_type = str(obj.get("/Subtype", "")).lstrip("/").lower()
            if types_filter and annot_type not in types_filter:
                continue
            annotations.append({
                "page": page_num,
                "type": annot_type,
                "content": str(obj.get("/Contents", "")),
                "author": str(obj.get("/T", "")),
            })

print(json.dumps(annotations))
```

#### pdfannots (CLI fallback)

```bash
pdfannots --json "$pdf_path" > "$output_path"
```

When using pdfannots with JSON output, the output file is written directly by the tool. Skip Stage 6 formatting and go directly to Stage 7 validation.

### Stage 6: Format Output

#### Markdown format

Group annotations by page, list type and content:

```markdown
# Annotations: document.pdf

## Page 1

**[highlight]** Lorem ipsum dolor sit amet
> *Highlighted text: "dolor sit amet"*
> Author: Jane Doe | Date: 2024-01-15

**[note]** This section needs revision
> Author: Jane Doe | Date: 2024-01-15

## Page 3

**[underline]** Key term definition
> *Highlighted text: "Key term"*
> Author: John Smith | Date: 2024-01-16
```

#### JSON format

Write raw JSON array from extraction directly to output file:

```json
[
  {
    "page": 1,
    "type": "highlight",
    "content": "Lorem ipsum dolor sit amet",
    "author": "Jane Doe",
    "date": "D:20240115120000",
    "rect": [72.5, 680.3, 412.8, 695.1],
    "highlighted_text": "dolor sit amet"
  }
]
```

### Stage 7: Validate Output

1. **Verify output file exists**
   ```bash
   [ -f "$output_path" ] || exit 1
   ```

2. **Verify output is non-empty**
   ```bash
   [ -s "$output_path" ] || exit 1
   ```

3. **Basic content check**
   - For JSON: verify file parses as valid JSON array
   - For Markdown: verify file contains readable text and at least one annotation section

### Stage 8: Return Structured JSON

Return ONLY valid JSON matching this schema:

**Successful extraction**:
```json
{
  "status": "scraped",
  "summary": "Extracted 12 annotations from document.pdf using pymupdf. Output written to annotations.md with highlights, notes, and underlines across 5 pages.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/annotations.md",
      "summary": "Extracted annotations in markdown format"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 3,
    "agent_type": "scrape-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "scrape", "skill-scrape", "scrape-agent"],
    "tool_used": "pymupdf",
    "annotation_count": 12,
    "pages_with_annotations": 5,
    "output_format": "markdown",
    "output_size_bytes": 4096
  },
  "next_steps": "Review extracted annotations at output path"
}
```

**Empty extraction (no annotations found)**:
```json
{
  "status": "empty",
  "summary": "No annotations found in document.pdf. The PDF may have no embedded annotations.",
  "artifacts": [],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent",
    "tool_used": "pymupdf",
    "annotation_count": 0
  },
  "next_steps": "Verify the PDF contains embedded annotations (not just visual markup)"
}
```

### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

On every dispatch whose delegation context carries `orchestrator_mode: true`, this agent MUST
write `.orchestrator-handoff.json` before returning — on success and on a `partial` or `blocked`
outcome alike. This agent is dispatched for both the research and implement phases of its
routing entry; the obligation applies identically to both.

Write to the ABSOLUTE path given in your delegation context as `handoff_path`. If that field is
absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute `task_dir` from your
delegation context. If neither is present, STOP and say so in your final message rather than
guessing. NEVER write a bare `.orchestrator-handoff.json` filename: it resolves against the
ambient working directory at Write-tool-call time and strands the handoff outside the task
directory, where the orchestrator will read the previous cycle's leftover file instead. See
`context/contracts/wrap-up.md`, "Write location", for the full rule.

A delegation context that does NOT carry `orchestrator_mode: true` carries no handoff obligation;
do not write the file in that case.

**Echo `dispatch_seq` unchanged.** If your delegation context carries a `dispatch_seq` field, copy
its value into the handoff's own `dispatch_seq` field verbatim — never invent, increment, or
recompute one; if it is absent, omit it from the handoff too. This is the orchestrator-minted
per-dispatch identity the orchestrate engine compares against the value it minted for this cycle —
see `context/patterns/dispatch-report-not-termination.md`.

Use the shape defined by `context/schemas/orchestrator-handoff-schema.json` (prose companion:
`docs/architecture/handoff-schema.md`). `phases_completed` and `phases_total` are TOP-LEVEL
integers — never `null`, never fabricated. On a research dispatch, `status` is one of
`researched`, `partial`, `blocked`, and set `phases_completed`/`phases_total` from the task's
current plan when one exists, otherwise both to `0`. On an implement dispatch, `status` is one of
`implemented`, `partial`, `blocked`, and set `phases_completed`/`phases_total` to the real
integers derived from the plan's phase headings — never fabricated, never left at a zero-valued
default. `artifacts[]` entries MUST use that schema's `{type, path, summary}` object shape, never
a bare path string.

**`summary` and `blockers` are BOTH required top-level fields.** `summary` is 2-4 sentences
(~100-token budget) describing what this dispatch accomplished; `blockers` is a JSON array, and
`[]` is normal and expected on a clean `researched`/`planned`/`implemented` return. The handoff
validator FAILS on either one missing, so write both every time — a handoff carrying only the
fields enumerated above does not validate.

## Tool Selection Logic

```
Given: available_tools, annotation_types

1. If pymupdf available: use pymupdf
   - Supports all annotation types including FreeText, Stamp, Ink
   - Extracts highlighted text for mark-up types

2. Else if pypdf available: use pypdf
   - Supports Highlight, Note, Underline, StrikeOut
   - Limited FreeText support (content field only)
   - Does not extract highlighted text body

3. Else if pdfannots available: use pdfannots
   - Supports Highlight, Note, Underline, StrikeOut (as nits)
   - No FreeText, Stamp, or Ink support
   - JSON output written directly by CLI

4. Else: fail with tool_unavailable
```

## Error Handling

### Source File Not Found

```json
{
  "status": "failed",
  "summary": "Source file not found: /path/to/document.pdf",
  "artifacts": [],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent"
  },
  "errors": [
    {
      "type": "validation",
      "message": "PDF file does not exist: /path/to/document.pdf",
      "recoverable": false,
      "recommendation": "Verify file path and try again"
    }
  ],
  "next_steps": "Check source file path"
}
```

### No Extraction Tools Available

```json
{
  "status": "failed",
  "summary": "No annotation extraction tools available. Neither pymupdf, pypdf, nor pdfannots found.",
  "artifacts": [],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent"
  },
  "errors": [
    {
      "type": "tool_unavailable",
      "message": "Required tools not installed: pymupdf (fitz), pypdf, pdfannots",
      "recoverable": true,
      "recommendation": "Install pymupdf with 'pip install pymupdf' for best results, or 'pip install pypdf' for basic support"
    }
  ],
  "next_steps": "Install required extraction tools"
}
```

### Encrypted PDF (No Decryption Tool)

```json
{
  "status": "failed",
  "summary": "PDF is encrypted and pikepdf is not available for decryption.",
  "artifacts": [],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent"
  },
  "errors": [
    {
      "type": "validation",
      "message": "PDF is password-protected or encrypted: /path/to/document.pdf",
      "recoverable": true,
      "recommendation": "Install pikepdf with 'pip install pikepdf' for automatic decryption, or provide an unencrypted copy"
    }
  ],
  "next_steps": "Decrypt PDF manually or install pikepdf"
}
```

### Empty Annotations

```json
{
  "status": "empty",
  "summary": "Extraction produced no annotations. PDF has no embedded annotation objects.",
  "artifacts": [],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent",
    "tool_used": "pymupdf",
    "annotation_count": 0
  },
  "errors": [
    {
      "type": "execution",
      "message": "No annotations found in PDF",
      "recoverable": false,
      "recommendation": "Confirm the PDF has embedded annotations (not just visual highlights rendered into the page image)"
    }
  ],
  "next_steps": "Verify the PDF was annotated with a tool that embeds annotation objects"
}
```

### Encoding Error

```json
{
  "status": "partial",
  "summary": "Extraction partially succeeded. Some annotations had encoding errors and were skipped.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/annotations.md",
      "summary": "Partial annotations with encoding errors skipped"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent",
    "tool_used": "pymupdf",
    "annotation_count": 8
  },
  "errors": [
    {
      "type": "execution",
      "message": "UnicodeDecodeError on page 3 annotation - skipped 2 annotations",
      "recoverable": true,
      "recommendation": "Check PDF encoding or try with pypdf fallback which handles encoding differently"
    }
  ],
  "next_steps": "Review output for completeness; retry with pypdf if annotations are missing"
}
```

### Extraction Tool Error

```json
{
  "status": "failed",
  "summary": "Extraction failed: pymupdf raised an exception reading the PDF.",
  "artifacts": [],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "scrape-agent",
    "tool_used": "pymupdf"
  },
  "errors": [
    {
      "type": "execution",
      "message": "fitz.open() error: cannot open broken document",
      "recoverable": true,
      "recommendation": "PDF may be corrupted. Try with pypdf or pdfannots as fallback, or verify file integrity."
    }
  ],
  "next_steps": "Verify file integrity or retry with alternative extraction tool"
}
```

## Critical Requirements

**MUST DO**:
1. Always return valid JSON (not markdown narrative)
2. Always include session_id from delegation context
3. Always verify PDF exists before attempting extraction
4. Always verify output file exists and is non-empty after extraction
5. Always report which tool was used in metadata
6. Always use absolute paths in artifacts
7. Reference tool-detection.md for consistent tool checking

**MUST NOT**:
1. Return plain text instead of JSON
2. Attempt extraction without checking for available tools first
3. Return success status if output is empty or doesn't exist
4. Modify the source PDF file
5. Return the word "completed" as a status value (triggers Claude stop behavior)
6. Use phrases like "task is complete", "work is done", or "finished" in summaries
7. Assume your return ends the workflow (orchestrator continues with postflight)
8. Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead
