# Skill-Agent Mapping Reference

Complete reference for skill-to-agent routing and delegation. For quick overview, see CLAUDE.md.

## Core Skills

Core skills are always available regardless of which extensions are loaded.

### Research and Planning

`general`/`meta`/`markdown` research and planning route directly to agents via
`skill-orchestrate`'s dispatch (`command-route-agent.sh`), not through a dedicated research/plan
skill layer — the base lifecycle skills that used to occupy this table have been deleted:

| Agent | Model | Purpose |
|-------|-------|---------|
| general-research-agent | opus | General web/codebase research |
| planner-agent | opus | Implementation plan creation |

### Implementation

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-meta | meta-builder-agent | - | System building and meta tasks |
| skill-reviser | reviser-agent | opus | Plan revision with research synthesis |
| skill-spawn | spawn-agent | opus | Blocker analysis and task decomposition |

`general`/`meta`/`markdown` implementation likewise routes directly to
`general-implementation-agent` via `skill-orchestrate`'s dispatch — no dedicated implement skill.

### Direct Execution Skills

These skills execute directly without agent delegation:

| Skill | Purpose |
|-------|---------|
| skill-status-sync | Atomic status updates to state.json/TODO.md |
| skill-refresh | Process and file cleanup |
| skill-orchestrate | Autonomous lifecycle state machine — drives research/plan/implement loop (/orchestrate command) |
| skill-git-workflow | Create scoped git commits for task operations |
| skill-fix-it | Scan codebase for tagged comments and create structured tasks |

### User-Only Skills

These skills cannot be invoked by agents:

| Skill | Purpose |
|-------|---------|
| skill-tag | Semantic version tagging for deployment |

## Task-Type-Based Routing

Skills are selected based on task language:

### Core Languages

| Task Type | Research Agent | Implementation Agent | Tools |
|----------|----------------|---------------------|-------|
| `general` | general-research-agent | general-implementation-agent | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `meta` | general-research-agent | general-implementation-agent | Read, Grep, Glob, Write, Edit |
| `markdown` | general-research-agent | general-implementation-agent | Read, Write, Edit |

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
┌───────────┐
│ Extension │
│ loaded?   │
└─────┬─────┘
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
