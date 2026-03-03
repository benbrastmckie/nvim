# Command Execution Patterns

This file provides execution patterns for different command types in the .opencode system.

## Command Types

### Core Workflow Commands
These are the main task management commands that handle research, planning, implementation, and revision workflows.

### LEAN-Specific Commands
These commands are specialized for LEAN 4 theorem proving, Lake build system, and Mathlib integration.

## Execution Pattern

All commands follow this pattern:
1. Load context files relevant to the command type
2. Parse arguments and determine operation mode
3. Execute the command logic
4. Update task state in specs/state.json and TODO.md
5. Commit changes to git

## Skill/Agent Integration

The system integrates with skills and agents through these patterns:

### Skill Delegation
- Skills use Task tool to delegate to specialized agents
- Skills handle postflight operations (status updates, artifact management)
- Skills create return metadata files

### Agent Functions
- Agents receive delegated tasks with specific context
- Agents perform specialized work (research, implementation, verification)
- Agents return structured results

### Integration Protocol
1. **Skill receives command** → analyzes task context
2. **Skill delegates to agent** → uses Task tool with proper routing
3. **Agent executes work** → performs specialized operations
4. **Agent returns result** → structured return format
5. **Skill handles postflight** → updates state, creates artifacts
6. **Control returns to caller** → command completes

## Error Handling

Commands include comprehensive error handling:
- Validate arguments
- Check required tools
- Handle task state conflicts
- Provide helpful error messages
- Exit with appropriate codes

## Integration Points

Commands integrate with:
- Task state management (specs/state.json, specs/TODO.md)
- Agent delegation (via Task tool when needed)
- Git workflow (automatic commits)
- Context loading (from .opencode/context/)
- Skill execution (for specialized operations)