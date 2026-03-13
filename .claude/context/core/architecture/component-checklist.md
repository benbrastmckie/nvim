# Component Creation Checklist

**Created**: 2026-01-19
**Purpose**: Decision tree and checklists for creating new components
**Audience**: /meta agent, developers extending the system

---

## Quick Decision Tree

Use this flowchart to determine which component(s) to create:

```
START: What capability do you need?
   |
   |-- Does the user need to invoke it via "/command"?
   |      |
   |      YES --> Create Command
   |               |
   |               |-- Does it need specialized execution?
   |                      |
   |                      YES --> Also create Skill + Agent
   |                      |
   |                      NO --> Use existing skill/agent
   |
   |-- Are you adding new language/domain support?
   |      |
   |      YES --> Create Skill + Agent pair
   |              (Commands already exist)
   |
   |-- Do you need reusable execution logic?
          |
          YES --> Create Agent only
                  (Existing skills can invoke it)
```

---

## When to Create Each Component

### Create a Command When...

| Criterion | Decision |
|-----------|----------|
| User types `/something` to trigger it | YES |
| It is a new workflow operation (not variant) | YES |
| Operation spans multiple tasks or has utility function | YES |
| Just adding language variant (e.g., Python research) | NO - use existing command |
| Internal-only capability | NO - create skill/agent only |

### Create a Skill When...

| Criterion | Decision |
|-----------|----------|
| New language support (e.g., Python, Rust) | YES |
| Specialized domain handling | YES |
| Need input validation before agent execution | YES |
| Direct execution with no agent needed | YES (skill-status-sync pattern) |
| Execution is trivial (no validation) | NO |
| Existing skill handles the use case | NO |

### Create an Agent When...

| Criterion | Decision |
|-----------|----------|
| Full research workflow for new domain | YES |
| Implementation workflow for new language | YES |
| Multi-step execution with artifact creation | YES |
| Execution is trivial | NO - embed in skill |
| No artifacts are created | NO |
| Existing agent can be extended | NO |

---

## Component Creation Checklists

### Command Checklist

**Before creating**:
- [ ] Verify no existing command handles this use case
- [ ] Determine which skill(s) will be invoked
- [ ] Define argument structure

**YAML frontmatter required**:
```yaml
---
name: {command-name}
description: {One-line description}
routing:
  {language}: {skill-name}
  default: {default-skill}
---
```

**Content requirements**:
- [ ] Clear description of command purpose
- [ ] Usage examples with all argument patterns
- [ ] Routing explanation (which skill handles which language)
- [ ] Error handling (invalid arguments, task not found)

**File location**: `.claude/commands/{command-name}.md`

---

### Skill Checklist (Thin Wrapper Pattern)

**Before creating**:
- [ ] Verify corresponding agent exists or will be created
- [ ] Determine validation requirements
- [ ] Review thin-wrapper-skill template

**YAML frontmatter required**:
```yaml
---
name: skill-{name}
description: {One-line description}
allowed-tools: Task
context: fork
agent: {agent-name}
---
```

**Content requirements**:
- [ ] Trigger conditions section
- [ ] Input validation section
- [ ] Context preparation section (session_id generation)
- [ ] Agent invocation section (MUST use Task tool, not Skill tool)
- [ ] Return validation section
- [ ] Error handling section

**Critical**: Always use Task tool to invoke agents.

**File location**: `.claude/skills/skill-{name}/SKILL.md`

---

### Agent Checklist

**Before creating**:
- [ ] Verify corresponding skill exists or will be created
- [ ] Identify required context files
- [ ] Review subagent-return format

**YAML frontmatter required**:
```yaml
---
name: {name}-agent
description: {One-line description}
---
```

**Content requirements**:
- [ ] Agent Metadata section
- [ ] Allowed Tools section
- [ ] Context References section (use @-references)
- [ ] Execution Flow section (multi-stage workflow)
- [ ] Artifact creation patterns
- [ ] Return Format section with JSON example
- [ ] Error Handling section
- [ ] Critical Requirements (MUST DO / MUST NOT)

**Critical**: Include anti-stop patterns in MUST NOT section.

**MUST NOT items to include**:
```markdown
8. Return the word "completed" as a status value (triggers Claude stop behavior)
9. Use phrases like "task is complete", "work is done", or "finished" in summaries
10. Assume your return ends the workflow (orchestrator continues with postflight)
```

**File location**: `.claude/agents/{name}-agent.md`

---

## Common Component Combinations

