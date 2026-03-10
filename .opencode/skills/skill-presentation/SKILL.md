---
name: skill-presentation
description: Presentation extraction and slide generation routing
allowed-tools: Task
---

# Presentation Skill

Thin wrapper that routes presentation operations to the `presentation-agent`.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User explicitly runs `/slides` command
- User requests presentation conversion in conversation

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Convert presentation to Beamer"
- "Extract slides from PowerPoint"
- "Generate Polylux slides"
- "Create Touying presentation"
- "Convert PPTX to LaTeX"

**File extension detection**:
- Source file has extension: `.pptx`, `.ppt`
- Target mentions: "Beamer", "slides", ".tex", "Polylux", "Touying", ".typ"

**Task description keywords**:
- "presentation conversion"
- "PowerPoint to LaTeX"
- "slide extraction"
- "academic slides"

### When NOT to trigger

Do not invoke for:
- Document conversions (use skill-filetypes)
- Spreadsheet conversions (use skill-spreadsheet)
- Simple markdown extraction without slide formatting

---

## Execution

### 1. Input Validation

Validate required inputs:
- `source_path` - Must be provided and file must exist
- `output_path` - Optional, defaults to source dir with .tex extension
- `output_format` - Optional, defaults to "beamer"
- `theme` - Optional theme name

```bash
# Validate source exists
if [ ! -f "$source_path" ]; then
  return error "Source file not found: $source_path"
fi

# Validate source is presentation format
source_ext="${source_path##*.}"
case "$source_ext" in
  pptx|ppt|md) ;; # Valid
  *) return error "Not a presentation format: .$source_ext" ;;
esac

# Determine output path if not provided
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
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "source_path": "/absolute/path/to/presentation.pptx",
  "output_path": "/absolute/path/to/slides.tex",
  "output_format": "beamer",
  "theme": "metropolis",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "slides", "skill-presentation"]
  }
}
```

### 3. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "presentation-agent"
  - prompt: [Include source_path, output_path, output_format, theme, metadata]
  - description: "Convert {source_path} to {output_format} slides"
```

The agent will:
- Detect available tools (python-pptx, pandoc, markitdown)
- Extract presentation content
- Generate formatted slide output
- Extract and preserve speaker notes
- Return standardized JSON result

### 4. Return Validation

Validate return matches `subagent-return.md` schema:
- Status is one of: converted, partial, failed
- Summary is non-empty and <100 tokens
- Artifacts array present with output file path
- Metadata contains slide count

### 5. Return Propagation

Return validated result to caller without modification.

---

## Return Format

Expected successful return:
```json
{
  "status": "converted",
  "summary": "Successfully converted presentation.pptx to Beamer slides with 15 slides",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/slides.tex",
      "summary": "Beamer presentation with speaker notes"
    }
  ],
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "presentation-agent",
    "delegation_depth": 2,
    "tool_used": "python-pptx+pandoc",
    "slide_count": 15,
    "has_speaker_notes": true
  },
  "next_steps": "Review and compile slides"
}
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if source file not found or not a presentation.

### Unsupported Format
Return failed status with clear message about supported formats.

### Agent Errors
Pass through the agent's error return verbatim.

### Tool Not Available
Return failed status with installation instructions.
