# Research Report: Grant Agent Patterns and Implementation

- **Task**: 205 - Create grant-agent with research and writing capabilities
- **Started**: 2026-03-15T00:00:00Z
- **Completed**: 2026-03-15T00:30:00Z
- **Effort**: 1 hour
- **Dependencies**: Task 204 (grant extension scaffold)
- **Sources/Inputs**:
  - Codebase: .claude/agents/ (5 agent files)
  - Codebase: .claude/extensions/grant/ (extension scaffold)
  - Codebase: .claude/context/core/ (format standards)
- **Artifacts**: specs/205_create_grant_agent/reports/01_grant-agent-patterns.md
- **Standards**: report-format.md, artifact-management.md, return-metadata-file.md

## Executive Summary

- Grant-agent should follow the established subagent pattern with frontmatter (name, description, model) and structured execution stages
- Agent requires WebSearch, WebFetch, Read, Write, and Edit tools for comprehensive grant research and proposal drafting
- Progressive context loading should use index.json queries with `load_when.languages == "grant"` and `load_when.agents == "grant-agent"`
- Four primary execution workflows: funder research, proposal drafting, budget development, and progress tracking
- Agent must implement early metadata pattern (Stage 0) and return brief text summary, writing structured metadata to `.return-meta.json`
- Integration with skill-grant requires matching frontmatter `agent:` field and tool declarations

## Context & Scope

This research analyzes the patterns and structure required to implement grant-agent.md for the grant writing extension. The agent will be located at `.claude/extensions/grant/agents/grant-agent.md` and invoked by skill-grant.

**Constraints**:
- Must follow existing agent frontmatter standards
- Must implement early metadata pattern for interruption recovery
- Must integrate with extension's index-entries.json for context discovery
- Must support the four workflow stages defined in EXTENSION.md

## Findings

### Agent Frontmatter Standard

All agents in `.claude/agents/` follow this frontmatter structure:

```yaml
---
name: {agent-name}
description: {Brief description}
model: opus  # or omit for default
---
```

**Key observations**:
- `model: opus` is used for research and planning agents (general-research-agent, planner-agent)
- Implementation agents typically omit the model field (use default)
- `mode`, `temperature`, and `tools` fields appear in some agents (code-reviewer-agent) but not consistently

**Recommendation for grant-agent**: Use `model: opus` since grant writing requires deep reasoning for proposal development.

### Agent Structure Patterns

All agents follow a consistent structure:

1. **Overview Section**: Brief description, invocation context, return format note
2. **Agent Metadata**: Name, Purpose, Invoked By, Return Format
3. **Allowed Tools**: Categorized tool listing with descriptions
4. **Context References**: On-demand loading with @-references
5. **Dynamic Context Discovery**: index.json query patterns
6. **Execution Flow**: Staged workflow (Stage 0-7 typical)
7. **Error Handling**: Error categories and recovery strategies
8. **Return Format Examples**: Success, partial, failed cases
9. **Critical Requirements**: MUST DO and MUST NOT lists

### Tool Requirements for Grant-Agent

Based on skill-grant SKILL.md and grant writing workflows:

| Tool | Purpose |
|------|---------|
| WebSearch | Research funder priorities, past grants, eligibility requirements |
| WebFetch | Retrieve specific application guidelines, funder websites |
| Read | Access context files, templates, existing proposal drafts |
| Write | Create proposal documents, reports, metadata files |
| Edit | Modify draft sections, update progress tracking |

### Progressive Context Loading Pattern

The grant extension uses `index-entries.json` which gets merged into the main `index.json` when loaded. Current entry:

```json
{
  "path": "project/grant/README.md",
  "load_when": {
    "languages": ["grant"],
    "agents": ["grant-agent"],
    "commands": ["/grant"]
  }
}
```

**Context Discovery Query for grant-agent**:

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "grant-agent") |
  .path' .claude/context/index.json
