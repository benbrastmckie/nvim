---
description: Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF)
allowed-tools: Skill, Bash(jq:*), Bash(test:*), Bash(dirname:*), Bash(basename:*), Read
argument-hint: SOURCE_PATH [OUTPUT_PATH]
---

# /convert Command

Convert documents between formats by delegating to the document converter skill/agent chain.

## Arguments

- `$1` - Source file path (required)
- `$2` - Output file path (optional, inferred from source if not provided)

## Usage Examples

```bash
# PDF to Markdown (output inferred)
/convert document.pdf                    # -> document.md

# DOCX to Markdown with explicit output
/convert report.docx notes.md            # -> notes.md

# Markdown to PDF
/convert README.md README.pdf            # -> README.pdf

# HTML to Markdown
/convert page.html page.md               # -> page.md

# Absolute paths
/convert /path/to/file.pdf /output/dir/result.md
```

## Supported Conversions

| Source | Target | Notes |
|--------|--------|-------|
| PDF | Markdown | Uses markitdown or pandoc |
| DOCX | Markdown | Uses markitdown or pandoc |
| XLSX | Markdown | Uses markitdown (tables) |
| PPTX | Markdown | Uses markitdown |
| HTML | Markdown | Uses markitdown or pandoc |
| Images | Markdown | Uses markitdown (OCR if available) |
| Markdown | PDF | Uses pandoc or typst |

## Execution

### CHECKPOINT 1: GATE IN

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Parse Arguments**
   ```bash
   source_path="$1"
   output_path="$2"

   # Validate source path provided
   if [ -z "$source_path" ]; then
     echo "Error: Source path required"
     echo "Usage: /convert SOURCE_PATH [OUTPUT_PATH]"
     exit 1
   fi

   # Convert to absolute path if relative
   if [[ "$source_path" != /* ]]; then
     source_path="$(pwd)/$source_path"
   fi
   ```

3. **Validate Source File Exists**
   ```bash
   if [ ! -f "$source_path" ]; then
     echo "Error: Source file not found: $source_path"
     exit 1
   fi
   ```

4. **Determine Output Path** (if not provided)
   ```bash
   if [ -z "$output_path" ]; then
     source_dir=$(dirname "$source_path")
     source_base=$(basename "$source_path" | sed 's/\.[^.]*$//')
     source_ext="${source_path##*.}"

     case "$source_ext" in
       pdf|docx|xlsx|pptx|html|htm|png|jpg|jpeg)
         output_path="${source_dir}/${source_base}.md"
         ;;
       md|markdown)
         output_path="${source_dir}/${source_base}.pdf"
         ;;
       *)
         echo "Error: Cannot infer output format for .$source_ext"
         echo "Please specify output path explicitly"
         exit 1
         ;;
     esac
   fi

   # Convert output to absolute path if relative
   if [[ "$output_path" != /* ]]; then
     output_path="$(pwd)/$output_path"
   fi
   ```

**ABORT** if source file does not exist or format is unsupported.

**On GATE IN success**: Arguments validated. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 passes, immediately invoke the Skill tool.

**Invoke the Skill tool NOW** with:
```
skill: "skill-document-converter"
args: "source_path={source_path} output_path={output_path} session_id={session_id}"
```

The skill will spawn the document-converter-agent to perform the conversion.

**On DELEGATE success**: Conversion attempted. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts

2. **Verify Output File Exists**
   ```bash
   if [ ! -f "$output_path" ]; then
     echo "Warning: Output file not created"
     # Return skill error details
   fi
   ```

3. **Verify Output Non-Empty**
   ```bash
   if [ ! -s "$output_path" ]; then
     echo "Warning: Output file is empty"
   fi
   ```

**On GATE OUT success**: Output verified.

### CHECKPOINT 3: COMMIT

Git commit is **optional** for standalone conversions.

Only commit if:
- User explicitly requests it
- Conversion is part of a task workflow

```bash
# Only if commit requested
git add "$output_path"
git commit -m "$(cat <<'EOF'
convert: {source_filename} -> {output_filename}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

**Success**:
```
Conversion complete!

Source: {source_path}
Output: {output_path}
Tool:   {tool_used from metadata}
Size:   {output_size}

Status: converted
```

**Partial (empty output)**:
```
Conversion completed with warnings.

Source: {source_path}
Output: {output_path}
Warning: Output may be incomplete or require manual review.

Status: extracted
```

**Failed**:
```
Conversion failed.

Source: {source_path}
Error: {error_message}

Recommendation: {recommendation from error}
```

## Error Handling

### GATE IN Failure

**Source not found**:
```
Error: Source file not found: {path}

Please verify the file path and try again.
```

**Unsupported format**:
```
Error: Cannot infer output format for .{ext}

Supported source formats: pdf, docx, xlsx, pptx, html, md
Please specify output path explicitly: /convert source.{ext} output.md
```

### DELEGATE Failure

**Tool not available**:
```
Error: No conversion tools available.

Required tools (install one):
  - markitdown: pip install markitdown
  - pandoc: apt install pandoc (or brew install pandoc)

Then retry: /convert {source_path}
```

**Conversion error**:
```
Error: Conversion failed.

Details: {error_message from agent}
Recommendation: {recommendation from agent}
```

### GATE OUT Failure

**Output not created**:
```
Warning: Output file was not created.

The conversion tool may have failed silently.
Check the source file for issues (encrypted, corrupted, etc.)
```
