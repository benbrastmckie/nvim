# Implementation Plan: Task #279

- **Task**: 279 - Create skill-scrape and /scrape command
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: Task #278 (scrape-agent must exist)
- **Research Inputs**: specs/279_create_skill_scrape_command/reports/01_meta-research.md
- **Artifacts**: plans/01_skill-scrape-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create two files following established filetypes extension patterns: `skill-scrape/SKILL.md` (thin wrapper delegating to scrape-agent, modeled on skill-filetypes) and `commands/scrape.md` (checkpoint-based command, modeled on convert.md). Together they complete the `/scrape` command pipeline from user invocation through skill routing to agent execution.

### Research Integration

The filetypes extension uses a consistent three-layer pattern: command -> skill -> agent. The `/convert` command exemplifies this: checkpoint-based execution in convert.md, thin delegation wrapper in skill-filetypes/SKILL.md, routing logic in filetypes-router-agent.md, and execution in document-agent.md. The `/scrape` command follows the same structure but routes directly to scrape-agent (no router needed since PDF annotation extraction is a single specialized operation).

## Goals & Non-Goals

**Goals**:
- Create `skill-scrape/SKILL.md` as a thin wrapper following skill-filetypes pattern
- Create `commands/scrape.md` with CHECKPOINT 1 (GATE IN) -> STAGE 2 (DELEGATE) -> CHECKPOINT 2 (GATE OUT) -> CHECKPOINT 3 (COMMIT) structure
- Support argument syntax: `/scrape document.pdf [output.md] [--format markdown|json] [--types highlight,note,underline]`
- Default output path: `{filename}_annotations.md` in same directory as input
- Route directly to scrape-agent (no router agent needed)
- Return user-friendly console summary matching convert.md output format

**Non-Goals**:
- Batch processing of multiple PDFs (single file per invocation)
- Modifying the filetypes-router-agent to route PDF annotations (direct routing is simpler)
- Creating context documentation files (covered in task 280)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Argument parsing for --types flag (comma-separated) | L | M | Use explicit bash parameter parsing, document in SKILL.md |
| Output path collision (annotations.md already exists) | L | L | Warn but do not overwrite by default, or use force flag |
| skill-scrape not found if manifest not updated | M | M | Tasks 279 and 280 are sequential; manifest update follows |

## Implementation Phases

### Phase 1: Create skill-scrape/SKILL.md [NOT STARTED]

**Goal**: Write the skill definition as a thin wrapper that validates inputs and delegates to scrape-agent via Task tool.

**Tasks**:
- [ ] Create directory `.claude/extensions/filetypes/skills/skill-scrape/`
- [ ] Create `SKILL.md` with YAML frontmatter (`name: skill-scrape`, `allowed-tools: Task`)
- [ ] Write brief description paragraph (thin wrapper, delegates to scrape-agent)
- [ ] Write Context Pointers section (reference subagent-return.md, load at subagent execution only)
- [ ] Write Trigger Conditions section with direct invocation and implicit patterns
- [ ] Write Input Validation section (pdf_path required, output_path optional with default logic)
- [ ] Write Context Preparation section with delegation JSON schema
- [ ] Write Invoke Agent section (Task tool, NOT Skill tool, with scrape-agent subagent_type)
- [ ] Write Return Validation section
- [ ] Write Return Propagation section
- [ ] Write Return Format section with example JSON
- [ ] Write Error Handling section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md` - Create new file

**Verification**:
- File exists at correct path
- YAML frontmatter has `allowed-tools: Task`
- Delegation context JSON includes pdf_path, output_path, annotation_types, output_format, metadata
- Uses Task tool (NOT Skill tool) to invoke scrape-agent
- Default output path logic: `{basename}_annotations.md`

### Phase 2: Create commands/scrape.md [NOT STARTED]

**Goal**: Write the /scrape command definition with full checkpoint-based execution flow following convert.md structure.

**Tasks**:
- [ ] Create `commands/scrape.md` with YAML frontmatter (description, allowed-tools, argument-hint)
- [ ] Write Arguments section documenting $1 through $4 (pdf, output, --format, --types)
- [ ] Write Usage Examples section showing all invocation patterns
- [ ] Write Supported Operations section (annotation types table)
- [ ] Write CHECKPOINT 1: GATE IN section:
  - [ ] Session ID generation (portable bash)
  - [ ] Argument parsing with flag handling (--format, --types)
  - [ ] Source path validation and absolute path conversion
  - [ ] Output path derivation logic (`{basename}_annotations.md`)
  - [ ] Output path absolute path conversion
  - [ ] ABORT conditions documented
- [ ] Write STAGE 2: DELEGATE section (invoke Skill tool with skill-scrape)
- [ ] Write CHECKPOINT 2: GATE OUT section (validate return, verify output exists/non-empty)
- [ ] Write CHECKPOINT 3: COMMIT section (optional git commit, non-blocking)
- [ ] Write Output section (success/partial/empty/failed console formats)
- [ ] Write Error Handling section for each failure mode

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/filetypes/commands/scrape.md` - Create new file

