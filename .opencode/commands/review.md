---
description: Analyze codebase, identify issues, and optionally create tasks
---

Route to skill-reviewer for comprehensive codebase analysis.

**Input**: $ARGUMENTS

**Command Pattern**: `/review [scope] [--create-tasks]`

---

## Routing

**Target**: skill-reviewer  
**Subagent**: code-reviewer-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="code-reviewer-agent"

---

## Validation (Performed by Skill)

- Scope is valid (file path, directory, or "all")
- Review state is accessible: `specs/reviews/state.json`

---

## Skill Arguments

- **scope**: Review scope - file, directory, or "all" (string, default: "all")
- **create_tasks**: Whether to create tasks for issues found (bool, default: false)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Scan for archivable tasks yourself
- Detect orphaned directories yourself
- Load review state yourself
- Analyze codebase yourself
- Check for TODO/FIXME comments yourself
- Create analysis reports yourself
- Create tasks yourself
- Update ROAD_MAP.md yourself
- Commit changes yourself

### DO:
- Extract scope and --create-tasks flag from input
- Generate session_id for tracking
- Invoke Skill(skill-reviewer, args)
- Return skill result to user

**Skill handles**: Codebase analysis, issue detection, report generation, task creation, roadmap updates, commits

---

## Expected Skill Behavior

The skill-reviewer will:
1. Parse scope and flags
2. Load or initialize `specs/reviews/state.json`
3. Delegate to code-reviewer-agent via Task tool with forked context
4. code-reviewer-agent will:
   - Gather context (Lean diagnostics, TODO/FIXME detection, etc.)
   - Integrate with roadmap if applicable
   - Analyze findings by category
   - Create review report at `specs/reviews/review-{DATE}.md`
   - Annotate completed roadmap items in `specs/ROAD_MAP.md` (if applicable)
5. Update review state
6. If --create-tasks: Create tasks for High/Critical issues
7. Commit changes
8. Return comprehensive summary to user

---

## Output

Skill returns:
- Issue statistics by category (Critical, High, Medium, Low)
- Review report path
- Code quality metrics
- Created task count (if --create-tasks)
- Roadmap progress updates (if applicable)

---

## Error Handling

Handled by skill:
- Invalid scope → Error with guidance
- Missing review files → Initialize with defaults
- Lean diagnostics failure → Log warning, continue
- Roadmap parsing errors → Log warning, skip integration
- Git failures → Log warning, continue

---

**Note**: This is a routing specification. All implementation details are delegated to skill-reviewer.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
