# Development Templates

This directory contains templates for creating new commands and agents in the Claude Code agent system.

---

## Available Templates

### Command Template

**File**: `command-template.md`
**Purpose**: Template for creating new command files
**Use When**: Adding a new user-facing command to the system
**Guide**: See [Creating Commands](../guides/creating-commands.md) for step-by-step instructions

**Key Features**:
- Frontmatter delegation pattern
- Standard command structure
- Usage examples
- Validation checklist
- File size requirements (<300 lines)

**Usage**:
1. Copy `command-template.md` to `.claude/commands/<command-name>.md`
2. Replace all `<placeholders>` with actual values
3. Fill in all sections (Purpose, Usage, Workflow, etc.)
4. Ensure frontmatter specifies correct agent
5. Validate using checklist at end of template
6. Test command with valid and invalid inputs

### Skill Template (Thin Wrapper Pattern)

**File**: `.claude/context/templates/thin-wrapper-skill.md`
**Purpose**: Template for creating new skill files
**Use When**: Adding a new skill that delegates to an agent
**Guide**: See [Creating Skills](../guides/creating-skills.md) for step-by-step instructions

**Key Features**:
- `context: fork` for token efficiency
- 5-step validation and delegation flow
- Input validation patterns
- Return format validation

**Usage**:
1. Create `.claude/skills/skill-<name>/SKILL.md`
2. Use `context: fork` and specify target agent
3. Implement 5-step validation and delegation flow
4. Validate return matches subagent-return.md
5. Test with corresponding agent

### Agent Template

**File**: `agent-template.md`
**Purpose**: Template for creating new agent files
**Use When**: Adding a new agent to handle execution
**Guide**: See [Creating Agents](../guides/creating-agents.md) for step-by-step instructions

**Key Features**:
- Complete 8-stage workflow implementation
- Stage 7 requirements (artifact validation, status updates, git commits)
- Return format specification
- Context loading pattern
- Validation checklist

**Usage**:
1. Copy `agent-template.md` to `.claude/agents/<agent-name>.md`
2. Replace all `<placeholders>` with actual values
3. Implement all 8 workflow stages
4. **Ensure Stage 7 is fully implemented** (critical for reliability)
5. Validate using checklist at end of template
6. Test agent with valid and invalid inputs

---

## Template Standards

### Frontmatter Delegation Pattern

All commands must use frontmatter to specify their agent:

```yaml
---
agent: <agent-name>
---
```

**Requirements**:
- Agent name must match agent file (without `.md` extension)
- Agent file must exist in `.claude/skills/`
- Frontmatter must be at top of file (before any content)

**Example**:
```yaml
---
agent: research-agent
---

# /research Command
...
```

### 8-Stage Workflow Pattern

All agents must implement the complete 8-stage workflow:

1. **Stage 1: Input Validation** - Validate parameters and prerequisites
2. **Stage 2: Context Loading** - Load required context on-demand
3. **Stage 3: Core Execution** - Perform core work
4. **Stage 4: Output Generation** - Generate outputs in required formats
5. **Stage 5: Artifact Creation** - Create artifacts in task directory
6. **Stage 6: Return Formatting** - Format return following subagent-return-format.md
7. **Stage 7: Artifact Validation and Status Updates** - Validate artifacts, update TODO.md, state.json, create git commit
8. **Stage 8: Cleanup** - Perform cleanup

**Critical**: Stage 7 must be fully implemented. Stage 7 failures cause system-wide reliability issues.

### File Size Requirements

**Commands**:
- **Target**: <250 lines
- **Maximum**: <300 lines
- **Rationale**: Keep commands simple and focused on delegation

**Agents**:
- **No strict limit**: Agents can be larger (they own complete workflow)
- **Recommendation**: Keep under 500 lines if possible
- **Rationale**: Agents are more complex, but should still be maintainable

### Context Loading Pattern

All agents must use lazy-loading pattern:

1. Load `.claude/context/index.json` first
2. Discover available context files from index
3. Load only required context files on-demand
4. Load context after routing (not during)

**Example**:
```markdown
## Stage 2: Context Loading

1. Read `.claude/context/index.json`
2. Load required context:
   - `.claude/context/standards/agent-workflow.md`
   - `.claude/context/agents/research-context.md`
3. Parse context for relevant information
```

---

## Validation Checklists

### Command Validation Checklist

Before submitting a new command, verify:

**Frontmatter**:
- [ ] Frontmatter includes `agent:` field
- [ ] Agent name matches agent file
- [ ] Agent file exists

**Documentation**:
- [ ] Purpose section complete
- [ ] Usage section with examples
- [ ] Workflow section describes 8 stages
- [ ] Artifacts section lists outputs
- [ ] Prerequisites documented

