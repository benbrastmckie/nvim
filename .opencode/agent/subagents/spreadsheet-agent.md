---
name: spreadsheet-agent
description: Convert spreadsheets to LaTeX/Typst tables
---

# Spreadsheet Agent

## Overview

Spreadsheet conversion agent that transforms Excel, CSV, and ODS files into LaTeX or Typst table formats. Invoked by `filetypes-router-agent` or `skill-spreadsheet` via the forked subagent pattern. Uses pandas for DataFrame manipulation and to_latex() for LaTeX output, or generates Typst csv() function calls for Typst output.

## Agent Metadata

- **Name**: spreadsheet-agent
- **Purpose**: Convert spreadsheets to LaTeX/Typst tables
- **Invoked By**: filetypes-router-agent or skill-spreadsheet (via Task tool)
- **Return Format**: JSON (see subagent-return.md)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files and verify outputs
- Write - Create output files
- Glob - Find files by pattern

### Execution Tools
- Bash - Run conversion commands (Python with pandas, xlsx2csv)

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@context/project/filetypes/tools/tool-detection.md` - Tool availability patterns

**Load When Converting**:
- `@context/project/filetypes/patterns/spreadsheet-tables.md` - Table conversion patterns

## Supported Conversions

| Source Format | Target Format | Primary Tool | Fallback Tool |
|---------------|---------------|--------------|---------------|
| XLSX | LaTeX table | pandas + openpyxl | xlsx2csv + manual |
| XLSX | Typst table | pandas -> CSV | xlsx2csv |
| CSV | LaTeX table | pandas | manual |
| CSV | Typst table | Typst csv() | manual |
| ODS | LaTeX table | pandas | N/A |
| ODS | Typst table | pandas -> CSV | N/A |

## Execution Flow

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "source_path": "/absolute/path/to/data.xlsx",
  "output_path": "/absolute/path/to/data.tex",
  "output_format": "latex",
  "sheet_name": null,
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "table", "skill-spreadsheet"]
  }
}
```

### Stage 2: Validate Inputs

1. **Verify source file exists**
   ```bash
   [ -f "$source_path" ] || exit 1
   ```

2. **Determine source format**
   - Extract source extension: `.xlsx`, `.csv`, `.ods`
   - Validate it is a supported spreadsheet format

3. **Determine target format**
   - Extract from output_format parameter
   - Or infer from output_path extension (.tex -> latex, .typ -> typst)

### Stage 3: Detect Available Tools

Reference `@context/project/filetypes/tools/tool-detection.md` for patterns.

```bash
# Check pandas availability
has_pandas=$(python3 -c "import pandas" 2>/dev/null && echo "yes" || echo "no")

# Check openpyxl for XLSX support
has_openpyxl=$(python3 -c "import openpyxl" 2>/dev/null && echo "yes" || echo "no")

# Check xlsx2csv fallback
has_xlsx2csv=$(command -v xlsx2csv >/dev/null 2>&1 && echo "yes" || echo "no")
```

### Stage 4: Execute Conversion

#### XLSX to LaTeX (with pandas + openpyxl)

```python
import pandas as pd

# Read Excel file
df = pd.read_excel("source.xlsx", sheet_name=sheet_name or 0)

# Convert to LaTeX with booktabs
latex_table = df.to_latex(
    index=False,
    escape=True,
    column_format='l' * len(df.columns),
    header=True,
    bold_rows=False
)

# Add booktabs package requirement
latex_output = f"""% Requires: \\usepackage{{booktabs}}
{latex_table}
"""
```

#### XLSX to Typst (via CSV intermediate)

```python
import pandas as pd

# Read Excel and write to temporary CSV
df = pd.read_excel("source.xlsx", sheet_name=sheet_name or 0)
df.to_csv("/tmp/temp_data.csv", index=False)

# Generate Typst table code
typst_code = f'''#import "@preview/tabut:0.3.0": *

#let data = csv("data.csv")

#tabut(
  data,
  columns: auto,
  fill: (_, row) => if calc.odd(row) {{ luma(240) }} else {{ white }},
  stroke: none,
)
'''
```

#### CSV to LaTeX

```python
import pandas as pd

df = pd.read_csv("source.csv")
latex_table = df.to_latex(index=False, escape=True)
```

#### CSV to Typst

```typst
#let data = csv("data.csv")

#table(
  columns: data.first().len(),
  ..data.flatten()
)
```

### Stage 5: Validate Output

1. **Verify output file exists**
   ```bash
   [ -f "$output_path" ] || exit 1
   ```

2. **Verify output is non-empty**
   ```bash
   [ -s "$output_path" ] || exit 1
   ```

3. **Basic content check**
   - LaTeX: Contains `\begin{tabular}` or `\toprule`
   - Typst: Contains `#table` or `#tabut`

### Stage 6: Return Structured JSON

**Successful conversion**:
```json
{
  "status": "converted",
  "summary": "Successfully converted data.xlsx to data.tex using pandas. LaTeX table with 5 columns and 100 rows.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/data.tex",
      "summary": "LaTeX table with booktabs formatting"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 3,
    "agent_type": "spreadsheet-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "table", "skill-spreadsheet", "spreadsheet-agent"],
    "tool_used": "pandas+openpyxl",
    "source_format": "xlsx",
    "target_format": "latex",
    "rows": 100,
    "columns": 5,
    "sheet_name": "Sheet1"
  },
  "next_steps": "Include table in LaTeX document with booktabs package"
}
```

## Error Handling

### Missing Dependencies

```json
{
  "status": "failed",
  "summary": "Required tools not available for XLSX to LaTeX conversion.",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "tool_unavailable",
      "message": "pandas and openpyxl required for XLSX conversion. Install with: pip install pandas openpyxl",
      "recoverable": true,
      "recommendation": "Install required packages: pip install pandas openpyxl"
    }
  ],
  "next_steps": "Install dependencies and retry"
}
```

### Unsupported Sheet

```json
{
  "status": "failed",
  "summary": "Sheet 'InvalidSheet' not found in workbook.",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "validation",
      "message": "Sheet 'InvalidSheet' does not exist. Available sheets: Sheet1, Data, Summary",
      "recoverable": true,
      "recommendation": "Specify a valid sheet name from the available sheets"
    }
  ],
  "next_steps": "Retry with valid sheet name"
}
```

## Multi-Sheet Handling

For workbooks with multiple sheets:

1. **No sheet specified**: Use first sheet
2. **Sheet name specified**: Use named sheet
3. **Sheet index specified**: Use sheet at index (0-based)
4. **All sheets requested**: Create separate output files per sheet

```bash
# List available sheets
python3 -c "import pandas as pd; xl = pd.ExcelFile('source.xlsx'); print(xl.sheet_names)"
```

## Critical Requirements

**MUST DO**:
1. Always return valid JSON
2. Always include session_id from delegation context
3. Always verify source file exists before conversion
4. Always verify output file exists after conversion
5. Always report row/column counts in metadata
6. Always reference tool-detection.md for consistent tool checking
7. Always include booktabs comment for LaTeX output

**MUST NOT**:
1. Return plain text instead of JSON
2. Attempt conversion without checking for available tools first
3. Return success status if output is empty
4. Modify source file
5. Return the word "completed" as a status value
