# Command Output Standard

## Overview

This standard defines the format for command output displayed to users by the orchestrator. It ensures consistent, clear, and concise output across all commands.

## Purpose

- Provide clear context about which task or command is running
- Maintain brief, informative summaries (<100 tokens)
- Ensure consistent output format across all commands
- Avoid redundant information in output

## Header Format

### Task Number Format

Use `Task #{N}` format consistently (no colon after the number):
- Correct: `Task #{N}`
- Incorrect: `Task #{N}:` or `Task: {N}`

### Task-Based Commands

Commands that operate on specific tasks display:

```
{Action} for Task #{N}

{Brief 1-2 sentence summary}

{Artifact label}: {path}

Status: [{STATUS}]
Next: /{command} {N}
```

### Direct Commands

Commands that operate without task context display:

```
{Action} Complete

{Brief 1-2 sentence summary}

{Metrics or counts (if applicable)}

Next Steps:
1. {step}
```

## Output Templates

Commands are assigned to one of three templates based on output complexity.

### Template A: Simple (4-6 lines)

For commands with single artifact and straightforward outcome.

**Structure:**
```
{Action} for Task #{N}

{Artifact}: {path}

Status: [{STATUS}]
Next: /{command} {N}
```

**Example:**
```
Research completed for Task #{N}

Report: specs/{NNN}_modal_logic/reports/01_modal-logic-research.md

Status: [RESEARCHED]
Next: /orchestrate {N}
```

**Assigned Commands:** `/task`

### Template B: Standard (8-12 lines)

For commands with multiple artifacts or metrics.

**Structure:**
```
{Action} for Task #{N}

{Primary artifact}: {path}

{Metric or count section}:
- {item}: {value}

Status: [{STATUS}]
Next: /{command} {N}
```

**Example:**
```
Implementation complete for Task #{N}

Summary: specs/{NNN}_modal_logic/summaries/01_modal-logic-summary.md

Phases completed: 3/3

Status: [COMPLETED]
```

**Assigned Commands:** `/orchestrate`, `/revise`, `/errors`

`/orchestrate` is the only lifecycle driver that exists, and it produces exactly the
phase-metrics-and-summary-artifact output this template describes, so it is assigned here
rather than left without any template assignment at all.

### Template C: Complex (15-25 lines)

For commands with grouped results, multiple sections, or interactive outcomes.

**Structure:**
```
{Action} Complete

{Primary result summary}

{Section 1}:
- {item}
- {item}

{Section 2} ({count}):
- {item}

{Optional metrics section}

Next Steps:
1. {step}
2. {step}
```

**Example:**
```
Archived 5 tasks

Completed (3):
- #245: Add LSP configuration
- #247: Fix parser edge case
- #251: Update documentation

Abandoned (2):
- #246: Deprecated approach
- #250: Superseded by #251

Directories moved: 5
Active tasks remaining: 12

Next Steps:
1. Review archive at specs/archive/
2. Run /review for codebase analysis
```

**Assigned Commands:** `/todo`, `/review`, `/meta`, `/fix-it`, `/refresh`

## Template Assignment Table

| Command | Template | Rationale |
|---------|----------|-----------|
| `/task` | Simple (A) | Task creation confirmation |
| `/orchestrate` | Standard (B) | Phase metrics, summary artifact |
| `/revise` | Standard (B) | Version info, key changes |
| `/errors` | Standard (B) | Error counts, pattern summary |
| `/todo` | Complex (C) | Grouped archives, multiple sections |
| `/review` | Complex (C) | Grouped issues, recommendations |
| `/meta` | Complex (C) | Multiple tasks, next steps |
| `/fix-it` | Complex (C) | Tag groups, task selections |
| `/refresh` | Complex (C) | Process/directory sections |

## Next Step Format

### Single Next Step

Use `Next: /{command} {N}` format (no bold, single line):

```
Next: /orchestrate {N}
```

### Multiple Next Steps

Use `Next Steps:` header (capitalized, no bold) with numbered list:

```
Next Steps:
1. Review tasks in TODO.md
2. Run /orchestrate 650 to begin
3. Progress through the research -> plan -> implement phases via /orchestrate
```

**Avoid:**
- `**Next Steps**:` (bold)
- `**Next**:` (bold)
- `Next: /orchestrate {N} to fix` (action description in next step)

## Summary Requirements

### Token Limit
- **Maximum**: 100 tokens (~400 characters)
- **Target**: 50-75 tokens (~200-300 characters)
- **Enforcement**: Subagent return format standard enforces this limit

### Content Guidelines
- **Focus**: What was accomplished and key outcomes
- **Avoid**: Implementation details, verbose explanations
- **Include**: Status, key results
- **Tone**: Clear, concise, informative

### Summary Structure
1. **First sentence**: What was accomplished
2. **Second sentence** (optional): Key outcome or result

**Good Example:**
```
Research completed for modal logic proof automation. Created comprehensive analysis
of LeanSearch API integration patterns.
```

**Bad Example (too verbose):**
```
I have completed the research phase for the task which involves modal logic proof
automation. During this research, I analyzed the LeanSearch API documentation,
reviewed existing proof search implementations, evaluated different integration
patterns, and created a detailed report with recommendations for implementation.
```

## No Summary Conclusions

**IMPORTANT**: Do NOT add conclusions or closing statements after the output.

