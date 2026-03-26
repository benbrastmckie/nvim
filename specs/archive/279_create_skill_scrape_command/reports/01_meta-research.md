# Research Report: Task #279

**Task**: 279 - Create skill-scrape and /scrape command
**Generated**: 2026-03-25
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Create the skill and command layers for PDF annotation extraction
**Scope**: New skill + command in filetypes extension
**Affected Components**: skill-scrape, /scrape command
**Domain**: filetypes extension
**Language**: meta

## Task Requirements

### /scrape Command

Create `.claude/extensions/filetypes/commands/scrape.md` following `convert.md` pattern:

**Usage**:
```bash
# Extract annotations from PDF (output inferred as .md)
/scrape document.pdf

# Extract to specific output file
/scrape document.pdf annotations.md

# Extract as JSON
/scrape document.pdf annotations.json

# Extract from vimtex context (no args - uses current PDF)
/scrape
```

**Checkpoint-based execution**:
1. **GATE IN**: Generate session_id, parse arguments, validate source PDF exists
2. **DELEGATE**: Invoke skill-scrape with source_path, output_path, session_id
3. **GATE OUT**: Verify output file exists and is non-empty
4. **COMMIT**: Optional git commit

**Argument Handling**:
- `$1` - Source PDF path (required, or infer from vimtex context)
- `$2` - Output file path (optional, defaults to `Annotations/{basename}.md`)

**Output Path Inference**:
- If no output specified: `{source_dir}/Annotations/{source_basename}.md`
- If output has `.json` extension: use JSON format
- If output has `.md` extension: use markdown format

### skill-scrape

Create `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md` following `skill-filetypes/SKILL.md` pattern:

**Structure**:
```yaml
---
name: skill-scrape
description: PDF annotation extraction with tool detection and fallbacks
allowed-tools: Task
---
```

**Execution Flow**:
1. Input validation (source PDF exists)
2. Context preparation (source_path, output_path, format, metadata)
3. Invoke scrape-agent via Task tool (NOT Skill tool)
4. Return validation (matches subagent-return.md schema)
5. Return propagation to caller

**Trigger Conditions**:
- Direct: User runs `/scrape` command
- Implicit: Plan step mentions "extract annotations", "scrape PDF comments", "get PDF highlights"

### Pattern References

**convert.md** (command pattern):
- Session ID generation at GATE IN
- Absolute path conversion for relative inputs
- Output path inference from source extension
- GATE OUT verification of output file

**skill-filetypes/SKILL.md** (skill pattern):
- Thin wrapper with `allowed-tools: Task`
- Validates inputs before delegation
- Uses Task tool (not Skill tool) to invoke agent
- Returns validated JSON result

## Integration Points

- **Component Type**: Skill + Command
- **Affected Area**: `.claude/extensions/filetypes/skills/` and `.claude/extensions/filetypes/commands/`
- **Action Type**: Create
- **Related Files**:
  - `.claude/extensions/filetypes/commands/convert.md` (command pattern)
  - `.claude/extensions/filetypes/skills/skill-filetypes/SKILL.md` (skill pattern)
  - `.claude/extensions/filetypes/agents/scrape-agent.md` (agent to invoke)

## Dependencies

- Task #278: scrape-agent must exist before skill can invoke it

## Interview Context

### User-Provided Information
- Follow convert.md and skill-filetypes patterns exactly
- Support both explicit path and vimtex context inference
- Output format selection based on output file extension
- Checkpoint-based execution with proper error handling

### Effort Assessment
- **Estimated Effort**: 1-2 hours
- **Complexity Notes**: Well-defined patterns from convert.md and skill-filetypes; main effort is adapting for annotation-specific arguments

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 279 [focus]` with a specific focus prompt.*