### Pattern 1: New User Workflow

When: Creating entirely new command workflow (e.g., /analyze)

**Creates**:
1. Command: `.claude/commands/analyze.md`
2. Skill: `.claude/skills/skill-analyzer/SKILL.md`
3. Agent: `.claude/agents/analyzer-agent.md`

### Pattern 2: New Language Support

When: Adding support for a new language (e.g., Python)

**Creates**:
1. Skill: `.claude/skills/skill-python-research/SKILL.md`
2. Agent: `.claude/agents/python-research-agent.md`

**Uses existing**: `/research` command routes by language

### Pattern 3: Domain-Specific Agent

When: Adding specialized execution for existing workflow

**Creates**:
1. Agent: `.claude/agents/database-implementation-agent.md`

**Uses existing**: `skill-implementer` routes to it

### Pattern 4: Utility Skill (Direct Execution)

When: Need atomic operation without full agent

**Creates**:
1. Skill: `.claude/skills/skill-status-sync/SKILL.md`

**Pattern**: Skill uses direct tools (Bash, Edit, Read) instead of delegating to agent

---

## Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Command | `{verb}.md` | `research.md`, `implement.md` |
| Skill | `skill-{domain}-{purpose}/SKILL.md` | `skill-lean-research/SKILL.md` |
| Agent | `{domain}-{purpose}-agent.md` | `lean-research-agent.md` |

**Rules**:
- Use lowercase with hyphens
- Be descriptive but concise
- Include domain when relevant (lean, latex, etc.)
- Agents always end in `-agent`

---

## Frontmatter Field Reference

### Command Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Command name (matches filename without .md) |
| `description` | Yes | One-line description |
| `routing` | No | Language -> skill mapping |

### Skill Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | `skill-{name}` format |
| `description` | Yes | One-line description |
| `allowed-tools` | Yes | Usually `Task` for thin wrappers |
| `context` | Yes | Usually `fork` to avoid eager loading |
| `agent` | Yes | Target agent name |

### Agent Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | `{name}-agent` format |
| `description` | Yes | One-line description |

---

## Validation After Creation

After creating a component, verify:

### Command Validation
```bash
# Check file exists
ls -la .claude/commands/{name}.md

# Check frontmatter is valid YAML
head -20 .claude/commands/{name}.md
```

### Skill Validation
```bash
# Check directory and file exist
ls -la .claude/skills/skill-{name}/SKILL.md

# Verify uses Task tool, not Skill tool
grep -n "Task tool" .claude/skills/skill-{name}/SKILL.md
```

### Agent Validation
```bash
# Check file exists
ls -la .claude/agents/{name}-agent.md

# Verify frontmatter present
head -10 .claude/agents/{name}-agent.md

# Verify anti-stop patterns included
grep "completed.*triggers" .claude/agents/{name}-agent.md
```

---

## Common Mistakes to Avoid

### 1. Missing Agent Frontmatter

**Wrong**: Agent file without frontmatter (Claude Code ignores it)
```markdown
# My Agent
This agent does things...
```

**Right**: Agent file with proper frontmatter
```yaml
---
name: my-agent
description: Does specific things for a purpose
---
# My Agent
...
```

### 2. Skill Using Skill Tool Instead of Task Tool

**Wrong**: Skill invokes agent via Skill tool
```markdown
Use Skill(lean-research-agent) to execute...
```

**Right**: Skill invokes agent via Task tool
```markdown
Use Task tool with subagent_type: lean-research-agent
```

### 3. Agent Returning "completed" Status

**Wrong**: Triggers Claude stop behavior
```json
{"status": "completed", ...}
```

**Right**: Use contextual status values
```json
{"status": "researched", ...}  // for research
{"status": "planned", ...}     // for planning
{"status": "implemented", ...} // for implementation
```

### 4. Creating Empty Task Directories

**Wrong**: Creating directory at task creation time
```bash
mkdir -p specs/OC_{NNN}_{SLUG}/  # at task creation
```

**Right**: Create lazily when writing first artifact
```bash
mkdir -p specs/OC_{NNN}_{SLUG}/reports/  # when agent writes report
```

---

## Related Documentation

- @.claude/docs/guides/component-selection.md - User-facing decision guide
- @.claude/docs/guides/creating-commands.md - Command creation details
- @.claude/docs/guides/creating-skills.md - Skill creation details
- @.claude/docs/guides/creating-agents.md - Agent creation details
- @.claude/context/core/patterns/anti-stop-patterns.md - Patterns to avoid
