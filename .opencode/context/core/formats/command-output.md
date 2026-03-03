# Command Output Standard

## Overview

This standard defines the format for command output displayed to users by the orchestrator. It ensures consistent, clear, and concise output across all OpenCode commands.

## Purpose

- Provide clear context about which task or command is running
- Maintain brief, informative summaries (<100 tokens)
- Ensure consistent output format across all commands
- Avoid redundant information in output

## Header Format

### Task-Based Commands

Commands that operate on specific tasks (`/research`, `/plan`, `/implement`, `/revise`, `/task`) display:

```
Task: {task_number}

{summary}
```

**Example:**
```
Task: 258

Research completed for modal logic proof automation. Created comprehensive analysis of LeanSearch API integration patterns and proof search strategies.

Artifacts created:
- report: specs/258_modal_logic_automation/reports/research-001.md
```

### Direct Commands

Commands that operate without task context (`/todo`, `/errors`, `/review`, `/meta`) display:

```
Command: /{command_name}

{summary}
```

**Example:**
```
Command: /review

Review completed. Analyzed 3 recent implementations for quality and consistency. All implementations meet standards.

Artifacts created:
- report: specs/reviews/review-20260103.md
```

## Summary Requirements

### Token Limit
- **Maximum**: 100 tokens (~400 characters)
- **Target**: 50-75 tokens (~200-300 characters)
- **Enforcement**: Subagent return format standard enforces this limit

### Content Guidelines
- **Focus**: What was accomplished and key outcomes
- **Avoid**: Implementation details, verbose explanations
- **Include**: Status, key results, next steps (if applicable)
- **Tone**: Clear, concise, informative

### Summary Structure
1. **First sentence**: What was accomplished
2. **Second sentence** (optional): Key outcome or result
3. **Third sentence** (optional): Next steps or recommendation

**Good Example:**
```
Research completed for modal logic proof automation. Created comprehensive analysis 
of LeanSearch API integration patterns and proof search strategies.
```

**Bad Example (too verbose):**
```
I have completed the research phase for task 258 which involves modal logic proof 
automation. During this research, I analyzed the LeanSearch API documentation, 
reviewed existing proof search implementations, evaluated different integration 
patterns, and created a detailed report with recommendations for implementation.
```

## No Summary Conclusions

**IMPORTANT**: Do NOT add conclusions or closing statements after the summary.

The header already provides task/command context. Adding a conclusion like "Task 258 completed" or "Command /review finished" is redundant.

**Correct:**
```
Task: 258

Research completed for modal logic proof automation. Created comprehensive analysis.

Artifacts created:
- report: specs/258_modal_logic_automation/reports/research-001.md
```

**Incorrect (redundant conclusion):**
```
Task: 258

Research completed for modal logic proof automation. Created comprehensive analysis.

Artifacts created:
- report: specs/258_modal_logic_automation/reports/research-001.md

Task 258 research completed successfully.  ← REDUNDANT, DO NOT ADD
```

## Artifact Display

### Format
```
Artifacts created:
{for each artifact:}
- {artifact.type}: {artifact.path}
```

### Example
```
Artifacts created:
- report: specs/258_modal_logic_automation/reports/research-001.md
- summary: specs/258_modal_logic_automation/summaries/research-summary-20260103.md
```

## Error Display

### Format
```
Status: Failed
{failure_reason}

Errors:
{for each error:}
- {error.message}

Recommendation: {recommendation}
```

### Example
```
Status: Failed
Research failed due to missing task entry in specs/TODO.md

Errors:
- Task 999 not found in specs/TODO.md

Recommendation: Verify task number and retry
```

## Complete Examples

### Task-Based Command (Success)
```
Task: 258

Research completed for modal logic proof automation. Created comprehensive analysis of LeanSearch API integration patterns and proof search strategies.

Artifacts created:
- report: specs/258_modal_logic_automation/reports/research-001.md
- summary: specs/258_modal_logic_automation/summaries/research-summary-20260103.md
```

### Task-Based Command (Failure)
```
Task: 999

Status: Failed
Task not found in specs/TODO.md

Errors:
- Task 999 not found in specs/TODO.md

Recommendation: Verify task number exists and retry
```

### Direct Command (Success)
```
Command: /review

Review completed. Analyzed 3 recent implementations for quality and consistency. All implementations meet standards.

Artifacts created:
- report: specs/reviews/review-20260103.md
```

### Direct Command (No Artifacts)
```
Command: /todo

specs/TODO.md updated. Added 2 new tasks, updated 3 task statuses to [COMPLETED].
```

## Implementation Notes

### Orchestrator Responsibility
- The orchestrator (Stage 5: PostflightCleanup) is responsible for formatting output
- Headers are added based on command type detected in Stage 1
- Summaries are passed through from subagent returns (already <100 tokens)

### Subagent Responsibility
- Subagents return summaries in standardized format (see subagent-return-format.md)
- Subagents ensure summaries are <100 tokens
- Subagents do NOT add headers or conclusions (orchestrator handles this)

### Command Type Detection
- Task-based: Commands with `routing.task_based: true` in frontmatter
- Direct: Commands with `routing.task_based: false` in frontmatter
- Detection happens in orchestrator Stage 1 (PreflightValidation)

## Related Standards

- **subagent-return-format.md**: Defines return format from subagents
- **command-argument-handling.md**: Defines argument parsing for commands
- **summary.md**: Defines summary content guidelines