**File Size**:
- [ ] Command file <250 lines (target)
- [ ] Command file <300 lines (maximum)
- [ ] No embedded routing logic
- [ ] No embedded workflow execution

**Testing**:
- [ ] Tested with valid arguments
- [ ] Tested with invalid arguments
- [ ] Artifacts created successfully
- [ ] Stage 7 execution verified

### Agent Validation Checklist

Before submitting a new agent, verify:

**8-Stage Workflow**:
- [ ] Stage 1 (Input Validation) implemented
- [ ] Stage 2 (Context Loading) implemented
- [ ] Stage 3 (Core Execution) implemented
- [ ] Stage 4 (Output Generation) implemented
- [ ] Stage 5 (Artifact Creation) implemented
- [ ] Stage 6 (Return Formatting) implemented
- [ ] **Stage 7 (Artifact Validation, Status Updates, Git Commits) implemented**
- [ ] Stage 8 (Cleanup) implemented

**Stage 7 Requirements**:
- [ ] Artifact validation implemented
- [ ] TODO.md update implemented
- [ ] state.json update implemented
- [ ] Git commit creation implemented
- [ ] Timestamp recording implemented

**Return Format**:
- [ ] Matches subagent-return-format.md
- [ ] All required fields present
- [ ] Summary concise (<100 tokens)
- [ ] Artifacts array populated

**Testing**:
- [ ] Tested with valid inputs
- [ ] Tested with invalid inputs
- [ ] Stage 7 execution verified
- [ ] Artifacts validated
- [ ] Return format validated

---

## Examples

### Example Command: /analyze

```yaml
---
agent: analyzer
---

# /analyze Command

## Purpose

Analyzes code for potential issues and suggests improvements.

**Use this command when you need to**: Review code quality and identify improvement opportunities.

## Usage

```
/analyze <file-path> [--depth=shallow|deep]
```

### Arguments

- `<file-path>`: Path to file or directory to analyze
- `[--depth]`: Analysis depth (default: shallow)

### Examples

```
# Analyze single file
/analyze Logos/Core/Syntax/Formula.lean

# Deep analysis of directory
/analyze Logos/Core/ --depth=deep
```

## Workflow

This command delegates to the `analyzer` agent, which executes the 8-stage workflow...

[Rest of command documentation]
```

### Example Agent: Analyzer

```markdown
# Analyzer Agent

**Agent Type**: analyzer  
**Delegation Depth**: 1  
**Timeout**: 600s  
**Status**: Active

## Purpose

Analyzes code for potential issues and suggests improvements.

**Responsibilities**:
- Parse code files
- Identify potential issues
- Suggest improvements
- Generate analysis report

## 8-Stage Workflow

### Stage 1: Input Validation

**Objective**: Validate file path and analysis depth

**Tasks**:
1. Validate file path exists
2. Validate depth parameter (shallow|deep)
3. Check file is readable
4. Validate delegation depth < 3

[Rest of workflow implementation]
```

---

## Best Practices

### Command Development

1. **Keep Commands Simple**: Commands should delegate, not execute
2. **Document Thoroughly**: Include clear examples and usage instructions
3. **Use Frontmatter**: Always specify agent in frontmatter
4. **Stay Under 300 Lines**: If command exceeds 300 lines, refactor
5. **Test Thoroughly**: Test with valid and invalid inputs

### Agent Development

1. **Implement All 8 Stages**: Don't skip stages, especially Stage 7
2. **Load Context On-Demand**: Use lazy-loading pattern
3. **Follow Return Format**: Match subagent-return-format.md exactly
4. **Handle Errors Gracefully**: Provide clear error messages and recovery steps
5. **Validate Stage 7**: Ensure artifacts validated, TODO.md updated, git commit created

### Testing

1. **Test Valid Inputs**: Verify command works with correct inputs
2. **Test Invalid Inputs**: Verify error handling works
3. **Test Stage 7**: Verify TODO.md, state.json, git commit created
4. **Test Artifacts**: Verify artifacts created and validated
5. **Test Return Format**: Verify return matches subagent-return-format.md

---

## Related Documentation

### Guides
- [Component Selection](../guides/component-selection.md) - When to create command vs skill vs agent
- [Creating Commands](../guides/creating-commands.md) - Step-by-step command creation
- [Creating Skills](../guides/creating-skills.md) - Step-by-step skill creation
- [Creating Agents](../guides/creating-agents.md) - Step-by-step agent creation

### Standards
- **Return Format**: `.claude/context/formats/subagent-return.md`
- **Skill Template**: `.claude/context/templates/thin-wrapper-skill.md`

---

## Support

For questions or issues with templates:

1. Check existing commands and agents for examples
2. Consult workflow standard and return format documentation
3. Create task for template improvements if needed

---

**Document Version**: 1.0
**Last Updated**: 2025-12-29
