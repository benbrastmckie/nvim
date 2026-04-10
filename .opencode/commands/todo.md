---
description: Archive completed and abandoned tasks with CHANGE_LOG updates and memory harvest
---

# Command: /todo

**Purpose**: Archive completed and abandoned tasks with automatic CHANGE_LOG.md updates and memory harvest suggestions  
**Layer**: 2 (Command File)  
**Delegates To**: skill-todo (Direct execution skill)

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    dry_run = "--dry-run" in $ARGUMENTS
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Execute skill-todo</action>
    <process>
      Invoke skill-todo with parsed arguments.
      
      The skill handles:
      - Scanning for archivable tasks
      - Detecting orphaned/misplaced directories  
      - Scanning roadmap and README suggestions
      - Harvesting memory suggestions from artifacts
      - Interactive prompts for user decisions
      - Archiving tasks to specs/archive/
      - Updating ROADMAP.md annotations
      - Applying README.md suggestions
      - Updating CHANGE_LOG.md with entries
      - Creating selected memories
      - Git commit with comprehensive message
    </process>
  </step_1>
</workflow_execution>

---

## Features

### Automatic CHANGE_LOG.md Updates

The skill automatically creates/updates `specs/CHANGE_LOG.md` with entries for each archived task:

```markdown
### 2026-03-05

**Task OC_142: implement_knowledge_capture_system**
- Status: completed
- Type: meta
- Summary: Implemented comprehensive knowledge capture system with /fix-it command, /remember task mode, and enhanced /todo features

Artifacts:
- .opencode/commands/fix-it.md - Tag scanning and task creation
- .opencode/skills/skill-todo/SKILL.md - New skill definition
- specs/CHANGE_LOG.md - New changelog file
```

### Memory Harvest Suggestions

After archiving, the skill scans task artifacts for valuable knowledge:

1. **Research reports** - Findings with general applicability
2. **Implementation plans** - Reusable patterns and techniques
3. **Summaries** - Key learnings and insights

Presented interactively with categories:
- [TECHNIQUE] - Reusable method or approach
- [PATTERN] - Design or implementation pattern
- [CONFIG] - Configuration or setup knowledge
- [WORKFLOW] - Process or procedure
- [INSIGHT] - Key learning or understanding

### Roadmap Annotation

Automatically annotates ROADMAP.md items when tasks complete:
- Completed: `- [x] item *(Completed: Task OC_N, DATE)*`
- Abandoned: `- [ ] item *(Task OC_N abandoned: reason)*`

### README.md Suggestions

For meta tasks, applies readme_suggestions from completion_data to update .opencode/README.md.

---

## Error Handling

<error_handling>
  <parsing_errors>
    - Invalid flags -> Return usage help
  </parsing_errors>
  
  <execution_errors>
    - Skill execution errors -> Log and return guidance
    - State file errors -> Return error with technical details
    - Git commit failures -> Log warning, continue
  </execution_errors>
  
  <interactive_errors>
    - User cancels prompts -> Exit gracefully
    - AskUserQuestion failures -> Default to conservative option
  </interactive_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    specs/state.json
    specs/TODO.md
    specs/ROADMAP.md
    specs/archive/state.json
    specs/errors.json
  </reads>
  
  <writes>
    specs/archive/state.json
    specs/state.json
    specs/TODO.md
    specs/ROADMAP.md
    specs/CHANGE_LOG.md
    .opencode/README.md
    .opencode/memory/10-Memories/
    .opencode/memory/20-Indices/index.md
  </writes>
</state_management>