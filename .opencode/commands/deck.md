---
description: Generate YC-style investor pitch decks in Typst
allowed-tools: Skill, Bash(test:*), Bash(dirname:*), Bash(basename:*), Bash(pwd:*), Read
argument-hint: PROMPT_OR_PATH [OUTPUT_PATH] [--theme simple|metropolis|stargazer] [--slides N]
---

# /deck Command

Generate 10-slide investor pitch decks in Typst format using YC best practices and the touying slide package.

## Arguments

- `$1` - Prompt or source file path (required): Either a text description of your startup OR a path to a file containing startup information
- `$2` - Output file path (optional, defaults to pitch-deck.typ or derived from source)
- `--theme` - Touying theme: `simple` (default), `metropolis`, `dewdrop`, `university`, `stargazer`
- `--slides` - Number of slides (optional, default 10)

## Usage Examples

```bash
# Generate from a prompt
/deck "We are Acme AI, an enterprise LLM platform founded by ex-Google engineers. We've grown 300% MoM."

# Generate from a file
/deck startup-info.md

# Generate with output path
/deck "Brief startup description" pitch.typ

# Generate with theme
/deck company-overview.md deck.typ --theme metropolis

# Generate from file with custom slide count
/deck detailed-info.md --slides 12
```

## Input Formats

### Prompt Input
Provide a text description of your startup:
- Company name and what you do
- Problem you solve
- Your solution
- Traction metrics
- Team background
- Funding ask

### File Input
Provide a path to a markdown, text, or JSON file containing:
- Startup overview document
- Investment memo
- Company description
- Pitch notes

The agent will extract relevant information and map it to the YC 10-slide structure.

## Output

Generates a `.typ` file with:
- Touying 0.6.3 imports and theme setup
- 10 slides following YC structure (Title, Problem, Solution, Traction, Why Us, Business Model, Market, Team, Ask, Closing)
- Speaker notes for each slide
- `[TODO: ...]` placeholders for missing information
- Ready for compilation with `typst compile`

## Execution

### CHECKPOINT 1: GATE IN

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Parse Arguments**
   ```bash
   input=""
   output_path=""
   theme="simple"
   slide_count="10"

   # First positional argument is input (prompt or path)
   input="$1"
   shift

   # Parse remaining arguments
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --theme)
         theme="$2"
         shift 2
         ;;
       --slides)
         slide_count="$2"
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

   # Validate input provided
   if [ -z "$input" ]; then
     echo "Error: Input required (prompt or file path)"
     echo "Usage: /deck PROMPT_OR_PATH [OUTPUT_PATH] [--theme NAME] [--slides N]"
     exit 1
   fi
   ```

3. **Determine Input Type**
   ```bash
   prompt=""
   source_path=""

   # Check if input is an existing file
   if [ -f "$input" ]; then
     source_path="$input"
     # Convert to absolute path if relative
     if [[ "$source_path" != /* ]]; then
       source_path="$(pwd)/$source_path"
     fi
   else
     # Treat as prompt text
     prompt="$input"
   fi
   ```

4. **Determine Output Path** (if not provided)
   ```bash
   if [ -z "$output_path" ]; then
     if [ -n "$source_path" ]; then
       source_dir=$(dirname "$source_path")
       source_base=$(basename "$source_path" | sed 's/\.[^.]*$//')
       output_path="${source_dir}/${source_base}-deck.typ"
     else
       output_path="$(pwd)/pitch-deck.typ"
     fi
   fi

   # Convert output to absolute path if relative
   if [[ "$output_path" != /* ]]; then
     output_path="$(pwd)/$output_path"
   fi
   ```

5. **Validate Theme**
   ```bash
   case "$theme" in
     simple|metropolis|dewdrop|university|stargazer)
       ;; # Valid
     *)
       echo "Error: Unknown theme: $theme"
       echo "Supported themes: simple, metropolis, dewdrop, university, stargazer"
       exit 1
       ;;
   esac
   ```

6. **Validate Slide Count**
   ```bash
   if ! [[ "$slide_count" =~ ^[0-9]+$ ]] || [ "$slide_count" -lt 5 ] || [ "$slide_count" -gt 20 ]; then
     echo "Error: Slide count must be between 5 and 20"
     exit 1
   fi
   ```

**ABORT** if no input provided or theme is invalid.

**On GATE IN success**: Arguments validated. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 passes, immediately invoke the Skill tool.

**Invoke the Skill tool NOW** with:
```
skill: "skill-deck"
args: "prompt={prompt} source_path={source_path} output_path={output_path} theme={theme} slide_count={slide_count} session_id={session_id}"
```

The skill will spawn the deck-agent to generate the pitch deck.

**On DELEGATE success**: Generation attempted. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

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

4. **Verify Touying Import Present**
   ```bash
   if ! grep -q '@preview/touying' "$output_path"; then
     echo "Warning: Output missing touying import"
   fi
   ```

**On GATE OUT success**: Output verified.

### CHECKPOINT 3: COMMIT

Git commit is **optional** for standalone generation.

Only commit if:
- User explicitly requests it
- Generation is part of a task workflow

```bash
# Only if commit requested
git add "$output_path"
git commit -m "$(cat <<'EOF'
deck: generate pitch deck

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

**Success**:
```
Pitch deck generated!

Output: {output_path}
Theme:  {theme}
Slides: {slide_count}
TODOs:  {slides_with_todos} slides need content

Input:  {input_type: prompt_only|file_only|prompt_and_file}

Compile with: typst compile {output_path}

Status: generated
```

**Failed**:
```
Pitch deck generation failed.

Error: {error_message}

Recommendation: {recommendation from error}
```

## Error Handling

### GATE IN Failure

**No input provided**:
```
Error: Input required (prompt or file path)

Usage: /deck PROMPT_OR_PATH [OUTPUT_PATH] [--theme NAME] [--slides N]

Examples:
  /deck "We are Acme, building X for Y..."
  /deck startup-info.md
  /deck company.md deck.typ --theme metropolis
```

**Invalid theme**:
```
Error: Unknown theme: {theme}

Supported themes: simple, metropolis, dewdrop, university, stargazer
```

**Invalid slide count**:
```
Error: Slide count must be between 5 and 20
```

### DELEGATE Failure

**Source file not found**:
```
Error: Source file not found: {path}

Please verify the file path and try again.
```

**Empty input**:
```
Error: No content found in input.

Provide either:
- A text prompt describing your startup
- A file path to a document with startup information
```

### GATE OUT Failure

**Output file missing**:
```
Error: Failed to create output file.

Check write permissions for: {output_path}
```