```

**Planned Context Structure** (from grant/context/project/grant/README.md):
- `domain/` - Core grant concepts and terminology
- `patterns/` - Proposal structure and writing patterns
- `templates/` - Budget, timeline, and checklist templates
- `tools/` - Funder-specific application guides
- `standards/` - Writing standards and character limits

### Execution Flow for Grant-Agent

Based on existing agent patterns, grant-agent should implement these stages:

#### Stage 0: Initialize Early Metadata
Write `in_progress` status to `.return-meta.json` immediately.

#### Stage 1: Parse Delegation Context
Extract task_context, metadata, focus_prompt, workflow_type from skill-grant delegation.

#### Stage 2: Determine Grant Workflow
Route based on workflow type:

| Workflow | Primary Actions | Tools |
|----------|-----------------|-------|
| `funder_research` | Search funders, fetch guidelines, analyze requirements | WebSearch, WebFetch, Read |
| `proposal_draft` | Load templates, draft sections, track progress | Read, Write, Edit |
| `budget_develop` | Calculate line items, write justifications | Read, Write, Edit |
| `progress_track` | Update completion status, generate summaries | Read, Write, Edit |

#### Stage 3: Execute Workflow
Run the selected workflow with appropriate context loading.

#### Stage 4: Synthesize and Create Artifacts
Generate reports, drafts, or summaries based on workflow type.

#### Stage 5: Write Metadata File
Write final status and artifacts to `.return-meta.json`.

#### Stage 6: Return Brief Summary
Return 3-6 bullet point text summary (NOT JSON).

### Return Format Integration

Grant-agent must use the file-based metadata exchange pattern:

```json
{
  "status": "researched|planned|implemented|partial|failed",
  "artifacts": [
    {
      "type": "report|proposal|budget",
      "path": "specs/{NNN}_{SLUG}/reports/01_funder-analysis.md",
      "summary": "Brief description"
    }
  ],
  "metadata": {
    "session_id": "{from delegation}",
    "agent_type": "grant-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research|implement", "skill-grant", "grant-agent"]
  }
}
```

### Skill-Agent Integration

skill-grant references grant-agent via frontmatter:

```yaml
---
agent: grant-agent
model: opus
---
```

Grant-agent should expect delegation from skill-grant with:
- task_context (task number, name, language="grant", description)
- metadata (session_id, delegation_depth, delegation_path)
- workflow_type (funder_research, proposal_draft, budget_develop, progress_track)
- focus_prompt (optional specific focus)

### Grant-Specific Features

Based on grant/context/project/grant/README.md, grant-agent should support:

1. **Grant Types**: AI Safety, Tech Startup, Nonprofit, Academic
2. **Core Components**: Executive Summary, Need Statement, Project Description, Budget, Timeline, Evaluation
3. **Best Practices**: Technical clarity, Impact statements, Budget justification

## Decisions

1. **Model**: Use `model: opus` for grant-agent due to complex reasoning requirements
2. **Tool Set**: WebSearch, WebFetch, Read, Write, Edit (full research + writing capability)
3. **Workflow Routing**: Support four distinct workflows with different tool emphasis
4. **Context Loading**: Implement progressive loading via index.json queries with `load_when.agents[]? == "grant-agent"`
5. **Return Format**: Brief text summary to console, structured JSON to `.return-meta.json`

## Recommendations

### 1. Agent File Location
Place at: `.claude/extensions/grant/agents/grant-agent.md`

### 2. Frontmatter Template
```yaml
---
name: grant-agent
description: Grant proposal research and writing with funder analysis
model: opus
---
```

### 3. Execution Stages
Implement 7-stage workflow matching general-research-agent pattern but with grant-specific routing logic.

### 4. Context Loading Sections
```markdown
**Always Load**:
- `@.claude/context/core/formats/return-metadata-file.md`

**Load for Grant Tasks**:
- `@.claude/extensions/grant/context/project/grant/README.md`