**Verification**:
- File exists at correct path
- YAML frontmatter includes `allowed-tools: Skill, Bash(...)` and `argument-hint`
- All four checkpoint/stage blocks are present
- --types argument parsed correctly (comma-split to JSON array)
- Default output uses `{basename}_annotations.md` pattern
- Commit message format follows git-workflow.md conventions
- Output summary format matches convert.md style (Source, Output, Tool, Count, Status)

## File Content Specifications

### skill-scrape/SKILL.md Frontmatter

```yaml
---
name: skill-scrape
description: PDF annotation extraction routing to scrape-agent
allowed-tools: Task
---
```

### skill-scrape Delegation Context

```json
{
  "pdf_path": "/absolute/path/to/document.pdf",
  "output_path": "/absolute/path/to/document_annotations.md",
  "annotation_types": ["highlight", "note", "underline"],
  "output_format": "markdown",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "scrape", "skill-scrape"]
  }
}
```

### scrape.md Frontmatter

```yaml
---
description: Extract annotations and comments from PDF files
allowed-tools: Skill, Bash(date:*), Bash(od:*), Bash(tr:*), Bash(test:*), Bash(dirname:*), Bash(basename:*), Read
argument-hint: SOURCE_PDF [OUTPUT_PATH] [--format markdown|json] [--types TYPE,...]
---
```

### Argument Parsing Logic

```bash
# Parse positional args and flags
source_path=""
output_path=""
output_format="markdown"
annotation_types='[]'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      output_format="$2"
      shift 2
      ;;
    --types)
      # Convert comma-separated to JSON array: "highlight,note" -> '["highlight","note"]'
      IFS=',' read -ra types <<< "$2"
      annotation_types=$(printf '"%s",' "${types[@]}" | sed 's/,$//')
      annotation_types="[$annotation_types]"
      shift 2
      ;;
    *)
      if [ -z "$source_path" ]; then
        source_path="$1"
      else
        output_path="$1"
      fi
      shift
      ;;
  esac
done
```

### Default Output Path Logic

```bash
if [ -z "$output_path" ]; then
  source_dir=$(dirname "$source_path")
  source_base=$(basename "$source_path" .pdf)
  output_path="${source_dir}/${source_base}_annotations.md"
fi
```

### Console Output Format (Success)

```
Annotation extraction complete!

Source: {source_path}
Output: {output_path}
Tool:   {tool_used from metadata}
Found:  {annotation_count} annotations ({types breakdown})

Status: scraped
```

### Console Output Format (Empty)

```
Extraction complete - no annotations found.

Source: {source_path}
Output: {output_path}
Note:   PDF contained no annotations of the requested types.

Status: empty
```

## Testing & Validation

- [ ] `skill-scrape/SKILL.md` exists at `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md`
- [ ] `scrape.md` exists at `.claude/extensions/filetypes/commands/scrape.md`
- [ ] skill-scrape frontmatter has `allowed-tools: Task`
- [ ] scrape.md frontmatter has `allowed-tools: Skill, Bash(...)` with all needed bash tools
- [ ] skill-scrape uses Task tool (not Skill tool) to invoke scrape-agent
- [ ] scrape.md handles all four argument patterns
- [ ] --types parsing converts comma-list to JSON array correctly
- [ ] Default output path uses `_annotations.md` suffix
- [ ] All three checkpoint stages present in scrape.md
- [ ] Error handling covers: file not found, unsupported format, no tools, agent failure

## Artifacts & Outputs

- `.claude/extensions/filetypes/skills/skill-scrape/SKILL.md` - New skill definition
- `.claude/extensions/filetypes/commands/scrape.md` - New command definition

## Rollback/Contingency

If argument parsing for --types proves complex in the command markdown format, simplify to accept only positional arguments and --format flag. The type filtering can be documented as a feature of the skill/agent layer without requiring command-level parsing. The types can default to all annotation types when not specified.
