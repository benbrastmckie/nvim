---
name: skill-spreadsheet
description: Spreadsheet to table conversion routing
allowed-tools: Task
---

# Spreadsheet Skill

Thin wrapper that routes spreadsheet-to-table operations to the `spreadsheet-agent`.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User explicitly runs `/table` command
- User requests spreadsheet to table conversion in conversation

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Convert spreadsheet to table"
- "Create LaTeX table from Excel"
- "Import data from XLSX"
- "Generate Typst table from CSV"
- "Extract table data from spreadsheet"

**File extension detection**:
- Source file has extension: `.xlsx`, `.xls`, `.csv`, `.ods`
- Target mentions: "LaTeX table", ".tex", "Typst table", ".typ"

**Task description keywords**:
- "spreadsheet conversion"
- "Excel to table"
- "data table"
- "tabular data"

### When NOT to trigger

Do not invoke for:
- Document conversions (use skill-filetypes)
- Presentation conversions (use skill-presentation)
- Reading spreadsheets without table generation
- Spreadsheets already in LaTeX/Typst format

---

## Execution

### 1. Input Validation

Validate required inputs:
- `source_path` - Must be provided and file must exist
- `output_path` - Optional, defaults to source dir with .tex extension
- `output_format` - Optional, defaults to "latex"

```bash
# Validate source exists
if [ ! -f "$source_path" ]; then
  return error "Source file not found: $source_path"
fi

# Validate source is spreadsheet format
source_ext="${source_path##*.}"
case "$source_ext" in
  xlsx|xls|csv|ods) ;; # Valid
  *) return error "Not a spreadsheet format: .$source_ext" ;;
esac

# Determine output path if not provided
if [ -z "$output_path" ]; then
  source_dir=$(dirname "$source_path")
  source_base=$(basename "$source_path" | sed 's/\.[^.]*$//')

  case "$output_format" in
    latex|tex) output_path="${source_dir}/${source_base}.tex" ;;
    typst|typ) output_path="${source_dir}/${source_base}.typ" ;;
    *) output_path="${source_dir}/${source_base}.tex" ;;
  esac
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "source_path": "/absolute/path/to/data.xlsx",
  "output_path": "/absolute/path/to/data.tex",
  "output_format": "latex",
  "sheet_name": null,
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "table", "skill-spreadsheet"]
  }
}
```

### 3. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "spreadsheet-agent"
  - prompt: [Include source_path, output_path, output_format, sheet_name, metadata]
  - description: "Convert {source_path} to {output_format} table"
```

The agent will:
- Detect available tools (pandas, openpyxl, xlsx2csv)
- Read spreadsheet data
- Generate formatted table output
- Return standardized JSON result

### 4. Return Validation

Validate return matches `subagent-return.md` schema:
- Status is one of: converted, partial, failed
- Summary is non-empty and <100 tokens
- Artifacts array present with output file path
- Metadata contains row/column counts

### 5. Return Propagation

Return validated result to caller without modification.

---

## Return Format

Expected successful return:
```json
{
  "status": "converted",
  "summary": "Successfully converted data.xlsx to LaTeX table using pandas",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/data.tex",
      "summary": "LaTeX table with 5 columns, 100 rows"
    }
  ],
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "spreadsheet-agent",
    "delegation_depth": 2,
    "tool_used": "pandas+openpyxl",
    "rows": 100,
    "columns": 5
  },
  "next_steps": "Include table in document"
}
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if source file not found or not a spreadsheet.

### Unsupported Format
Return failed status with clear message about supported formats.

### Agent Errors
Pass through the agent's error return verbatim.

### Tool Not Available
Return failed status with installation instructions.
