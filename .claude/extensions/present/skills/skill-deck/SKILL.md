---
name: skill-deck
description: Generate YC-style investor pitch decks in Typst
allowed-tools: Task
---

# Deck Skill

Thin wrapper that routes pitch deck generation requests to the `deck-agent`.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User explicitly runs `/deck` command
- User requests pitch deck generation in conversation

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Generate pitch deck"
- "Create investor deck"
- "Build presentation for investors"
- "Make YC-style slides"
- "Create startup pitch"

**Target mentions**:
- "pitch deck"
- "investor presentation"
- "seed round slides"
- "fundraising deck"
- "touying pitch"

**Task description keywords**:
- "pitch deck generation"
- "investor slides"
- "startup presentation"
- "YC deck"

### When NOT to trigger

Do not invoke for:
- Converting existing presentations (use skill-presentation)
- General slide conversion from PPTX (use skill-presentation)
- Document format conversions (use skill-filetypes)
- Creating non-investor presentation slides

---

## Execution

### 1. Input Validation

Validate required inputs:
- At least one of: `prompt` (text description) OR `source_path` (file path)
- `output_path` - Optional, defaults based on input
- `theme` - Optional, defaults to "simple"
- `slide_count` - Optional, defaults to 10

```bash
# Validate at least one input source
if [ -z "$prompt" ] && [ -z "$source_path" ]; then
  return error "Either a prompt or source file path is required"
fi

# If source_path provided, validate it exists
if [ -n "$source_path" ] && [ ! -f "$source_path" ]; then
  return error "Source file not found: $source_path"
fi

# Convert source_path to absolute if relative
if [ -n "$source_path" ] && [[ "$source_path" != /* ]]; then
  source_path="$(pwd)/$source_path"
fi

# Determine output path if not provided
if [ -z "$output_path" ]; then
  if [ -n "$source_path" ]; then
    source_dir=$(dirname "$source_path")
    source_base=$(basename "$source_path" | sed 's/\.[^.]*$//')
    output_path="${source_dir}/${source_base}-deck.typ"
  else
    output_path="$(pwd)/pitch-deck.typ"
  fi
fi

# Convert output_path to absolute if relative
if [[ "$output_path" != /* ]]; then
  output_path="$(pwd)/$output_path"
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "prompt": "Startup description from user",
  "source_path": "/absolute/path/to/startup-info.md",
  "output_path": "/absolute/path/to/pitch-deck.typ",
  "theme": "simple",
  "slide_count": 10,
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "deck", "skill-deck"]
  }
}
```

### 3. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "deck-agent"
  - prompt: [Include prompt, source_path, output_path, theme, slide_count, metadata]
  - description: "Generate pitch deck from input"
```

The agent will:
- Parse and validate inputs
- Read source file if provided
- Map content to YC's 10-slide structure
- Generate Typst code using touying
- Include speaker notes and TODO placeholders
- Return standardized JSON result

### 4. Return Validation

Validate return matches `subagent-return.md` schema:
- Status is one of: generated, partial, failed
- Summary is non-empty and <100 tokens
- Artifacts array present with output file path
- Metadata contains slide_count and slides_with_todos

### 5. Return Propagation

Return validated result to caller without modification.

---

## Return Format

Expected successful return:
```json
{
  "status": "generated",
  "summary": "Generated 10-slide pitch deck for Acme AI in Typst format. 2 slides have TODO placeholders.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "/absolute/path/to/pitch-deck.typ",
      "summary": "Touying pitch deck with speaker notes"
    }
  ],
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "deck-agent",
    "delegation_depth": 2,
    "theme": "simple",
    "slide_count": 10,
    "slides_with_todos": 2,
    "input_type": "prompt_and_file"
  },
  "next_steps": "Review and compile: typst compile pitch-deck.typ"
}
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if neither prompt nor source file provided.

### Source File Not Found
Return failed status with clear message about the missing file.

### Agent Errors
Pass through the agent's error return verbatim.

### Write Failure
Return failed status with directory/permission guidance.
