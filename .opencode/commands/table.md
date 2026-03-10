---
description: Convert spreadsheets to LaTeX or Typst tables
allowed-tools: Skill, Bash(jq:*), Bash(test:*), Bash(dirname:*), Bash(basename:*), Read
argument-hint: SOURCE_PATH [OUTPUT_PATH] [--format latex|typst]
---

# /table Command

Convert spreadsheet files to LaTeX or Typst table format.

## Arguments

- `$1` - Source file path (required): XLSX, CSV, or ODS file
- `$2` - Output file path (optional, inferred from source if not provided)
- `--format` - Output format: `latex` (default) or `typst`
- `--sheet` - Sheet name for multi-sheet workbooks (optional)

## Usage Examples

```bash
# XLSX to LaTeX (default)
/table data.xlsx                         # -> data.tex

# XLSX to Typst
/table data.xlsx output.typ --format typst

# CSV to LaTeX with explicit output
/table budget.csv budget.tex --format latex

# Specific sheet from workbook
/table workbook.xlsx summary.tex --sheet "Q4 Data"

# Absolute paths
/table /path/to/file.xlsx /output/dir/result.tex
```

## Supported Conversions

| Source | Target | Notes |
|--------|--------|-------|
| XLSX | LaTeX | Uses pandas + openpyxl, booktabs format |
| XLSX | Typst | Uses pandas, generates csv() or tabut table |
| CSV | LaTeX | Uses pandas DataFrame.to_latex() |
| CSV | Typst | Uses Typst csv() function |
| ODS | LaTeX | Uses pandas |
| ODS | Typst | Uses pandas via CSV intermediate |

## Execution

### CHECKPOINT 1: GATE IN

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Parse Arguments**
   ```bash
   source_path="$1"
   output_path=""
   output_format="latex"
   sheet_name=""

   # Parse remaining arguments
   shift
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --format)
         output_format="$2"
         shift 2
         ;;
       --sheet)
         sheet_name="$2"
         shift 2
         ;;
       *)
         if [ -z "$output_path" ]; then
           output_path="$1"
         fi
         shift
         ;;
     esac
   done

   # Validate source path provided
   if [ -z "$source_path" ]; then
     echo "Error: Source path required"
     echo "Usage: /table SOURCE_PATH [OUTPUT_PATH] [--format latex|typst] [--sheet NAME]"
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

4. **Validate Source Format**
   ```bash
   source_ext="${source_path##*.}"
   case "$source_ext" in
     xlsx|xls|csv|ods)
       ;; # Valid spreadsheet format
     *)
       echo "Error: Not a spreadsheet format: .$source_ext"
       echo "Supported formats: xlsx, xls, csv, ods"
       exit 1
       ;;
   esac
   ```

5. **Determine Output Path** (if not provided)
   ```bash
   if [ -z "$output_path" ]; then
     source_dir=$(dirname "$source_path")
     source_base=$(basename "$source_path" | sed 's/\.[^.]*$//')

     case "$output_format" in
       latex|tex) output_path="${source_dir}/${source_base}.tex" ;;
       typst|typ) output_path="${source_dir}/${source_base}.typ" ;;
       *) output_path="${source_dir}/${source_base}.tex" ;;
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
skill: "skill-spreadsheet"
args: "source_path={source_path} output_path={output_path} output_format={output_format} sheet_name={sheet_name} session_id={session_id}"
```

The skill will spawn the spreadsheet-agent to perform the conversion.

**On DELEGATE success**: Conversion attempted. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts, metadata (with rows/columns)

2. **Verify Output File Exists**
   ```bash
   if [ ! -f "$output_path" ]; then
     echo "Warning: Output file not created"
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
table: convert {source_filename} to {output_format}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

**Success**:
```
Table conversion complete!

Source: {source_path}
Output: {output_path}
Format: {output_format}
Size:   {rows} rows x {columns} columns

Tool used: {tool from metadata}

Status: converted
```

**Failed**:
```
Table conversion failed.

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

**Not a spreadsheet**:
```
Error: Not a spreadsheet format: .{ext}

Supported formats: xlsx, xls, csv, ods
```

### DELEGATE Failure

**Tool not available**:
```
Error: Required tools not available for spreadsheet conversion.

Install with:
  pip install pandas openpyxl

Then retry: /table {source_path}
```

**Sheet not found**:
```
Error: Sheet '{sheet_name}' not found.

Available sheets: {list of sheets}
Retry with: /table {source_path} --sheet "Valid Sheet Name"
```
