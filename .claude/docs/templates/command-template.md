---
agent: <agent-name>
---

# /<command-name> Command

## Purpose

[Brief description of what this command does and when to use it]

**Use this command when you need to**: [specific use case]

---

## Usage

```
/<command-name> <required-arg> [optional-arg]
```

### Arguments

- `<required-arg>`: [Description of required argument]
- `[optional-arg]`: [Description of optional argument] (optional)

### Examples

```
# Example 1: [Description]
/<command-name> example-value

# Example 2: [Description with optional arg]
/<command-name> example-value --option
```

---

## Workflow

This command delegates to the `<agent-name>` agent, which executes the following workflow:

1. **Input Validation**: Validates command arguments and prerequisites
2. **Context Loading**: Loads required context files on-demand
3. **Core Execution**: [Brief description of core work]
4. **Output Generation**: [Brief description of output]
5. **Artifact Creation**: Creates [artifact type] in `specs/<task-number>_<topic>/`
6. **Return Formatting**: Formats response following subagent-return-format.md
7. **Artifact Validation**: Validates artifacts, updates TODO.md, state.json, creates git commit
8. **Cleanup**: Performs any necessary cleanup

---

## Artifacts

This command creates the following artifacts:

- **[Artifact Type]**: `specs/<task-number>_<topic>/<artifact-path>`
  - [Description of artifact]
  - [Required sections or format]

---

## Prerequisites

- [Prerequisite 1]
- [Prerequisite 2]

---

## Related Commands

- `/<related-command-1>`: [Brief description of relationship]
- `/<related-command-2>`: [Brief description of relationship]

---

## See Also

- **Skill**: `.claude/skills/<skill-name>.md`
- **Agent**: `.claude/agents/<agent-name>.md`
- **Return Format**: `.claude/context/formats/subagent-return.md`

---

## Validation Checklist

Use this checklist when creating a new command:

### Frontmatter
- [ ] Frontmatter includes `agent:` field
- [ ] Agent name matches agent file (without `.md` extension)
- [ ] Agent file exists in `.claude/skills/`

### Documentation
- [ ] Purpose section clearly describes command use case
- [ ] Usage section includes syntax and examples
- [ ] Workflow section describes 8-stage workflow
- [ ] Artifacts section lists all created artifacts
- [ ] Prerequisites section lists all requirements

### File Size
- [ ] Command file is <250 lines (target)
- [ ] Command file is <300 lines (maximum)
- [ ] No embedded routing logic (delegated to agent)
- [ ] No embedded workflow execution (delegated to agent)

### Testing
- [ ] Command tested with valid arguments
- [ ] Command tested with invalid arguments (error handling)
- [ ] Artifacts created successfully
- [ ] Stage 7 execution verified (TODO.md, state.json, git commit)

### Documentation Quality
- [ ] All sections complete (no placeholders)
- [ ] Examples are realistic and helpful
- [ ] Related commands documented
- [ ] See Also section includes relevant links

---

**Template Version**: 1.0
**Last Updated**: 2025-12-29
