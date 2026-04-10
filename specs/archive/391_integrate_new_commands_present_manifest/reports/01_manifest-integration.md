# Research Report: Task #391

**Task**: 391 - Integrate new commands into present extension manifest
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T00:05:00Z
**Effort**: small
**Dependencies**: 387, 388, 389, 390 (all completed)
**Sources/Inputs**:
- Present extension manifest.json, index-entries.json, EXTENSION.md, README.md
- Founder extension manifest.json (routing pattern reference)
- New agent, skill, and command files from tasks 387-390
- New context files created by tasks 387-390
**Artifacts**: - specs/391_integrate_new_commands_present_manifest/reports/01_manifest-integration.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- Tasks 387-390 created 4 new commands (/budget, /timeline, /funds, /talk) with agents, skills, and context files, but none are registered in manifest.json
- The manifest.json `provides` section lists only the original grant agent/skill/command; 4 agents, 4 skills, and 4 commands need adding
- The manifest.json `routing` section has only one entry (`grant` under `implement`); needs routing entries for all 5 command types across research/plan/implement phases
- index-entries.json has 17 entries covering only the original grant context; 9 new context files plus talk library entries need index entries
- EXTENSION.md and README.md need updates to document the 4 new commands

## Context & Scope

Task 391 integrates artifacts created by tasks 387-390 into the present extension's registration files. The 4 predecessor tasks each created a complete command stack (agent, skill, command definition, context files) but did not update the manifest or index.

## Findings

### 1. manifest.json -- provides Section

**Current state** (only original grant entries):
```json
"provides": {
  "agents": ["grant-agent.md"],
  "skills": ["skill-grant"],
  "commands": ["grant.md"],
  "rules": [],
  "context": ["project/present"],
  "scripts": [],
  "hooks": []
}
```

**Files that exist but are not registered**:
- Agents: `budget-agent.md`, `timeline-agent.md`, `funds-agent.md`, `talk-agent.md`
- Skills: `skill-budget`, `skill-funds`, `skill-talk`, `skill-timeline`
- Commands: `budget.md`, `timeline.md`, `funds.md`, `talk.md`

**Required change**: Add all 4 new agents, skills, and commands to their respective arrays.

### 2. manifest.json -- routing Section

**Current state** (single entry):
```json
"routing": {
  "implement": {
    "grant": "skill-grant:assemble"
  }
}
```

**Required change**: Following the founder extension pattern (which maps `language:subtype` keys across research/plan/implement phases), add routing entries. Based on the skill/agent architecture:

```json
"routing": {
  "research": {
    "present": "skill-grant",
    "present:grant": "skill-grant",
    "present:budget": "skill-budget",
    "present:timeline": "skill-timeline",
    "present:funds": "skill-funds",
    "present:talk": "skill-talk"
  },
  "plan": {
    "present": "skill-planner",
    "present:grant": "skill-planner",
    "present:budget": "skill-planner",
    "present:timeline": "skill-planner",
    "present:funds": "skill-planner",
    "present:talk": "skill-planner"
  },
  "implement": {
    "present": "skill-grant",
    "present:grant": "skill-grant:assemble",
    "present:budget": "skill-budget",
    "present:timeline": "skill-timeline",
    "present:funds": "skill-funds",
    "present:talk": "skill-talk"
  }
}
```

**Decision point**: The existing manifest uses language `"present"` in the top-level `"language"` field, but the original `routing` used `"grant"` as the key (matching the old language value). The EXTENSION.md language routing table shows `grant` and `present` as distinct languages. The implementation should standardize on `present` as the base language with subtypes.

**Note on planning**: The original grant flow used `skill-grant` for both research and implement. The new commands (budget, timeline, funds, talk) each have dedicated skills that handle their own workflow. For planning, these may use the core `skill-planner` or their own skills -- the implementer should check each SKILL.md for plan-phase handling.

### 3. index-entries.json -- New Context Files Needing Entries

**9 new context files** created by tasks 387-390 that are NOT in index-entries.json:

| File | Domain | Created By | Line Count |
|------|--------|-----------|------------|
| `project/present/domain/funding-analysis.md` | funds | Task 389 | 275 |
| `project/present/domain/grant-budget-frameworks.md` | budget | Task 387 | 215 |
| `project/present/domain/presentation-types.md` | talk | Task 390 | 113 |
| `project/present/domain/research-timelines.md` | timeline | Task 388 | 266 |
| `project/present/patterns/budget-forcing-questions.md` | budget | Task 387 | 260 |
| `project/present/patterns/funding-forcing-questions.md` | funds | Task 389 | 337 |
| `project/present/patterns/talk-structure.md` | talk | Task 390 | 106 |
| `project/present/patterns/timeline-patterns.md` | timeline | Task 388 | 151 |
| `project/present/templates/timeline-template.md` | timeline | Task 388 | 197 |

