---
description: Convert presentations to Beamer, Polylux, or Touying slides
allowed-tools: Skill, Bash(jq:*), Bash(test:*), Bash(dirname:*), Bash(basename:*), Read
argument-hint: SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying]
---

# /slides Command

Convert PowerPoint presentations to academic slide formats (Beamer, Polylux, Touying).

## Arguments

- `$1` - Source file path (required): PPTX file
- `$2` - Output file path (optional, inferred from source if not provided)
- `--format` - Output format: `beamer` (default), `polylux`, or `touying`
- `--theme` - Theme name (optional)

## Usage Examples

```bash
# PPTX to Beamer (default)
/slides presentation.pptx                # -> presentation.tex

# PPTX to Polylux (Typst)
/slides deck.pptx slides.typ --format polylux

# PPTX to Touying (Typst)
/slides talk.pptx talk.typ --format touying

# With theme
/slides conference.pptx conf.tex --format beamer --theme metropolis

# Absolute paths
/slides /path/to/file.pptx /output/dir/result.tex
```

## Supported Conversions

| Source | Target | Notes |
|--------|--------|-------|
| PPTX | Beamer | Uses python-pptx + pandoc |
| PPTX | Polylux | Uses python-pptx, generates Typst |
| PPTX | Touying | Uses python-pptx, generates Typst |
| PPTX | Markdown | Uses python-pptx or markitdown |
| Markdown | PPTX | Uses pandoc |

## Output Formats

### Beamer (LaTeX)
- Traditional academic presentation format
- Wide theme support (metropolis, Madrid, etc.)
- Supports overlays and animations
- Speaker notes via `\note{}` command

### Polylux (Typst)
- Typst-native slide package
- Simple, clean syntax
- Easy customization
- Good for quick slides

### Touying (Typst)
- Feature-rich Typst slide framework
- Multiple themes (simple, dewdrop, university)
- Advanced animations
- Better for complex presentations

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
   output_format="beamer"
   theme=""

   # Parse remaining arguments
   shift
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --format)
         output_format="$2"
         shift 2
         ;;
       --theme)
         theme="$2"
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
     echo "Usage: /slides SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying] [--theme NAME]"
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
     pptx|ppt|md)
       ;; # Valid presentation format
     *)
       echo "Error: Not a presentation format: .$source_ext"
       echo "Supported formats: pptx, ppt, md"
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
       beamer|latex|tex) output_path="${source_dir}/${source_base}.tex" ;;
       polylux|touying|typst|typ) output_path="${source_dir}/${source_base}.typ" ;;
       pptx) output_path="${source_dir}/${source_base}_generated.pptx" ;;
       *) output_path="${source_dir}/${source_base}.tex" ;;
     esac
   fi

   # Convert output to absolute path if relative
   if [[ "$output_path" != /* ]]; then
     output_path="$(pwd)/$output_path"
   fi
   ```

6. **Validate Output Format**
   ```bash
   case "$output_format" in
     beamer|latex|polylux|touying|typst|pptx)
       ;; # Valid
     *)
       echo "Error: Unknown output format: $output_format"
       echo "Supported formats: beamer, polylux, touying"
       exit 1
       ;;
   esac
   ```

**ABORT** if source file does not exist or format is unsupported.

**On GATE IN success**: Arguments validated. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 passes, immediately invoke the Skill tool.

**Invoke the Skill tool NOW** with:
```
skill: "skill-presentation"
args: "source_path={source_path} output_path={output_path} output_format={output_format} theme={theme} session_id={session_id}"
```

The skill will spawn the presentation-agent to perform the conversion.

**On DELEGATE success**: Conversion attempted. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts, metadata (with slide_count)

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
slides: convert {source_filename} to {output_format}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

**Success**:
```
Slide conversion complete!

Source: {source_path}
Output: {output_path}
Format: {output_format}
Slides: {slide_count}
Notes:  {has_speaker_notes ? "Included" : "None"}

Tool used: {tool from metadata}

Status: converted
```

**Failed**:
```
Slide conversion failed.

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

**Not a presentation**:
```
Error: Not a presentation format: .{ext}

Supported formats: pptx, ppt, md
```

**Invalid output format**:
```
Error: Unknown output format: {format}

Supported formats: beamer, polylux, touying
```

### DELEGATE Failure

**Tool not available**:
```
Error: Required tools not available for presentation conversion.

Install with:
  pip install python-pptx

For Beamer output, also install:
  apt install pandoc  (or brew install pandoc)

Then retry: /slides {source_path}
```

**Corrupted file**:
```
Error: Failed to open PPTX file.

The file may be corrupted or not a valid PowerPoint file.
Try re-saving the file from PowerPoint.
```
