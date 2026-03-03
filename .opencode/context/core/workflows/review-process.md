<!-- Context: workflows/review | Priority: high | Version: 3.0 | Updated: 2025-12-25 -->

# Repository Review Workflow

## Quick Reference

**Purpose**: Gap analysis, coverage checks, registry updates, task registration

**Workflow**: Analyze → Read MAINTENANCE.md → Update Registries → Register Tasks

**Registries**: IMPLEMENTATION_STATUS.md, FEATURE_REGISTRY.md, SORRY_REGISTRY.md, TACTIC_REGISTRY.md

**Principles**: Configuration-driven, Repository-agnostic, No implementation

---

## Workflow Overview

The `/review` command performs comprehensive repository analysis and updates project tracking documentation based on findings. The workflow is configuration-driven, reading update instructions from the repository's MAINTENANCE.md file.

## Workflow Stages

The /review command follows the standard 8-stage workflow defined in @.opencode/context/core/workflows/command-lifecycle.md with review-specific adaptations:

**Stage 1 (Preflight)**: Load registries, validate scope, read next_project_number, generate project path
**Stage 2 (PrepareDelegation)**: Generate session_id, set delegation context for reviewer subagent
**Stage 3 (InvokeReviewer)**: Delegate to reviewer subagent with review scope and registry context
**Stage 4 (ReceiveResults)**: Validate reviewer return against subagent-return-format.md
**Stage 5 (ProcessResults)**: Extract artifacts, metrics, identified tasks from reviewer return
**Stage 6 (CreateTasks)**: Create specs/TODO.md tasks from identified_tasks, map placeholder numbers to actual numbers
**Stage 7 (Postflight)**: Replace placeholders in review summary, delegate to status-sync-manager for atomic updates, create review task entry, git commit
**Stage 8 (ReturnSuccess)**: Return brief summary and artifact path to user

See @.opencode/commands/review.md for complete stage specifications.

## Review-Specific Workflow Details

### Repository Analysis (Reviewer Subagent)

The reviewer subagent performs comprehensive gap analysis following the Review Checklist below.

### Registry Updates (Reviewer Subagent)

Update files specified in MAINTENANCE.md (or defaults):
- IMPLEMENTATION_STATUS.md: Module completion, sorry counts, gaps/limitations
- FEATURE_REGISTRY.md: New features, undocumented features, feature status
- SORRY_REGISTRY.md: New/resolved sorry placeholders, counts, resolution guidance
- TACTIC_REGISTRY.md: New tactics, descriptions, usage examples

### Task Creation (Review Command Stage 6)

Create tasks via /task command for identified work:
- Use placeholder numbers (TBD-1, TBD-2) in review summary
- Map placeholders to actual task numbers after creation
- Replace placeholders in review summary with actual numbers and invocation instructions

### Artifact Management

Follows @.opencode/context/core/orchestration/state-management.md:
- Lazy directory creation (project root created when writing first file)
- Only summaries/ subdirectory created (not reports/ or plans/)
- Review summary artifact triggers project specs/state.json creation via status-sync-manager

## Principles

**Configuration-Driven**: Read update instructions from MAINTENANCE.md rather than hardcoding file paths

**Repository-Agnostic**: Workflow works for any repository with MAINTENANCE.md update instructions

**No Implementation**: Review only identifies and registers work; does not implement tasks

**Constructive**: Focus on gaps and improvements, not criticism

**Thorough**: Check functionality not just style, consider edge cases, think maintainability, look for security

**Timely**: Complete review promptly, register tasks clearly, provide actionable recommendations

## Review Checklist

### Functionality
- [ ] Does what it's supposed to do
- [ ] Edge cases handled
- [ ] Error cases handled
- [ ] No obvious bugs

### Code Quality
- [ ] Clear, descriptive naming
- [ ] Functions small and focused
- [ ] No unnecessary complexity
- [ ] Follows coding standards
- [ ] DRY - no duplication

### Security
- [ ] Input validation present
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] No hardcoded secrets
- [ ] Sensitive data handled properly
- [ ] Auth/authorization appropriate

### Testing
- [ ] Tests present
- [ ] Happy path covered
- [ ] Edge cases covered
- [ ] Error cases covered
- [ ] All tests pass

### Performance
- [ ] No obvious performance issues
- [ ] Efficient algorithms
- [ ] No unnecessary operations
- [ ] Resources properly managed

### Maintainability
- [ ] Easy to understand
- [ ] Complex logic documented
- [ ] Follows project conventions
- [ ] Easy to modify/extend

## Review Summary Format

Review summaries follow @.opencode/context/core/formats/summary-format.md:
- Metadata: Status [COMPLETED], timestamps, priority
- Overview: 2-3 sentences (<100 tokens)
- What Changed: Registry updates performed
- Key Findings: Critical findings (sorry count, build errors, etc.)
- Impacts: Implications for codebase health
- Follow-ups: Identified tasks with placeholder numbers (TBD-1, TBD-2)
- References: Paths to updated registries

Placeholder numbers replaced with actual task numbers and invocation instructions in Stage 7.

## Common Issues

### Security
- Hardcoded credentials (Critical)
- SQL injection vulnerabilities (Critical)
- Missing input validation (Critical)
- Exposed sensitive data (Critical)

### Code Quality
- Large functions (>50 lines) (Warning)
- Deep nesting (>3 levels) (Warning)
- Code duplication (Warning)
- Unclear naming (Warning)

### Testing
- Missing tests (Warning)
- Low coverage (<80%) (Warning)
- Flaky tests (Warning)
- Tests testing implementation (Warning)

## Best Practices

- Review within 24 hours
- Provide specific, actionable feedback
- Explain WHY, not just WHAT
- Suggest alternatives
- Acknowledge good work
- Use severity levels (Critical/Warning/Suggestion)
- Test the code if possible
- Check for security issues first

**Golden Rule**: Review code as you'd want yours reviewed - thoroughly but kindly.