The output already provides task/command context. Adding a conclusion like "Task {N} completed" or "Command /review finished" is redundant.

**Correct:**
```
Research completed for Task #{N}

Report: specs/{NNN}_modal_logic_automation/reports/01_modal-logic-research.md

Status: [RESEARCHED]
Next: /orchestrate {N}
```

**Incorrect (redundant conclusion):**
```
Research completed for Task #{N}

Report: specs/{NNN}_modal_logic_automation/reports/01_modal-logic-research.md

Status: [RESEARCHED]
Next: /orchestrate {N}

Task {N} research completed successfully.  ← REDUNDANT, DO NOT ADD
```

## Artifact Display

### Console Output Format

Use labeled paths for console output:

```
Report: specs/{NNN}_modal_logic/reports/01_modal-logic-research.md
Plan: specs/{NNN}_modal_logic/plans/02_modal-logic-plan.md
Summary: specs/{NNN}_modal_logic/summaries/01_modal-logic-summary.md
```

### Markdown File Format

Use markdown links in files (reports, plans, summaries):

```markdown
- [01_research-findings.md](../reports/01_research-findings.md)
- [02_implementation-plan.md](../plans/02_implementation-plan.md)
```

## Error Display

### Format
```
{Action} failed for Task #{N}

Error: {error_message}

Recommendation: {how_to_fix}
```

### Example
```
Research failed for Task #{N}

Error: Task not found in specs/TODO.md

Recommendation: Verify task number and retry
```

## Complete Examples by Template

### Template A: Simple

**Research command:**
```
Research completed for Task #{N}

Report: specs/{NNN}_modal_logic/reports/01_modal-logic-research.md

Status: [RESEARCHED]
Next: /orchestrate {N}
```

**Plan command:**
```
Plan created for Task #{N}

Plan: specs/{NNN}_modal_logic/plans/02_modal-logic-plan.md

Phases: 3
Estimated effort: 4-6 hours

Status: [PLANNED]
Next: /orchestrate {N}
```

**Task creation:**
```
Task #{N} created: Fix parser edge case

Status: [NOT STARTED]
Task Type: general
Artifacts path: specs/{NNN}_fix_parser_edge_case/ (created on first artifact)
```

### Template B: Standard

**Implement command (complete):**
```
Implementation complete for Task #{N}

Summary: specs/{NNN}_modal_logic/summaries/01_modal-logic-summary.md

Phases completed: 3/3

Status: [COMPLETED]
```

**Implement phase (partial):**
```
Implementation paused for Task #{N}

Completed: Phases 1-2
Remaining: Phase 3

Status: [IMPLEMENTING]
Next: /orchestrate {N} (will resume from Phase 3)
```

**Errors command:**
```
Error Analysis Complete

Report: specs/errors/analysis-20260312.md

Errors: 15 total
- Critical unfixed: 2
- High unfixed: 5

Tasks created: 2
- Task #{N}: Fix delegation timeout
- Task #{N}: Fix state sync failure

Next: /orchestrate {N}
```

### Template C: Complex

**Todo command:**
```
Archived 5 tasks

Completed (3):
- #245: Add LSP configuration
- #247: Fix parser edge case
- #251: Update documentation

Abandoned (2):
- #246: Deprecated approach
- #250: Superseded by #251

Directories moved: 5
Active tasks remaining: 12

Next Steps:
1. Review archive at specs/archive/
2. Run /review for codebase analysis
```

**Review command:**
```
Review complete for: src/

Report: specs/reviews/review-20260312.md

Issues found:
- Critical: 1
- High: 3
- Medium: 8
- Low: 12

Tasks created: 2
- Task #{N}: Fix critical LSP error (grouped, 4 issues)
- Task #{N}: Code quality improvements (grouped, 6 issues)

Next Steps:
1. Review report for details
2. Run /orchestrate {N} to address critical issue
```

**Meta command:**
```
Tasks Created

Created 3 task(s) for agent system:

High Priority:
- Task #{N}: Create skill-export
  Path: specs/{NNN}_create_skill_export/

Medium Priority:
- Task #{N}: Add export agent
  Path: specs/{NNN}_add_export_agent/
- Task #{N}: Update CLAUDE.md references
  Path: specs/{NNN}_update_claudemd_references/

Next Steps:
1. Review tasks in TODO.md
2. Run /orchestrate {N} to begin work on first task
3. Progress through the research -> plan -> implement phases via /orchestrate
```

## Implementation Notes

### Command Responsibility
- Commands format their own output following assigned template
- Use template assignment table to determine correct format
- Summaries from skills/agents are incorporated into template structure

### Template Selection
- Simple (A): Commands returning single artifact with linear workflow
- Standard (B): Commands with metrics, multiple artifacts, or completion states
- Complex (C): Commands with grouped results, interactive selection, or multiple sections

### Consistency Checks
- Task number format: Always `Task #{N}` (no colon after)
- Next step format: `Next: /{command} {N}` (single) or `Next Steps:` (multiple)
- Status markers: `[STATUS]` format (e.g., `[COMPLETED]`, `[RESEARCHED]`)
- No bold in next step headers
- No action descriptions in next step (e.g., avoid "to fix", "to begin")

## Related Standards

- **return-metadata-file.md**: Defines metadata file format for agent returns
- **interactive-selection.md**: Defines AskUserQuestion patterns for interactive commands
- **summary-format.md**: Defines summary content guidelines