**Additionally**, the talk library files under `project/present/talk/` (themes, patterns, components, content templates) should be considered for index entries. The talk library has its own `index.json` at `project/present/talk/index.json` with categories for themes, patterns, animations, content, and components.

**Pattern for new entries**: Each entry should use `load_when` matching its command and agent:
- Budget files: `languages: ["present"], agents: ["budget-agent"], commands: ["/budget"]`
- Timeline files: `languages: ["present"], agents: ["timeline-agent"], commands: ["/timeline"]`
- Funds files: `languages: ["present"], agents: ["funds-agent"], commands: ["/funds"]`
- Talk files: `languages: ["present"], agents: ["talk-agent"], commands: ["/talk"]`

**Note**: Existing grant entries use `languages: ["grant"]` and `commands: ["/grant"]`. The implementer should decide whether to also add `"present"` to existing grant entries for consistency, or keep them as-is.

### 4. EXTENSION.md Updates

**Current skill-agent table** has 2 rows (grant-agent, talk-agent). Needs 2 more:
- `skill-budget` -> `budget-agent` (opus) -- Grant budget spreadsheet generation
- `skill-timeline` -> `timeline-agent` (opus) -- Research timeline planning
- `skill-funds` -> `funds-agent` (opus) -- Funding landscape analysis

**Note**: talk-agent is already listed. Verify the model field -- budget-agent does NOT have `model: opus` in its frontmatter (it only has `mcp-servers: []`), while the other 3 new agents do.

**Current commands table** has 3 entries (/grant with 3 modes). Needs 4 new command entries:
- `/budget` with its modes
- `/timeline` with its modes
- `/funds` with its modes
- `/talk` with its modes (already partially documented)

**Current language routing table** has 2 rows. Needs additional rows for:
- `present:budget` task type
- `present:timeline` task type
- `present:funds` task type

### 5. README.md Updates

**Current state**: Documents only `/grant` command. The overview table, commands section, and related files section all need expansion to include the 4 new commands.

Specifically:
- Overview table: add `/budget`, `/timeline`, `/funds`, `/talk` rows
- Commands section: add subsections for each new command with usage examples
- Related files: add references to new context files and workflows

### 6. opencode-agents.json

The manifest has a `merge_targets.opencode_json` entry. If this file exists, it may also need agent entries for the new agents.

## Decisions

- Use `present` as the base language key in routing (matching `manifest.json` top-level `"language": "present"`)
- Follow the founder extension routing pattern with `language:subtype` keys
- Each new context file gets its own index entry with command-specific `load_when`
- Budget-agent should likely get `model: opus` added for consistency (all other new agents have it)

## Recommendations

1. **Update manifest.json `provides`** -- Add 4 agents, 4 skills, 4 commands to arrays
2. **Update manifest.json `routing`** -- Add research/plan/implement routing for all 5 present subtypes following founder pattern
3. **Add 9 index-entries.json entries** -- One per new context file with appropriate `load_when` selectors
4. **Consider talk library index entries** -- The talk/ directory has substantial content; either add individual entries or a single umbrella entry
5. **Update EXTENSION.md** -- Add 3 skill-agent rows, 4 command entries, expand language routing table
6. **Update README.md** -- Add all 4 new commands to overview, commands section, and related files
7. **Check opencode-agents.json** -- Add new agent definitions if file exists

## Risks & Mitigations

- **Language key inconsistency**: Existing grant entries use `"grant"` language; new entries use `"present"`. Mitigation: either add `present:grant` routing or keep `grant` as legacy alias
- **Budget-agent missing model field**: Could cause incorrect model selection. Mitigation: add `model: opus` to budget-agent frontmatter
- **Talk library bulk**: Adding individual index entries for all talk library files would be verbose. Mitigation: use a single umbrella entry with broad topic coverage, or rely on the talk library's own index.json

## Appendix

### Files to Modify
1. `.claude/extensions/present/manifest.json`
2. `.claude/extensions/present/index-entries.json`
3. `.claude/extensions/present/EXTENSION.md`
4. `.claude/extensions/present/README.md`
5. `.claude/extensions/present/opencode-agents.json` (if applicable)

### Reference Files Consulted
- `.claude/extensions/founder/manifest.json` -- routing pattern reference
- `.claude/extensions/present/agents/*.md` -- agent frontmatter
- `.claude/extensions/present/skills/*/SKILL.md` -- skill names and descriptions
- `.claude/extensions/present/commands/*.md` -- command definitions
- `.claude/extensions/present/context/project/present/talk/index.json` -- talk library structure