**Load On-Demand by Workflow**:
- Funder research: `project/grant/domain/funder-types.md`
- Proposal draft: `project/grant/templates/proposal-template.md`
- Budget: `project/grant/templates/budget-template.md`
```

### 5. Error Handling
Implement WebSearch/WebFetch fallback chain (similar to general-research-agent):
- Primary: Web search for funder information
- Fallback 1: Broader search terms
- Fallback 2: Known funder databases
- Fallback 3: Return partial with recommendations

### 6. Workflow-Specific Outputs

| Workflow | Primary Artifact | Path Pattern |
|----------|------------------|--------------|
| funder_research | Research report | `reports/01_funder-analysis.md` |
| proposal_draft | Draft document | `drafts/01_narrative-draft.md` |
| budget_develop | Budget document | `budgets/01_line-item-budget.md` |
| progress_track | Status summary | `summaries/01_progress-summary.md` |

### 7. Index Entries Enhancement
Expand index-entries.json with additional context files as they are created:

```json
{
  "entries": [
    {
      "path": "project/grant/README.md",
      "load_when": {
        "languages": ["grant"],
        "agents": ["grant-agent"]
      }
    },
    {
      "path": "project/grant/domain/funder-types.md",
      "topics": ["funders", "eligibility"],
      "load_when": {
        "agents": ["grant-agent"]
      }
    }
  ]
}
```

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Web search rate limits | Medium | Medium | Implement caching, use fallback queries |
| Funder website structure changes | Medium | High | Use WebFetch with error handling, fallback to WebSearch |
| Large proposal documents | Low | Medium | Use Edit for incremental changes, avoid full rewrites |
| Context overload | Medium | Low | Progressive loading with budget checks via line_count |

## Appendix

### Files Examined

1. `.claude/agents/general-research-agent.md` - Primary reference for research agent pattern
2. `.claude/agents/planner-agent.md` - Planning workflow pattern
3. `.claude/agents/meta-builder-agent.md` - Multi-step interactive workflow pattern
4. `.claude/agents/code-reviewer-agent.md` - Simple frontmatter example
5. `.claude/agents/README.md` - Agent standards overview
6. `.claude/extensions/grant/manifest.json` - Extension structure
7. `.claude/extensions/grant/EXTENSION.md` - Extension integration documentation
8. `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Skill that invokes grant-agent
9. `.claude/extensions/grant/index-entries.json` - Context index entries
10. `.claude/extensions/grant/context/project/grant/README.md` - Grant domain overview
11. `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema
12. `.claude/context/core/formats/report-format.md` - Report structure
13. `.claude/context/core/patterns/context-discovery.md` - Context loading patterns

### Agent Pattern Summary

```
┌─────────────────────────────────────────────────────────────┐
│                      grant-agent.md                         │
├─────────────────────────────────────────────────────────────┤
│ Frontmatter: name, description, model: opus                │
├─────────────────────────────────────────────────────────────┤
│ Stage 0: Initialize metadata (in_progress)                 │
│ Stage 1: Parse delegation context                          │
│ Stage 2: Determine workflow type                           │
│ Stage 3: Load context (progressive)                        │
│ Stage 4: Execute workflow                                  │
│ Stage 5: Create artifacts                                  │
│ Stage 6: Write metadata file                               │
│ Stage 7: Return brief summary                              │
├─────────────────────────────────────────────────────────────┤
│ Tools: WebSearch, WebFetch, Read, Write, Edit              │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Decision Tree

```
grant-agent receives delegation
    │
    ▼
Parse workflow_type
    │
    ├─── funder_research
    │    └── WebSearch + WebFetch + Read
    │        Create: reports/01_funder-analysis.md
    │
    ├─── proposal_draft
    │    └── Read templates + Write + Edit
    │        Create: drafts/01_narrative-draft.md
    │
    ├─── budget_develop
    │    └── Read templates + Write + Edit
    │        Create: budgets/01_line-item-budget.md
    │
    └─── progress_track
         └── Read + Write + Edit
             Create: summaries/01_progress-summary.md
```
