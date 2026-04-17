# Skill-Agent Mapping Reference

Complete reference for skill-to-agent routing and delegation. For quick overview, see CLAUDE.md.

## Core Skills

Core skills are always available regardless of which extensions are loaded.

### Research and Planning

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-researcher | general-research-agent | opus | General web/codebase research |
| skill-planner | planner-agent | opus | Implementation plan creation |

### Implementation

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-implementer | general-implementation-agent | - | General file implementation |
| skill-meta | meta-builder-agent | - | System building and meta tasks |
| skill-reviser | reviser-agent | opus | Plan revision with research synthesis |
| skill-spawn | spawn-agent | opus | Blocker analysis and task decomposition |

### Direct Execution Skills

These skills execute directly without agent delegation:

| Skill | Purpose |
|-------|---------|
| skill-status-sync | Atomic status updates to state.json/TODO.md |
| skill-refresh | Process and file cleanup |
| skill-todo | Archive completed tasks, sync metrics |
| skill-orchestrator | Route commands to appropriate workflows based on task type and status |
| skill-git-workflow | Create scoped git commits for task operations |
| skill-fix-it | Scan codebase for tagged comments and create structured tasks |

### User-Only Skills

These skills cannot be invoked by agents:

| Skill | Purpose |
|-------|---------|
| skill-tag | Semantic version tagging for deployment |

## Team Mode Skills

When `--team` flag is passed to commands, routing overrides to team skills which spawn multiple parallel teammates. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable.

| Flag | Team Skill | Teammates | Purpose |
|------|------------|-----------|---------|
| `--team` | skill-team-research | 2-4 | Parallel investigation with synthesis |
| `--team` | skill-team-plan | 2-3 | Parallel plan generation with trade-offs |
| `--team` | skill-team-implement | 2-4 | Parallel phase execution with debugger |

**Graceful Degradation**: If team mode unavailable, falls back to single-agent mode.

**Cost Note**: Team mode uses ~5x tokens compared to single-agent. Default team_size=2 minimizes cost.

## Task-Type-Based Routing

Skills are selected based on task language:

### Core Languages

| Task Type | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `general` | skill-researcher | skill-implementer | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `meta` | skill-researcher | skill-implementer | Read, Grep, Glob, Write, Edit |
| `markdown` | skill-researcher | skill-implementer | Read, Write, Edit |

### Extension Languages

Extensions define their own skill-to-agent mappings via `manifest.json`:

```json
{
  "name": "extension-name",
  "task_types": ["lang1", "lang2"],
  "skills": {
    "skill-lang-research": "lang-research-agent",
    "skill-lang-implementation": "lang-implementation-agent"
  }
}
```

When an extension is loaded (via the extension picker or `@-reference`), its skills become available for routing.

**Example Extension Routing** (when lean extension loaded):

| Task Type | Research Skill | Implementation Skill |
|----------|----------------|---------------------|
| `lean4` | skill-lean-research | skill-lean-implementation |

## Agent Model Preferences

Agents declare preferred models via `model:` frontmatter field:

| Agent | Model | Rationale |
|-------|-------|-----------|
| general-research-agent | opus | Superior reasoning for research |
| planner-agent | opus | Superior reasoning for planning |
| general-implementation-agent | (default) | Faster for execution |
| meta-builder-agent | (default) | Faster for file operations |

See `.claude/docs/reference/standards/agent-frontmatter-standard.md` for model enforcement details.

## Routing Decision Flow

```
Command invoked with task N
         │
         ▼
┌─────────────────┐
│ Get task.task_type│
│ from state.json  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Check --team    │
│ flag present?   │
└────────┬────────┘
    ┌────┴────┐
   yes       no
    │         │
    ▼         ▼
┌───────┐ ┌───────────┐
│ Team  │ │ Extension │
│ skill │ │ loaded?   │
└───────┘ └─────┬─────┘
          ┌─────┴─────┐
         yes         no
          │           │
          ▼           ▼
    ┌───────────┐ ┌────────────┐
    │ Extension │ │ Core skill │
    │ skill     │ │ by language│
    └───────────┘ └────────────┘
```

## Extension Skill Loading

Extensions are loaded via:

1. **Extension picker**: Opens extension selector
2. **@-reference**: `@.claude/extensions/lean/context/...` auto-loads extension
3. **Context discovery**: Agents query `index.json` which includes merged extension entries

### Merging Process

When extension loaded:
1. Extension `index-entries.json` merged into main `index.json`
2. Extension skills become available in routing tables
3. Extension rules auto-apply to matching file paths

## Related Documentation

- [State Management Schema](state-management-schema.md) - Task task_type field values
- [Agent Frontmatter Standard](../../docs/reference/standards/agent-frontmatter-standard.md) - Model declarations
- [Extensions Architecture](../../extensions/README.md) - Extension structure
